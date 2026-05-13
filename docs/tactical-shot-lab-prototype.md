# Tactical Shot Lab Prototype

## Purpose

This prototype is a small Godot experiment for testing a more believable hit-resolution model for a tactical mercenary game inspired by *Jagged Alliance*.

The goal is not to build a full game yet, and not to commit to a grid-based tactical format yet. The goal is to build a laboratory where shooting can be tested, tuned, and explained.

Core idea:

> Mercenaries should not make absurd close-range misses. Low weapon skill should reduce hit quality, precision, reaction reliability, and performance against difficult targets, not turn a trained soldier into an incompetent clown.

## Main Design Principle

Traditional tactical games often use a single abstract hit chance:

```text
hit / miss
```

This can lead to situations where a trained mercenary misses a stationary enemy from two meters away. That feels unfair because the visual situation contradicts the result.

This prototype should instead separate the shot into several stages:

```text
1. Hit probability
2. Hit / miss roll
3. Explanation of physical error sources
```

Body parts, damage, armor, and hit quality are intentionally postponed. The current lab should answer one question first: does the chance to hit feel physically believable?

## Lab Framing

This prototype should be treated as a shooting laboratory first.

The laboratory should answer questions like:

- Does the shot model feel fair at close range?
- Does low weapon skill feel worse without producing absurd misses?
- Does target movement create believable difficulty?
- Are the random results explainable after the shot?
- Is a grid actually useful for this game, or is a free-position tactical space better?

Do not design the first prototype around movement rules, turns, action points, pathfinding, or cover geometry. Those systems can be tested later after the shot model has proven itself.

The visual space can be:

- A free 2D test range with continuous positions.
- A simple measurement ruler or distance ring overlay.
- An optional grid overlay for readability only.

The first version should avoid making grid cells part of the shot math. Distance should be measured in meters from world positions.

Long-term direction:

- The actual game is expected to be 3D.
- Distance should eventually come from a direct physics raycast or shape query between shooter and target.
- The shot model should already be written as if it receives measured 3D shot data, even if the first lab visualizes that data in 2D.
- The 2D lab is a fast way to tune formulas, not a commitment to a 2D game.

## Prototype Scope

This is a laboratory scene, not a full tactical game.

### Included

- Small 2D top-down test range.
- One shooter.
- One target.
- Selectable weapon from YAML.
- Selectable target profile from YAML.
- Adjustable shooter weapon skill.
- Adjustable aim AP spent before firing.
- Free draggable shooter placement.
- Free draggable target placement.
- Zoomable test range.
- Adjustable target movement state.
- Adjustable target movement direction.
- Distance-based shot resolution.
- Weapon mechanical accuracy, handling, and sight alignment parameters.
- Target hit radius parameters.
- Formula settings loaded from YAML.
- Runtime formula reload after YAML changes.
- Detailed shot result log.
- Batch simulation button for statistical testing.
- Optional visual grid or ruler overlay.

### Not Included

- No campaign map.
- No inventory.
- No squad management.
- No AI.
- No enemy turns.
- No pathfinding.
- No fog of war.
- No mandatory grid movement.
- No complex animations.
- No full combat loop.
- No economy.
- No weapon-specific firing modes yet.

## Scene

Suggested scene name:

```text
TacticalShotLab.tscn
```

Suggested node structure:

```text
TacticalShotLab
├── RangeView
│   ├── OptionalGridOverlay
│   ├── DistanceRings
│   └── ShotLine
├── Shooter
├── Target
└── UI
    ├── PistolSkillSlider
    ├── WeaponOption
    ├── TargetOption
    ├── TargetMovementStateOption
    ├── TargetMovementDirectionOption
    ├── FireButton
    ├── SimulateButton
    ├── CurrentShotInfoPanel
    └── ResultLog
```

The scene should be visually simple.

Use a top-down view:

- Shooter as a simple circle or placeholder sprite.
- Target as a simple circle or placeholder sprite.
- A clean test range area with enough space to compare distances.
- Optional grid, ruler, or distance rings as measurement aids.
- Optional line from shooter to target when firing.
- UI panel on the side.

The scene should not imply final tactical movement rules. If a grid is shown, it should be visibly a laboratory overlay, not the core game board.

The shooter and target should be draggable directly on the field. Mouse wheel zoom should scale the field so long-range pistol shots and future obstacle layouts can be inspected comfortably.

## Controls

The prototype should allow the user to change the situation before firing.

### Shooter Controls

```text
Weapon Skill: 0..100
```

Interpretation:

```text
0   = minimally trained mercenary
50  = competent professional
100 = elite pistol specialist
```

