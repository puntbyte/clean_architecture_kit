import 'package:example/features/auth/domain/entities/user.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';
import 'package:injectable/injectable.dart';
import '/core/usecase/usecase.dart';
import '/core/utils/types.dart';

@Injectable()
final class GetUserUsecase implements UnaryUsecase<User, int> {
  const GetUserUsecase(this.repository);

  @override
  final AuthRepository repository;

  @override
  FutureEither<User> call(int id) => repository.getUser(id);
}
