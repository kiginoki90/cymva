import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/favorite_list.dart';
import 'package:cymva/view/account/image_post_list.dart';
import 'package:cymva/view/float_bottom.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/poat/time_line_page.dart';
import 'package:flutter/material.dart';
import 'post_list.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_header.dart';

class AccountPage extends StatefulWidget {
  final String userId;

  const AccountPage({Key? key, required this.userId}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Account? myAccount;

  @override
  void initState() {
    super.initState();
    _getAccount();
  }

  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.userId);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザー情報が取得できませんでした')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TimeLinePage()),
      );
    } else {
      setState(() {
        myAccount = account;
      });
    }
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
            AccountHeader(userId: widget.userId),
            Expanded(
              child: PageView(
                children: [
                  PostList(myAccount: myAccount!),
                  ImagePostList(myAccount: myAccount!),
                  FavoriteList(
                    myAccount: myAccount!,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatBottom(),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 1),
    );
  }
}
