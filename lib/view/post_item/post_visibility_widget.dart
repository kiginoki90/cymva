import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:cymva/view/repost_item.dart';
import 'package:flutter/material.dart';

class PostVisibilityWidget extends StatefulWidget {
  final Account postAccount;
  final String userId;
  final Post repostPost;

  const PostVisibilityWidget({
    Key? key,
    required this.postAccount,
    required this.userId,
    required this.repostPost,
  }) : super(key: key);

  @override
  _PostVisibilityWidgetState createState() => _PostVisibilityWidgetState();
}

class _PostVisibilityWidgetState extends State<PostVisibilityWidget> {
  late Future<bool> _isFollowingFuture;
  late Future<List<String>> _blockedAccountsFuture;
  final BookmarkPost _bookmarkPost = BookmarkPost();

  @override
  void initState() {
    super.initState();
    _isFollowingFuture = _isFollowing();
    _blockedAccountsFuture = _fetchBlockedAccounts(widget.userId);
    // _bookmarkPost.getBookmarkPosts();
  }

  Future<bool> _isFollowing() async {
    final userFollowCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('follow');
    final doc = await userFollowCollection.doc(widget.postAccount.id).get();
    return doc.exists;
  }

  Future<List<String>> _fetchBlockedAccounts(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();
    return snapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFollowingFuture,
      builder: (context, followingSnapshot) {
        if (!followingSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final isFollowing = followingSnapshot.data!;
        final isOwner = widget.userId == widget.postAccount.id;

        return FutureBuilder<List<String>>(
          future: _blockedAccountsFuture,
          builder: (context, blockedSnapshot) {
            if (!blockedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final blockedAccounts = blockedSnapshot.data!;
            final isBlocked = blockedAccounts.contains(widget.postAccount.id);

            if ((widget.postAccount.lockAccount && !isFollowing && !isOwner) ||
                isBlocked) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Text(
                  'この引用は表示できません',
                  textAlign: TextAlign.start,
                ),
              );
            } else {
              _bookmarkPost.bookmarkUsersNotifiers[widget.repostPost.id] ??=
                  ValueNotifier<int>(0);
              _bookmarkPost.updateBookmarkUsersCount(widget.repostPost.id);
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailPage(
                        post: widget.repostPost,
                        postAccount: widget.postAccount,
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                        bookmarkUsersNotifier: _bookmarkPost
                            .bookmarkUsersNotifiers[widget.repostPost.id]!,
                        isBookmarkedNotifier: ValueNotifier<bool>(
                          _bookmarkPost.bookmarkPostsNotifier.value
                              .contains(widget.repostPost.id),
                        ),
                      ),
                    ),
                  );
                },
                child: RepostItem(
                  repostPost: widget.repostPost,
                  repostPostAccount: widget.postAccount,
                ),
              );
            }
          },
        );
      },
    );
  }
}
