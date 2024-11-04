import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:cymva/view/repost_item.dart';
import 'package:flutter/material.dart';

class PostVisibilityWidget extends StatelessWidget {
  final Account postAccount;
  final String userId;
  final Post repostPost;

  const PostVisibilityWidget({
    Key? key,
    required this.postAccount,
    required this.userId,
    required this.repostPost,
  }) : super(key: key);

  Future<bool> _isFollowing() async {
    final userFollowCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('follow');
    final doc = await userFollowCollection.doc(postAccount.id).get();
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
      future: _isFollowing(),
      builder: (context, followingSnapshot) {
        if (!followingSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final isFollowing = followingSnapshot.data!;
        final isOwner = userId == postAccount.id;

        return FutureBuilder<List<String>>(
          future: _fetchBlockedAccounts(userId),
          builder: (context, blockedSnapshot) {
            if (!blockedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final blockedAccounts = blockedSnapshot.data!;
            final isBlocked = blockedAccounts.contains(postAccount.id);

            if ((postAccount.lockAccount && !isFollowing && !isOwner) ||
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
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailPage(
                        post: repostPost,
                        postAccountName: postAccount.name,
                        postAccountUserId: postAccount.userId,
                        postAccountImagePath: postAccount.imagePath,
                        replyFlag: ValueNotifier<bool>(false),
                        userId: userId,
                      ),
                    ),
                  );
                },
                child: RepostItem(
                  repostPost: repostPost,
                  repostPostAccount: postAccount,
                ),
              );
            }
          },
        );
      },
    );
  }
}
