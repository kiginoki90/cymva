import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
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
import 'package:flutter/services.dart';

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
    this.rebuildNavigation = true,
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
  List<GlobalKey<NavigatorState>> pageKeys = [];

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

  Future<void> _initializePageList(bool myAccount) async {
    // 非同期処理でユーザーIDを取得
    var myUserId = await storage.read(key: 'account_id');

    // 非同期処理が完了した後にUIを更新
    setState(() {
      pageKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

      if (myAccount) {
        pageList = [
          Navigator(
            key: pageKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) =>
                  TimeLineBody(userId: userId!, fromLogin: widget.fromLogin),
            ),
          ),
          Navigator(
            key: pageKeys[1],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => AccountPage(
                postUserId: myUserId!, // 修正: myUserId を使用
                withDelay: widget.withDelay,
              ),
            ),
          ),
          Navigator(
            key: pageKeys[2],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => SearchPage(
                  userId: userId!, notdDleteStotage: widget.notDleteStotage),
            ),
          ),
          Navigator(
            key: pageKeys[3],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => MessesPage(userId: userId!),
            ),
          ),
          // if (showChatIcon)
          //   Navigator(
          //     key: pageKeys[4],
          //     onGenerateRoute: (_) => MaterialPageRoute(
          //       builder: (context) => PostPage(),
          //     ),
          //   ),
        ];
      } else {
        pageList = [
          Navigator(
            key: pageKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) =>
                  TimeLineBody(userId: userId!, fromLogin: widget.fromLogin),
            ),
          ),
          Navigator(
            key: pageKeys[1],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => AccountPage(
                postUserId: widget.userId,
                withDelay: widget.withDelay,
              ),
            ),
          ),
          Navigator(
            key: pageKeys[2],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => SearchPage(
                  userId: userId!, notdDleteStotage: widget.notDleteStotage),
            ),
          ),
          Navigator(
            key: pageKeys[3],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => MessesPage(userId: userId!),
            ),
          ),
          // if (showChatIcon)
          //   Navigator(
          //     key: pageKeys[4],
          //     onGenerateRoute: (_) => MaterialPageRoute(
          //       builder: (context) => PostPage(),
          //     ),
          //   ),
        ];
      }
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
      canPop: false, // 戻るボタンのデフォルト動作を無効化
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // Navigatorスタックが空でない場合は戻る動作を実行
        if (pageKeys[selectedIndex].currentState?.canPop() == true) {
          pageKeys[selectedIndex].currentState?.pop();
        } else {
          // Navigatorスタックが空の場合はホームタブに戻る
          if (selectedIndex != 0) {
            setState(() {
              selectedIndex = 0;
            });
          } else {
            // ホームタブにいる場合はアプリを終了
            print("Exiting the app.");
            SystemNavigator.pop(); // アプリを終了
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: selectedIndex,
          children: pageList,
        ),
        bottomNavigationBar: _shouldShowNavigationBar()
            ? BottomNavigationBar(
                items: [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined), label: 'ホーム'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.perm_identity_outlined), label: 'アカウント'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.search), label: '検索'),
                  BottomNavigationBarItem(
                    icon: StreamBuilder<bool>(
                      stream: _hasUnreadNotificationsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data == true) {
                          return Stack(
                            children: [
                              const Icon(Icons.notifications),
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
                          );
                        } else {
                          return const Icon(Icons.notifications); // 通知アイコンのみ表示
                        }
                      },
                    ),
                    label: 'メッセージ',
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: selectedIndex == 4
                            ? Colors.blue
                            : Colors.transparent, // 塗りつぶし
                        borderRadius: BorderRadius.circular(8), // 角丸
                      ),
                      padding: const EdgeInsets.all(8), // アイコン周りの余白
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: selectedIndex == 4
                            ? Colors.white
                            : Colors.grey, // アイコンの色
                      ),
                    ),
                    label: '投稿',
                  ),
                ],
                currentIndex: selectedIndex,
                selectedItemColor: Colors.blue, // 選択されたアイテムの色
                unselectedItemColor: Colors.grey, // 選択されていないアイテムの色
                onTap: (index) async {
                  String? myUserId = await storage.read(key: 'account_id');
                  if (index == 4) {
                    // Firestoreからユーザー情報を取得
                    final userDocSnapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(myUserId)
                        .get();

                    if (userDocSnapshot.exists) {
                      final userDoc = userDocSnapshot.data();

                      if (userDoc != null &&
                          (userDoc['admin'] == 4 || userDoc['admin'] == 5)) {
                        showTopSnackBar(context, '投稿機能が制限されています',
                            backgroundColor: Colors.red);
                        return;
                      }
                    }
                    _showPostPage();
                  }

                  if (myUserId != userId && index != 4) {
                    navigateToPage(context, myUserId!, index.toString(), false);
                    if (index == 3) {
                      _markNotificationsAsRead();
                    }
                  } else {
                    if (selectedIndex != index) {
                      // indexが1の場合のみ画面遷移
                      if (index == 1) {
                        // myUserId が null の場合は userId を使用
                        String targetUserId = myUserId ?? userId!;

                        navigateToPage(context, targetUserId, '1', false);
                      } else if (index != 4) {
                        setState(() {
                          selectedIndex = index;
                        });
                        if (index == 3) {
                          _markNotificationsAsRead();
                        }
                      }
                    } else {
                      if (index != 1) {
                        if (index == 3) {
                          _markNotificationsAsRead();
                        }

                        // 現在のページをリセットする場合
                        if (pageKeys[index].currentState?.canPop() ?? false) {
                          pageKeys[index]
                              .currentState
                              ?.pop(); // 現在のタブのNavigatorスタックを操作
                        } else {
                          navigateToPage(
                              context, myUserId!, index.toString(), false);
                        }
                      } else {
                        String? myUserId =
                            await storage.read(key: 'account_id');

                        // myUserId が null の場合は userId を使用
                        String targetUserId = myUserId ?? userId!;
                        navigateToPage(context, targetUserId, '1', false);
                      }
                    }
                  }
                },
              )
            : null, // ナビゲーションバーを非表示
      ),
    );
  }

  /// ナビゲーションバーを表示するかどうかを判定
  bool _shouldShowNavigationBar() {
    // FullScreenImagePageに遷移中の場合はナビゲーションバーを非表示
    return ModalRoute.of(context)?.settings.name != 'FullScreenImagePage';
  }

  Stream<bool> _hasUnreadNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('message')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.any((doc) => doc['isRead'] == false);
    });
  }

  //通知を既読にする
  Future<void> _markNotificationsAsRead() async {
    final firestore = FirebaseFirestore.instance;

    if (widget.userId != null) {
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('message')
          .get();

      for (var doc in messageSnapshot.docs) {
        await firestore
            .collection('users')
            .doc(widget.userId)
            .collection('message')
            .doc(doc.id)
            .update({'isRead': true});
      }
    }
  }

  void _showPostPage() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: PostPage(), // ここで投稿成功時に pop(context, true) を返すようにする
        );
      },
    );

    // 投稿の結果に応じてスナックバーを表示
    if (result == true) {
      showTopSnackBar(context, '投稿が完了しました', backgroundColor: Colors.green);
    } else if (result == false) {
      showTopSnackBar(context, '投稿に失敗しました', backgroundColor: Colors.red);
    }
  }
}
