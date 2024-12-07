// import 'package:cymva/model/account.dart';
// import 'package:cymva/utils/firestore/users.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'db.dart';

// final viewModelProvider =
//     ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

// class ViewModel extends ChangeNotifier {
//   ViewModel(this.ref);

//   final Ref ref;
//   List<QueryDocumentSnapshot> stackedPostList = [];
//   List<QueryDocumentSnapshot> currentPostList = [];
//   List<String> favoritePosts = [];
//   List<String> blockedAccounts = [];
//   Map<String, Account> postUserMap = {};

//   Future<void> getPosts(String userId) async {
//     stackedPostList = [];
//     currentPostList = await ref.read(dbManagerProvider).getPosts();
//     favoritePosts = await ref.read(dbManagerProvider).getFavoritePosts(userId);
//     blockedAccounts =
//         await ref.read(dbManagerProvider).fetchBlockedAccounts(userId);
//     stackedPostList.addAll(currentPostList);
//     postUserMap = await UserFirestore.getPostUserMap(
//           stackedPostList
//               .map((doc) => (doc.data()
//                   as Map<String, dynamic>)['post_account_id'] as String)
//               .toList(),
//         ) ??
//         {};
//     notifyListeners();
//   }

//   Future<void> getPostsNext(String userId) async {
//     currentPostList = await ref.read(dbManagerProvider).getPostsNext();
//     stackedPostList.addAll(currentPostList);
//     final newPostUserMap = await UserFirestore.getPostUserMap(
//           currentPostList
//               .map((doc) => (doc.data()
//                   as Map<String, dynamic>)['post_account_id'] as String)
//               .toList(),
//         ) ??
//         {};
//     postUserMap.addAll(newPostUserMap);
//     notifyListeners();
//   }
// }

// final dbManagerProvider = Provider((ref) => DbManager());
