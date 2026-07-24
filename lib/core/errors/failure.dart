import 'package:equatable/equatable.dart';

/// Representa un error controlado que puede mostrar la interfaz.
class Failure extends Equatable {
  const Failure(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

class ValidationFailure extends Failure { const ValidationFailure(super.message, {super.code, super.statusCode}); }
class UnauthorizedFailure extends Failure { const UnauthorizedFailure(super.message, {super.code, super.statusCode}); }
class NotFoundFailure extends Failure { const NotFoundFailure(super.message, {super.code, super.statusCode}); }
class ServerFailure extends Failure { const ServerFailure(super.message, {super.code, super.statusCode}); }
