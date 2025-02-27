import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/follow_service.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:cymva/view/account/follow_page.dart';
import 'package:cymva/view/account/follower_page.dart';
import 'package:cymva/view/admin/admin_page.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/show_account_report_dialog.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// アカウント詳細ページ
class AccountTopPage extends StatefulWidget {
  final String postAccountId;
  final String userId;
  final storage = FlutterSecureStorage();

  AccountTopPage({Key? key, required this.postAccountId, required this.userId})
      : super(key: key);

  @override
  State<AccountTopPage> createState() => _AccountTopPageState();
}

class _AccountTopPageState extends State<AccountTopPage> {
  Account? myAccount;
  int currentPage = 0;
  bool isFollowing = false;
  late Future<int> _followCountFuture;
  late Future<int> _followerCountFuture;
  double previousScrollOffset = 0.0;
  List<Account> siblingAccounts = [];
  Account? postAccount;
  final FollowService followService = FollowService();
  bool isFollowed = false;
  String? backgroundImageUrl;

  @override
  void initState() {
    super.initState();
    _followCountFuture = _getFollowCount();
    _followerCountFuture = _getFollowerCount();
    _fetchBackgroundImage();
    _initialize();
  }

  Future<void> _initialize() async {
    await followService.initialize();
    await _getAccount();
    await _checkFollowStatus();
    await _getPostAccount();
    await _getFollowCount();
    await _getFollowerCount();
    fetchFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    isFollowing = await followService.checkFollowStatus(widget.postAccountId);
    setState(() {});
  }