Important: skill 0 does not mean "civilian who has never held a gun". It means the lower end of a professional mercenary baseline.

### Target Movement State

```text
Standing
Walking
Running
Sprinting
```

### Target Movement Direction

```text
Toward shooter
Away from shooter
Sideways
Zigzag
```

Sideways and zigzag movement should be harder to hit because they require tracking and lead compensation.

### Range Interaction

The prototype should let the user control shooter and target placement without requiring tactical movement.

Minimum controls:

```text
Drag shooter
Drag target
Mouse wheel zoom
Optional pan
```

Distance should be derived from the shooter and target world positions. The UI can display distance and bearing, but those values should not be manually authoritative.

### Actions

```text
Fire
Simulate 100 shots
```

`Fire` resolves one shot and prints a detailed result.

`Simulate 100 shots` runs the same shot conditions 100 times and prints aggregated statistics.

## Shot Result Model

A shot should not be resolved as a single binary roll.

Use this flow:

```text
Shot input:
- Shooter
- Target
- Weapon
- Distance
- Target angle
- Target movement
- Target direction
- Optional situational modifiers

Shot output:
- Hit chance
- Hit roll
- Hit or miss result
- Angular error budget
- Explanation modifiers
```

## Shot Resolution Stages

### 1. Hit Probability

Hit probability is based on an angular error budget.

The model should avoid abstract bonuses like `baseContact`. Instead, it should use physically interpretable inputs:

- Shooter aim error in milliradians.
- Weapon mechanical accuracy in milliradians.
- Weapon handling error in milliradians.
- Sight/range error in milliradians.
- Movement tracking error in milliradians.
- Target hit radius in meters.
- Distance in meters.

The core idea:

```text
totalAngularErrorMrad = sqrt(sum(errorSourceMrad^2))
missSigmaMeters = distanceMeters * totalAngularErrorMrad / 1000
hitChance = probability that 2D aim error lands inside targetHitRadius
```

This means distance matters naturally: the same angular error creates a small miss at 2 meters and a large miss at 20 meters.

Target size is equally important. A small target at 20 meters may be difficult, while an elephant-sized target at 100 meters can still be easy because it occupies a much larger angular size.

Targets should be listed in `res://config/formula_config.yaml` under `targets`:

```yaml
default_target: human

targets:
  human:
    name: Human target
    hit_radius_m: 0.30
  elephant:
    name: Elephant-sized target
    hit_radius_m: 1.50
```

### 2. Weapon Parameters

Weapons should be listed in `res://config/formula_config.yaml` under `weapons`.

Suggested format:

```yaml
default_weapon: basic_pistol

weapons:
  basic_pistol:
    name: Basic pistol
    mechanical_accuracy_mrad: 6.0
    handling: 0.80
    handling_error_max_mrad: 10.0
    aim_handling_gain_per_ap: 0.015
    aim_skill_scaling: 0.30
    sight_alignment_error_mrad: 4.0
```

The UI should expose a weapon dropdown using the weapon `name`, while the internal selection uses the stable YAML key such as `basic_pistol`.

Suggested pistol parameters:

```text
mechanicalAccuracyMrad = 6.0
handling = 0.80
handlingErrorMaxMrad = 10.0
aimHandlingGainPerAp = 0.015
aimSkillScaling = 0.30
sightAlignmentErrorMrad = 4.0
```

Interpretation:

- `mechanicalAccuracyMrad`: intrinsic weapon/ammo dispersion.
- `handling`: how much extra angular error the weapon adds when firing quickly or with minimal aim time.
- `handlingErrorMaxMrad`: maximum handling-induced angular error for a weapon with `handling = 0`.
- `aimHandlingGainPerAp`: how much each spent aim AP improves effective handling.
- `aimSkillScaling`: how strongly shooter skill increases the value of spent aim AP.
- `sightAlignmentErrorMrad`: angular error from aligning the sights. This is still an angular error, so distance already magnifies it through geometry.

Effective handling:

```text
effectiveHandling =
    clamp(
        weapon.handling
      + aimAP * weapon.aimHandlingGainPerAp * (1 + skillFactor * weapon.aimSkillScaling),
        0,
        1
    )
```

This makes pistols strong for quick shots because their base handling is high, while carbines benefit more from deliberate aiming because their aim gain can be higher.

There should be no weapon parameter that adds error simply because distance increased. If a value is already angular, distance affects it through:

```text
missSigmaMeters = distanceMeters * totalAngularErrorMrad / 1000
```

### 3. Shooter Parameters

Suggested shooter parameters:

```text
minAimErrorMrad = 2.0
maxAimErrorMrad = 18.0
movementTrackingCompensation = 0.75
```

