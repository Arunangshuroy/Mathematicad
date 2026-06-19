// =============================================================================
// PARAMETRIC INVOLUTE SPUR GEAR
// =============================================================================
// Author  : Arunangshu Das
// License : CC BY 4.0
//
// MATHEMATICAL BASIS
// Tooth profile follows the involute of a circle:
//   x(t) = r_b * (cos(t) + t*sin(t))
//   y(t) = r_b * (sin(t) - t*cos(t))
// where t is the unwind angle (radians) and r_b is the base circle radius.
//
// Two involute-profile teeth maintain CONSTANT angular velocity ratio
// throughout contact -- this is the fundamental law of gearing and the
// reason every modern mechanical gear uses this curve, not an arc or line.
//
// KEY FORMULAS (module m, tooth count N, pressure angle phi):
//   pitch_diameter   Dp = m * N
//   base_radius      rb = (Dp/2) * cos(phi)
//   addendum_radius  ra = Dp/2 + m            (tooth tip)
//   dedendum_radius  rd = Dp/2 - 1.25*m       (tooth root, 1.25 = clearance factor)
//   circular_pitch   p  = PI * m
//   tooth_half_angle = (PI / N) / 2           (angular half-width at pitch circle)
// =============================================================================
// --- Gear parameters ---
m          = 2;     // Module (mm). Tooth size -- pitch_diameter / tooth_count.
teeth      = 20;     // Number of teeth. Min ~8 to avoid undercut at 20 deg pressure angle.
phi_deg    = 20;     // Pressure angle (degrees). 20 deg is the modern standard.
face_w     = 8;      // Gear thickness / face width (mm).
bore_d     = 5;      // Center bore diameter (mm) -- for shaft.
clearance_factor = 1.25;  // Dedendum clearance multiplier (standard = 1.25).
$fn = 64;
// --- Derived dimensions ---
Dp  = m * teeth;                          // Pitch diameter
phi = phi_deg;                             // pressure angle, kept in degrees for OpenSCAD trig
rb  = (Dp/2) * cos(phi);                  // Base circle radius
ra  = Dp/2 + m;                            // Addendum (tip) radius
rd  = Dp/2 - clearance_factor * m;        // Dedendum (root) radius
tooth_angle = 360 / teeth;                 // Angular pitch per tooth (degrees)
// involute_point(t_deg): returns [x, y] on the involute at unwind angle t (degrees)
function involute_point(t_deg) =
    let (t = t_deg * PI / 180)
    [ rb * (cos(t_deg) + t * sin(t_deg)),
      rb * (sin(t_deg) - t * cos(t_deg)) ];
// max_t: the unwind angle (degrees) at which the involute reaches the addendum radius.
// Solved from: ra^2 = rb^2 * (1 + t^2)  =>  t = sqrt((ra/rb)^2 - 1)
function max_unwind_angle() =
    let (t_rad = sqrt(pow(ra/rb, 2) - 1))
    t_rad * 180 / PI;
// single_tooth_profile(): builds one tooth as a polygon by sampling the involute
// curve on both flanks (mirrored), then closing with arcs at root and tip.
module single_tooth_profile(steps = 12) {
    max_t = max_unwind_angle();
    // Right flank: sample involute from base circle to addendum
    right_flank = [ for (i = [0:steps])
        involute_point(max_t * i / steps) ];
    // Half tooth angle at pitch circle -- used to position the mirror flank
    // so the tooth is centered on its angular slot.
    half_tooth_deg = tooth_angle / 4;  // quarter of pitch angle = half tooth thickness angle approx
    // Left flank = mirror of right flank about the tooth centerline
    left_flank = [ for (i = [steps:-1:0])
        let (p = involute_point(max_t * i / steps))
        [ p.x*cos(2*half_tooth_deg) + p.y*sin(2*half_tooth_deg),
         -p.x*sin(2*half_tooth_deg) + p.y*cos(2*half_tooth_deg) ] ];
    polygon(concat(right_flank, left_flank));
}
// gear_2d(): assembles all teeth around the center, then unions with the
// dedendum (root) circle so teeth are structurally connected to the gear body.
module gear_2d() {
    union() {
        circle(r = rd);  // Root disc -- base material the teeth attach to
        for (i = [0:teeth-1])
            rotate([0, 0, i * tooth_angle])
                single_tooth_profile();
    }
}
// gear(): extrudes the 2D profile and subtracts the center bore.
module gear() {
    difference() {
        linear_extrude(height = face_w)
            gear_2d();
        translate([0, 0, -0.1])
            cylinder(d = bore_d, h = face_w + 0.2);
    }
}
gear();
// --- Verification echo (prints to console on render) ---
echo("Pitch diameter:", Dp, "mm");
echo("Base circle radius:", rb, "mm");
echo("Addendum radius:", ra, "mm");
echo("Dedendum radius:", rd, "mm");
echo("Circular pitch:", PI * m, "mm");
bracket-adjustable.scad
Adjustable Slotted L-Bracket
Copy
// =============================================================================
// ADJUSTABLE SLOTTED L-BRACKET
// =============================================================================
// Author  : Arunangshu Das
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
hinge-livinghinge.scad
Parametric Living Hinge
Copy
// =============================================================================
// PARAMETRIC LIVING HINGE
// =============================================================================
// Author  : Arunangshu Das
// License : CC BY 4.0
//
// MATHEMATICAL BASIS
//
// 1. BENDING STRESS (rectangular cross-section beam in pure bending)
//      sigma_max = M*c / I = 6*M / (b * h^2)
//    where:
//      M = bending moment applied to the hinge
//      b = hinge width
//      h = hinge thickness
//      c = h/2 (distance from neutral axis to outer surface)
//      I = b*h^3/12 (second moment of area, rectangular section)
//
//    CRITICAL: stress scales as 1/h^2. Halving hinge thickness roughly
//    QUADRUPLES peak stress for the same applied moment. This is why
//    hinge_t below has an absolute floor and should never be tuned by
//    instinct alone.
//
// 2. BENDING STRAIN (fatigue driver)
//      epsilon = h / (2*R)
//    where R is the bend radius the hinge curls to when folded flat.
//    Keeping epsilon below the material's fatigue strain limit determines
//    cycle life. PLA fatigue strain limit is low (~1%) -- PLA is a POOR
//    living-hinge material. PP (~15-20%) or TPU is strongly preferred.
//    This script defaults to PP-appropriate geometry; halve hinge_t
//    further only if printing in PP/PETG, never in PLA.
//
// 3. CORRUGATED (multi-rib) HINGES
//    Distributing the bend across N parallel thin ribs instead of one
//    continuous web divides total bending curvature across N hinge
//    elements, each individually experiencing 1/N of the total bend
//    angle's local curvature -- this is why corrugated hinges survive
//    far more cycles than a single wide web of the same total width.
// =============================================================================
