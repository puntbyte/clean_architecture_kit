import 'package:bloc/bloc.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';

import 'auth_bloc.dart'; // Just to import the state/event classes

// VIOLATION: presentation_layer_purity
// This BLoC incorrectly depends on the entire AuthRepository.
class AuthBlocViolations extends Bloc<AuthEvent, AuthState> {
  // It should depend on a specific UseCase instead.
  final AuthRepository _repository;

  AuthBlocViolations(
    this._repository, // <-- LINT WARNING HERE
  ) : super(AuthInitial());
}
