part of '../home_screen.dart';

enum _Accent { positive, negative }

class _PlayerCard extends StatefulWidget {
  final RatingPlayerStats rating;
  final int rank;

  const _PlayerCard({required this.rating, required this.rank});

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rating = widget.rating;
    final rank = widget.rank;

    final (rankBg, rankFg) = switch (rank) {
      1 => (const Color(0xFFFFD700), Colors.black87),
      2 => (const Color(0xFFB0BEC5), Colors.black87),
      3 => (const Color(0xFFBF8970), Colors.white),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    final winRatePct = rating.winRate * 100;
    final (wrFg, wrBg) = winRatePct >= 50
        ? (Colors.green.shade700, Colors.green.shade50)
        : winRatePct >= 35
            ? (Colors.amber.shade800, Colors.amber.shade50)
            : (Colors.red.shade700, Colors.red.shade50);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              // Collapsed header row
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: rankBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: tt.labelMedium?.copyWith(
                        color: rankFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rating.player.displayName,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Win-rate pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: wrBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${winRatePct.roundTo(1)}%',
                      style: tt.labelSmall?.copyWith(
                        color: wrFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rating coefficient
                  Text(
                    rating.ratingCoefficient.roundTo(2).toString(),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              // Expanded details
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _ExpandedStats(rating: rating),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded stats section
// ---------------------------------------------------------------------------

class _ExpandedStats extends StatelessWidget {
  final RatingPlayerStats rating;

  const _ExpandedStats({required this.rating});

  Widget _row(List<Widget> tiles) => Row(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: tiles[i]),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row([
          _StatTile(label: 'Games', value: '${rating.wins}/${rating.gamesPlayed}'),
          _StatTile(label: 'Add. Pts', value: rating.additionalPoints.roundTo(2).toString(), accent: _Accent.positive),
          _StatTile(label: 'Penalty', value: rating.penaltyPoints.roundTo(2).toString(), accent: _Accent.negative),
          _StatTile(label: rating.seasonId >= 29 ? 'Support 5' : 'Best Move', value: rating.bestMovePoints.roundTo(2).toString(), accent: _Accent.positive),
        ]),
        const SizedBox(height: 6),
        _row([
          _StatTile(label: 'MVP', value: rating.mvp.roundTo(4).toString()),
          _StatTile(label: 'CI/Game', value: rating.ciForGame.roundTo(3).toString()),
          _StatTile(label: 'CI', value: rating.ci.roundTo(3).toString()),
          _StatTile(label: 'Death %', value: '${(rating.percentOfDeath * 100).roundTo(1)}%'),
        ]),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'First Killed', value: '${rating.firstKilled}')),
            const SizedBox(width: 6),
            Expanded(child: _StatTile(label: 'City Lost', value: '${rating.firstKilledCityLost}')),
            const Spacer(flex: 2),
          ],
        ),
        if (rating.seasonId >= 29) ...[
          const SizedBox(height: 6),
          _row([
            _StatTile(
              label: 'Protocol Pts',
              value: rating.protocolPoints.roundTo(2).toString(),
              accent: rating.protocolPoints >= 0 ? _Accent.positive : _Accent.negative,
            ),
            _StatTile(
              label: 'Guesses',
              value: '${rating.protocolCorrectGuesses}/${rating.protocolTotalGuesses}',
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ]),
        ],
        const SizedBox(height: 12),
        _RoleBreakdown(rating: rating),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final _Accent? accent;

  const _StatTile({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bg = switch (accent) {
      _Accent.positive => Colors.green.withValues(alpha: 0.09),
      _Accent.negative => Colors.red.withValues(alpha: 0.09),
      null => cs.surfaceContainerLow,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RoleBreakdown extends StatelessWidget {
  final RatingPlayerStats rating;

  const _RoleBreakdown({required this.rating});

  static Color _roleColor(String roleName) => switch (roleName) {
        'sheriff' => const Color(0xFF1565C0),
        'don' => const Color(0xFFC62828),
        'civilian' => const Color(0xFF2E7D32),
        'mafia' => const Color(0xFF6A1B9A),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'By role',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider(color: cs.outlineVariant)),
          ],
        ),
        const SizedBox(height: 8),
        ...Role.values.map((role) {
          final roleName = role.name[0].toUpperCase() + role.name.substring(1);
          final roleColor = _roleColor(role.name.toLowerCase());

          final wins = rating.winByRole
              .firstWhere((e) => role.sheetValues.contains(e.$1),
                  orElse: () => (role.sheetValue, 0))
              .$2;
          final games = rating.gamesForRole
              .firstWhere((e) => role.sheetValues.contains(e.$1),
                  orElse: () => (role.sheetValue, 0))
              .$2;
          final add = rating.bestMoveAndAdditionalPointsByRole
              .firstWhere((e) => role.sheetValues.contains(e.$1),
                  orElse: () => (role.sheetValue, 0.0))
              .$2;
          final wr = games > 0 ? (wins / games * 100).roundTo(1) : 0.0;

          final Color wrFg;
          final Color wrBg;
          if (games == 0) {
            wrFg = cs.onSurfaceVariant;
            wrBg = cs.surfaceContainerLow;
          } else if (wr >= 50) {
            wrFg = Colors.green.shade700;
            wrBg = Colors.green.shade50;
          } else if (wr >= 35) {
            wrFg = Colors.amber.shade800;
            wrBg = Colors.amber.shade50;
          } else {
            wrFg = Colors.red.shade700;
            wrBg = Colors.red.shade50;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 62,
                  child: Text(
                    roleName,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$wins/$games',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: wrBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    games > 0 ? '$wr% WR' : '–',
                    style: tt.labelSmall?.copyWith(
                      color: wrFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  add >= 0 ? '+${add.roundTo(2)}' : add.roundTo(2).toString(),
                  style: tt.bodySmall?.copyWith(
                    color: add >= 0 ? cs.primary : Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
