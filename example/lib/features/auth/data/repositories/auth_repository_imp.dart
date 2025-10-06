import 'package:example/core/utils/types.dart';
import 'package:example/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:example/features/auth/domain/entities/user.dart';
import 'package:example/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  const AuthRepositoryImpl(this._remoteDataSource);

  @override
  FutureEither<User> getUser(int id) async {
    return Right(User(id: '1', name: 'test'));
  }

  @override
  FutureEither<void> saveUser({required String name, required String password}) async {
    return const Right(null);
  }

  @override
  FutureEither<User?> getCurrentUser() async => const Right(null);
}
