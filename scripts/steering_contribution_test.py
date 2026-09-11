#!/usr/bin/env python3
"""Simulate the PB600 steering mixer across throttle and rudder values.

This reproduces the logic in scripts/mixes/system.lua to answer the question:
why does steering appear to collapse at higher speed, and how much turn authority
remains at different throttle/rudder combinations?
"""

from __future__ import annotations

import math
from pathlib import Path

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover
    plt = None

TURN_GAIN = 0.40
STEER_TAPER_START = 0.50
STEER_MIN_SCALE = 0.25
PIVOT_BLEND_END = 0.80
THROTTLE_DEADBAND_MIN = 0.005
THROTTLE_DEADBAND_MAX = 0.050


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


def simulate_turn(rudder: float, throttle: float) -> tuple[float, float, float, float, float]:
    """Return: turn, left, right, differential, speed_scale."""
    rud = clamp(rudder, -1.0, 1.0)
    thr = clamp(throttle, -1.0, 1.0)
    vehicle_speed = abs(throttle_to_speed_demand(thr))
    sscale = speed_scale(vehicle_speed)

    rud_curve = rud * abs(rud)

    throttle_norm = clamp(abs(thr), 0.0, 1.0)
    throttle_deadband = THROTTLE_DEADBAND_MIN + (THROTTLE_DEADBAND_MAX - THROTTLE_DEADBAND_MIN) * throttle_norm
    throttle_outside_deadband = clamp((throttle_norm - throttle_deadband) / max(1.0 - throttle_deadband, 0.001), 0.0, 1.0)
    throttle_response_scale = 0.25 + (0.75 * throttle_outside_deadband)

    turn = rud_curve * TURN_GAIN * sscale * throttle_response_scale

    pivot_blend = clamp(abs(thr) / PIVOT_BLEND_END, 0.0, 1.0)
    drive_throttle = throttle_to_speed_demand(thr)

    drive_left = drive_throttle * (1.0 + turn * 0.7)
    drive_right = drive_throttle * (1.0 - turn * 0.4)

    pivot_left = turn
    pivot_right = -turn

    left = (drive_left * pivot_blend) + (pivot_left * (1.0 - pivot_blend))
    right = (drive_right * pivot_blend) + (pivot_right * (1.0 - pivot_blend))

    differential = left - right
    return turn, left, right, differential, sscale


def make_table() -> list[tuple[float, float, float, float, float, float, float]]:
    rows: list[tuple[float, float, float, float, float, float, float]] = []
    for throttle in [i / 10.0 for i in range(11)]:
        for rudder in [i / 10.0 for i in range(11)]:
            turn, left, right, differential, sscale = simulate_turn(rudder, throttle)
            rows.append((throttle, rudder, turn, left, right, differential, sscale))
    return rows


def print_table() -> None:
    print("Throttle | Rudder | speedScale | turn | left | right | differential")
    print("---------|--------|------------|------|------|-------|--------------")
    for throttle, rudder, turn, left, right, differential, sscale in make_table():
        if rudder in (0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0):
            pass
        print(f"{throttle:>8.1f} | {rudder:>6.1f} | {sscale:>10.3f} | {turn:>4.3f} | {left:>4.3f} | {right:>5.3f} | {differential:>12.3f}")


def plot_turns() -> None:
    if plt is None:
        print("matplotlib not available; skipping plot generation.")
        return

    rudders = [i / 10.0 for i in range(11)]
    fig, ax = plt.subplots(figsize=(10, 6))

    for throttle in [i / 10.0 for i in range(11)]:
        values = []
        for rudder in rudders:
            turn, _, _, _, _ = simulate_turn(rudder, throttle)
            values.append(turn)
        ax.plot(rudders, values, label=f"thr {throttle:.1f}")

    ax.set_title("PB600 simulated steering contribution vs rudder")
    ax.set_xlabel("Rudder input (0.0 to 1.0)")
    ax.set_ylabel("Steering contribution turn")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 0.45)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="upper left", fontsize=8)

    out = Path(__file__).resolve().parent.parent / "images" / "steering_contribution_test.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out, dpi=180)
    print(f"Saved plot to: {out}")


if __name__ == "__main__":
    print_table()
    print()
    print("Key observations:")
    for throttle in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
        rudder = 1.0
        turn, left, right, differential, sscale = simulate_turn(rudder, throttle)
        print(f"  throttle={throttle:.1f}, rudder=1.00 => speedScale={sscale:.3f}, turn={turn:.3f}, left={left:.3f}, right={right:.3f}, diff={differential:.3f}")
    print()
    plot_turns()
