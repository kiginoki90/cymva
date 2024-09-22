import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cymva/view/account/account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class FunctionUtils {
  // 複数の画像を選択するメソッド
  static Future<List<File>?> getImagesFromGallery(BuildContext context) async {
    ImagePicker picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(); // 複数枚の画像を選択

    if (pickedFiles.isNotEmpty) {
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File image = File(pickedFile.path);

      // ファイルサイズをチェック (上限: 5MB)
      final int fileSize = await image.length();
      final int maxSize = 5 * 1024 * 1024; // 5MBの上限を設定
      if (fileSize > maxSize) {
        // ファイルサイズが大きすぎる場合はエラーを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルサイズが大きすぎます。5MB以下のファイルを選択してください。')),
        );

        //OK
        final String userId = FirebaseAuth.instance.currentUser!.uid;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AccountPage(userId: userId),
          ),
        );
      }

      return image;
    } else {
      return null;
    }
  }

  // 画像をアップロードするメソッド
  static Future<String?> uploadImage(
      String uid, File image, BuildContext context) async {
    try {
      final FirebaseStorage storageInstance = FirebaseStorage.instance;

      // ファイル名 (8文字のランダム文字列)
      String shortFileName = 'img_${_generateRandomString(8)}.jpg';

      // Firebase Storage でのファイルパスを設定
      final Reference ref = storageInstance.ref().child('$uid/$shortFileName');

      print('Uploading to: $ref');

      // File を Uint8List に変換
      Uint8List imageBytes = await image.readAsBytes();

      // ファイルをアップロード
      await ref.putData(imageBytes);

      // ダウンロードURLを取得
      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl; // 正常にアップロードされた場合はURLを返す
    } catch (e) {
      print('画像のアップロード中にエラーが発生しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像のアップロード中にエラーが発生しました')),
      );
      return null; // エラー時はnullを返す
    }
  }

  // 6文字のランダムな文字列を生成するヘルパーメソッド
  static String _generateRandomString(int length) {
    const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(length,
        (_) => characters.codeUnitAt(random.nextInt(characters.length))));
  }

  // AssetからFileに変換するヘルパーメソッド
  static Future<File> xFileToFile(XFile xFile) async {
    final byteData = await xFile.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${xFile.name}');
    return await tempFile.writeAsBytes(byteData);
  }

// 複数の画像を選択するメソッド
  static Future<List<XFile>?> selectImages(
      BuildContext context, category) async {
    final List<XFile>? pickedFiles = await ImagePicker().pickMultiImage();

    if (category == '漫画') {
      if (pickedFiles != null && pickedFiles.length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択は最大50枚までです')),
        );
        return pickedFiles.take(50).toList();
      }
    } else {
      if (pickedFiles != null && pickedFiles.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択は最大4枚までです')),
        );
        return pickedFiles.take(4).toList(); // 最大4枚を返す
      }
    }

    return pickedFiles;
  }

  // 画像またはビデオを選択するメソッド
  static Future<File?> getMedia(bool isVideo) async {
    File? pickedFile;
    if (isVideo) {
      final videoFile =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        pickedFile = File(videoFile.path);
      }
    } else {
      final imageFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (imageFile != null) {
        pickedFile = File(imageFile.path);
      }
    }
    return pickedFile;
  }

  // VideoPlayerControllerを取得するメソッド
  static Future<VideoPlayerController?> getVideoController(
      File mediaFile) async {
    VideoPlayerController controller = VideoPlayerController.file(mediaFile);
    await controller.initialize();
    return controller;
  }
}
