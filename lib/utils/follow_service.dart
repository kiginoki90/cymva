import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FollowService {
  final FirebaseFirestore firestore;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  String? userId;

  FollowService(this.firestore);

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
      } else {
        // Follow
        await UserFirestore.users
            .doc(userId)
            .collection('follow')
            .doc(postUserId)
            .set({'followed_at': Timestamp.now(), 'user_id': postUserId});

        final cutoffTime =
            Timestamp.now().toDate().subtract(Duration(hours: 24));

        // 過去24時間以内のメッセージを取得
        final recentMessagesQuery = await UserFirestore.users
            .doc(postUserId)
            .collection('message')
            .where('request_user', isEqualTo: userId)
            .where('message_type', isEqualTo: 3)
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime))
            .get();

        // 条件に合致するメッセージが存在しない場合
        if (recentMessagesQuery.docs.isEmpty) {
          // 全期間のメッセージを取得
          final allMessagesQuery = await UserFirestore.users
              .doc(postUserId)
              .collection('message')
              .where('request_user', isEqualTo: userId)
              .where('message_type', isEqualTo: 3)
              .get();

          // 全期間のメッセージが存在しない場合
          if (allMessagesQuery.docs.isEmpty) {
            await UserFirestore.users
                .doc(postUserId)
                .collection('message')
                .add({
              'isRead': false,
              'message_type': 3,
              'request_user': userId,
              'timestamp': Timestamp.now(),
              'bold': true,
            });
          }
        }
      }
    } catch (e) {
      print('フォロー処理に失敗しました: $e');
    }
  }

  Future<void> handleUnfollow(String postUserId) async {
    if (userId == null) return;

    await UserFirestore.users
        .doc(userId)
        .collection('follow')
        .doc(postUserId)
        .delete();
  }

  Future<void> handleFollowRequest(
      BuildContext context, String postUserId, Account myAccount) async {
    final CollectionReference messageCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(postUserId)
        .collection('message');

    final Timestamp currentTime = Timestamp.now();
    final cutoffTime = currentTime.toDate().subtract(Duration(hours: 24));

    try {
      sendMessageToUser(postUserId);

      // 過去24時間以内のメッセージを取得
      final recentMessagesQuery = await messageCollection
          .where('request_user', isEqualTo: myAccount.id)
          .where('message_type', isEqualTo: 1)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime))
          .get();

      // 条件に合致するメッセージが存在しない場合のみメッセージを送信
      if (recentMessagesQuery.docs.isEmpty) {
        await messageCollection.add({
          'timestamp': currentTime,
          'message_type': 1,
          'request_user': myAccount.id,
          'request_userId': myAccount.userId,
          'isRead': false,
          'bold': true,
        });
      }
    } catch (e) {
      print('フォローリクエストの送信に失敗しました: $e');
    }
  }

  Future<void> sendMessageToUser(String postUserId) async {
    final CollectionReference messageCollection =
        firestore.collection('users').doc(userId).collection('message');

    final Timestamp currentTime = Timestamp.now();

    try {
      // postUserIdに基づいてuser_idを取得
      final userDoc = await firestore.collection('users').doc(postUserId).get();
      final requestUserId = userDoc['user_id'];

      // メッセージを送信
      await messageCollection.add({
        'timestamp': currentTime,
        'message_type': 6,
        'request_user': postUserId,
        'request_userId': requestUserId,
        'isRead': false,
        'bold': true,
      });
    } catch (e) {
      print('メッセージの送信に失敗しました: $e');
    }
  }

  Future<void> saveDeviceToken() async {
    if (userId == null) return;

    try {
      // デバイストークンを取得
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        // Firestoreにトークンを保存
        await UserFirestore.users.doc(userId).update({'fcmToken': fcmToken});
      }
    } catch (e) {
      print('デバイストークンの保存に失敗しました: $e');
    }
  }
}
