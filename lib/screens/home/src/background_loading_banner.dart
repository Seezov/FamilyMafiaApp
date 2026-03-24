part of '../home_screen.dart';

class _BackgroundLoadingBanner extends StatelessWidget {
  const _BackgroundLoadingBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF004D40),
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
