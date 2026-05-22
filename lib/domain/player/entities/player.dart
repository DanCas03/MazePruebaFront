// lib/domain/player/entities/player.dart

import '../../game_core/value_objects/position.dart';

class Player {
  // Estado actual
  Position currentPosition;
  
  // Estado interno privado (notar el guion bajo en Dart)
  final List<Position> _movementHistory;

  Player({required this.currentPosition}) 
      : _movementHistory = [currentPosition]; // El historial nace con la posición inicial

  /// Exponemos el historial como una lista INMUTABLE.
  /// Esto evita que otra capa modifique el historial usando .add() o .remove()
  List<Position> get movementHistory => List.unmodifiable(_movementHistory);

  /// Cantidad de pasos dados (útil para el sistema de estrellas/puntuación)
  int get moveCount => _movementHistory.length - 1;

  /// Método oficial para mover al jugador
  void moveTo(Position newPosition) {
    currentPosition = newPosition;
    _movementHistory.add(newPosition);
  }

  /// Método para deshacer el último movimiento (Base para el patrón Memento/Command)
  bool undoLastMove() {
    // Solo podemos deshacer si hay más de un elemento (no podemos borrar el inicio)
    if (_movementHistory.length > 1) {
      _movementHistory.removeLast();
      currentPosition = _movementHistory.last;
      return true; // Se deshizo con éxito
    }
    return false; // No hay más movimientos para deshacer
  }
}