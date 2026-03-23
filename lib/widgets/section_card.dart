import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: title == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xDD000000), // black87
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
      ),
    );
  }
}
