import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:cymva/view/reply_page.dart';

class IconsActionsWidget extends StatelessWidget {
  final Post post;
  final Account postAccount;
  final String userId;
  final ValueNotifier<int> bookmarkUsersNotifier;
  final ValueNotifier<bool> isBookmarkedNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<int> replyCountNotifier;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBookMsrkToggle;

  const IconsActionsWidget({
    Key? key,
    required this.post,
    required this.postAccount,
    required this.userId,
    required this.bookmarkUsersNotifier,
    required this.isBookmarkedNotifier,
    required this.isFavoriteNotifier,
    required this.replyCountNotifier,
    required this.onFavoriteToggle,
    required this.onBookMsrkToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(post.postId)
                  .collection('favorite_users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final favoriteCount = snapshot.data!.docs.length;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    '$favoriteCount',
                    key: ValueKey<int>(favoriteCount),
                  ),
                );
              },
            ),
            const SizedBox(width: 5),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('favorite_posts')
                  .doc(post.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final isFavorite = snapshot.data!.exists;

                return GestureDetector(
                  onTap: () {
                    onFavoriteToggle();
                    final newValue = !isFavoriteNotifier.value;
                    isFavoriteNotifier.value = newValue;

                    // スナックバーを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newValue ? 'スターを送りました' : 'スターを返して貰いました'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // タップした感覚を提供
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_outline,
                      key: ValueKey<bool>(isFavorite),
                      color: isFavorite
                          ? const Color.fromARGB(255, 255, 183, 59)
                          : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(post.postId)
                  .collection('repost')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('0');
                }
                final repostCount = snapshot.data!.docs.length;
                return Text(repostCount.toString());
              },
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RepostPage(
                      post: post,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: Icon(
                Icons.repeat_outlined,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: replyCountNotifier,
          builder: (context, replyCount, child) {
            return Row(
              children: [
                Text(replyCount.toString()),
                IconButton(
                  onPressed: post.closeComment
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReplyPage(
                                post: post,
                                userId: userId,
                                postAccount: postAccount,
                              ),
                            ),
                          );
                        },
                  icon: Icon(
                    Icons.comment,
                    color: post.closeComment ? Colors.grey : Colors.black,
                  ),
                ),
              ],
            );
          },
        ),
        Row(
          children: [
            if (postAccount.id == userId)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.postId)
                    .collection('bookmark_users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bookmarkCount = snapshot.data!.docs.length;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Text(
                      '$bookmarkCount',
                      key: ValueKey<int>(bookmarkCount),
                    ),
                  );
                },
              ),
            const SizedBox(width: 5),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('bookmark_posts')
                  .doc(post.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final isBookmarked = snapshot.data!.exists;
                return GestureDetector(
                  onTap: () {
                    onBookMsrkToggle();
                    final newValue = !isBookmarkedNotifier.value;
                    isBookmarkedNotifier.value = newValue;

                    // スナックバーを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newValue ? '栞を挟みました' : '栞を外しました'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      key: ValueKey<bool>(isBookmarked),
                      color: isBookmarked
                          ? const Color.fromARGB(255, 59, 144, 255)
                          : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
