import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/message/messes_page.dart';
import 'package:cymva/view/post_page/post_page.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

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
  bool showChatIcon = true;
  late StreamSubscription<DocumentSnapshot> _tokenSubscription;
  Timestamp? lastPasswordChangeToken;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndAdminStatus();
    _loadNotifications();
  }

  Future<void> _loadUserIdAndAdminStatus() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      // Firestoreからadminレベルを取得し、4ならチャットアイコンを非表示に設定
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      setState(() {
        showChatIcon = (userDoc['admin'] ?? 0) < 4;
        pageList = [
          TimeLineBody(userId: userId!),
          AccountPage(postUserId: userId!),
          SearchPage(userId: userId!),
          MessesPage(userId: userId!),
          if (showChatIcon) PostPage(userId: userId!),
        ];
      });

      // パスワード変更トークンを監視する
      _tokenSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((userSnapshot) async {
        if (userSnapshot.exists) {
          final userData = userSnapshot.data();
          final parentsId = userData?['parents_id'];

          if (parentsId != null) {
            // parents_idのドキュメントを取得し、パスワード変更トークンを監視
            final parentSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(parentsId)
                .get();

            final currentToken =
                parentSnapshot['passwordChangeToken'] as Timestamp?;

            // ローカルストレージから前回のトークンを取得
            final lastTokenString =
                await storage.read(key: 'passwordChangeToken');

            // lastTokenStringがnullまたは空の場合はnullとして扱う
            final lastToken = (lastTokenString != null &&
                    lastTokenString != "null" &&
                    lastTokenString.isNotEmpty)
                ? Timestamp.fromMillisecondsSinceEpoch(
                    int.parse(lastTokenString))
                : null;

            // Firestoreのトークンとローカルストレージのトークンを比較
            if (currentToken != null &&
                (lastTokenString == null ||
                    currentToken.millisecondsSinceEpoch.toString() !=
                        lastTokenString)) {
              // ローカルストレージに新しいトークンを保存
              await storage.write(
                key: 'passwordChangeToken',
                value: currentToken.millisecondsSinceEpoch.toString(),
              );

              final newTokenString =
                  await storage.read(key: 'passwordChangeToken');

              if (newTokenString != null &&
                  newTokenString ==
                      currentToken.millisecondsSinceEpoch.toString()) {
                print('トークンが正しく保存されました: $newTokenString');
              } else {
                print('トークンの保存に失敗しました');
              }
              // ログアウト処理を呼び出す
              _logoutIfPasswordChanged();
            } else if (lastToken == null) {
              // lastTokenがnullの場合に直接ログアウト処理を実行
              _logoutIfPasswordChanged();
            }
          } else {
            print('parents_idが存在しません');
          }
        }
      });
    }
  }

  Future<void> _logoutIfPasswordChanged() async {
    // ログアウト処理を実装
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // ウィジェットがマウントされている場合のみ Navigator を使用
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Future<void> _loadNotifications() async {
    final firestore = FirebaseFirestore.instance;
    String? userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('message')
          .get();

      notifications.clear();

      for (var doc in messageSnapshot.docs) {
        final isRead = doc['isRead'] ?? true;
        notifications.add({'isRead': isRead});
      }

      setState(() {});
    }
  }

  Future<void> _markNotificationsAsRead() async {
    final firestore = FirebaseFirestore.instance;

    if (userId != null) {
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('message')
          .get();

      for (var doc in messageSnapshot.docs) {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('message')
            .doc(doc.id)
            .update({'isRead': true});
      }

      notifications = List.generate(
          messageSnapshot.docs.length, (index) => {'isRead': true});

      setState(() {});
    }
  }

  void _handleItemTapped(int index) async {
    if (index == 3) {
      await _markNotificationsAsRead();
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
      return Center(child: CircularProgressIndicator());
    }

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
                      '',
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
        if (showChatIcon)
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '',
          ),
      ],
      currentIndex: widget.selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: _handleItemTapped,
    );
  }

  bool _hasUnreadNotifications() {
    return notifications.any((notification) => notification['isRead'] == false);
  }
}
