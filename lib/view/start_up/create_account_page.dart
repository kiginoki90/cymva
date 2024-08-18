import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/widget_utils.dart';
import 'package:cymva/view/start_up/check_email_page.dart';

//CreateAccountPageウィジットを作成し、そのウィジットが状態を保ち、状態の初期化と管理を委ねている。
//新規アカウント作成画面を定義する。StatefulWidgetを継承し、createStateメソッドをオーバーライドして対応するStateオブジェクトである_CreateAccountPageStateを生成する。
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  //TextEditingControllerはテキストフィールドの内容を管理するためのコントローラを作成
  TextEditingController nameController = TextEditingController();
  TextEditingController userIdController = TextEditingController();
  TextEditingController selfIntroductionController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  File? image;

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
                //アプリで画像をギャラリーから選択する機能を実装
                //FunctionUtils.getImageFromGallery()はギャラリーから画像を選択する処理を行う。
                onTap: () async {
                  //resultが変数。varは変数を宣言するために使用されるキーワード。型を具体的に明示しない際に使用する。
                  var result = await FunctionUtils.getImageFromGallery(context);
                  if (result != null) {
                    //画像が取得できたら選択された画像のパスを使ってFileオブジェクトを生成。imageに代入している。
                    setState(() {
                      image = File(result.path);
                    });
                  }
                },
                //CircleAvatarウィジットはforegroundImageにより全面に表示される画像を指定する。
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
              SizedBox(height: 30),
              ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty &&
                        userIdController.text.isNotEmpty &&
                        selfIntroductionController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        passController.text.isNotEmpty) {
                      //AuthenticationクラスのsignUpメソッド
                      var result = await Authentication.signUp(
                          email: emailController.text,
                          pass: passController.text);
                      //resultがUserCredential型であることをチェック
                      if (result is UserCredential) {
                        //画像のアップロードを行い、アップロードされた画像のパスを返す。パスはiamgePathへ。
                        String? iamgePath = await FunctionUtils.uploadImage(
                            result.user!.uid, image!, context);
                        //Accountクラスのインスタンス作成。ID等5つのデータが含まれる。
                        //Accountオブジェクトが作られる。
                        Account newAccount = Account(
                          id: result.user!.uid,
                          name: nameController.text,
                          userId: userIdController.text,
                          selfIntroduction: selfIntroductionController.text,
                          imagePath: iamgePath!,
                        );
                        //作成したAccountオブジェクトをFirestoreに保存する。
                        var _result = await UserFirestore.setUser(newAccount);
                        //実行結果がtrueならば
                        if (_result == true) {
                          //メール承認を行う。
                          result.user!.sendEmailVerification();
                          //ナビゲーションを利用してCheckEmailPageへ画面遷移を行う。
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => CheckEmailPage(
                                      email: emailController.text,
                                      pass: passController.text)));
                        }
                      }
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
