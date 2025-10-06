/// A generic type for representing a value that can be either a success (`Right`)
/// or a failure (`Left`). This is a simplified version of what a package like
/// `fpdart` provides. Your project can use its own `Either` type.
sealed class Either<L, R> {
  const Either();
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
}

/// A generic Failure class. Projects can define their own more specific failures.
class Failure {
  final String message;
  const Failure(this.message);
}

/// A `typedef` for a `Future` that resolves to an `Either` type.
///
/// By convention, `Left` represents a `Failure` and `Right` represents a
/// success value of type [T]. This is the return type that the `architecture_kit`
/// linter enforces for repository and use case methods.
typedef FutureEither<T> = Future<Either<Failure, T>>;

/// An abstract interface for a use case that takes one parameter ([Input]) and
/// returns a value of type [Output].
abstract interface class UnaryUsecase<Output, Input> {
  const UnaryUsecase();

  /// Executes the use case.
  FutureEither<Output> call(Input params);
}

/// An abstract interface for a use case that takes no parameters and
/// returns a value of type [Output].
abstract interface class NullaryUsecase<Output> {
  const NullaryUsecase();

  /// Executes the use case.
  FutureEither<Output> call();
}
