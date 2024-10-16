import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessesPage extends StatefulWidget {
  final String userId;

  const MessesPage({super.key, required this.userId});

  @override
  State<MessesPage> createState() => _MessesPageState();
}

class _MessesPageState extends State<MessesPage> {
  List<Map<String, dynamic>> notifications = [];
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final firestore = FirebaseFirestore.instance;

    // 現在のユーザーのIDを取得
    final snapshot = await firestore
        .collection('users')
        .doc(widget.userId)
        .collection('message')
        .get();

    // 取得したデータをリストに格納
    final List<Map<String, dynamic>> tempNotifications =
        snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'request_user': doc['request_user'],
        'message_type': doc['message_type'],
        'request_userId': doc.data().containsKey('request_userId')
            ? doc['request_userId']
            : null,
      };
    }).toList();

    // 非同期でユーザー情報を取得
    for (var notification in tempNotifications) {
      final userId = notification['request_user'];
      final user = await UserFirestore.getUser(userId); // 非同期でユーザー情報を取得
      notification['user'] = user; // ユーザー情報を通知に追加
    }

    setState(() {
      notifications = tempNotifications;
    });
  }

  // フォロー依頼を許可する処理
  Future<void> _acceptFollowRequest(String requestUserId) async {
    try {
      final currentUserId = await storage.read(key: 'account_id');

      // フォロー依頼を許可した際に、相手のメッセージを削除
      final messageQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('message')
          .where('request_user', isEqualTo: requestUserId)
          .where('message_type', isEqualTo: 1)
          .get();

      // 該当するメッセージを削除
      for (var doc in messageQuerySnapshot.docs) {
        await doc.reference.delete();
      }

      // 自分のアカウントのフォロワーに相手を追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .doc(requestUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});

      // 相手のアカウントのフォローに自分を追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requestUserId)
          .collection('follow')
          .doc(currentUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});

      // 相手のユーザーのmessagesサブコレクションにメッセージを追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requestUserId)
          .collection('message')
          .add({
        'message_type': 2,
        'request_user': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _updateFollowRequests();

      // 成功メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('フォロリクエストを許可しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('フォロリクエストの許可に失敗しました')),
      );
      print(e);
    }
  }

  Future<void> _updateFollowRequests() async {
    await _fetchNotifications(); // 通知を再取得して更新
  }

  Future<void> _showDeleteConfirmationDialog(
      String requestUserId, String messageId) async {
    final currentUserId = await storage.read(key: 'account_id');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('確認'),
          content: Text('このメッセージを削除しますか？'),
          actions: [
            TextButton(
              child: Text('いいえ'),
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
            ),
            TextButton(
              child: Text('はい'),
              onPressed: () async {
                // Firestore からメッセージを削除する処理
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('message')
                    .doc(messageId) // 削除するメッセージのID
                    .delete();

                // ダイアログを閉じる
                Navigator.of(context).pop();

                // 削除成功メッセージ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('メッセージが削除されました')),
                );

                await _updateFollowRequests();

                // 通知リストの更新
                setState(() {
                  notifications.removeWhere((notification) =>
                      notification['message_id'] == messageId);
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('通知')),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final requestUser = notification['request_user'];
          final user = notification['user'];
          final requestUserId = notification['request_userId'];

          return Column(
            children: [
              if (notification['message_type'] == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 5.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AccountPage(postUserId: requestUser),
                              ),
                            );
                          },
                          child: Text(
                            '@${requestUserId}さんからフォロー依頼が届いています',
                            maxLines: 3, // 最大3行
                            overflow: TextOverflow.ellipsis, // 3行を超えたら省略表示
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _showDeleteConfirmationDialog(
                                    requestUser, notification['id']);
                              },
                              child: Text(
                                '削除',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8), // ボタン間のスペースを追加
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  _acceptFollowRequest(requestUser),
                              child: Text(
                                '許可',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (notification['message_type'] == 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '@${user.userId}さんへのフォローリクエストが許可されました。',
                    // style: TextStyle(color: Colors.green),
                  ),
                ),
              Divider(),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 3),
    );
  }
}
