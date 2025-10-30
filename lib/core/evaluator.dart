import 'package:math_expressions/math_expressions.dart';
import 'dart:math' as math;

typedef RealFunc = double Function(double x);

final _parser = Parser();

String _sanitize(String s) {
  // Permite ** como ^, y reconoce PI mayúscula también
  return s.replaceAll('**', '^').replaceAll('PI', 'pi').trim();
}

Expression _compile(String expr) {
  final sanitized = _sanitize(expr);
  try {
    return _parser.parse(sanitized);
  } catch (e) {
    throw StateError(
      'No pude interpretar la expresión "$expr". '
      'Usa ^ para potencias o exp(...). Detalle: $e',
    );
  }
}

double evalScalar(String expr) {
  final e = _compile(expr);
  final cm = ContextModel()
    ..bindVariableName('e', Number(math.e))
    ..bindVariableName('pi', Number(math.pi));
  return e.evaluate(EvaluationType.REAL, cm);
}

RealFunc makeFunction(String expr) {
  final e = _compile(expr);
  return (double x) {
    final cm = ContextModel()
      ..bindVariableName('x', Number(x))
      ..bindVariableName('e', Number(math.e))
      ..bindVariableName('pi', Number(math.pi));
    return e.evaluate(EvaluationType.REAL, cm);
  };
}

RealFunc numericDerivative(RealFunc f, {double h = 1e-6}) {
  return (double x) => (f(x + h) - f(x - h)) / (2 * h);
}
