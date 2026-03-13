// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Game {
  int get seasonId => throw _privateConstructorUsedError;
  List<String> get players => throw _privateConstructorUsedError;
  List<String> get roles =>
      throw _privateConstructorUsedError; // true = city won, false = mafia won, null = non-rating game
  bool? get cityWon => throw _privateConstructorUsedError;
  int get firstKilled => throw _privateConstructorUsedError;
  double get bestMovePoints => throw _privateConstructorUsedError;
  List<int> get bestMove => throw _privateConstructorUsedError;
  List<double>? get additionalPoints => throw _privateConstructorUsedError;
  List<double>? get penaltyPoints => throw _privateConstructorUsedError;
  List<double>? get autoAdditionalPoints => throw _privateConstructorUsedError;
  List<String>? get wonByPlayer => throw _privateConstructorUsedError;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameCopyWith<Game> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameCopyWith<$Res> {
  factory $GameCopyWith(Game value, $Res Function(Game) then) =
      _$GameCopyWithImpl<$Res, Game>;
  @useResult
  $Res call({
    int seasonId,
    List<String> players,
    List<String> roles,
    bool? cityWon,
    int firstKilled,
    double bestMovePoints,
    List<int> bestMove,
    List<double>? additionalPoints,
    List<double>? penaltyPoints,
    List<double>? autoAdditionalPoints,
    List<String>? wonByPlayer,
  });
}

/// @nodoc
class _$GameCopyWithImpl<$Res, $Val extends Game>
    implements $GameCopyWith<$Res> {
  _$GameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seasonId = null,
    Object? players = null,
    Object? roles = null,
    Object? cityWon = freezed,
    Object? firstKilled = null,
    Object? bestMovePoints = null,
    Object? bestMove = null,
    Object? additionalPoints = freezed,
    Object? penaltyPoints = freezed,
    Object? autoAdditionalPoints = freezed,
    Object? wonByPlayer = freezed,
  }) {
    return _then(
      _value.copyWith(
            seasonId: null == seasonId
                ? _value.seasonId
                : seasonId // ignore: cast_nullable_to_non_nullable
                      as int,
            players: null == players
                ? _value.players
                : players // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            roles: null == roles
                ? _value.roles
                : roles // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            cityWon: freezed == cityWon
                ? _value.cityWon
                : cityWon // ignore: cast_nullable_to_non_nullable
                      as bool?,
            firstKilled: null == firstKilled
                ? _value.firstKilled
                : firstKilled // ignore: cast_nullable_to_non_nullable
                      as int,
            bestMovePoints: null == bestMovePoints
                ? _value.bestMovePoints
                : bestMovePoints // ignore: cast_nullable_to_non_nullable
                      as double,
            bestMove: null == bestMove
                ? _value.bestMove
                : bestMove // ignore: cast_nullable_to_non_nullable
                      as List<int>,
            additionalPoints: freezed == additionalPoints
                ? _value.additionalPoints
                : additionalPoints // ignore: cast_nullable_to_non_nullable
                      as List<double>?,
            penaltyPoints: freezed == penaltyPoints
                ? _value.penaltyPoints
                : penaltyPoints // ignore: cast_nullable_to_non_nullable
                      as List<double>?,
            autoAdditionalPoints: freezed == autoAdditionalPoints
                ? _value.autoAdditionalPoints
                : autoAdditionalPoints // ignore: cast_nullable_to_non_nullable
                      as List<double>?,
            wonByPlayer: freezed == wonByPlayer
                ? _value.wonByPlayer
                : wonByPlayer // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GameImplCopyWith<$Res> implements $GameCopyWith<$Res> {
  factory _$$GameImplCopyWith(
    _$GameImpl value,
    $Res Function(_$GameImpl) then,
  ) = __$$GameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int seasonId,
    List<String> players,
    List<String> roles,
    bool? cityWon,
    int firstKilled,
    double bestMovePoints,
    List<int> bestMove,
    List<double>? additionalPoints,
    List<double>? penaltyPoints,
    List<double>? autoAdditionalPoints,
    List<String>? wonByPlayer,
  });
}

