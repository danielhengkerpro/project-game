extends Node

# Musik latar prosedural orisinal. Tidak memakai aset berhak cipta.
const MIX_RATE: int = 22050
const DURASI: float = 16.0

var _pemain: AudioStreamPlayer
var _musik: AudioStreamWAV

func _ready() -> void:
	_pemain = AudioStreamPlayer.new()
	_pemain.bus = "Master"
	add_child(_pemain)
	_musik = _buat_musik()
	_pemain.stream = _musik
	GameConfig.settings_changed.connect(_terapkan)
	_terapkan()

func _terapkan() -> void:
	if GameConfig.music_muted or GameConfig.music_volume <= 0.0:
		_pemain.stop()
		return
	_pemain.volume_db = linear_to_db(clampf(GameConfig.music_volume, 0.001, 1.0))
	if not _pemain.playing:
		_pemain.play()

func _buat_musik() -> AudioStreamWAV:
	var total := int(MIX_RATE * DURASI)
	var data := PackedByteArray()
	data.resize(total * 2)
	var nada := [110.0, 130.81, 146.83, 164.81, 196.0, 220.0]
	for i in range(total):
		var t := float(i) / MIX_RATE
		var langkah := int(t * 2.0) % nada.size()
		var f: float = nada[langkah]
		var pulse := 0.5 + 0.5 * sin(TAU * 0.125 * t)
		var sampel := sin(TAU * f * t) * 0.10
		sampel += sin(TAU * f * 2.0 * t) * 0.035
		sampel += sin(TAU * (f * 1.5) * t) * 0.018 * pulse
		sampel *= 0.72 + 0.28 * sin(TAU * 0.25 * t)
		data.encode_s16(i * 2, int(clampf(sampel, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	wav.data = data
	return wav
