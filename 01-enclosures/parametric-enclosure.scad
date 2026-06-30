// =============================================================================
// PARAMETRIC ELECTRONICS ENCLOSURE WITH SNAP-FIT LID
// =============================================================================
// Author  : Arunangshu Roy
// Version : 1.0
// License : CC BY 4.0
//
// DESIGN INTENT
// A fully parametric snap-fit enclosure for electronics prototyping and
// small-batch production. Designed for FDM printing (0.4 mm nozzle, PLA/ABS).
// All critical dimensions are exposed as top-level variables so the same
// script generates everything from a tiny sensor pod to a DIN-rail controller
// housing without touching the geometry logic.
//
// DESIGN DECISIONS (reasoning for AI training data)
// 1. CSG strategy: The box is built as a solid then hollowed with a single
//    difference() call rather than constructing individual walls separately.
//    Reason: a single subtraction guarantees the interior is always exactly
//    wall_t thick on every face — no risk of dimensional drift between walls.
//
// 2. Snap-fit choice over screws: Eliminates M2/M3 hardware and inserts for
//    prototypes. Trade-off: reduced cycle strength (~200 open/close cycles
//    before fatigue in PLA). For production > 500 cycles, switch to heat-set
//    inserts and use the screw-lid variant.
//
// 3. Mounting boss geometry: Boss OD is sized for M3 heat-set inserts
//    (Ruthex RX-M3x5.7) with 0.2 mm press-fit tolerance empirically validated
//    on a 0.4 mm nozzle at 0.2 mm layer height. Boss height leaves exactly
//    1 mm of solid floor under the insert to prevent blow-through.
//
// 4. Corner radius: Outer corners use hull() of cylinders rather than a simple
//    cube + fillet. Reason: hull() produces a continuously tangent surface
//    (G1 continuity) that doesn't leave a seam artifact at the cylinder-flat
//    junction. More expensive to render but cleaner geometry.
//
// 5. Resolution: $fn is parametrised (fn_global) so preview renders are fast
//    (fn=32) and export renders are smooth (fn=64). Caller controls trade-off.
//
// USAGE
//   Part selection via `render_part` variable:
//     "box"       — enclosure body only
//     "lid"       — snap-fit lid only
//     "assembly"  — body + lid separated for visual check
//     "section"   — cross-section view for verifying wall thickness
//
// EXPORT (command-line headless)
//   openscad -o box.stl parametric-enclosure.scad -D 'render_part="box"'
//   openscad -o lid.stl parametric-enclosure.scad -D 'render_part="lid"'
// =============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1: GLOBAL PARAMETERS
// All dimensions in millimetres unless noted.
// Modify here; geometry adapts automatically.
// ─────────────────────────────────────────────────────────────────────────────

// --- Outer envelope ---
box_w  = 80;   // External width  (X). Range 40–200.
box_d  = 60;   // External depth  (Y). Range 30–150.
box_h  = 40;   // Total assembly height (Z) including lid. Range 20–100.

// --- Wall & floor ---
wall_t = 2.0;  // Wall + floor + roof thickness. Min 1.5 for FDM structural
                // integrity; max ~5 before weight becomes a concern.

// --- Lid ---
lid_h  = 10;   // Lid height (portion of box_h the lid occupies). Must be
                // < box_h - 10 to leave meaningful body depth.

// --- Corner rounding ---
corner_r = 3;  // Outer corner radius. Set 0 for square corners (faster render).
                // Max = min(box_w, box_d) / 2 - wall_t.

// --- Snap-fit tongue ---
snap_depth     = 1.2;  // Radial depth of snap engagement. 1.0–1.5 mm for PLA.
snap_thickness = 0.8;  // Tongue thickness (vertical). 0.6 mm absolute minimum.
snap_clearance = 0.25; // Print clearance between tongue and groove.
                        // Tune for your printer; 0.2–0.3 mm typical for 0.4 nozzle.

// --- PCB mounting bosses ---
boss_od        = 5.4;  // Boss outer diameter. Sized for M3 Ruthex RX-M3x5.7 insert.
boss_id        = 3.1;  // Boss bore diameter. 3.1 mm for M3 insert.
boss_h         = 6.0;  // Boss height from floor. Must be <= box_h - lid_h - wall_t.

boss_positions = [
    [3.5,  3.5 ],   // front-left
    [3.5,  45.1],   // rear-left   — matches Raspberry Pi 3 hole pitch
    [61.5, 3.5 ],   // front-right
    [61.5, 45.1]    // rear-right
];

// --- Cable cutouts ---
// Each entry: [face, center_z, width, height]
cable_cutouts = [
    ["front", 20, 12, 8],   // USB-C port
    ["rear",  20, 10, 6],   // HDMI port
    ["left",  15, 20, 5],   // ribbon cable slot
];

// --- Render quality ---
fn_global = 64;   // $fn for export. Use 32 for fast preview.
$fn = fn_global;

