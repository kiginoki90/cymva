import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:intl/intl.dart';
import 'package:cymva/view/post_detail_page.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cymva/view/account/account_page.dart';

class PostItemWidget extends StatelessWidget {
  final Post post;
  final Account postAccount;
  final ValueNotifier<int> favoriteUsersNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final VoidCallback onFavoriteToggle;

  const PostItemWidget({
    required this.post,
    required this.postAccount,
    required this.favoriteUsersNotifier,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              post: post,
              postAccountName: postAccount.name,
              postAccountUserId: postAccount.userId,
              postAccountImagePath: postAccount.imagePath,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AccountPage(userId: post.postAccountId),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  postAccount.imagePath,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            postAccount.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@${postAccount.userId}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(DateFormat('yyyy/M/d')
                          .format(post.createdTime!.toDate())),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.content),
                      const SizedBox(height: 10),
                      if (post.mediaUrl != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImagePage(
                                    imageUrl: post.mediaUrl!),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post.mediaUrl!,
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: favoriteUsersNotifier,
                            builder: (context, value, child) {
                              return Text((value - 1).toString());
                            },
                          ),
                          const SizedBox(width: 5),
                          ValueListenableBuilder<bool>(
                            valueListenable: isFavoriteNotifier,
                            builder: (context, isFavorite, child) {
                              return GestureDetector(
                                onTap: () {
                                  onFavoriteToggle();
                                  isFavoriteNotifier.value =
                                      !isFavoriteNotifier.value;
                                },
                                child: Icon(
                                  isFavorite ? Icons.star : Icons.star_outline,
                                  color: isFavorite
                                      ? Color.fromARGB(255, 255, 183, 59)
                                      : Colors.grey,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.comment),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
