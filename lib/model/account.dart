import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  String id;
  String parents_id;
  String name;
  String imagePath;
  String selfIntroduction;
  String userId;
  Timestamp? createdTime;
  Timestamp? updatedTime;

  Account(
      {this.id = '',
      this.name = '',
      this.parents_id = '',
      this.imagePath = '',
      this.selfIntroduction = '',
      this.userId = '',
      this.createdTime,
      this.updatedTime});

  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      id: doc.id, // ドキュメントIDをidフィールドにセット
      parents_id: doc['parents_id'],
      name: doc['name'],
      imagePath: doc['image_path'],
      selfIntroduction: doc['self_introduction'],
      userId: doc['user_id'],
      createdTime: doc['created_time'],
      updatedTime: doc['updated_time'],
    );
  }

  // Firestoreに保存するためのMapに変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'parents_id': parents_id,
      'name': name,
      'image_path': imagePath,
      'self_introduction': selfIntroduction,
      'user_id': userId,
      'created_time': createdTime,
      'updated_time': updatedTime,
    };
  }
}
