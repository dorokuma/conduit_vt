import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conduit_vt/xterm.dart';

void main() {
  testWidgets(
    'deferResize delays Terminal.resize until commitDeferredResize',
    (tester) async {
      final terminal = Terminal();
      final resizes = <List<int>>[];
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        resizes.add([width, height, pixelWidth, pixelHeight]);
      };

      TerminalSize? lastViewport;
      Size? lastCellSize;
      final viewKey = GlobalKey<TerminalViewState>();

      Future<void> pumpAt(Size size) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: TerminalView(
                  terminal,
                  key: viewKey,
                  deferResize: true,
                  onViewportSizeChanged: (viewport, cellSize) {
                    lastViewport = viewport;
                    lastCellSize = cellSize;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpAt(const Size(400, 400));

      expect(resizes, isEmpty, reason: 'layout must not call Terminal.resize');
      expect(lastViewport, isNotNull);
      expect(lastCellSize, isNotNull);
      expect(terminal.viewWidth, 80);
      expect(terminal.viewHeight, 24);

      viewKey.currentState!.commitDeferredResize();

      expect(resizes, hasLength(1));
      expect(terminal.viewWidth, lastViewport!.width);
      expect(terminal.viewHeight, lastViewport!.height);
      expect(resizes.single[0], lastViewport!.width);
      expect(resizes.single[1], lastViewport!.height);

      viewKey.currentState!.commitDeferredResize();
      expect(resizes, hasLength(1), reason: 'repeat commit must be idempotent');

      final committedWidth = terminal.viewWidth;
      final committedHeight = terminal.viewHeight;

      await pumpAt(const Size(400, 200));

      expect(resizes, hasLength(1), reason: 'size change still defers resize');
      expect(terminal.viewWidth, committedWidth);
      expect(terminal.viewHeight, committedHeight);
      expect(lastViewport!.height, lessThan(committedHeight));

      viewKey.currentState!.commitDeferredResize();
      expect(resizes, hasLength(2));
      expect(terminal.viewWidth, lastViewport!.width);
      expect(terminal.viewHeight, lastViewport!.height);
    },
  );

  testWidgets(
    'switching deferResize off applies the pending viewport size',
    (tester) async {
      final terminal = Terminal();
      final resizes = <List<int>>[];
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        resizes.add([width, height, pixelWidth, pixelHeight]);
      };

      TerminalSize? lastViewport;

      Future<void> pump({required bool deferResize}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: TerminalView(
                  terminal,
                  deferResize: deferResize,
                  onViewportSizeChanged: (viewport, cellSize) {
                    lastViewport = viewport;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump(deferResize: true);
      expect(resizes, isEmpty, reason: 'layout must not call Terminal.resize');
      expect(terminal.viewWidth, 80);
      expect(terminal.viewHeight, 24);
      expect(lastViewport, isNotNull);

      await pump(deferResize: false);
      expect(resizes, hasLength(1), reason: 'onResize fires once on undefer');
      expect(terminal.viewWidth, lastViewport!.width);
      expect(terminal.viewHeight, lastViewport!.height);
    },
  );

  testWidgets(
    'default autoResize still resizes during layout',
    (tester) async {
      final terminal = Terminal();
      final resizes = <List<int>>[];
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        resizes.add([width, height, pixelWidth, pixelHeight]);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: TerminalView(terminal),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(resizes, isNotEmpty);
      expect(terminal.viewWidth, resizes.last[0]);
      expect(terminal.viewHeight, resizes.last[1]);
    },
  );
}
