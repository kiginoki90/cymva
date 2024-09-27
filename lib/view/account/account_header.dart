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

  const AccountHeader(
      {Key? key, required this.postUserId, required this.pageController})
      : super(key: key);

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
    _getAccount();
    _getPostAccount();
    _checkFollowStatus();
    widget.pageController.addListener(() {
      setState(() {
        currentPage = widget.pageController.page?.round() ?? 0;
      });
    });
  }

  Future<void> _checkFollowStatus() async {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    try {
      var followDoc = await UserFirestore.users
          .doc(currentUserId)
          .collection('follow')
          .doc(widget.postUserId)
          .get();
      setState(() {
        isFollowing = followDoc.exists;
      });
    } catch (e) {
      print('フォロー状態の確認に失敗しました: $e');
    }
  }

  Future<void> _getAccount() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // ここでログインしている自分のアカウント情報を取得
    myAccount = await UserFirestore.getUser(userId!);

    setState(() {});
  }

  Future<void> _getPostAccount() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> postUser = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(widget.postUserId)
          .get();

      if (postUser.exists) {
        setState(() {
          // fromDocumentを使用して、ドキュメントからAccountオブジェクトを生成
          postAccount = Account.fromDocument(postUser);
        });
      } else {
        print("ユーザードキュメントが見つかりませんでした");
      }
    } catch (e) {
      print("Firestoreからアカウントを取得する際にエラーが発生しました: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      // myAccountがnullの場合の表示
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 15, left: 15, top: 20),
          height: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postAccount!.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '@${postAccount!.userId}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (userId == widget.postUserId)
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
                              child: const Text('編集')),
                        ),
                      SizedBox(
                        height: 10,
                      ),
                      SizedBox(
                        height: 25,
                        width: 120,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (userId == widget.postUserId) {
                              // ログインしているアカウントのIDとこのページのアカウントIDが一致する場合
                              // 「施錠」ボタンの処理
                            } else {
                              try {
                                if (isFollowing) {
                                  // フォロー中の場合、フォローを解除する
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

                                  setState(() {
                                    isFollowing = false;
                                  });

                                  print('フォローを解除しました');
                                } else {
                                  // フォローしていない場合、フォローする
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

                                  setState(() {
                                    isFollowing = true;
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
                                color: isFollowing ? Colors.blue : Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0), // 角を丸くしない
                            ),
                          ),
                          child: Text(
                            userId == widget.postUserId
                                ? '施錠'
                                : (isFollowing ? 'フォロー中' : 'フォロー'),
                            style: TextStyle(
                              color: isFollowing ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home,
                    color: currentPage == 0 ? Colors.blue : Colors.grey,
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: currentPage == 0 ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
              onPressed: () {
                widget.pageController.jumpToPage(0);
              },
            ),
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.camera,
                    color: currentPage == 1 ? Colors.blue : Colors.grey,
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: currentPage == 1 ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
              onPressed: () {
                widget.pageController.jumpToPage(1);
              },
            ),
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: currentPage == 2 ? Colors.blue : Colors.grey,
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: currentPage == 2 ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
              onPressed: () {
                widget.pageController.jumpToPage(2);
              },
            ),
          ],
        ),
      ],
    );
  }
}
