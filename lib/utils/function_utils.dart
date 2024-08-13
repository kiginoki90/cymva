import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FunctionUtils {
  static Future<dynamic> getImageFromGallery() async {
    ImagePicker picker = ImagePicker();

    final PickedFile = await picker.pickImage(source: ImageSource.gallery);
    return PickedFile;
    // if (PickedFile != null) {
    //   setState(() {
    //     image = File(PickedFile.path);
    //   });
    // }
  }

//FireStoreにデータをアップロード、そのダウンロードURLを取得するメソッド
  static Future<String> uploadImage(String uid, File image) async {
    //FirebaseStorage.instanceを使用して、Firebase Storageのインスタンスを取得
    //storageInstanceはFirebase Storageへのアクセスを可能にするオブジェクト
    final FirebaseStorage storageInstance = FirebaseStorage.instance;
    //storageInstance.ref()を使用して、Firebase Storageのルート参照を取得
    final Reference ref = storageInstance.ref();
    //ref.child(uid)を使用して、指定されたuid（ユーザーID）の下に画像を保存する参照を取得
    //putFile()メソッドを使用して、指定されたimageファイルをFirebaseにアップロード
    await ref.child(uid).putFile(image);
    String downloadUrl = await storageInstance.ref(uid).getDownloadURL();
    // print('image_path: $downloadUrl');
    return downloadUrl;
  }
}
