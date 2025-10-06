import 'package:bloc/bloc.dart';
import 'package:example/features/auth/domain/usecases/get_current_user_usecase.dart';

// This is a placeholder for a real BLoC.
// Notice it correctly depends on a UseCase, not a Repository.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUsecase _getCurrentUser;

  AuthBloc(this._getCurrentUser) : super(AuthInitial());
}

sealed class AuthEvent {}

sealed class AuthState {}

class AuthInitial extends AuthState {}
