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
                  repostPostAccount.imagePath ??
                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 画像の取得に失敗した場合のエラービルダー
                    return Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                // Expandedを追加して、テキストが横幅を調整できるようにする
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1, // 最大1行に設定
                  text: TextSpan(
                    style:
                        const TextStyle(color: Colors.black), // テキストのデフォルトスタイル
                    children: [
                      TextSpan(
                        text: repostPostAccount.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' '), // スペースを追加
                      TextSpan(
                        text: '@${repostPostAccount.userId}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(repostPost.content),
          const SizedBox(height: 10),
          if (repostPost.mediaUrl != null && repostPost.mediaUrl!.isNotEmpty)
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
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
                      mediaUrl ??
                          'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                      width: MediaQuery.of(context).size.width *
                          0.4, // 画像の幅を画面に合わせる
                      height: 150, // 固定高さ
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 画像の取得に失敗した場合のエラービルダー
                        return Image.network(
                          'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        );
                      },
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
