import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/edit_account_page.dart';
import 'package:cymva/view/poat/time_line_page.dart';
import 'package:cymva/model/account.dart';

class AccountHeader extends StatefulWidget {
  final String userId;
  final PageController pageController;

  const AccountHeader(
      {Key? key, required this.userId, required this.pageController})
      : super(key: key);

  @override
  _AccountHeaderState createState() => _AccountHeaderState();
}

class _AccountHeaderState extends State<AccountHeader> {
  Account? myAccount;
  int currentPage = 0;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _getAccount();
    _checkFollowStatus(); // フォロー状態を確認
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

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      // myAccountがnullの場合の表示
      return Center(child: CircularProgressIndicator());
    }
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 15, left: 15, top: 20),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@${myAccount!.userId}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: 25,
                        width: 110,
                        child: OutlinedButton(
                            onPressed: () async {
                              var result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EditAccountPage()));
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
                            if (currentUserId == widget.userId) {
                              // ログインしているアカウントのIDとこのページのアカウントIDが一致する場合
                              // 「施錠」ボタンの処理
                            } else {
                              try {
                                if (isFollowing) {
                                  // フォロー中の場合、フォローを解除する
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
                                  });

                                  print('フォローを解除しました');
                                } else {
                                  // フォローしていない場合、フォローする
                                  await UserFirestore.users
                                      .doc(currentUserId)
                                      .collection('follow')
                                      .doc(widget.userId)
                                      .set({'followed_at': Timestamp.now()});

                                  await UserFirestore.users
                                      .doc(widget.userId)
                                      .collection('followers')
                                      .doc(currentUserId)
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
                            currentUserId == widget.userId
                                ? '施錠'
                                : (isFollowing ? 'フォロー中' : 'フォロー'),
                            style: TextStyle(
                              color: isFollowing ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
              SizedBox(height: 15),
              Text(myAccount!.selfIntroduction), // nullチェック後にアクセス
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
