# PistenBully 600 RC Control System

Custom EdgeTX Lua mixer scripts and radio configuration for a scale RC
PistenBully 600 snowcat.

The project provides coordinated control of the tracks, front blade,
rear tiller, finishers, and tiller rotor while reproducing several
behaviors of the full-size PistenBully.

The control system is designed for a RadioMaster TX16S MK3 running
EdgeTX.

------------------------------------------------------------------------

## Table of Contents

-   [Overview](#overview)
-   [Operating Modes](#operating-modes)
    -   [Automatic Blade Transition](#automatic-blade-transition)
-   [Track Control](#track-control)
-   [Hydrostatic Drive Simulation](#hydrostatic-drive-simulation)
-   [DasMikro TBS Mini Sound System](#dasmikro-tbs-mini-sound-system)
    -   [Prop1 - Engine / Drivetrain
        Sound](#prop1-engine-drivetrain-sound)
    -   [Prop2 - Horn / Reverse Warning](#prop2-horn-reverse-warning)
    -   [Automatic Reverse Beeper](#automatic-reverse-beeper)
    -   [Prop3 - Engine Autostart](#prop3-engine-autostart)
    -   [Sound-System Signal
        Architecture](#sound-system-signal-architecture)
-   [Automatic Reverse / Tiller Lift](#automatic-reverse-tiller-lift)
-   [Tiller Motor Safety](#tiller-motor-safety)
-   [Emergency Stop](#emergency-stop)
-   [Blade Control](#blade-control)
-   [Manual Blade Controls](#manual-blade-controls)
-   [Automatic Blade Positioning](#automatic-blade-positioning)
-   [Blade Coordination](#blade-coordination)
    -   [Coordination Rudder Deadband](#coordination-rudder-deadband)
-   [Tiller Control](#tiller-control)
-   [Tiller Coordination](#tiller-coordination)
-   [Global Variables](#global-variables)
-   [Lua Output Allocation](#lua-output-allocation)
    -   [`blade.lua`](#bladelua)
    -   [`tiller.lua`](#tillerlua)
    -   [`system.lua`](#systemlua)
-   [Transition States](#transition-states)
    -   [Reading Logical Switches from
        Lua](#reading-logical-switches-from-lua)
-   [Logical Switch Philosophy](#logical-switch-philosophy)
-   [Repository Structure](#repository-structure)
-   [Development and Deployment](#development-and-deployment)
-   [Actuator Calibration](#actuator-calibration)
    -   [Asymmetric Lift Timing](#asymmetric-lift-timing)
    -   [Blade Timing](#blade-timing)
    -   [Tiller Timing](#tiller-timing)
    -   [Reverse Lift Timing](#reverse-lift-timing)
    -   [Position Model
        Synchronization](#position-model-synchronization)
    -   [Transmitter Calibration](#transmitter-calibration)
    -   [Receiver Failsafe](#receiver-failsafe)
-   [Design Principles](#design-principles)
-   [Current Development Status](#current-development-status)
    -   [Safety](#safety)

------------------------------------------------------------------------

## Overview

The PB600 uses three custom Lua mixer scripts:

  ---------------------------------------------------------------------
  Script                             Responsibility
  ---------------------------------- ----------------------------------
  `system.lua`                       Track drive, hydrostatic drive
                                     behavior, safety interlocks,
                                     transition states, reverse
                                     behavior, tiller motor control,
                                     and engine/sound-card drive signal

  `blade.lua`                        Front blade actuator control,
                                     positioning, manual operation,
                                     coordinated blade movement, and
                                     automatic reverse-clearance lift

  `tiller.lua`                       Rear tiller lift, angle,
                                     finishers, grooming position, and
                                     automatic reverse lift
  ---------------------------------------------------------------------

The scripts intentionally separate responsibilities:

-   `system.lua` controls machine-level behavior and safety.
-   `blade.lua` controls only blade hardware.
-   `tiller.lua` controls only rear implement positioning.
-   Lua outputs are reserved primarily for actual hardware control or
    important machine state.
-   Frequently adjusted settings are exposed as EdgeTX Global Variables.
-   Mechanical calibration and rarely changed tuning values remain
    constants in the Lua code.

------------------------------------------------------------------------

# Operating Modes

The `SD` three-position switch selects the primary operating mode.

  -----------------------------------------------------------------------
  SD Position             Mode                    Behavior
  ----------------------- ----------------------- -----------------------
  Up                      Transport               Blade and tiller move
                                                  to transport positions

  Middle                  Plow                    Blade moves to working
                                                  position; tiller
                                                  remains raised

  Down                    Groom                   Blade remains at
                                                  working position and
                                                  tiller lowers to its
                                                  Groom position
  -----------------------------------------------------------------------

Each Lua script reads `SD` directly. No Lua output is consumed simply to
communicate the current operating mode.

## Automatic Blade Transition

When entering or leaving Transport, the blade automatically moves only:

-   Blade Lift
-   Blade Angle
-   Left Wing
-   Right Wing

Blade Tilt and Blade Slew do **not** participate in automatic mode
transitions. Tilt and Slew remain under manual control and, when
enabled, coordinated-turn control.

Plow and Groom use the same normal blade working configuration, so
changing between Plow and Groom does not reposition the blade solely
because of the mode change.

------------------------------------------------------------------------

# Track Control

Track drive is generated entirely by `system.lua`.

The script accepts throttle and rudder inputs and generates independent
left and right track outputs.

### Features

-   Differential track steering
-   Pivot/drive blending
-   Nonlinear rudder response
-   Reduced steering sensitivity at higher speeds
-   Hydrostatic-style acceleration
-   Hydrostatic-style deceleration/braking
-   Increased braking when changing direction
-   Reduced track power while implements are transitioning
-   Automatic Groom reverse protection
-   Emergency stop

Raw throttle and rudder mixes should **not** also be applied to the
physical track channels.

Example:

``` text
CH1 - Left Track
  100% LUA:System:TrackL

CH3 - Right Track
  100% LUA:System:TrackR
```

The Lua track outputs are the sole authority for the track ESCs.

------------------------------------------------------------------------

# Hydrostatic Drive Simulation

The track control attempts to reproduce the heavy, progressive feel of
the PB600 hydrostatic drivetrain rather than directly mapping stick
position to ESC output.

The primary tuning constants are maintained in `system.lua`:

``` lua
local TURN_GAIN     = 0.25
local SPEED_FACTOR  = 0.60

local ACCEL_RATE    = 205
local DECEL_RATE    = 512
local REVERSE_BOOST = 250
```

These values are intentionally stored in code rather than Global
Variables because they represent machine calibration rather than normal
operator adjustments.

### Acceleration

Track output builds progressively toward the commanded speed.

The current target behavior is approximately five seconds to build from
zero to full commanded power.

### Hydrostatic braking

Reducing throttle causes the tracks to decelerate more aggressively than
they accelerate, simulating the braking effect of a hydrostatic
drivetrain.

The current target behavior is approximately two seconds from full power
to zero.

### Direction changes

Changing directly between forward and reverse applies additional braking
while passing through zero.

### Steering

Steering response is nonlinear near stick center and progressively
increases with rudder input.

Steering authority is also reduced as vehicle speed increases.

------------------------------------------------------------------------

# DasMikro TBS Mini Sound System

The PB600 uses a DasMikro TBS Mini sound module for engine, drivetrain,
horn, and reverse-warning sounds.

The current receiver connections are:

``` text
Prop1 = CH15 - Engine / drivetrain
Prop2 = CH16 - Horn / reverse beeper
Prop3 = Not connected
```

Prop3 is not required because the sound module is configured for
automatic engine start.

------------------------------------------------------------------------

## Prop1 - Engine / Drivetrain Sound

TBS Mini Prop1 is connected to receiver CH15.

``` text
system.lua Engine
        |
        v
      CH15
        |
        v
 TBS Mini Prop1
```

CH15 is configured as:

``` text
100% LUA:System:Engine
```

The sound card previously received raw throttle on CH15.

The current configuration instead uses the `Engine` output generated by
`system.lua`. This allows engine RPM to follow effective hydrostatic
drivetrain activity rather than raw throttle-stick position.

During Groom reverse initiation, the tracks remain stopped while the
blade and tiller raise to their reverse-clearance positions. Because the
Engine signal is derived from the actual track outputs, the engine
remains near idle until reverse movement is permitted.

------------------------------------------------------------------------

## Prop2 - Horn / Reverse Warning

TBS Mini Prop2 is connected to receiver CH16.

The basic three-position control is SA:

``` text
SA Up       = Reverse warning beep
SA Middle   = No auxiliary sound
SA Down     = Horn
```

The horn is manually activated by moving SA Down.

------------------------------------------------------------------------

## Automatic Reverse Beeper

The reverse warning uses EdgeTX logical switches to periodically
activate the Prop2 beeper rather than playing a continuous warning.

### L08 - Reverse Detection

L08 detects a reverse throttle request:

``` text
L08
Function: a < x
V1: Thr
V2: -5
```

Conceptually:

``` text
Thr < -5
   |
   v
L08 = TRUE
```

This provides a small threshold around neutral so the reverse warning
does not activate from minor throttle-stick movement.

### L09 - Reverse Beeper Timer

L09 is a timer controlled by L08:

``` text
L09
Function: Timer
V1: 0.4
V2: 0.8
Switch: L08
```

When reverse is requested, L08 becomes true and enables L09.

CH16 uses this timer to repeatedly toggle the Prop2 command between the
neutral/middle command and the SA-Up beeper command:

``` text
SA Middle = No sound
SA Up     = Reverse beep
```

The resulting control sequence is:

``` text
Reverse requested
      |
      v
Thr < -5
      |
      v
L08 TRUE
      |
      v
L09 timer active
      |
      +---- repeating 0.4 / 0.8 sec cycle ----+
      |                                        |
      v                                        v
Middle command                            Up command
No sound                                  Reverse beep
      ^                                        |
      |                                        |
      +----------------------------------------+
```

The timer stops when throttle is no longer below -5.

The reverse beeper intentionally begins when reverse is requested, even
while the blade and tiller are completing their automatic
reverse-clearance lift.

------------------------------------------------------------------------

## Prop3 - Engine Autostart

TBS Mini Prop3 is not connected.

The sound module is configured to use automatic engine start based on
activity on Prop1.

``` text
TBS Prop3    = Not connected
Engine Start = Automatic
```

A separate receiver channel or switch for engine start/stop is therefore
not required.

------------------------------------------------------------------------

## Sound-System Signal Architecture

The complete control path is:

``` text
                    RadioMaster TX16S MK3
                             |
             +---------------+---------------+
             |                               |
             v                               v
      system.lua Engine                     SA
             |                               |
             v                               |
           CH15                    +----------+----------+
             |                     |          |          |
             v                    UP        MIDDLE      DOWN
      TBS Mini Prop1               |          |          |
             |                   BEEP        OFF        HORN
             |                     |
             |                     +---- L09 timer
             |                              ^
             |                              |
             |                         L08: Thr < -5
             |                              ^
             |                              |
             |                           Reverse
             |
             v
     Engine / Drivetrain
          Sound

      TBS Mini Prop3
             |
       Not connected
             |
      Engine autostart
```

### Receiver Connections

  ------------------------------------------------------------------------
  Receiver Channel Source                TBS Input        Function
  ---------------- --------------------- ---------------- ----------------
  CH15             `LUA:System:Engine`   Prop1            Engine /
                                                          drivetrain sound

  CH16             SA + L08/L09          Prop2            Horn / reverse
                   reverse-beeper logic                   warning

  None             None                  Prop3            Unused -
                                                          automatic engine
                                                          start
  ------------------------------------------------------------------------

------------------------------------------------------------------------

# Automatic Reverse / Blade and Tiller Lift

When operating in Groom mode, reverse is integrated with both the front
blade and rear tiller rather than simply being blocked.

The sequence is:

``` text
Reverse requested
       |
       v
Tiller rotor disabled
       |
       v
Reverse track output blocked
       |
       +------------------+
       |                  |
       v                  v
Blade raises          Tiller raises
by configured amount  by configured amount
       |                  |
       +--------+---------+
                |
                v
Both reverse-clearance lifts complete
                |
                v
Reverse track movement enabled
                |
                v
Snowcat backs with blade and tiller raised
                |
                v
Reverse command released
                |
       +--------+---------+
       |                  |
       v                  v
Blade returns         Tiller returns
to starting height    to starting height
       |                  |
       +--------+---------+
                |
                v
Both returns complete
                |
                v
Tiller rotor enabled
```

The base reverse lift amount is controlled by `GV4`.

Both the blade and tiller capture their exact lift position when the
reverse sequence begins. After reverse ends, each implement returns to
its captured pre-reverse position rather than simply returning to a
nominal GV-defined working position.

The tiller uses GV4 directly. The blade uses GV4 multiplied by the
code-level `BLADE_REVERSE_LIFT_FACTOR`. With the current factor of
`1.00`, both implements use the same reverse-lift percentage.

If reverse is released before either implement finishes raising, the
reverse-clearance lift is still completed before the implement returns
to its captured starting height.

This replaces the earlier design in which reverse was completely
prohibited in Groom unless the operator held the `SH` switch. `SH` is
therefore not required for normal reverse operation.

------------------------------------------------------------------------

# Tiller Motor Safety

`system.lua` provides a dedicated `TMotor` safety-interlock output.

``` text
TMotor = +1024 / +100%  -> Rotor operation permitted
TMotor = -1024 / -100%  -> Rotor forced OFF
```

The tiller motor ESC uses the following command convention:

``` text
-1024 / -100% =   0% motor power
    0 /    0% =  50% motor power
+1024 / +100% = 100% motor power
```

Therefore `TMotor = 0` must **not** be interpreted as motor OFF.

The normal rotor-speed command comes from `S1`. `TMotor` acts as a
safety override that forces the physical tiller motor channel to `-1024`
whenever rotor operation is prohibited.

The tiller rotor is disabled during:

-   Emergency stop
-   Automatic reverse lift
-   Reverse operation
-   Return from reverse to Groom position
-   Normal tiller transitions

The rotor is not permitted to restart until the tiller has completed its
return to the normal Groom position.

Conceptually:

``` text
Normal operation:
CH14 follows S1

Safety lockout:
CH14 forced to -1024
```

The receiver failsafe for the physical tiller motor channel must also be
configured for:

``` text
CH14 = -100% / -1024
```

Receiver `Hold` should **not** be used for the tiller motor channel.

------------------------------------------------------------------------

# Emergency Stop

`SF` is the machine emergency-stop switch.

E-stop is deliberately handled independently by each Lua script rather
than relying on one script to communicate the stop condition to the
others.

When E-stop is active:

### `system.lua`

-   Left track output = 0
-   Right track output = 0
-   Tiller motor disabled

### `blade.lua`

-   All blade actuator outputs stop

### `tiller.lua`

-   All tiller actuator outputs stop

This provides a simple and redundant safety architecture.

------------------------------------------------------------------------

# Blade Control

`blade.lua` directly controls all six blade functions.

  Lua Output   Function
  ------------ --------------------
  `Lift`       Blade lift
  `Tilt`       Blade tilt
  `Angle`      Blade angle
  `Slew`       Blade lateral slew
  `LW`         Left wing
  `RW`         Right wing

All six available Lua mixer outputs are therefore dedicated to physical
blade functions.

------------------------------------------------------------------------

## Blade Reverse Clearance

In Groom mode, blade lift participates in the automatic
reverse-clearance sequence.

When reverse is first requested, `blade.lua`:

1.  Captures the current modeled blade-lift position.
2.  Calculates a raised target using GV4 and
    `BLADE_REVERSE_LIFT_FACTOR`.
3.  Raises completely to that target.
4.  Holds the blade at the raised position while reverse remains active.
5.  Returns to the exact captured position after reverse is released.

If reverse is released before the blade has finished raising, the blade
still completes the full commanded reverse lift before returning to its
starting position.

During blade reverse lift, hold, and return:

-   Manual blade control is suppressed.
-   Blade coordination is suppressed.
-   Automatic reverse clearance has authority over blade Lift.

Normal blade control resumes after the reverse-return sequence
completes.

------------------------------------------------------------------------

# Manual Blade Controls

The right stick changes function according to the `SC` switch.

  SC Position   Aileron        Elevator
  ------------- -------------- -------------
  Up            Blade Tilt     Blade Lift
  Middle        Blade Slew     Blade Angle
  Down          Tiller Angle   Tiller Lift

Blade wings remain independently controlled by the left and right
sliders.

------------------------------------------------------------------------

# Automatic Blade Positioning

Automatic Transport / working-position transitions operate:

``` text
Lift
Angle
Left Wing
Right Wing
```

They do **not** automatically operate:

``` text
Tilt
Slew
```

  Axis         Transport -\> Plow/Groom   Plow/Groom -\> Transport
  ------------ -------------------------- ---------------------------
  Lift         Move down to GV2 depth     Raise to home
  Angle        Move to working angle      Return to transport angle
  Left Wing    Move to working opening    Close
  Right Wing   Move to working opening    Close
  Tilt         No automatic output        No automatic output
  Slew         No automatic output        No automatic output

`TranB` remains active until Lift, Angle, and Wings have completed their
automatic movement.

------------------------------------------------------------------------

# Blade Coordination

In Groom mode, rudder input can automatically coordinate blade movement
with vehicle turns.

Coordinated functions include:

-   Blade wings
-   Blade slew
-   Blade tilt
-   Blade angle

The relative amount of movement for each blade axis is stored as
constants in `blade.lua`.

For example:

``` lua
local COORD_WING_RANGE  = 0.15
local COORD_SLEW_RANGE  = 0.12
local COORD_TILT_RANGE  = 0.08
local COORD_ANGLE_RANGE = 0.10
```

A single Global Variable controls overall coordination intensity.

This replaces the older design that used individual GVs for each
coordinated blade axis.

The objective is to tune the relationship among the blade movements once
in code and expose only overall coordination strength to the operator.

## Coordination Rudder Deadband

Implement coordination uses a larger rudder deadband than track steering
so small incidental rudder movement while moving the combined
throttle/rudder stick does not cause blade or tiller movement.

Current starting values:

``` text
Track steering rudder deadband:   ~2%
Blade coordination deadband:      ~12%
```

In `blade.lua`:

``` lua
local COORD_RUD_DEADBAND = 0.12
```

The coordination input is rescaled outside the deadband so full physical
rudder still produces full configured coordination.

The larger coordination deadband affects implement coordination only and
does not reduce normal track-steering responsiveness.

------------------------------------------------------------------------

# Tiller Control

`tiller.lua` controls four rear implement functions.

  Lua Output   Function
  ------------ ----------------
  `TAng`       Tiller angle
  `TLift`      Tiller lift
  `FinL`       Left finisher
  `FinR`       Right finisher

Two Lua output slots remain available for future functionality.

When entering Groom mode, the tiller automatically moves to the
configured Groom position.

When leaving Groom, the tiller returns to its raised position.

------------------------------------------------------------------------

# Tiller Coordination

When coordination is enabled in Groom mode, rudder input can
automatically adjust tiller angle to follow the vehicle through a turn.

Overall coordination strength uses the same `GV1` master coordination
setting used by the blade.

This keeps blade and tiller coordination synchronized through a single
operator adjustment.

------------------------------------------------------------------------

# Global Variables

Global Variables are reserved for settings that are useful to adjust
live from the transmitter.

  ------------------------------------------------------------------------
  GV          Setting        Range       Current     Purpose
  ----------- -------------- ----------- ----------- ---------------------
  GV1         Coordination   0-100       60          Overall strength of
              Intensity                              automatic
                                                     blade/tiller
                                                     coordination

  GV2         Blade Working  0-100       40          Blade operating
              Depth                                  height/depth

  GV3         Tiller Groom   0-100       35          Normal tiller
              Depth                                  grooming height/depth

  GV4         Reverse Lift   0-100       10          Base amount the blade
              Height                                 and tiller raise for
                                                     reverse clearance

  GV5         Tiller Working 0-100       50          Normal tiller working
              Angle                                  angle

  GV6-GV9     Reserved                               Available for future
                                                     operator-adjustable
                                                     settings
  ------------------------------------------------------------------------

## Reverse Lift Scaling

`GV4` is the common operator adjustment for reverse-clearance lift.

The tiller uses GV4 directly. The blade uses GV4 multiplied by a
code-level scaling factor:

``` lua
local BLADE_REVERSE_LIFT_FACTOR = 1.00
```

With `GV4 = 10%` and a blade factor of `1.00`, both blade and tiller
raise approximately 10% of full lift travel.

The blade factor can be changed in code if the blade requires a
different amount of reverse clearance without consuming another Global
Variable.

Mechanical timing, actuator direction, steering characteristics,
deadbands, and other machine calibration values are maintained directly
in the Lua source.

------------------------------------------------------------------------

# Lua Output Allocation

EdgeTX custom Lua mixer scripts are limited to six outputs per script.

The project deliberately manages those outputs as follows.

## `blade.lua`

``` text
1  Lift
2  Tilt
3  Angle
4  Slew
5  LW
6  RW
```

**6 of 6 outputs used**

## `tiller.lua`

``` text
1  TAng
2  TLift
3  FinL
4  FinR
5  Reserved
6  Reserved
```

**4 of 6 outputs used**

## `system.lua`

``` text
1  TrackL
2  TrackR
3  TMotor
4  TranB
5  TranT
6  Engine
```

**6 of 6 outputs used**

`TranB` and `TranT` are consumed locally by EdgeTX logical switches and
do not require physical receiver channels.

`Engine` is mapped to the sound-card throttle input and represents
effective drivetrain output rather than raw throttle-stick position.

Two Lua output slots remain available across the system, both in
`tiller.lua`.

------------------------------------------------------------------------

# Transition States

`system.lua` exposes two transition-state outputs:

``` text
TranB = Blade transition state
TranT = Tiller transition state
```

The outputs use:

``` text
+1024 = Transition active
-1024 = Transition inactive
```

These signals do **not** need to be assigned to physical receiver
channels.

EdgeTX logical switches consume the Lua outputs directly:

``` text
L11 = TranB active
L12 = TranT active
```

The logical switches should test whether the corresponding Lua output is
greater than zero.

The operator widget can then use L11 and L12 for transition and status
messaging without consuming physical receiver channels.

## Reading Logical Switches from Lua

`getLogicalSwitchValue()` uses a **zero-based** index and returns a Lua
boolean.

``` lua
local bladeTransition = getLogicalSwitchValue(10)   -- L11
local tillerTransition = getLogicalSwitchValue(11)  -- L12
```

``` text
Index 0  = L01
Index 1  = L02
...
Index 10 = L11
Index 11 = L12
```

Use the boolean directly:

``` lua
if getLogicalSwitchValue(10) then
    -- Blade transition active
end
```

Do not compare `getLogicalSwitchValue()` to `1024`.

------------------------------------------------------------------------

# Logical Switch Philosophy

Machine-control logic is kept primarily in Lua.

Logical switches should be used for radio-level functions such as:

-   Operator display indicators
-   Audio announcements
-   Warnings
-   Debugging
-   Special functions

Suggested logical states include:

``` text
E-stop Active
Any Transition Active
Groom Mode
Reverse Requested
Tiller Motor Locked
```

Safety-critical behavior should not depend on a long chain of EdgeTX
logical switches when Lua can directly read the underlying physical
switch or control.

Current transmitter-local transition assignments are:

``` text
L11 = Blade Transition (`TranB`)
L12 = Tiller Transition (`TranT`)
```

This avoids consuming physical receiver channels solely for status
information.

------------------------------------------------------------------------

# Repository Structure

A suggested repository structure is:

``` text
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

The Git repository is the authoritative source for Lua scripts and
widget code.

Files should be edited and committed in the repository rather than
directly on the radio SD card.

------------------------------------------------------------------------

# Development and Deployment

Two deployment targets are used:

``` text
Test:
C:\radio

Production / Radio SD Card:
D:\
```

The intended workflow is:

``` text
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

Production deployment should copy only the files managed by the
repository into their appropriate EdgeTX SD-card directories rather than
treating the entire SD card as the Git working directory.

This keeps source control independent of the removable radio storage.

------------------------------------------------------------------------

# Actuator Calibration

Mechanical characteristics that normally remain constant are stored near
the beginning of each Lua script.

## Asymmetric Lift Timing

Lift actuator movement is asymmetric. The measured tiller full-stroke
travel is:

``` text
Full stroke DOWN = 11.0 seconds
Full stroke UP   = 17.0 seconds
```

The tiller was used as the initial calibration proxy for blade lift
movement. Testing showed that the upward proportional runtime required
additional compensation to return consistently to the original physical
position.

The current calibrated lift timing used by `blade.lua`, `tiller.lua`,
and `system.lua` is:

``` lua
local LIFT_DOWN_FULL_TIME = 11.0
local LIFT_UP_FULL_TIME   = 17.0
```

or the equivalent script-specific constant names.

## Blade Timing

Current blade working depth:

``` text
GV2 = 40%

Transport -> Working: 11.0 x 0.40 = 4.40 seconds DOWN
Working -> Transport: 17.0 x 0.40 = 6.80 seconds UP
```

## Tiller Timing

Current Groom depth:

``` text
GV3 = 35%

Raised -> Groom: 11.0 x 0.35 = 3.85 seconds DOWN
Groom -> Raised: 17.0 x 0.35 = 5.95 seconds UP
```

## Reverse Clearance Timing

Reverse is not permitted in Groom until both the blade and tiller have
completed their required reverse-clearance lift.

`system.lua` calculates the required lift time for each implement and
waits for the slower movement.

With the current settings:

``` text
GV4 = 10%
Blade Reverse Lift Factor = 1.00
Blade full-stroke UP  = 17.0 seconds
Tiller full-stroke UP = 17.0 seconds
```

the reverse lift times are:

``` text
Blade:   17.0 x 10% = 1.70 seconds UP
Tiller:  17.0 x 10% = 1.70 seconds UP

Reverse clearance time:
max(1.70, 1.70) = 1.70 seconds
```

When reverse is released, both implements return toward their exact
captured pre-reverse positions. With the current 11-second full-stroke
downward calibration, a 10% return movement is approximately:

``` text
11.0 x 10% = 1.10 seconds DOWN
```

The system waits for the slower required return before the reverse cycle
is considered complete.

## Position Model Synchronization

`blade.lua`, `tiller.lua`, and `system.lua` must use matching lift
calibration values. `system.lua` relies on these same values for
transition timing, reverse-clearance timing, and tiller-motor lockout
timing.

Using one symmetric travel time for both directions causes the modeled
actuator position to drift from the physical actuator after repeated
transitions.

Operator-facing GVs should not be used to compensate for incorrect
mechanical calibration.

## Transmitter Calibration

Physical stick calibration should be verified before compensating for
center errors in Lua. A miscalibrated rudder center can cause neutral
rudder to be interpreted as a pivot request.

After calibration, verify approximately:

``` text
Centered throttle = 0
Centered rudder   = 0
```

Software deadbands should handle normal small stick movement, not
compensate for a badly calibrated transmitter.

## Receiver Failsafe

Safety-critical channels should use explicit safe failsafe positions
rather than `Hold`. In particular:

``` text
Tiller Motor CH14 failsafe = -100% / -1024
```

Track channels should likewise be configured to their stopped values.

------------------------------------------------------------------------

# Design Principles

The project follows several rules intended to keep the radio
configuration maintainable.

### One owner for each physical function

A physical actuator should normally have one authoritative Lua output.

Avoid combining legacy radio mixes with Lua outputs for the same
actuator.

### Hardware outputs are valuable

Lua outputs are limited, so outputs should primarily be reserved for
physical hardware control or genuinely useful external machine states.

### GVs are for live tuning

If a parameter is routinely adjusted while operating the snowcat, it
belongs in a GV.

If it represents mechanical calibration or established machine behavior,
it belongs in code.

### Safety logic stays simple

E-stop is read directly by each relevant Lua script.

No script should depend on another Lua script's output to recognize the
E-stop.

### Automatic behavior has one authority

Reverse operation in Groom uses a coordinated blade/tiller
reverse-clearance sequence.

`system.lua` owns permission for track reverse and determines when
sufficient clearance time has elapsed. `blade.lua` owns physical blade
reverse-lift movement, while `tiller.lua` owns physical tiller
reverse-lift movement.

Both implement scripts capture their own starting positions and return
independently to those positions after reverse.

Older competing behaviors such as an SH reverse override should not be
layered on top of this behavior.

### Preserve spare capacity

Unused Lua outputs and GVs are intentionally left available rather than
consumed simply because they exist.

`blade.lua` and `system.lua` currently use all six available outputs.
The two remaining Lua output slots are in `tiller.lua`.

------------------------------------------------------------------------

# Current Development Status

The control system is undergoing a consolidation from several
generations of working PB600 scripts.

The current architecture is intended to become the new baseline:

-   Simplified GV allocation
-   GV2 Blade Working Depth = 40%
-   GV3 Tiller Groom Depth = 35%
-   GV4 Reverse Lift Height = 10%
-   Direct Lua hardware outputs
-   Preserved time-based hydrostatic track behavior
-   Approximately 5-second acceleration to full power
-   Approximately 2-second hydrostatic deceleration
-   Unified blade/tiller coordination
-   Blade coordination rudder deadband = approximately 12%
-   Automatic blade and tiller reverse-clearance lift
-   Reverse blocked until both implements reach clearance
-   Blade and tiller return to their captured pre-reverse heights
-   Tiller rotor safety interlock throughout reverse lift, reverse
    operation, and return
-   E-stop across tracks, tiller rotor, blade, and tiller actuators
-   Explicit Transport / Plow / Groom transitions
-   Logical switches used for transmitter-local status/UI functions
    rather than primary machine-control logic
-   L11/L12 provide Blade/Tiller transition status without consuming
    receiver channels
-   Direction-specific 11-second-down / 17-second-up lift timing
-   Blade automatic transitions limited to Lift, Angle, and Wings
-   Tilt and Slew excluded from automatic blade mode transitions
-   Receiver failsafe forces tiller rotor channel to -1024/off
-   Effective drivetrain `Engine` output replaces raw throttle for
    sound-card Prop1
-   `system.lua` uses all six Lua outputs
-   Two Lua output slots remain available in `tiller.lua`

New functionality should be evaluated against this architecture before
additional GVs, logical switches, or Lua outputs are allocated.

------------------------------------------------------------------------

## Safety

This is hobby RC control software.

Always test new Lua scripts with the model safely supported and, where
practical, with track drive and high-power accessories disconnected.

Verify actuator direction, travel limits, E-stop behavior, and automatic
transitions before operating the model under load.
