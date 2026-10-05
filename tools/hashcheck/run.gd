extends SceneTree

# Same djb2 variant Brotato's Keys.generate_hash uses.
func generate_hash(value: String) -> int:
	var h := 5381
	for i in value.length():
		h = ((h << 5) + h) + value.ord_at(i)
		h = h & 0x7FFFFFFF
	return h

func _init() -> void:
	var ids := [
		"character_aitato_deepseek",
		"character_capybara",
		"character_well_rounded",
		"character_baby",
	]
	var path := OS.get_environment("APPDATA") + "/Brotato/76561198978820132/save_v3_1.json"
	var f := File.new()
	var unlocked := ""
	if f.open(path, File.READ) == OK:
		var txt := f.get_as_text()
		f.close()
		var re := RegEx.new()
		re.compile("\"characters_unlocked\"\\s*:\\s*\\[([^\\]]*)\\]")
		var m := re.search(txt)
		if m:
			unlocked = m.get_string(1)
	for id in ids:
		var h := generate_hash(id)
		var present := false
		if unlocked != "":
			present = ("[" + unlocked + "]").find("[%d" % h) != -1 or unlocked.find("%d" % h) != -1
		print("%-28s hash=%-12d inSave=%s" % [id, h, present])
	print("unlocked list length: %d" % unlocked.length())
	quit(0)
