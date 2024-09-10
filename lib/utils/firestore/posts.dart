import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';

// 投稿に関するプログラムFirestore
class PostFirestore {
  static final _firestoreInstance = FirebaseFirestore.instance;
  static final CollectionReference posts =
      _firestoreInstance.collection('posts');

  static Future<String?> addPost(Post newPost) async {
    try {
      final CollectionReference _userPost = _firestoreInstance
          .collection('users')
          .doc(newPost.postAccountId)
          .collection('my_posts');

      // 新しい投稿データのマップを作成
      Map<String, dynamic> postData = {
        'content': newPost.content,
        'post_account_id': newPost.postAccountId,
        'created_time': Timestamp.now(),
        'media_url': newPost.mediaUrl,
        'is_video': newPost.isVideo,
        'post_id': '',
        'reply': newPost.reply,
        'repost': newPost.repost,
      };

      // Firestoreに投稿を追加し、その結果からドキュメントIDを取得
      DocumentReference docRef = await posts.add(postData);

      // 投稿データの 'post_id' フィールドをドキュメントIDで更新
      await docRef.update({
        'post_id': docRef.id,
      });

      // ユーザーの投稿サブコレクションにドキュメントを追加
      await _userPost.doc(docRef.id).set({
        'post_id': docRef.id,
        'created_time': Timestamp.now(),
      });

      // // favorite_users サブコレクションを空で作成（スター一覧）
      // await docRef.collection('favorite_users').doc('placeholder').set({});

      print('投稿完了');
      return docRef.id; // 作成した投稿のドキュメントIDを返す
    } on FirebaseException catch (e) {
      print('投稿エラー: $e');
      return null;
    }
  }

  static Future<List<Post>?> getPostsFromIds(List<String> ids) async {
    List<Post> postList = [];
    try {
      for (String id in ids) {
        var doc = await posts.doc(id).get();
        if (!doc.exists) {
          // IDが見つからなかった場合はスキップ
          continue;
        }
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Post post = Post(
          id: doc.id,
          content: data['content'],
          postAccountId: data['post_account_id'],
          createdTime: data['created_time'],
          isVideo: data['is_video'] ?? false, // is_videoが存在しない場合はfalseを設定
          mediaUrl: (data['media_url'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList(), // リストに変換
          reply: data['reply'] ?? null,
          postId: data['post_id'] ?? '',
          repost: data['repost'] ?? null,
        );
        postList.add(post);
      }
      print('自分の投稿を取得');
      return postList;
    } on FirebaseException catch (e) {
      print('投稿取得エラー: $e');
      return null;
    }
  }

  static Future<dynamic> deletePosts(String accountId) async {
    final CollectionReference _userPosts = _firestoreInstance
        .collection('users')
        .doc(accountId)
        .collection('my_posts');
    var snapshot = await _userPosts.get();
    snapshot.docs.forEach((doc) async {
      await posts.doc(doc.id).delete();
      _userPosts.doc(doc.id).delete();
    });
  }
}
