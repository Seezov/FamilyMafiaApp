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
  List<double>? get protocolAdditionalPoints =>
      throw _privateConstructorUsedError;
  List<double>? get protocolPenaltyPoints => throw _privateConstructorUsedError;
  List<String>? get wonByPlayer => throw _privateConstructorUsedError;
  List<ProtocolEntry>? get protocol =>
      throw _privateConstructorUsedError; // ordered by kill order (index 0 = first killed)
  List<int>? get supportFive =>
      throw _privateConstructorUsedError; // up to 5 signed ints: abs=slot, positive=red, negative=black
  String? get host =>
      throw _privateConstructorUsedError; // who hosted (ведучий); null for seasons 0-1 or when blank
  DateTime? get date =>
      throw _privateConstructorUsedError; // game day (UTC midnight); null when unknown
  List<int>? get fouls =>
      throw _privateConstructorUsedError; // per slot 0..4; null for sheet seasons (fouls are not parsed there)
  List<GameComment>? get comments =>
      throw _privateConstructorUsedError; // host's comments, sheet order; null = none recorded
  String? get label =>
      throw _privateConstructorUsedError; // event label above the game in the sheet («МІНІКАП», «Гра 3»)
  int? get table => throw _privateConstructorUsedError;

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
    List<double>? protocolAdditionalPoints,
    List<double>? protocolPenaltyPoints,
    List<String>? wonByPlayer,
    List<ProtocolEntry>? protocol,
    List<int>? supportFive,
    String? host,
    DateTime? date,
    List<int>? fouls,
    List<GameComment>? comments,
    String? label,
    int? table,
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
    Object? protocolAdditionalPoints = freezed,
    Object? protocolPenaltyPoints = freezed,
    Object? wonByPlayer = freezed,
    Object? protocol = freezed,
    Object? supportFive = freezed,
    Object? host = freezed,
    Object? date = freezed,
    Object? fouls = freezed,
    Object? comments = freezed,
    Object? label = freezed,
    Object? table = freezed,
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
            protocolAdditionalPoints: freezed == protocolAdditionalPoints
                ? _value.protocolAdditionalPoints
                : protocolAdditionalPoints // ignore: cast_nullable_to_non_nullable
                      as List<double>?,
            protocolPenaltyPoints: freezed == protocolPenaltyPoints
                ? _value.protocolPenaltyPoints
                : protocolPenaltyPoints // ignore: cast_nullable_to_non_nullable
                      as List<double>?,
            wonByPlayer: freezed == wonByPlayer
                ? _value.wonByPlayer
                : wonByPlayer // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            protocol: freezed == protocol
                ? _value.protocol
                : protocol // ignore: cast_nullable_to_non_nullable
                      as List<ProtocolEntry>?,
            supportFive: freezed == supportFive
                ? _value.supportFive
                : supportFive // ignore: cast_nullable_to_non_nullable
                      as List<int>?,
            host: freezed == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as String?,
            date: freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            fouls: freezed == fouls
                ? _value.fouls
                : fouls // ignore: cast_nullable_to_non_nullable
                      as List<int>?,
            comments: freezed == comments
                ? _value.comments
                : comments // ignore: cast_nullable_to_non_nullable
                      as List<GameComment>?,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
            table: freezed == table
                ? _value.table
                : table // ignore: cast_nullable_to_non_nullable
                      as int?,
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
    List<double>? protocolAdditionalPoints,
    List<double>? protocolPenaltyPoints,
    List<String>? wonByPlayer,
    List<ProtocolEntry>? protocol,
    List<int>? supportFive,
    String? host,
    DateTime? date,
    List<int>? fouls,
    List<GameComment>? comments,
    String? label,
    int? table,
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
    Object? protocolAdditionalPoints = freezed,
    Object? protocolPenaltyPoints = freezed,
    Object? wonByPlayer = freezed,
    Object? protocol = freezed,
    Object? supportFive = freezed,
    Object? host = freezed,
    Object? date = freezed,
    Object? fouls = freezed,
    Object? comments = freezed,
    Object? label = freezed,
    Object? table = freezed,
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
        protocolAdditionalPoints: freezed == protocolAdditionalPoints
            ? _value._protocolAdditionalPoints
            : protocolAdditionalPoints // ignore: cast_nullable_to_non_nullable
                  as List<double>?,
        protocolPenaltyPoints: freezed == protocolPenaltyPoints
            ? _value._protocolPenaltyPoints
            : protocolPenaltyPoints // ignore: cast_nullable_to_non_nullable
                  as List<double>?,
        wonByPlayer: freezed == wonByPlayer
            ? _value._wonByPlayer
            : wonByPlayer // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        protocol: freezed == protocol
            ? _value._protocol
            : protocol // ignore: cast_nullable_to_non_nullable
                  as List<ProtocolEntry>?,
        supportFive: freezed == supportFive
            ? _value._supportFive
            : supportFive // ignore: cast_nullable_to_non_nullable
                  as List<int>?,
        host: freezed == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as String?,
        date: freezed == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        fouls: freezed == fouls
            ? _value._fouls
            : fouls // ignore: cast_nullable_to_non_nullable
                  as List<int>?,
        comments: freezed == comments
            ? _value._comments
            : comments // ignore: cast_nullable_to_non_nullable
                  as List<GameComment>?,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
        table: freezed == table
            ? _value.table
            : table // ignore: cast_nullable_to_non_nullable
                  as int?,
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
    final List<double>? protocolAdditionalPoints,
    final List<double>? protocolPenaltyPoints,
    final List<String>? wonByPlayer,
    final List<ProtocolEntry>? protocol,
    final List<int>? supportFive,
    this.host,
    this.date,
    final List<int>? fouls,
    final List<GameComment>? comments,
    this.label,
    this.table,
  }) : _players = players,
       _roles = roles,
       _bestMove = bestMove,
       _additionalPoints = additionalPoints,
       _penaltyPoints = penaltyPoints,
       _autoAdditionalPoints = autoAdditionalPoints,
       _protocolAdditionalPoints = protocolAdditionalPoints,
       _protocolPenaltyPoints = protocolPenaltyPoints,
       _wonByPlayer = wonByPlayer,
       _protocol = protocol,
       _supportFive = supportFive,
       _fouls = fouls,
       _comments = comments,
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

  final List<double>? _protocolAdditionalPoints;
  @override
  List<double>? get protocolAdditionalPoints {
    final value = _protocolAdditionalPoints;
    if (value == null) return null;
    if (_protocolAdditionalPoints is EqualUnmodifiableListView)
      return _protocolAdditionalPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<double>? _protocolPenaltyPoints;
  @override
  List<double>? get protocolPenaltyPoints {
    final value = _protocolPenaltyPoints;
    if (value == null) return null;
    if (_protocolPenaltyPoints is EqualUnmodifiableListView)
      return _protocolPenaltyPoints;
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

  final List<ProtocolEntry>? _protocol;
  @override
  List<ProtocolEntry>? get protocol {
    final value = _protocol;
    if (value == null) return null;
    if (_protocol is EqualUnmodifiableListView) return _protocol;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // ordered by kill order (index 0 = first killed)
  final List<int>? _supportFive;
  // ordered by kill order (index 0 = first killed)
  @override
  List<int>? get supportFive {
    final value = _supportFive;
    if (value == null) return null;
    if (_supportFive is EqualUnmodifiableListView) return _supportFive;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // up to 5 signed ints: abs=slot, positive=red, negative=black
  @override
  final String? host;
  // who hosted (ведучий); null for seasons 0-1 or when blank
  @override
  final DateTime? date;
  // game day (UTC midnight); null when unknown
  final List<int>? _fouls;
  // game day (UTC midnight); null when unknown
  @override
  List<int>? get fouls {
    final value = _fouls;
    if (value == null) return null;
    if (_fouls is EqualUnmodifiableListView) return _fouls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // per slot 0..4; null for sheet seasons (fouls are not parsed there)
  final List<GameComment>? _comments;
  // per slot 0..4; null for sheet seasons (fouls are not parsed there)
  @override
  List<GameComment>? get comments {
    final value = _comments;
    if (value == null) return null;
    if (_comments is EqualUnmodifiableListView) return _comments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // host's comments, sheet order; null = none recorded
  @override
  final String? label;
  // event label above the game in the sheet («МІНІКАП», «Гра 3»)
  @override
  final int? table;

  @override
  String toString() {
    return 'Game(seasonId: $seasonId, players: $players, roles: $roles, cityWon: $cityWon, firstKilled: $firstKilled, bestMovePoints: $bestMovePoints, bestMove: $bestMove, additionalPoints: $additionalPoints, penaltyPoints: $penaltyPoints, autoAdditionalPoints: $autoAdditionalPoints, protocolAdditionalPoints: $protocolAdditionalPoints, protocolPenaltyPoints: $protocolPenaltyPoints, wonByPlayer: $wonByPlayer, protocol: $protocol, supportFive: $supportFive, host: $host, date: $date, fouls: $fouls, comments: $comments, label: $label, table: $table)';
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
              other._protocolAdditionalPoints,
              _protocolAdditionalPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._protocolPenaltyPoints,
              _protocolPenaltyPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._wonByPlayer,
              _wonByPlayer,
            ) &&
            const DeepCollectionEquality().equals(other._protocol, _protocol) &&
            const DeepCollectionEquality().equals(
              other._supportFive,
              _supportFive,
            ) &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._fouls, _fouls) &&
            const DeepCollectionEquality().equals(other._comments, _comments) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.table, table) || other.table == table));
  }

  @override
  int get hashCode => Object.hashAll([
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
    const DeepCollectionEquality().hash(_protocolAdditionalPoints),
    const DeepCollectionEquality().hash(_protocolPenaltyPoints),
    const DeepCollectionEquality().hash(_wonByPlayer),
    const DeepCollectionEquality().hash(_protocol),
    const DeepCollectionEquality().hash(_supportFive),
    host,
    date,
    const DeepCollectionEquality().hash(_fouls),
    const DeepCollectionEquality().hash(_comments),
    label,
    table,
  ]);

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
    final List<double>? protocolAdditionalPoints,
    final List<double>? protocolPenaltyPoints,
    final List<String>? wonByPlayer,
    final List<ProtocolEntry>? protocol,
    final List<int>? supportFive,
    final String? host,
    final DateTime? date,
    final List<int>? fouls,
    final List<GameComment>? comments,
    final String? label,
    final int? table,
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
  List<double>? get protocolAdditionalPoints;
  @override
  List<double>? get protocolPenaltyPoints;
  @override
  List<String>? get wonByPlayer;
  @override
  List<ProtocolEntry>? get protocol; // ordered by kill order (index 0 = first killed)
  @override
  List<int>? get supportFive; // up to 5 signed ints: abs=slot, positive=red, negative=black
  @override
  String? get host; // who hosted (ведучий); null for seasons 0-1 or when blank
  @override
  DateTime? get date; // game day (UTC midnight); null when unknown
  @override
  List<int>? get fouls; // per slot 0..4; null for sheet seasons (fouls are not parsed there)
  @override
  List<GameComment>? get comments; // host's comments, sheet order; null = none recorded
  @override
  String? get label; // event label above the game in the sheet («МІНІКАП», «Гра 3»)
  @override
  int? get table;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GameComment {
  List<int> get seats =>
      throw _privateConstructorUsedError; // 1-indexed; empty = about the whole game
  String get text => throw _privateConstructorUsedError;

  /// Create a copy of GameComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameCommentCopyWith<GameComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameCommentCopyWith<$Res> {
  factory $GameCommentCopyWith(
    GameComment value,
    $Res Function(GameComment) then,
  ) = _$GameCommentCopyWithImpl<$Res, GameComment>;
  @useResult
  $Res call({List<int> seats, String text});
}

/// @nodoc
class _$GameCommentCopyWithImpl<$Res, $Val extends GameComment>
    implements $GameCommentCopyWith<$Res> {
  _$GameCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? seats = null, Object? text = null}) {
    return _then(
      _value.copyWith(
            seats: null == seats
                ? _value.seats
                : seats // ignore: cast_nullable_to_non_nullable
                      as List<int>,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GameCommentImplCopyWith<$Res>
    implements $GameCommentCopyWith<$Res> {
  factory _$$GameCommentImplCopyWith(
    _$GameCommentImpl value,
    $Res Function(_$GameCommentImpl) then,
  ) = __$$GameCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<int> seats, String text});
}

/// @nodoc
class __$$GameCommentImplCopyWithImpl<$Res>
    extends _$GameCommentCopyWithImpl<$Res, _$GameCommentImpl>
    implements _$$GameCommentImplCopyWith<$Res> {
  __$$GameCommentImplCopyWithImpl(
    _$GameCommentImpl _value,
    $Res Function(_$GameCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GameComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? seats = null, Object? text = null}) {
    return _then(
      _$GameCommentImpl(
        seats: null == seats
            ? _value._seats
            : seats // ignore: cast_nullable_to_non_nullable
                  as List<int>,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$GameCommentImpl implements _GameComment {
  const _$GameCommentImpl({
    final List<int> seats = const [],
    required this.text,
  }) : _seats = seats;

  final List<int> _seats;
  @override
  @JsonKey()
  List<int> get seats {
    if (_seats is EqualUnmodifiableListView) return _seats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seats);
  }

  // 1-indexed; empty = about the whole game
  @override
  final String text;

  @override
  String toString() {
    return 'GameComment(seats: $seats, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameCommentImpl &&
            const DeepCollectionEquality().equals(other._seats, _seats) &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_seats),
    text,
  );

  /// Create a copy of GameComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameCommentImplCopyWith<_$GameCommentImpl> get copyWith =>
      __$$GameCommentImplCopyWithImpl<_$GameCommentImpl>(this, _$identity);
}

abstract class _GameComment implements GameComment {
  const factory _GameComment({
    final List<int> seats,
    required final String text,
  }) = _$GameCommentImpl;

  @override
  List<int> get seats; // 1-indexed; empty = about the whole game
  @override
  String get text;

  /// Create a copy of GameComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameCommentImplCopyWith<_$GameCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
