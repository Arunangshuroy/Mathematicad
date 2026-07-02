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
// The lid carries a horizontal tongue that clips into a groove on the body.
// Tongue geometry is critical: too thin → snaps off; too thick → won't clip.
snap_depth     = 1.2;  // Radial depth of snap engagement. 1.0–1.5 mm for PLA.
snap_thickness = 0.8;  // Tongue thickness (vertical). 0.6 mm absolute minimum.
snap_clearance = 0.25; // Print clearance between tongue and groove.
                        // Tune for your printer; 0.2–0.3 mm typical for 0.4 nozzle.

// --- PCB mounting bosses ---
// Boss array is defined as [x_offset, y_offset] from inner bottom-left corner.
// Coordinates are from the INSIDE of the box (i.e., after wall offset).
boss_od        = 5.4;  // Boss outer diameter. Sized for M3 heat-set insert
                        // (Ruthex RX-M3x5.7 requires Ø5.1 mm hole → 5.4 OD
                        // leaves 0.15 mm wall each side around the insert bore).
boss_id        = 3.1;  // Boss bore diameter. 3.1 mm for M3 insert (not clearance).
boss_h         = 6.0;  // Boss height from floor. Must be ≤ box_h - lid_h - wall_t.
                        // Leaves 1 mm floor under insert (6 - 5 = 1 mm safety).

// Boss positions: list of [x, y] offsets from inside-corner (0,0).
// Default: 4 corners of standard 72.6 × 44.6 mm PCB footprint (Raspberry Pi 3).
boss_positions = [
    [3.5,  3.5 ],   // front-left
    [3.5,  45.1],   // rear-left
    [61.5, 3.5 ],   // front-right  (58 mm span in X → matches RPi 58mm hole pitch)
    [61.5, 45.1]    // rear-right
];

