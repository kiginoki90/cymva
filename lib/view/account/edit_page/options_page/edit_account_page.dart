import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/function_utils.dart';

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
  bool isPrivate = false;

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

    isPrivate = myAccount.lockAccount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('プロフィール編集'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                var result = await FunctionUtils.getImageFromGallery(context);
                if (result != null) {
                  setState(() {
                    image = File(result.path);
                  });
                }
              },
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: getImage(),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: image == null
                        ? Icon(Icons.camera_alt,
                            color: Colors.grey[800], size: 30)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.edit, color: Colors.blue, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: nameController,
              label: '名前',
              hintText: 'Enter your name',
              description: '名前を15字以内で記入してください',
            ),
            // SizedBox(height: 20),
            // _buildTextField(
            //   controller: userIdController,
            //   label: 'ユーザーID',
            //   hintText: 'Enter your user ID',
            //   description: 'ユーザーIDを20字以内で入力してください。',
            // ),
            SizedBox(height: 20),
            _buildTextField(
              controller: selfIntroductionController,
              label: '自己紹介',
              hintText: 'Enter your self introduction',
              description: '自己紹介を400字以内で入力してください。',
            ),
            SizedBox(height: 20),
            // 公開/非公開切り替えスイッチ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'アカウントの公開設定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isPrivate,
                  onChanged: (bool value) async {
                    setState(() {
                      isPrivate = value; // スイッチの状態を更新
                    });

                    // Firestoreにlock_accountを更新
                    await UserFirestore.updateLockAccount(
                        myAccount.id, isPrivate);
                  },
                  activeColor: Colors.blueGrey, // スイッチがオンのときの色
                ),
              ],
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
                      imagePath: imagePath,
                      lockAccount: isPrivate);

                  Authentication.myAccount = updateAccount;
                  var result = await UserFirestore.updataUser(updateAccount);
                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text(
                '更新',
                style:
                    TextStyle(color: const Color.fromARGB(255, 255, 255, 255)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}
