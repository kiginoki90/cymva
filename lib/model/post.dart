import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String id;
  String content;
  String postAccountId;
  Timestamp? createdTime;
  String? mediaUrl;
  bool isVideo;

  Post({
    this.id = '',
    this.content = '',
    this.postAccountId = '',
    this.createdTime,
    this.mediaUrl,
    this.isVideo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'postAccountId': postAccountId,
      'createdTime': createdTime ?? FieldValue.serverTimestamp(),
      'mediaUrl': mediaUrl,
      'isVideo': isVideo,
    };
  }

  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      id: doc['id'],
      content: doc['content'],
      postAccountId: doc['postAccountId'],
      createdTime: doc['createdTime'],
      mediaUrl: doc['mediaUrl'],
      isVideo: doc['isVideo'],
    );
  }
}
