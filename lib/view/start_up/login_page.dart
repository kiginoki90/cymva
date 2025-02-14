import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/start_up/create_account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  String? errorMessage;
  final storage = const FlutterSecureStorage();
  bool _isObscured = true;

  Future<void> _sendPasswordResetEmail() async {
    String email = emailController.text;
    if (email.isEmpty) {
      setState(() {
        errorMessage = 'メールアドレスを入力してください';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await updatePasswordChangeToken(user.uid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('パスワードリセットのメールを送信しました')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'メールの送信に失敗しました: $e';
      });
    }
  }

  Future<void> updatePasswordChangeToken(String userId) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(userId).update({
      'passwordChangeToken': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveAccountToStorage(Account account) async {
    try {
      await storage.write(key: 'account_id', value: account.id);
      await storage.write(key: 'account_name', value: account.name);
      print('アカウント情報が保存されました: ${account.id}');
    } catch (e) {
      print('アカウント情報の保存に失敗しました: $e');
    }
  }

  Future<void> _saveParentsTokenToStorage(String userId) async {
    final firestore = FirebaseFirestore.instance;

    // usersコレクションからparents_idを取得
    final userDoc = await firestore.collection('users').doc(userId).get();
    final parentsId = userDoc['parents_id'] as String?;

    if (parentsId != null) {
      // parents_idのpasswordChangeTokenを取得
      final parentsDoc =
          await firestore.collection('users').doc(parentsId).get();
      final passwordChangeToken = parentsDoc['passwordChangeToken'];

      // ストレージに保存
      await storage.write(
        key: 'passwordChangeToken',
        value: passwordChangeToken.millisecondsSinceEpoch.toString(),
      );
    } else {
      print('parents_idが見つかりません');
    }
  }

  // Future<void> _userAccountStorage(String userId) async {
  //   final firestore = FirebaseFirestore.instance;
  //   final storage = FlutterSecureStorage();

  //   try {
  //     // Firestoreからユーザー情報を取得
  //     DocumentSnapshot userDoc =
  //         await firestore.collection('users').doc(userId).get();

  //     // ユーザー情報が存在する場合
  //     if (userDoc.exists) {
  //       // ユーザーデータを取得
  //       var userData = userDoc.data() as Map<String, dynamic>;

  //       // 必要なフィールドをローカルストレージに保存
  //       await storage.write(
  //           key: 'image_path', value: userData['image_path'] ?? '');
  //       await storage.write(
  //           key: 'key_account', value: userData['key_account'] ?? '');
  //       await storage.write(key: 'name', value: userData['name'] ?? '');
  //       await storage.write(
  //           key: 'parents_id', value: userData['parents_id'] ?? '');
  //       await storage.write(
  //           key: 'self_introduction',
  //           value: userData['self_introduction'] ?? '');
  //       await storage.write(
  //           key: 'updated_time', value: userData['updated_time'] ?? '');
  //       await storage.write(key: 'user_id', value: userData['user_id'] ?? '');
  //     } else {
  //       print("ユーザー情報が見つかりませんでした");
  //     }
  //   } catch (e) {
  //     print("Firestoreからデータを取得する際にエラーが発生しました: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(height: 50),
                Text(
                  'Cymva city',
                  style: TextStyle(
                    fontFamily: 'OpenSans', // フォントファミリーを指定
                    fontSize: 29,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    width: 300,
                    child: TextField(
                      controller: emailController,
                      decoration: InputDecoration(hintText: 'email'),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(80),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 300,
                  child: TextField(
                    controller: passController,
                    decoration: InputDecoration(
                      hintText: 'パスワード',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscured ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                      ),
                    ),
                    obscureText: _isObscured,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(24),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(text: 'アカウントを作成していない方は'),
                      TextSpan(
                        text: 'こちら',
                        style: TextStyle(color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateAccountPage(),
                              ),
                            );
                          },
                      ),
                      TextSpan(text: '\n\n'),
                      TextSpan(text: 'パスワードを忘れてしまった方は'),
                      TextSpan(
                        text: 'こちら',
                        style: TextStyle(color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _sendPasswordResetEmail();
                          },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 70),
                ElevatedButton(
                  onPressed: () async {
                    Authentication.myAccount = null;

                    try {
                      var result = await Authentication.emailSinIn(
                        email: emailController.text,
                        pass: passController.text,
                      );

                      if (result is UserCredential) {
                        if (result.user!.emailVerified == true) {
                          var _result =
                              await UserFirestore.getUser(result.user!.uid);
                          if (_result != null) {
                            await _saveAccountToStorage(_result);

                            // parents_idのpasswordChangeTokenを保存
                            await _saveParentsTokenToStorage(result.user!.uid);

                            // await _userAccountStorage(result.user!.uid);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TimeLineBody(
                                  userId: result.user!.uid,
                                  fromLogin: true,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              errorMessage = 'ユーザー情報が取得できません';
                            });
                          }
                        } else {
                          setState(() {
                            errorMessage = 'メール認証が完了していません';
                          });
                        }
                      } else {
                        setState(() {
                          errorMessage = 'サインインに失敗しました';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        errorMessage = 'エラーが発生しました: $e';
                      });
                    }
                  },
                  child: Text('emailでログイン'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