Skill interpolates between `maxAimErrorMrad` and `minAimErrorMrad`. Low skill means larger aim error, not a magical inability to shoot.

## Movement Difficulty

Movement is one of the key reasons why low weapon skill can produce believable misses.

A low-skill mercenary should not often miss a standing enemy at two meters. But he may struggle against a running or zigzagging target, especially moving sideways.

Suggested base movement penalties:

```text
Standing:  0
Walking:   10
Running:   25
Sprinting: 40
```

Suggested direction modifiers:

```text
Toward shooter: 0.50
Away from shooter: 0.75
Sideways: 1.25
Zigzag: 1.60
```

Suggested calculation:

```text
movementDifficulty = movementStatePenalty * directionModifier
```

Shooter skill should reduce movement difficulty:

```text
skillCompensation = pistolSkill * 0.5
effectiveMovementDifficulty = max(0, movementDifficulty - skillCompensation)
```

This means experienced shooters are much better at tracking moving targets, but movement remains meaningful.

## Distance Difficulty

Distance should affect both contact and quality.

Suggested distance bands:

```text
PointBlank: 0-3 meters
Short:      3-8 meters
Medium:     8-15 meters
Long:       15-25 meters
Extreme:    25+ meters
```

Suggested distance difficulty:

```text
PointBlank: 0
Short:      12
Medium:     30
Long:       50
Extreme:    80
```

For the first prototype, use direct world-space distance. In the temporary 2D lab, the visual scale can be:

```text
100 pixels = 1 meter
```

If a grid overlay is enabled, it should use the same scale for readability:

```text
1 visual grid square = 100 pixels = 1 meter
```

The grid must not be required by the resolver. `ShotResolver` should only need shot geometry, measured distance, weapon data, and modifiers.

For future 3D compatibility, treat distance as a measured shot input:

```text
shotOrigin = shooter muzzle or eye position
targetPoint = chosen target body point
raycastDistance = distance from shotOrigin to first relevant hit
intendedTargetDistance = distance from shotOrigin to targetPoint
lineOfFireBlocked = raycast hit something before the intended target
```

In the first 2D prototype, these values can be approximated from `Vector2` positions. In the future 3D version, they should come from Godot physics queries such as raycasts.

The important rule is that the hit resolver should not decide how distance is measured. It should receive distance and line-of-fire information from the scene or physics layer.

## Formula Draft

This is intentionally simple and tunable.

Formula constants should live outside the resolver in:

```text
res://config/formula_config.yaml
```

The lab should watch this file while running. When the YAML file changes, the next `Fire` or `Simulate 100` action should use the new values without restarting the game.

For the first implementation, YAML support can be intentionally narrow:

- Nested sections by indentation.
- String, int, float, and bool scalar values.
- No arrays required.
- No advanced YAML features.

This keeps tuning fast while avoiding a dependency on a full YAML parser.

### Hit Chance

```text
shooterErrorMrad = lerp(maxAimErrorMrad, minAimErrorMrad, skill / 100)
mechanicalErrorMrad = weapon.mechanicalAccuracyMrad
effectiveHandling = weapon.handling + aimAP * weapon.aimHandlingGainPerAp * (1 + skillFactor * weapon.aimSkillScaling)
handlingErrorMrad = (1 - effectiveHandling) * weapon.handlingErrorMaxMrad
sightAlignmentErrorMrad = weapon.sightAlignmentErrorMrad
movementErrorMrad = targetSpeedMps * directionModifier * trackingErrorMradPerMps

totalAngularErrorMrad = sqrt(
    shooterErrorMrad^2
  + mechanicalErrorMrad^2
  + handlingErrorMrad^2
  + sightAlignmentErrorMrad^2
  + movementErrorMrad^2
)

missSigmaMeters = distanceMeters * totalAngularErrorMrad / 1000
hitChance = 1 - exp(-0.5 * (targetHitRadiusMeters / missSigmaMeters)^2)
```

Clamp the final percentage to the configured minimum and maximum.

## Data Structures

Use GDScript resources or plain scripts.

Suggested types:

```text
Mercenary
- pistolSkill: int
- stress: int
- woundPenalty: int

Target
- position: Vector2 for the 2D lab, Vector3 in the future 3D game
- distanceFromShooter: float
- angleFromShooter: float
- hitRadiusMeters: float
- movementState: TargetMovementState
- movementDirection: TargetMovementDirection

ShotGeometry
- shotOrigin: Vector2 or Vector3
- targetPoint: Vector2 or Vector3
- intendedTargetDistance: float
- raycastDistance: float
- lineOfFireBlocked: bool

Weapon
- id: String
- name: String
- mechanicalAccuracyMrad: float
- handling: float
- handlingErrorMaxMrad: float
- sightAlignmentErrorMrad: float

ShotResult
- hit: bool
- distance: float
- lineOfFireBlocked: bool
- hitChance: int
- hitRoll: int
- totalAngularErrorMrad: float
- missSigmaMeters: float
- modifiers: Array[ShotModifier]

ShotModifier
- name: String
- value: int
- description: String
```

