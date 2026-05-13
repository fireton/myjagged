class_name FormulaConfigLoader
extends RefCounted

const YAMLParserScript := preload("res://scripts/YamlClass.gd")


static func load_config(path: String, fallback: Dictionary) -> Dictionary:
	var loaded: Dictionary = YAMLParserScript.load_yaml_file(path)
	if loaded.is_empty():
		return fallback.duplicate(true)

	var merged := fallback.duplicate(true)
	_deep_merge(merged, loaded)
	return merged


static func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.has(key) and target[key] is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