  Future<void> _fetchBackgroundImage() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      final imageUrl = data?['background_image'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        setState(() {
          backgroundImageUrl = imageUrl;
        });
      }
    }
  }

  Future<void> _getPostAccount() async {
    final postUserSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postAccountId)
        .get();

    if (postUserSnapshot.exists) {
      setState(() {
        postAccount = Account.fromDocument(postUserSnapshot);
      });
    }
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.userId);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ユーザー情報が取得できませんでした')));
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => TimeLinePage(userId: widget.userId)));
    } else {
      setState(() {
        myAccount = account;
      });
      await _getSiblingAccounts(account.parents_id);
    }
  }

  Future<void> _getSiblingAccounts(String parentsId) async {
    try {
      QuerySnapshot querySnapshot = await UserFirestore.users
          .where('parents_id', isEqualTo: parentsId)
          .get();

      List<Account> accounts = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Account(
          id: doc.id,
          name: data['name'],
          userId: data['user_id'],
          selfIntroduction: data['self_introduction'] ?? '',
          imagePath: data['image_path'] ?? '',
          parents_id: data['parents_id'],
          lockAccount: data['lock_account'] ?? '',
        );
      }).toList();

      setState(() {
        siblingAccounts = accounts;
      });
    } catch (e) {
      print('アカウントの取得に失敗しました: $e');
    }
  }

  Future<void> fetchFollowStatus() async {
    try {
      // followersサブコレクション内にpostAccountIdがあるかをチェック
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(widget.postAccountId)
          .get();

      // ドキュメントが存在する場合のみフォローされていますと表示
      if (doc.exists) {
        setState(() {
          isFollowed = true;
        });
      }
    } catch (e) {
      print("エラーが発生しました: $e");
    }
  }

  Future<int> _getFollowCount() async {
    final followCollection =
        UserFirestore.users.doc(widget.postAccountId).collection('follow');
    final followDocs = await followCollection.get();
    return followDocs.size;
  }

  Future<int> _getFollowerCount() async {
    final followersCollection =
        UserFirestore.users.doc(widget.postAccountId).collection('followers');
    final followerDocs = await followersCollection.get();
    return followerDocs.size;
  }

  @override
  Widget build(BuildContext context) {
    if (postAccount == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          postAccount!.name,
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo is ScrollUpdateNotification) {
            if (scrollInfo.metrics.pixels > previousScrollOffset) {
              // スクロールが下方向に進んだ場合
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AccountPage(postUserId: widget.userId)),
              );
            }
            previousScrollOffset = scrollInfo.metrics.pixels; // スクロール位置を更新
          }
          return true;
        },
        child: Stack(
          children: [
            if (backgroundImageUrl != null)
              Positioned.fill(
                child: Image.network(
                  backgroundImageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            Column(
              children: [
                _buildHeader(),
                SizedBox(height: 30),
                if (widget.userId == widget.postAccountId)
                  _buildSiblingAccounts(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(right: 15, left: 15),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildAccountOptions(),
              ),
              if (widget.userId != widget.postAccountId)
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildFollowButton(),
                ),
              if (isFollowed)
                Text(
                  'フォローされています',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              _buildAccountDetails(),
              SizedBox(height: 10),
              _buildSelfIntroduction(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (myAccount?.admin == 1)
          SizedBox(
            height: 25,
            width: 110,
            child: TextButton(
              onPressed: () async {
                // Show logout confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('ログアウト'),
                      content: Text('このアカウントからすべてのユーザーをログアウトしますか？'),
                      actions: [
                        TextButton(
                          child: Text('キャンセル'),
                          onPressed: () {
                            Navigator.pop(context); // Close the dialog
                          },
                        ),
                        TextButton(
                          child: Text('ログアウト'),
                          onPressed: () async {
                            // Call your logout method here
                            await _logoutOtherUsers(widget.postAccountId);
                            Navigator.pop(context); // Close the dialog
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text(''),
            ),
          ),
        Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.userId != widget.postAccountId)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz),
                onSelected: (String value) {
                  if (value == '1') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShowAccountReportDialog(
                            accountId: widget.postAccountId),
                      ),
                    );
                  } else if (value == '2') {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('アカウントをブロック'),
                          content: Text('次の操作を選択してください'),
                          actions: [
                            TextButton(
                              child: Text('ブロック'),
                              onPressed: () async {
                                // Firestore インスタンス
                                final firestore = FirebaseFirestore.instance;

                                // 現在のユーザーとブロック対象のユーザーID
                                final currentUserId = widget.userId;
                                final blockedUserId = widget.postAccountId;

                                // 自分の block サブコレクションの参照
                                final blockCollectionRef = firestore
                                    .collection('users')
                                    .doc(currentUserId)
                                    .collection('block');

                                // すでに blocked_user_id が存在するかチェック
                                final existingBlocks = await blockCollectionRef
                                    .where('blocked_user_id',
                                        isEqualTo: blockedUserId)
                                    .get();

                                // ブロック対象がすでに存在する場合は処理を終了
                                if (existingBlocks.docs.isNotEmpty) {
                                  // すでにブロックしている場合はポップアップを閉じる
                                  Navigator.pop(context);
                                  return;
                                }

                                // 自分の block サブコレクションにブロック情報を追加
                                await blockCollectionRef.add({
                                  'blocked_user_id': blockedUserId,
                                  'parents_id': postAccount?.parents_id,
                                  'blocked_at': Timestamp.now(),
                                });

                                // ブロック対象ユーザーの blockUsers サブコレクションにブロック情報を追加
                                final blockedUserBlockCollectionRef = firestore
                                    .collection('users')
                                    .doc(blockedUserId)
                                    .collection('blockUsers');

                                await blockedUserBlockCollectionRef.add({
                                  'blocked_user_id': currentUserId,
                                  'parents_id': myAccount?.parents_id,
                                  'blocked_at': Timestamp.now(),
                                });

                                // ポップアップを閉じる
                                Navigator.pop(context);
                              },
                            ),
                            TextButton(
                              child: Text('解除'),
                              onPressed: () async {
                                // 解除処理
                                final firestore = FirebaseFirestore.instance;
                                final currentUserId = widget.userId;
                                final blockedUserId = widget.postAccountId;

                                // 自分の block サブコレクションの参照
                                final blockCollectionRef = firestore
                                    .collection('users')
                                    .doc(currentUserId)
                                    .collection('block');

                                // 一致するドキュメントを探す
                                final querySnapshot = await blockCollectionRef
                                    .where('blocked_user_id',
                                        isEqualTo: blockedUserId)
                                    .get();

                                // 一致するドキュメントが見つかった場合、削除する
                                if (querySnapshot.docs.isNotEmpty) {
                                  for (var doc in querySnapshot.docs) {
                                    await blockCollectionRef
                                        .doc(doc.id)
                                        .delete();
                                  }
                                }

                                // ブロックされたユーザーの blockUsers サブコレクションの参照
                                final blockedUserBlockCollectionRef = firestore
                                    .collection('users')
                                    .doc(blockedUserId)
                                    .collection('blockUsers');

                                // 一致するドキュメントを探す
                                final blockedUserQuerySnapshot =
                                    await blockedUserBlockCollectionRef
                                        .where('blocked_user_id',
                                            isEqualTo: currentUserId)
                                        .get();

                                // 一致するドキュメントが見つかった場合、削除する
                                if (blockedUserQuerySnapshot.docs.isNotEmpty) {
                                  for (var doc
                                      in blockedUserQuerySnapshot.docs) {
                                    await blockedUserBlockCollectionRef
                                        .doc(doc.id)
                                        .delete();
                                  }
                                }

                                Navigator.pop(context); // ポップアップを閉じる
                              },
                            ),
                            TextButton(
                              child: Text('キャンセル'),
                              onPressed: () {
                                Navigator.pop(context); // ポップアップを閉じる
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem<String>(
                      value: '1',
                      child: Text('通報'),
                    ),
                    const PopupMenuItem<String>(
                      value: '2',
                      child: Text('ブロック'),
                    ),
                  ];
                },
              ),
            if (widget.userId == widget.postAccountId)
              Column(
                children: [
                  SizedBox(height: 20),
                  if (postAccount!.admin != 5)
                    SizedBox(
                      height: 25,
                      width: 110,
                      child: OutlinedButton(
                        onPressed: () async {
                          var result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AccountOptionsPage()));
                          // if (result == true) {
                          //   setState(() {
                          //     myAccount = Authentication.myAccount!;
                          //   });
                          // }
                        },
                        child: const Icon(Icons.settings),
                      ),
                    ),
                  SizedBox(height: 20),
                  if (myAccount?.admin == 1)
                    SizedBox(
                      height: 25,
                      width: 110,
                      child: GestureDetector(
                        onDoubleTap: () async {
                          var result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AdminPage()),
                          );
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _logoutOtherUsers(String accountId) async {
    final firestore = FirebaseFirestore.instance;

    final sessionsSnapshot = await firestore
        .collection('sessions')
        .where('accountId', isEqualTo: accountId)
        .get();

    for (var sessionDoc in sessionsSnapshot.docs) {
      await sessionDoc.reference.update({'isLoggedIn': false});
    }
  }

  Widget _buildFollowButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: isFollowing ? Colors.blue : Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: GestureDetector(
          onTap: () {
            // lock_accountがtrueの場合はポップアップを出す
            if (postAccount?.lockAccount ?? false) {
              if (isFollowing) {
                showUnfollowDialog();
              } else {
                showFollowDialog();
              }
            } else {
              toggleFollowStatus();
            }
            // タップした感覚を提供
            HapticFeedback.lightImpact();
          },
          child: Text(
            isFollowing ? 'フォロー中' : 'フォロー',
            style: TextStyle(
              color: isFollowing ? Colors.blue : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDetails() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImagePage(
                      imageUrls: postAccount?.imagePath != null
                          ? [postAccount!.imagePath]
                          : [],
                      initialIndex: 0,
                    ),
                  ));
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: postAccount!.admin >= 4
                      ? Colors.grey
                      : Colors.transparent,
                  width: postAccount!.admin >= 4 ? 4.0 : 0.0,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Image.network(
                postAccount!.imagePath ??
                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 画像の取得に失敗した場合のエラービルダー
                  return Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          _buildAccountInfo() ?? Container(),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FutureBuilder<int>(
                future: _followCountFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FollowPage(userId: widget.postAccountId),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'フォロー: ${snapshot.data ?? 0}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(width: 20),
              FutureBuilder<int>(
                future: _followerCountFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FollowerPage(userId: widget.postAccountId),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'フォロワー: ${snapshot.data ?? 0}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    return GestureDetector(
      onTap: () {
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => DetailedSearchPage(
        //       initialUserId: postAccount!.userId,
        //       movingFlag: true,
        //     ),
        //   ),
        // );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (postAccount!.lockAccount == true)
                const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Icon(
                    Icons.lock,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              SelectableText(
                postAccount!.name,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SelectableText(
            '@${postAccount!.userId}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfIntroduction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LinkText(
        text: postAccount!.selfIntroduction.isNotEmpty
            ? postAccount!.selfIntroduction
            : '',
        userId: followService.userId!,
        textSize: 13,
        tapable: true,
      ),
    );
  }

  Widget _buildSiblingAccounts() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0, // 子ウィジェット間の水平スペース
        runSpacing: 8.0, // 子ウィジェット間の垂直スペース
        alignment: WrapAlignment.center, // 子ウィジェットを中央に配置
        children: siblingAccounts.map((sibling) {
          return GestureDetector(
            onTap: () async {
              await onAccountChanged(sibling); // アカウント切り替え処理を追加
            },
            child: CircleAvatar(
              radius: 20, // アイコンのサイズ
              backgroundColor: Colors.grey, // 背景色を設定（画像が取得できない場合に表示される色）
              child: ClipOval(
                child: Image.network(
                  sibling.imagePath.isNotEmpty
                      ? sibling.imagePath
                      : 'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 画像の取得に失敗した場合のエラービルダー
                    return Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> toggleFollowStatus() async {
    await followService.toggleFollowStatus(widget.postAccountId);
    _checkFollowStatus();
  }

  void showFollowDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('このアカウントは非公開です'),
          content: Text('フォローリクエストを送信しますか？'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await followService.handleFollowRequest(
                    widget.postAccountId, myAccount!);
              },
              child: Text('送信'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  void showUnfollowDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('フォロー解除の確認'),
          content: Text('このアカウントは非公開です。フォロー解除してよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // ダイアログを閉じる
                toggleFollowStatus(); // フォロー解除処理を実行
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  Future<void> onAccountChanged(Account newAccount) async {
    try {
      // 新しいアカウントの情報をセキュアストレージに保存
      await widget.storage.write(key: 'account_id', value: newAccount.id);
      await widget.storage.write(key: 'account_name', value: newAccount.name);

      // 状態を更新して画面をリロード
      setState(() {
        myAccount = newAccount; // 現在のアカウントを切り替え
      });

      print('アカウントが切り替えられました: ${newAccount.name}');

      // 必要に応じて新しいアカウントページに遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AccountPage(postUserId: newAccount.id),
        ),
      );
    } catch (e) {
      print('アカウント切り替えに失敗しました: $e');
    }
  }
}
