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
  final String userId;
  final bool showChatIcon;
  final int firstIndex;
  final bool rebuildNavigation;
  final bool myAccount;
  final bool? notDleteStotage;
  final bool? fromLogin;
  final bool? withDelay;

  const NavigationBarPage({
    super.key,
    required this.userId,
    this.showChatIcon = false,
    this.firstIndex = 0,
    this.rebuildNavigation = false,
    this.myAccount = false,
    this.notDleteStotage = false,
    this.fromLogin = false,
    this.withDelay = false,
  });

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  String? userId;
  List<Map<String, dynamic>> notifications = [];
  final FlutterSecureStorage storage = FlutterSecureStorage();
  bool showChatIcon = true;
  late StreamSubscription<DocumentSnapshot> _tokenSubscription;
  Timestamp? lastPasswordChangeToken;
  int selectedIndex = 0;
  List<Widget> pageList = [];

  @override
  void initState() {
    super.initState();
    showChatIcon = widget.showChatIcon;
    selectedIndex = widget.firstIndex;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserIdAndAdminStatus();
    await _loadNotifications();
    if (userId != null) {
      _initializePageList(widget.myAccount);
    }
  }

  void _initializePageList(bool myAccount) {
    setState(() {
      if (myAccount)
        pageList = [
          TimeLineBody(userId: userId!, fromLogin: widget.fromLogin),
          AccountPage(postUserId: userId!, withDelay: widget.withDelay),
          SearchPage(userId: userId!, notdDleteStotage: widget.notDleteStotage),
          MessesPage(userId: userId!),
          if (showChatIcon) PostPage(userId: userId!),
        ];
      else
        pageList = [
          TimeLineBody(userId: userId!, fromLogin: widget.fromLogin),
          AccountPage(postUserId: widget.userId, withDelay: widget.withDelay),
          SearchPage(userId: userId!, notdDleteStotage: widget.notDleteStotage),
          MessesPage(userId: userId!),
          if (showChatIcon) PostPage(userId: userId!),
        ];
    });
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
        if (userDoc.exists) {
          showChatIcon = (userDoc['admin'] ?? 0) < 4;
        } else {
          // userDoc が存在しない場合の処理
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && selectedIndex != 0) {
          setState(() {
            selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: pageList.isNotEmpty
            ? pageList[selectedIndex]
            : const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'ホーム'),
            BottomNavigationBarItem(
                icon: Icon(Icons.perm_identity_outlined), label: 'アカウント'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (_hasUnreadNotifications())
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: const Text(
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
              label: 'メッセージ',
            ),
            if (showChatIcon)
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline), label: '投稿'),
          ],
          currentIndex: selectedIndex,
          selectedItemColor: Colors.blue, // 選択されたアイテムの色
          unselectedItemColor: Colors.grey, // 選択されていないアイテムの色
          onTap: (index) async {
            if (index == 1) {
              // 非同期処理でアカウントIDを取得
              String? myUserId = await storage.read(key: 'account_id') ??
                  FirebaseAuth.instance.currentUser?.uid;

              if (myUserId != null) {
                // navigateToPageを置き換え処理に変更
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        NavigationBarPage(
                      userId: myUserId,
                      showChatIcon: true,
                      firstIndex: 1,
                      withDelay: true,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      // アニメーションを無効化
                      return child;
                    },
                  ),
                );
              } else {
                // 必要に応じてエラーメッセージを表示
                print('アカウントIDが取得できませんでした');
              }
            } else {
              setState(() {
                selectedIndex = index;
              });
              // 通知をロード
              _loadNotifications();
            }
          },
        ),
      ),
    );
  }

  bool _hasUnreadNotifications() {
    return notifications.any((notification) => notification['isRead'] == false);
  }
}
