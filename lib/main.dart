import 'package:flutter/material.dart';
import 'core/evaluator.dart';
import 'core/methods.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const RootApp());

enum Method { newton, fixedPoint, bisection, secant, falsePosition, lagrange }

class RootApp extends StatelessWidget {
  const RootApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Análisis Numérico',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          border: UnderlineInputBorder(),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Method method = Method.newton;

  // Expresiones para métodos de raíces
  final fCtrl = TextEditingController(text: 'x^3 - x - 1'); // f(x)
  final gCtrl = TextEditingController(text: 'cos(x)'); // g(x) punto fijo

  // Parámetros numéricos
  final x0Ctrl = TextEditingController(text: '1'); // x0 / p0
  final x1Ctrl = TextEditingController(text: '2'); // x1 (secante)
  final aCtrl = TextEditingController(text: '0'); // a (intervalo)
  final bCtrl = TextEditingController(text: '2'); // b (intervalo)
  final tolCtrl = TextEditingController(text: '1e-6');
  final maxIterCtrl = TextEditingController(text: '50');

  // Interpolación (Lagrange)
  final pointsCtrl = TextEditingController(text: '0,1; 1,2; 2,5');
  final xEvalCtrl = TextEditingController(text: '1.5');

  MethodResult? result;
  PolyResult? poly;
  List<double>? lastXs, lastYs; // puntos para la gráfica

  @override
  void dispose() {
    fCtrl.dispose();
    gCtrl.dispose();
    x0Ctrl.dispose();
    x1Ctrl.dispose();
    aCtrl.dispose();
    bCtrl.dispose();
    tolCtrl.dispose();
    maxIterCtrl.dispose();
    pointsCtrl.dispose();
    xEvalCtrl.dispose();
    super.dispose();
  }

  double _parseDouble(String s, double def) {
    final v = double.tryParse(s.trim());
    return v ?? def;
  }

  bool _hasSignChange(String fx, double a, double b) {
    final f = makeFunction(fx);
    final fa = f(a), fb = f(b);
    return fa.isFinite && fb.isFinite && fa * fb < 0;
  }

