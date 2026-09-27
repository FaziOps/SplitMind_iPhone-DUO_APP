import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

/// Drops events until [duration] passes with no new event, then processes the
/// last one. Processing is sequential, so an in-flight request always finishes.
EventTransformer<E> debounceSequential<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).asyncExpand(mapper);
}
