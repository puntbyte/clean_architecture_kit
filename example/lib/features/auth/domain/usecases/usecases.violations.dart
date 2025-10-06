import 'package:example/core/usecase/usecase.dart';

// VIOLATION: enforce_use_case_inheritance (does not implement a base use case)
class LogoutUser {
  const LogoutUser();
}

// VIOLATION: enforce_naming_conventions (should be `LoginUsecase`)
class Login implements UnaryUsecase<void, void> { // <-- LINT WARNING HERE
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// VIOLATION: enforce_file_and_folder_location (should be in data/repositories)
class AuthRepositoryImpl { // <-- LINT WARNING HERE
  const AuthRepositoryImpl();
}
