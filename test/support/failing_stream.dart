/// A stream that fails the way a broken query does: [error] is thrown, so it
/// carries the throw's own stack. A stackless `Stream.error` gets the test
/// zone's whole capture chain instead, back to the runner's web socket, and a
/// load-error log that prints its stack then prints hundreds of lines of it.
Stream<T> failingStream<T>(Object error) async* {
  throw error;
}
