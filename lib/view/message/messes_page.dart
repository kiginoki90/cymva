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
        .collection('messages')
        .get();

    // 取得したデータをリストに格納
    final List<Map<String, dynamic>> tempNotifications =
        snapshot.docs.map((doc) {
      return {
        'request_user': doc['request_user'],
        'message_type': doc['message_type'],
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

      // followersサブコレクションにrequestUserを追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .doc(requestUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});

      // 相手のユーザーのmessagesサブコレクションにメッセージを追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requestUserId)
          .collection('messages')
          .add({
        'message_type': 2,
        'request_user': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('通知')),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final requestUserId = notification['request_user'];
          final user = notification['user'];

          return Column(
            children: [
              if (notification['message_type'] == 1)
                ListTile(
                  title: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AccountPage(postUserId: requestUserId),
                        ),
                      );
                    },
                    child: Text('@${user.userId}さんからフォロー依頼が届いています'),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () => _acceptFollowRequest(requestUserId),
                      child: Text('許可'),
                    ),
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
