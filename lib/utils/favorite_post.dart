import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritePost {
  final ValueNotifier<Set<String>> favoritePostsNotifier =
      ValueNotifier<Set<String>>({});
  final Map<String, ValueNotifier<int>> favoriteUsersNotifiers = {};

  Future<List<String>> getFavoritePosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final favoritePostsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorite_posts')
        .get();

    final favoritePosts =
        favoritePostsSnapshot.docs.map((doc) => doc.id).toSet();
    favoritePostsNotifier.value = favoritePosts;
    return favoritePosts.toList();
  }

  Future<void> toggleFavorite(String postId, bool isFavorite) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final favoritePostsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorite_posts');

    final favoriteUsersCollection = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users');

    if (isFavorite == true) {
      await favoritePostsCollection.doc(postId).delete();
      await favoriteUsersCollection.doc(userId).delete();
    } else {
      await favoritePostsCollection.doc(postId).set({});
      await favoriteUsersCollection.doc(userId).set({});
    }

    final updatedFavorites = favoritePostsNotifier.value.toSet();
    if (updatedFavorites.contains(postId)) {
      updatedFavorites.remove(postId);
    } else {
      updatedFavorites.add(postId);
    }
    favoritePostsNotifier.value = updatedFavorites;

    await updateFavoriteUsersCount(postId);
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
