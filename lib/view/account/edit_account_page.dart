import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/widget_utils.dart';
import 'package:cymva/view/start_up/login_page.dart';

class EditAccountPage extends StatefulWidget {
  @override
  _EditAccountPageState createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  Account myAccount = Authentication.myAccount!;
  TextEditingController nameController = TextEditingController();
  TextEditingController userIdController = TextEditingController();
  TextEditingController selfIntroductionController = TextEditingController();
  File? image;

  ImageProvider getImage() {
    if (image == null) {
      return NetworkImage(myAccount.imagePath);
    } else {
      return FileImage(image!);
    }
  }

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: myAccount.name);
    userIdController = TextEditingController(text: myAccount.userId);
    selfIntroductionController =
        TextEditingController(text: myAccount.selfIntroduction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WidgetUtils.createAppBer('プロフィール編集'),
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
                  foregroundImage: getImage(),
                  radius: 40,
                  child: Icon(Icons.add),
                ),
              ),
              Container(
                width: 300,
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(hintText: 'name'),
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
              SizedBox(height: 30),
              ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty &&
                        userIdController.text.isNotEmpty &&
                        selfIntroductionController.text.isNotEmpty) {
                      String? imagePath = '';

                      if (image == null) {
                        imagePath = myAccount.imagePath ?? '';
                      } else {
                        String? result = await FunctionUtils.uploadImage(
                            myAccount.id, image!, context);
                        if (result != null) {
                          imagePath = result;
                        } else {
                          imagePath =
                              'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344';
                        }
                      }
                      Account updateAccount = Account(
                          id: myAccount.id,
                          name: nameController.text,
                          userId: userIdController.text,
                          selfIntroduction: selfIntroductionController.text,
                          imagePath: imagePath);
                      Authentication.myAccount = updateAccount;
                      var result =
                          await UserFirestore.updataUser(updateAccount);
                      if (result == true) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  child: Text('更新')),
              SizedBox(height: 50),
              ElevatedButton(
                  onPressed: () {
                    Authentication.signOut();
                    while (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => LoginPage()));
                  },
                  child: Text('ログアウト')),
              SizedBox(
                height: 50,
              ),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    UserFirestore.deleteUser(myAccount.id);
                    Authentication.deleteAuth();
                    while (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => LoginPage()));
                  },
                  child: Text('アカウントを削除'))
            ],
          ),
        ),
      ),
    );
  }
}
