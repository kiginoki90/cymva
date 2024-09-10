import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/edit_page/edit_account_page.dart';
import 'package:cymva/view/poat/time_line_page.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/follow_page.dart';
import 'package:cymva/view/account/follower_page.dart';
import 'package:cymva/view/account/account_page.dart';

//アカウント詳細ページ
class AccountTopPage extends StatefulWidget {
  final String userId;
  const AccountTopPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AccountTopPage> createState() => _AccountTopPageState();
}

class _AccountTopPageState extends State<AccountTopPage> {
  Account? myAccount;
  int currentPage = 0;
  bool isFollowing = false;
  late Future<int> _followCountFuture;
  late Future<int> _followerCountFuture;
  double previousScrollOffset = 0.0; // スクロールの前回のオフセット

  @override
  void initState() {
    super.initState();
    _getAccount();
    _checkFollowStatus();
    _followCountFuture = _getFollowCount();
    _followerCountFuture = _getFollowerCount();
  }

  Future<void> _checkFollowStatus() async {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    try {
      var followDoc = await UserFirestore.users
          .doc(currentUserId)
          .collection('follow')
          .doc(widget.userId)
          .get();
      setState(() {
        isFollowing = followDoc.exists;
      });
    } catch (e) {
      print('フォロー状態の確認に失敗しました: $e');
    }
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.userId);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ユーザー情報が取得できませんでした')));
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const TimeLinePage()));
    } else {
      setState(() {
        myAccount = account;
      });
    }
  }

  Future<int> _getFollowCount() async {
    final followCollection =
        UserFirestore.users.doc(widget.userId).collection('follow');
    final followDocs = await followCollection.get();
    return followDocs.size;
  }

  Future<int> _getFollowerCount() async {
    final followersCollection =
        UserFirestore.users.doc(widget.userId).collection('followers');
    final followerDocs = await followersCollection.get();
    return followerDocs.size;
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      return Center(child: CircularProgressIndicator());
    }
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(myAccount!.name),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo is ScrollUpdateNotification) {
            if (scrollInfo.metrics.pixels > previousScrollOffset) {
              // スクロールが下方向に進んだ場合
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AccountPage(userId: currentUserId)),
              );
            }
            previousScrollOffset = scrollInfo.metrics.pixels; // スクロール位置を更新
          }
          return true;
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(right: 15, left: 15, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ボタンを右端に配置
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end, // ボタンを右端に揃える
                        children: [
                          SizedBox(
                            height: 25,
                            width: 110,
                            child: OutlinedButton(
                              onPressed: () async {
                                var result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AccountOptionsPage()));
                                if (result == true) {
                                  setState(() {
                                    myAccount = Authentication.myAccount!;
                                  });
                                }
                              },
                              child: const Text('編集'),
                            ),
                          ),
                          SizedBox(height: 10), // ボタン間のスペース
                          SizedBox(
                            height: 25,
                            width: 120,
                            child: OutlinedButton(
                              onPressed: () async {
                                if (currentUserId == widget.userId) {
                                  // 自身のアカウント
                                } else {
                                  try {
                                    if (isFollowing) {
                                      await UserFirestore.users
                                          .doc(currentUserId)
                                          .collection('follow')
                                          .doc(widget.userId)
                                          .delete();

                                      await UserFirestore.users
                                          .doc(widget.userId)
                                          .collection('followers')
                                          .doc(currentUserId)
                                          .delete();

                                      setState(() {
                                        isFollowing = false;
                                        _followerCountFuture =
                                            _getFollowerCount();
                                      });

                                      print('フォローを解除しました');
                                    } else {
                                      await UserFirestore.users
                                          .doc(currentUserId)
                                          .collection('follow')
                                          .doc(widget.userId)
                                          .set(
                                              {'followed_at': Timestamp.now()});

                                      await UserFirestore.users
                                          .doc(widget.userId)
                                          .collection('followers')
                                          .doc(currentUserId)
                                          .set(
                                              {'followed_at': Timestamp.now()});

                                      setState(() {
                                        isFollowing = true;
                                        _followerCountFuture =
                                            _getFollowerCount();
                                      });

                                      print('フォローしました');
                                    }
                                  } catch (e) {
                                    print('フォロー処理に失敗しました: $e');
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    isFollowing ? Colors.blue : Colors.white,
                                side: BorderSide(
                                    color: isFollowing
                                        ? Colors.blue
                                        : Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                              ),
                              child: Text(
                                currentUserId == widget.userId
                                    ? '施錠'
                                    : (isFollowing ? 'フォロー中' : 'フォロー'),
                                style: TextStyle(
                                  color:
                                      isFollowing ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20), // ボタンとアイコンの間にスペースを追加

                      // アイコンを中央に配置
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                myAccount!.imagePath,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  myAccount!.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '@${myAccount!.userId}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          FutureBuilder<int>(
                            future: _followCountFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              }
                              if (snapshot.hasError) {
                                return Text('エラー');
                              }
                              final followCount = snapshot.data ?? 0;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FollowPage(userId: widget.userId),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Text(
                                      'フォロー: $followCount',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          FutureBuilder<int>(
                            future: _followerCountFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              }
                              if (snapshot.hasError) {
                                return Text('エラー');
                              }
                              final followerCount = snapshot.data ?? 0;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FollowerPage(userId: widget.userId),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Text(
                                      'フォロワー: $followerCount',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.all(8.15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(myAccount?.selfIntroduction ?? '自己紹介がありません'),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
