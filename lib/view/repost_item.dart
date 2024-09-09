import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:flutter/material.dart';

class RepostItem extends StatelessWidget {
  final Post repostPost;
  final Account repostPostAccount;

  const RepostItem({
    required this.repostPost,
    required this.repostPostAccount,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  repostPostAccount.imagePath,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                repostPostAccount.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '@${repostPostAccount.userId}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(repostPost.content),
          const SizedBox(height: 5),
          if (repostPost.mediaUrl != null && repostPost.mediaUrl!.isNotEmpty)
            Wrap(
              spacing: 8.0, // 画像間のスペース
              children: repostPost.mediaUrl!.map((url) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: MediaQuery.of(context).size.width * 0.85, // 幅の調整
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
