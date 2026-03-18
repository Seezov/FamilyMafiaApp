import 'package:freezed_annotation/freezed_annotation.dart';

part 'protocol_entry.freezed.dart';

@freezed
class ProtocolEntry with _$ProtocolEntry {
  const factory ProtocolEntry({
    required int killedSlot, // 1-indexed slot that was killed
    @Default([]) List<int> colorGuesses, // signed ints: abs=slot, positive=red, negative=black
  }) = _ProtocolEntry;
}
