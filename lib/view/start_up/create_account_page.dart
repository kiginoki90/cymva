import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/widget_utils.dart';
import 'package:cymva/view/start_up/check_email_page.dart';

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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    print('Image: $image');
    return Scaffold(
      appBar: WidgetUtils.createAppBer('新規登録'),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(height: 30),
              // GestureDetector(
              //   onTap: () async {
              //     var result = await FunctionUtils.getImageFromGallery(context);
              //     if (result != null) {
              //       setState(() {
              //         image = File(result.path);
              //       });
              //     }
              //   },
              //   child: Container(
              //     width: 80,
              //     height: 80,
              //     decoration: BoxDecoration(
              //       borderRadius: BorderRadius.circular(8),
              //       image: image == null
              //           ? null
              //           : DecorationImage(
              //               image: FileImage(image!),
              //               fit: BoxFit.cover,
              //             ),
              //       color: Colors.grey[300],
              //     ),
              //     child: image == null ? Icon(Icons.add) : null,
              //   ),
              // ),
              Container(
                width: 300,
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: '名前'),
                  maxLength: 30,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 300,
                  child: TextField(
                    controller: userIdController,
                    decoration: InputDecoration(hintText: 'ユーザーID'),
                    maxLength: 30,
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
                    decoration: InputDecoration(hintText: 'メールアドレス'),
                  ),
                ),
              ),
              Container(
                width: 300,
                child: TextField(
                  controller: passController,
                  decoration: InputDecoration(hintText: 'パスワード（6文字以上の英数字）'),
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
                    bool isUnique = await isUserIdUnique(userIdController.text);
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
                          var _result = await UserFirestore.setUser(newAccount);
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
                        // FirebaseAuthExceptionのエラーメッセージをハンドリング
                        if (e.code == 'email-already-in-use') {
                          setState(() {
                            errorMessage = 'このメールアドレスは既に使用されています';
                          });
                        } else if (e.code == 'weak-password') {
                          setState(() {
                            errorMessage = 'パスワードは6文字以上で入力してください';
                          });
                        } else if (e.code == 'invalid-email') {
                          setState(() {
                            errorMessage = '無効なメールアドレスです';
                          });
                        } else {
                          setState(() {
                            errorMessage = 'アカウント作成に失敗しました: ${e.message}';
                          });
                        }
                      } catch (e) {
                        // その他のエラーハンドリング
                        setState(() {
                          errorMessage = 'アカウント作成に失敗しました: ${e.toString()}';
                        });
                      }
                    } else {
                      setState(() {
                        errorMessage = 'そのユーザーIDは既に使われています';
                      });
                    }
                  } else {
                    setState(() {
                      errorMessage = '全ての項目を入力してください';
                    });
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
              hintText: '自己紹介',
              counterText: '', // デフォルトの文字カウンタを非表示に
            ),
            maxLength: 300, // 文字数制限300文字
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: Text(
            '$selfIntroCharCount/300', // 現在の文字数と最大文字数を表示
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
