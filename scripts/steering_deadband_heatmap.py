#!/usr/bin/env python3
"""Generate a heatmap showing the PB600 steering deadband behavior.

The intent is to make the expected behavior obvious:
- at low throttle, the deadband is small, so most of the row is active
- at high throttle, the deadband grows, so only larger rudder inputs respond
"""

from __future__ import annotations

import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

TURN_GAIN = 0.40
STEER_TAPER_START = 0.50
STEER_MIN_SCALE = 0.25
THROTTLE_DEADBAND_MIN = 0.020
THROTTLE_DEADBAND_MAX = 0.100


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def throttle_to_speed_demand(throttle: float) -> float:
    sign = -1 if throttle < 0 else 1
    x = clamp(abs(throttle), 0.0, 1.0)
    shaped = x * x * (3.0 - 2.0 * x)
    return shaped * sign


def speed_scale(vehicle_speed: float) -> float:
    vehicle_speed = clamp(vehicle_speed, 0.0, 1.0)
    if vehicle_speed <= STEER_TAPER_START:
        return 1.0
    t = clamp((vehicle_speed - STEER_TAPER_START) / (1.0 - STEER_TAPER_START), 0.0, 1.0)
    smooth = t * t * (3.0 - 2.0 * t)
    return 1.0 - (smooth * (1.0 - STEER_MIN_SCALE))


def simulate_turn(rudder: float, throttle: float) -> float:
    rud = clamp(rudder, -1.0, 1.0)
    thr = clamp(throttle, -1.0, 1.0)
    vehicle_speed = abs(throttle_to_speed_demand(thr))
    sscale = speed_scale(vehicle_speed)
    rud_curve = rud * abs(rud)

    throttle_norm = clamp(abs(thr), 0.0, 1.0)
    throttle_deadband = THROTTLE_DEADBAND_MIN + (THROTTLE_DEADBAND_MAX - THROTTLE_DEADBAND_MIN) * throttle_norm
    throttle_outside_deadband = clamp((throttle_norm - throttle_deadband) / max(1.0 - throttle_deadband, 0.001), 0.0, 1.0)
    throttle_response_scale = 0.25 + (0.75 * throttle_outside_deadband)

    return rud_curve * TURN_GAIN * sscale * throttle_response_scale


# Build a dense grid so the heatmap matches the actual steering model.
# Rows = throttle (0.0 to 1.0)
# Cols = rudder   (0.0 to 1.0)
step = 0.01
throttle_values = np.arange(0.0, 1.0 + step, step)
rudder_values = np.arange(0.0, 1.0 + step, step)
Z = np.zeros((len(throttle_values), len(rudder_values)))
for i, thr in enumerate(throttle_values):
    for j, rud in enumerate(rudder_values):
        Z[i, j] = simulate_turn(rud, thr)

# Need a color map that makes larger response darker blue, near-zero lighter.
# This matches the expectation: low throttle rows are mostly dark blue, high throttle rows only dark after the deadband threshold.
fig, ax = plt.subplots(figsize=(10, 6.2))
img = ax.imshow(
    Z,
    origin='lower',
    aspect='auto',
    cmap='Blues',
    vmin=0.0,
    vmax=0.30,
    extent=[0, 1, 0, 1],
)

# The model says the deadband is narrow at low throttle and expands with throttle.
# That means the dark/active portion of each row should dominate at low throttle,
# while only the right side of the row becomes active at high throttle.
for thr in [0.0, 0.25, 0.50, 0.75, 1.0]:
    throttle_deadband = THROTTLE_DEADBAND_MIN + (THROTTLE_DEADBAND_MAX - THROTTLE_DEADBAND_MIN) * abs(thr)
    y = thr
    x = throttle_deadband
    ax.plot([x, x], [0, 1], color='white', linestyle='--', linewidth=1.2, alpha=0.75)
    ax.text(x + 0.02, y + 0.02, f"{throttle_deadband:.2f}", color='white', fontsize=8, ha='left', va='bottom')

ax.set_title('PB600 steering deadband heatmap')
ax.set_xlabel('Rudder input (normalized)')
ax.set_ylabel('Throttle (normalized)')
ax.set_xticks([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
ax.set_yticks([0.0, 0.25, 0.5, 0.75, 1.0])
ax.set_xticklabels([f'{v:.1f}' for v in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]])
ax.set_yticklabels(['0%', '25%', '50%', '75%', '100%'])
ax.grid(False)

cbar = fig.colorbar(img, ax=ax, fraction=0.046, pad=0.04)
cbar.set_label('Turn contribution')

out_svg = Path(__file__).resolve().parent.parent / 'images' / 'steering_deadband_heatmap.svg'
out_svg.parent.mkdir(parents=True, exist_ok=True)
fig.tight_layout()
fig.savefig(out_svg, format='svg', dpi=220)
print(f'Wrote {out_svg}')
