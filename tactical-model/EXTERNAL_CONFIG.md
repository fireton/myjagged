# External formula config

When running from the Godot editor, the lab uses the internal project config:

```text
res://config/formula_config.yaml
```

Exported builds first look for this file next to the executable or, on macOS, next to the `.app` bundle:

```text
formula_config.yaml
```

If the external file exists, the exported lab uses it and hot-reloads it while running.

If the external file does not exist, the lab falls back to the internal project default:

```text
res://config/formula_config.yaml
```

For Windows export, put `formula_config.yaml` next to `tactical-lab.exe`.

For macOS export, put `formula_config.yaml` next to the `.app` bundle:

```text
tactical-lab-macos/
  tactical-lab.app
  tactical-lab.command
  formula_config.yaml
```

After exporting, copy the current config to both release folders with:

```sh
godot --headless --path tactical-model --script res://scripts/copy_external_config.gd
```
