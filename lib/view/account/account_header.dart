import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/edit_account_page.dart';
import 'package:cymva/view/poat/time_line_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';

class AccountHeader extends StatefulWidget {
  final String userId;

  const AccountHeader({Key? key, required this.userId}) : super(key: key);

  @override
  _AccountHeaderState createState() => _AccountHeaderState();
}

class _AccountHeaderState extends State<AccountHeader> {
  Account? myAccount;

  @override
  void initState() {
    super.initState();
    _getAccount();
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

    return Container(
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
                      myAccount!.imagePath, // nullチェック後にアクセス
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
                        myAccount!.name, // nullチェック後にアクセス
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${myAccount!.userId}', // nullチェック後にアクセス
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                ],
              ),
              OutlinedButton(
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
                  child: const Text('編集'))
            ],
          ),
          SizedBox(height: 15),
          Text(myAccount!.selfIntroduction), // nullチェック後にアクセス
        ],
      ),
    );
  }
}
