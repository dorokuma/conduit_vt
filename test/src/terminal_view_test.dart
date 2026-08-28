import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:conduit_vt/xterm.dart';

import '../_fixture/_fixture.dart';

@GenerateNiceMocks([MockSpec<TerminalInputHandler>()])
import 'terminal_view_test.mocks.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('htop golden test', (tester) async {
    final terminal = Terminal();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TerminalView(terminal))),
    );

    terminal.write(TestFixtures.htop_80x25_3s());
    await tester.pump();

    await expectLater(
      find.byType(TerminalView),
      matchesGoldenFile('_goldens/htop_80x25_3s.png'),
    );
  }, skip: !Platform.isMacOS);

  testWidgets('color golden test', (tester) async {
    final terminal = Terminal();

    // terminal.lineFeedMode = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, textStyle: TerminalStyle(fontSize: 8)),
        ),
      ),
    );

    terminal.write(TestFixtures.colors().replaceAll('\n', '\r\n'));
    await tester.pump();

    await expectLater(
      find.byType(TerminalView),
      matchesGoldenFile('_goldens/colors.png'),
    );
  }, skip: !Platform.isMacOS);

  group('TerminalView.readOnly', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, readOnly: true, autofocus: true),
          ),
        ),
      );

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('does not block input when false', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, readOnly: false, autofocus: true),
          ),
        ),
      );

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), 'ls -al');
    });
  });

  group('TerminalView.focusNode', () {
    testWidgets('is not listened when terminal is disposed', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isActive,
              builder: (context, isActive, child) {
                if (!isActive) {
                  return Container();
                }
                return TerminalView(
                  terminal,
                  focusNode: focusNode,
                  autofocus: true,
                );
              },
            ),
          ),
        ),
      );

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isTrue);

      isActive.value = false;
      await tester.pumpAndSettle();

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isFalse);
    });

    testWidgets('does not dispose external focus node', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isActive,
              builder: (context, isActive, child) {
                if (!isActive) {
                  return Container();
                }
                return TerminalView(
                  terminal,
                  focusNode: focusNode,
                  autofocus: true,
                );
              },
            ),
          ),
        ),
      );

      isActive.value = false;
      await tester.pumpAndSettle();

      expect(() => focusNode.addListener(() {}), returnsNormally);
    });
  });

  group('TerminalController.pointerInputs', () {
    testWidgets('works', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, controller: terminalView),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isNotEmpty);
    });

    testWidgets('does not respond when disabled', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.none(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, controller: terminalView),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isEmpty);
    });
  });

  group('TerminalView.autofocus', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, autofocus: true, focusNode: focusNode),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('works in hardwareKeyboardOnly mode', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('TerminalView.hardwareKeyboardOnly', () {
    testWidgets('works', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

      expect(output.join(), 'abc');
    });
  });

  group('TerminalView.textScaler', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();

      final textScaler = ValueNotifier(TextScaler.linear(1.0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TextScaler>(
              valueListenable: textScaler,
              builder: (context, textScaler, child) {
                return TerminalView(terminal, textScaler: textScaler);
              },
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@1x.png'),
      );

      textScaler.value = TextScaler.linear(2.0);
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });

    testWidgets('can obtain textScaler from parent', (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: TerminalView(terminal),
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });
  });

  group('TerminalView.inputHandler', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, autofocus: true)),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await tester.pumpAndSettle();

      expect(terminalOutput.join(), '\x04');
    });

    testWidgets('can convert text input to key events', (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) => 'AAA');

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, autofocus: true)),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('c');
      await binding.idle();

      await tester.pumpAndSettle();

      verify(inputHandler.call(any));
      expect(terminalOutput.join(), 'AAA');
    });
  });

  group('TerminalView.simulateScroll', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, autofocus: true, simulateScroll: true),
        ),
      );

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
    });

    testWidgets('uses arrow keys instead of mouse reporting when enabled', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();
      // Enable normal mouse reporting; the alternate-buffer simulation should
      // take precedence and avoid emitting a mouse sequence.
      terminal.write('\x1b[?1000h');

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            simulateScroll: true,
            altBufferScrollSimulate: true,
          ),
        ),
      );

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
      expect(terminalOutput.join(), isNot(contains('\x1B[M')));
    });

    testWidgets('uses SGR mouse reporting when alternate simulation is disabled', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();
      // Enable SGR mouse reporting.
      terminal.write('\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            autofocus: true,
            simulateScroll: true,
            altBufferScrollSimulate: false,
          ),
        ),
      );

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[<69;'));
      expect(terminalOutput.join(), isNot(contains('\x1B[B')));
    });

    testWidgets('keeps simulating arrows when mouse reporting is disabled', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, autofocus: true, simulateScroll: true),
        ),
      );

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
    });

    testWidgets('does nothing when disabled', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, autofocus: true, simulateScroll: false),
        ),
      );

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });
  });

  group('TerminalView.keepKeyboardHiddenOnTap', () {
    // TerminalView's autoResize schedules a 250ms post-frame timer that is
    // not cancelled until the widget tree is disposed, which would fail the
    // post-test "no pending timers" assertion. Settle long enough to drain
    // it (mirrors the pattern used in terminal_surface_test.dart).
    Future<void> flushTimers(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Helper to read the [TerminalViewState] off the public GlobalKey so
    // the new hideSoftKeyboard entry point can be invoked without poking
    // at private fields.
    TerminalViewState viewOf(GlobalKey<TerminalViewState> key) {
      final state = key.currentState;
      expect(state, isNotNull, reason: 'TerminalViewState should be mounted');
      return state!;
    }

    testWidgets('tap does not open the soft keyboard when true', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              focusNode: focusNode,
              keepKeyboardHiddenOnTap: true,
            ),
          ),
        ),
      );

      // The terminal starts with no input connection: no IME.
      expect(focusNode.hasFocus, isFalse);
      expect(binding.testTextInput.isVisible, isFalse);

      // Tap the terminal. With keepKeyboardHiddenOnTap: true, neither the
      // focus request nor the openInputConnection path is taken, so the
      // soft keyboard must NOT become visible.
      await tester.tap(find.byType(TerminalView));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(binding.testTextInput.isVisible, isFalse);

      await flushTimers(tester);
    });

    testWidgets('tap does open the soft keyboard by default', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal, focusNode: focusNode),
          ),
        ),
      );

      expect(binding.testTextInput.isVisible, isFalse);

      await tester.tap(find.byType(TerminalView));
      await tester.pump();

      // Sanity-check: the default behavior still pops the IME so the new
      // flag is observably a no-op except when set.
      expect(focusNode.hasFocus, isTrue);
      expect(binding.testTextInput.isVisible, isTrue);

      await flushTimers(tester);
    });

    testWidgets(
      'hideSoftKeyboard drops the input connection even on Android',
      (tester) async {
        final terminal = Terminal();
        final focusNode = FocusNode();
        final key = GlobalKey<TerminalViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalView(
                terminal,
                key: key,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        // Pop the IME the default way so an input connection is open.
        await tester.tap(find.byType(TerminalView));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
        expect(binding.testTextInput.isVisible, isTrue);
        expect(viewOf(key).hasInputConnection, isTrue);

        // The toolbar toggle uses hideSoftKeyboard as its second-tap
        // action. It must close the platform input, drop focus, and
        // release the TextInputConnection so the next showSoftKeyboard
        // attaches a fresh one (the connection cache was the reason
        // Android IMEs ignored earlier close() calls).
        viewOf(key).hideSoftKeyboard();
        await tester.pump();

        expect(binding.testTextInput.isVisible, isFalse);
        expect(focusNode.hasFocus, isFalse);
        expect(viewOf(key).hasInputConnection, isFalse);

        await flushTimers(tester);
      },
    );

    testWidgets(
      'hardwareKeyboardOnly + keepKeyboardHiddenOnTap skips both branches',
      (tester) async {
        final terminal = Terminal();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalView(
                terminal,
                focusNode: focusNode,
                hardwareKeyboardOnly: true,
                keepKeyboardHiddenOnTap: true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(TerminalView));
        await tester.pump();

        // hardwareKeyboardOnly alone would have requested focus; the
        // keepKeyboardHiddenOnTap short-circuit must still suppress it.
        expect(focusNode.hasFocus, isFalse);
        expect(binding.testTextInput.isVisible, isFalse);

        await flushTimers(tester);
      },
    );
  });

  group('TerminalView.softKeyboardToggle', () {
    // Same post-frame timer drain as the keepKeyboardHiddenOnTap group.
    Future<void> flushTimers(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Pulls the [TerminalViewState] off the public GlobalKey so tests
    // can call the new [showSoftKeyboard] / [hideSoftKeyboard] entry
    // points without poking at private fields.
    TerminalViewState viewOf(GlobalKey<TerminalViewState> key) {
      final state = key.currentState;
      expect(state, isNotNull, reason: 'TerminalViewState should be mounted');
      return state!;
    }

    testWidgets(
      'showSoftKeyboard opens the IME even with keepKeyboardHiddenOnTap',
      (tester) async {
        final terminal = Terminal();
        final focusNode = FocusNode();
        final key = GlobalKey<TerminalViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalView(
                terminal,
                key: key,
                focusNode: focusNode,
                keepKeyboardHiddenOnTap: true,
              ),
            ),
          ),
        );

        // Sanity: the suppress-on-tap flag is in effect; the IME starts
        // hidden and a tap does not show it.
        expect(focusNode.hasFocus, isFalse);
        expect(binding.testTextInput.isVisible, isFalse);

        await tester.tap(find.byType(TerminalView));
        await tester.pump();
        expect(binding.testTextInput.isVisible, isFalse);

        // Calling showSoftKeyboard must open the IME regardless of the
        // keepKeyboardHiddenOnTap flag: this is the path the toolbar's
        // keyboard button uses.
        viewOf(key).showSoftKeyboard();
        await tester.pump();

        expect(binding.testTextInput.isVisible, isTrue);

        await flushTimers(tester);
      },
    );

    testWidgets('hideSoftKeyboard closes the IME and drops focus', (
      tester,
    ) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      final key = GlobalKey<TerminalViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              key: key,
              focusNode: focusNode,
              keepKeyboardHiddenOnTap: true,
            ),
          ),
        ),
      );

      // Open the IME first.
      viewOf(key).showSoftKeyboard();
      await tester.pump();
      expect(binding.testTextInput.isVisible, isTrue);
      // showSoftKeyboard() requests focus when there is none, so the
      // focus node is now active. That is the precondition for the
      // "show" half of the toggle button.
      expect(focusNode.hasFocus, isTrue);

      // Hide it again: the toolbar's keyboard button does this on a
      // second tap. The IME must close and the focus node must drop,
      // so a subsequent tap on the terminal (which is gated by
      // keepKeyboardHiddenOnTap + an active focus chain) does not
      // re-show the IME.
      viewOf(key).hideSoftKeyboard();
      await tester.pump();

      expect(binding.testTextInput.isVisible, isFalse);
      expect(focusNode.hasFocus, isFalse);

      await flushTimers(tester);
    });

    testWidgets('showSoftKeyboard after hideSoftKeyboard reopens the IME', (
      tester,
    ) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      final key = GlobalKey<TerminalViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              key: key,
              focusNode: focusNode,
              keepKeyboardHiddenOnTap: true,
            ),
          ),
        ),
      );

      viewOf(key).showSoftKeyboard();
      await tester.pump();
      viewOf(key).hideSoftKeyboard();
      await tester.pump();
      expect(binding.testTextInput.isVisible, isFalse);

      viewOf(key).showSoftKeyboard();
      await tester.pump();
      expect(binding.testTextInput.isVisible, isTrue);

      await flushTimers(tester);
    });

    testWidgets(
      'dismissSoftKeyboard closes IME, drops focus, releases connection',
      (tester) async {
        final terminal = Terminal();
        final focusNode = FocusNode();
        final key = GlobalKey<TerminalViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalView(
                terminal,
                key: key,
                focusNode: focusNode,
                keepKeyboardHiddenOnTap: true,
              ),
            ),
          ),
        );

        // Open the IME the toolbar-button way and confirm a live input
        // connection is attached.
        viewOf(key).showSoftKeyboard();
        await tester.pump();
        expect(binding.testTextInput.isVisible, isTrue);
        expect(focusNode.hasFocus, isTrue);
        expect(viewOf(key).hasInputConnection, isTrue);

        // dismissSoftKeyboard is the toolbar's second-tap entry point.
        // It must: drop focus so the focus chain can't reopen the IME,
        // close the TextInputConnection (hasInputConnection reflects
        // the real platform connection, not the animated viewInsets
        // gradient), and ask the platform to hide text input as a
        // hard fallback for IMEs that linger.
        viewOf(key).dismissSoftKeyboard();
        await tester.pump();

        expect(binding.testTextInput.isVisible, isFalse);
        expect(focusNode.hasFocus, isFalse);
        expect(viewOf(key).hasInputConnection, isFalse);

        await flushTimers(tester);
      },
    );
  });
}
