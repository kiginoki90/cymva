import 'package:cymva/model/account.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/time_line/follow_page.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:cymva/view/time_line/timeline_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeLineBody extends StatefulWidget {
  final String userId;
  const TimeLineBody({super.key, required this.userId});

  @override
  State<TimeLineBody> createState() => _TimeLineBodyState();
}

class _TimeLineBodyState extends State<TimeLineBody> {
  late Future<List<String>>? _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final PageController _pageController = PageController();

  Account? myAccount;

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    _loadAccount(); // アカウント情報をロードする関数を呼び出し
  }

  // Firestoreからアカウント情報を取得する関数
  Future<void> _loadAccount() async {
    myAccount = await getAccount(widget.userId);
    setState(() {});
  }

  // Firestoreからアカウント情報を取得する関数
  Future<Account?> getAccount(String userId) async {
    try {
      // Firestoreのusersコレクションから特定のユーザーIDに対応するドキュメントを取得
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // ドキュメントが存在する場合、Accountインスタンスを返す
      if (doc.exists) {
        return Account.fromDocument(doc);
      } else {
        print('ユーザードキュメントが見つかりません');
        return null; // ドキュメントが存在しない場合はnullを返す
      }
    } catch (e) {
      print('アカウント情報の取得に失敗しました: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // アカウント情報がまだ取得されていない場合はローディングインジケーターを表示
    if (myAccount == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(), // ローディングインジケーターを表示
        ),
      );
    }

    // アカウント情報が取得された場合に表示するUI
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TimelineHeader(pageController: _pageController),
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  TimeLinePage(userId: widget.userId),
                  FollowPage(myAccount: myAccount!),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 0),
    );
  }
}
