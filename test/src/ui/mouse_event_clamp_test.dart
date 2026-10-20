// Regression tests for the tap-coordinate-out-of-bounds bug.
//
// The remote terminal (e.g. herdr) silently drops SGR mouse events whose
// row number is outside the visible viewport. Before the fix, [RenderTerminal]
// fed `getCellOffset`'s row straight to [_terminal.mouseInput] — and
// `getCellOffset` clamps the row using the entire buffer line count
// (scrollback + viewport), so on the primary screen with scrollback present
// every tap in the bottom half of the viewport was reported as a row number
// that exceeded the view height, and the remote TUI ignored it.
//
// The fix in render.dart clamps the position to viewWidth/viewHeight-1 right
// before passing it to the terminal. These tests pin that behavior down for
// both the primary screen (with scrollback) and the alternate screen buffer
// (no scrollback, but the cell-over-background layout must still produce
// in-viewport coordinates).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conduit_vt/xterm.dart';

void main() {
  group('RenderTerminal.mouseEvent coordinates', () {
    testWidgets(
      'primary screen with scrollback: click near viewport bottom emits '
      'row <= viewHeight and col <= viewWidth',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(
          maxLines: 1000,
          onOutput: output.add,
        );
        // Enable SGR mouse reporting (mode 1006) so taps become SGR events.
        terminal.write('\x1b[?1000h\x1b[?1006h');

        // 40 columns wide, 10 rows tall viewport.
        terminal.resize(40, 10);

        // Write 50 lines of content to push 40 lines into scrollback, so
        // the buffer has 50 lines but only 10 are visible.
        for (var i = 0; i < 50; i++) {
          terminal.write('scrollback line $i\r\n');
        }
        await tester.pump();

        expect(terminal.buffer.lines.length, greaterThan(10));
        expect(terminal.viewHeight, 10);
        expect(terminal.viewWidth, 40);

        final controller = TerminalController(
          pointerInputs: const PointerInputs({PointerInput.tap}),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TerminalView(
                  terminal,
                  controller: controller,
                  textStyle: const TerminalStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap near the viewport bottom (logical cell ~(20, 9) of 40x10).
        final terminalViewFinder = find.byType(TerminalView);
        final box = tester.getRect(terminalViewFinder);
        // Approx cell width/height: 400/40 = 10, 200/10 = 20. Tap at column
        // 20 (centered), row 9 (last visible row).
        final tapOffset = Offset(
          box.left + 20 * 10 + 5,
          box.top + 9 * 20 + 10,
        );
        await tester.tapAt(tapOffset);
        await tester.pump();
        // Flush the 300ms double-tap detection timer so it doesn't keep the
        // test alive past the widget tree disposal.
        await tester.pump(const Duration(milliseconds: 400));

        // Collect SGR output (left button down + up).
        final sgrEvents = output
            .where((s) => s.contains('\x1B[<') && s.endsWith('M'))
            .toList();
        expect(
          sgrEvents,
          isNotEmpty,
          reason: 'SGR mouse press should be emitted for the tap',
        );

        // Extract col;row from each SGR event and assert they fit the
        // viewport (1-based, so row in [1, viewHeight]).
        final re = RegExp(r'\x1B\[<0;(\d+);(\d+)M');
        for (final s in sgrEvents) {
          final m = re.firstMatch(s);
          expect(m, isNotNull, reason: 'SGR shape: $s');
          final col = int.parse(m!.group(1)!);
          final row = int.parse(m.group(2)!);
          expect(
            col,
            inInclusiveRange(1, terminal.viewWidth),
            reason: 'SGR col out of viewport range: $s',
          );
          expect(
            row,
            inInclusiveRange(1, terminal.viewHeight),
            reason: 'SGR row out of viewport range: $s',
          );
        }
      },
    );

    testWidgets(
      'alternate screen buffer with SGR mouse mode: tap coordinates stay '
      'within the viewport',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add);
        terminal.useAltBuffer();
        terminal.resize(40, 10);
        terminal.write('\x1b[?1000h\x1b[?1006h');

        final controller = TerminalController(
          pointerInputs: const PointerInputs({PointerInput.tap}),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 200,
                child: TerminalView(
                  terminal,
                  controller: controller,
                  textStyle: const TerminalStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester.getRect(find.byType(TerminalView));
        // Tap at far bottom-right corner of the viewport.
        await tester.tapAt(Offset(
          box.right - 5,
          box.bottom - 5,
        ));
        await tester.pump();
        // Flush the 300ms double-tap detection timer.
        await tester.pump(const Duration(milliseconds: 400));

        final sgrEvents = output
            .where((s) => s.contains('\x1B[<') && s.endsWith('M'))
            .toList();
        expect(sgrEvents, isNotEmpty);

        final re = RegExp(r'\x1B\[<0;(\d+);(\d+)M');
        for (final s in sgrEvents) {
          final m = re.firstMatch(s);
          expect(m, isNotNull);
          final col = int.parse(m!.group(1)!);
          final row = int.parse(m.group(2)!);
          expect(col, inInclusiveRange(1, terminal.viewWidth), reason: s);
          expect(row, inInclusiveRange(1, terminal.viewHeight), reason: s);
        }
      },
    );
  });
}