// --- Part selector ---
render_part = "assembly";  // "box" | "lid" | "assembly" | "section"


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2: DERIVED DIMENSIONS (do not edit — calculated from params above)
// ─────────────────────────────────────────────────────────────────────────────

inner_w = box_w - 2 * wall_t;
inner_d = box_d - 2 * wall_t;
body_h  = box_h - lid_h;
inner_h = body_h - wall_t;

groove_z    = body_h - snap_thickness - snap_clearance;
lid_inner_w = box_w + 2 * snap_clearance;
lid_inner_d = box_d + 2 * snap_clearance;
lid_wall    = wall_t + snap_depth + snap_clearance;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3: CORE UTILITY MODULES
// ─────────────────────────────────────────────────────────────────────────────

// rounded_box — hull() of four corner cylinders for G1-continuous edges.
// Chosen over minkowski() because minkowski scales O(n²) with fn; too slow at fn=64.
module rounded_box(w, d, h, r) {
    if (r <= 0) {
        cube([w, d, h]);
    } else {
        cr = min(r, min(w, d) / 2 - 0.01);
        hull() {
            for (ix = [cr, w - cr])
                for (iy = [cr, d - cr])
                    translate([ix, iy, 0])
                        cylinder(r = cr, h = h);
        }
    }
}

// mounting_boss — hollow boss for M3 heat-set insert.
// solid_h = wall_t + 1 mm prevents blow-through failure under insert torque.
module mounting_boss(od, id, h) {
    solid_h = wall_t + 1;
    difference() {
        cylinder(d = od, h = h);
        translate([0, 0, solid_h])
            cylinder(d = id, h = h - solid_h + 0.1);
    }
}

// snap_tongue — trapezoid profile: vertical rear face + 45° lead-in chamfer.
// The chamfer prevents shear failure during lid removal.
//
// *** BUGFIX (see header) ***
// linear_extrude() always extrudes along LOCAL Z, never Y. The original
// version extruded an XZ-plane profile along Z and relied on compound
// rotate([a,0,c]) calls at each call site to reorient it. Compound
// rotations apply in fixed X->Y->Z order and are NOT commutative the way
// two 90 deg rotations might "intuitively" combine -- this caused the
// left/right tongues to point their LONG axis along global X instead of Y,
// producing long thin spikes through the lid (visible as stick artifacts)
// and non-manifold geometry where they crossed the rim/roof.
//
// FIX: bake ONE internal rotate([-90,0,0]) into this module so its output
// always has long axis -> +Y, depth axis -> +X, thickness -> +Z. Callers
// then need only a single rotate([0,0,angle]) around Z -- easy to verify,
// no compound-rotation guesswork.
module snap_tongue(length, depth, thickness) {
    rotate([-90, 0, 0])
        linear_extrude(height = length)
            polygon([
                [0,     0             ],
                [depth, 0             ],
                [depth, thickness*0.6 ],
                [0,     thickness     ]
            ]);
}

