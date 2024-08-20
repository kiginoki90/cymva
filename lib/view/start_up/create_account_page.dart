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
              GestureDetector(
                onTap: () async {
                  var result = await FunctionUtils.getImageFromGallery(context);
                  if (result != null) {
                    setState(() {
                      image = File(result.path);
                    });
                  }
                },
                child: CircleAvatar(
                  foregroundImage: image == null ? null : FileImage(image!),
                  radius: 40,
                  child: Icon(Icons.add),
                ),
              ),
              Container(
                width: 300,
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'name'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 300,
                  child: TextField(
                    controller: userIdController,
                    decoration: InputDecoration(hintText: 'userId'),
                  ),
                ),
              ),
              Container(
                width: 300,
                child: TextField(
                  controller: selfIntroductionController,
                  decoration: InputDecoration(hintText: 'selfIntroduction'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
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
                      try {
                        var result = await Authentication.signUp(
                            email: emailController.text,
                            pass: passController.text);
                        if (result is UserCredential) {
                          String? imagePath = await FunctionUtils.uploadImage(
                              result.user!.uid, image!, context);
                          Account newAccount = Account(
                            id: result.user!.uid,
                            name: nameController.text,
                            userId: userIdController.text,
                            selfIntroduction: selfIntroductionController.text,
                            imagePath: imagePath!,
                          );
                          var _result = await UserFirestore.setUser(newAccount);
                          if (_result == true) {
                            result.user!.sendEmailVerification();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CheckEmailPage(
                                        email: emailController.text,
                                        pass: passController.text)));
                          }
                        }
                      } catch (e) {
                        setState(() {
                          errorMessage = 'アカウント作成に失敗しました: ${e.toString()}';
                        });
                      }
                    } else {
                      setState(() {
                        errorMessage = '全ての項目を入力してください';
                      });
                    }
                  },
                  child: Text('アカウントを作成'))
            ],
          ),
        ),
      ),
    );
  }
}
