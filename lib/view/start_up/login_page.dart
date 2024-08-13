import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // App Check をインポート
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/screen.dart';
import 'package:cymva/view/start_up/create_account_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();

  Future<String?> _getAppCheckToken() async {
    try {
      // App Check トークンを取得
      String? token = await FirebaseAppCheck.instance.getToken(true);
      return token;
    } catch (e) {
      print('App Check トークンの取得に失敗しました: $e');
      return null;
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
                'tilel',
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
                ),
              ),
              SizedBox(height: 10),
              RichText(
                text:
                    TextSpan(style: TextStyle(color: Colors.black), children: [
                  TextSpan(text: 'アカウントを作成していない方は'),
                  TextSpan(
                      text: 'こちら',
                      style: TextStyle(color: Colors.blue),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => CreateAccountPage()));
                        }),
                ]),
              ),
              SizedBox(height: 70),
              ElevatedButton(
                  onPressed: () async {
                    // App Check トークンを取得
                    // String? appCheckToken = await _getAppCheckToken();
                    // if (appCheckToken == null) {
                    //   print('App Check トークンの取得に失敗しました');
                    //   return;
                    // }

                    // ユーザーのパスワードとメールアドレスを使用して Firebase 認証を行う
                    var result = await Authentication.emailSinIn(
                        email: emailController.text, pass: passController.text);

                    if (result is UserCredential) {
                      if (result.user!.emailVerified == true) {
                        var _result =
                            await UserFirestore.getUser(result.user!.uid);
                        if (_result != null) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TimeLinePage()));
                        } else {
                          print('ユーザー情報が取得できません');
                        }
                      } else {
                        print('メール認証が完了していません');
                      }
                    } else {
                      print('サインインエラー: $result');
                    }
                  },
                  child: Text('emailでログイン'))
            ],
          ),
        ),
      ),
    );
  }
}
