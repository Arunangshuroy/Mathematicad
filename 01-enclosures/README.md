# Parametric Electronics Enclosure

A fully parametric snap-fit enclosure for electronics prototyping and small-batch production.

## Files
| File | Purpose |
|------|---------|
| `parametric-enclosure.scad` | Main model — box body + snap-fit lid |
| `lid-with-snap-fit.scad` | Lid module extracted as standalone |
| `mounting-boss.scad` | Reusable M3 heat-insert boss module |

## Parameters (key)
| Variable | Default | Purpose |
|----------|---------|---------|
| `box_w / box_d / box_h` | 80 / 60 / 40 | Outer envelope (mm) |
| `wall_t` | 2.0 | Wall + floor thickness |
| `lid_h` | 10 | Lid portion of total height |
| `snap_depth` | 1.2 | Radial snap engagement |
| `snap_clearance` | 0.25 | Print fit clearance — tune per printer |
| `boss_od / boss_id` | 5.4 / 3.1 | M3 Ruthex RX-M3x5.7 heat-insert boss |
| `render_part` | "assembly" | `box` · `lid` · `assembly` · `section` |

## Print settings
Layer: 0.2 mm · Infill: 20% · Walls: 3 · Supports: None
