import 'package:cymva/view/account/edit_page/options_page/add_account_page.dart';
import 'package:cymva/view/account/edit_page/options_page/blocked_users_page.dart';
import 'package:cymva/view/account/edit_page/options_page/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/view/account/edit_page/options_page/change_password_page.dart';
import 'package:cymva/view/account/edit_page/options_page/edit_account_page.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountOptionsPage extends StatelessWidget {
  Account myAccount = Authentication.myAccount!;
  final storage = const FlutterSecureStorage();

  @override
  Widget build(BuildContext context) {
    String userId = myAccount.id;
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Options', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOptionItem(
              context,
              icon: Icons.edit,
              label: 'プロフィール編集',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAccountPage(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildOptionItem(
              context,
              icon: Icons.lock,
              label: 'パスワード変更',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordPage(),
                  ),
                );
              },
            ),
            const Divider(),
            // _buildOptionItem(
            //   context,
            //   icon: Icons.lock,
            //   label: 'X連携',
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => XAuthPage(userId),
            //       ),
            //     );
            //   },
            // ),
            // const Divider(),
            _buildOptionItem(
              context,
              icon: Icons.logout,
              label: 'ログアウト',
              onTap: () {
                _showConfirmationDialog(
                  context,
                  'ログアウト',
                  '本当にログアウトしますか？',
                  () async {
                    try {
                      // Firebaseからサインアウト
                      await Authentication.signOut();

                      // ストレージからアカウント情報を削除
                      await storage.delete(key: 'account_id');
                      await storage.delete(key: 'account_name');

                      // ナビゲーションスタックを全て削除してLoginPageへ遷移
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginPage()),
                        (Route<dynamic> route) => false, // 全てのルートを削除
                      );
                    } catch (e) {
                      print('ログアウト処理中にエラーが発生しました: $e');
                    }
                  },
                );
              },
            ),
            const Divider(),
            _buildOptionItem(
              context,
              icon: Icons.remove_moderator,
              label: 'ブロック管理',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlockedUsersPage(userId: userId),
                  ),
                );
              },
            ),
            const Divider(),
            _buildOptionItem(
              context,
              icon: Icons.person_add,
              label: 'アカウント追加',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAccountPage(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildOptionItem(
              context,
              icon: Icons.delete_forever,
              label: 'アカウント削除',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeleteAccountPage(
                      userId: myAccount.id,
                      parentsId: myAccount.parents_id,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(BuildContext context,
      {required IconData icon,
      required String label,
      required Function onTap}) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF219DDD)),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 207, 236, 250),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: TextButton(
                child: Text('キャンセル', style: TextStyle(color: Colors.black)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            TextButton(
              child: Text('OK！'),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
