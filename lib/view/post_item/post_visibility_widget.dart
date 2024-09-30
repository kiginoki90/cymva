import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFollowing(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final isFollowing = snapshot.data!;
        final isOwner = userId == postAccount.id;

        if (postAccount.lockAccount && !isFollowing && !isOwner) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey), // 枠線の色
              borderRadius: BorderRadius.circular(8.0), // 角を丸める
            ),
            child: const Text(
              'この引用は表示できません',
              textAlign: TextAlign.start,
            ),
          );
        } else {
          return RepostItem(
            repostPost: repostPost,
            repostPostAccount: postAccount,
          );
        }
      },
    );
  }
}
