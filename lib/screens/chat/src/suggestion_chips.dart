part of '../chat_screen.dart';

class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionChips({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(
            suggestions[i],
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF00897B),
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFFE0F2F1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00897B), width: 0.5),
          ),
          onPressed: () => onTap(suggestions[i]),
        ),
      ),
    );
  }
}
