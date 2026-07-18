/// Direcciones de deslizamiento. Los 4 primeros (orden congelado) son la
/// geometría rectangular original; los 4 diagonales habilitan las 6 direcciones
/// de un hex flat-top (ADR-0007 D2). El string wire es el `name` camelCase
/// idéntico ("upLeft"): el decoder compara por nombre. Cada espacio publica su
/// subconjunto real vía `BoardSpace.directions`.
enum Direction { up, down, left, right, upLeft, upRight, downLeft, downRight }
