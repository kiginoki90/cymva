// import 'package:cloud_firestore/cloud_firestore.dart';

// class DbManager {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   DocumentSnapshot? _lastDocument;

//   Future<List<QueryDocumentSnapshot>> getPosts() async {
//     Query query = _firestore
//         .collection('posts')
//         .orderBy('created_time', descending: true)
//         .limit(30);
//     final querySnapshot = await query.get();
//     if (querySnapshot.docs.isNotEmpty) {
//       _lastDocument = querySnapshot.docs.last;
//     }
//     return querySnapshot.docs;
//   }

//   Future<List<QueryDocumentSnapshot>> getPostsNext() async {
//     if (_lastDocument == null) return [];

//     Query query = _firestore
//         .collection('posts')
//         .orderBy('created_time', descending: true)
//         .startAfterDocument(_lastDocument!)
//         .limit(30);
//     final querySnapshot = await query.get();
//     if (querySnapshot.docs.isNotEmpty) {
//       _lastDocument = querySnapshot.docs.last;
//     }
//     return querySnapshot.docs;
//   }

//   Future<List<String>> getFavoritePosts(String userId) async {
//     final snapshot = await _firestore
//         .collection('favorites')
//         .doc(userId)
//         .collection('posts')
//         .get();

//     return snapshot.docs.map((doc) => doc['post_id'] as String).toList();
//   }

//   Future<List<String>> fetchBlockedAccounts(String userId) async {
//     final snapshot = await _firestore
//         .collection('users')
//         .doc(userId)
//         .collection('blockUsers')
//         .get();

//     return snapshot.docs
//         .map((doc) => doc['blocked_user_id'] as String)
//         .toList();
//   }
// }
