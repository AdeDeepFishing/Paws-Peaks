extends Node

signal recorded(wav: PackedByteArray)
signal partial_recorded(wav: PackedByteArray)
signal failed(message: String)
var recording := false
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var pcm := PackedByteArray()
var sample_cursor := 0.0
var bus_index := -1
var elapsed := 0.0
var peak := 0
var silence := 0.0
var voiced := 0.0
var partial_at := 3.0
const LIMIT := 16000 * 20 * 2

func start() -> void:
	if recording: return
	pcm.clear()
	elapsed = 0.0
	silence = 0.0
	voiced = 0.0
	partial_at = 3.0
	peak = 0
	sample_cursor = 0.0
	bus_index = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "PlayerTalkMic")
	AudioServer.set_bus_mute(bus_index, true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_index, capture)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = "PlayerTalkMic"
	add_child(player)
	capture.clear_buffer()
	recording = true
	player.play()

func _process(delta: float) -> void:
	if not recording: return
	elapsed += delta
	if elapsed >= 20.0:
		stop(true)
		return
	var available := capture.get_frames_available()
	if available == 0: return
	var frames := capture.get_buffer(available)
	var energy := 0.0
	for frame in frames: energy += pow((frame.x + frame.y) * 0.5, 2)
	var rms := sqrt(energy / maxf(frames.size(), 1))
	var step := AudioServer.get_mix_rate() / 16000.0
	while sample_cursor < frames.size() and pcm.size() < LIMIT:
		var frame := frames[int(sample_cursor)]
		var value := int(clampf((frame.x + frame.y) * 0.5, -1.0, 1.0) * 32767.0)
		peak = maxi(peak, absi(value))
		pcm.append(value & 255)
		pcm.append((value >> 8) & 255)
		sample_cursor += step
	sample_cursor -= frames.size()
	if pcm.size() >= LIMIT or speech_ended(rms, frames.size() / AudioServer.get_mix_rate()):
		stop(true)
	elif voiced >= .25 and elapsed >= partial_at:
		partial_at = elapsed + 3.0
		partial_recorded.emit(snapshot_wav())

## Accumulate captured audio duration so rendering stalls do not alter turn detection.
func speech_ended(rms: float, duration: float) -> bool:
	if rms > 0.012:
		voiced += duration
		silence = 0.0
	else:
		silence += duration
	return voiced >= .25 and silence >= 1.35

func stop(submit := true) -> void:
	if not recording: return
	recording = false
	player.stop()
	player.queue_free()
	AudioServer.remove_bus(bus_index)
	bus_index = -1
	if not submit:
		pcm.clear()
		return
	if pcm.size() < 3200 or peak < 100:
		pcm.clear()
		failed.emit("No speech heard. Check microphone permission and try again.")
		return
	var wav := snapshot_wav()
	pcm.clear()
	recorded.emit(wav)

func snapshot_wav() -> PackedByteArray:
	var wav := PackedByteArray()
	wav.resize(44)
	for i in 4: wav[i] = "RIFF".to_ascii_buffer()[i]
	wav.encode_u32(4, pcm.size() + 36)
	for i in 8: wav[8 + i] = "WAVEfmt ".to_ascii_buffer()[i]
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 1)
	wav.encode_u16(22, 1)
	wav.encode_u32(24, 16000)
	wav.encode_u32(28, 32000)
	wav.encode_u16(32, 2)
	wav.encode_u16(34, 16)
	for i in 4: wav[36 + i] = "data".to_ascii_buffer()[i]
	wav.encode_u32(40, pcm.size())
	wav.append_array(pcm)
	return wav

func _exit_tree() -> void:
	stop(false)
