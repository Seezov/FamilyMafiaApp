part of '../home_screen.dart';

class _BackgroundLoadingBanner extends StatelessWidget {
  const _BackgroundLoadingBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading previous seasons\u2026',
              style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
