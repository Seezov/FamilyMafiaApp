import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a second row of tiles when given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: HeroCard(
          label: 'S26', title: 'Season Summary',
          gradientStart: Colors.teal, gradientEnd: Colors.black,
          statTiles: [HeroStatTile(value: '303', label: 'Games')],
          secondaryStatTiles: [HeroStatTile(value: '22', label: 'Main league')],
        ),
      ),
    ));
    expect(find.text('Main league'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
  });
}
