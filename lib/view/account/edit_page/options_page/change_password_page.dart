import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final storage = const FlutterSecureStorage();

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
        // ユーザーを再認証
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        await user.reauthenticateWithCredential(credential);

        // パスワードを更新
        await user.updatePassword(newPassword);

        // パスワード変更トークンを更新
        await updatePasswordChangeToken(user.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('パスワードが変更されました')),
        );

        // ログイン画面に遷移
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => LoginPage()), // LoginPage() はログイン画面のウィジェット
        );
      }
    } catch (e) {
      print('パスワード変更に失敗しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('パスワード変更に失敗しました')),
      );
    }
  }

  // トークン更新処理
  Future<void> updatePasswordChangeToken(String userId) async {
    final firestore = FirebaseFirestore.instance;

    // `userId`の`parents_id`を取得
    final userDoc = await firestore.collection('users').doc(userId).get();
    final parentsId = userDoc['parents_id'];

    if (parentsId != null) {
      // Firestoreにサーバーのタイムスタンプを設定
      final timestamp = FieldValue.serverTimestamp();

      // `parents_id`のドキュメントの`passwordChangeToken`フィールドにタイムスタンプを更新
      await firestore.collection('users').doc(parentsId).update({
        'passwordChangeToken': timestamp,
      });

      // `parents_id`のドキュメントを再取得して、更新されたタイムスタンプをローカルストレージに保存
      final parentDoc =
          await firestore.collection('users').doc(parentsId).get();
      final updatedTimestamp = parentDoc['passwordChangeToken'];

      // FlutterSecureStorageに保存
      await storage.write(
        key: 'passwordChangeToken',
        value: updatedTimestamp.toString(),
      );
    } else {
      print('parents_idが存在しません');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('パスワード変更'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(labelText: '現在のパスワード'),
              obscureText: true,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
              ],
            ),
            SizedBox(height: 40),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: '新しいパスワード'),
              obscureText: true,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
              ],
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: '新しいパスワード（確認）'),
              obscureText: true,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text('パスワードを変更する'),
            ),
            SizedBox(height: 10),
            Text('パスワードは6文字以上24文字以内の英数字で設定してください'),
          ],
        ),
      ),
    );
  }
}
