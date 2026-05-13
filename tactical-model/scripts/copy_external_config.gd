extends SceneTree

const SOURCE := "res://config/formula_config.yaml"

var _failed := false


func _initialize() -> void:
	var destinations := [
		"../release/tactical-lab-win/formula_config.yaml",
		"../release/tactical-lab-macos/formula_config.yaml",
	]

	for destination in destinations:
		_copy_config(destination)

	quit(1 if _failed else 0)


func _copy_config(destination: String) -> void:
	var source_path := ProjectSettings.globalize_path(SOURCE)
	var destination_path := ProjectSettings.globalize_path(destination)
	var destination_dir := destination_path.get_base_dir()

	if not DirAccess.dir_exists_absolute(destination_dir):
		print("Skipping missing export folder: %s" % destination_dir)
		return

	var error := DirAccess.copy_absolute(source_path, destination_path)
	if error != OK:
		_failed = true
		push_error("Failed to copy %s to %s. Error: %d" % [source_path, destination_path, error])
	else:
		print("Copied external config: %s" % destination_path)
