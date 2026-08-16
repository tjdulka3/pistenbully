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
| Down | Groom | Blade remains at working position and tiller lowers to its Groom position |

Each Lua script reads `SD` directly. No Lua output is consumed simply to communicate the current operating mode.

## Automatic Blade Transition

When entering or leaving Transport, the blade automatically moves only:

- Blade Lift
- Blade Angle
- Left Wing
- Right Wing

Blade Tilt and Blade Slew do **not** participate in automatic mode transitions. Tilt and Slew remain under manual control and, when enabled, coordinated-turn control.

Plow and Groom use the same normal blade working configuration, so changing between Plow and Groom does not reposition the blade solely because of the mode change.

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

local ACCEL_RATE    = 205
local DECEL_RATE    = 512
local REVERSE_BOOST = 250
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

`system.lua` provides a dedicated `TMotor` safety-interlock output.

```text
TMotor = +1024 / +100%  -> Rotor operation permitted
TMotor = -1024 / -100%  -> Rotor forced OFF
```

The tiller motor ESC uses the following command convention:

```text
-1024 / -100% =   0% motor power
    0 /    0% =  50% motor power
+1024 / +100% = 100% motor power
```

Therefore `TMotor = 0` must **not** be interpreted as motor OFF.

The normal rotor-speed command comes from `S1`. `TMotor` acts as a safety override that forces the physical tiller motor channel to `-1024` whenever rotor operation is prohibited.

The tiller rotor is disabled during:

- Emergency stop
- Automatic reverse lift
- Reverse operation
- Return from reverse to Groom position
- Normal tiller transitions

The rotor is not permitted to restart until the tiller has completed its return to the normal Groom position.

Conceptually:

```text
Normal operation:
CH14 follows S1

Safety lockout:
CH14 forced to -1024
```

The receiver failsafe for the physical tiller motor channel must also be configured for:

```text
CH14 = -100% / -1024
```

Receiver `Hold` should **not** be used for the tiller motor channel.

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

# Automatic Blade Positioning

Automatic Transport / working-position transitions operate:

```text
Lift
Angle
Left Wing
Right Wing
```

They do **not** automatically operate:

```text
Tilt
Slew
```

| Axis | Transport -> Plow/Groom | Plow/Groom -> Transport |
|---|---|---|
| Lift | Move down to GV2 depth | Raise to home |
| Angle | Move to working angle | Return to transport angle |
| Left Wing | Move to working opening | Close |
| Right Wing | Move to working opening | Close |
| Tilt | No automatic output | No automatic output |
| Slew | No automatic output | No automatic output |

`TranB` remains active until Lift, Angle, and Wings have completed their automatic movement.

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

## Coordination Rudder Deadband

Implement coordination uses a larger rudder deadband than track steering so small incidental rudder movement while moving the combined throttle/rudder stick does not cause blade or tiller movement.

Typical starting values:

```text
Track steering rudder deadband:   ~2%
Implement coordination deadband:  ~8%
```

The coordination input is rescaled outside the deadband so full physical rudder still produces full configured coordination.

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

| GV | Setting | Range | Current | Purpose |
|---|---|---|---|---|
| GV1 | Coordination Intensity | 0-100 | 60 | Overall strength of automatic blade/tiller coordination |
| GV2 | Blade Working Depth | 0-100 | 40 | Blade operating height/depth |
| GV3 | Tiller Groom Depth | 0-100 | 35 | Normal tiller grooming height/depth |
| GV4 | Reverse Lift Height | 0-100 | 10 | Amount the tiller raises before reverse is permitted 
| GV5 | Tiller Working Angle | 0-100 | 50 | Normal tiller working angle |
| GV6-GV9 | Reserved | | | Available for future operator-adjustable settings |

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
3  TMotor
4  TranB
5  TranT
6  Reserved
```

**5 of 6 outputs used**

This leaves three Lua output slots available across the system for future functionality.

---

# Transition States

`system.lua` exposes two transition-state outputs:

```text
TranB = Blade transition state
TranT = Tiller transition state
```

The outputs use:

```text
+1024 = Transition active
-1024 = Transition inactive
```

These signals do **not** need to be assigned to physical receiver channels.

EdgeTX logical switches consume the Lua outputs directly:

```text
L11 = TranB active
L12 = TranT active
```

The logical switches should test whether the corresponding Lua output is greater than zero.

The operator widget can then use L11 and L12 for transition and status messaging without consuming physical receiver channels.

## Reading Logical Switches from Lua

`getLogicalSwitchValue()` uses a **zero-based** index and returns a Lua boolean.

```lua
local bladeTransition = getLogicalSwitchValue(10)   -- L11
local tillerTransition = getLogicalSwitchValue(11)  -- L12
```

```text
Index 0  = L01
Index 1  = L02
...
Index 10 = L11
Index 11 = L12
```

Use the boolean directly:

```lua
if getLogicalSwitchValue(10) then
    -- Blade transition active
