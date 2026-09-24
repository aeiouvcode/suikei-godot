## Rebuild + v6 (source only, not pushed) - Sep 24 8:20 PM
- Previous workspace lost; v4 + v5 rebuilt exactly by replaying the recorded edit scripts on repo v3 source (02ab634).
- v6 clear-water grade, measured against the hayashimon1 reference video frame:
  pale low-contrast granite bed (bed + rock), caustics pow 1.6 x3.0 (softer than v5), base light 0.68 + c*0.95,
  in-scatter emission 0.8, two-scale refraction wobble on the bed (swell + ripple), fewer/tighter sun glints,
  cooler sky reflection, lower Fresnel alpha. Near-water mean RGB 58,161,141 vs reference 56,160,143 (v5 was 60,127,116).
- Fish: VIS_SCALE 2.2 -> 2.9, darker dorsal blend, stronger/larger bed shadow. Fish still PARTIAL (needs a real model pass).
- QA: run with --fixed-fps 15 (and >300 s) on this slow sandbox; the fight holds and the full loop completes.
