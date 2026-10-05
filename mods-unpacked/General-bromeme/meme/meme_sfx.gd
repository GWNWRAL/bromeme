extends Reference

# =============================================================================
#  meme 入侵音效（纯代码合成，不依赖任何音频素材文件）
#
#  whistle 汽笛 / laugh 罐头笑声 / salute 礼炮 / siren 警笛
#
#  合成结果挂在原版 SoundManager 上缓存（同一进程只算一次，约 40ms/条）；
#  播放是自己挂 AudioStreamPlayer 走原版 Sound 总线，音高每次 ±随机。
#  音量/音高随机量/归一化增益都在下面的表里，想调直接改数。
# =============================================================================

const CACHE_KEY: String = "bromeme_sfx_cache"
const RATE: int = 22050

# 每种音效的相对音量（dB）；想大声一点就往 0 靠
const VOLUME: Dictionary = {
	"whistle": -5.0,
	"laugh": -4.0,
	"salute": -4.0,
	"siren": -8.0,
	"clap": -4.5,
}
# 每种音效的随机音高幅度（±比例）
const PITCH_RAND: Dictionary = {
	"whistle": 0.16,
	"laugh": 0.22,
	"salute": 0.16,
	"siren": 0.14,
	"clap": 0.18,
}
# 合成后统一拉到差不多的峰值（原始波形高低不一，先归一化再交给 VOLUME 调）
const GAIN: Dictionary = {
	"whistle": 1.66,
	"laugh": 2.07,
	"salute": 1.03,
	"siren": 2.72,
	"clap": 1.35,
}
# 副音效：主音效之外随机叠一声（多种汽笛/大笑/鼓掌，音高各自随机）
const ACCENT_CHANCE: float = 0.45
const ACCENTS: Array = ["clap", "laugh", "whistle", "siren"]


static func get_sound(id: String) -> AudioStreamSample:
	var cache: Dictionary = _cache()
	if cache.has(id):
		return cache[id]
	var stream := _synth(id)
	if stream != null:
		cache[id] = stream
		_store_cache(cache)
	return stream


# 缓存挂在原版 SoundManager 上（进程内一直存在），合成一次就够
static func _cache() -> Dictionary:
	var host = SoundManager
	if host == null:
		return {}
	if host.has_meta(CACHE_KEY):
		return host.get_meta(CACHE_KEY)
	return {}


static func _store_cache(cache: Dictionary) -> void:
	var host = SoundManager
	if host != null:
		host.set_meta(CACHE_KEY, cache)


# 播放一个音效：自己挂一个 AudioStreamPlayer（走原版 Sound 总线，音高单独随机），
# 不走 SoundManager 的播放池——音效池满了它会把请求丢掉。
static func play(id: String, parent: Node) -> void:
	_play_one(id, parent)
	# 再随机叠一声别的（鼓掌 / 大笑 / 汽笛 / 口哨），音高各自随机 → 每次都不太一样
	if randf() < ACCENT_CHANCE:
		var pool: Array = []
		for accent in ACCENTS:
			if String(accent) != id:
				pool.append(String(accent))
		if not pool.empty():
			_play_one(pool[randi() % pool.size()], parent)


static func _play_one(id: String, parent: Node) -> void:
	var stream := get_sound(id)
	if stream == null or parent == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Sound"
	p.stream = stream
	p.volume_db = float(VOLUME.get(id, -5.0))
	var pr: float = float(PITCH_RAND.get(id, 0.10))
	p.pitch_scale = 1.0 + rand_range(-pr, pr)
	p.pause_mode = Node.PAUSE_MODE_PROCESS
	parent.add_child(p)
	p.play()


static func _synth(id: String) -> AudioStreamSample:
	match id:
		"whistle":
			return _whistle()
		"laugh":
			return _laugh()
		"salute":
			return _salute()
		"siren":
			return _siren()
		"clap":
			return _clap()
	return null


# 鼓掌：一串短促的拍手脉冲（高频正弦 + 一点噪声），数量/间距/音高每次都不一样
static func _clap() -> AudioStreamSample:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var b := _blank(1.15)
	var claps: int = 6 + (rng.randi() % 4)
	var step: float = 0.10 + rng.randf_range(-0.02, 0.04)
	var f1: float = 1250.0 * (1.0 + rng.randf_range(-0.18, 0.18))
	var f2: float = 2150.0 * (1.0 + rng.randf_range(-0.18, 0.18))
	var length: int = int(0.038 * float(RATE))

	for c in claps:
		var start: int = int((0.03 + float(c) * step + rng.randf_range(-0.015, 0.015)) * float(RATE))
		for i in length:
			var idx: int = start + i
			if idx < 0 or idx >= b.size():
				continue
			var env: float = 1.0 - float(i) / float(length)
			env = env * env
			var t: float = float(i) / float(RATE)
			var v: float = (sin(TAU * f1 * t) * 0.6 + sin(TAU * f2 * t) * 0.4) * env
			v = v + rng.randf_range(-0.35, 0.35) * env
			b[idx] = b[idx] + v

	return _to_stream(b, float(GAIN.get("clap", 1.35)))


static func _blank(seconds: float) -> PoolRealArray:
	var b := PoolRealArray()
	b.resize(int(seconds * float(RATE)))
	return b


static func _to_stream(b: PoolRealArray, gain: float) -> AudioStreamSample:
	var sp := StreamPeerBuffer.new()
	sp.big_endian = false
	var n: int = b.size()
	for i in n:
		var v: float = b[i] * gain
		if v > 1.0:
			v = 1.0
		elif v < -1.0:
			v = -1.0
		sp.put_16(int(round(v * 32000.0)))
	var s := AudioStreamSample.new()
	s.format = AudioStreamSample.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = sp.data_array
	return s


