import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/favorite_list.dart';
import 'package:cymva/view/account/image_post_list.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:flutter/material.dart';
import 'post_list.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_header.dart';

class AccountPage extends StatefulWidget {
  final String postUserId;

  const AccountPage({Key? key, required this.postUserId}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Account? myAccount;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _getAccount();
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.postUserId);
    print(account);
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
        myAccount = account;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AccountHeader(
              postUserId: widget.postUserId,
              pageController: _pageController, // pageControllerを渡す
            ),
            Expanded(
              child: PageView(
                controller: _pageController, // PageControllerを設定
                children: [
                  PostList(myAccount: myAccount!),
                  ImagePostList(myAccount: myAccount!),
                  FavoriteList(myAccount: myAccount!)
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 1),
    );
  }
}
