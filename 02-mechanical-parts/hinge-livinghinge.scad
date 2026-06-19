// =============================================================================
// PARAMETRIC LIVING HINGE
// =============================================================================
// Author  : Arunangshu Roy
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
// --- Hinge parameters ---
panel_w     = 60;    // Width of each rigid panel (mm)
panel_l     = 40;    // Length of each rigid panel (mm)
panel_t     = 3;     // Rigid panel thickness (mm)
hinge_t     = 0.6;   // Hinge web thickness (mm). ABSOLUTE FLOOR: 0.4mm @ 0.4 nozzle.
                       // See bending stress note -- do not reduce casually.
hinge_gap   = 0.3;   // Vertical gap between panel and hinge web (print release gap)
// --- Corrugation (set rib_count = 1 for a single continuous hinge) ---
rib_count   = 5;     // Number of parallel hinge ribs across panel_w.
rib_gap     = 4;     // Gap between ribs (mm) -- where material is fully removed.
bend_radius_design = 3;  // Target bend radius (mm) when folded -- used only
                           // for the strain echo check below, not geometry.
$fn = 32;
// rigid_panel(): one solid panel half of the hinge assembly.
module rigid_panel() {
    cube([panel_w, panel_l, panel_t]);
}
// hinge_rib(width): a single thin flexible web segment.
// Modelled as a thin slab spanning the gap between the two panels.
module hinge_rib(width) {
    translate([0, panel_l, panel_t - hinge_t])
        cube([width, hinge_gap*2 + 0.01, hinge_t]);
        // Note: hinge sits flush with panel TOP surface (panel_t - hinge_t),
        // not centered, so the hinge prints as a continuous flat plane
        // across the panel boundary -- critical for bridging without sag.
}
// living_hinge_assembly(): two rigid panels connected by N parallel ribs.
// Rib positions are evenly distributed with rib_gap between them --
// the corrugation pattern that lets the hinge flex without a single
// wide web concentrating all bending strain in one place.
module living_hinge_assembly() {
    rib_width = (panel_w - (rib_count - 1) * rib_gap) / rib_count;
    // First rigid panel
    rigid_panel();
    // Second rigid panel, placed after the hinge gap
    translate([0, panel_l + hinge_gap*2, 0])
        rigid_panel();
    // Hinge ribs distributed across the width
    for (i = [0:rib_count-1]) {
        x_pos = i * (rib_width + rib_gap);
        translate([x_pos, 0, 0])
            hinge_rib(rib_width);
    }
}
living_hinge_assembly();
// --- Verification echoes ---
bending_strain = hinge_t / (2 * bend_radius_design);
echo("Hinge bending strain at design radius:", bending_strain * 100, "%");
echo("PLA fatigue strain limit (~1%) -- exceeded?", bending_strain > 0.01);
echo("PP fatigue strain limit (~15-20%) -- exceeded?", bending_strain > 0.15);
echo("Rib width (mm):", (panel_w - (rib_count - 1) * rib_gap) / rib_count);
