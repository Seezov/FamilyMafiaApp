// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'protocol_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProtocolEntry {
  int get killedSlot =>
      throw _privateConstructorUsedError; // 1-indexed slot that was killed
  List<int> get colorGuesses => throw _privateConstructorUsedError;

  /// Create a copy of ProtocolEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProtocolEntryCopyWith<ProtocolEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProtocolEntryCopyWith<$Res> {
  factory $ProtocolEntryCopyWith(
    ProtocolEntry value,
    $Res Function(ProtocolEntry) then,
  ) = _$ProtocolEntryCopyWithImpl<$Res, ProtocolEntry>;
  @useResult
  $Res call({int killedSlot, List<int> colorGuesses});
}

/// @nodoc
class _$ProtocolEntryCopyWithImpl<$Res, $Val extends ProtocolEntry>
    implements $ProtocolEntryCopyWith<$Res> {
  _$ProtocolEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProtocolEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? killedSlot = null, Object? colorGuesses = null}) {
    return _then(
      _value.copyWith(
            killedSlot: null == killedSlot
                ? _value.killedSlot
                : killedSlot // ignore: cast_nullable_to_non_nullable
                      as int,
            colorGuesses: null == colorGuesses
                ? _value.colorGuesses
                : colorGuesses // ignore: cast_nullable_to_non_nullable
                      as List<int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProtocolEntryImplCopyWith<$Res>
    implements $ProtocolEntryCopyWith<$Res> {
  factory _$$ProtocolEntryImplCopyWith(
    _$ProtocolEntryImpl value,
    $Res Function(_$ProtocolEntryImpl) then,
  ) = __$$ProtocolEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int killedSlot, List<int> colorGuesses});
}

/// @nodoc
class __$$ProtocolEntryImplCopyWithImpl<$Res>
    extends _$ProtocolEntryCopyWithImpl<$Res, _$ProtocolEntryImpl>
    implements _$$ProtocolEntryImplCopyWith<$Res> {
  __$$ProtocolEntryImplCopyWithImpl(
    _$ProtocolEntryImpl _value,
    $Res Function(_$ProtocolEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProtocolEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? killedSlot = null, Object? colorGuesses = null}) {
    return _then(
      _$ProtocolEntryImpl(
        killedSlot: null == killedSlot
            ? _value.killedSlot
            : killedSlot // ignore: cast_nullable_to_non_nullable
                  as int,
        colorGuesses: null == colorGuesses
            ? _value._colorGuesses
            : colorGuesses // ignore: cast_nullable_to_non_nullable
                  as List<int>,
      ),
    );
  }
}

/// @nodoc

class _$ProtocolEntryImpl implements _ProtocolEntry {
  const _$ProtocolEntryImpl({
    required this.killedSlot,
    final List<int> colorGuesses = const [],
  }) : _colorGuesses = colorGuesses;

  @override
  final int killedSlot;
  // 1-indexed slot that was killed
  final List<int> _colorGuesses;
  // 1-indexed slot that was killed
  @override
  @JsonKey()
  List<int> get colorGuesses {
    if (_colorGuesses is EqualUnmodifiableListView) return _colorGuesses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_colorGuesses);
  }

  @override
  String toString() {
    return 'ProtocolEntry(killedSlot: $killedSlot, colorGuesses: $colorGuesses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProtocolEntryImpl &&
            (identical(other.killedSlot, killedSlot) ||
                other.killedSlot == killedSlot) &&
            const DeepCollectionEquality().equals(
              other._colorGuesses,
              _colorGuesses,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    killedSlot,
    const DeepCollectionEquality().hash(_colorGuesses),
  );

  /// Create a copy of ProtocolEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProtocolEntryImplCopyWith<_$ProtocolEntryImpl> get copyWith =>
      __$$ProtocolEntryImplCopyWithImpl<_$ProtocolEntryImpl>(this, _$identity);
}

abstract class _ProtocolEntry implements ProtocolEntry {
  const factory _ProtocolEntry({
    required final int killedSlot,
    final List<int> colorGuesses,
  }) = _$ProtocolEntryImpl;

  @override
  int get killedSlot; // 1-indexed slot that was killed
  @override
  List<int> get colorGuesses;

  /// Create a copy of ProtocolEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProtocolEntryImplCopyWith<_$ProtocolEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
