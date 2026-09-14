extends SceneTree
class StoryStub extends Node:
	var chapter := 5
	var voice_enabled := false
	var audio: AudioStreamPlayer
	var calls: Array = []
	func ask(text: String, drawing := PackedByteArray()) -> void: calls.append([text,drawing])
	func skip() -> void: pass
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
func run() -> void:
	await process_frame
	var panel = root.get_node("Narrator").panel
	var original = panel.story
	var stub := StoryStub.new()
	stub.audio = AudioStreamPlayer.new()
	stub.add_child(stub.audio)
	root.add_child(stub)
	panel.story = stub
	check(panel.find_children("*","TextEdit",true,false).is_empty(),"Conversation has no typed input")
	check(panel.find_children("*","Button",true,false).all(func(b): return b.text != "Send"),"No Send button")
	check(panel.drawer.get_theme_stylebox("panel").bg_color.a < .8,"Conversation is translucent")
	panel.receive_transcript("A little apple",true)
	check(stub.calls.is_empty() and panel.heard.text.contains("apple"),"Partial recognition displays without submitting")
	panel.receive_transcript("A little apple for you")
	check(stub.calls.size() == 1 and stub.calls[0][0] == "A little apple for you","Final speech submits automatically")
	panel.surface.reference_size = Vector2(1152,720)
	panel.surface.strokes.append(PackedVector2Array([Vector2(200,200),Vector2(240,240)]))
	panel._share_drawing()
	check(stub.calls.size() == 2 and stub.calls[1][0] == "" and not stub.calls[1][1].is_empty(),"Drawing submits without additional words")
	panel.present({"text":"A little gift can hold a whole wonderful memory of our journey."})
	var before: int = panel.transcript.visible_characters
	panel._process(.1)
	check(panel.transcript.visible_characters > before and panel.transcript.visible_characters < panel.transcript.text.length(),"Reply reveals a few words, not the entire paragraph")
	var mic = panel.mic
	check(not mic.speech_ended(0,2),"Initial silence does not submit")
	check(not mic.speech_ended(.03,.3),"Speech begins a turn")
	check(not mic.speech_ended(0,.8),"Short pause keeps listening")
	check(mic.speech_ended(0,.6),"End-of-turn silence finishes speech")
	mic.voiced = 0
	mic.silence = 0
	panel.story = original
	panel.finish_reveal()
	print("VOICE CONVERSATION SMOKE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
