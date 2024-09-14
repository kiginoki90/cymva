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
              const SizedBox(width: 5),
              Text(
                '@${repostPostAccount.userId}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(repostPost.content),
          const SizedBox(height: 10),
          if (repostPost.mediaUrl != null && repostPost.mediaUrl!.isNotEmpty)
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(), // グリッド内でのスクロールを無効に
              shrinkWrap: true, // グリッドのサイズを内容に合わせる
              itemCount: repostPost.mediaUrl!.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // グリッドの列数を2に設定
              ),
              itemBuilder: (BuildContext context, int index) {
                final mediaUrl = repostPost.mediaUrl![index];
                return GestureDetector(
                  child: ClipRRect(
                    child: Image.network(
                      mediaUrl,
                      width: MediaQuery.of(context).size.width *
                          0.4, // 画像の幅を画面に合わせる
                      height: 150, // 固定高さ
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
