import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:cymva/view/account/edit_page/account_top_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/model/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountHeader extends StatefulWidget {
  final String postUserId;
  final PageController pageController;
  final int value;

  const AccountHeader({
    Key? key,
    required this.postUserId,
    required this.pageController,
    required this.value,
  }) : super(key: key);

  @override
  _AccountHeaderState createState() => _AccountHeaderState();
}

class _AccountHeaderState extends State<AccountHeader> {
  Account? myAccount;
  Account? postAccount;
  int currentPage = 0;
  bool isFollowing = false;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  String? userId;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.pageController.addListener(() {
      setState(() {
        currentPage = widget.pageController.page?.round() ?? 0;
      });
    });
  }

  Future<void> _initialize() async {
    // userIdの取得
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      await _getAccount();
      await _getPostAccount();
      await _checkFollowStatus();
    }
  }

  Future<void> _checkFollowStatus() async {
    // フォロー状態を確認
    final followDoc = await UserFirestore.users
        .doc(userId)
        .collection('follow')
        .doc(widget.postUserId)
        .get();

    setState(() {
      isFollowing = followDoc.exists;
    });
  }

  Future<void> _getAccount() async {
    // ログインしているユーザーのアカウント情報を取得
    myAccount = await UserFirestore.getUser(userId!);
    setState(() {});
  }

  Future<void> _getPostAccount() async {
    // 投稿ユーザーのアカウント情報を取得
    final postUserSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postUserId)
        .get();

    if (postUserSnapshot.exists) {
      setState(() {
        postAccount = Account.fromDocument(postUserSnapshot);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null || postAccount == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 15, left: 15, top: 20),
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountTopPage(
                        postAccountId: postAccount!.id,
                        userId: userId!,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        postAccount!.imagePath,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          postAccount!.name.length > 25
                              ? '${postAccount!.name.substring(0, 25)}...'
                              : postAccount!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '@${postAccount!.userId.length > 25 ? '${postAccount!.userId.substring(0, 25)}...' : postAccount!.userId}',
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildFollowOrEditButton(),
            ],
          ),
        ),
        if (widget.value == 1) _buildNavigationIcons(),
      ],
    );
  }

  Widget _buildFollowOrEditButton() {
    if (userId == widget.postUserId) {
      // 自分のアカウントの場合
      return SizedBox(
        height: 25,
        width: 80,
        child: OutlinedButton(
          onPressed: () async {
            var result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountOptionsPage()),
            );
            if (result == true) {
              setState(() {
                myAccount = Authentication.myAccount!;
              });
            }
          },
          child: const Text('編集'),
        ),
      );
    } else {
      // 他ユーザーの場合
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: isFollowing ? Colors.blue : Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: GestureDetector(
          onTap: () {
            // lock_accountがtrueの場合はポップアップを出す
            if (postAccount?.lockAccount ?? false) {
              _showFollowDialog();
            } else {
              _toggleFollowStatus();
            }
          },
          child: Text(
            isFollowing ? 'フォロー中' : 'フォロー',
            style: TextStyle(
              color: isFollowing ? Colors.blue : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleFollowStatus() async {
    try {
      if (isFollowing) {
        // フォロー解除
        await UserFirestore.users
            .doc(userId)
            .collection('follow')
            .doc(widget.postUserId)
            .delete();
        await UserFirestore.users
            .doc(widget.postUserId)
            .collection('followers')
            .doc(userId)
            .delete();
      } else {
        // フォロー
        await UserFirestore.users
            .doc(userId)
            .collection('follow')
            .doc(widget.postUserId)
            .set({'followed_at': Timestamp.now()});
        await UserFirestore.users
            .doc(widget.postUserId)
            .collection('followers')
            .doc(userId)
            .set({'followed_at': Timestamp.now()});
      }
      setState(() {
        isFollowing = !isFollowing;
      });
    } catch (e) {
      print('フォロー処理に失敗しました: $e');
    }
  }

  Widget _buildNavigationIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIcon(Icons.home, 0),
        _buildIcon(Icons.camera, 1),
        _buildIcon(Icons.star, 2),
      ],
    );
  }

  Widget _buildIcon(IconData iconData, int pageIndex) {
    return IconButton(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            color: currentPage == pageIndex ? Colors.blue : Colors.grey,
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 2,
            width: 60,
            color: currentPage == pageIndex ? Colors.blue : Colors.grey,
          ),
        ],
      ),
      onPressed: () {
        widget.pageController.jumpToPage(pageIndex);
      },
    );
  }

  void _showFollowDialog() {
    // フォロー中かどうかで異なるメッセージを表示
    final String message =
        isFollowing ? 'フォローを解除してもよろしいですか？' : 'ユーザーにフォロー依頼を出しますか？';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isFollowing ? 'フォロー解除' : 'フォロー依頼'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                // キャンセルを押した場合、ダイアログを閉じる
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                // OKを押した場合の処理
                if (isFollowing) {
                  // フォロー解除処理
                  _handleUnfollow();
                } else {
                  // フォロー依頼処理
                  _handleFollowRequest();
                }
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUnfollow() async {
    // フォロー解除処理
    setState(() {
      isFollowing = false;
    });

    // Firestoreでフォロー解除の処理を実装
    // 例: フォローサブコレクションからユーザーを削除する
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('follow')
        .doc(widget.postUserId)
        .delete();
  }

  Future<void> _handleFollowRequest() async {
    // フォロー依頼の処理
    // サブコレクションmessageにフォロー依頼のメッセージを追加
    final CollectionReference messageCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postUserId)
        .collection('message');

    final Timestamp currentTime = Timestamp.now();

    // follow_messageをtrueとしてメッセージを追加
    await messageCollection.add({
      'created_time': currentTime,
      'message_type': 1,
      'request_user': myAccount!.id,
      'request_userId': myAccount!.userId,
    });

    // フォロー状態は変更しない（依頼のみ）
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('フォロー依頼を送りました')),
    );
  }
}
