# PistenBully 600 RC Control System

Custom EdgeTX Lua mixer scripts and radio configuration for a scale RC PistenBully 600 snowcat.

The project provides coordinated control of the tracks, front blade, rear tiller, finishers, and tiller rotor while reproducing several behaviors of the full-size PistenBully.

The control system is designed for a RadioMaster TX16S MK3 running EdgeTX.

---

## Overview

The PB600 uses three custom Lua mixer scripts:

| Script | Responsibility |
|---|---|
| `system.lua` | Track drive, hydrostatic drive behavior, safety interlocks, transition states, reverse behavior, and tiller motor control |
| `blade.lua` | Front blade actuator control, positioning, manual operation, and coordinated blade movement |
| `tiller.lua` | Rear tiller lift, angle, finishers, grooming position, and automatic reverse lift |

The scripts intentionally separate responsibilities:

- `system.lua` controls machine-level behavior and safety.
- `blade.lua` controls only blade hardware.
- `tiller.lua` controls only rear implement positioning.
- Lua outputs are reserved primarily for actual hardware control or important machine state.
- Frequently adjusted settings are exposed as EdgeTX Global Variables.
- Mechanical calibration and rarely changed tuning values remain constants in the Lua code.

---

# Operating Modes

The `SD` three-position switch selects the primary operating mode.

| SD Position | Mode | Behavior |
|---|---|---|
| Up | Transport | Blade and tiller move to transport positions |
| Middle | Plow | Blade moves to working position; tiller remains raised |
| Down | Groom | Blade is available for grooming and tiller lowers to its working position |

Each Lua script reads `SD` directly. No Lua output is consumed simply to communicate the current operating mode.

---

# Track Control

Track drive is generated entirely by `system.lua`.

The script accepts throttle and rudder inputs and generates independent left and right track outputs.

### Features

- Differential track steering
- Pivot/drive blending
- Nonlinear rudder response
- Reduced steering sensitivity at higher speeds
- Hydrostatic-style acceleration
- Hydrostatic-style deceleration/braking
- Increased braking when changing direction
- Reduced track power while implements are transitioning
- Automatic Groom reverse protection
- Emergency stop

Raw throttle and rudder mixes should **not** also be applied to the physical track channels.

Example:

```text
CH1 - Left Track
  100% LUA:System:TrackL

CH3 - Right Track
  100% LUA:System:TrackR
```

The Lua track outputs are the sole authority for the track ESCs.

---

# Hydrostatic Drive Simulation

The track control attempts to reproduce the heavy, progressive feel of the PB600 hydrostatic drivetrain rather than directly mapping stick position to ESC output.

The primary tuning constants are maintained in `system.lua`:

```lua
local TURN_GAIN     = 0.25
local SPEED_FACTOR  = 0.60

local ACCEL_RATE    = 60
local DECEL_RATE    = 180
local REVERSE_BOOST = 140
```

These values are intentionally stored in code rather than Global Variables because they represent machine calibration rather than normal operator adjustments.

### Acceleration

Track output builds progressively toward the commanded speed.

### Hydrostatic braking

Reducing throttle causes the tracks to decelerate more aggressively than they accelerate, simulating the braking effect of a hydrostatic drivetrain.

### Direction changes

Changing directly between forward and reverse applies additional braking while passing through zero.

### Steering

Steering response is nonlinear near stick center and progressively increases with rudder input.

Steering authority is also reduced as vehicle speed increases.

---

# Automatic Reverse / Tiller Lift

When operating in Groom mode, reverse is integrated with the rear tiller rather than simply being blocked.

The sequence is:

```text
Reverse requested
       |
       v
Tiller rotor disabled
       |
       v
Reverse track output blocked
       |
       v
Tiller raises by configured amount
       |
       v
Tiller reaches reverse clearance
       |
       v
Reverse track movement enabled
       |
       v
Snowcat backs with tiller raised
       |
       v
Reverse command released
       |
       v
Tiller returns to Groom position
       |
       v
Tiller rotor enabled
```

The reverse lift amount is controlled by `GV4`.

This replaces the earlier design in which reverse was completely prohibited in Groom unless the operator held the `SH` switch.

`SH` is therefore not required for normal reverse operation.

---

# Tiller Motor Safety

`system.lua` provides a dedicated `TillerMot` output.

```text
TillerMot = 100%  -> Rotor permitted
TillerMot =   0%  -> Rotor locked out
```

The tiller rotor is disabled during:

