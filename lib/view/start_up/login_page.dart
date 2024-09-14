import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/start_up/create_account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  String? errorMessage; // エラーメッセージを保存する変数

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('パスワードリセットのメールを送信しました')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'メールの送信に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(height: 50),
              Text(
                'title',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  width: 300,
                  child: TextField(
                    controller: emailController,
                    decoration: InputDecoration(hintText: 'email'),
                  ),
                ),
              ),
              Container(
                width: 300,
                child: TextField(
                  controller: passController,
                  decoration: InputDecoration(hintText: 'pass'),
                  obscureText: true,
                ),
              ),
              SizedBox(height: 10),
              if (errorMessage != null) // エラーメッセージがある場合に表示
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
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TimeLineBody(),
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
    );
  }
}