/// @nodoc
class __$$GameImplCopyWithImpl<$Res>
    extends _$GameCopyWithImpl<$Res, _$GameImpl>
    implements _$$GameImplCopyWith<$Res> {
  __$$GameImplCopyWithImpl(_$GameImpl _value, $Res Function(_$GameImpl) _then)
    : super(_value, _then);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seasonId = null,
    Object? players = null,
    Object? roles = null,
    Object? cityWon = freezed,
    Object? firstKilled = null,
    Object? bestMovePoints = null,
    Object? bestMove = null,
    Object? additionalPoints = freezed,
    Object? penaltyPoints = freezed,
    Object? autoAdditionalPoints = freezed,
    Object? wonByPlayer = freezed,
  }) {
    return _then(
      _$GameImpl(
        seasonId: null == seasonId
            ? _value.seasonId
            : seasonId // ignore: cast_nullable_to_non_nullable
                  as int,
        players: null == players
            ? _value._players
            : players // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        roles: null == roles
            ? _value._roles
            : roles // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        cityWon: freezed == cityWon
            ? _value.cityWon
            : cityWon // ignore: cast_nullable_to_non_nullable
                  as bool?,
        firstKilled: null == firstKilled
            ? _value.firstKilled
            : firstKilled // ignore: cast_nullable_to_non_nullable
                  as int,
        bestMovePoints: null == bestMovePoints
            ? _value.bestMovePoints
            : bestMovePoints // ignore: cast_nullable_to_non_nullable
                  as double,
        bestMove: null == bestMove
            ? _value._bestMove
            : bestMove // ignore: cast_nullable_to_non_nullable
                  as List<int>,
        additionalPoints: freezed == additionalPoints
            ? _value._additionalPoints
            : additionalPoints // ignore: cast_nullable_to_non_nullable
                  as List<double>?,
        penaltyPoints: freezed == penaltyPoints
            ? _value._penaltyPoints
            : penaltyPoints // ignore: cast_nullable_to_non_nullable
                  as List<double>?,
        autoAdditionalPoints: freezed == autoAdditionalPoints
            ? _value._autoAdditionalPoints
            : autoAdditionalPoints // ignore: cast_nullable_to_non_nullable
                  as List<double>?,
        wonByPlayer: freezed == wonByPlayer
            ? _value._wonByPlayer
            : wonByPlayer // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
      ),
    );
  }
}

/// @nodoc

class _$GameImpl extends _Game {
  const _$GameImpl({
    required this.seasonId,
    required final List<String> players,
    required final List<String> roles,
    this.cityWon,
    required this.firstKilled,
    required this.bestMovePoints,
    required final List<int> bestMove,
    final List<double>? additionalPoints,
    final List<double>? penaltyPoints,
    final List<double>? autoAdditionalPoints,
    final List<String>? wonByPlayer,
  }) : _players = players,
       _roles = roles,
       _bestMove = bestMove,
       _additionalPoints = additionalPoints,
       _penaltyPoints = penaltyPoints,
       _autoAdditionalPoints = autoAdditionalPoints,
       _wonByPlayer = wonByPlayer,
       super._();

  @override
  final int seasonId;
  final List<String> _players;
  @override
  List<String> get players {
    if (_players is EqualUnmodifiableListView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_players);
  }

