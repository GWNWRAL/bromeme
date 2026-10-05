extends SceneTree

# 语法 + 合成自检：把四段音效各自写成 wav 到 D:/DSH/_aitato_work/sfx_out/，
# 并打印时长/采样数，方便外面用 python 检查波形。

const SCRIPTS := [
	"res://meme/meme_sfx.gd",
	"res://meme/meme_invasion.gd",
]

const IDS := ["whistle", "laugh", "salute", "siren"]
const OUT_DIR := "D:/DSH/_aitato_work/sfx_out"


func _write_wav(path: String, data: PoolByteArray, rate: int) -> void:
	var f := File.new()
	if f.open(path, File.WRITE) != OK:
		printerr("cannot write ", path)
		return
	var n: int = data.size()
	f.store_buffer("RIFF".to_ascii())
	f.store_32(36 + n)
	f.store_buffer("WAVEfmt ".to_ascii())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii())
	f.store_32(n)
	f.store_buffer(data)
	f.close()


func _init() -> void:
	var failures := 0
	for path in SCRIPTS:
		if load(path) == null:
			printerr("FAILED script: ", path)
			failures += 1
		else:
			print("OK script: ", path)

	var sfx = load("res://meme/meme_sfx.gd")
	if sfx == null:
		print("sfx script missing")
		quit(1)
		return
	var dir := Directory.new()
	if not dir.dir_exists(OUT_DIR):
		dir.make_dir_recursive(OUT_DIR)
	for id in IDS:
		var t0: int = OS.get_ticks_msec()
		var st = sfx.get_sound(id)
		var ms: int = OS.get_ticks_msec() - t0
		if st == null:
			printerr("FAILED sound: ", id)
			failures += 1
			continue
		var data: PoolByteArray = st.data
		var samples: int = data.size() / 2
		print("OK sound: %-8s %d samples  %.3fs  gen=%dms  peak_bytes=%d" % [
			id, samples, float(samples) / float(st.mix_rate), ms, data.size()])
		_write_wav(OUT_DIR + "/" + id + ".wav", data, st.mix_rate)
	# 缓存命中检查：第二次必须是同一份对象
	var a = sfx.get_sound("whistle")
	var b = sfx.get_sound("whistle")
	print("cache same: ", a == b)
	# 播放路径：真挂 AudioStreamPlayer（stub SoundManager 用不到，走自己的播放器）
	var holder := Node.new()
	get_root().add_child(holder)
	sfx.play("whistle", holder)
	sfx.play("laugh", holder)
	sfx.play("salute", holder)
	sfx.play("siren", holder)
	print("children after play: ", holder.get_child_count())
	for c in holder.get_children():
		print("   player bus=%s vol=%.1f pitch=%.3f pause=%d" % [c.bus, c.volume_db, c.pitch_scale, c.pause_mode])
	print("play() calls done")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