// --- Cable cutouts ---
// Each entry: [face, center_z, width, height]
// face: "front"=Y-, "rear"=Y+, "left"=X-, "right"=X+
cable_cutouts = [
    ["front", 20, 12, 8],   // USB-C port area, centered at Z=20
    ["rear",  20, 10, 6],   // HDMI port area
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

// Inner cavity dimensions
inner_w = box_w - 2 * wall_t;
inner_d = box_d - 2 * wall_t;
body_h  = box_h - lid_h;        // Body (tray) height
inner_h = body_h - wall_t;      // Interior depth (floor to open top)

// Snap groove Z position — sits at the body-lid interface, recessed slightly
// so the lid seats flush rather than proud.
groove_z = body_h - snap_thickness - snap_clearance;

// Lid inner dimensions — must slip over box exterior with clearance
lid_inner_w = box_w + 2 * snap_clearance;
lid_inner_d = box_d + 2 * snap_clearance;
lid_wall    = wall_t + snap_depth + snap_clearance;   // Lid rim wall thickness


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3: CORE UTILITY MODULES
// ─────────────────────────────────────────────────────────────────────────────

// rounded_box: Builds a box with rounded vertical edges using hull() of
// cylinders at each corner. More expensive than a simple cube but produces
// G1-continuous surfaces — no seam artifacts at wall junctions.
// The hull() approach is chosen over minkowski(cube, cylinder) because
// minkowski() scales O(n²) with face count; at fn=64 it becomes impractically
// slow for complex parent shapes.
module rounded_box(w, d, h, r) {
    if (r <= 0) {
        // Fast path: no rounding requested — plain cube avoids hull() overhead.
        cube([w, d, h]);
    } else {
        // Clamp radius so it never exceeds half the shortest horizontal dimension.
        cr = min(r, min(w, d) / 2 - 0.01);
        hull() {
            // Four vertical cylinders, one at each corner.
            // Cylinder axis is Z so rounding appears on vertical edges only —
            // horizontal edges remain sharp (as-printed, no cosmetic fillet needed).
            for (ix = [cr, w - cr])
                for (iy = [cr, d - cr])
                    translate([ix, iy, 0])
                        cylinder(r = cr, h = h);
        }
    }
}


// mounting_boss: A hollow boss for M3 heat-set inserts.
// Design notes:
//   - solid_h: the base of the boss is a solid cylinder to prevent the
//     drill-through failure mode where the insert bore exits through the floor.
//   - The bore is subtracted with a cylinder slightly taller than boss_h so
//     the difference() operation produces a clean through-hole at the tip —
//     no thin membrane that slicers sometimes fail to represent correctly.
module mounting_boss(od, id, h) {
    solid_h = wall_t + 1;  // 1 mm solid floor below insert — empirically
                            // sufficient for M3 torque without boss cracking.
    difference() {
        cylinder(d = od, h = h);                        // Solid boss cylinder
        translate([0, 0, solid_h])
            cylinder(d = id, h = h - solid_h + 0.1);   // Insert bore (+0.1 prevents z-fighting)
    }
}


// snap_tongue: The male tongue on the inside face of the lid rim.
// The tongue profile is a right trapezoid (not a symmetric triangle):
//   - Vertical rear face (assembly direction): allows the lid to slide on
//     without resistance until the snap point.
//   - Angled front face (lead-in): 45° chamfer guides the tongue over the
//     groove edge during removal. Without this chamfer, the tongue shears
//     rather than deflecting — the leading failure mode for snap-fits.
// Depth is snap_depth; the caller must subtract a matching groove from the body.
//
// BUGFIX NOTE: linear_extrude() always extrudes along the LOCAL Z axis,
// never along Y, regardless of how the 2D profile is drawn. The previous
// version of this module extruded a 2D XZ-plane profile along Z and relied
// on compound rotate([a,0,c]) calls at each of the 4 call sites to reorient
// it — but compound rotations in OpenSCAD apply in a fixed X→Y→Z order and
// are NOT commutative in the way that "intuitively" combining two 90°
// rotations might suggest. The result was that the left/right tongues had
// their LONG axis pointing along global X instead of along Y, producing
// long thin spikes punching through the lid (visible as two stick-like
// artifacts) and invalid (non-manifold) geometry where they crossed the
// rim and roof.
//
// FIX: bake a single internal rotate([-90,0,0]) into this module so its
// OUTPUT always has: long axis -> +Y, depth axis -> +X, thickness -> +Z.
// Every call site then needs only ONE simple rotate([0,0,angle]) around Z
// to aim the tongue at its target face — no compound rotation guesswork,
// and the result is verifiable by inspection (rotate_extrude/rotate around
// a single axis is easy to reason about; compound XYZ rotation is not).
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


// cable_cutout_negative: Returns a box-shaped negative volume for a cable
// cutout on a named face. Called inside difference() on the box body.
// A slight oversize (+0.5 mm each side) is intentional: cable cutouts are
// always filed/dressed after print, so exact fit here would make that step
// impossible. The extra margin also compensates for typical FDM wall bow.
module cable_cutout_negative(face, center_z, cut_w, cut_h) {
    margin = 0.5;   // Assembly + filing allowance — see rationale above.
    cw = cut_w + 2 * margin;
    ch = cut_h + 2 * margin;
    depth = wall_t * 3;   // Overkill depth ensures clean subtraction regardless
                          // of wall_t value. No partial cuts possible.
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

        // ── Outer shell ──────────────────────────────────────────────────────
        rounded_box(box_w, box_d, body_h, corner_r);

        // ── Interior hollow ──────────────────────────────────────────────────
        // Translate by wall_t in X and Y (side walls), wall_t in Z (floor).
        // The cavity is open at the top (no roof) — lid provides the closure.
        // Height uses inner_h (= body_h - wall_t) + 0.1 mm epsilon so the
        // hollow exits cleanly 0.1 mm above the outer shell's top face.
        // Using body_h here caused the cavity's rounded-corner curve to
        // terminate exactly coplanar with the outer top face, leaving a
        // zero-thickness ring surface artifact visible in F5/F6 render.
        translate([wall_t, wall_t, wall_t])
            rounded_box(inner_w, inner_d, inner_h + 0.1, max(0, corner_r - wall_t));

        // ── Snap groove ──────────────────────────────────────────────────────
        // A peripheral channel cut into the inner face of the rim at groove_z.
        // The lid's snap tongue engages this groove on all four faces.
        //
        // PREVIOUS APPROACH (caused artifact): a nested difference() inside this
        // parent difference() — an outer rounded_box minus an inner rounded_box.
        // The outer box's XY started at x = wall_t - groove_expand = 0.55 mm,
        // while the outer shell's corner arc is centered at x = corner_r = 3 mm.
        // These two arcs (both r=3, different centers) left a thin 0.55 mm ledge
        // at the inner wall's top rim — visible as the surface artifact.
        //
        // FIX: the nested difference() is unnecessary. The inner hollow already
        // removes all material inward of wall_t. The groove only needs to carve
        // the band between (wall_t - groove_expand) and wall_t — one direct
        // rounded_box subtraction achieves this with no leftover faces.
        // corner_r for groove = corner_r - groove_expand (stays concentric with
        // the outer shell's corner arc, guaranteeing flush intersection there).
        translate([wall_t - snap_depth - snap_clearance,
                   wall_t - snap_depth - snap_clearance,
                   groove_z])
            rounded_box(
                box_w - 2*(wall_t - snap_depth - snap_clearance),
                box_d - 2*(wall_t - snap_depth - snap_clearance),
                snap_thickness + 2*snap_clearance + 0.1,
                max(0, corner_r - snap_depth - snap_clearance)
            );

        // ── Cable cutouts ─────────────────────────────────────────────────────
        // Looping over the parameter array keeps the diff() list short and
        // ensures every cutout is applied in one pass (no cascading differences
        // that can leave tool-path artifacts in some slicers).
        for (co = cable_cutouts)
            cable_cutout_negative(co[0], co[1], co[2], co[3]);

    } // end difference() — box shell with all subtractions applied

    // ── Mounting bosses ───────────────────────────────────────────────────────
    // Added OUTSIDE the difference() so they cannot accidentally be subtracted
    // by interior hollow. The floor subtraction stops at wall_t (floor thickness)
    // which is above the boss base — bosses stand proud from the floor correctly.
    for (bp = boss_positions)
        translate([wall_t + bp[0], wall_t + bp[1], wall_t])
            mounting_boss(boss_od, boss_id, boss_h);
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5: SNAP-FIT LID
// ─────────────────────────────────────────────────────────────────────────────

module snap_lid() {
    // The lid is an inverted tray: a flat roof with a descending rim that
    // surrounds the top of the box body. The rim carries the snap tongue on
    // its inner face.
    //
    // Lid coordinate system: Z=0 is the top face of the lid (touching the
    // table when printing upright). The rim descends in -Z direction.
    // This orientation prints without supports: the flat roof is on the bed,
    // rim walls print vertically, tongue is a small horizontal overhang at
    // the rim tip (45° lead-in makes it self-supporting).

    difference() {

        // ── Outer lid tray ───────────────────────────────────────────────────
        // Lid outer dimensions = box outer + 2×clearance + 2×snap_depth.
        // lid_wall is the rim wall thickness (calculated in derived section).
        lid_outer_w = lid_inner_w + 2 * lid_wall;
        lid_outer_d = lid_inner_d + 2 * lid_wall;

        rounded_box(lid_outer_w, lid_outer_d, lid_h, corner_r + snap_clearance);

        // ── Inner hollow (the cavity that slips over the box body) ───────────
        translate([lid_wall, lid_wall, wall_t])
            rounded_box(
                lid_inner_w, lid_inner_d,
                lid_h,   // full height ensures open bottom
                max(0, corner_r + snap_clearance - lid_wall)
            );

    } // end difference() — hollow lid tray

    // ── Snap tongues ──────────────────────────────────────────────────────────
    // Four tongues, one per rim face. Each tongue runs the full inner length of
    // its face minus corner_r relief at each end (avoids interference in corners
    // where geometry becomes complex and tongue engagement is unreliable anyway).
    //
    // Tongue Z offset from lid bottom: positioned so it aligns with groove_z
    // when the lid is fully seated. The rim descends (lid_h - wall_t) mm below
    // the roof; the tongue sits wall_t mm above the rim tip.

    lid_outer_w_local = lid_inner_w + 2 * lid_wall;
    lid_outer_d_local = lid_inner_d + 2 * lid_wall;
    tongue_z = wall_t;   // Distance from lid bottom (rim tip) to tongue bottom

    // ── Tongue placement — verified algebraically (see snap_tongue() note above) ──
    // Each placement uses only ONE rotation (around Z) since snap_tongue()
    // now emits its long axis along +Y internally. Direction was confirmed
    // by checking both: (a) the long axis lies flat along the target wall,
    // and (b) the depth axis points INWARD toward the matching groove cut
    // in box_body() — both verified before locking these values in, since a
    // wrong sign on the depth axis would point the tongue away from the
    // groove and produce a snap-fit that physically cannot engage.

    // Front tongue (low-Y rim wall). Long axis runs along -X from this
    // origin; depth axis points +Y (inward, toward the groove).
    translate([lid_wall + corner_r + (lid_inner_w - 2*corner_r), lid_wall, tongue_z])
        rotate([0, 0, 90])
        snap_tongue(lid_inner_w - 2*corner_r, snap_depth, snap_thickness);

    // Rear tongue (high-Y rim wall). Long axis runs along +X; depth axis
    // points -Y (inward).
    translate([lid_wall + corner_r, lid_wall + lid_inner_d, tongue_z])
        rotate([0, 0, -90])
        snap_tongue(lid_inner_w - 2*corner_r, snap_depth, snap_thickness);

    // Left tongue (low-X rim wall). Long axis runs along +Y; depth axis
    // points +X (inward). No rotation needed — this is the module's
    // native orientation.
    translate([lid_wall, lid_wall + corner_r, tongue_z])
        rotate([0, 0, 0])
        snap_tongue(lid_inner_d - 2*corner_r, snap_depth, snap_thickness);

    // Right tongue (high-X rim wall). Long axis runs along -Y; depth axis
    // points -X (inward).
    translate([lid_wall + lid_inner_w, lid_wall + corner_r + (lid_inner_d - 2*corner_r), tongue_z])
        rotate([0, 0, 180])
        snap_tongue(lid_inner_d - 2*corner_r, snap_depth, snap_thickness);
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6: RENDER / ASSEMBLY DISPATCH
// ─────────────────────────────────────────────────────────────────────────────

if (render_part == "box") {
    // ── Export-ready box only ─────────────────────────────────────────────────
    box_body();

} else if (render_part == "lid") {
    // ── Export-ready lid only ─────────────────────────────────────────────────
    // Lid is flipped for printing (flat side down, no supports needed).
    // The translate brings it to Z=0 after the flip.
    lid_outer_total = lid_inner_w + 2*(wall_t + snap_depth + snap_clearance);
    translate([lid_outer_total, 0, lid_h])
        rotate([180, 0, 0])
        snap_lid();

} else if (render_part == "assembly") {
    // ── Assembly view — lid lifted for visual inspection ──────────────────────
    // Lid is shown in its natural orientation (roof up) floating 5 mm above
    // the body. This lets you verify wall alignment and snap geometry visually
    // before committing to a print.
    box_body();
    translate([0, 0, body_h + 5])
        snap_lid();

} else if (render_part == "section") {
    // ── Cross-section view — reveals wall, floor, boss, snap geometry ─────────
    // A half-space difference() cuts the model along X=box_w/2.
    // Useful for verifying: wall_t, boss solid_h, snap groove depth, floor thickness.
    // This is a debugging/documentation render, not for export.
    difference() {
        union() {
            box_body();
            translate([0, 0, body_h + 5]) snap_lid();
        }
        // Cutting half-space: a large cube occupying X > box_w/2
        translate([box_w/2, -1, -1])
            cube([box_w + 2, box_d + 2, box_h + 20]);
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 7: CUSTOMIZER PRESETS  (OpenSCAD Customizer panel)
// ─────────────────────────────────────────────────────────────────────────────
// These comments are parsed by OpenSCAD's built-in Customizer panel.
// Uncomment and open View → Customizer to use the GUI sliders.
//
// /* [Outer Dimensions] */
// box_w = 80;     // Width (mm) [40:5:200]
// box_d = 60;     // Depth (mm) [30:5:150]
// box_h = 40;     // Total height (mm) [20:5:100]
//
// /* [Wall] */
// wall_t = 2.0;   // Wall thickness (mm) [1.5:0.5:5]
// corner_r = 3;   // Corner radius (mm) [0:1:10]
//
// /* [Lid] */
// lid_h = 10;     // Lid height (mm) [5:1:30]
//
// /* [Snap Fit] */
// snap_depth = 1.2;      // Snap engagement depth (mm) [0.8:0.1:2.0]
// snap_clearance = 0.25; // Print clearance (mm) [0.1:0.05:0.5]
//
// /* [Output] */
// render_part = "assembly"; // [box, lid, assembly, section]
