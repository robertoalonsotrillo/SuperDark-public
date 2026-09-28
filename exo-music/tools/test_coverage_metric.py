#!/usr/bin/env python3
"""Does the coverage metric do the three things the pre-registration relies on?

A metric adopted as DESCRIPTIVE still has to be a measurement. Three properties
carry the whole of `.lab/measurements/2026-09-18_coverage_metric_prereg.md`, and
each is checked here on a case whose answer is known before running.

  1  THE RADIUS IS A RATIO, NOT A NUMBER. The pre-registration is explicit that
     "a fixed 0.09 would silently change meaning if the anchor set grew denser".
     So: scale every anchor by k and r must scale by exactly k; halve the
     spacing and r must halve. A radius that survived either of those unchanged
     would be a constant wearing a formula.

  2  THE NULL IS ACTUALLY A NULL. Condition 4 of the pre-registration wants the
     separation reported every time so a saturation is visible the moment it
     happens. A null that returns the measurement back is worse than none, and
     the window-ORDER permutation is exactly that: coverage is a set-membership
     question over a point cloud, so reordering rows cannot change it. This
     pins BOTH facts -- the per-dimension shuffle moves the number, the order
     permutation provably does not -- so nobody wires up the degenerate one
     later believing it is a control.

  3  IT RUNS ON A REAL ARM AND REPORTS. No assertion on the value. The bound is
     UNSET and this file is not the place it gets set by the back door.

    python3 tools/test_coverage_metric.py
"""
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coverage_metric as CM      # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARM = os.path.join(
    ROOT, "harness", "superseded_260919_sliced_wrong",
    "run_260919_092415_champion", "arm_windows.log")


def grid(step, n=4, dim=3):
    """A cubic lattice of side `step`: median nearest-neighbour spacing is
    exactly `step`, so the expected radius is known in closed form."""
    ax = np.arange(n) * step
    return np.array(np.meshgrid(*([ax] * dim), indexing="ij")).reshape(dim, -1).T


class RadiusIsARatio(unittest.TestCase):

    def test_matches_the_rule_in_closed_form(self):
        C = grid(0.5)
        nn, _ = CM.spacings(C)
        self.assertAlmostEqual(nn, 0.5, places=9)
        self.assertAlmostEqual(CM.radius(C), CM.RADIUS_RATIO * 0.5, places=9)

    def test_scaling_the_anchors_scales_the_radius_by_the_same_factor(self):
        C = grid(0.5)
        r0 = CM.radius(C)
        for k in (0.5, 2.0, 7.3, 0.013):
            self.assertAlmostEqual(CM.radius(C * k), r0 * k, places=9,
                                   msg=f"radius did not scale by {k}")

    def test_a_denser_anchor_set_gives_a_smaller_radius(self):
        # the failure the ratio exists to prevent: the same physical question
        # asked of a denser set must tighten, not stay at 0.09
        self.assertLess(CM.radius(grid(0.25)), CM.radius(grid(0.5)))

    def test_translation_does_not_change_it(self):
        C = grid(0.5)
        self.assertAlmostEqual(CM.radius(C + 11.0), CM.radius(C), places=9)

    def test_the_real_anchor_set_does_not_give_the_prereg_number(self):
        # Recorded as a test because it is a discrepancy, not a bug to hide: the
        # rule says median NEAREST-NEIGHBOUR spacing and the prereg says that
        # gives about 0.09, but 0.09 is 0.12 x the median PAIRWISE distance.
        # If this test ever fails, the anchor set changed and the note in
        # coverage_metric.py's docstring must be re-checked, not deleted.
        C, _ = CM.load_anchors()
        nn, pw = CM.spacings(C)
        self.assertEqual(len(C), 89)
        self.assertAlmostEqual(CM.RADIUS_RATIO * pw, 0.0903, places=3)
        self.assertLess(CM.RADIUS_RATIO * nn, 0.05)


class TheNullIsANull(unittest.TestCase):

    def setUp(self):
        # a trajectory that OCCUPIES three regions: the case the whole
        # tight-radius argument is about. Its per-dimension marginals are
        # three-valued, so an independent shuffle scatters it over the 27
        # product combinations instead of the 3 it actually visited.
        rng = np.random.default_rng(11)
        self.C = np.array([[0.2, 0.2, 0.2], [0.5, 0.5, 0.5], [0.8, 0.8, 0.8],
                           [0.2, 0.5, 0.8], [0.8, 0.2, 0.5]])
        centres = self.C[:3]
        self.W = np.repeat(centres, 400, axis=0) + rng.normal(0, 0.005, (1200, 3))
        self.r = 0.05

    def test_factory_reaches_the_regions_it_occupies(self):
        self.assertAlmostEqual(CM.coverage(self.C, self.W, self.r), 3 / 5)

    def test_per_dimension_shuffle_changes_the_number(self):
        nulls = CM.shuffled_null(self.C, self.W, self.r, reps=16, seed=3)
        fac = CM.coverage(self.C, self.W, self.r)
        self.assertNotAlmostEqual(float(np.mean(nulls)), fac, places=6,
                                  msg="the shuffled null returned the "
                                      "measurement; it is not a control")

    def test_order_permutation_is_provably_degenerate(self):
        # not a weakness to be worked around -- a fact to be pinned, so that a
        # later "let's shuffle the windows" cannot quietly become the null
        fac = CM.coverage(self.C, self.W, self.r)
        for seed in (1, 2, 99):
            self.assertEqual(
                CM.order_permutation_null(self.C, self.W, self.r, seed), fac,
                msg="window-order permutation must equal the factory value "
                    "exactly; if it does not, the statistic is not "
                    "order-invariant and this file's reasoning is wrong")

    def test_null_is_reproducible_from_the_seed(self):
        a = CM.shuffled_null(self.C, self.W, self.r, reps=8, seed=7)
        b = CM.shuffled_null(self.C, self.W, self.r, reps=8, seed=7)
        self.assertEqual(a, b)


class TheLogCarriesThePosition(unittest.TestCase):

    def test_windows_load_in_the_anchor_basis(self):
        C, _ = CM.load_anchors()
        W, held, bad = CM.load_windows(ARM, C.shape[1])
        self.assertGreater(len(W), 800, "arm too short to say anything")
        self.assertEqual(W.shape[1], C.shape[1],
                         "window vectors are not in the anchors' basis")
        self.assertTrue(np.isfinite(W).all())


class ReportOnTheRealArm(unittest.TestCase):
    """No assertion on the value. The bound is UNSET."""

    def test_report(self):
        C, _ = CM.load_anchors()
        W, held, bad = CM.load_windows(ARM, C.shape[1])
        nn, pw = CM.spacings(C)
        print()
        print(f"  arm {os.path.basename(os.path.dirname(ARM))}: {len(W)} "
              f"positioned windows"
              + (f", {held} without a position" if held else ""))
        print(f"  anchors {len(C)}, median NN {nn:.4f}, median pairwise {pw:.4f}")
        for label, r in (("prereg rule  0.12 x median NN", CM.RADIUS_RATIO * nn),
                         ("prereg table 0.12 x median pairwise",
                          CM.RADIUS_RATIO * pw)):
            fac = CM.coverage(C, W, r)
            nulls = CM.shuffled_null(C, W, r, reps=32, seed=5)
            nm = float(np.mean(nulls))
            print(f"    {label:38} r={r:.4f}  factory {100*fac:5.1f}%  "
                  f"null {100*nm:5.1f}% (sd {100*np.std(nulls):.1f})  "
                  f"separation {100*(fac-nm):+5.1f}")
        print("    STATUS: descriptive, bound UNSET.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
