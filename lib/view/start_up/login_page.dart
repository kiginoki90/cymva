import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/navigation_bar.dart';
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
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  @override
  void initState() {
    super.initState();
    _loadFailedAttempts();
  }

  Future<void> _loadFailedAttempts() async {
    String? failedAttemptsStr = await storage.read(key: 'failed_attempts');
    String? lockoutEndTimeStr = await storage.read(key: 'lockout_end_time');
    if (failedAttemptsStr != null) {
      setState(() {
        _failedAttempts = int.parse(failedAttemptsStr);
      });
    }
    if (lockoutEndTimeStr != null) {
      setState(() {
        _lockoutEndTime = DateTime.parse(lockoutEndTimeStr);
      });
    }
  }

  Future<void> _incrementFailedAttempts() async {
    setState(() {
      _failedAttempts++;
    });
    await storage.write(
        key: 'failed_attempts', value: _failedAttempts.toString());
    if (_failedAttempts > 6) {
      _lockoutEndTime = DateTime.now().add(Duration(minutes: 30));
      await storage.write(
          key: 'lockout_end_time', value: _lockoutEndTime.toString());
    }
  }

  Future<void> _resetFailedAttempts() async {
    setState(() {
      _failedAttempts = 0;
      _lockoutEndTime = null;
    });
    await storage.delete(key: 'failed_attempts');
    await storage.delete(key: 'lockout_end_time');
  }

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

      showTopSnackBar(context, 'パスワードリセットのメールを送信しました',
          backgroundColor: Colors.green);
    } catch (e) {
      showTopSnackBar(context, 'メールの送信に失敗しました', backgroundColor: Colors.red);
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
                    if (_lockoutEndTime != null &&
                        DateTime.now().isBefore(_lockoutEndTime!)) {
                      setState(() {
                        errorMessage =
                            '5回の失敗により、一時的にロックされています。\nしばらくしてから再試行してください。';
                      });
                      return;
                    }

                    // 失敗の回数が5回以上かつ最後の失敗から5分以上経っていれば、失敗の回数をリセット
                    if (_failedAttempts >= 5 &&
                        _lockoutEndTime != null &&
                        DateTime.now().isAfter(_lockoutEndTime!)) {
                      await _resetFailedAttempts();
                    }

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

                            await _resetFailedAttempts(); // 成功時に失敗回数をリセット

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => NavigationBarPage(
                                      userId: result.user!.uid,
                                      showChatIcon: true)),
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
                        await _incrementFailedAttempts(); // 失敗時に失敗回数をインクリメント
                        setState(() {
                          if (_failedAttempts >= 5) {
                            _lockoutEndTime =
                                DateTime.now().add(Duration(minutes: 30));
                            errorMessage =
                                '複数回の失敗により、一時的にロックされています。\nしばらくしてから再試行してください。';
                          } else {
                            errorMessage =
                                'ログインに失敗しました。失敗回数: $_failedAttempts\n5回の失敗で一時的にロックされます';
                          }
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