All UI labels and internal strings can be in English for the prototype.

## Result Log

After one shot, print something like:

```text
Shot result
Distance: 2.1 m
Target angle: Front
Weapon skill: 35
Target movement: Running
Target direction: Sideways

Hit chance: 72%
Hit roll: 61
Hit: Yes

Target hit radius: 0.30 m
Expected miss sigma: 0.25 m
Total angular error: 12.0 mrad

Angular error budget:
Shooter aim error: 12.4 mrad
Weapon mechanical error: 6.0 mrad
Weapon handling error: 1.5 mrad
Sight alignment error: 4.0 mrad
Movement tracking error: 7.2 mrad

Explanation:
The shot hit because the sampled roll was within the calculated hit chance.
```

After 100 simulated shots, print aggregated statistics:

```text
Simulation: 100 shots
Distance: 2.1 m
Target angle: Front
Weapon skill: 35
Target movement: Running
Target direction: Sideways

Hit:  72%
Miss: 28%

Average calculated hit chance: 71.5%
```

## Acceptance Criteria

The first prototype is successful when:

1. A stationary target at close range is almost never missed.
2. Low weapon skill still feels worse through larger angular error and lower hit chance.
3. Moving targets are meaningfully harder to hit.
4. Sideways and zigzag movement are harder than movement toward the shooter.
5. The shot log clearly explains why a result happened.
6. The simulation button makes it easy to tune the model.
7. The system is easy to modify without touching UI code.
8. The shot model works without depending on grid cells.
9. The prototype helps decide whether a future grid-based tactical layer is worth building.
10. `ShotResolver` accepts measured shot geometry instead of calculating distance from UI state directly.

## Suggested Implementation Order

### Step 1: Static scene

Create the test range, shooter, target, optional measurement overlay, and UI controls.

### Step 2: Distance calculation

Show current distance between shooter and target using world-space positions. The shooter and target should be draggable on the range.

### Step 3: Single shot resolver

Implement `ShotResolver` with hit chance, hit roll, and angular error budget. It should receive `ShotGeometry` as input so the same resolver can later be driven by a 3D raycast.

### Step 4: Result log

Print detailed shot result and modifiers.

### Step 5: Movement controls

Add target movement state and direction modifiers.

### Step 6: Range controls

Add mouse wheel zoom and optional pan. The resolver should receive updated measured distance after every placement change.

### Step 7: Batch simulation

Add `Simulate 100 shots` and print aggregated statistics.

### Step 8: Tuning pass

Adjust values until close-range shooting feels fair and movement-based difficulty feels believable.

### Step 9: Grid decision

After the resolver feels good, decide whether the next prototype should use:

- Grid-based tactical movement.
- Free-position real-time-with-pause movement.
- Hybrid free movement with tactical measurement overlays.

## Out of Scope for Now

Do not implement these until the shot model feels good:

- Cover system.
- Multiple weapons.
- Burst fire.
- Reaction fire.
- Suppression.
- Morale.
- Wounds.
- Inventory.
- AI.
- Turn order.
- Grid movement rules.
- Full tactical combat.

## Future Extensions

After the shooting model feels good, possible next prototypes:

### Prototype 2: Tactical Movement

- Action points.
- Movement format decision: grid-based, free-position, or hybrid.
- Basic line of sight.
- Basic cover.

### Prototype 3: Small Combat Encounter

- Two mercenaries.
- Two enemies.
- Simple turn order.
- Very simple enemy AI.

### Prototype 3D: Raycast Shooting Range

- 3D range scene.
- Shooter muzzle or eye transform.
- Target body collision shapes.
- Direct raycast-based distance measurement.
- Line-of-fire blocking checks.
- Same `ShotResolver` as the 2D lab.

### Prototype 4: Combat Pressure

- Wounds.
- Stress.
- Suppression.
- Reaction fire.

### Prototype 5: Weapon Differences

- Pistols.
- Rifles.
- Shotguns.
- SMGs.
- Weapon range profiles.
- Recoil.
- Burst fire.

## Design Summary

The prototype should test one specific idea:

> A trained mercenary should almost always connect at close range, but low skill should make the hit less effective, especially against moving or difficult targets.

The main value of the prototype is not visuals or game completeness. The main value is a transparent, tunable, and believable shot-resolution model.
