import 'package:flutter_test/flutter_test.dart';
import 'package:conduit_vt/xterm.dart';

void main() {
  group('OSC 8 Hyperlinks', () {
    test('start - write - end sequence assigns correct hyperlink ID to cells', () {
      final terminal = Terminal();
      final uri = 'https://example.com';
      // OSC 8 ; params ; uri BEL text OSC 8 ; ; BEL
      terminal.write('\x1b]8;;$uri\x07link\x1b]8;;\x07');

      final line = terminal.buffer.lines[0];
      final pool = terminal.hyperlinkPool;
      final expectedId = pool.acquire(uri);

      for (var i = 0; i < 4; i++) {
        expect(line.getHyperlinkId(i), equals(expectedId));
        expect(
          terminal.getHyperlinkAt(CellOffset(i, 0)),
          equals('https://example.com'),
        );
      }
    });

    test('URI containing semicolons is preserved and not truncated', () {
      final terminal = Terminal();
      final uriWithSemicolon = 'https://example.com/path;query=1;param=2';
      terminal.write('\x1b]8;;$uriWithSemicolon\x1b\\link\x1b]8;;\x1b\\');

      expect(
        terminal.getHyperlinkAt(CellOffset(0, 0)),
        equals('https://example.com/path;query=1;param=2'),
      );
      expect(
        terminal.getHyperlinkAt(CellOffset(3, 0)),
        equals('https://example.com/path;query=1;param=2'),
      );
    });

    test('cells written after endHyperlink have hyperlinkId 0', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;;https://example.com\x07link\x1b]8;;\x07plain');

      final line = terminal.buffer.lines[0];
      final linkId = line.getHyperlinkId(0);
      expect(linkId, isNonZero);

      for (var i = 0; i < 4; i++) {
        expect(line.getHyperlinkId(i), equals(linkId));
        expect(
          terminal.getHyperlinkAt(CellOffset(i, 0)),
          equals('https://example.com'),
        );
      }

      // 'plain' is at indices 4..8
      for (var i = 4; i < 9; i++) {
        expect(line.getHyperlinkId(i), equals(0));
        expect(terminal.getHyperlinkAt(CellOffset(i, 0)), isNull);
      }
    });

    test('getHyperlinkAt hit and out-of-bounds', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;;https://example.com\x07abc\x1b]8;;\x07');

      // Hits
      expect(
        terminal.getHyperlinkAt(CellOffset(0, 0)),
        equals('https://example.com'),
      );
      expect(
        terminal.getHyperlinkAt(CellOffset(1, 0)),
        equals('https://example.com'),
      );
      expect(
        terminal.getHyperlinkAt(CellOffset(2, 0)),
        equals('https://example.com'),
      );

      // Miss on line without hyperlink
      expect(terminal.getHyperlinkAt(CellOffset(3, 0)), isNull);

      // Out of bounds: negative x/y
      expect(terminal.getHyperlinkAt(CellOffset(-1, 0)), isNull);
      expect(terminal.getHyperlinkAt(CellOffset(0, -1)), isNull);

      // Out of bounds: y >= lines.length
      expect(terminal.getHyperlinkAt(CellOffset(0, 100)), isNull);

      // Out of bounds: x >= line.length
      expect(terminal.getHyperlinkAt(CellOffset(1000, 0)), isNull);
    });

    test('HyperlinkPool deduplication and retrieval', () {
      final pool = HyperlinkPool();
      final id1 = pool.acquire('https://a.com');
      final id2 = pool.acquire('https://b.com');
      final id3 = pool.acquire('https://a.com');

      expect(id1, equals(1));
      expect(id2, equals(2));
      expect(id3, equals(id1));
      expect(pool.get(id1), equals('https://a.com'));
      expect(pool.get(id2), equals('https://b.com'));
      expect(pool.get(0), isNull);
      expect(pool.get(-1), isNull);
      expect(pool.get(999), isNull);
    });

    test('BufferLine resize and copy preserves hyperlinkId', () {
      final line1 = BufferLine(10);
      line1.setCell(0, 'A'.codeUnitAt(0), 1, CursorStyle(), 42);
      expect(line1.getHyperlinkId(0), equals(42));

      line1.resize(20);
      expect(line1.getHyperlinkId(0), equals(42));
      expect(line1.getHyperlinkId(15), equals(0));

      final line2 = BufferLine(10);
      line2.copyFrom(line1, 0, 2, 5);
      expect(line2.getHyperlinkId(2), equals(42));
      expect(line2.getHyperlinkId(0), equals(0));
    });

    test('CellData includes hyperlinkId in getHash', () {
      final cell1 = CellData(foreground: 1, background: 2, flags: 3, content: 4, hyperlinkId: 5);
      final cell2 = CellData(foreground: 1, background: 2, flags: 3, content: 4, hyperlinkId: 5);
      final cell3 = CellData(foreground: 1, background: 2, flags: 3, content: 4, hyperlinkId: 6);

      expect(cell1.getHash(), equals(cell2.getHash()));
      expect(cell1.getHash(), isNot(equals(cell3.getHash())));
    });

    test('Erasing cells resets hyperlinkId to 0', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;;https://example.com\x07hello\x1b]8;;\x07');
      expect(terminal.getHyperlinkAt(CellOffset(0, 0)), equals('https://example.com'));

      // Erase line
      terminal.write('\x1b[2K');
      expect(terminal.getHyperlinkAt(CellOffset(0, 0)), isNull);
      expect(terminal.buffer.lines[0].getHyperlinkId(0), equals(0));
    });

    test('OSC 8 with params parses and applies hyperlink', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;id=link123:foo=bar;https://example.com/item\x07click\x1b]8;;\x07');
      expect(
        terminal.getHyperlinkAt(CellOffset(0, 0)),
        equals('https://example.com/item'),
      );
    });
  });
}
