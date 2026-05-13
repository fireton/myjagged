# Tactical Shot Lab

Godot laboratory for tuning a physically readable hit-chance model for a tactical mercenary game.

The current prototype is not a full game. It is a test range for experimenting with weapon skill, weapon handling, aim AP, target size, movement, distance, and hit probability.

## Project Layout

```text
docs/                         Design notes and prototype documentation
tactical-model/               Godot project
tactical-model/config/        Default formula config bundled with the project
tactical-model/scripts/       GDScript source
tactical-model/tests/         Lightweight headless tests
release/                      Local exported builds, ignored by git
```

## Running

Open the Godot project:

```text
tactical-model/project.godot
```

Or run from the command line:

```sh
godot --path tactical-model
```

## Formula Tuning

The default formula config lives at:

```text
tactical-model/config/formula_config.yaml
```

Exported builds can use an external config file named:

```text
formula_config.yaml
```

Place it next to the executable or, on macOS, next to the `.app` bundle:

```text
tactical-lab-macos/
  tactical-lab.app
  tactical-lab.command
  formula_config.yaml
```

The app watches the active config file and reloads it while running.

After exporting, copy the current config to release folders with:

```sh
godot --headless --path tactical-model --script res://scripts/copy_external_config.gd
```

More details: [tactical-model/EXTERNAL_CONFIG.md](tactical-model/EXTERNAL_CONFIG.md)

## Tests

Run lightweight GDScript tests:

```sh
godot --headless --path tactical-model --script res://tests/test_runner.gd
```

The tests cover YAML parsing, weapon/target config loading, aim AP behavior, distance behavior, and basic hit-chance relationships.

## Export Notes

Exports are local artifacts and should not be committed:

```text
release/
```

The repository intentionally keeps the internal default config in `tactical-model/config/`, while local external tuning copies are ignored.