- Emergency stop
- Automatic reverse lift
- Reverse operation
- Return from reverse to Groom position
- Normal tiller transitions

The rotor is not permitted to restart until the tiller has completed its return to the normal Groom position.

The physical tiller motor channel should use the operator's normal speed command multiplied by `TillerMot`.

Conceptually:

```text
Tiller Motor Command = S1 × TillerMot
```

This allows `S1` to control tiller rotor speed while Lua retains final safety authority.

---

# Emergency Stop

`SF` is the machine emergency-stop switch.

E-stop is deliberately handled independently by each Lua script rather than relying on one script to communicate the stop condition to the others.

When E-stop is active:

### `system.lua`

- Left track output = 0
- Right track output = 0
- Tiller motor disabled

### `blade.lua`

- All blade actuator outputs stop

### `tiller.lua`

- All tiller actuator outputs stop

This provides a simple and redundant safety architecture.

---

# Blade Control

`blade.lua` directly controls all six blade functions.

| Lua Output | Function |
|---|---|
| `Lift` | Blade lift |
| `Tilt` | Blade tilt |
| `Angle` | Blade angle |
| `Slew` | Blade lateral slew |
| `LW` | Left wing |
| `RW` | Right wing |

All six available Lua mixer outputs are therefore dedicated to physical blade functions.

---

# Manual Blade Controls

The right stick changes function according to the `SC` switch.

| SC Position | Aileron | Elevator |
|---|---|---|
| Up | Blade Tilt | Blade Lift |
| Middle | Blade Slew | Blade Angle |
| Down | Tiller Angle | Tiller Lift |

Blade wings remain independently controlled by the left and right sliders.

---

# Blade Coordination

In Groom mode, rudder input can automatically coordinate blade movement with vehicle turns.

Coordinated functions include:

- Blade wings
- Blade slew
- Blade tilt
- Blade angle

The relative amount of movement for each blade axis is stored as constants in `blade.lua`.

For example:

```lua
local COORD_WING_RANGE  = 0.15
local COORD_SLEW_RANGE  = 0.12
local COORD_TILT_RANGE  = 0.08
local COORD_ANGLE_RANGE = 0.10
```

A single Global Variable controls overall coordination intensity.

This replaces the older design that used individual GVs for each coordinated blade axis.

The objective is to tune the relationship among the blade movements once in code and expose only overall coordination strength to the operator.

---

# Tiller Control

`tiller.lua` controls four rear implement functions.

| Lua Output | Function |
|---|---|
| `TAng` | Tiller angle |
| `TLift` | Tiller lift |
| `FinL` | Left finisher |
| `FinR` | Right finisher |

Two Lua output slots remain available for future functionality.

When entering Groom mode, the tiller automatically moves to the configured Groom position.

When leaving Groom, the tiller returns to its raised position.

---

# Tiller Coordination

When coordination is enabled in Groom mode, rudder input can automatically adjust tiller angle to follow the vehicle through a turn.

Overall coordination strength uses the same `GV1` master coordination setting used by the blade.

This keeps blade and tiller coordination synchronized through a single operator adjustment.

---

# Global Variables

Global Variables are reserved for settings that are useful to adjust live from the transmitter.

| GV | Setting | Purpose |
|---|---|---|
| GV1 | Coordination Intensity | Overall strength of automatic blade/tiller coordination |
| GV2 | Blade Working Depth | Blade operating height/depth |
| GV3 | Tiller Groom Depth | Normal tiller grooming height/depth |
| GV4 | Reverse Lift Height | Amount the tiller raises before reverse is permitted |
| GV5 | Tiller Working Angle | Normal tiller working angle |
| GV6-GV9 | Reserved | Available for future operator-adjustable settings |

Mechanical timing, actuator direction, steering characteristics, deadbands, and other machine calibration values are maintained directly in the Lua source.

---

# Lua Output Allocation

EdgeTX custom Lua mixer scripts are limited to six outputs per script.

The project deliberately manages those outputs as follows.

## `blade.lua`

```text
1  Lift
2  Tilt
3  Angle
4  Slew
5  LW
6  RW
```

**6 of 6 outputs used**

## `tiller.lua`

```text
1  TAng
2  TLift
3  FinL
4  FinR
5  Reserved
6  Reserved
```

**4 of 6 outputs used**

## `system.lua`

```text
1  TrackL
2  TrackR
3  TillerMot
4  BladeTr
5  TillerTr
6  Reserved
```

**5 of 6 outputs used**

