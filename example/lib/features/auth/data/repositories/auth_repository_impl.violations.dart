import 'package:example/core/utils/types.dart';
import 'package:example/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:example/features/auth/data/model/user_model.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

class BadDependencyRepositoryImpl implements AuthRepository {
  // VIOLATION: enforce_abstract_data_source_dependency (depends on concrete implementation)
  final DefaultAuthRemoteDataSource dataSource;

  const BadDependencyRepositoryImpl(
    this.dataSource, // <-- LINT ERROR HERE
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class BadMappingRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource dataSource;

  const BadMappingRepositoryImpl(this.dataSource);

  @override
  // VIOLATION: repository_implementation_purity (must return Entity `User`, not Model `UserModel`)
  FutureEither<UserModel> getUser(int id) async { // <-- LINT ERROR HERE
    // This implementation "forgets" to map the model to an entity.
    return const Right(UserModel(id: '1', name: 'Bad User'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
