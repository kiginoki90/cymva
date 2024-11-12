import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/users.dart';

class FollowService {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  String? userId;

  Future<void> initialize() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;
  }

  Future<bool> checkFollowStatus(String postUserId) async {
    if (userId == null) return false;

    final followDoc = await UserFirestore.users
        .doc(userId)
        .collection('follow')
        .doc(postUserId)
        .get();

    return followDoc.exists;
  }

  Future<void> toggleFollowStatus(String postUserId) async {
    if (userId == null) return;

    final isFollowing = await checkFollowStatus(postUserId);
    try {
      if (isFollowing) {
        // Unfollow
        await UserFirestore.users
            .doc(userId)
            .collection('follow')
            .doc(postUserId)
            .delete();
        await UserFirestore.users
            .doc(postUserId)
            .collection('followers')
            .doc(userId)
            .delete();
      } else {
        // Follow
        await UserFirestore.users
            .doc(userId)
            .collection('follow')
            .doc(postUserId)
            .set({'followed_at': Timestamp.now()});
        await UserFirestore.users
            .doc(postUserId)
            .collection('followers')
            .doc(userId)
            .set({'followed_at': Timestamp.now()});

        // 24時間以内に同じメッセージがあるか確認
        final userDoc = await UserFirestore.users.doc(postUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>;
        final followMessage = userData['follow_message'] ?? false;

        if (followMessage) {
          final cutoffTime =
              Timestamp.now().toDate().subtract(Duration(hours: 24));
          final recentMessagesQuery = await UserFirestore.users
              .doc(postUserId)
              .collection('message')
              .where('request_user', isEqualTo: userId)
              .where('message_type', isEqualTo: 3)
              .where('timestamp',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime))
              .get();

          // メッセージがなければ、新しいメッセージを追加
          if (recentMessagesQuery.docs.isEmpty) {
            await UserFirestore.users
                .doc(postUserId)
                .collection('message')
                .add({
              'isRead': false,
              'message_type': 3,
              'request_user': userId,
              'timestamp': Timestamp.now(),
            });
          }
        }
      }
    } catch (e) {
      print('フォロー処理に失敗しました: $e');
    }
  }

  Future<void> handleUnfollow(String postUserId) async {
    await UserFirestore.users
        .doc(userId)
        .collection('follow')
        .doc(postUserId)
        .delete();
  }

  Future<void> handleFollowRequest(String postUserId, Account myAccount) async {
    final CollectionReference messageCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(postUserId)
        .collection('message');

    final Timestamp currentTime = Timestamp.now();

    // Add follow request message
    await messageCollection.add({
      'created_time': currentTime,
      'message_type': 1,
      'request_user': myAccount.id,
      'request_userId': myAccount.userId,
      'isRead': false,
    });
  }
}
