import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

List<TextRange> findConsoleMatches(String text, String query) {
  if (text.isEmpty || query.isEmpty) return const [];
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final matches = <TextRange>[];
  var offset = 0;
  while (offset < lowerText.length) {
    final start = lowerText.indexOf(lowerQuery, offset);
    if (start < 0) break;
    final end = start + query.length;
    matches.add(TextRange(start: start, end: end));
    offset = end;
  }
  return matches;
}

/// Debounces searches and terminates obsolete work, including pending spawns.
class ConsoleSearchWorker {
  Timer? _timer;
  Isolate? _isolate;
  ReceivePort? _port;
  Completer<List<TextRange>?>? _pending;
  int _generation = 0;

  Future<List<TextRange>?> search(
    String text,
    String query, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    cancel();
    if (text.isEmpty || query.isEmpty) return Future.value(const []);
    final generation = _generation;
    final pending = Completer<List<TextRange>?>();
    _pending = pending;
    _timer = Timer(delay, () async {
      final port = ReceivePort();
      _port = port;
      port.listen((message) {
        if (generation != _generation) return;
        if (message is! List<TextRange>) {
          cancel();
          return;
        }
        final matches = message;
        pending.complete(matches);
        _pending = null;
        _isolate?.kill(priority: Isolate.immediate);
        _isolate = null;
        port.close();
        _port = null;
      });
      try {
        final isolate = await Isolate.spawn(_searchConsoleInBackground, (
          port.sendPort,
          text,
          query,
        ), onError: port.sendPort);
        if (generation != _generation || pending.isCompleted) {
          isolate.kill(priority: Isolate.immediate);
        } else {
          _isolate = isolate;
        }
      } on Object {
        if (generation == _generation) cancel();
      }
    });
    return pending.future;
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    _pending?.complete(null);
    _pending = null;
  }
}

void _searchConsoleInBackground((SendPort, String, String) request) {
  final (port, text, query) = request;
  Isolate.exit(port, findConsoleMatches(text, query));
}

void revealConsoleMatch({
  required GlobalKey textKey,
  required GlobalKey viewportKey,
  required ScrollController scrollController,
  required TextRange match,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!scrollController.hasClients) return;
    final textContext = textKey.currentContext;
    final viewport = viewportKey.currentContext?.findRenderObject();
    if (textContext == null || viewport is! RenderBox) return;
    final editable = _findRenderEditable(textContext);
    if (editable == null) return;
    final boxes = editable.getBoxesForSelection(
      TextSelection(baseOffset: match.start, extentOffset: match.end),
    );
    if (boxes.isEmpty) return;

    final matchTop = editable.localToGlobal(Offset(0, boxes.first.top)).dy;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final destination =
        (scrollController.offset +
                matchTop -
                viewportTop -
                viewport.size.height * .25)
            .clamp(
              scrollController.position.minScrollExtent,
              scrollController.position.maxScrollExtent,
            );
    scrollController.animateTo(
      destination,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  });
}

RenderEditable? _findRenderEditable(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderEditable) return renderObject;
  RenderEditable? editable;
  context.visitChildElements((child) {
    editable ??= _findRenderEditable(child);
  });
  return editable;
}
