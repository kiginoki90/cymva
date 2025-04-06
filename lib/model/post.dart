import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String id;
  String content;
  String postAccountId;
  String postUserId;
  Timestamp? createdTime;
  List<String>? mediaUrl;
  bool isVideo;
  String postId;
  String? reply;
  String? repost;
  String? category;
  bool hide;
  bool clip;
  Timestamp? clipTime;
  DocumentSnapshot? documentSnapshot;
  bool closeComment;

  Post({
    this.id = '',
    this.content = '',
    this.postAccountId = '',
    this.postUserId = '',
    this.createdTime,
    this.mediaUrl,
    this.isVideo = false,
    this.postId = '',
    this.reply,
    this.repost,
    this.category,
    this.hide = false,
    this.clip = false,
    this.clipTime,
    this.documentSnapshot,
    this.closeComment = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'post_account_id': postAccountId,
      'post_user_id': postUserId,
      'created_time': createdTime ?? FieldValue.serverTimestamp(),
      'media_url': mediaUrl ?? [],
      'is_video': isVideo,
      'post_id': postId,
      'reply': reply,
      'repost': repost,
      'category': category,
      'hide': hide,
      'clip': clip,
      'clip_time': clipTime,
      'closeComment': closeComment,
    };
  }

  // FirestoreドキュメントからPostを作成
  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('データが存在しません');
    }

    return Post(
      id: doc.id,
      content: data['content'] ?? '',
      postAccountId: data['post_account_id'] ?? '',
      postUserId: data['post_user_id'] ?? '',
      createdTime: data['created_time'] as Timestamp?,
      mediaUrl: List<String>.from(data['media_url'] ?? []),
      isVideo: data['is_video'] ?? false,
      postId: data['post_id'] ?? '',
      reply: data['reply'] as String?,
      repost: data['repost'] as String?,
      category: data['category'] as String?,
      hide: data.containsKey('hide') ? data['hide'] as bool : false,
      clip: data.containsKey('clip') ? data['clip'] as bool : false,
      clipTime: data['clip_time'] as Timestamp?,
      documentSnapshot: doc,
      closeComment: data['closeComment'] ?? false,
    );
  }

  // factory Post.fromMap(Map<String, dynamic> data,
  //     {DocumentSnapshot? documentSnapshot}) {
  //   return Post(
  //     id: documentSnapshot?.id ?? data['id'] ?? '',
  //     content: data['content'] ?? '',
  //     postAccountId: data['post_account_id'] ?? '',
  //     postUserId: data['post_user_id'] ?? '',
  //     createdTime: data['created_time'] as Timestamp?,
  //     mediaUrl: List<String>.from(data['media_url'] ?? []),
  //     isVideo: data['is_video'] ?? false,
  //     postId: data['post_id'] ?? '',
  //     reply: data['reply'] as String?,
  //     repost: data['repost'] as String?,
  //     category: data['category'] as String?,
  //     hide: data.containsKey('hide') ? data['hide'] as bool : false,
  //     clip: data.containsKey('clip') ? data['clip'] as bool : false,
  //     clipTime: data['clip_time'] as Timestamp?,
  //     documentSnapshot: documentSnapshot,
  //     closeComment: data['closeComment'] ?? false,
  //   );
  // }
}
