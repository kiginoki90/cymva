import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BookmarkPost {
  final ValueNotifier<Set<String>> bookmarkPostsNotifier =
      ValueNotifier<Set<String>>({});
  final Map<String, ValueNotifier<int>> bookmarkUsersNotifiers = {};
  final FlutterSecureStorage storage = FlutterSecureStorage();
  String? userId;

  Future<List<String>> getBookmarkPosts(String postId) async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return [];

    final bookmarkPostsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('bookmark_users')
        .get();

    final bookmarkPosts =
        bookmarkPostsSnapshot.docs.map((doc) => doc.id).toSet();
    bookmarkPostsNotifier.value = bookmarkPosts;

    return bookmarkPosts.toList();
  }

  Future<void> toggleBookmark(String postId, bool isBookmarked) async {
    String? userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // ユーザーIDが取得できなければ、処理を中断
    if (userId == null) {
      print('Error: userId is null');
      return;
    }

    final bookmarkUsersCollection = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('bookmark_users');

    final timestamp = Timestamp.now(); // 現在の時間を取得

    try {
      if (isBookmarked) {
        await bookmarkUsersCollection.doc(userId).delete();
      } else {
        await bookmarkUsersCollection.doc(userId).set({
          'added_at': timestamp,
          'user_id': userId,
        });
      }

      // ブックマークの状態を更新
      final updatedBookmarks = bookmarkPostsNotifier.value.toSet();
      if (isBookmarked) {
        updatedBookmarks.remove(postId);
      } else {
        updatedBookmarks.add(postId);
      }
      bookmarkPostsNotifier.value = updatedBookmarks;

      // ブックマークユーザー数を更新
      await updateBookmarkUsersCount(postId);
    } catch (e) {
      print('Error toggling bookmark: $e'); // エラーログを表示
    }
  }

  Future<void> updateBookmarkUsersCount(String postId) async {
    if (postId.isEmpty) {
      // postIdが空の場合は処理をスキップ
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('bookmark_users')
        .get();

    bookmarkUsersNotifiers[postId] ??= ValueNotifier<int>(0);
    bookmarkUsersNotifiers[postId]!.value = snapshot.size;
  }
}
