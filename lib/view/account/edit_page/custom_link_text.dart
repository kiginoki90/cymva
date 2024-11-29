import 'package:cymva/view/account/edit_page/account_top_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/search/search_page.dart';

class CustomLinkText extends StatelessWidget {
  final String text;
  final String userId;

  CustomLinkText({required this.text, required this.userId});

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final hashtagRegex = RegExp(r'#[\w]+');
    final mentionRegex = RegExp(r'@[\w]+');

    final matches = urlRegex.allMatches(text);
    final List<InlineSpan> children = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        children.addAll(_processTextWithHashtagsAndMentions(
            text.substring(start, match.start),
            hashtagRegex,
            mentionRegex,
            context));
      }

      final urlString = match.group(0)!;
      final Uri url = Uri.parse(urlString);

      children.add(TextSpan(
        text: urlString,
        style: const TextStyle(
          fontSize: 12,
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
      children.addAll(_processTextWithHashtagsAndMentions(
          text.substring(start), hashtagRegex, mentionRegex, context));
    }

    return RichText(
      text: TextSpan(
        children: children,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  List<InlineSpan> _processTextWithHashtagsAndMentions(String inputText,
      RegExp hashtagRegex, RegExp mentionRegex, BuildContext context) {
    final List<InlineSpan> spans = [];
    int textStart = 0;

    final matches = [
      ...hashtagRegex.allMatches(inputText),
      ...mentionRegex.allMatches(inputText)
    ];
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start > textStart) {
        spans.add(TextSpan(
          text: inputText.substring(textStart, match.start),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('#')) {
        spans.add(TextSpan(
          text: matchedText,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    userId: userId,
                    initialHashtag: matchedText,
                  ),
                ),
              );
            },
        ));
      } else if (matchedText.startsWith('@')) {
        spans.add(TextSpan(
          text: matchedText,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final userId = matchedText.substring(1);
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .where('user_id', isEqualTo: userId)
                  .limit(1)
                  .get();
              if (userDoc.docs.isNotEmpty) {
                final postAccountId = userDoc.docs.first.id;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountTopPage(
                      postAccountId: postAccountId,
                      userId: this.userId,
                    ),
                  ),
                );
              }
            },
        ));
      }

      textStart = match.end;
    }

    if (textStart < inputText.length) {
      spans.add(TextSpan(
        text: inputText.substring(textStart),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ));
    }

    return spans;
  }
}
