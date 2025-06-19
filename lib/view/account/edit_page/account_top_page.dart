import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/follow_service.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:cymva/view/account/follow_page.dart';
import 'package:cymva/view/account/follower_page.dart';
import 'package:cymva/view/admin/admin_page.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/show_account_report_dialog.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/model/account.dart';
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
  final FollowService followService = FollowService(FirebaseFirestore.instance);
  bool isFollowed = false;
  String? backgroundImageUrl;
  bool isProcessing = false; // 処理中フラグを追加

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
    if (isProcessing) return; // 処理中の場合は何もしない
    setState(() {
      isProcessing = true; // 処理開始
    });

    try {
      isFollowing = await followService.checkFollowStatus(widget.postAccountId);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('フォロー状態の確認中にエラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false; // 処理終了
        });
      }
    }
  }

  Future<void> _fetchBackgroundImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final imageUrl = data?['background_image'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
          setState(() {
            backgroundImageUrl = imageUrl;
          });
        }
      }
    } catch (e) {
      print('背景画像の取得中にエラーが発生しました: $e');
    }
  }

  Future<void> _getPostAccount() async {
    try {
      final postUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postAccountId)
          .get();

      if (postUserSnapshot.exists && mounted) {
        setState(() {
          postAccount = Account.fromDocument(postUserSnapshot);
        });
      }
    } catch (e) {
      print('投稿アカウントの取得中にエラーが発生しました: $e');
    }
  }

  Future<void> _getAccount() async {
    try {
      final Account? account = await UserFirestore.getUser(widget.userId);
      if (account == null) {
        if (mounted) {
          showTopSnackBar(context, 'ユーザー情報が取得できませんでした',
              backgroundColor: Colors.red);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => TimeLinePage(userId: widget.userId)),
          );
        }
      } else if (mounted) {
        setState(() {
          myAccount = account;
        });
        await _getSiblingAccounts(account.parents_id);
      }
    } catch (e) {
      print('アカウント情報の取得中にエラーが発生しました: $e');
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
          .doc(widget.postAccountId)
          .collection('follow')
          .doc(widget.userId)
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
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('follow')
        .where('user_id', isEqualTo: widget.postAccountId)
        .get();
    return querySnapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    if (postAccount == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        leading: isProcessing
            ? null // 処理中の場合は無効化
            : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
        title: Text(
          postAccount!.name,
          style: TextStyle(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Stack(
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
        Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.userId != widget.postAccountId)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz),
                onSelected: isProcessing
                    ? null // 処理中の場合は無効化
                    : (String value) {
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
                                      try {
                                        // Firestore インスタンス
                                        final firestore =
                                            FirebaseFirestore.instance;

                                        // 現在のユーザーとブロック対象のユーザーID
                                        final currentUserId = widget.userId;
                                        final blockedUserId =
                                            widget.postAccountId;

                                        // 自分の block サブコレクションの参照
                                        final blockCollectionRef = firestore
                                            .collection('users')
                                            .doc(currentUserId)
                                            .collection('block');

                                        // すでに blocked_user_id が存在するかチェック
                                        final existingBlocks =
                                            await blockCollectionRef
                                                .where('blocked_user_id',
                                                    isEqualTo: blockedUserId)
                                                .get();

                                        // ブロック対象がすでに存在する場合は処理を終了
                                        if (existingBlocks.docs.isNotEmpty) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text('すでにブロックされています')),
                                          );
                                          return;
                                        }

                                        // 自分の block サブコレクションにブロック情報を追加
                                        await blockCollectionRef.add({
                                          'blocked_user_id': blockedUserId,
                                          'parents_id': postAccount?.parents_id,
                                          'blocked_at': Timestamp.now(),
                                        });

                                        // ブロック対象ユーザーの blockUsers サブコレクションにブロック情報を追加
                                        final blockedUserBlockCollectionRef =
                                            firestore
                                                .collection('users')
                                                .doc(blockedUserId)
                                                .collection('blockUsers');

                                        await blockedUserBlockCollectionRef
                                            .add({
                                          'blocked_user_id': currentUserId,
                                          'parents_id': myAccount?.parents_id,
                                          'blocked_at': Timestamp.now(),
                                        });

                                        // 成功メッセージを表示
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('アカウントをブロックしました')),
                                        );
                                      } catch (e) {
                                        // エラーメッセージを表示
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('ブロックに失敗しました: $e')),
                                        );
                                      } finally {
                                        Navigator.pop(context); // ポップアップを閉じる
                                      }
                                    },
                                  ),
                                  TextButton(
                                    child: Text('解除'),
                                    onPressed: () async {
                                      try {
                                        // Firestore インスタンス
                                        final firestore =
                                            FirebaseFirestore.instance;
                                        final currentUserId = widget.userId;
                                        final blockedUserId =
                                            widget.postAccountId;

                                        // 自分の block サブコレクションの参照
                                        final blockCollectionRef = firestore
                                            .collection('users')
                                            .doc(currentUserId)
                                            .collection('block');

                                        // 一致するドキュメントを探す
                                        final querySnapshot =
                                            await blockCollectionRef
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
                                        final blockedUserBlockCollectionRef =
                                            firestore
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
                                        if (blockedUserQuerySnapshot
                                            .docs.isNotEmpty) {
                                          for (var doc
                                              in blockedUserQuerySnapshot
                                                  .docs) {
                                            await blockedUserBlockCollectionRef
                                                .doc(doc.id)
                                                .delete();
                                          }
                                        }

                                        // 成功メッセージを表示
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('ブロックを解除しました')),
                                        );
                                      } catch (e) {
                                        // エラーメッセージを表示
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('解除に失敗しました: $e')),
                                        );
                                      } finally {
                                        Navigator.pop(context); // ポップアップを閉じる
                                      }
                                    },
                                  ),
                                  TextButton(
                                    child: Text('キャンセル'),
                                    onPressed: () {
                                      Navigator.pop(context);
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
                        onPressed: isProcessing
                            ? null // 処理中の場合は無効化
                            : () async {
                                setState(() {
                                  isProcessing = true; // 処理開始
                                });
                                try {
                                  var result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AccountOptionsPage(
                                          loginUserId: widget.userId),
                                    ),
                                  );
                                } catch (e) {
                                  print('エラーが発生しました: $e');
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      isProcessing = false; // 処理終了
                                    });
                                  }
                                }
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

  String _formatText(String text, int chunkSize) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i += chunkSize) {
      if (i + chunkSize < text.length) {
        buffer.writeln(text.substring(i, i + chunkSize));
      } else {
        buffer.write(text.substring(i));
      }
    }
    return buffer.toString();
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
          onTap: isProcessing
              ? null // 処理中の場合は何もしない
              : () {
                  if (postAccount?.lockAccount ?? false) {
                    if (isFollowing) {
                      showUnfollowDialog();
                    } else {
                      showFollowDialog();
                    }
                  } else {
                    toggleFollowStatus();
                  }
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
                SlideDirectionPageRoute(
                  page: FullScreenImagePage(
                    imageUrls: [postAccount!.imagePath],
                    initialIndex: 0,
                  ),
                  isSwipeUp: true,
                ),
              );
            },
            child: Hero(
              tag: postAccount!.imagePath, // ユニークなタグを設定
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
                    onTap: isProcessing
                        ? null // 処理中の場合は無効化
                        : () {
                            setState(() {
                              isProcessing = true; // 処理開始
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FollowPage(userId: widget.postAccountId),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() {
                                  isProcessing = false; // 処理終了
                                });
                              }
                            });
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
                    onTap: isProcessing
                        ? null // 処理中の場合は無効化
                        : () {
                            setState(() {
                              isProcessing = true; // 処理開始
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FollowerPage(userId: widget.postAccountId),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() {
                                  isProcessing = false; // 処理終了
                                });
                              }
                            });
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
                _formatText(postAccount!.name, 20),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          SelectableText(
            _formatText('@${postAccount!.userId}', 20),
            style: const TextStyle(fontSize: 15, color: Colors.grey),
            textAlign: TextAlign.center,
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
        textSize: 13,
        tapable: true,
      ),
    );
  }

  Widget _buildSiblingAccounts() {
    if (siblingAccounts.length <= 1) {
      return const SizedBox.shrink(); // 空のウィジェットを返す
    }
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
    // if (isProcessing) return; // 処理中の場合は何もしない
    // setState(() {
    //   isProcessing = true; // 処理開始
    // });

    try {
      await followService.toggleFollowStatus(widget.postAccountId);
      await _checkFollowStatus();
    } catch (e) {
      print('フォロー状態の切り替え中にエラーが発生しました: $e');
    }
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
                    context, widget.postAccountId, myAccount!);
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AccountPage(
            postUserId: newAccount.id,
            withDelay: false,
          ),
        ),
      );
    } catch (e) {
      print('アカウント切り替えに失敗しました: $e');
    }
  }
}
