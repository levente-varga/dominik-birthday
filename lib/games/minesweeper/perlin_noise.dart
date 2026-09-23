import 'dart:math' as math;

/// Classic 2D Perlin Noise implementation with Ken Perlin's Improved Noise quintic fade curve.
class PerlinNoise2D {
  late final List<int> _p;

  PerlinNoise2D([int seed = 0]) {
    final permutation = List<int>.generate(256, (i) => i);
    final rng = math.Random(seed);
    permutation.shuffle(rng);
    _p = List<int>.filled(512, 0);
    for (int i = 0; i < 256; i++) {
      _p[i] = permutation[i];
      _p[256 + i] = permutation[i];
    }
  }

  static double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  static double _lerp(double t, double a, double b) => a + t * (b - a);

  static double _grad(int hash, double x, double y) {
    switch (hash & 3) {
      case 0:
        return x + y;
      case 1:
        return -x + y;
      case 2:
        return x - y;
      case 3:
        return -x - y;
      default:
        return 0.0;
    }
  }

  /// Samples continuous 2D Perlin noise at ([x], [y]), normalized to approximately `[-1.0, 1.0]`.
  /// At integer lattice point (0, 0), this is mathematically guaranteed to be 0.0.
  double sample(double x, double y) {
    if (x == 0.0 && y == 0.0) return 0.0;

    final xi = x.floor();
    final yi = y.floor();
    final X = xi & 255;
    final Y = yi & 255;

    final xf = x - xi;
    final yf = y - yi;

    final u = _fade(xf);
    final v = _fade(yf);

    final aa = _p[_p[X] + Y];
    final ab = _p[_p[X] + Y + 1];
    final ba = _p[_p[X + 1] + Y];
    final bb = _p[_p[X + 1] + Y + 1];

    final x1 = _lerp(u, _grad(aa, xf, yf), _grad(ba, xf - 1, yf));
    final x2 = _lerp(u, _grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1));

    return (_lerp(v, x1, x2) * 0.70710678).clamp(-1.0, 1.0);
  }
}

/// 2D Vector Perlin Noise that combines two orthogonal Perlin fields.
/// Returns a scalar magnitude in `[0.0, 1.0]`, with `(0, 0)` guaranteed to be `0.0`.
class VectorPerlin2D {
  final PerlinNoise2D noiseX;
  final PerlinNoise2D noiseY;

  VectorPerlin2D([int seed = 42])
      : noiseX = PerlinNoise2D(seed),
        noiseY = PerlinNoise2D(seed + 1000);

  /// Samples the 2D vector noise magnitude at ([x], [y]).
  /// At `(0, 0)`, this returns exactly `0.0`.
  /// Peak values clamp at `1.0`.
  double sample(double x, double y) {
    if (x == 0.0 && y == 0.0) return 0.0;
    final nx = noiseX.sample(x, y);
    final ny = noiseY.sample(x, y);
    final mag = math.sqrt(nx * nx + ny * ny);
    return mag.clamp(0.0, 1.0);
  }
}
