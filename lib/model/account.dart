import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Account {
  int admin;
  String id;
  String parents_id;
  String name;
  String imagePath;
  String selfIntroduction;
  String userId;
  Timestamp? createdTime;
  Timestamp? updatedTime;
  bool lockAccount;

  Account({
    this.admin = 3,
    this.id = '',
    this.name = '',
    this.parents_id = '',
    this.imagePath = '',
    this.selfIntroduction = '',
    this.userId = '',
    this.createdTime,
    this.updatedTime,
    this.lockAccount = false,
  });

  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      admin: doc['admin'],
      id: doc.id, // ドキュメントIDをidフィールドにセット
      parents_id: doc['parents_id'],
      name: doc['name'],
      imagePath: doc['image_path'],
      selfIntroduction: doc['self_introduction'],
      userId: doc['user_id'],
      createdTime: doc['created_time'],
      updatedTime: doc['updated_time'],
      lockAccount: doc['lock_account'],
    );
  }

  // Firestoreに保存するためのMapに変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'admin': admin,
      'parents_id': parents_id,
      'name': name,
      'image_path': imagePath,
      'self_introduction': selfIntroduction,
      'user_id': userId,
      'created_time': createdTime,
      'updated_time': updatedTime,
      'lock_account': lockAccount,
    };
  }
}
