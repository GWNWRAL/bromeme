#!/usr/bin/env python3
"""
Independently re-implement the factor the extension computes and print the
resulting table, so the compounding definition can be checked against the spec
("multiply by the growth, i.e. 200% -> 210% with 5%") without launching the game.

Also mirrors it against the LINEAR formula used by the mod this was modelled on,
to make the difference explicit.
"""

MAX_SCALE_WAVE = 200
MAX_GROWTH = 1.0


def factor_compound(growth, wave):
    g = min(max(growth, 0.0), MAX_GROWTH)
    if g <= 0.0:
        return 1.0
    n = int(min(max(wave, 0), MAX_SCALE_WAVE))
    if n <= 0:
        return 1.0
    return (1.0 + g) ** n


def factor_linear(growth, wave):
    return 1.0 + max(0, wave) * max(0.0, growth)


print("=" * 76)
print("Compound (this mod):  multiplier = (1 + g) ^ wave")
print("=" * 76)
print("  wave |      +5% |     +10% |      +2% |      +0% |   linear +5%")
print("  -----+----------+----------+----------+----------+-------------")
for w in [0, 1, 2, 3, 5, 10, 20, 40, 60]:
    print("  %4d | %8.4f | %8.4f | %8.4f | %8.4f | %11.4f" % (
        w,
        factor_compound(0.05, w),
        factor_compound(0.10, w),
        factor_compound(0.02, w),
        factor_compound(0.0, w),
        factor_linear(0.05, w),
    ))

print()
print("=" * 76)
print("Spec check: 'enemy HP is 200%, growth 5% -> next wave is 210%'")
print("=" * 76)
print("  A multiplier of 2.00 with +5%% compounding becomes 2.00 * 1.05 = %.4f" % (2.0 * factor_compound(0.05, 1)))
print("  i.e. 200%% -> %.0f%%   (a LINEAR +5%% would only give 200%% + 5%% = 205%%)" % (2.0 * factor_compound(0.05, 1) * 100))
print()
print("  Wave-over-wave ratio must be constant 1.05 (that is what 'compound' means):")
for w in range(1, 6):
    a = factor_compound(0.05, w)
    b = factor_compound(0.05, w + 1)
    print("    wave %d -> %d : %.6f -> %.6f   ratio %.6f" % (w, w + 1, a, b, b / a))

print()
print("=" * 76)
print("Guard rails")
print("=" * 76)
print("  growth clamped to [0, %s]        : g=-1 -> %.4f    g=5 -> %.4f" % (
    MAX_GROWTH, factor_compound(-1, 10), factor_compound(5, 10)))
print("  wave clamped to [0, %d]          : wave=-3 -> %.4f  wave=999 -> %.4f" % (
    MAX_SCALE_WAVE, factor_compound(0.05, -3), factor_compound(0.05, 999)))
print("  float headroom at max settings   : (1+1.0)^%d = %.3e  (2^53 = %.3e)" % (
    MAX_SCALE_WAVE, factor_compound(1.0, MAX_SCALE_WAVE), 2.0 ** 53))
