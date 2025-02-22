import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Account {
  int admin;
  String id;
  String parents_id;
  String name;
  String imagePath;
  String? backgroundImagePath;
  String selfIntroduction;
  String userId;
  Timestamp? createdTime;
  Timestamp? updatedTime;
  bool lockAccount;
  bool followMessage;
  bool replyMessage;

  Account({
    this.admin = 3,
    this.id = '',
    this.name = '',
    this.parents_id = '',
    this.imagePath = '',
    this.backgroundImagePath = '',
    this.selfIntroduction = '',
    this.userId = '',
    this.createdTime,
    this.updatedTime,
    this.lockAccount = false,
    this.followMessage = true,
    this.replyMessage = true,
  });

  factory Account.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Account(
      admin: data['admin'],
      id: doc.id,
      parents_id: data['parents_id'],
      name: data['name'],
      imagePath: data['image_path'],
      backgroundImagePath: data['background_image_path'] ?? '',
      selfIntroduction: data['self_introduction'],
      userId: data['user_id'],
      createdTime: data['created_time'],
      updatedTime: data['updated_time'],
      lockAccount: data['lock_account'] ?? true,
      replyMessage: data['replyMessage'] ?? true,
    );
  }

  // Firestoreに保存するためのMapに変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admin': admin,
      'parents_id': parents_id,
      'name': name,
      'image_path': imagePath,
      'self_introduction': selfIntroduction,
      'user_id': userId,
      'created_time': createdTime,
      'updated_time': updatedTime,
      'lock_account': lockAccount,
      'follow_message': followMessage,
      'replyMessage': replyMessage,
    };
  }
}
