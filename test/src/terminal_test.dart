import 'package:test/test.dart';
import 'package:conduit_vt/core.dart';

void main() {
  group('Terminal Conduit state accessors', () {
    test('expose cursor positions for overlay clients', () {
      final terminal = Terminal()..write('ab');

      expect(terminal.cursorColumn, 2);
      expect(terminal.cursorRow, 0);
      expect(terminal.absoluteCursorRow, 0);
      expect(terminal.isUsingAltBuffer, isFalse);
    });
  });

  group('Terminal.inputHandler', () {
    test('can be set to null', () {
      final terminal = Terminal(inputHandler: null);
      expect(() => terminal.keyInput(TerminalKey.keyA), returnsNormally);
    });

    test('can be changed', () {
      final handler1 = _TestInputHandler();
      final handler2 = _TestInputHandler();
      final terminal = Terminal(inputHandler: handler1);

      terminal.keyInput(TerminalKey.keyA);
      expect(handler1.events, isNotEmpty);

      terminal.inputHandler = handler2;

      terminal.keyInput(TerminalKey.keyA);
      expect(handler2.events, isNotEmpty);
    });
  });

  group('Terminal.mouseInput', () {
    test('can handle mouse events', () {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, isEmpty);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, ['\x1B[M +,']);
    });
  });

  group('Terminal.reflowEnabled', () {
    test('prevents reflow when set to false', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('preserves hidden cells when reflow is disabled', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello World');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('can be set at runtime', () {
      final terminal = Terminal(reflowEnabled: true);

      terminal.resize(5, 5);
      terminal.write('Hello World');
      terminal.reflowEnabled = false;
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), ' Worl');
      expect(terminal.buffer.lines[2].toString(), 'd');
    });
  });

  group('Terminal.mouseInput', () {
    test('applys to the main buffer', () {
      final terminal = Terminal(wordSeparators: {'z'.codeUnitAt(0)});

      expect(terminal.mainBuffer.wordSeparators, contains('z'.codeUnitAt(0)));
    });

    test('applys to the alternate buffer', () {
      final terminal = Terminal(wordSeparators: {'z'.codeUnitAt(0)});

      expect(terminal.altBuffer.wordSeparators, contains('z'.codeUnitAt(0)));
    });
  });

  group('Terminal.onPrivateOSC', () {
    test(r'works with \a end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x07');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x07');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x07');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x07');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test(r'works with \x1b\ end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x1b\\');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x1b\\');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x1b\\');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x1b\\');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test('do not receive common osc', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]0;hello world\x07');

      expect(lastCode, isNull);
      expect(lastData, isNull);
    });
  });
  group('Terminal.keepScrollbackOnErase', () {
    test('preserves scrollback when CSI 3J is received', () {
      final terminal = Terminal(
        maxLines: 1000,
        keepScrollbackOnErase: true,
      );
      terminal.resize(80, 10);

      // Write 200 lines + enough line-feeds to push content into the
      // scrollback area.
      final payload = StringBuffer();
      for (var i = 0; i < 200; i++) {
        payload.writeln('line $i');
      }
      terminal.write(payload.toString());

      final heightBefore = terminal.mainBuffer.height;
      final scrollBackBefore = terminal.mainBuffer.scrollBack;
      expect(scrollBackBefore, greaterThan(0),
          reason: 'scrollback should accumulate from 200 lines');

      terminal.write('\x1B[3J');

      expect(terminal.mainBuffer.height, heightBefore,
          reason: 'CSI 3J must not drop buffered lines when keepScrollbackOnErase is true');
      expect(terminal.mainBuffer.scrollBack, scrollBackBefore,
          reason: 'CSI 3J must not trim scrollback when keepScrollbackOnErase is true');
    });

    test('clears scrollback by default when CSI 3J is received', () {
      final terminal = Terminal(maxLines: 1000);
      terminal.resize(80, 10);

      final payload = StringBuffer();
      for (var i = 0; i < 200; i++) {
        payload.writeln('line $i');
      }
      terminal.write(payload.toString());

      final scrollBackBefore = terminal.mainBuffer.scrollBack;
      expect(scrollBackBefore, greaterThan(0),
          reason: 'scrollback should accumulate from 200 lines');

      terminal.write('\x1B[3J');

      expect(terminal.mainBuffer.scrollBack, 0,
          reason: 'default behaviour: CSI 3J must empty the scrollback');
    });
  });
}

class _TestInputHandler implements TerminalInputHandler {
  final events = <TerminalKeyboardEvent>[];

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}