  final List<String> _roles;
  @override
  List<String> get roles {
    if (_roles is EqualUnmodifiableListView) return _roles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roles);
  }

  // true = city won, false = mafia won, null = non-rating game
  @override
  final bool? cityWon;
  @override
  final int firstKilled;
  @override
  final double bestMovePoints;
  final List<int> _bestMove;
  @override
  List<int> get bestMove {
    if (_bestMove is EqualUnmodifiableListView) return _bestMove;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bestMove);
  }

  final List<double>? _additionalPoints;
  @override
  List<double>? get additionalPoints {
    final value = _additionalPoints;
    if (value == null) return null;
    if (_additionalPoints is EqualUnmodifiableListView)
      return _additionalPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<double>? _penaltyPoints;
  @override
  List<double>? get penaltyPoints {
    final value = _penaltyPoints;
    if (value == null) return null;
    if (_penaltyPoints is EqualUnmodifiableListView) return _penaltyPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<double>? _autoAdditionalPoints;
  @override
  List<double>? get autoAdditionalPoints {
    final value = _autoAdditionalPoints;
    if (value == null) return null;
    if (_autoAdditionalPoints is EqualUnmodifiableListView)
      return _autoAdditionalPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _wonByPlayer;
  @override
  List<String>? get wonByPlayer {
    final value = _wonByPlayer;
    if (value == null) return null;
    if (_wonByPlayer is EqualUnmodifiableListView) return _wonByPlayer;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Game(seasonId: $seasonId, players: $players, roles: $roles, cityWon: $cityWon, firstKilled: $firstKilled, bestMovePoints: $bestMovePoints, bestMove: $bestMove, additionalPoints: $additionalPoints, penaltyPoints: $penaltyPoints, autoAdditionalPoints: $autoAdditionalPoints, wonByPlayer: $wonByPlayer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameImpl &&
            (identical(other.seasonId, seasonId) ||
                other.seasonId == seasonId) &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            const DeepCollectionEquality().equals(other._roles, _roles) &&
            (identical(other.cityWon, cityWon) || other.cityWon == cityWon) &&
            (identical(other.firstKilled, firstKilled) ||
                other.firstKilled == firstKilled) &&
            (identical(other.bestMovePoints, bestMovePoints) ||
                other.bestMovePoints == bestMovePoints) &&
            const DeepCollectionEquality().equals(other._bestMove, _bestMove) &&
            const DeepCollectionEquality().equals(
              other._additionalPoints,
              _additionalPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._penaltyPoints,
              _penaltyPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._autoAdditionalPoints,
              _autoAdditionalPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._wonByPlayer,
              _wonByPlayer,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    seasonId,
    const DeepCollectionEquality().hash(_players),
    const DeepCollectionEquality().hash(_roles),
    cityWon,
    firstKilled,
    bestMovePoints,
    const DeepCollectionEquality().hash(_bestMove),
    const DeepCollectionEquality().hash(_additionalPoints),
    const DeepCollectionEquality().hash(_penaltyPoints),
    const DeepCollectionEquality().hash(_autoAdditionalPoints),
    const DeepCollectionEquality().hash(_wonByPlayer),
  );

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      __$$GameImplCopyWithImpl<_$GameImpl>(this, _$identity);
}

abstract class _Game extends Game {
  const factory _Game({
    required final int seasonId,
    required final List<String> players,
    required final List<String> roles,
    final bool? cityWon,
    required final int firstKilled,
    required final double bestMovePoints,
    required final List<int> bestMove,
    final List<double>? additionalPoints,
    final List<double>? penaltyPoints,
    final List<double>? autoAdditionalPoints,
    final List<String>? wonByPlayer,
  }) = _$GameImpl;
  const _Game._() : super._();

  @override
  int get seasonId;
  @override
  List<String> get players;
  @override
  List<String> get roles; // true = city won, false = mafia won, null = non-rating game
  @override
  bool? get cityWon;
  @override
  int get firstKilled;
  @override
  double get bestMovePoints;
  @override
  List<int> get bestMove;
  @override
  List<double>? get additionalPoints;
  @override
  List<double>? get penaltyPoints;
  @override
  List<double>? get autoAdditionalPoints;
  @override
  List<String>? get wonByPlayer;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
