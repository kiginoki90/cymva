import 'package:flutter/material.dart';

class PostActionButtons extends StatelessWidget {
  final int favoriteCount;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool isRetweeted;
  final VoidCallback onRetweetToggle;
  final int replyCount;
  final VoidCallback onReplyPressed;
  final VoidCallback onSharePressed;

  const PostActionButtons({
    Key? key,
    required this.favoriteCount,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.isRetweeted,
    required this.onRetweetToggle,
    required this.replyCount,
    required this.onReplyPressed,
    required this.onSharePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(favoriteCount.toString()),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onFavoriteToggle,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_outline,
                color: isFavorite
                    ? Color.fromARGB(255, 255, 183, 59)
                    : Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onRetweetToggle,
              child: Icon(
                isRetweeted ? Icons.repeat : Icons.repeat_outlined,
                color: isRetweeted ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
        Row(
          children: [
            Text(replyCount.toString()),
            IconButton(
              onPressed: onReplyPressed,
              icon: const Icon(Icons.comment),
            ),
          ],
        ),
        IconButton(
          onPressed: onSharePressed,
          icon: const Icon(Icons.share),
        ),
      ],
    );
  }
}