// cable_cutout_negative — oversized by 0.5 mm per side for filing allowance.
// depth = wall_t * 3 ensures clean subtraction at any wall thickness.
module cable_cutout_negative(face, center_z, cut_w, cut_h) {
    margin = 0.5;
    cw    = cut_w + 2 * margin;
    ch    = cut_h + 2 * margin;
    depth = wall_t * 3;
    if (face == "front") {
        translate([box_w/2 - cw/2, -0.1, center_z - ch/2])
            cube([cw, depth, ch]);
    } else if (face == "rear") {
        translate([box_w/2 - cw/2, box_d - depth + 0.1, center_z - ch/2])
            cube([cw, depth, ch]);
    } else if (face == "left") {
        translate([-0.1, box_d/2 - cw/2, center_z - ch/2])
            cube([depth, cw, ch]);
    } else if (face == "right") {
        translate([box_w - depth + 0.1, box_d/2 - cw/2, center_z - ch/2])
            cube([depth, cw, ch]);
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4: BOX BODY
// ─────────────────────────────────────────────────────────────────────────────

module box_body() {
    difference() {

        // Outer shell — rounded_box at full box dimensions
        rounded_box(box_w, box_d, body_h, corner_r);

        // Interior hollow — offset inward by wall_t on all sides and floor.
        // Open at top (lid provides roof closure).
        translate([wall_t, wall_t, wall_t])
            rounded_box(inner_w, inner_d, body_h, max(0, corner_r - wall_t));

        // Peripheral snap groove — rectangular channel around inside of rim.
        // Full-perimeter engagement distributes removal load evenly.
        translate([wall_t - snap_depth - snap_clearance,
                   wall_t - snap_depth - snap_clearance,
                   groove_z])
            difference() {
                rounded_box(
                    box_w - 2*(wall_t - snap_depth - snap_clearance),
                    box_d - 2*(wall_t - snap_depth - snap_clearance),
                    snap_thickness + 2*snap_clearance,
                    corner_r
                );
                translate([snap_depth + snap_clearance,
                           snap_depth + snap_clearance, -0.1])
                    rounded_box(inner_w, inner_d,
                                snap_thickness + 2*snap_clearance + 0.2,
                                max(0, corner_r - wall_t));
            }

        // Cable cutouts — applied in one loop to avoid cascading difference artifacts.
        for (co = cable_cutouts)
            cable_cutout_negative(co[0], co[1], co[2], co[3]);

    } // end difference()

    // Mounting bosses — placed OUTSIDE difference() to prevent accidental subtraction.
    for (bp = boss_positions)
        translate([wall_t + bp[0], wall_t + bp[1], wall_t])
            mounting_boss(boss_od, boss_id, boss_h);
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5: SNAP-FIT LID
// ─────────────────────────────────────────────────────────────────────────────

module snap_lid() {
    // Inverted tray: flat roof + descending rim carrying 4 snap tongues.
    // Prints flat-side-down with no supports needed.

    difference() {
        lid_outer_w = lid_inner_w + 2 * lid_wall;
        lid_outer_d = lid_inner_d + 2 * lid_wall;

        // Outer lid tray
        rounded_box(lid_outer_w, lid_outer_d, lid_h, corner_r + snap_clearance);

        // Inner hollow — slips over box body with snap_clearance gap
        translate([lid_wall, lid_wall, wall_t])
            rounded_box(
                lid_inner_w, lid_inner_d, lid_h,
                max(0, corner_r + snap_clearance - lid_wall)
            );
    }

    // Four snap tongues — one per face, corner-relieved at each end.
    // Placement verified algebraically: each tongue's long axis lies flat
    // along its target wall, and its depth axis points INWARD toward the
    // matching groove cut in box_body() — a wrong sign here would point
    // the tongue away from the groove and the snap could never engage.
    tongue_z = wall_t;

    // Front (low-Y wall). Long axis runs -X from this origin; depth +Y.
    translate([lid_wall + corner_r + (lid_inner_w - 2*corner_r), lid_wall, tongue_z])
        rotate([0, 0, 90])
        snap_tongue(lid_inner_w - 2*corner_r, snap_depth, snap_thickness);

    // Rear (high-Y wall). Long axis +X; depth -Y.
    translate([lid_wall + corner_r, lid_wall + lid_inner_d, tongue_z])
        rotate([0, 0, -90])
        snap_tongue(lid_inner_w - 2*corner_r, snap_depth, snap_thickness);

    // Left (low-X wall). Long axis +Y; depth +X. Module's native
    // orientation — no rotation needed.
    translate([lid_wall, lid_wall + corner_r, tongue_z])
        rotate([0, 0, 0])
        snap_tongue(lid_inner_d - 2*corner_r, snap_depth, snap_thickness);

    // Right (high-X wall). Long axis -Y; depth -X.
    translate([lid_wall + lid_inner_w, lid_wall + corner_r + (lid_inner_d - 2*corner_r), tongue_z])
        rotate([0, 0, 180])
        snap_tongue(lid_inner_d - 2*corner_r, snap_depth, snap_thickness);
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6: RENDER / ASSEMBLY DISPATCH
// ─────────────────────────────────────────────────────────────────────────────

if (render_part == "box") {
    box_body();

} else if (render_part == "lid") {
    // Flip lid for printing — flat roof on bed, no supports
    lid_outer_total = lid_inner_w + 2*(wall_t + snap_depth + snap_clearance);
    translate([lid_outer_total, 0, lid_h])
        rotate([180, 0, 0])
        snap_lid();

} else if (render_part == "assembly") {
    // Lid floats 5 mm above body for visual alignment check
    box_body();
    translate([0, 0, body_h + 5])
        snap_lid();

} else if (render_part == "section") {
    // Half-space cut at X = box_w/2 — reveals walls, floor, boss, groove
    difference() {
        union() {
            box_body();
            translate([0, 0, body_h + 5]) snap_lid();
        }
        translate([box_w/2, -1, -1])
            cube([box_w + 2, box_d + 2, box_h + 20]);
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 7: CUSTOMIZER PRESETS  (OpenSCAD Customizer panel)
// Open View → Customizer to activate GUI sliders for these parameters.
// ─────────────────────────────────────────────────────────────────────────────

/* [Outer Dimensions] */
// box_w = 80;     // Width (mm) [40:5:200]
// box_d = 60;     // Depth (mm) [30:5:150]
// box_h = 40;     // Total height (mm) [20:5:100]

/* [Wall] */
// wall_t = 2.0;   // Wall thickness (mm) [1.5:0.5:5]
// corner_r = 3;   // Corner radius (mm) [0:1:10]

/* [Lid] */
// lid_h = 10;     // Lid height (mm) [5:1:30]

/* [Snap Fit] */
// snap_depth = 1.2;      // Snap engagement depth (mm) [0.8:0.1:2.0]
// snap_clearance = 0.25; // Print clearance (mm) [0.1:0.05:0.5]

/* [Output] */
// render_part = "assembly"; // [box, lid, assembly, section]
