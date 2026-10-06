#!/usr/bin/env python3
"""Steady-state track output heatmaps mirroring the steering model in mixes/system.lua.

Plots left track, right track and yaw (L-R)/2 over throttle (-100..100%) and rudder (-100..100%).
Hydrostatic smoothing and reverse lockouts are not modeled.
"""

from pathlib import Path

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
except Exception as e:
    print(f"matplotlib not available: {e}")
    raise SystemExit(1)

# Constants from system.lua
TRACK_CENTER_SPACING_FT = 3.0
PIVOT_RADIUS_FT = TRACK_CENTER_SPACING_FT / 2.0
FULL_TURN_RADIUS_FT = 6.0
STEER_GAIN_LOW = 0.70
STEER_GAIN_FULL = PIVOT_RADIUS_FT / FULL_TURN_RADIUS_FT
STEER_TAPER_START = 0.75
DRIVE_DEADBAND = 0.05
RUDDER_DEADBAND = 0.01
RUDDER_DB_MIN = 0.01
RUDDER_DB_KNEE = 0.80
RUDDER_DB_KNEE_VALUE = 0.06
RUDDER_DB_MAX = 0.20


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def track_commands(thr, rud):
    """Return (left, right, turn_radius_ft) for signed throttle and rudder in -1..1."""
    if abs(rud) < RUDDER_DEADBAND:
        rud = 0.0

    thr_norm = abs(thr)
    if thr_norm <= RUDDER_DB_KNEE:
        deadband = RUDDER_DB_MIN + (RUDDER_DB_KNEE_VALUE - RUDDER_DB_MIN) * thr_norm / RUDDER_DB_KNEE
    else:
        deadband = RUDDER_DB_KNEE_VALUE + (RUDDER_DB_MAX - RUDDER_DB_KNEE_VALUE) * (thr_norm - RUDDER_DB_KNEE) / (1.0 - RUDDER_DB_KNEE)

    eff = 0.0
    if abs(rud) > deadband:
        eff = (abs(rud) - deadband) / (1.0 - deadband)
        if rud < 0:
            eff = -eff

    drive = 0.0 if thr_norm <= DRIVE_DEADBAND else (1.0 if thr > 0 else -1.0) * (thr_norm - DRIVE_DEADBAND) / (1.0 - DRIVE_DEADBAND)

    speed = abs(drive)
    gain = STEER_GAIN_LOW
    if speed > STEER_TAPER_START:
        gain += (STEER_GAIN_FULL - STEER_GAIN_LOW) * (speed - STEER_TAPER_START) / (1.0 - STEER_TAPER_START)
    steer = eff * gain

    left = drive + steer
    right = drive - steer
    if left > 1.0:
        right -= left - 1.0
        left = 1.0
    elif left < -1.0:
        right -= left + 1.0
        left = -1.0
    if right > 1.0:
        left -= right - 1.0
        right = 1.0
    elif right < -1.0:
        left -= right + 1.0
        right = -1.0

    diff = abs(left - right) / 2.0
    radius = float("inf") if diff < 1e-6 else abs(left + right) / 2.0 / diff * PIVOT_RADIUS_FT
    return left, right, radius


def main():
    axis = np.linspace(-1.0, 1.0, 201)
    left = np.zeros((axis.size, axis.size))
    right = np.zeros_like(left)
    for i, thr in enumerate(axis):
        for j, rud in enumerate(axis):
            left[i, j], right[i, j], _ = track_commands(thr, rud)
    yaw = (left - right) / 2.0

    fig, axes = plt.subplots(1, 3, figsize=(21, 7))
    panels = [
        (left, "Left Track Output", "RdBu_r", -1.0, 1.0),
        (right, "Right Track Output", "RdBu_r", -1.0, 1.0),
        (yaw, "Yaw Command (L - R) / 2", "PuOr", -1.0, 1.0),
    ]
    for ax, (data, title, cmap, vmin, vmax) in zip(axes, panels):
        im = ax.imshow(data, cmap=cmap, origin="lower", extent=[-100, 100, -100, 100],
                       aspect="equal", vmin=vmin, vmax=vmax)
        ax.contour(axis * 100, axis * 100, data, levels=[-0.5, -0.25, 0.25, 0.5],
                   colors="black", alpha=0.35, linewidths=0.5)
        for edge in (-DRIVE_DEADBAND * 100, DRIVE_DEADBAND * 100):
            ax.axhline(edge, color="black", linestyle="--", linewidth=0.8, alpha=0.6)
        ax.set_title(title, fontweight="bold")
        ax.set_xlabel("Rudder (%)")
        ax.set_ylabel("Throttle (%)")
        ax.grid(True, alpha=0.2, linestyle="--")
        fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    fig.suptitle("PB600 Steering Model (drive deadband +/-5% throttle, dashed)", fontsize=14, fontweight="bold")
    fig.tight_layout()

    output_dir = Path(__file__).resolve().parent.parent / "images"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "steering_contribution_heatmap.png"
    fig.savefig(output_path, dpi=130, bbox_inches="tight")
    print(f"Saved heatmap to: {output_path}")

    print("\nFull-rudder track outputs vs throttle (right rudder)")
    print(f"{'Throttle':>9}{'Left':>8}{'Right':>8}{'Radius ft':>11}")
    for thr_pct in range(0, 101, 5):
        l, r, rad = track_commands(thr_pct / 100.0, 1.0)
        print(f"{thr_pct:>8}%{l:>8.2f}{r:>8.2f}{rad:>11.2f}")


if __name__ == "__main__":
    main()