end
```

Do not compare `getLogicalSwitchValue()` to `1024`.

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

Current transmitter-local transition assignments are:

```text
L11 = Blade Transition (`TranB`)
L12 = Tiller Transition (`TranT`)
```

This avoids consuming physical receiver channels solely for status information.

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

# Actuator Calibration

Mechanical characteristics that normally remain constant are stored near the beginning of each Lua script.

## Asymmetric Lift Timing

Lift actuator movement is asymmetric. The measured tiller full-stroke travel is:

```text
Full stroke DOWN = 11.0 seconds
Full stroke UP   = 14.0 seconds
```

The tiller is currently being used as the calibration proxy for blade lift movement, so blade and tiller currently use matching directional lift rates.

## Blade Timing

Current blade working depth:

```text
GV2 = 40%

Transport -> Working: 11.0 x 0.40 = 4.40 seconds DOWN
Working -> Transport: 14.0 x 0.40 = 5.60 seconds UP
```

## Tiller Timing

Current Groom depth:

```text
GV3 = 35%

Raised -> Groom: 11.0 x 0.35 = 3.85 seconds DOWN
Groom -> Raised: 14.0 x 0.35 = 4.90 seconds UP
```

## Reverse Lift Timing

With `GV4 = 10%`:

```text
Reverse lift UP: 14.0 x 0.10 = 1.40 seconds
Return DOWN:     11.0 x 0.10 = 1.10 seconds
```

## Position Model Synchronization

`blade.lua`, `tiller.lua`, and `system.lua` must use matching lift calibration values. `system.lua` relies on these same values for transition timing, reverse-clearance timing, and tiller-motor lockout timing.

Using one symmetric travel time for both directions causes the modeled actuator position to drift from the physical actuator after repeated transitions.

Operator-facing GVs should not be used to compensate for incorrect mechanical calibration.

## Transmitter Calibration

Physical stick calibration should be verified before compensating for center errors in Lua. A miscalibrated rudder center can cause neutral rudder to be interpreted as a pivot request.

After calibration, verify approximately:

```text
Centered throttle = 0
Centered rudder   = 0
```

Software deadbands should handle normal small stick movement, not compensate for a badly calibrated transmitter.

## Receiver Failsafe

Safety-critical channels should use explicit safe failsafe positions rather than `Hold`. In particular:

```text
Tiller Motor CH14 failsafe = -100% / -1024
```

Track channels should likewise be configured to their stopped values.

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
- Logical switches used for transmitter-local status/UI functions rather than primary machine-control logic
- L11/L12 provide Blade/Tiller transition status without consuming receiver channels
- Direction-specific 11-second-down / 14-second-up lift timing
- Blade automatic transitions limited to Lift, Angle, and Wings
- Tilt and Slew excluded from automatic blade mode transitions
- Receiver failsafe forces tiller rotor channel to -1024/off

New functionality should be evaluated against this architecture before additional GVs, logical switches, or Lua outputs are allocated.

---

## Safety

This is hobby RC control software.

Always test new Lua scripts with the model safely supported and, where practical, with track drive and high-power accessories disconnected.

Verify actuator direction, travel limits, E-stop behavior, and automatic transitions before operating the model under load.
