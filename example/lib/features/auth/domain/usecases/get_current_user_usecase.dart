import 'package:example/core/utils/types.dart';
import 'package:example/features/auth/domain/entities/user.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/src/either.dart';
import 'package:injectable/injectable.dart';
import '/core/usecase/usecase.dart';
import '/core/utils/types.dart';

@Injectable()
final class GetCurrentUserUsecase implements NullaryUsecase<User?> {
  const GetCurrentUserUsecase(this.repository);

  final AuthRepository repository;

  @override
  FutureEither<User?> call() => repository.getCurrentUser();
}
