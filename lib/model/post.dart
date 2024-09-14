import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String id;
  String content;
  String postAccountId;
  Timestamp? createdTime;
  List<String>? mediaUrl;
  bool isVideo;
  String postId;
  String? reply;
  String? repost;
  String? category;

  Post({
    this.id = '',
    this.content = '',
    this.postAccountId = '',
    this.createdTime,
    this.mediaUrl,
    this.isVideo = false,
    this.postId = '',
    this.reply,
    this.repost,
    this.category,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'post_account_id': postAccountId, // Fixed key
      'created_time': createdTime ?? FieldValue.serverTimestamp(),
      'media_url': mediaUrl ?? [], // Ensure default empty list
      'is_video': isVideo,
      'post_id': postId,
      'reply': reply,
      'repost': repost,
      'category': category,
    };
  }

  // FirestoreドキュメントからPostを作成
  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Data extraction

    return Post(
      id: doc.id,
      content: data['content'] ?? '',
      postAccountId: data['post_account_id'] ?? '',
      createdTime: data['created_time'] as Timestamp?,
      mediaUrl: List<String>.from(data['media_url'] ?? []),
      isVideo: data['is_video'] ?? false,
      postId: data['post_id'] ?? '',
      reply: data['reply'] as String?,
      repost: data['repost'] as String?,
      category: data['category'] as String?,
    );
  }

  // Create a Post from a Map
  factory Post.fromMap(Map<String, dynamic> data) {
    return Post(
      content: data['content'] ?? '',
      postAccountId: data['post_account_id'] ?? '',
      createdTime: data['created_time'] as Timestamp?,
      mediaUrl: List<String>.from(data['media_url'] ?? []),
      isVideo: data['is_video'] ?? false,
      postId: data['post_id'] ?? '',
      reply: data['reply'] as String?,
      repost: data['repost'] as String?,
      category: data['category'] as String?,
    );
  }
}
