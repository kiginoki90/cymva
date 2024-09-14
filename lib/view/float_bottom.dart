import 'package:cymva/view/post_page/post_page.dart';
import 'package:flutter/material.dart';

class FloatBottom extends StatefulWidget {
  const FloatBottom({super.key});

  @override
  State<FloatBottom> createState() => _FloatBottomState();
}

class _FloatBottomState extends State<FloatBottom> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PostPage()),
        );
      },
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}
