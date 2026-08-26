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

    terminal.write(
        List<String>.generate(200, (i) => 'scrollback line $i').join('\r\n'));
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
    'primary screen touch drag with onTouchScroll forwards deltas and '
    'does not move native scrollback or emit sequences',
    (tester) async {
      final output = <String>[];
      final deltas = <int>[];
      final terminal = Terminal(onOutput: output.add);
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              scrollController: scrollController,
              autofocus: true,
              onTouchScroll: deltas.add,
            ),
          ),
        ),
      );

      terminal.write(
          List<String>.generate(200, (i) => 'scrollback line $i').join('\r\n'));
      await tester.pump();

      scrollController.jumpTo(0);
      await tester.pump();
      final topOffset = scrollController.offset;

      await tester.drag(
        find.byType(TerminalView),
        const Offset(0, -300),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();

      // Upward finger drag scrolls toward newer content: positive line delta.
      expect(deltas, isNotEmpty);
      expect(deltas.reduce((a, b) => a + b), greaterThan(0));

      // onTouchScroll takes over touch dragging: native scrollback does not
      // move (physics disabled user dragging).
      expect(scrollController.offset, closeTo(topOffset, 0.001));

      // No keyInput/mouse escape sequences are sent to the terminal.
      expect(output.join(), isEmpty);
    },
  );

  testWidgets(
    'primary screen downward touch drag with onTouchScroll reports older '
    'content',
    (tester) async {
      final deltas = <int>[];
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            onTouchScroll: deltas.add,
          ),
        ),
      );

      terminal.write(
          List<String>.generate(200, (i) => 'scrollback line $i').join('\r\n'));
      await tester.pump();

      await tester.drag(
        find.byType(TerminalView),
        const Offset(0, 300),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();

      // Downward finger drag scrolls toward older content: negative line delta.
      expect(deltas, isNotEmpty);
      expect(deltas.reduce((a, b) => a + b), lessThan(0));
    },
  );

  testWidgets(
    'alternate screen touch drag with onTouchScroll forwards deltas instead '
    'of arrow/mouse sequences',
    (tester) async {
      final output = <String>[];
      final deltas = <int>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.useAltBuffer();
      // Mouse reporting on: onTouchScroll must take precedence over both the
      // arrow-key simulation and the SGR mouse reporting.
      terminal.write('\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            altBufferScrollSimulate: true,
            onTouchScroll: deltas.add,
          ),
        ),
      );

      await tester.drag(
        find.byType(TerminalView),
        const Offset(0, -300),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty);
      // No arrow keys and no mouse sequences are sent to the terminal.
      expect(output.join(), isEmpty);
    },
  );

  testWidgets('writing at bottom does not pull a scrolled user back down',
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

    terminal.write(
        List<String>.generate(200, (i) => 'scrollback line $i').join('\r\n'));
    await tester.pump();
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byType(TerminalView),
      const Offset(0, -300),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
    await tester.pump();
    final historicalOffset = scrollController.offset;
    expect(
        historicalOffset, lessThan(scrollController.position.maxScrollExtent));

    terminal.write('\r\nnew line 1\r\nnew line 2\r\nnew line 3');
    await tester.pump();

    expect(scrollController.offset, closeTo(historicalOffset, 0.001));
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
