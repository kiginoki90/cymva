import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/widget_utils.dart';
import 'package:cymva/view/start_up/check_email_page.dart';
import 'package:flutter/services.dart';
import 'package:cymva/utils/snackbar_utils.dart'; // showTopSnackBarをインポート

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController userIdController = TextEditingController();
  TextEditingController selfIntroductionController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  File? image;

  String? errorMessage; // エラーメッセージを保持するための変数
  int selfIntroCharCount = 0; // 自己紹介の現在の文字数
  int nameCharCount = 0;
  String? userIdErrorMessage; // ユーザーIDのエラーメッセージを保持するための変数

  @override
  void initState() {
    super.initState();

    nameController.addListener(() {
      setState(() {
        nameCharCount = nameController.text.length;
      });
    });
    selfIntroductionController.addListener(() {
      setState(() {
        selfIntroCharCount = selfIntroductionController.text.length;
      });
    });
  }

  // user_idの重複確認
  Future<bool> isUserIdUnique(String userId) async {
    var result = await UserFirestore.getUserByUserId(userId);
    return result == null; // 結果がnullならそのuser_idはユニーク
  }

// ユーザーIDの検証
  bool isValidUserId(String userId) {
    final validCharacters = RegExp(r'^[a-zA-Z0-9!#\$&*~\-_+=.,?]+$');
    return validCharacters.hasMatch(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WidgetUtils.createAppBer('新規登録'),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(height: 30),
              _buildNameField(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 300,
                  child: TextField(
                    controller: userIdController,
                    decoration: InputDecoration(
                      labelText: 'ユーザーID',
                      helperText: '2字以上30字未満、空白を含めることはできません',
                      helperStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      errorText: userIdErrorMessage,
                    ),
                    maxLength: 30,
                    onChanged: (value) {
                      setState(() {
                        if (value.contains(' ')) {
                          userIdErrorMessage = 'ユーザーIDに空白を含めることはできません';
                        } else if (value.length < 2) {
                          userIdErrorMessage = 'ユーザーIDは最低2文字必要です';
                        } else {
                          userIdErrorMessage = null;
                        }
                      });
                    },
                  ),
                ),
              ),
              _buildSelfIntroductionField(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 300,
                  child: TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: 'メールアドレス'),
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
                    labelText: 'パスワード',
                    helperText: '6文字以上24文字以内の英数字',
                    helperStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(24),
                  ],
                ),
              ),
              if (errorMessage != null) ...[
                SizedBox(height: 10),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ],
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      userIdController.text.isNotEmpty &&
                      selfIntroductionController.text.isNotEmpty &&
                      emailController.text.isNotEmpty &&
                      passController.text.isNotEmpty) {
                    if (userIdErrorMessage == null) {
                      bool isUnique =
                          await isUserIdUnique(userIdController.text);
                      if (isUnique) {
                        try {
                          var result = await Authentication.signUp(
                              email: emailController.text,
                              pass: passController.text);
                          if (result is UserCredential) {
                            Account newAccount = Account(
                              id: result.user!.uid,
                              name: nameController.text,
                              userId: userIdController.text,
                              selfIntroduction: selfIntroductionController.text,
                              imagePath: '',
                            );
                            var _result =
                                await UserFirestore.setUser(newAccount);
                            if (_result == true) {
                              result.user!.sendEmailVerification();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckEmailPage(
                                      email: emailController.text,
                                      pass: passController.text),
                                ),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          switch (e.code) {
                            case 'email-already-in-use':
                              showTopSnackBar(
                                context,
                                'このメールアドレスは既に使用されています',
                                backgroundColor: Colors.red,
                              );
                              break;
                            case 'weak-password':
                              showTopSnackBar(
                                context,
                                'パスワードは6文字以上で入力してください',
                                backgroundColor: Colors.red,
                              );
                              break;
                            case 'invalid-email':
                              showTopSnackBar(
                                context,
                                '無効なメールアドレスです',
                                backgroundColor: Colors.red,
                              );
                              break;
                            default:
                              showTopSnackBar(
                                context,
                                'アカウント作成に失敗しました: ${e.message}',
                                backgroundColor: Colors.red,
                              );
                              break;
                          }
                        } catch (e) {
                          showTopSnackBar(
                            context,
                            'アカウント作成に失敗しました: ${e.toString()}',
                            backgroundColor: Colors.red,
                          );
                        }
                      } else {
                        showTopSnackBar(
                          context,
                          'そのユーザーIDは既に使われています',
                          backgroundColor: Colors.red,
                        );
                      }
                    } else {
                      showTopSnackBar(
                        context,
                        'ユーザーIDに無効な文字が含まれています',
                        backgroundColor: Colors.red,
                      );
                    }
                  } else {
                    showTopSnackBar(
                      context,
                      '全ての項目を入力してください',
                      backgroundColor: Colors.red,
                    );
                  }
                },
                child: Text('アカウントを作成'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 名前フィールド
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 300,
          child: TextField(
            controller: nameController,
            maxLines: null, // 自動改行を有効にするためにmaxLinesをnullに
            decoration: InputDecoration(
              labelText: '名前',
              counterText: '', // デフォルトの文字カウンタを非表示に
            ),
            maxLength: 35,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: Text(
            '$nameCharCount/35', // 現在の文字数と最大文字数を表示
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // 自己紹介フィールド
  Widget _buildSelfIntroductionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 300,
          child: TextField(
            controller: selfIntroductionController,
            maxLines: null, // 自動改行を有効にするためにmaxLinesをnullに
            decoration: InputDecoration(
              labelText: '自己紹介',
              counterText: '', // デフォルトの文字カウンタを非表示に
            ),
            maxLength: 400, // 文字数制限300文字
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: Text(
            '$selfIntroCharCount/400', // 現在の文字数と最大文字数を表示
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
