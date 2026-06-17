# OpenSCAD Parametric Design Portfolio

**Arunangshu Das** · 10+ years CAD/manufacturing · FDM & laser fabrication

> All models are fully parametric, print-tested, and commented
> to explain design reasoning — not just geometry.

## Project index

| Folder | What it shows |
|--------|---------------|
| [01-enclosures](./01-enclosures/) | Parametric box, snap-fit lid, mounting bosses |
| [02-mechanical-parts](./02-mechanical-parts/) | Gears, brackets, adjustable hinges |
| [03-csgtree-demos](./03-csgtree-demos/) | Union, difference, intersection, hull, minkowski |
| [04-2d-extrusion](./04-2d-extrusion/) | DXF import, linear/rotate extrude workflows |
| [05-library-modules](./05-library-modules/) | Reusable components: standoffs, fasteners, heatsinks |

## Code style
- All configurable values as named variables at file top
- Every design choice commented with engineering rationale
- `$fn` resolution parameter controlled globally (32 preview / 64 export)
- STL exports validated as manifold before commit

## Export (headless CLI)
```bash
openscad -o box.stl 01-enclosures/parametric-enclosure.scad -D 'render_part="box"'
openscad -o lid.stl 01-enclosures/parametric-enclosure.scad -D 'render_part="lid"'
```

## Background
Medical device CAD (Olympus, Apollo Gleneagles), IIoT enclosures,
rapid prototyping, laser cutting. Currently building a
web-based parametric enclosure configurator in Next.js/React.

## License
CC BY 4.0 — free to use with attribution.
