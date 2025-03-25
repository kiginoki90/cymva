import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/widget_utils.dart';
import 'package:flutter/services.dart';

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController userIdController = TextEditingController();
  TextEditingController selfIntroductionController = TextEditingController();
  File? image;

  String? errorMessage;
  int selfIntroCharCount = 0; // 自己紹介の現在の文字数
  int existingAccountCount = 0; // 同じメールアドレスで作成されたアカウント数

  @override
  void initState() {
    super.initState();
    _checkExistingAccounts();
    selfIntroductionController.addListener(() {
      setState(() {
        selfIntroCharCount = selfIntroductionController.text.length;
      });
    });
  }

  // 同じメールアドレスで作成されたアカウントの数を確認
  Future<void> _checkExistingAccounts() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      existingAccountCount =
          await UserFirestore.getAccountCountByParentsId(currentUser.uid);
      print(existingAccountCount);
      setState(() {});
    }
  }

  // user_idの重複確認
  Future<bool> isUserIdUnique(String userId) async {
    var result = await UserFirestore.getUserByUserId(userId);
    return result == null; // 結果がnullならそのuser_idはユニーク
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WidgetUtils.createAppBer('アカウント追加'),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(height: 30),
              GestureDetector(
                onTap: () async {
                  var result = await FunctionUtils.getImageFromGallery(
                    context,
                  );
                  if (result != null) {
                    setState(() {
                      image = File(result.path);
                    });
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: image == null
                        ? null
                        : DecorationImage(
                            image: FileImage(image!),
                            fit: BoxFit.cover,
                          ),
                    color: Colors.grey[300],
                  ),
                  child: image == null ? Icon(Icons.add) : null,
                ),
              ),
              _buildTextField(nameController, '名前', maxLength: 35),
              SizedBox(height: 20),
              _buildTextField(userIdController, 'ユーザーID', maxLength: 30),
              SizedBox(height: 20),
              _buildSelfIntroductionField(),
              if (errorMessage != null) ...[
                SizedBox(height: 10),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ],
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: existingAccountCount >= 3 ? null : _addAccount,
                child: Text('アカウントを追加'),
              ),
              if (existingAccountCount >= 3)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'これ以上アカウントを追加できません。同じメールアドレスで3つまでアカウントを作成できます。',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 共通のテキストフィールドビルダー
  Widget _buildTextField(TextEditingController controller, String hintText,
      {bool obscureText = false, int? maxLength}) {
    return Container(
      width: 300,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(hintText: hintText),
        maxLength: maxLength,
        inputFormatters: [
          LengthLimitingTextInputFormatter(50),
        ],
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

// アカウント追加処理
  Future<void> _addAccount() async {
    await _checkExistingAccounts(); // 既存アカウント数を再確認
    if (nameController.text.isNotEmpty &&
        userIdController.text.isNotEmpty &&
        selfIntroductionController.text.isNotEmpty) {
      bool isUnique = await isUserIdUnique(userIdController.text);
      if (userIdController.text.length < 2) {
        setState(() {
          errorMessage = 'ユーザーIDは2文字以上で入力してください';
        });
        return;
      }
      if (!isUnique) {
        setState(() {
          errorMessage = 'そのユーザーIDは既に使われています';
        });
        return;
      }

      if (existingAccountCount >= 3) {
        setState(() {
          errorMessage = 'これ以上アカウントを追加できません。';
        });
        return;
      }

      try {
        // Firestoreインスタンスを取得
        final FirebaseFirestore firestore = FirebaseFirestore.instance;

        final CollectionReference users = firestore.collection('users');

        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // 現在のユーザーのドキュメントを取得
          DocumentSnapshot currentUserDoc =
              await users.doc(currentUser.uid).get();

          // data()の戻り値をマップにキャスト
          Map<String, dynamic>? userData =
              currentUserDoc.data() as Map<String, dynamic>?;

          // parents_idを取得
          String parentsId = userData?['parents_id'] ?? currentUser.uid;

          // 画像をアップロード
          String? imagePath = image != null
              ? await FunctionUtils.uploadImage(
                  currentUser.uid, image!, context)
              : null;

          // Firestoreに新しいアカウント情報を保存（自動生成されたIDを使用）
          Account newAccount = Account(
            id: '', // 自動生成されるため空文字を設定
            name: nameController.text,
            userId: userIdController.text,
            selfIntroduction: selfIntroductionController.text,
            imagePath: imagePath ?? '',
            createdTime: Timestamp.now(),
            parents_id: parentsId,
          );

          // Firestoreにアカウントを追加
          bool firestoreResult =
              await UserFirestore.addAdditionalAccountWithAutoId(newAccount);

          if (firestoreResult) {
            _showSuccessMessage();
          } else {
            setState(() {
              errorMessage = 'アカウント追加に失敗しました。';
            });
          }
        }
      } catch (e) {
        setState(() {
          errorMessage = 'アカウント追加に失敗しました: ${e.toString()}';
        });
      }
    } else {
      setState(() {
        errorMessage = '全ての項目を入力してください';
      });
    }
  }

  // 成功メッセージを表示
  void _showSuccessMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('成功'),
          content: Text('アカウントの追加が成功しました。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ダイアログを閉じる
                Navigator.pop(context); // 前の画面に戻る
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
