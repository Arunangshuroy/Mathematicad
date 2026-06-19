// =============================================================================
// ADJUSTABLE SLOTTED L-BRACKET
// =============================================================================
// Author  : Arunangshu Roy
// License : CC BY 4.0
//
// MATHEMATICAL BASIS
//
// 1. SLOT GEOMETRY (stadium shape)
//    A slot = rectangle + two semicircular end-caps of radius r.
//    Area = (L - 2r)*2r + PI*r^2
//    Built in OpenSCAD as hull() of two circles separated by (L - 2r) --
//    the convex hull automatically produces the correct stadium outline.
//
// 2. FILLET STRESS RELIEF
//    Internal corner stress concentration factor (thin-plate approximation):
//      Kt ~= 1 + 2*t/r
//    As r -> 0 (sharp corner), Kt -> infinity: a true stress singularity.
//    This is why internal_fillet_r below is never set to 0 -- it is the
//    single most important parameter for bracket fatigue life.
//
// 3. BEND ALLOWANCE (if laser-cut from sheet and bent, not printed)
//    Bend allowance accounts for material stretch at the bend:
//      BA = (PI/180) * angle * (radius + k*thickness)
//    where k (the "K-factor") is typically 0.33-0.5 depending on material
//    and bend method. Relevant if you fabricate this from sheet metal
//    rather than printing it solid.
// =============================================================================
// --- Bracket parameters ---
arm_a_len   = 50;   // Length of first arm (mm)
arm_b_len   = 40;   // Length of second arm (mm)
arm_w       = 20;   // Width of both arms (mm)
thickness   = 4;    // Material thickness (mm)
internal_fillet_r = 4;  // Internal corner fillet -- see stress note above.
                          // NEVER set to 0 in a real design.
// --- Slot parameters ---
slot_len    = 16;   // Total slot length (mm) -- adjustment range
slot_r      = 2.5;  // Slot half-width = bolt clearance radius (mm) -- M4 clearance
slot_inset  = 12;   // Distance from bracket corner to slot center
$fn = 48;
// stadium_2d(): the slot shape -- hull of two circles = rectangle with
// semicircular ends. This is the standard parametric way to build a slot.
module stadium_2d(length, r) {
    hull() {
        translate([-(length - 2*r)/2, 0]) circle(r = r);
        translate([ (length - 2*r)/2, 0]) circle(r = r);
    }
}
// l_bracket_2d(): the bracket's flat profile before extrusion.
// Built as two overlapping rectangles (the two arms) unioned together,
// then filleted internally using offset() -- a cleaner approach than
// manually computing fillet geometry with arcs.
module l_bracket_2d() {
    union() {
        // Arm A (horizontal)
        square([arm_a_len, arm_w]);
        // Arm B (vertical) -- overlaps Arm A at the corner
        square([arm_w, arm_b_len]);
    }
}
// l_bracket_filleted_2d(): applies the internal fillet using OpenSCAD's
// offset() function. offset(r, $fn) with a positive value first, then
// negative, rounds convex corners; the inverse pair rounds concave (internal)
// corners. This avoids manually parametrising fillet arc geometry by hand.
module l_bracket_filleted_2d() {
    offset(r = -internal_fillet_r)
        offset(r = internal_fillet_r)
            l_bracket_2d();
}
// bracket(): extrudes the filleted profile, then subtracts slots on both arms.
module bracket() {
    difference() {
        linear_extrude(height = thickness)
            l_bracket_filleted_2d();
        // Slot in arm A -- oriented along the arm's long axis
        translate([slot_inset, arm_w/2, -0.1])
            linear_extrude(height = thickness + 0.2)
                stadium_2d(slot_len, slot_r);
        // Slot in arm B -- rotated 90deg to align with vertical arm axis
        translate([arm_w/2, slot_inset, -0.1])
            rotate([0, 0, 90])
                linear_extrude(height = thickness + 0.2)
                    stadium_2d(slot_len, slot_r);
    }
}
bracket();
echo("Slot adjustment range:", slot_len - 2*slot_r, "mm");
echo("Internal fillet stress factor Kt (approx):", 1 + 2*thickness/internal_fillet_r);
