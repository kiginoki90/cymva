import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkText extends StatelessWidget {
  final String text;

  LinkText({required this.text});

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final matches = urlRegex.allMatches(text);
    final List<InlineSpan> children = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        // URL以外のテキストを追加
        children.add(TextSpan(
          text: text.substring(start, match.start),
          style: const TextStyle(fontSize: 18),
        ));
      }

      // URL部分をリンクとして追加
      final urlString = match.group(0)!;
      final Uri url = Uri.parse(urlString);

      children.add(TextSpan(
        text: urlString,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              throw 'Could not launch $url';
            }
          },
      ));
      start = match.end;
    }

    // 最後の部分のテキストを追加
    if (start < text.length) {
      children.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(fontSize: 18),
      ));
    }

    return RichText(
      text: TextSpan(
        children: children,
        style: DefaultTextStyle.of(context).style,
      ),
    );
  }
}
