import 'package:equatable/equatable.dart';

import '../value_objects/email.dart';
import '../value_objects/username.dart';

/// Read model del perfil del usuario autenticado (`GET /auth/me`, back#44).
/// Dart puro: reutiliza los VOs [Username]/[Email] para arrastrar sus
/// invariantes de dominio (misma política que el back) en vez de exponer
/// `String` sueltos. Inmutable y con igualdad por valor para que la UI pueda
/// reaccionar y compararlo sin conocer detalles de red.
class UserProfile extends Equatable {
  final String id;
  final Username username;
  final Email email;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
  });

  @override
  List<Object?> get props => [id, username, email];
}
