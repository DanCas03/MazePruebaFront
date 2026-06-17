// Stub — reemplazado en Phase 2B.7
import 'command.dart';

class CommandInvoker {
  final List<ICommand> _history = [];
  bool get canUndo => _history.isNotEmpty;
  void clearHistory() => _history.clear();
}
