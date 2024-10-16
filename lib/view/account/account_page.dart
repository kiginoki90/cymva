import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/favorite_list.dart';
import 'package:cymva/view/account/image_post_list.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'post_list.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountPage extends StatefulWidget {
  final String postUserId;

  const AccountPage({Key? key, required this.postUserId}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Account? postAccount;
  late PageController _pageController;
  String? userId;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _getAccount();
    _getUserId();
  }

  Future<void> _getUserId() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;
    setState(() {});
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.postUserId);

    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザー情報が取得できませんでした')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => TimeLinePage(userId: widget.postUserId)),
      );
    } else {
      setState(() {
        postAccount = account;
      });
    }
  }

  Future<Account?> _getMyAccount() async {
    if (userId != null) {
      return await UserFirestore.getUser(userId!);
    }
    return null;
  }

  // myAccountのfollowサブコレクションにhomeAccountのIDが存在するかチェックするメソッド
  Future<bool> _isFollowing(String myAccountId, String postAccountId) async {
    final followSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(myAccountId)
        .collection('follow')
        .doc(postAccountId)
        .get();

    return followSnapshot.exists; // 存在する場合はtrueを返す
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (postAccount == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // FutureBuilderを使用してmyAccountを取得
    return FutureBuilder<Account?>(
      future: _getMyAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final myAccount = snapshot.data;

        if (myAccount == null) {
          return Scaffold(
            body: Center(child: Text('ユーザー情報が取得できませんでした')),
          );
        }

        // follow状態をチェックするFutureBuilder
        return FutureBuilder<bool>(
          future: _isFollowing(myAccount.id, postAccount!.id),
          builder: (context, followSnapshot) {
            if (followSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final isFollowing = followSnapshot.data ?? false;

            // ページ遷移の条件をチェック
            if (postAccount!.lockAccount &&
                postAccount!.id != myAccount.id &&
                !isFollowing) {
              // 条件が満たされている場合、別のウィジェットを表示
              return Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      AccountHeader(
                        postUserId: widget.postUserId,
                        pageController: _pageController,
                        value: 0,
                      ),
                      // 非公開アカウントのメッセージを表示
                      Expanded(
                        child: Center(
                          child: Text('このアカウントの投稿は非公開です。'),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: NavigationBarPage(selectedIndex: 1),
              );
            }

            // 通常の表示
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    AccountHeader(
                      postUserId: widget.postUserId,
                      pageController: _pageController,
                      value: 1,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        children: [
                          PostList(
                              postAccount: postAccount!, myAccount: myAccount!),
                          ImagePostList(myAccount: postAccount!),
                          FavoriteList(myAccount: postAccount!)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBarPage(selectedIndex: 1),
            );
          },
        );
      },
    );
  }
}
