import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkText extends StatefulWidget {
  final String text;
  final int textSize;
  final bool tapable;
  final Color? color;
  final int? maxLines; // 最大行数を指定する引数を追加

  const LinkText({
    required this.text,
    required this.textSize,
    this.tapable = false,
    this.color,
    this.maxLines, // 新しい引数をコンストラクタに追加
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
        maxLines: widget.maxLines, // 最大行数を設定
      );
    } else {
      return Text.rich(
        TextSpan(
          children: children,
          style: DefaultTextStyle.of(context).style,
        ),
        maxLines: widget.maxLines, // 最大行数を設定
        overflow: widget.maxLines != null
            ? TextOverflow.ellipsis
            : null, // 行数を超えた場合の省略
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
      final hashIndex = inputText.indexOf('#', textStart);

      // '@'または'#'のどちらが先に出現するかを判定
      final indices = [atIndex, hashIndex].where((index) => index != -1);
      if (indices.isEmpty) {
        // '@'も'#'も見つからない場合、残りのテキストを追加
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

      final nextIndex = indices.reduce((a, b) => a < b ? a : b);

      // 通常テキストを追加
      if (nextIndex > textStart) {
        spans.add(TextSpan(
          text: inputText.substring(textStart, nextIndex),
          style: TextStyle(
            fontFamily: 'CustomFont',
            fontSize: widget.textSize.toDouble(),
            color: widget.color ?? Colors.black,
          ),
        ));
      }

      // '@'または'#'以降のテキストをリンクとして追加（改行で制限）
      final spaceIndex = inputText.indexOf(' ', nextIndex);
      final newlineIndex = inputText.indexOf('\n', nextIndex);
      final endIndex = [
        spaceIndex == -1 ? inputText.length : spaceIndex,
        newlineIndex == -1 ? inputText.length : newlineIndex,
      ].reduce((a, b) => a < b ? a : b);

      final matchedText = inputText.substring(nextIndex, endIndex);

      if (matchedText.startsWith('@')) {
        // '@'の処理
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountPage(
                      postUserId: postAccountId,
                      withDelay: false,
                    ),
                  ),
                );
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
      } else if (matchedText.startsWith('#')) {
        // '#'の処理
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(
            fontSize: widget.textSize.toDouble(),
            color: Colors.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                // matchedTextをストレージに保存
                await storage.write(key: 'query', value: matchedText);

                // 現在ログインしているユーザーIDを取得
                final userId = await storage.read(key: 'account_id');
                if (userId == null) {
                  showTopSnackBar(context, 'ユーザーIDが見つかりません',
                      backgroundColor: Colors.red);
                  return;
                }

                // navigateToSearchPageにユーザーIDを渡す
                navigateToSearchPage(
                  context,
                  userId,
                  '2',
                  true,
                  false,
                );
              } catch (e) {
                showTopSnackBar(context, 'エラーが発生しました: $e',
                    backgroundColor: Colors.red);
              }
            },
        ));
      }

      textStart = endIndex;
    }

    return spans;
  }
}
