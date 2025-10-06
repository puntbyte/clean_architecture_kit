import 'package:example/core/utils/types.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';
import 'package:injectable/injectable.dart';
import '/core/usecase/usecase.dart';

typedef _SaveUserParams = ({String name, String password});

@Injectable()
final class SaveUserUsecase implements UnaryUsecase<void, _SaveUserParams> {
  const SaveUserUsecase(this.repository);

  @override
  final AuthRepository repository;

  @override
  FutureEither<void> call(_SaveUserParams params) =>
      repository.saveUser(name: params.name, password: params.password);
}
