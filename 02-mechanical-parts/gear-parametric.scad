// =============================================================================
// PARAMETRIC INVOLUTE SPUR GEAR
// =============================================================================
// Author  : Arunangshu Roy
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
