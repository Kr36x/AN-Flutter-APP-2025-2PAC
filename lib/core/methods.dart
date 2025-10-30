import 'evaluator.dart';

class IterRow {
  final int iter;
  final double pn; // aproximación actual
  final double fpn; // f(pn)
  final double error; // |pn - p_{n-1}|
  const IterRow(this.iter, this.pn, this.fpn, this.error);
}

class MethodResult {
  final double root;
  final List<IterRow> log;
  const MethodResult(this.root, this.log);
}

/// ------------------------------
/// Métodos de raíces
/// ------------------------------

/// Newton-Raphson
MethodResult newtonMethod(
  String fx,
  double x0, {
  double tol = 1e-6,
  int maxIter = 50,
}) {
  final f = makeFunction(fx);
  final df = numericDerivative(f);
  final log = <IterRow>[];

  var p = x0;
  var prev = double.nan;
  for (var k = 1; k <= maxIter; k++) {
    final fp = f(p);
    final dfp = df(p);
    if (dfp == 0 || dfp.isNaN || dfp.isInfinite) {
      log.add(IterRow(k, p, fp, (prev.isNaN ? double.nan : (p - prev).abs())));
      return MethodResult(p, log);
    }
    final next = p - fp / dfp;
    final err = prev.isNaN ? double.nan : (next - p).abs();
    log.add(IterRow(k, next, f(next), err));

    if ((f(next)).abs() < tol || (err.isFinite && err < tol)) {
      return MethodResult(next, log);
    }
    prev = p;
    p = next;
  }

  return MethodResult(p, log);
}

/// Punto fijo  (x = g(x))
MethodResult fixedPointMethod(
  String gx,
  double p0, {
  double a = double.negativeInfinity,
  double b = double.infinity,
  double tol = 1e-6,
  int maxIter = 50,
}) {
  final g = makeFunction(gx);
  final log = <IterRow>[];

  var prev = p0;
  for (var n = 1; n <= maxIter; n++) {
    var pn = g(prev);

    if (a.isFinite && pn < a) pn = a;
    if (b.isFinite && pn > b) pn = b;

    final err = (pn - prev).abs();
    final fpn = pn - g(pn);
    log.add(IterRow(n, pn, fpn, err));

    if (err < tol) {
      return MethodResult(pn, log);
    }
    prev = pn;
  }

  return MethodResult(prev, log);
}

/// Bisección (requiere f(a)*f(b) < 0)
MethodResult bisectionMethod(
  String fx,
  double a,
  double b, {
  double tol = 1e-6,
  int maxIter = 50,
}) {
  final f = makeFunction(fx);
  final log = <IterRow>[];

  var fa = f(a);
  var fb = f(b);
  if (fa * fb > 0) {
    return MethodResult(double.nan, [
      IterRow(0, a, fa, double.nan),
      IterRow(0, b, fb, double.nan),
    ]);
  }

  double prev = double.nan;
  for (var k = 1; k <= maxIter; k++) {
    final p = (a + b) / 2.0;
    final fp = f(p);
    final err = prev.isNaN ? double.nan : (p - prev).abs();

    log.add(IterRow(k, p, fp, err));

    if (fp.abs() < tol ||
        (err.isFinite && err < tol) ||
        ((b - a) / 2.0) < tol) {
      return MethodResult(p, log);
    }

    if (fa * fp < 0) {
      b = p;
      fb = fp;
    } else {
      a = p;
      fa = fp;
    }
    prev = p;
  }

  return MethodResult((a + b) / 2.0, log);
}

/// Secante (requiere dos semillas x0 y x1)
MethodResult secantMethod(
  String fx,
  double x0,
  double x1, {
  double tol = 1e-6,
  int maxIter = 50,
}) {
  final f = makeFunction(fx);
  final log = <IterRow>[];

  var pPrev = x0;
  var p = x1;
  var fpPrev = f(pPrev);
  var fp = f(p);

  log.add(IterRow(0, pPrev, fpPrev, double.nan));
  log.add(IterRow(1, p, fp, (p - pPrev).abs()));

  for (var k = 2; k <= maxIter; k++) {
    final denom = (fp - fpPrev);
    if (denom == 0.0 || denom.isNaN || denom.isInfinite) {
      return MethodResult(p, log);
    }

    final pNext = p - fp * (p - pPrev) / denom;
    final fpNext = f(pNext);
    final err = (pNext - p).abs();

    log.add(IterRow(k, pNext, fpNext, err));

    if (err < tol || fpNext.abs() < tol) {
      return MethodResult(pNext, log);
    }

    pPrev = p;
    fpPrev = fp;
    p = pNext;
    fp = fpNext;
  }

  return MethodResult(p, log);
}

/// Punto falso (Regula Falsi) — requiere f(a)*f(b) < 0
MethodResult falsePositionMethod(
  String fx,
  double a,
  double b, {
  double tol = 1e-6,
  int maxIter = 50,
}) {
  final f = makeFunction(fx);
  final log = <IterRow>[];

  var fa = f(a);
  var fb = f(b);

  if (fa * fb > 0) {
    return MethodResult(double.nan, [
      IterRow(0, a, fa, double.nan),
      IterRow(0, b, fb, double.nan),
    ]);
  }

  double prev = double.nan;

  for (var k = 1; k <= maxIter; k++) {
    final denom = (fb - fa);
    if (denom == 0.0 || denom.isNaN || denom.isInfinite) {
      return MethodResult((a + b) / 2.0, log);
    }

    final p = b - fb * (b - a) / denom;
    final fp = f(p);
    final err = prev.isNaN ? double.nan : (p - prev).abs();

    log.add(IterRow(k, p, fp, err));

    if (fp.abs() < tol || (err.isFinite && err < tol)) {
      return MethodResult(p, log);
    }

    if (fa * fp < 0) {
      b = p;
      fb = fp;
    } else {
      a = p;
      fa = fp;
    }

    prev = p;
  }

  return MethodResult((a + b) / 2.0, log);
}

