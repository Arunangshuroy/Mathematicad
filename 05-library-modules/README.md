# Reusable Component Library

Drop-in modules for common hardware — use with `use <../05-library-modules/fasteners.scad>`.

## Files
| File | Provides |
|------|---------|
| `fasteners.scad` | M2/M3/M4 clearance holes, counterbores, heat-insert bores |
| `heatsink.scad` | Parametric fin array — fin count, height, spacing, base thickness |
| `pcb-standoffs.scad` | PCB standoffs for M2.5/M3 screws, configurable height and bore |

## Usage
```scad
use <../05-library-modules/pcb-standoffs.scad>
standoff(h=8, od=5, id=2.7);
```
