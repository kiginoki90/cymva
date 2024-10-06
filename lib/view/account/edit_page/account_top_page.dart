import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/follow_service.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:cymva/view/account/follow_page.dart';
import 'package:cymva/view/account/follower_page.dart';
import 'package:cymva/view/admin/admin_page.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_page.dart';
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

  @override
  void initState() {
    super.initState();
    _followCountFuture = _getFollowCount();
    _followerCountFuture = _getFollowerCount();
    _initialize();
  }

  Future<void> _initialize() async {
    await followService.initialize();
    await _getAccount();
    await _checkFollowStatus();
    await _getPostAccount();
    await _getFollowCount();
    await _getFollowerCount();
  }

  Future<void> _checkFollowStatus() async {
    isFollowing = await followService.checkFollowStatus(widget.postAccountId);
    setState(() {});
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
      print('同じparents_idを持つアカウントの取得に失敗しました: $e');
    }
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.postAccountId);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ユーザー情報が取得できませんでした')));
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  TimeLinePage(userId: widget.postAccountId)));
    } else {
      setState(() {
        myAccount = account;
      });
      await _getSiblingAccounts(account.parents_id);
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
    if (myAccount == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          myAccount!.name,
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
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 30),
            if (widget.userId == widget.postAccountId) _buildSiblingAccounts(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.userId != widget.postAccountId)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz),
            onSelected: (String value) {},
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'Option 1',
                  child: Text(
                    'ブロック',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ];
            },
          ),
        if (widget.userId == widget.postAccountId)
          Column(
            children: [
              SizedBox(height: 20),
              SizedBox(
                height: 25,
                width: 110,
                child: OutlinedButton(
                  onPressed: () async {
                    var result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AccountOptionsPage()));
                    if (result == true) {
                      setState(() {
                        myAccount = Authentication.myAccount!;
                      });
                    }
                  },
                  child: const Text('編集'),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 25,
                width: 110,
                child: TextButton(
                  onPressed: () async {
                    var result = await Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AdminPage()));
                  },
                  child: const Text(''),
                ),
              ),
            ],
          ),
      ],
    );
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
              showFollowDialog();
            } else {
              toggleFollowStatus();
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
                    builder: (context) =>
                        AccountPage(postUserId: myAccount!.id)),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                myAccount!.imagePath,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                myAccount!.name,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '@${myAccount!.userId}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
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

  Widget _buildSelfIntroduction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        myAccount!.selfIntroduction.isNotEmpty
            ? myAccount!.selfIntroduction
            : '自己紹介は設定されていません',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildSiblingAccounts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: siblingAccounts.map((sibling) {
        return GestureDetector(
          onTap: () async {
            await onAccountChanged(sibling); // アカウント切り替え処理を追加
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(sibling.imagePath),
              radius: 20, // アイコンのサイズ
            ),
          ),
        );
      }).toList(),
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