# -----------------------------------------------------------------------------
#  汽笛：几个谐波叠在一起 + 一点气流噪声，1.05 秒
# -----------------------------------------------------------------------------
static func _whistle() -> AudioStreamSample:
	var n: int = int(1.05 * float(RATE))
	var b := _blank(1.05)
	var f0: float = 645.0
	var mult: Array = [1.0, 1.5, 2.0, 2.5, 3.0]
	var amp: Array = [1.0, 0.42, 0.26, 0.12, 0.07]
	var ph := PoolRealArray()
	ph.resize(mult.size())
	var det := PoolRealArray()
	det.resize(mult.size())
	for k in mult.size():
		ph[k] = 0.0
		det[k] = 1.0 + (float(k) - 2.0) * 0.0016
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		for k in mult.size():
			ph[k] += TAU * f0 * float(mult[k]) * det[k] / float(RATE)
			s += float(amp[k]) * sin(ph[k])
		var nz: float = rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.35
		s += lp * 0.07
		var env: float = 1.0
		if t < 0.07:
			env = t / 0.07
		elif t > 0.70:
			env = max(0.0, 1.0 - (t - 0.70) / 0.35)
		env *= 1.0 + 0.028 * sin(TAU * 5.4 * t)
		b[i] = s * env * 0.30
	return _to_stream(b, float(GAIN.get("whistle", 1.0)))


# -----------------------------------------------------------------------------
#  罐头笑声：一群人「哈哈哈」，前面留 0.13 秒空档好跟汽笛错开，总长 1.35 秒
# -----------------------------------------------------------------------------
static func _laugh() -> AudioStreamSample:
	var total: float = 1.35
	var n: int = int(total * float(RATE))
	var b := _blank(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		var nz: float = rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.12
		var swell: float = 0.0
		if t < 0.35:
			swell = t / 0.35
		else:
			swell = max(0.0, 1.0 - (t - 0.35) / 0.95)
		b[i] = lp * 0.5 * swell
	var t0: float = 0.13
	while t0 < 1.14:
		var dur: float = rng.randf_range(0.085, 0.16)
		var vf0: float = rng.randf_range(115.0, 215.0)
		var vf1: float = rng.randf_range(700.0, 900.0)
		var vf2: float = rng.randf_range(1080.0, 1320.0)
		var vam: float = rng.randf_range(0.55, 1.0)
		var start: int = int(t0 * float(RATE))
		var cnt: int = int(dur * float(RATE))
		var ph0: float = rng.randf() * TAU
		for j in cnt:
			var idx: int = start + j
			if idx >= n:
				break
			var u: float = float(j) / float(cnt)
			var e: float = sin(PI * u)
			e = e * e
			var tt: float = float(j) / float(RATE)
			var v: float = 0.45 * sin(TAU * vf0 * tt + ph0) + 0.62 * sin(TAU * vf1 * tt) + 0.30 * sin(TAU * vf2 * tt)
			b[idx] += v * e * vam * 0.30
		t0 += dur + rng.randf_range(0.015, 0.075)
	return _to_stream(b, float(GAIN.get("laugh", 1.0)))


# -----------------------------------------------------------------------------
#  礼炮：起爆脆声 + 低频炮身 + 闷响 + 余音，前面留 0.30 秒空档，总长 1.2 秒
# -----------------------------------------------------------------------------
static func _salute() -> AudioStreamSample:
	var total: float = 1.2
	var n: int = int(total * float(RATE))
	var b := _blank(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp: float = 0.0
	var prev: float = 0.0
	var lead: float = 0.30
	for i in n:
		var t: float = float(i) / float(RATE) - lead
		if t < 0.0:
			b[i] = 0.0
			prev = rng.randf() * 2.0 - 1.0
			continue
		var nz: float = rng.randf() * 2.0 - 1.0
		var hp: float = nz - prev
		prev = nz
		lp += (nz - lp) * 0.055
		var s: float = 0.0
		s += hp * exp(-t / 0.020) * 0.75
		s += lp * exp(-t / 0.30) * 1.5
		s += sin(TAU * 66.0 * t) * exp(-t / 0.17) * 0.75
		s += nz * exp(-t / 0.55) * 0.10
		b[i] = s * 0.42
	return _to_stream(b, float(GAIN.get("salute", 1.0)))


# -----------------------------------------------------------------------------
#  警笛：双音呜咽 + 轻度过载，1.5 秒
# -----------------------------------------------------------------------------
static func _siren() -> AudioStreamSample:
	var total: float = 1.5
	var n: int = int(total * float(RATE))
	var b := _blank(total)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		var cycle: float = fmod(t, 1.2) / 1.2
		var w: float = 0.5 - 0.5 * cos(TAU * cycle)
		var f: float = 470.0 + 640.0 * w
		ph += TAU * f / float(RATE)
		var s: float = sin(ph) + 0.38 * sin(2.0 * ph) + 0.16 * sin(3.0 * ph)
		s = tanh(s * 1.7) * 0.75
		var env: float = 1.0
		if t < 0.08:
			env = t / 0.08
		elif t > 1.20:
			env = max(0.0, 1.0 - (t - 1.20) / 0.30)
		env *= 1.0 + 0.05 * sin(TAU * 6.5 * t)
		b[i] = s * env * 0.42
	return _to_stream(b, float(GAIN.get("siren", 1.0)))
