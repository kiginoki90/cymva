import 'package:cymva/view/search/search_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkText extends StatelessWidget {
  final String text;
  final String userId;

  LinkText({required this.text, required this.userId});

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final hashtagRegex = RegExp(r'#[\w]+');

    final matches = urlRegex.allMatches(text);
    final hashtagMatches = hashtagRegex.allMatches(text);
    final List<InlineSpan> children = [];
    int start = 0;

    // Handle URLs first
    for (final match in matches) {
      if (match.start > start) {
        children.addAll(_processTextWithHashtags(
            text.substring(start, match.start), hashtagRegex, context));
      }

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

    // Handle remaining text after the last URL
    if (start < text.length) {
      children.addAll(_processTextWithHashtags(
          text.substring(start), hashtagRegex, context));
    }

    return RichText(
      text: TextSpan(
        children: children,
        style: DefaultTextStyle.of(context).style,
      ),
    );
  }

  List<InlineSpan> _processTextWithHashtags(
      String inputText, RegExp hashtagRegex, BuildContext context) {
    final List<InlineSpan> spans = [];
    int textStart = 0;

    for (final match in hashtagRegex.allMatches(inputText)) {
      if (match.start > textStart) {
        spans.add(TextSpan(
          text: inputText.substring(textStart, match.start),
          style: const TextStyle(fontSize: 18),
        ));
      }

      final hashtag = match.group(0)!;
      spans.add(TextSpan(
        text: hashtag,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.blue,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchPage(
                  userId: userId,
                  initialHashtag: hashtag,
                ),
              ),
            );
          },
      ));

      textStart = match.end;
    }

    if (textStart < inputText.length) {
      spans.add(TextSpan(
        text: inputText.substring(textStart),
        style: const TextStyle(fontSize: 18),
      ));
    }

    return spans;
  }
}