/// ------------------------------
/// Interpolación de Lagrange — polinomio explícito
/// ------------------------------

class PolyResult {
  /// Coeficientes en orden ascendente: c0 + c1 x + c2 x^2 + ...
  final List<double> coeffs;

  /// Cadena legible para mostrar: P(x) = ...
  final String readable;

  /// Evaluación opcional en x* (si lo deseas en la UI)
  final double? yAt;
  final double? xAt;

  const PolyResult({
    required this.coeffs,
    required this.readable,
    this.xAt,
    this.yAt,
  });
}

/// Opera: suma de polinomios
List<double> _polyAdd(List<double> a, List<double> b) {
  final n = a.length, m = b.length;
  final k = (n > m) ? n : m;
  final out = List<double>.filled(k, 0.0);
  for (var i = 0; i < k; i++) {
    out[i] = (i < n ? a[i] : 0.0) + (i < m ? b[i] : 0.0);
  }
  return out;
}

/// Opera: (polinomio) * (x - alpha)
List<double> _polyMulMonomial(List<double> p, double alpha) {
  // q(x) = p(x) * (x - alpha)
  final out = List<double>.filled(p.length + 1, 0.0);
  for (var i = out.length - 1; i >= 0; i--) {
    final prev = (i - 1 >= 0) ? p[i - 1] : 0.0;
    final curr = (i < p.length) ? p[i] : 0.0;
    out[i] = prev - alpha * curr;
  }
  return out;
}

List<double> _polyScale(List<double> p, double k) =>
    p.map((e) => e * k).toList();

double polyEval(List<double> c, double x) {
  // Horner
  double acc = 0.0;
  for (var i = c.length - 1; i >= 0; i--) {
    acc = acc * x + c[i];
  }
  return acc;
}

/// Quita coeficientes ~0 para un string más limpio
List<double> _trimZeros(List<double> c, {double eps = 1e-12}) {
  var last = c.length - 1;
  while (last > 0 && c[last].abs() < eps) last--;
  return c.sublist(0, last + 1).map((v) => (v.abs() < eps) ? 0.0 : v).toList();
}

/// Construye el polinomio de Lagrange en forma expandida:
/// P(x) = sum_i y_i * L_i(x), donde
/// L_i(x) = Π_{j!=i} (x - x_j) / (x_i - x_j)
List<double> lagrangePolynomialCoeffs(List<double> xs, List<double> ys) {
  if (xs.length != ys.length || xs.isEmpty) {
    throw ArgumentError('Listas xs y ys inválidas.');
  }
  // Validar x únicos
  final seen = <double>{};
  for (final x in xs) {
    if (seen.contains(x)) {
      throw ArgumentError(
        'Hay valores de x repetidos: la interpolación requiere x únicos.',
      );
    }
    seen.add(x);
  }

  // Acumulador de coeficientes
  var coeffs = <double>[0.0];

  for (var i = 0; i < xs.length; i++) {
    // Construir L_i(x) en forma polinómica: iniciar en 1
    var Li = <double>[1.0];
    double denom = 1.0;

    for (var j = 0; j < xs.length; j++) {
      if (j == i) continue;
      Li = _polyMulMonomial(Li, xs[j]); // *(x - x_j)
      denom *= (xs[i] - xs[j]); // /(x_i - x_j)
    }

    // Escalar por y_i / denom
    Li = _polyScale(Li, ys[i] / denom);

    // Acumular en P(x)
    coeffs = _polyAdd(coeffs, Li);
  }

  return _trimZeros(coeffs);
}

/// Convierte coeficientes a un string legible: "P(x) = a0 + a1 x + a2 x^2 + ..."
String polyToreadableString(List<double> c, {int decimals = 8}) {
  c = _trimZeros(c);
  String fmt(double v) {
    // redondeo amable que evita -0
    final r = double.parse(v.toStringAsFixed(decimals));
    return (r == -0.0) ? '0' : r.toString();
  }

  final sb = StringBuffer('P(x) = ');
  bool first = true;
  for (var i = 0; i < c.length; i++) {
    final a = c[i];
    if (a == 0.0) continue;

    final sign = (a < 0) ? ' - ' : (first ? '' : ' + ');
    final absA = a.abs();

    sb.write(sign);
    // coeficiente
    final showCoeff = !(absA == 1.0 && i > 0);
    if (showCoeff) sb.write(fmt(absA));
    // variable/potencia
    if (i >= 1) {
      if (showCoeff) sb.write('·');
      sb.write('x');
      if (i >= 2) sb.write('^$i');
    }
    first = false;
  }

  if (first) sb.write('0'); // todos eran 0
  return sb.toString();
}

/// dado xs, ys y opcional xAt, devuelve
/// coeficientes, string bonito y evaluación en xAt (si se pasó).
PolyResult buildLagrangePolynomial(
  List<double> xs,
  List<double> ys, {
  double? xAt,
}) {
  final coeffs = lagrangePolynomialCoeffs(xs, ys);
  final readable = polyToreadableString(coeffs, decimals: 8);
  final yAt = (xAt == null) ? null : polyEval(coeffs, xAt);
  return PolyResult(coeffs: coeffs, readable: readable, xAt: xAt, yAt: yAt);
}
