import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cymva/view/account/account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FunctionUtils {
  // static Future<dynamic> getImageFromGallery() async {
  //   ImagePicker picker = ImagePicker();

  //   final PickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   return PickedFile;
  //   // if (PickedFile != null) {
  //   //   setState(() {
  //   //     image = File(PickedFile.path);
  //   //   });
  //   // }
  // }

  static Future<List<File>?> getImagesFromGallery(BuildContext context) async {
    ImagePicker picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(); // 複数枚の画像を選択

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      return pickedFiles.map((file) => File(file.path)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像が選択されていません')),
      );
      return null;
    }
  }

  // ギャラリーから画像を取得し、ファイルサイズが適切かチェック
  static Future<File?> getImageFromGallery(BuildContext context) async {
    ImagePicker picker = ImagePicker();
    final PickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (PickedFile != null) {
      File image = File(PickedFile.path);

      // ファイルサイズをチェック (上限: 5MB)
      final int fileSize = await image.length();
      final int maxSize = 5 * 1024 * 1024; // 5MBの上限を設定
      if (fileSize > maxSize) {
        // ファイルサイズが大きすぎる場合はエラーを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルサイズが大きすぎます。5MB以下のファイルを選択してください。')),
        );
        final String userId = FirebaseAuth.instance.currentUser!.uid;
        // 遷移先のユーザーIDなどのパラメータを必要に応じて設定
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                AccountPage(userId: userId), // 適切なユーザーIDに置き換えてください
          ),
        );
      }

      return image;
    } else {
      return null;
    }
  }

  static Future<String?> uploadImage(
      String uid, File image, BuildContext context) async {
    try {
      final FirebaseStorage storageInstance = FirebaseStorage.instance;

      // より短いファイル名 (4 文字)
      String shortFileName = 'img_${_generateRandomString(4)}.jpg';

      // Firebase Storage でのファイルパスを設定
      final Reference ref = storageInstance.ref().child('$uid/$shortFileName');

      print('Uploading to: $ref');
      // File を Uint8List に変換
      Uint8List imageBytes = image.readAsBytesSync();
      await ref.putData(imageBytes);

      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('画像のアップロード中にエラーが発生しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像のアップロード中にエラーが発生しました')),
      );
      return null;
    }
  }

  // 6文字のランダムな文字列を生成するヘルパーメソッド
  static String _generateRandomString(int length) {
    const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(length,
        (_) => characters.codeUnitAt(random.nextInt(characters.length))));
  }
}