  (List<double>, List<double>) _parsePoints(String input) {
    final xs = <double>[];
    final ys = <double>[];
    final items = input
        .replaceAll('\n', ';')
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final it in items) {
      final parts = it.split(',').map((s) => s.trim()).toList();
      if (parts.length != 2) {
        throw ArgumentError('Formato inválido en "$it". Usa "x,y; x,y; ..."');
      }
      final xi = double.tryParse(parts[0]);
      final yi = double.tryParse(parts[1]);
      if (xi == null || yi == null) {
        throw ArgumentError('No se pudo convertir "$it" a números.');
      }
      xs.add(xi);
      ys.add(yi);
    }
    if (xs.length < 2) {
      throw ArgumentError('Se requieren al menos 2 puntos.');
    }
    return (xs, ys);
  }

  void _run() {
    FocusScope.of(context).unfocus();
    final fx = fCtrl.text.trim();
    final gx = gCtrl.text.trim();

    final x0 = _parseDouble(x0Ctrl.text, 0);
    final x1 = _parseDouble(x1Ctrl.text, x0 + 1);
    final a = _parseDouble(aCtrl.text, x0);
    final b = _parseDouble(bCtrl.text, x1);
    final tol = _parseDouble(tolCtrl.text, 1e-6);
    final maxIter = int.tryParse(maxIterCtrl.text.trim()) ?? 50;

    try {
      switch (method) {
        case Method.newton:
          setState(() {
            result = newtonMethod(fx, x0, tol: tol, maxIter: maxIter);
            poly = null;
            lastXs = null;
            lastYs = null;
          });
          break;
        case Method.fixedPoint:
          setState(() {
            result = fixedPointMethod(
              gx,
              x0,
              a: a,
              b: b,
              tol: tol,
              maxIter: maxIter,
            );
            poly = null;
            lastXs = null;
            lastYs = null;
          });
          break;
        case Method.bisection:
          if (!_hasSignChange(fx, a, b)) {
            _showSnack('Bisección requiere f(a)*f(b) < 0');
            return;
          }
          setState(() {
            result = bisectionMethod(fx, a, b, tol: tol, maxIter: maxIter);
            poly = null;
            lastXs = null;
            lastYs = null;
          });
          break;
        case Method.secant:
          setState(() {
            result = secantMethod(fx, x0, x1, tol: tol, maxIter: maxIter);
            poly = null;
            lastXs = null;
            lastYs = null;
          });
          break;
        case Method.falsePosition:
          if (!_hasSignChange(fx, a, b)) {
            _showSnack('Punto falso requiere f(a)*f(b) < 0');
            return;
          }
          setState(() {
            result = falsePositionMethod(fx, a, b, tol: tol, maxIter: maxIter);
            poly = null;
            lastXs = null;
            lastYs = null;
          });
          break;
        case Method.lagrange:
          final parsed = _parsePoints(pointsCtrl.text);
          final xs = parsed.$1;
          final ys = parsed.$2;
          final xe = double.tryParse(xEvalCtrl.text.trim());
          final r = buildLagrangePolynomial(xs, ys, xAt: xe);
          setState(() {
            poly = r;
            result = null;
            lastXs = xs;
            lastYs = ys;
          });
          break;
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openGitHub() async {
    final Uri url = Uri.parse('https://github.com/Kr36x');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showSnack('No se pudo abrir el perfil de GitHub');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis Numérico'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 900;
          final content = Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(
                    label: 'Método:',
                    field: DropdownButtonFormField<Method>(
                      value: method,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (m) => setState(() => method = m!),
                      items: const [
                        DropdownMenuItem(
                          value: Method.newton,
                          child: Text('Newton-Raphson'),
                        ),
                        DropdownMenuItem(
                          value: Method.fixedPoint,
                          child: Text('Punto fijo (x = g(x))'),
                        ),
                        DropdownMenuItem(
                          value: Method.bisection,
                          child: Text('Bisección'),
                        ),
                        DropdownMenuItem(
                          value: Method.secant,
                          child: Text('Secante'),
                        ),
                        DropdownMenuItem(
                          value: Method.falsePosition,
                          child: Text('Punto falso (Regula Falsi)'),
                        ),
                        DropdownMenuItem(
                          value: Method.lagrange,
                          child: Text('Interpolación (Lagrange: P(x))'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (method != Method.lagrange)
                    _card(
                      title: 'Funciones',
                      child: Column(
                        children: [
                          _row(
                            label: 'f(x):',
                            field: TextField(
                              controller: fCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Ej: sin(pi*x) - e^(-x)',
                              ),
                            ),
                          ),
                          if (method == Method.fixedPoint)
                            _row(
                              label: 'g(x):',
                              field: TextField(
                                controller: gCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Ej: cos(x)',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (method == Method.lagrange)
                    _card(
                      title: 'Datos para interpolación (Lagrange)',
                      child: Column(
                        children: [
                          _row(
                            label: 'Puntos (x,y):',
                            field: TextField(
                              controller: pointsCtrl,
                              maxLines: 1,
                              decoration: const InputDecoration(
                                hintText: 'Ej: 0,1; 1,2; 2,5',
                              ),
                            ),
                          ),
                          _row(
                            label: 'x* (opcional) a evaluar:',
                            field: TextField(
                              controller: xEvalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: 'Ej: 1.5',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (method != Method.lagrange) const SizedBox(height: 12),

                  if (method != Method.lagrange)
                    _card(
                      title: 'Parámetros',
                      child: Wrap(
                        runSpacing: 8,
                        spacing: 12,
                        children: [
                          if (method == Method.newton ||
                              method == Method.fixedPoint ||
                              method == Method.secant)
                            _mini('x0 / p0', x0Ctrl),
                          if (method == Method.secant) _mini('x1', x1Ctrl),
                          if (method == Method.bisection ||
                              method == Method.falsePosition ||
                              method == Method.fixedPoint)
                            _mini('a', aCtrl),
                          if (method == Method.bisection ||
                              method == Method.falsePosition ||
                              method == Method.fixedPoint)
                            _mini('b', bCtrl),
                          _mini('tol', tolCtrl),
                          _mini('maxIter', maxIterCtrl, isInt: true),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _run,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Calcular'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          result = null;
                          poly = null;
                          lastXs = null;
                          lastYs = null;
                        }),
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  if (result != null) _results(result!),
                  if (poly != null && lastXs != null && lastYs != null)
                    _polyResults(poly!, lastXs!, lastYs!),

                  const SizedBox(height: 48),
                  Text(
                    method == Method.lagrange
                        ? 'Ingresa al menos 2 puntos con x únicos. P(x) pasa por todos ellos. La gráfica incluye x* si lo das.'
                        : 'Tips: puedes usar pi y e en las expresiones (ej. sin(pi*x), e^(x)). También ** es aceptado como ^.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: InkWell(
                      onTap: _openGitHub,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.code, size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              '@Kr36x',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '· GitHub',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );

          if (!wide) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _results(MethodResult r) {
    final rows = r.log;
    return _card(
      title: 'Resultado (métodos de raíces)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('Aproximación: ${r.root}'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('pₙ')),
                DataColumn(label: Text('f(pₙ)')),
                DataColumn(label: Text('error')),
              ],
              rows: rows
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text('${e.iter}')),
                        DataCell(Text(e.pn.toString())),
                        DataCell(Text(e.fpn.toString())),
                        DataCell(
                          Text(e.error.isNaN ? '—' : e.error.toString()),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _polyResults(PolyResult r, List<double> xs, List<double> ys) {
    return _card(
      title: 'Interpolación de Lagrange — Polinomio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(r.readable),
          if (r.xAt != null && r.yAt != null) ...[
            const SizedBox(height: 8),
            SelectableText('P(${r.xAt}) = ${r.yAt}'),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            width: double.infinity, // <- evita que se aplaste
            child: _PolynomialPlot(
              coeffs: r.coeffs,
              xs: xs,
              ys: ys,
              xMark: r.xAt,
              yMark: r.yAt,
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Coeficientes (c0, c1, c2, ...)'),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: SelectableText(r.coeffs.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row({required String label, required Widget field}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _mini(String label, TextEditingController ctrl, {bool isInt = false}) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        decoration: InputDecoration(labelText: label),
        onChanged: (s) {
          if (isInt && int.tryParse(s.trim()) == null) return;
        },
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// ===============================
///  Gráfica del polinomio P(x)
/// ===============================
class _PolynomialPlot extends StatelessWidget {
  final List<double> coeffs;
  final List<double> xs;
  final List<double> ys;
  final double? xMark;
  final double? yMark;

  const _PolynomialPlot({
    required this.coeffs,
    required this.xs,
    required this.ys,
    this.xMark,
    this.yMark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PolyPainter(
        coeffs: coeffs,
        xs: xs,
        ys: ys,
        xMark: xMark,
        yMark: yMark,
        cs: Theme.of(context).colorScheme,
      ),
    );
  }
}

class _PolyPainter extends CustomPainter {
  final List<double> coeffs;
  final List<double> xs;
  final List<double> ys;
  final double? xMark;
  final double? yMark;
  final ColorScheme cs;

  _PolyPainter({
    required this.coeffs,
    required this.xs,
    required this.ys,
    required this.cs,
    this.xMark,
    this.yMark,
  });

  double _eval(List<double> c, double x) {
    double acc = 0.0;
    for (var i = c.length - 1; i >= 0; i--) acc = acc * x + c[i];
    return acc;
  }

  double _niceStep(double span) {
    final raw = span / 5.0; // ~5 divisiones
    final k = (math.log(raw) / math.ln10).floor();
    final pow10 = math.pow(10.0, k).toDouble();
    final base = raw / pow10;
    double nice;
    if (base < 1.5)
      nice = 1;
    else if (base < 3.5)
      nice = 2;
    else if (base < 7.5)
      nice = 5;
    else
      nice = 10;
    return nice * pow10;
  }

  (double, double) _niceBounds(double minV, double maxV, double step) {
    final nmin = (minV / step).floor() * step;
    final nmax = (maxV / step).ceil() * step;
    return (nmin, nmax);
  }

  Offset _toScreen(
    double x,
    double y,
    Rect r,
    double xmin,
    double xmax,
    double ymin,
    double ymax,
  ) {
    final sx = r.left + (x - xmin) / (xmax - xmin) * r.width;
    final sy = r.bottom - (y - ymin) / (ymax - ymin) * r.height;
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final R = Offset.zero & size;
    final pad = 36.0;
    final plot = Rect.fromLTWH(
      R.left + pad,
      R.top + 12,
      R.width - pad - 12,
      R.height - pad - 12,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // ===== Dominio =====
    double minX = xs.reduce(math.min);
    double maxX = xs.reduce(math.max);

    // Incluir x* si existe
    if (xMark != null && xMark!.isFinite) {
      minX = math.min(minX, xMark!);
      maxX = math.max(maxX, xMark!);
    }

    // Margen horizontal
    double dx = (maxX - minX).abs();
    if (dx == 0) dx = 1;
    minX -= 0.15 * dx;
    maxX += 0.15 * dx;

    // ===== Rango (muestreo + puntos + y*) =====
    const nSamples = 300;
    double minY = double.infinity, maxY = -double.infinity;
    for (int i = 0; i <= nSamples; i++) {
      final xx = minX + (maxX - minX) * i / nSamples;
      final yy = _eval(coeffs, xx);
      if (yy < minY) minY = yy;
      if (yy > maxY) maxY = yy;
    }
    for (var i = 0; i < xs.length; i++) {
      if (ys[i] < minY) minY = ys[i];
      if (ys[i] > maxY) maxY = ys[i];
    }
    // Incluir y* si existe (o evalúalo si no vino)
    double? yStar = yMark;
    if ((yStar == null || !yStar.isFinite) &&
        xMark != null &&
        xMark!.isFinite) {
      yStar = _eval(coeffs, xMark!);
    }
    if (xMark != null && xMark!.isFinite && yStar != null && yStar.isFinite) {
      if (yStar < minY) minY = yStar;
      if (yStar > maxY) maxY = yStar;
    }

    double dy = (maxY - minY).abs();
    if (dy == 0) dy = 1;
    minY -= 0.15 * dy;
    maxY += 0.15 * dy;

    // Pasos y límites "legibles"
    final xStep = _niceStep(maxX - minX);
    final yStep = _niceStep(maxY - minY);
    (minX, maxX) = _niceBounds(minX, maxX, xStep);
    (minY, maxY) = _niceBounds(minY, maxY, yStep);

    // ===== Fondo y grid =====
    final bg = Paint()
      ..color = cs.surfaceVariant.withOpacity(0.10)
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(12)),
      bg,
    );

    final grid = Paint()
      ..color = cs.outlineVariant.withOpacity(0.35)
      ..strokeWidth = 1;

    for (
      double x = (minX / xStep).ceil() * xStep;
      x <= maxX + 1e-9;
      x += xStep
    ) {
      final p0 = _toScreen(x, minY, plot, minX, maxX, minY, maxY);
      final p1 = _toScreen(x, maxY, plot, minX, maxX, minY, maxY);
      canvas.drawLine(p0, p1, grid);
    }
    for (
      double y = (minY / yStep).ceil() * yStep;
      y <= maxY + 1e-9;
      y += yStep
    ) {
      final p0 = _toScreen(minX, y, plot, minX, maxX, minY, maxY);
      final p1 = _toScreen(maxX, y, plot, minX, maxX, minY, maxY);
      canvas.drawLine(p0, p1, grid);
    }

    // ===== Ejes en 0 =====
    final axis = Paint()
      ..color = cs.onSurface.withOpacity(0.75)
      ..strokeWidth = 1.4;
    if (0 >= minX && 0 <= maxX) {
      canvas.drawLine(
        _toScreen(0, minY, plot, minX, maxX, minY, maxY),
        _toScreen(0, maxY, plot, minX, maxX, minY, maxY),
        axis,
      );
    }
    if (0 >= minY && 0 <= maxY) {
      canvas.drawLine(
        _toScreen(minX, 0, plot, minX, maxX, minY, maxY),
        _toScreen(maxX, 0, plot, minX, maxX, minY, maxY),
        axis,
      );
    }

    // Ticks y labels X
    for (
      double x = (minX / xStep).ceil() * xStep;
      x <= maxX + 1e-9;
      x += xStep
    ) {
      final p = _toScreen(x, minY, plot, minX, maxX, minY, maxY);
      tp.text = TextSpan(
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        text: _fmt(x),
      );
      tp.layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, plot.bottom + 2));
    }
    // Ticks y labels Y
    for (
      double y = (minY / yStep).ceil() * yStep;
      y <= maxY + 1e-9;
      y += yStep
    ) {
      final p = _toScreen(minX, y, plot, minX, maxX, minY, maxY);
      tp.text = TextSpan(
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        text: _fmt(y),
      );
      tp.layout();
      tp.paint(canvas, Offset(plot.left - tp.width - 6, p.dy - tp.height / 2));
    }

    // Guía vertical en x* (punteada)
    if (xMark != null && xMark!.isFinite && xMark! >= minX && xMark! <= maxX) {
      final p0 = _toScreen(xMark!, minY, plot, minX, maxX, minY, maxY);
      final p1 = _toScreen(xMark!, maxY, plot, minX, maxX, minY, maxY);
      final guide = Paint()
        ..color = cs.error.withOpacity(0.35)
        ..strokeWidth = 1.2;
      const dash = 6.0, gap = 4.0;
      double y = p0.dy;
      while (y < p1.dy) {
        final y2 = (y + dash).clamp(p0.dy, p1.dy);
        canvas.drawLine(Offset(p0.dx, y), Offset(p0.dx, y2), guide);
        y = y2 + gap;
      }
    }

    // Curva P(x)
    final path = Path();
    for (int i = 0; i <= nSamples; i++) {
      final xx = minX + (maxX - minX) * i / nSamples;
      final yy = _eval(coeffs, xx);
      final s = _toScreen(xx, yy, plot, minX, maxX, minY, maxY);
      if (i == 0)
        path.moveTo(s.dx, s.dy);
      else
        path.lineTo(s.dx, s.dy);
    }
    final curve = Paint()
      ..color = cs.primary
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(path, curve);

    // Puntos de datos (rombos)
    final fill = Paint()
      ..color = cs.tertiary
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = cs.onTertiaryContainer.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < xs.length; i++) {
      final p = _toScreen(xs[i], ys[i], plot, minX, maxX, minY, maxY);
      final rh = Path()
        ..moveTo(p.dx, p.dy - 4)
        ..lineTo(p.dx + 4, p.dy)
        ..lineTo(p.dx, p.dy + 4)
        ..lineTo(p.dx - 4, p.dy)
        ..close();
      canvas.drawPath(rh, fill);
      canvas.drawPath(rh, stroke);
    }

    // Marcador en (x*, y*)
    if (xMark != null && xMark!.isFinite && yStar != null && yStar!.isFinite) {
      final m = _toScreen(xMark!, yStar!, plot, minX, maxX, minY, maxY);
      final mark = Paint()
        ..color = cs.errorContainer
        ..isAntiAlias = true;
      canvas.drawCircle(m, 4.5, mark);
      final border = Paint()
        ..color = cs.onErrorContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(m, 4.5, border);

      // burbuja etiqueta
      final label = '(${_fmt(xMark!)}, ${_fmt(yStar!)})';
      tp.text = TextSpan(
        style: TextStyle(fontSize: 11, color: cs.onSurface),
        text: label,
      );
      tp.layout();
      final off = Offset(
        (m.dx + 6 + tp.width < plot.right) ? m.dx + 6 : m.dx - 6 - tp.width,
        (m.dy - 6 - tp.height > plot.top) ? m.dy - 6 - tp.height : m.dy + 6,
      );
      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(off.dx - 6, off.dy - 2, tp.width + 12, tp.height + 6),
        const Radius.circular(6),
      );
      final bubblePaint = Paint()..color = cs.surface.withOpacity(0.9);
      canvas.drawRRect(bubbleRect, bubblePaint);
      tp.paint(canvas, Offset(off.dx, off.dy));
    }

    // Leyenda
    final legendPad = 6.0;
    final items = <(Color, String)>[
      (cs.primary, 'P(x)'),
      (cs.tertiary, 'Datos'),
      if (xMark != null && (yStar != null && yStar!.isFinite))
        (cs.errorContainer, 'x*'),
    ];
    double lx = plot.left + 8, ly = plot.top + 8;
    for (final it in items) {
      final swatch = Paint()..color = it.$1;
      final rect = Rect.fromLTWH(lx, ly + 3, 14, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        swatch,
      );
      tp.text = TextSpan(
        style: TextStyle(fontSize: 12, color: cs.onSurface),
        text: ' ${it.$2}',
      );
      tp.layout();
      tp.paint(canvas, Offset(lx + 18, ly));
      lx += 18 + tp.width + legendPad;
    }
  }

  String _fmt(double v) {
    final r = double.parse(v.toStringAsFixed(6));
    final s = r.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  @override
  bool shouldRepaint(covariant _PolyPainter old) {
    return old.coeffs != coeffs ||
        old.xs != xs ||
        old.ys != ys ||
        old.xMark != xMark ||
        old.yMark != yMark;
  }
}