This leaves three Lua output slots available across the system for future functionality.

---

# Transition States

`system.lua` exposes two transition-state outputs:

```text
BladeTr
TillerTr
```

These indicate whether the respective implement is currently performing an automatic movement.

They can be used by:

- EdgeTX logical switches
- Operator-screen indicators
- Audio announcements
- Future safety logic
- Debugging

The actual operating mode does not require a Lua output because all scripts can read `SD` directly.

---

# Logical Switch Philosophy

Machine-control logic is kept primarily in Lua.

Logical switches should be used for radio-level functions such as:

- Operator display indicators
- Audio announcements
- Warnings
- Debugging
- Special functions

Suggested logical states include:

```text
E-stop Active
Any Transition Active
Groom Mode
Reverse Requested
Tiller Motor Locked
```

Safety-critical behavior should not depend on a long chain of EdgeTX logical switches when Lua can directly read the underlying physical switch or control.

---

# Repository Structure

A suggested repository structure is:

```text
pb600-edgetx/
|
+-- README.md
|
+-- lua/
|   +-- blade.lua
|   +-- tiller.lua
|   +-- system.lua
|
+-- widgets/
|   +-- operator/
|   +-- debug/
|
+-- docs/
|   +-- channel-map.md
|   +-- gv-reference.md
|   +-- calibration.md
|
+-- deploy/
|   +-- deploy-test.ps1
|   +-- deploy-production.ps1
|
+-- .gitignore
```

The Git repository is the authoritative source for Lua scripts and widget code.

Files should be edited and committed in the repository rather than directly on the radio SD card.

---

# Development and Deployment

Two deployment targets are used:

```text
Test:
C:\radio

Production / Radio SD Card:
D:\
```

The intended workflow is:

```text
Edit in VS Code
      |
      v
Test / Review
      |
      v
Commit to Git
      |
      v
Deploy to C:\radio
      |
      v
Test
      |
      v
Deploy approved version to D:\
```

Production deployment should copy only the files managed by the repository into their appropriate EdgeTX SD-card directories rather than treating the entire SD card as the Git working directory.

This keeps source control independent of the removable radio storage.

---

# Calibration

Mechanical characteristics that normally remain constant should be stored near the beginning of each Lua script.

Examples include:

```lua
local LIFT_FULL_TIME  = 6.7
local WING_FULL_TIME  = 3.75

local TILLER_LIFT_FULL  = 12.5
local TILLER_ANGLE_FULL = 3.75
```

If an actuator is replaced or its speed changes, recalibrate the appropriate full-travel value in the source.

Operator-facing GVs should not be used to compensate for incorrect mechanical calibration.

---

# Design Principles

The project follows several rules intended to keep the radio configuration maintainable.

### One owner for each physical function

A physical actuator should normally have one authoritative Lua output.

Avoid combining legacy radio mixes with Lua outputs for the same actuator.

### Hardware outputs are valuable

Lua outputs are limited, so outputs should primarily be reserved for physical hardware control or genuinely useful external machine states.

### GVs are for live tuning

If a parameter is routinely adjusted while operating the snowcat, it belongs in a GV.

If it represents mechanical calibration or established machine behavior, it belongs in code.

### Safety logic stays simple

E-stop is read directly by each relevant Lua script.

No script should depend on another Lua script's output to recognize the E-stop.

### Automatic behavior has one authority

Reverse operation in Groom uses the automatic reverse-lift sequence.

Older competing behaviors such as an SH reverse override should not be layered on top of it.

### Preserve spare capacity

Unused Lua outputs and GVs are intentionally left available rather than consumed simply because they exist.

---

# Current Development Status

The control system is undergoing a consolidation from several generations of working PB600 scripts.

The current architecture is intended to become the new baseline:

- Simplified GV allocation
- Direct Lua hardware outputs
- Preserved hydrostatic track behavior
- Unified blade/tiller coordination
- Automatic reverse tiller lift
- Tiller rotor safety interlock
- E-stop across tracks, tiller rotor, blade, and tiller actuators
- Explicit Transport / Plow / Groom transitions
- Reduced dependence on EdgeTX logical switches

New functionality should be evaluated against this architecture before additional GVs, logical switches, or Lua outputs are allocated.

---

## Safety

This is hobby RC control software.

Always test new Lua scripts with the model safely supported and, where practical, with track drive and high-power accessories disconnected.

Verify actuator direction, travel limits, E-stop behavior, and automatic transitions before operating the model under load.
