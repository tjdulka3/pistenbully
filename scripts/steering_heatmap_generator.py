#!/usr/bin/env python3
"""Generate a steering contribution heatmap for all throttle and rudder combinations.

Shows turn ratio values across the full range of throttle (0-100%) and rudder (0-100%).
"""

from pathlib import Path
import math

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
except Exception as e:
    print(f"matplotlib not available: {e}")
    exit(1)

# Constants from system.lua
TRACK_CENTER_SPACING_FT = 3.0
PIVOT_RADIUS_FT = TRACK_CENTER_SPACING_FT / 2.0
FULL_TURN_RADIUS_FT = 10.0
LOW_SPEED_TURN_RATIO = 1.0
FULL_SPEED_TURN_RATIO = PIVOT_RADIUS_FT / FULL_TURN_RADIUS_FT

THROTTLE_DEADBAND_MIN = 0.02
THROTTLE_DEADBAND_MAX = 0.10
RUDDER_DEADBAND = 0.02


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def calculate_turn_ratio(throttle_norm, rudder_norm):
    """Calculate turn ratio for given throttle and rudder inputs."""
    
    # Rudder deadband (widens with throttle)
    deadband = THROTTLE_DEADBAND_MIN + (THROTTLE_DEADBAND_MAX - THROTTLE_DEADBAND_MIN) * throttle_norm
    
    # Effective rudder after deadband
    if rudder_norm > deadband:
        effective_rudder = (rudder_norm - deadband) / (1.0 - deadband)
    else:
        effective_rudder = 0.0
    
    # Full rudder turn ratio (decays with throttle)
    full_rudder_turn_ratio = LOW_SPEED_TURN_RATIO + (FULL_SPEED_TURN_RATIO - LOW_SPEED_TURN_RATIO) * throttle_norm
    
    # Final turn ratio
    turn_ratio = full_rudder_turn_ratio * effective_rudder
    
    return turn_ratio, effective_rudder, deadband


def main():
    # Create grid: 101x101 for 0-100% in 1% increments
    throttles = np.linspace(0, 1.0, 101)
    rudders = np.linspace(0, 1.0, 101)
    
    # Calculate turn ratios
    heatmap_data = np.zeros((101, 101))
    
    for i, thr in enumerate(throttles):
        for j, rud in enumerate(rudders):
            turn_ratio, _, _ = calculate_turn_ratio(thr, rud)
            heatmap_data[i, j] = turn_ratio
    
    # Create figure
    fig, ax = plt.subplots(figsize=(14, 12))
    
    # Plot heatmap
    im = ax.imshow(
        heatmap_data,
        cmap='RdYlGn',
        origin='lower',
        extent=[0, 100, 0, 100],
        aspect='auto',
        vmin=0,
        vmax=1.0
    )
    
    # Labels and title
    ax.set_xlabel('Rudder Input (%)', fontsize=12, fontweight='bold')
    ax.set_ylabel('Throttle Input (%)', fontsize=12, fontweight='bold')
    ax.set_title('PB600 Steering Contribution Heatmap\n(Turn Ratio by Throttle and Rudder)', 
                 fontsize=14, fontweight='bold')
    
    # Set ticks
    ax.set_xticks(np.arange(0, 101, 10))
    ax.set_yticks(np.arange(0, 101, 10))
    ax.set_xticklabels([f'{int(x)}%' for x in np.arange(0, 101, 10)])
    ax.set_yticklabels([f'{int(y)}%' for y in np.arange(0, 101, 10)])
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax, label='Turn Ratio (0.0 = straight, 1.0 = max turn)')
    
    # Add contour lines for key values
    contour_levels = [0.1, 0.2, 0.3, 0.5, 0.7, 0.9]
    contours = ax.contour(rudders * 100, throttles * 100, heatmap_data, 
                          levels=contour_levels, colors='black', alpha=0.3, linewidths=0.5)
    ax.clabel(contours, inline=True, fontsize=8, fmt='%.1f')
    
    # Add grid
    ax.grid(True, alpha=0.2, linestyle='--')
    
    plt.tight_layout()
    
    # Save
    output_dir = Path(__file__).resolve().parent.parent / 'images'
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / 'steering_contribution_heatmap.png'
    fig.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"✓ Saved heatmap to: {output_path}")
    
    # Also generate a table for reference
    print("\n" + "="*120)
    print("STEERING CONTRIBUTION TABLE (Turn Ratio)")
    print("="*120)
    print(f"{'Throttle':<12}", end='')
    for rud_pct in range(0, 101, 10):
        print(f"{rud_pct:>8}%", end='')
    print()
    print("-"*120)
    
    for thr_pct in range(0, 101, 5):
        thr = thr_pct / 100.0
        print(f"{thr_pct:>6}%     ", end='')
        for rud_pct in range(0, 101, 10):
            rud = rud_pct / 100.0
            turn_ratio, _, _ = calculate_turn_ratio(thr, rud)
            print(f"{turn_ratio:>8.3f}", end='')
        print()


if __name__ == '__main__':
    main()
