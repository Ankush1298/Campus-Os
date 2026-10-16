import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours Dart source (keywords, types, strings, numbers, comments) as you type.
class DartHighlightController extends TextEditingController {
  DartHighlightController({super.text});

  static final RegExp _token = RegExp(
    r"(?<comment>//[^\n]*)|(?<string>'(?:\\.|[^'\\\n])*'?|"
    r'"(?:\\.|[^"\\\n])*"?)|(?<number>\b\d+(?:\.\d+)?\b)|(?<word>\b[A-Za-z_]\w*\b)',
  );
  static const Set<String> _keywords = {
    'return',
    'if',
    'else',
    'for',
    'while',
    'do',
    'break',
    'continue',
    'var',
    'final',
    'const',
    'void',
    'new',
    'switch',
    'case',
    'default',
    'in',
    'is',
    'as',
    'class',
    'try',
    'catch',
    'throw',
    'true',
    'false',
    'null',
  };
  static const Set<String> _types = {
    'int',
    'double',
    'num',
    'String',
    'bool',
    'List',
    'Map',
    'Set',
    'dynamic',
    'Object',
  };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > last)
        spans.add(TextSpan(text: text.substring(last, m.start)));
      final t = m[0]!;
      Color? c;
      if (m.namedGroup('comment') != null) {
        c = const Color(0xFF6B7280);
      } else if (m.namedGroup('string') != null) {
        c = const Color(0xFF15803D);
      } else if (m.namedGroup('number') != null) {
        c = const Color(0xFFB45309);
      } else if (_keywords.contains(t)) {
        c = const Color(0xFF5A6AE8);
      } else if (_types.contains(t)) {
        c = const Color(0xFF0369A1);
      }
      spans.add(
        TextSpan(
          text: t,
          style: c == null ? null : TextStyle(color: c),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}

/// UI-level deterrent against pasting solutions: rejects any single edit that inserts more than [maxChunk]
/// non-whitespace characters (typing, auto-indent and short tokens still work). NOT a security control:
/// it cannot stop screenshots, other apps or a modified client.
class NoPasteFormatter extends TextInputFormatter {
  final int maxChunk;
  final VoidCallback? onBlocked;
  NoPasteFormatter({this.maxChunk = 8, this.onBlocked});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final removed =
        oldValue.selection.isValid && !oldValue.selection.isCollapsed
        ? oldValue.selection.end - oldValue.selection.start
        : 0;
    final inserted = newValue.text.length - oldValue.text.length + removed;
    if (inserted <= maxChunk) return newValue;
    final start = oldValue.selection.isValid ? oldValue.selection.start : 0;
    final end = (start + inserted).clamp(0, newValue.text.length);
    final chunk = newValue.text.substring(start.clamp(0, end), end);
    if (chunk.replaceAll(RegExp(r'\s'), '').length <= maxChunk) return newValue;
    onBlocked?.call();
    return oldValue;
  }
}

/// Monospace code editor with line numbers, syntax highlighting and no paste.
class CodeEditor extends StatelessWidget {
  final DartHighlightController controller;
  final VoidCallback? onPasteBlocked;
  final bool readOnly;
  final double minHeight;
  final bool blockPaste; // only tests turn this off

  const CodeEditor({
    super.key,
    required this.controller,
    this.onPasteBlocked,
    this.readOnly = false,
    this.minHeight = 220,
    this.blockPaste = true,
  });

  static const TextStyle _style = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13.5,
    height: 1.45,
    color: Color(0xFF0B1B3A),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 900,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, _) {
                    final lines = '\n'.allMatches(v.text).length + 1;
                    return Container(
                      width: 38,
                      padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                      color: const Color(0xFFE2E8F0),
                      child: Text(
                        List.generate(lines, (i) => '${i + 1}').join('\n'),
                        textAlign: TextAlign.right,
                        style: _style.copyWith(color: const Color(0xFF56667F)),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    key: const Key('practiverse-solution-input'),
                    controller: controller,
                    readOnly: readOnly,
                    maxLines: null,
                    minLines: 10,
                    style: _style,
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    inputFormatters: [
                      if (blockPaste)
                        NoPasteFormatter(onBlocked: onPasteBlocked),
                    ],
                    contextMenuBuilder: (context, state) {
                      final items = state.contextMenuButtonItems
                          .where(
                            (i) =>
                                !blockPaste ||
                                i.type != ContextMenuButtonType.paste,
                          )
                          .toList();
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: state.contextMenuAnchors,
                        buttonItems: items,
                      );
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.fromLTRB(10, 12, 10, 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
