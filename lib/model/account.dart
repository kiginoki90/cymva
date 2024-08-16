import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  String id;
  String name;
  String imagePath;
  String selfIntroduction;
  String userId;
  Timestamp? createdTime;
  Timestamp? updatedTime;

  Account(
      {this.id = '',
      this.name = '',
      this.imagePath = '',
      this.selfIntroduction = '',
      this.userId = '',
      this.createdTime,
      this.updatedTime});

  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      id: doc.id, // ドキュメントIDをidフィールドにセット
      name: doc['name'],
      imagePath: doc['image_path'],
      selfIntroduction: doc['self_introduction'],
      userId: doc['user_id'],
      createdTime: doc['created_time'],
      updatedTime: doc['updated_time'],
    );
  }
}
