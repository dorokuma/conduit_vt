import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conduit_vt/xterm.dart';

void main() {
  testWidgets('main screen touch drag scrolls through scrollback',
      (tester) async {
    final terminal = Terminal();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, scrollController: scrollController),
        ),
      ),
    );

    terminal.write(List<String>.generate(200, (i) => 'scrollback line $i').join('\r\n'));
    await tester.pump();

    expect(scrollController.hasClients, isTrue);
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    // Start at the top of the scrollback so an upward finger drag has room
    // to move toward history, then verify the reverse gesture returns.
    scrollController.jumpTo(0);
    await tester.pump();
    final topOffset = scrollController.offset;
    await tester.drag(
      find.byType(TerminalView),
      const Offset(0, -300),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(topOffset));

    final historicalOffset = scrollController.offset;
    await tester.drag(
      find.byType(TerminalView),
      const Offset(0, 300),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, lessThan(historicalOffset));
  });

  testWidgets(
    'alternate screen touch drag with mouse mode simulates arrow keys',
    (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.useAltBuffer();
      terminal.write('\x1b[?1000h');

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            altBufferScrollSimulate: true,
          ),
        ),
      );

      await tester.drag(
        find.byType(TerminalView),
        const Offset(0, -300),
        kind: PointerDeviceKind.touch,
      );

      expect(output.join(), contains('\x1B[B'));
      expect(output.join(), isNot(contains('\x1B[M')));
    },
  );

  testWidgets(
    'alternate screen touch drag with mouse mode emits SGR wheel events',
    (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.useAltBuffer();
      terminal.write('\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            altBufferScrollSimulate: false,
          ),
        ),
      );

      await tester.drag(
        find.byType(TerminalView),
        const Offset(0, -300),
        kind: PointerDeviceKind.touch,
      );

      expect(output.join(), contains('\x1B[<69;'));
      expect(output.join(), isNot(contains('\x1B[B')));
    },
  );
}
