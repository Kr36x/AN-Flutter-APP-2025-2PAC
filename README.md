# Análisis Numérico App

Una aplicación Flutter interactiva para la enseñanza y práctica de **métodos numéricos**.  
Permite resolver ecuaciones, encontrar raíces y construir polinomios de interpolación de manera visual, mostrando paso a paso las iteraciones y la gráfica correspondiente.

---

##  Características principales

### Métodos de raíces implementados
- **Newton-Raphson**
- **Punto fijo (x = g(x))**
- **Bisección**
- **Secante**
- **Punto falso (Regula Falsi)**

Cada método muestra:
- Tabla con iteraciones (`pₙ`, `f(pₙ)`, `error`)
- Resultado aproximado de la raíz
- Control de tolerancia y máximo de iteraciones

---

### Interpolación de Lagrange
Construye el **polinomio de interpolación** que pasa exactamente por los puntos ingresados.

- Devuelve el **polinomio explícito**  
  Ejemplo:  P(x) = 1.0 + 3.5·x - 1.5·x²
- Muestra los **coeficientes numéricos** `[c₀, c₁, c₂, ...]`
- Evalúa el polinomio en un punto opcional `x*`
- Dibuja una **gráfica interactiva**:
- Curva de `P(x)`
- Puntos de datos
- Marcador del punto evaluado `x*`
- Rejilla, ejes y leyenda automática

---

## Ejemplo de uso

1. Selecciona un método desde el menú desplegable.
2. Ingresa la función (por ejemplo, `f(x) = x^3 - x - 1`).
3. Define los parámetros necesarios (intervalos o valores iniciales).
4. Presiona **“Calcular”**.
5. Visualiza los resultados en la tabla o la gráfica (según el método).

Para la interpolación de Lagrange:

## Tecnologías utilizadas

- **Flutter 3.x**
- **Dart**
- **Material 3 (M3 Design)**
- **CustomPainter** para gráficas dinámicas
- **url_launcher** para enlaces externos (perfil GitHub)

## Autor

**@Kr36x** · [GitHub](https://github.com/Kr36x)  
Proyecto creado para aprendizaje y visualización de métodos numéricos con Flutter.
