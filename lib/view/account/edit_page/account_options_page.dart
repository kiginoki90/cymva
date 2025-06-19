import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/account/edit_page/options_page/add_account_page.dart';
import 'package:cymva/view/account/edit_page/options_page/blocked_users_page.dart';
import 'package:cymva/view/account/edit_page/options_page/bookmark.dart';
import 'package:cymva/view/account/edit_page/options_page/delete_account_page.dart';
import 'package:cymva/view/account/edit_page/options_page/support_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/view/account/edit_page/options_page/change_password_page.dart';
import 'package:cymva/view/account/edit_page/options_page/edit_account_page.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io'; // Platformクラスを使用するために追加

class AccountOptionsPage extends StatefulWidget {
  final String loginUserId;

  AccountOptionsPage({Key? key, required this.loginUserId}) : super(key: key);
  @override
  _AccountOptionsPageState createState() => _AccountOptionsPageState();
}

class _AccountOptionsPageState extends State<AccountOptionsPage> {
  final Account myAccount = Authentication.myAccount!;
  final storage = const FlutterSecureStorage();
  String? userId;
  String? loginUserId;
  int? loginCount;

  @override
  void initState() {
    super.initState();
    _checkLoginUserId();
  }

  Future<void> _checkLoginUserId() async {
    userId = FirebaseAuth.instance.currentUser?.uid;

    loginUserId = await storage.read(key: 'account_id');

    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(loginUserId)
          .get();

      if (userDoc.exists) {
        final String? parentsId = userDoc.data()?['parents_id'];

        if (parentsId != userId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccountPage(
                postUserId: userId!,
                withDelay: false,
              ),
            ),
          );
        }
      }
    }
  }

  Future<String?> _getImageUrl() async {
    try {
      // FirestoreからURLを取得
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('setting')
          .doc('AppBarIMG')
          .get();
      String? imageUrl = doc.data()?['AccountOptionsPage'];
      if (imageUrl != null) {
        // Firebase StorageからダウンロードURLを取得
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      print('Error fetching image URL: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String userId = myAccount.id;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: _getImageUrl(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('');
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Account Options',
                  style: TextStyle(color: Colors.black));
            } else {
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                height: kToolbarHeight,
              );
            }
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Container(
        constraints: BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOptionItem(
                context,
                icon: Icons.edit,
                label: '設定編集',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditAccountPage(),
                    ),
                  );
                },
              ),
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
              _buildOptionItem(
                context,
                icon: Icons.bookmark,
                label: '栞',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookmarkPage(userId: userId),
                    ),
                  );
                },
              ),
              if (!Platform.isAndroid) // Androidの場合は非表示
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
              _buildOptionItem(
                context,
                icon: Icons.support,
                label: 'サポート',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupportPage(),
                    ),
                  );
                },
              ),
            ],
          ),
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
