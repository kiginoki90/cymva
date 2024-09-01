import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String id;
  String content;
  String postAccountId;
  Timestamp? createdTime;
  String? mediaUrl;
  bool isVideo;
  String postId;
  String? reply;
  String? repost;

  Post({
    this.id = '',
    this.content = '',
    this.postAccountId = '',
    this.createdTime,
    this.mediaUrl,
    this.isVideo = false,
    this.postId = '',
    this.reply,
    this.repost = '',
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
      'postId': postId,
      'reply': reply,
      'repost': repost,
    };
  }

  // Create a Post from Firestore document
  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      id: doc.id,
      content: doc['content'],
      postAccountId: doc['post_account_id'],
      createdTime: doc['created_time'],
      mediaUrl: doc['media_url'],
      isVideo: doc['is_video'],
      postId: doc['post_id'] ?? '',
      reply: doc['reply'] ?? null,
      repost: doc['repost'] ?? null,
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
      postId: data['post_id'] ?? '',
      reply: data['reply'] ?? null,
      repost: data['repost'] ?? '',
    );
  }
}
