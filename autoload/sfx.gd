extends Node

# ==============================================================================
# SFX (Autoload)
#
# Semua suara dibuat langsung lewat kode (tanpa file audio), sama seperti
# suara menu di MenuUI. Hasilnya disimpan sebagai AudioStreamWAV lalu
# dimainkan lewat beberapa AudioStreamPlayer supaya bisa tumpang-tindih.
#
# Volume mengikuti GameConfig.sfx_volume dan ikut bisu saat GameConfig.muted.
# ==============================================================================

const MIX_RATE: int = 22050
const JUMLAH_PEMAIN: int = 8

# Tiap suara = daftar nada. Tiap nada: f = frekuensi (Hz),
# t = waktu mulai (detik), d = durasi (detik), v = kekuatan (0..1).
const DAFTAR_SUARA := {
	"move": {
		"durasi": 0.075,
		"jenis": "sine",
		"notes": [{"f": 466.16, "d": 0.05, "v": 0.55}]
	},
	"push": {
		"durasi": 0.13,
		"jenis": "sine",
		"notes": [
			{"f": 174.61, "d": 0.09, "v": 0.9},
			{"f": 261.63, "d": 0.08, "t": 0.02, "v": 0.45}
		]
	},
	"blocked": {
		"durasi": 0.075,
		"jenis": "square",
		"notes": [{"f": 110.0, "d": 0.06, "v": 0.45}]
	},
	"enter": {
		"durasi": 0.30,
		"jenis": "sine",
		"notes": [
			{"f": 523.25, "d": 0.11, "v": 0.7},
			{"f": 659.25, "d": 0.11, "t": 0.07, "v": 0.7},
			{"f": 783.99, "d": 0.16, "t": 0.14, "v": 0.75}
		]
	},
	"exit": {
		"durasi": 0.32,
		"jenis": "sine",
		"notes": [
			{"f": 783.99, "d": 0.11, "v": 0.7},
			{"f": 587.33, "d": 0.11, "t": 0.07, "v": 0.7},
			{"f": 392.0, "d": 0.17, "t": 0.14, "v": 0.75}
		]
	},
	"undo": {
		"durasi": 0.17,
		"jenis": "sine",
		"notes": [
			{"f": 440.0, "d": 0.07, "v": 0.6},
			{"f": 329.63, "d": 0.10, "t": 0.05, "v": 0.6}
		]
	},
	"reset": {
		"durasi": 0.24,
		"jenis": "sine",
		"notes": [
			{"f": 392.0, "d": 0.09, "v": 0.7},
			{"f": 261.63, "d": 0.14, "t": 0.06, "v": 0.7}
		]
	},
	"win": {
		"durasi": 0.72,
		"jenis": "sine",
		"notes": [
			{"f": 523.25, "d": 0.18, "v": 0.7},
			{"f": 659.25, "d": 0.18, "t": 0.11, "v": 0.7},
			{"f": 783.99, "d": 0.18, "t": 0.22, "v": 0.75},
			{"f": 1046.5, "d": 0.34, "t": 0.33, "v": 0.8}
		]
	}
}

var _suara: Dictionary = {}
var _pemain: Array[AudioStreamPlayer] = []
var _berikut: int = 0

func _ready() -> void:
	for nama in DAFTAR_SUARA.keys():
		_suara[nama] = _buat_nada(DAFTAR_SUARA[nama])

	for i in range(JUMLAH_PEMAIN):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pemain.append(p)

# ------------------------------------------------------------------ pemutaran
func play(nama: String) -> void:
	if GameConfig.muted or GameConfig.sfx_volume <= 0.0:
		return
	if not _suara.has(nama) or _pemain.is_empty():
		return

	var p: AudioStreamPlayer = _pemain[_berikut]
	_berikut = (_berikut + 1) % _pemain.size()
	p.stream = _suara[nama]
	p.volume_db = linear_to_db(clampf(GameConfig.sfx_volume, 0.001, 1.0))
	# Variasi kecil supaya langkah berulang tidak terdengar monoton.
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()

# ------------------------------------------------------------------ pembuat nada
func _buat_nada(def: Dictionary) -> AudioStreamWAV:
	var total: int = int(MIX_RATE * float(def.get("durasi", 0.1)))
	var jenis: String = def.get("jenis", "sine")
	var data := PackedByteArray()
	data.resize(total * 2)

	for i in range(total):
		var t: float = float(i) / float(MIX_RATE)
		var sampel: float = 0.0

		for n in def["notes"]:
			var mulai: float = float(n.get("t", 0.0))
			var durasi: float = float(n.get("d", 0.08))
			if t < mulai or t > mulai + durasi:
				continue
			var lt: float = t - mulai
			var p: float = lt / durasi
			var env: float = pow(1.0 - p, 2.0)   # memudar seperti "pluck"
			var f: float = float(n["f"])
			var v: float = float(n.get("v", 1.0))
			if jenis == "square":
				sampel += signf(sin(TAU * f * lt)) * env * v
			else:
				sampel += sin(TAU * f * lt) * env * v

		sampel = clampf(sampel * 0.45, -1.0, 1.0)
		data.encode_s16(i * 2, int(sampel * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
