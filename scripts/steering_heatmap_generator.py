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
TURN_GAIN = 1.0
STEER_YAW_PEAK = 0.50
STEER_YAW_FULL = PIVOT_RADIUS_FT / FULL_TURN_RADIUS_FT
STEER_TAPER_START = 0.75
PIVOT_POWER = 0.70
PIVOT_BLEND_START = 0.15
PIVOT_BLEND_END = 0.20
THROTTLE_DEADBAND_MIN = 0.02
THROTTLE_DEADBAND_MAX = 0.10
RUDDER_DEADBAND = 0.02


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def track_commands(thr, rud):
    """Return (left, right, turn_radius_ft) for signed throttle and rudder in -1..1."""
    if abs(rud) < RUDDER_DEADBAND:
        rud = 0.0

    thr_norm = abs(thr)
    deadband = THROTTLE_DEADBAND_MIN + (THROTTLE_DEADBAND_MAX - THROTTLE_DEADBAND_MIN) * thr_norm

    eff = 0.0
    if abs(rud) > deadband:
        eff = (abs(rud) - deadband) / (1.0 - deadband)
        if rud < 0:
            eff = -eff

    drive = 0.0 if thr_norm <= PIVOT_BLEND_START else (1.0 if thr > 0 else -1.0) * (thr_norm - PIVOT_BLEND_START) / (1.0 - PIVOT_BLEND_START)

    pivot_rudder = eff

    if thr_norm <= PIVOT_BLEND_START:
        blend = 1.0
    elif thr_norm < PIVOT_BLEND_END:
        blend = 1.0 - (thr_norm - PIVOT_BLEND_START) / (PIVOT_BLEND_END - PIVOT_BLEND_START)
    else:
        blend = 0.0
    pivot = pivot_rudder * PIVOT_POWER * blend

    envelope = STEER_YAW_PEAK
    if thr_norm > STEER_TAPER_START:
        envelope += (STEER_YAW_FULL - STEER_YAW_PEAK) * (thr_norm - STEER_TAPER_START) / (1.0 - STEER_TAPER_START)
    diff = eff * envelope * TURN_GAIN * (1.0 - blend) * (-1.0 if thr < 0 else 1.0)

    left = clamp(drive + pivot + diff, -1.0, 1.0)
    right = clamp(drive - pivot - diff, -1.0, 1.0)

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
        for edge in (-PIVOT_BLEND_START * 100, PIVOT_BLEND_START * 100):
            ax.axhline(edge, color="black", linestyle="--", linewidth=0.8, alpha=0.6)
        ax.set_title(title, fontweight="bold")
        ax.set_xlabel("Rudder (%)")
        ax.set_ylabel("Throttle (%)")
        ax.grid(True, alpha=0.2, linestyle="--")
        fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    fig.suptitle("PB600 Steering Model (pivot zone +/-15% throttle, dashed)", fontsize=14, fontweight="bold")
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
