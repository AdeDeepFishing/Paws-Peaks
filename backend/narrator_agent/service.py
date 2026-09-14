"""Evidence-backed journal, isolated actor/referee, and guarded ending transitions."""
import base64
from copy import deepcopy
import json
from pathlib import Path
import re
import threading
import time
from uuid import uuid4
from utils.common import AppError, image_input
from narrator_agent import model
from speech.service import Speech

EVENTS = {"stage_entered", "drawing_submitted", "drawing_interpreted", "drawing_corrected", "object_spawned", "object_use_resolved",
          "npc_interaction_resolved", "encounter_completed", "player_stuck", "player_idle", "boss_gate_reached"}

def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", value):
        raise AppError("INVALID_REQUEST", "Invalid request identity.")
    return value

def require(ok, code="INVALID_REQUEST"):
    if not ok: raise AppError(code, "The request no longer matches the current story. Please try again.")

class Service:
    def __init__(self, directory, config, caller=model.call):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.config, self.caller = config, caller
        self.lock = threading.RLock()
        self.voice_lock = threading.Lock()

    def path(self, run): return self.directory / identifier(run) / "story.json"

    def read(self, run):
        try: return json.loads(self.path(run).read_text())
        except FileNotFoundError: raise AppError("RUN_NOT_FOUND", "Start a journey first.") from None

    def write(self, state):
        path = self.path(state["run_id"])
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(".tmp")
        temp.write_text(json.dumps(state, ensure_ascii=False))
        temp.replace(path)

    def new(self, simulated=False):
        state = {"run_id": uuid4().hex, "revision": 0, "stage": 0, "phase": "GUIDE", "exit_open": False,
                 "ending": None, "candidate": None, "concern": "", "events": [], "requests": {},
                 "simulated": bool(simulated), "parent_run": None}
        self.write(state)
        return self.public(state)

    @staticmethod
    def public(state):
        return {k: deepcopy(state[k]) for k in ("run_id", "revision", "stage", "phase", "exit_open", "ending", "candidate", "concern", "simulated")}

    def add_event(self, state, kind, payload, revise=True):
        event = {"id": uuid4().hex, "type": kind, "stage": state["stage"], "payload": deepcopy(payload),
                 "provenance": "simulated" if state["simulated"] else "game", "time": time.time()}
        state["events"].append(event)
        if revise: state["revision"] += 1
        return event

    def context(self, state):
        # Keep every event in the journal, retrieve bounded coverage from each chapter.
        recent = state["events"][-24:]
        important = []
        for stage in range(1, 6):
            selected = [e for e in state["events"] if e["stage"] == stage and e["type"] in
                        ("drawing_corrected", "object_use_resolved", "npc_interaction_resolved", "encounter_completed", "narration_presented")]
            important.extend(selected[-6:])
        events = {e["id"]: e for e in important + recent}
        return {"state": self.public(state), "events": list(events.values()), "rules_version": model.VERSION,
                "world": {"stages": {"1": "A storybook creek and a river crossing", "2": "A woodland path guarded by a large dog", "3": "A windy hill with a giant bird", "4": "A sunset beach and an otter", "5": "A moonlit forest clearing with rocks, trees and fireflies; no campfire"},
                          "protagonist": "The Moonlit Wanderer. No confirmed family or home destination.",
                          "boss": "A towering paper-cloaked storyteller holding a book. Only appears physically in stage 5."}}

    def handle(self, request):
        require(isinstance(request, dict))
        op = request.get("op")
        with self.lock:
            if op == "new": return {"state": self.new(request.get("simulated", False))}
            run, request_id = identifier(request.get("run_id")), identifier(request.get("input_id"))
            state = self.read(run)
            if op == "state": return {"state": self.public(state)}
            if op == "export": return {"journal": {k: v for k, v in state.items() if k != "requests"}}
            if op == "delete":
                import shutil
                shutil.rmtree(self.path(run).parent)
                return {"deleted": True}
            if op == "checkpoint":
                checkpoint = self.path(run).parent / ("checkpoint-" + request_id + ".json")
                if not checkpoint.exists(): checkpoint.write_text(json.dumps(state))
                return {"checkpoint": request_id}
            if op == "fork":
                checkpoint = identifier(request.get("checkpoint"))
                path = self.path(run).parent / ("checkpoint-" + checkpoint + ".json")
                require(path.exists())
                fork = json.loads(path.read_text())
                fork["parent_run"], fork["run_id"], fork["requests"] = run, uuid4().hex, {}
                # Pending confirmations belong to the original branch, never the fork.
                fork["candidate"] = None
                if fork["phase"] == "STAY_OFFERED": fork["phase"] = "CONFRONTING"
                self.write(fork)
                return {"state": self.public(fork)}
            previous = state["requests"].get(request_id)
            if previous:
                if previous.get("pending"): raise AppError("IN_PROGRESS", "This response is still being prepared.")
                if previous.get("error"): raise AppError(previous["error"], "Please submit a new request to try again.")
                return deepcopy(previous)
            if op == "event":
                kind, payload = request.get("type"), request.get("payload", {})
                require(kind in EVENTS and isinstance(payload, dict) and len(json.dumps(payload)) <= 6000)
                if kind == "stage_entered":
                    stage = request.get("stage")
                    require(type(stage) is int and 1 <= stage <= 5)
                    state["stage"] = stage
                    if not state["ending"] and not state["exit_open"]:
                        state["phase"] = "CONFRONTING" if stage == 5 else ("ATTACHED" if stage >= 3 else "GUIDE")
                else: require(request.get("stage") == state["stage"], "STALE_RESULT")
                # Actual game events invalidate a pending ending confirmation.
                state["candidate"] = None
                if state["phase"] == "STAY_OFFERED": state["phase"] = "CONFRONTING"
                event = self.add_event(state, kind, payload)
                result = {"state": self.public(state), "event_id": event["id"]}
                state["requests"][request_id] = result
                self.write(state)
                return result
            if op == "presented":
                utterance = state["requests"].get(request.get("utterance_id"), {})
                require("utterance" in utterance)
                self.add_event(state, "narration_presented", utterance["utterance"], revise=False)
                result = {"state": self.public(state)}
                state["requests"][request_id] = result
                self.write(state)
                return result
            if op == "voice":
                utterance = state["requests"].get(request.get("utterance_id"), {}).get("utterance")
                require(isinstance(utterance, dict))
                text, speaker = utterance["text"], utterance.get("speaker", "narrator")
            elif op in ("confirm_stay", "cancel_stay", "leave"):
                require(request.get("revision") == state["revision"], "STALE_RESULT")
                require(state["stage"] == 5 and state["ending"] is None, "ENDING_LOCKED")
                if op == "leave":
                    require(state["exit_open"] and request.get("crossed_exit") is True)
                    state["ending"], state["phase"] = "leave", "ENDING_LEAVE"
                else:
                    require(state["candidate"] is not None and request.get("candidate") == state["candidate"])
                    if op == "confirm_stay": state["ending"], state["phase"] = "stay", "ENDING_STAY"
                    else: state["phase"] = "RELEASE_READY" if state["exit_open"] else "CONFRONTING"
                state["candidate"] = None
                self.add_event(state, op, {})
                result = {"state": self.public(state)}
                state["requests"][request_id] = result
                self.write(state)
                return result
            elif op == "respond":
                require(state["ending"] is None, "ENDING_LOCKED")
                require(request.get("revision") == state["revision"], "STALE_RESULT")
                text = request.get("text", "")
                require(isinstance(text, str) and len(text) <= 2000)
                require(request.get("trigger", "dialogue") in ("dialogue", "event", "idle"))
                image = None
                if request.get("image_base64"):
                    try: raw = base64.b64decode(request["image_base64"], validate=True)
                    except Exception: raise AppError("INVALID_REQUEST", "Invalid drawing.") from None
                    require(0 < len(raw) <= 1048576)
                    path = self.path(run).parent / (request_id + ".png")
                    path.write_bytes(raw)
                    try: image = image_input(path)
                    except Exception:
                        path.unlink(missing_ok=True)
                        raise
                require(bool(text.strip()) or image or request.get("trigger") != "dialogue")
                state["candidate"] = None
                if state["phase"] == "STAY_OFFERED": state["phase"] = "CONFRONTING"
                if text or image:
                    self.add_event(state, "player_input", {"text": text, "drawing": request_id if image else None, "verified_action": False})
                revision = state["revision"]
                context = self.context(state)
                context["input"] = {"text": text, "has_drawing": bool(image), "trigger": request.get("trigger", "dialogue")}
                state["requests"][request_id] = {"pending": True}
                self.write(state)
            else: raise AppError("INVALID_REQUEST", "Unknown story operation.")
        if op == "voice":
            with self.voice_lock:
                path = Speech(self.config, self.path(run).parent / "speech").generate(text, speaker)
            return {"audio_path": str(path), "utterance_id": request["utterance_id"]}
        started = time.monotonic()
        try:
            evidence_ids = {e["id"] for e in context["events"]}
            judge = {"decision": "NO_CHANGE", "reason": "Comment on confirmed events only.", "concern": context["state"]["concern"], "drawing_name": "", "evidence": []}
            metrics = []
            if context["state"]["stage"] == 5 and (text or image):
                judge, metric = self.caller(self.config, model.JUDGE, context, model.JUDGE_SCHEMA, image)
                metrics.append(metric)
            require(judge["decision"] in model.DECISIONS and set(judge["evidence"]) <= evidence_ids, "INVALID_MODEL_OUTPUT")
            if context["state"]["exit_open"] and judge["decision"] not in ("OFFER_STAY_ENDING", "REST_TEMPORARILY"):
                judge["decision"] = "NO_CHANGE"
            # The performer receives the validated proposal and may not rewrite it.
            context["authoritative_result"] = judge
            actor, metric = self.caller(self.config, model.ACTOR, context, model.ACTOR_SCHEMA, image)
            metrics.append(metric)
            require(set(actor["evidence"]) <= evidence_ids and actor["emotion"] in model.EMOTIONS, "INVALID_MODEL_OUTPUT")
            require(isinstance(actor["text"], str) and 0 < len(actor["text"]) <= 600, "INVALID_MODEL_OUTPUT")
            require((actor["channel"], actor["addressed_to"]) in (("direct_dialogue", "player"), ("book_narration", "protagonist")), "INVALID_MODEL_OUTPUT")
            with self.lock:
                state = self.read(run)
                require(state["revision"] == revision and state["ending"] is None, "STALE_RESULT")
                decision = judge["decision"]
                if decision == "OPEN_EXIT":
                    require(state["stage"] == 5)
                    state["exit_open"], state["phase"] = True, "RELEASE_READY"
                elif decision == "OFFER_STAY_ENDING":
                    require(state["stage"] == 5)
                    state["candidate"], state["phase"] = uuid4().hex, "STAY_OFFERED"
                elif decision == "REST_TEMPORARILY":
                    require(state["stage"] == 5)
                    state["phase"] = "RESTING"
                elif state["phase"] == "RESTING":
                    state["phase"] = "RELEASE_READY" if state["exit_open"] else "CONFRONTING"
                state["concern"] = judge["concern"][:400]
                self.add_event(state, "decision", judge)
                actor["speaker"] = "narrator"
                result = {"state": self.public(state), "utterance": actor, "decision": judge,
                          "input_id": request_id, "metrics": metrics, "elapsed_ms": round((time.monotonic()-started)*1000)}
                state["requests"][request_id] = result
                self.write(state)
                return result
        except Exception as error:
            code = error.code if isinstance(error, AppError) else "MODEL_UNAVAILABLE"
            with self.lock:
                state = self.read(run)
                state["requests"][request_id] = {"error": code}
                self.write(state)
            raise AppError(code, "The Storykeeper could not finish that thought. Your drawing and words are saved.") from None
