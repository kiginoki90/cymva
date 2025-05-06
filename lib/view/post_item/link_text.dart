import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkText extends StatefulWidget {
  final String text;
  final String userId;
  final int textSize;
  final bool tapable;
  final Color? color;

  const LinkText({
    required this.text,
    required this.userId,
    required this.textSize,
    this.tapable = false,
    this.color,
    Key? key,
  }) : super(key: key);

  @override
  _LinkTextState createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    // TapGestureRecognizerを解放
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');

    final matches = urlRegex.allMatches(widget.text);
    final List<InlineSpan> children = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        children.addAll(_processTextWithHashtagsAndMentions(
          widget.text.substring(start, match.start),
          context,
        ));
      }

      final String urlString = match.group(0)!;
      final String displayUrl = urlString.length > 35
          ? '${urlString.substring(0, 35)}...'
          : urlString;
      final Uri url = Uri.parse(urlString);

      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            throw 'Could not launch $url';
          }
        };
      _recognizers.add(recognizer);

      children.add(TextSpan(
        text: displayUrl,
        style: TextStyle(
          fontSize: widget.textSize.toDouble(),
          color: Colors.blue,
          fontFamily: 'CustomFont',
        ),
        recognizer: recognizer,
      ));
      start = match.end;
    }

    // Handle remaining text after the last URL
    if (start < widget.text.length) {
      children.addAll(_processTextWithHashtagsAndMentions(
        widget.text.substring(start),
        context,
      ));
    }

    if (widget.tapable) {
      return SelectableText.rich(
        TextSpan(children: children),
        style: TextStyle(
          fontFamily: 'CustomFont',
          fontSize: widget.textSize.toDouble(),
        ),
      );
    } else {
      return RichText(
        text: TextSpan(
          children: children,
          style: DefaultTextStyle.of(context).style,
        ),
      );
    }
  }

  List<InlineSpan> _processTextWithHashtagsAndMentions(
    String inputText,
    BuildContext context,
  ) {
    final List<InlineSpan> spans = [];
    int textStart = 0;

    while (textStart < inputText.length) {
      final atIndex = inputText.indexOf('@', textStart);

      if (atIndex == -1) {
        // '@'が見つからない場合、残りのテキストを追加
        spans.add(TextSpan(
          text: inputText.substring(textStart),
          style: TextStyle(
            fontFamily: 'CustomFont',
            fontSize: widget.textSize.toDouble(),
            color: widget.color ?? Colors.black,
          ),
        ));
        break;
      }

      // '@'の前の通常テキストを追加
      if (atIndex > textStart) {
        spans.add(TextSpan(
          text: inputText.substring(textStart, atIndex),
          style: TextStyle(
            fontFamily: 'CustomFont',
            fontSize: widget.textSize.toDouble(),
            color: widget.color ?? Colors.black,
          ),
        ));
      }

      // '@'以降のテキストをリンクとして追加（改行で制限）
      final spaceIndex = inputText.indexOf(' ', atIndex);
      final newlineIndex = inputText.indexOf('\n', atIndex);
      final endIndex = [
        spaceIndex == -1 ? inputText.length : spaceIndex,
        newlineIndex == -1 ? inputText.length : newlineIndex,
      ].reduce((a, b) => a < b ? a : b); // 最小値を取得

      final matchedText = inputText.substring(atIndex, endIndex);

      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final targetText = matchedText.substring(1); // '@'を除いた部分
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .where('user_id', isEqualTo: targetText)
                .limit(1)
                .get();

            if (userDoc.docs.isNotEmpty) {
              final postAccountId = userDoc.docs.first.id;
              navigateToPage(context, postAccountId, '1', true, false);
            } else {
              showTopSnackBar(context, 'ユーザーが見つかりませんでした',
                  backgroundColor: Colors.red);
            }
          } catch (e) {
            showTopSnackBar(context, 'エラーが発生しました: $e',
                backgroundColor: Colors.red);
          }
        };

      spans.add(TextSpan(
        text: matchedText,
        style: TextStyle(
          fontSize: widget.textSize.toDouble(),
          color: Colors.blue,
          fontFamily: 'CustomFont',
        ),
        recognizer: recognizer,
      ));

      textStart = endIndex;
    }

    return spans;
  }
}
