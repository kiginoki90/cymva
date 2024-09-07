import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReplyPost {
  final ValueNotifier<Set<String>> replyPostsNotifier =
      ValueNotifier<Set<String>>({});
  final Map<String, ValueNotifier<int>> favoriteUsersNotifiers = {};

  Future<List<String>> getReplyPosts(String postId) async {
    final replyPostsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('reply_post')
        .get(); // クエリを実行してQuerySnapshotを取得

    final replyPosts = replyPostsSnapshot.docs.map((doc) => doc.id).toSet();
    replyPostsNotifier.value = replyPosts;
    return replyPosts.toList();
  }

  Future<void> toggleReply(String postId, bool isFavorite) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // final favoritePostsCollection = FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(userId)
    //     .collection('reply_posts');

    final replyPostCollection = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('reply_post');

    final timestamp = Timestamp.now(); // 現在の時間を取得

    if (isFavorite == true) {
      await replyPostCollection.doc(userId).delete();
    } else {
      await replyPostCollection.doc(userId).set({
        'added_at': timestamp, // ユーザーが投稿をお気に入りにした時間を記録
      });
    }

    final updatedPosts = replyPostsNotifier.value.toSet();
    if (updatedPosts.contains(postId)) {
      updatedPosts.remove(postId);
    } else {
      updatedPosts.add(postId);
    }
    replyPostsNotifier.value = updatedPosts;

    await updateFavoriteUsersCount(postId);
  }

  Future<void> updateFavoriteUsersCount(String postId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('reply_post')
        .get();

    favoriteUsersNotifiers[postId] ??= ValueNotifier<int>(0);
    favoriteUsersNotifiers[postId]!.value = snapshot.size;
  }
}
