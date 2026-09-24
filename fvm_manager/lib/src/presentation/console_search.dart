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
