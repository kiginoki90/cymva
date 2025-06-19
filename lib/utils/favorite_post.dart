import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FavoritePost {
  final ValueNotifier<Set<String>> favoritePostsNotifier =
      ValueNotifier<Set<String>>({});
  final Map<String, ValueNotifier<int>> favoriteUsersNotifiers = {};
  final FlutterSecureStorage storage = FlutterSecureStorage();
  String? userId;

  Future<List<String>> getFavoritePosts(String postId) async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return [];

    final favoriteUsersSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users')
        .get();

    final favoriteUsers =
        favoriteUsersSnapshot.docs.map((doc) => doc.id).toSet();
    favoritePostsNotifier.value = favoriteUsers;
    return favoriteUsers.toList();
  }

  Future<void> toggleFavorite(String postId, bool isFavorite) async {
    String? userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // ユーザーIDが取得できなければ、処理を中断
    if (userId == null) {
      print('Error: userId is null');
      return;
    }

    final favoriteUsersCollection = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users');

    final timestamp = Timestamp.now(); // 現在の時間を取得

    try {
      // `post_account_id` を取得
      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (!postSnapshot.exists) {
        print('Error: Post not found');
        return;
      }

      final postAccountId = postSnapshot.data()?['post_account_id'];
      if (postAccountId == null) {
        print('Error: post_account_id is null');
        return;
      }

      if (isFavorite) {
        // お気に入りから削除
        await favoriteUsersCollection.doc(userId).delete();

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(postAccountId)
            .get();

        // メッセージのカウントを減らす
        if (userDoc.exists && userDoc.data()?['starMessage'] != false) {
          await _updateMessageCount(postId, postAccountId, decrement: true);
        }
      } else {
        // お気に入りに追加
        await favoriteUsersCollection.doc(userId).set({
          'added_at': timestamp, // ユーザーが投稿をお気に入りにした時間を記録
          'user_id': userId,
        });

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(postAccountId)
            .get();

        if (userDoc.exists && userDoc.data()?['starMessage'] != false) {
          _addOrUpdateMessage(postId, postAccountId);
        }
      }

      // お気に入りの状態を更新
      final updatedFavorites = favoritePostsNotifier.value.toSet();
      if (isFavorite) {
        updatedFavorites.remove(postId);
      } else {
        updatedFavorites.add(postId);
      }
      favoritePostsNotifier.value = updatedFavorites;

      // お気に入りユーザー数を更新
      await updateFavoriteUsersCount(postId);
    } catch (e) {
      print('Error toggling favorite: $e'); // エラーログを表示
    }
  }

  Future<void> _addOrUpdateMessage(String postId, String postAccountId) async {
    // userId を取得
    final userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // postAccountId と userId が一致している場合は処理を終了
    if (userId == postAccountId) {
      return;
    }

    final userMessageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(postAccountId) // `post_account_id` を使用
        .collection('message');

    final querySnapshot = await userMessageRef
        .where('message_type', isEqualTo: 8)
        .where('postID', isEqualTo: postId)
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // 既存のメッセージがある場合、そのcountを1増やす
      final docRef = querySnapshot.docs.first.reference;
      await docRef.update({'count': FieldValue.increment(1)});
    } else {
      // 新しいメッセージを追加
      final messageData = {
        'message_type': 8,
        'timestamp': FieldValue.serverTimestamp(),
        'postID': postId,
        'isRead': false,
        'count': 1,
        'bold': true,
      };
      await userMessageRef.add(messageData);
    }
  }

  Future<void> _updateMessageCount(String postId, String postAccountId,
      {bool decrement = false}) async {
    final userMessageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(postAccountId) // `post_account_id` を使用
        .collection('message');

    final querySnapshot = await userMessageRef
        .where('message_type', isEqualTo: 8)
        .where('postID', isEqualTo: postId)
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docRef = querySnapshot.docs.first.reference;

      if (decrement) {
        // count を減らす
        await docRef.update({'count': FieldValue.increment(-1)});

        // count が 0 以下になった場合、メッセージを削除
        final updatedDoc = await docRef.get();
        final updatedCount = updatedDoc.data()?['count'] ?? 0;
        if (updatedCount <= 0) {
          await docRef.delete();
        }
      } else {
        // count を増やす
        await docRef.update({'count': FieldValue.increment(1)});
      }
    }
  }

  Future<void> updateFavoriteUsersCount(String postId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users')
        .get();

    favoriteUsersNotifiers[postId] ??= ValueNotifier<int>(0);
    favoriteUsersNotifiers[postId]!.value = snapshot.size;
  }
}
