import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String id;
  String content;
  String postAccountId;
  Timestamp? createdTime;
  String? mediaUrl;
  bool isVideo;
  String reply;
  String postId;

  Post({
    this.id = '',
    this.content = '',
    this.postAccountId = '',
    this.createdTime,
    this.mediaUrl,
    this.isVideo = false,
    this.reply = '',
    this.postId = '',
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'postAccountId': postAccountId,
      'createdTime': createdTime ?? FieldValue.serverTimestamp(),
      'mediaUrl': mediaUrl,
      'isVideo': isVideo,
      'reply': reply,
      'postId': postId,
    };
  }

  // Create a Post from Firestore document
  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      id: doc['id'],
      content: doc['content'],
      postAccountId: doc['post_account_id'],
      createdTime: doc['created_time'],
      mediaUrl: doc['media_url'],
      isVideo: doc['is_video'],
      reply: doc['reply'] ?? '',
      postId: doc['post_id'] ?? '',
    );
  }

  // Create a Post from a Map
  factory Post.fromMap(Map<String, dynamic> data) {
    return Post(
      id: data['id'] ?? '',
      content: data['content'] ?? '',
      postAccountId: data['post_account_id'] ?? '',
      createdTime: data['created_time'],
      mediaUrl: data['media_url'],
      isVideo: data['is_video'] ?? false,
      reply: data['reply'] ?? '',
      postId: data['post_id'] ?? '',
    );
  }
}
