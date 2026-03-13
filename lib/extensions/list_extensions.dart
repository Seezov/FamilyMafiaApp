extension ListChunked<T> on List<T> {
  List<List<T>> chunked(int size) {
    final result = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      result.add(sublist(i, (i + size).clamp(0, length)));
    }
    return result;
  }

  T? maxByOrNull<R extends Comparable<R>>(R Function(T) selector) {
    if (isEmpty) return null;
    return reduce((a, b) => selector(a).compareTo(selector(b)) >= 0 ? a : b);
  }

  List<T> sortedByDescending<R extends Comparable<R>>(R Function(T) selector) {
    final copy = [...this];
    copy.sort((a, b) => selector(b).compareTo(selector(a)));
    return copy;
  }

  double sumOfDouble(double Function(T) selector) =>
      fold(0.0, (acc, e) => acc + selector(e));

  int sumOfInt(int Function(T) selector) =>
      fold(0, (acc, e) => acc + selector(e));
}
