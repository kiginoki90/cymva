import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/follow_service.dart';
import 'package:cymva/view/account/edit_page/account_options_page.dart';
import 'package:cymva/view/account/edit_page/account_top_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/model/account.dart';

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
  final FollowService followService = FollowService();

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
    await followService.initialize();
    await _getAccount();
    await _getPostAccount();
    await _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    isFollowing = await followService.checkFollowStatus(widget.postUserId);
    setState(() {});
  }

  Future<void> _getAccount() async {
    myAccount = await UserFirestore.getUser(followService.userId!);
    setState(() {});
  }

  Future<void> _getPostAccount() async {
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
                        userId: followService.userId!,
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
                        Row(
                          children: [
                            if (postAccount!.lockAccount)
                              const Padding(
                                padding: EdgeInsets.only(right: 4.0),
                                child: Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              postAccount!.name.length > 25
                                  ? '${postAccount!.name.substring(0, 25)}...'
                                  : postAccount!.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
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
    if (followService.userId == widget.postUserId) {
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
      );
    }
  }

  Future<void> toggleFollowStatus() async {
    await followService.toggleFollowStatus(widget.postUserId);
    _checkFollowStatus();
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
                    widget.postUserId, myAccount!);
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
}
