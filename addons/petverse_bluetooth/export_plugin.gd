@tool
extends EditorPlugin

var export_plugin: BluetoothExport

func _enter_tree() -> void:
	export_plugin = BluetoothExport.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)

class BluetoothExport extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_name() -> String:
		return "PetVerseBluetooth"

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/petverse_bluetooth/bin/PetVerseBluetooth.aar"])
