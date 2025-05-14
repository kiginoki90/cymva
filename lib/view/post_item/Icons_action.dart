import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/utils/book_mark.dart';

class IconsActionsWidget extends StatefulWidget {
  final Post post;
  final Account postAccount;
  final String userId;
  final ValueNotifier<int> bookmarkUsersNotifier;
  final ValueNotifier<bool> isBookmarkedNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<int> replyCountNotifier;
  // final VoidCallback onFavoriteToggle;
  // final VoidCallback onBookMsrkToggle;

  const IconsActionsWidget({
    Key? key,
    required this.post,
    required this.postAccount,
    required this.userId,
    required this.bookmarkUsersNotifier,
    required this.isBookmarkedNotifier,
    required this.isFavoriteNotifier,
    required this.replyCountNotifier,
    // required this.onFavoriteToggle,
    // required this.onBookMsrkToggle,
  }) : super(key: key);

  @override
  _IconsActionsWidgetState createState() => _IconsActionsWidgetState();
}

class _IconsActionsWidgetState extends State<IconsActionsWidget> {
  bool _isProcessingFavorite = false;
  bool _isProcessingBookmark = false;
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final FavoritePost _favoritePost = FavoritePost();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (_isProcessingFavorite) return;

                setState(() {
                  _isProcessingFavorite = true;
                });

                // Firestoreのドキュメントを確認
                final docSnapshot = await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.post.id)
                    .collection('favorite_users')
                    .doc(widget.userId)
                    .get();

                final snackBarMessage =
                    docSnapshot.exists ? 'スターを返して貰いました' : 'スターを送りました';

                await _favoritePost.toggleFavorite(
                    widget.post.id, docSnapshot.exists);

                // スナックバーを表示
                showTopSnackBar(context, snackBarMessage,
                    backgroundColor: const Color.fromARGB(255, 255, 183, 59));

                // タップした感覚を提供
                HapticFeedback.lightImpact();

                setState(() {
                  _isProcessingFavorite = false;
                });
              },
              child: Row(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('favorite_users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Text(
                          '0',
                          key: ValueKey<int>(0),
                        );
                      }

                      final favoriteCount = snapshot.data!.docs.length;

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
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
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('favorite_users')
                        .doc(widget.userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Icon(
                          Icons.star_outline,
                          color: Colors.grey,
                        );
                      }
                      final isFavorite = snapshot.data!.exists;

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
                        },
                        child: Icon(
                          isFavorite ? Icons.star : Icons.star_outline,
                          key: ValueKey<bool>(isFavorite),
                          color: isFavorite
                              ? const Color.fromARGB(255, 255, 183, 59)
                              : Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RepostPage(
                      post: widget.post,
                      userId: widget.userId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
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
                  Icon(
                    Icons.repeat_outlined,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: widget.replyCountNotifier,
          builder: (context, replyCount, child) {
            return GestureDetector(
              onTap: widget.post.closeComment
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReplyPage(
                            post: widget.post,
                            userId: widget.userId,
                            postAccount: widget.postAccount,
                          ),
                        ),
                      );
                    },
              child: Row(
                children: [
                  Text(replyCount.toString()),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.comment,
                    color:
                        widget.post.closeComment ? Colors.grey : Colors.black,
                  ),
                ],
              ),
            );
          },
        ),
        Row(
          children: [
            if (widget.postAccount.id == widget.userId)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.post.id)
                    .collection('bookmark_users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      '0',
                      key: ValueKey<int>(0),
                    );
                  }

                  final bookmarkCount = snapshot.data!.docs.length;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
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
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('bookmark_users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Icon(
                    Icons.bookmark_outline,
                    color: Colors.grey,
                  );
                }

                final isBookmarked = snapshot.data!.exists;

                return GestureDetector(
                  onTap: () async {
                    if (_isProcessingBookmark) return;

                    setState(() {
                      _isProcessingBookmark = true;
                    });

                    // Firestoreのドキュメントを確認
                    final docSnapshot = await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('bookmark_users')
                        .doc(widget.userId)
                        .get();

                    await _bookmarkPost.toggleBookmark(
                        widget.post.id, docSnapshot.exists);

                    // スナックバーのメッセージを設定
                    final snackBarMessage =
                        docSnapshot.exists ? '栞を外しました' : '栞を挟みました';

                    // スナックバーを表示
                    showTopSnackBar(context, snackBarMessage,
                        backgroundColor:
                            const Color.fromARGB(255, 59, 144, 255));

                    HapticFeedback.lightImpact();

                    setState(() {
                      _isProcessingBookmark = false;
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
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
