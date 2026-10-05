extends Node

const AUTHORNAME_MODNAME_DIR := "Yoko-DebugMenu"
const AUTHORNAME_MODNAME_LOG_NAME := "Yoko-DebugMenu:Main"

var mod_dir_path := ""
var extensions_dir_path := ""

func _init() -> void:
	ModLoaderLog.info("Init", AUTHORNAME_MODNAME_LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(AUTHORNAME_MODNAME_DIR)

	install_script_extensions()

func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.plus_file("extensions")

	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("debug_service.gd"))
