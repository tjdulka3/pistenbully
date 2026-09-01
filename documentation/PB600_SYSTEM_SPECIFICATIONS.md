# PB600 Snowcat System Specifications

Quick-reference specification for the RadioMaster TX16S MK3 / EdgeTX
PistenBully 600 RC control system.

## Table of Contents

-   [1. Platform](#1-platform)
-   [2. Transmitter Input Assignments](#2-transmitter-input-assignments)
-   [3. Physical Channel Map](#3-physical-channel-map)
-   [4. Lua Output Allocation](#4-lua-output-allocation)
-   [5. Implement Specifications](#5-implement-specifications)
-   [6. Position Model Ranges](#6-position-model-ranges)
-   [7. Mode Targets](#7-mode-targets)
-   [8. Global Variables](#8-global-variables)
-   [9. Coordination Parameters](#9-coordination-parameters)
-   [10. Track / Hydrostatic
    Parameters](#10-track-hydrostatic-parameters)
-   [11. Reverse Clearance Parameters](#11-reverse-clearance-parameters)
-   [12. Logical Switches](#12-logical-switches)
-   [13. Sound System Specifications](#13-sound-system-specifications)
-   [14. Lighting Channels](#14-lighting-channels)
-   [15. Tiller Rotor Specification](#15-tiller-rotor-specification)
-   [16. Safety Specifications](#16-safety-specifications)
-   [17. Receiver / Signal Notes](#17-receiver-signal-notes)
-   [18. Configuration Ownership](#18-configuration-ownership)

## 1. Platform

  ---------------------------------------------------------------------
  Item                               Specification
  ---------------------------------- ----------------------------------
  Model                              PistenBully 600 scale snowcat

  Transmitter                        RadioMaster TX16S MK3

  Firmware                           EdgeTX

  Stick Mode                         Mode 2

  Physical channel capacity          32 channels with backpack receiver
                                     arrangement

  Custom mixer scripts               `system.lua`, `blade.lua`,
                                     `tiller.lua`

  Sound module                       DasMikro TBS Mini
  ---------------------------------------------------------------------

## 2. Transmitter Input Assignments

  Input       Assignment
  ----------- ----------------------------------------------------
  Thr         Track forward / reverse
  Rud         Track steering; blade/tiller coordination input
  AIL         Context-sensitive implement control selected by SC
  ELE         Context-sensitive implement control selected by SC
  SC Up       AIL = Blade Tilt; ELE = Blade Lift
  SC Middle   AIL = Blade Slew; ELE = Blade Angle
  SC Down     AIL = Tiller Angle; ELE = Tiller Lift
  SD Up       Transport
  SD Middle   Plow
  SD Down     Groom
  SB Up       Coordination enabled
  SF Up       E-stop
  LS          Left blade wing
  RS          Right blade wing
  SE          Left tiller finisher
  SG          Right tiller finisher
  S1          Tiller rotor speed
  S2          Tiller swing servo
  SA Up       Reverse beep
  SA Middle   No auxiliary sound
  SA Down     Horn

## 3. Physical Channel Map

    Channel Function                Source / Control
  --------- ----------------------- ---------------------------------
        CH1 Left Track              `LUA:System:TrackL`
        CH2 Blade Lift              `LUA:Blade:Lift`
        CH3 Right Track             `LUA:System:TrackR`
        CH4 Blade Tilt              `LUA:Blade:Tilt`
        CH5 Left Blade Wing         `LUA:Blade:LW`
        CH6 Right Blade Wing        `LUA:Blade:RW`
        CH7 Left Tiller Finisher    `LUA:Tiller:FinL`
        CH8 Right Tiller Finisher   `LUA:Tiller:FinR`
        CH9 Tiller Swing Servo      S2 / standard EdgeTX mix
       CH10 Blade Angle             `LUA:Blade:Angle`
       CH11 Blade Slew              `LUA:Blade:Slew`
       CH12 Tiller Lift             `LUA:Tiller:TLift`
       CH13 Tiller Angle            `LUA:Tiller:TAng`
       CH14 Tiller Rotor Motor      S1 gated by `LUA:System:TMotor`
       CH15 TBS Prop1 / Engine      `LUA:System:EngOut`
       CH16 TBS Prop2 / Aux Sound   SA + L08/L09
       CH17 Headlights              Lighting control
       CH18 Warning Lights          Lighting control
       CH19 Spot Lights             Lighting control

## 4. Lua Output Allocation

### system.lua

    \# Output     Use
  ---- ---------- --------------------------------------------
     1 `TrackL`   Left track command
     2 `TrackR`   Right track command
     3 `TMotor`   Tiller rotor permission / lockout
     4 `TranB`    Blade transition state; transmitter-local
     5 `TranT`    Tiller transition state; transmitter-local
     6 `EngOut`   Effective drivetrain signal for sound card

### blade.lua

    \# Output    Physical Function
  ---- --------- -------------------
     1 `Lift`    Blade lift
     2 `Tilt`    Blade tilt
     3 `Angle`   Blade angle
     4 `Slew`    Blade slew
     5 `LW`      Left wing
     6 `RW`      Right wing

### tiller.lua

    \# Output    Physical Function
  ---- --------- -------------------
     1 `TAng`    Tiller angle
     2 `TLift`   Tiller lift
     3 `FinL`    Left finisher
     4 `FinR`    Right finisher

## 5. Implement Specifications

### Blade

  -----------------------------------------------------------------------
  Function            Channel Manual          Full-Travel  Direction Sign
                              Input           Calibration 
  ----------- --------------- ----------- --------------- ---------------
  Lift                    CH2 SC Up + ELE   Down 11.0 s /              -1
                                                Up 17.0 s 

  Tilt                    CH4 SC Up + AIL           5.0 s              +1

  Angle                  CH10 SC Middle +           6.7 s              +1
                              ELE                         

  Slew                   CH11 SC Middle +           6.7 s              +1
                              AIL                         

  Left Wing               CH5 LS                   3.75 s              +1

  Right Wing              CH6 RS                   3.75 s              +1
  -----------------------------------------------------------------------

### Tiller

  -----------------------------------------------------------------------
  Function            Channel Manual          Full-Travel  Direction Sign
                              Input           Calibration 
  ----------- --------------- ----------- --------------- ---------------
  Lift             Configured SC Down +     Down 11.0 s /              -1
                  tiller lift ELE               Up 17.0 s 
                      channel                             

  Angle                  CH13 SC Down +            3.75 s              +1
                              AIL                         

  Left                    CH7 SE                    2.0 s             ---
  Finisher                                                

  Right                   CH8 SG                    2.0 s             ---
  Finisher                                                

  Swing                   CH9 S2                    Servo             ---

  Rotor                  CH14 S1              ESC / motor             ---
                                               controller 
  -----------------------------------------------------------------------

## 6. Position Model Ranges

  Function        Minimum   Maximum Meaning
  ------------- --------- --------- -----------------------------
  Blade Lift           -1         0 -1 = full down; 0 = full up
  Blade Wings           0         1 0 = closed; 1 = fully open
  Tiller Lift          -1         0 -1 = full down; 0 = full up

**Wing position tracking must be clamped to `0..1`.**

## 7. Mode Targets

  -----------------------------------------------------------------------
  Mode              SD                Blade             Tiller
  ----------------- ----------------- ----------------- -----------------
  Transport         Up                Lift up; angle    Raised
                                      returned; wings   
                                      closed            

  Plow              Middle            Working           Raised
                                      depth/angle;      
                                      wings open        

  Groom             Down              Same normal blade Groom depth/angle
                                      working geometry  
                                      as Plow           
  -----------------------------------------------------------------------

### Blade Working Constants

  Constant             Value
  ------------------ -------
  `WORK_WING_OPEN`      0.40
  `WORK_ANGLE`         -0.50
  Working Depth          GV2

### Automatic Blade Transition Axes

  Axis         Automatic Transport ↔ Work
  ------------ ----------------------------
  Lift         Yes
  Angle        Yes
  Left Wing    Yes
  Right Wing   Yes
  Tilt         No
  Slew         No

## 8. Global Variables

     GV Parameter                     Starting Value
  ----- --------------------------- ----------------
    GV1 Coordination Intensity                   60%
    GV2 Blade Working Depth                      40%
    GV3 Tiller Groom Depth                       35%
    GV4 Blade/Tiller Reverse Lift                10%
    GV5 Tiller Working Angle                     50%
    GV6 Reserved                                 ---
    GV7 Reserved                                 ---
    GV8 Reserved                                 ---
    GV9 Reserved                                 ---

## 9. Coordination Parameters

  Parameter                            Value
  ---------------------------------- -------
  Blade/Tiller coordination master       GV1
  Implement rudder deadband             0.12
  Track rudder deadband                 0.02
  `COORD_WING_RANGE`                    0.15
  `COORD_SLEW_RANGE`                    0.12
  `COORD_TILT_RANGE`                    0.08
  `COORD_ANGLE_RANGE`                   0.10

Coordination is disabled during automatic mode transitions and
reverse-clearance movement.

## 10. Track / Hydrostatic Parameters

  Parameter             Value Function
  ------------------- ------- ----------------------------------------------
  `TURN_GAIN`            0.25 Base differential steering strength
  `SPEED_FACTOR`         0.60 Steering reduction as track speed increases
  `RUDDER_DEADBAND`      0.02 Track steering deadband
  `ACCEL_RATE`            205 Approx. 5 s zero-to-full acceleration
  `DECEL_RATE`            512 Approx. 2 s full-to-zero deceleration
  `REVERSE_BOOST`         250 Faster pressure dump during direction change

## 11. Reverse Clearance Parameters

  -----------------------------------------------------------------------
  Parameter                          Value / Source
  ---------------------------------- ------------------------------------
  Reverse lift amount                GV4

  Blade lift multiplier              `BLADE_REVERSE_LIFT_FACTOR = 1.00`

  Blade full UP time                 17.0 s

  Blade full DOWN time               11.0 s

  Tiller full UP time                17.0 s

  Tiller full DOWN time              11.0 s

  Reverse release condition          Slower of blade/tiller clearance
                                     times completed

  Return target                      Captured pre-reverse position for
                                     each implement

  Tiller rotor during reverse cycle  Locked out
  -----------------------------------------------------------------------

At GV4 = 10% and blade factor = 1.00:

  Movement                    Nominal Time
  ------------------------- --------------
  Blade reverse lift                1.70 s
  Tiller reverse lift               1.70 s
  Reverse clearance delay           1.70 s
  10% downward return             \~1.10 s

## 12. Logical Switches

  -----------------------------------------------------------------------
  Logical Switch          Configuration           Use
  ----------------------- ----------------------- -----------------------
  L08                     `Thr < -5`              Reverse requested

  L09                     Timer; V1 = 0.4, V2 =   Intermittent reverse
                          0.8; Switch = L08       beep

  L11                     System `TranB` state    Blade transition active

  L12                     System `TranT` state    Tiller transition
                                                  active
  -----------------------------------------------------------------------

Lua logical-switch indexes are zero-based:

``` lua
getLogicalSwitchValue(10) -- L11
getLogicalSwitchValue(11) -- L12
```

Return type is boolean `true` / `false`.

## 13. Sound System Specifications

  Item           Specification
  -------------- --------------------------------------------
  Module         DasMikro TBS Mini
  Firmware       4.0.0.0
  Sound set      Pistenbully, Sound Library Update Oct 2020
  Prop1          CH15 / effective engine signal
  Prop2          CH16 / auxiliary sounds
  Prop3          Not connected
  Engine start   Automatic

### Prop2 Functions

  SA Position / Logic   Sound
  --------------------- ----------------------------------------------------
  SA Up                 Reverse beep
  SA Middle             None
  SA Down               Horn
  L08 + L09             Toggles reverse-beep command at 0.4 / 0.8 s timing

## 14. Lighting Channels

    Channel Function
  --------- ----------------
       CH17 Headlights
       CH18 Warning lights

## 15. Tiller Rotor Specification

  Item                   Specification
  ---------------------- ----------------------
  Physical channel       CH14
  Operator input         S1
  Lua safety source      `System:TMotor`
  S1 = -1024             0% motor power
  S1 = 0                 \~50% motor power
  S1 = +1024             100% motor power
  Required OFF command   -1024
  Receiver failsafe      CH14 = -1024 / -100%

Because S1 zero represents approximately 50% motor power, the tiller
rotor cannot be safely disabled by multiplying the S1 command by zero.
The final channel command must be forced to `-1024`.

## 16. Safety Specifications

  -------------------------------------------------------------------------
  Condition     TrackL/R      Blade/Tiller   Tiller Rotor    Engine Output
                              Motion                         
  ------------- ------------- -------------- --------------- --------------
  Normal        Enabled       Enabled        S1-controlled   Effective
                                             when permitted  track average

  E-stop        0             Stopped        -1024 / OFF     0
  (`SF Up`)                                                  

  Reverse       0             Blade/tiller   OFF             Near idle
  clearance                   lift active                    
  lifting                                                    

  Reverse       Reverse       Clearance      OFF             Follows
  backing       enabled       positions held                 effective
                                                             tracks

  Reverse       As system     Blade/tiller   OFF             Follows
  return        state permits returning                      effective
                                                             tracks
  -------------------------------------------------------------------------

## 17. Receiver / Signal Notes

  ---------------------------------------------------------------------
  Item                               Specification
  ---------------------------------- ----------------------------------
  Extended physical channels         Backpack arrangement provides
                                     access through CH32

  CH14 failsafe                      Must be explicitly set to -100%;
                                     do not use Hold

  CH17                               Headlights

  CH18                               Warning lights

  Transition state channels          Not physically assigned; use
                                     L11/L12 locally
  ---------------------------------------------------------------------

## 18. Configuration Ownership

  Parameter Type                Location
  ----------------------------- ----------------------------
  Live operator tuning          Global Variables
  Track behavior                `system.lua` constants
  Blade calibration             `blade.lua` constants
  Tiller calibration            `tiller.lua` constants
  Channel/mix assignments       EdgeTX model configuration
  Transition state conversion   Logical switches L11/L12
  Sound auxiliary sequencing    L08/L09 + CH16 mix

### Candidate Shared Constants for Future Consolidation

``` text
Blade/tiller lift travel times
Wing travel time
Coordination rudder deadband
Coordination ranges
Blade reverse-lift factor
Hydrostatic acceleration/deceleration rates
TURN_GAIN
SPEED_FACTOR
Reverse threshold
```
