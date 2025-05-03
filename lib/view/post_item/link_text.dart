import 'package:cymva/utils/navigation_utils.dart';
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

  const LinkText({
    required this.text,
    required this.userId,
    required this.textSize,
    this.tapable = false,
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
    final hashtagRegex = RegExp(r'#([\wぁ-んァ-ン一-龥々ー]+)');
    final mentionRegex = RegExp(r'@[\w]+');

    final matches = urlRegex.allMatches(widget.text);
    final List<InlineSpan> children = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        children.addAll(_processTextWithHashtagsAndMentions(
          widget.text.substring(start, match.start),
          hashtagRegex,
          mentionRegex,
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
        hashtagRegex,
        mentionRegex,
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
    RegExp hashtagRegex,
    RegExp mentionRegex,
    BuildContext context,
  ) {
    final List<InlineSpan> spans = [];
    int textStart = 0;

    final matches = [
      ...hashtagRegex.allMatches(inputText),
      ...mentionRegex.allMatches(inputText),
    ];
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start > textStart) {
        spans.add(TextSpan(
          text: inputText.substring(textStart, match.start),
          style: TextStyle(
            fontFamily: 'CustomFont',
            fontSize: widget.textSize.toDouble(),
          ),
        ));
      }

      final matchedText = match.group(0)!;
      final recognizer = TapGestureRecognizer();
      _recognizers.add(recognizer);

      if (matchedText.startsWith('#')) {
        recognizer.onTap = () async {
          await storage.write(key: 'query', value: matchedText);
          navigateToSearchPage(context, widget.userId, '2', true);
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
      } else if (matchedText.startsWith('@')) {
        recognizer.onTap = () async {
          final userId = matchedText.substring(1);
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('user_id', isEqualTo: userId)
              .limit(1)
              .get();
          if (userDoc.docs.isNotEmpty) {
            final postAccountId = userDoc.docs.first.id;
            navigateToPage(context, postAccountId, '1', true, false);
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
      }

      textStart = match.end;
    }

    if (textStart < inputText.length) {
      spans.add(TextSpan(
        text: inputText.substring(textStart),
        style: TextStyle(
          fontFamily: 'CustomFont',
          fontSize: widget.textSize.toDouble(),
        ),
      ));
    }

    return spans;
  }
}
