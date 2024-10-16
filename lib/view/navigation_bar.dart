import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/message/messes_page.dart';
import 'package:cymva/view/post_page/post_page.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NavigationBarPage extends StatefulWidget {
  final int selectedIndex;

  const NavigationBarPage({
    super.key,
    required this.selectedIndex,
  });

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  List<Widget>? pageList;
  String? userId;
  List<Map<String, dynamic>> notifications = [];
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadNotifications();
  }

  Future<void> _loadUserId() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // userIdが取得できたらpageListを初期化
    setState(() {
      pageList = [
        TimeLineBody(userId: userId!),
        AccountPage(postUserId: userId!),
        SearchPage(userId: userId!),
        MessesPage(userId: userId!),
        PostPage(userId: userId!),
      ];
    });
  }

  Future<void> _loadNotifications() async {
    final firestore = FirebaseFirestore.instance;

    // ユーザーのIDを取得
    String? userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      // Firestoreからmessageサブコレクションを取得
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('message')
          .get();

      // notificationsをリセット
      notifications.clear();

      // メッセージをループしてisReadの値を確認
      for (var doc in messageSnapshot.docs) {
        final isRead = doc['isRead'] ?? true; // デフォルトはtrueとする
        notifications.add({'isRead': isRead});
      }

      // 状態を更新
      setState(() {});
    }
  }

  Future<void> _markNotificationsAsRead() async {
    final firestore = FirebaseFirestore.instance;

    if (userId != null) {
      // Firestoreからmessageサブコレクションを取得
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('message')
          .get();

      // すべてのメッセージのisReadフィールドをtrueに更新
      for (var doc in messageSnapshot.docs) {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('message')
            .doc(doc.id)
            .update({'isRead': true});
      }

      // 既存のnotificationsリストを更新
      notifications = List.generate(
          messageSnapshot.docs.length, (index) => {'isRead': true});

      // 状態を更新
      setState(() {});
    }
  }

  void _handleItemTapped(int index) async {
    if (index == 3) {
      // 通知アイコンがタップされた場合
      await _markNotificationsAsRead(); // isReadを全てtrueに更新
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => pageList![index],
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pageList == null) {
      return Center(child: CircularProgressIndicator()); // ローディング中の表示
    }

    // BottomNavigationBarの前にreturnを追加
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.perm_identity_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined),
              // 未読メッセージがある場合に赤丸を表示
              if (_hasUnreadNotifications())
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '', // テキストは空（赤丸だけ）
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: '',
        ),
      ],
      currentIndex: widget.selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: _handleItemTapped, // タップされたときの処理
    );
  }

  bool _hasUnreadNotifications() {
    // 実際の未読メッセージを判定するロジック
    return notifications.any((notification) => notification['isRead'] == false);
  }
}
