import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/post_item_utils.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
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
          _buildUserInfo(),
          const SizedBox(height: 5),
          if (repostPost.category == '俳句・短歌')
            buildVerticalText(repostPost.content)
          else
            LinkText(
              text: repostPost.content,
              textSize: 15,
            ),
          const SizedBox(height: 10),
          if (repostPost.mediaUrl != null && repostPost.mediaUrl!.isNotEmpty)
            MediaDisplayWidget(
              mediaUrl: repostPost.mediaUrl,
              category: repostPost.category ?? '',
              atStart: true,
              post: repostPost,
              is_video: repostPost.isVideo ?? false,
            ),
        ],
      ),
    );
  }

  // ユーザー情報を表示するウィジェット
  Widget _buildUserInfo() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            repostPostAccount.imagePath ??
                'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.network(
                'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            text: TextSpan(
              style: const TextStyle(color: Colors.black),
              children: [
                TextSpan(
                  text: repostPostAccount.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: '@${repostPostAccount.userId}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // メディアコンテンツを表示するウィジェット
  Widget _buildMediaContent(BuildContext context) {
    if (repostPost.mediaUrl!.length == 1) {
      // 画像が1枚のときは横幅いっぱいで表示
      final mediaUrl = repostPost.mediaUrl![0];
      return GestureDetector(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            mediaUrl,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorImage();
            },
          ),
        ),
      );
    } else {
      // 画像が複数枚のときはグリッドで表示
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: repostPost.mediaUrl!.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemBuilder: (BuildContext context, int index) {
          final mediaUrl = repostPost.mediaUrl![index];
          return GestureDetector(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                mediaUrl,
                width: MediaQuery.of(context).size.width * 0.4,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorImage();
                },
              ),
            ),
          );
        },
      );
    }
  }

  // エラービルダー用の画像
  Widget _buildErrorImage() {
    return Image.network(
      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
      width: 40,
      height: 40,
      fit: BoxFit.cover,
    );
  }
}
