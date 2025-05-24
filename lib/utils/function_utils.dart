import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/navigation_bar.dart';
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
      showTopSnackBar(context, '画像が選択されていません', backgroundColor: Colors.red);
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
        showTopSnackBar(context, 'ファイルサイズが大きすぎます。5MB以下のファイルを選択してください。',
            backgroundColor: Colors.red);

        //OK
        final String userId = FirebaseAuth.instance.currentUser!.uid;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                NavigationBarPage(userId: userId, firstIndex: 1),
          ),
        );
      }

      return image;
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> uploadImage(
      String uid, File image, BuildContext context,
      {bool shouldGetHeight = false}) async {
    try {
      final FirebaseStorage storageInstance = FirebaseStorage.instance;

      // ファイル名 (8文字のランダム文字列)
      String shortFileName = 'img_${_generateRandomString(8)}.jpg';

      // Firebase Storage でのファイルパスを設定
      final Reference ref = storageInstance.ref().child('$uid/$shortFileName');

      // File を Uint8List に変換
      Uint8List imageBytes = await image.readAsBytes();

      int? imageWidth;
      int? imageHeight;
      if (shouldGetHeight) {
        // 画像の幅と高さを取得
        final decodedImage = await decodeImageFromList(imageBytes);
        imageWidth = decodedImage.width;
        imageHeight = decodedImage.height;
      }

      // メタデータを追加してファイルをアップロード
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // ダウンロードURLを取得
      String downloadUrl = await ref.getDownloadURL();

      // ダウンロードURLと画像の幅・高さを返す
      return {
        'downloadUrl': downloadUrl,
        'width': imageWidth,
        'height': imageHeight,
      };
    } catch (e) {
      print('画像のアップロード中にエラーが発生しました: $e');
      return null;
    }
  }

// 動画をアップロードするメソッド
  static Future<Map<String, dynamic>?> uploadVideo(
      String uid, File video, BuildContext context) async {
    try {
      final FirebaseStorage storageInstance = FirebaseStorage.instance;

      // ファイル名 (8文字のランダム文字列)
      String shortFileName = 'video_${_generateRandomString(8)}.mp4';

      // Firebase Storage でのファイルパスを設定
      final Reference ref = storageInstance.ref().child('$uid/$shortFileName');

      print('Uploading video to: $ref');

      // File を Uint8List に変換
      Uint8List videoBytes = await video.readAsBytes();

      int? imageWidth;
      int? imageHeight;

      // 動画の幅と高さを取得
      final VideoPlayerController controller =
          VideoPlayerController.file(video);
      await controller.initialize();
      imageWidth = controller.value.size.width.toInt();
      imageHeight = controller.value.size.height.toInt();
      await controller.dispose(); // 使用後はコントローラーを破棄

      // ファイルをアップロード
      await ref.putData(videoBytes, SettableMetadata(contentType: 'video/mp4'));

      // ダウンロードURLを取得
      String downloadUrl = await ref.getDownloadURL();

      // ダウンロードURLと動画の幅・高さを返す
      return {
        'downloadUrl': downloadUrl,
        'width': imageWidth,
        'height': imageHeight,
      };
    } catch (e) {
      print('動画のアップロード中にエラーが発生しました: $e');
      showTopSnackBar(context, '動画のアップロード中にエラーが発生しました',
          backgroundColor: Colors.red);
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
        showTopSnackBar(context, '画像の選択は最大50枚までです',
            backgroundColor: Colors.red);
        return pickedFiles.take(50).toList();
      }
    } else {
      if (pickedFiles != null && pickedFiles.length > 4) {
        showTopSnackBar(context, '画像の選択は最大4枚までです', backgroundColor: Colors.red);
        return pickedFiles.take(4).toList(); // 最大4枚を返す
      }
    }

    return pickedFiles;
  }

  // 画像またはビデオを選択するメソッド
  static Future<File?> getMedia(bool isVideo, context) async {
    File? pickedFile;
    if (isVideo) {
      final videoFile =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        // 動画のサイズを確認
        final file = File(videoFile.path);
        final fileSizeInBytes = await file.length();

        // 512MB (512 * 1024 * 1024 bytes) を超えているか確認
        if (fileSizeInBytes <= 512 * 1024 * 1024) {
          pickedFile = file; // サイズが適切であれば設定
        } else {
          showTopSnackBar(context, '動画のサイズが512MBを超えています。',
              backgroundColor: Colors.red);
          return null;
        }
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
