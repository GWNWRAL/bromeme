extends Node

# Aitato - PLAIN TEST BUILD: character with no effects and no script extensions.

const MOD_NAME := "Aitato"
const MOD_DIR := "Aitato-Aitato/"
const LOG_NAME := "Aitato"
const CONTENT_DATA_PATH := "content_data/aitato_content_data.tres"

var dir := ""
var _done := false


func _init() -> void:
	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR


func _ready() -> void:
	if _done:
		return
	_done = true

	var path: String = dir + CONTENT_DATA_PATH
	if not ResourceLoader.exists(path):
		ModLoaderLog.error("Missing content data: %s" % path, LOG_NAME)
		return

	var loader = get_tree().root.get_node_or_null("ModLoader/Darkly77-ContentLoader/ContentLoader")
	if loader != null and loader.has_method("load_data"):
		loader.load_data(path, MOD_NAME)
		ModLoaderLog.info("Plain test content registered", LOG_NAME)
	else:
		ModLoaderLog.warn("ContentLoader not found; character not registered", LOG_NAME)
