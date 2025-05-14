import 'dart:io';
import 'package:cymva/utils/navigation_utils.dart';
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
  Account? myAccount;
  TextEditingController nameController = TextEditingController();
  TextEditingController userIdController = TextEditingController();
  TextEditingController selfIntroductionController = TextEditingController();
  File? image;
  bool isPrivate = false;
  bool followPrivate = true;
  bool replyMessage = true;
  bool quoteMessage = true; // 引用メッセージの初期値
  bool starMessage = true; // スターメッセージの初期値
  int _nameCharCount = 0;
  int _introCharCount = 0;

  ImageProvider getImage() {
    if (image == null) {
      return NetworkImage(myAccount?.imagePath ?? '');
    } else {
      return FileImage(image!);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAccountData();
  }

  Future<void> _fetchAccountData() async {
    final account = await UserFirestore.getUser(Authentication.myAccount!.id);
    if (account != null) {
      setState(() {
        myAccount = account;
        nameController.text = myAccount!.name;
        userIdController.text = myAccount!.userId;
        selfIntroductionController.text = myAccount!.selfIntroduction;
        isPrivate = myAccount!.lockAccount;
        followPrivate = myAccount!.followMessage;
        replyMessage = myAccount!.replyMessage;
        quoteMessage = myAccount!.quoteMessage;
        starMessage = myAccount!.starMessage;
        _nameCharCount = nameController.text.length;
        _introCharCount = selfIntroductionController.text.length;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    selfIntroductionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('設定編集'),
          backgroundColor: Colors.blueGrey,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('設定編集'),
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
              hintText: 'あなたの名前を教えてね',
              description: '名前を35字以内で記入してください',
              currentCharCount: _nameCharCount,
              onChanged: (text) {
                setState(() {
                  _nameCharCount = text.length;
                });
              },
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: selfIntroductionController,
              label: '自己紹介',
              hintText: 'あなたのことを教えてね',
              description: '自己紹介を400字以内で入力してください。',
              currentCharCount: _introCharCount,
              onChanged: (text) {
                setState(() {
                  _introCharCount = text.length;
                });
              },
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    userIdController.text.isEmpty ||
                    selfIntroductionController.text.isEmpty) {
                  // 未入力の項目がある場合の処理
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('入力エラー'),
                      content: Text('すべての項目を入力してください。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                if (nameController.text.length > 35) {
                  // 名前が35文字を超えた場合の警告
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('名前の文字数制限'),
                      content: Text('名前は35文字以内で入力してください。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                if (selfIntroductionController.text.length > 400) {
                  // 自己紹介が400文字を超えた場合の警告
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('自己紹介の文字数制限'),
                      content: Text('自己紹介は400文字以内で入力してください。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                // 文字数のチェックが通ったら更新処理を実行
                String? imagePath = '';

                if (image == null) {
                  imagePath = myAccount!.imagePath;
                } else {
                  String? result = await FunctionUtils.uploadImage(
                      myAccount!.id, image!, context);
                  if (result != null) {
                    imagePath = result;
                  } else {
                    imagePath =
                        'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7';
                  }
                }

                Account updateAccount = Account(
                  id: myAccount!.id,
                  name: nameController.text,
                  userId: userIdController.text,
                  selfIntroduction: selfIntroductionController.text,
                  imagePath: imagePath,
                  lockAccount: isPrivate,
                  followMessage: followPrivate,
                  replyMessage: replyMessage,
                );

                Authentication.myAccount = updateAccount;
                var result = await UserFirestore.updataUser(updateAccount);
                if (result == true) {
                  navigateToPage(context, myAccount!.id, '1', false, false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text(
                '更新',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'アカウント非公開',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isPrivate,
                  onChanged: (bool value) async {
                    setState(() {
                      isPrivate = value;
                    });
                    await UserFirestore.updateLockAccount(
                        myAccount!.id, isPrivate);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'フォローメッセージON/OFF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: followPrivate,
                  onChanged: (bool value) async {
                    setState(() {
                      followPrivate = value;
                    });
                    await UserFirestore.updateFollowMessage(
                        myAccount!.id, followPrivate);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '返信メッセージON/OFF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: replyMessage,
                  onChanged: (bool value) async {
                    setState(() {
                      replyMessage = value;
                    });
                    await UserFirestore.replyMessage(
                        myAccount!.id, replyMessage);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '引用メッセージON/OFF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: quoteMessage,
                  onChanged: (bool value) async {
                    setState(() {
                      quoteMessage = value;
                    });
                    await UserFirestore.updateQuoteMessage(
                        myAccount!.id, quoteMessage);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'スターメッセージON/OFF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: starMessage,
                  onChanged: (bool value) async {
                    setState(() {
                      starMessage = value;
                    });
                    await UserFirestore.updateStarMessage(
                        myAccount!.id, starMessage);
                  },
                  activeColor: Colors.blue,
                ),
              ],
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
    required int currentCharCount,
    required ValueChanged<String> onChanged, // 追加
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
          maxLines: null,
          onChanged: onChanged, // 追加
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '現在の文字数: $currentCharCount',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
