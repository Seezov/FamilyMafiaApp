import 'package:family_mafia_app/widgets/web_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Size> _pumpAt(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late Size seen;
  await tester.pumpWidget(MaterialApp(
    home: WebFrame(
      child: Builder(builder: (context) {
        seen = MediaQuery.sizeOf(context);
        return const SizedBox.expand(key: Key('content'));
      }),
    ),
  ));
  return seen;
}

void main() {
  testWidgets('caps content at 600 px on a wide window and tells MediaQuery so', (tester) async {
    final seen = await _pumpAt(tester, const Size(1400, 900));
    expect(tester.getSize(find.byKey(const Key('content'))), const Size(600, 900));
    expect(seen, const Size(600, 900));
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 400, reason: 'centred');
  });

  testWidgets('leaves a phone-width window untouched', (tester) async {
    final seen = await _pumpAt(tester, const Size(400, 800));
    expect(tester.getSize(find.byKey(const Key('content'))), const Size(400, 800));
    expect(seen, const Size(400, 800));
  });
}
