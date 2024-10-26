import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _auth = FirebaseAuth.instance;

  Future<void> _changePassword() async {
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('すべてのフィールドを入力してください')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新しいパスワードと確認用パスワードが一致しません')),
      );
      return;
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Re-authenticate the user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        await user.reauthenticateWithCredential(credential);

        // Update the password
        await user.updatePassword(newPassword);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('パスワードが変更されました')),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      print('パスワード変更に失敗しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('パスワード変更に失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('パスワード変更'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(labelText: '現在のパスワード'),
              obscureText: true,
            ),
            SizedBox(height: 40),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: '新しいパスワード'),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: '新しいパスワード（確認）'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text('パスワードを変更する'),
            ),
            SizedBox(height: 10),
            Text('パスワードは6文字以上の英数字で設定してください'),
          ],
        ),
      ),
    );
  }
}
