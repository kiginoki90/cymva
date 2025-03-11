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
      if (isFavorite) {
        // お気に入りから削除
        await favoriteUsersCollection.doc(userId).delete();
      } else {
        // お気に入りに追加
        await favoriteUsersCollection.doc(userId).set({
          'added_at': timestamp, // ユーザーが投稿をお気に入りにした時間を記録
          'user_id': userId,
        });
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
