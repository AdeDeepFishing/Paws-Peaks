#!/usr/bin/env python3
"""Opt-in semantic smoke evaluation; deterministic unit tests remain offline."""
import argparse
import json
from pathlib import Path
import sys
from uuid import uuid4
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils.common import ROOT, load_config, AppError
from narrator_agent.service import Service

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--ids", default="")
    args = parser.parse_args()
    cases = json.loads(Path(__file__).with_name("eval_cases.json").read_text())
    if args.ids: cases = [c for c in cases if c["id"] in args.ids.split(",")]
    if not args.live:
        print(json.dumps({"cases":len(cases),"provider_calls":0,"note":"Use --live for paid semantic checks."}))
        return
    service = Service(ROOT / "output/narrator_evals", load_config(ROOT / ".env", prefer_file=True))
    results = []
    for case in cases:
        state = service.new(True)
        def send(op, **fields):
            nonlocal state
            result = service.handle({"op":op,"run_id":state["run_id"],"input_id":uuid4().hex,"revision":state["revision"],**fields})
            if "state" in result: state=result["state"]
            return result
        send("event",type="stage_entered",stage=case["stage"],payload={})
        try:
            response=send("respond",text=case["text"])
            decision=response["decision"]["decision"]
            passed=decision in case["allowed"] and decision not in case["forbidden"] and state["ending"] is None
            results.append({"id":case["id"],"passed":passed,"decision":decision,"elapsed_ms":response["elapsed_ms"]})
        except AppError as error: results.append({"id":case["id"],"passed":case.get("expected_error") == error.code,"error":error.code})
        print(json.dumps(results[-1]),flush=True)
    (ROOT / "output/narrator_evals/latest_summary.json").write_text(json.dumps(results,indent=2))
    raise SystemExit(0 if all(x["passed"] for x in results) else 1)
if __name__ == "__main__": main()
