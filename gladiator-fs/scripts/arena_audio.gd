extends Node
## Original synthesized placeholder cues. Replace individual cues with recordings later.
var streams = {}
var voices = []
var voice_index = 0
var ambience: AudioStreamPlayer

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(0.65))
	for i in range(10):
		var player = AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	for cue in ["hit", "block", "throw", "horn", "crowd", "taunt", "pickup", "death"]:
		streams[cue] = synthesize(cue)

func synthesize(cue: String) -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.18
	if cue in ["horn", "crowd", "death"]:
		duration = 1.3 if cue != "death" else 0.45
	var bytes = PackedByteArray()
	bytes.resize(int(sample_rate * duration) * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = cue.hash()
	var filtered = 0.0
	for i in range(int(sample_rate * duration)):
		var t = float(i) / sample_rate
		var fade = pow(1.0 - t / duration, 2)
		var noise = rng.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, 0.09)
		var sample = 0.0
		match cue:
			"hit": sample = (noise * 0.3 + sin(t * (130 - t * 190) * TAU) * 0.7) * fade
			"block": sample = (sin(t * 830 * TAU) + sin(t * 1267 * TAU) * 0.5 + noise * 0.25) * fade * 0.45
			"throw": sample = filtered * sin(t / duration * PI) * 2
			"horn": sample = (sin(t * 146.83 * TAU) + sin(t * 220 * TAU) * 0.5 + sin(t * 440 * TAU) * 0.15) * minf(t * 8, 1) * fade * 0.35
			"crowd": sample = filtered * (0.8 + sin(t * 9) * 0.25) * sin(t / duration * PI)
			"taunt": sample = sin(t * (340 + sin(t * 26) * 60) * TAU) * fade * 0.2
			"pickup": sample = sin(t * (650 + t * 1900) * TAU) * fade * 0.22
			"death": sample = (sin(t * (100 - t * 150) * TAU) * 0.5 + filtered) * fade
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 18000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream

func play(cue: String) -> void:
	if not streams.has(cue):
		return
	var voice = voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = streams[cue]
	voice.pitch_scale = randf_range(0.95, 1.05) if cue != "horn" else 1.0
	voice.volume_db = -5 if cue == "crowd" else -1
	voice.play()

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()
	streams.clear()
