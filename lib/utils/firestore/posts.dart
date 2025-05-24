import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';

// 投稿に関するプログラムFirestore
class PostFirestore {
  static final _firestoreInstance = FirebaseFirestore.instance;
  static final CollectionReference posts =
      _firestoreInstance.collection('posts');

  static Future<String?> addPost(Post newPost) async {
    try {
      // 新しい投稿データのマップを作成
      Map<String, dynamic> postData = {
        'content': newPost.content,
        'post_account_id': newPost.postAccountId,
        'post_user_id': newPost.postUserId,
        'created_time': Timestamp.now(),
        'media_url': newPost.mediaUrl,
        'is_video': newPost.isVideo,
        'post_id': '',
        'reply': newPost.reply,
        'reply_limit': false,
        'repost': newPost.repost,
        'category': newPost.category,
        'clip': false,
        'clipTime': null,
        'hide': false,
        'imageHeight': newPost.imageHeight,
        'imageWidth': newPost.imageWidth,
      };

      // Firestoreに投稿を追加し、その結果からドキュメントIDを取得
      DocumentReference docRef = await posts.add(postData);

      // 投稿データの 'post_id' フィールドをドキュメントIDで更新
      await docRef.update({
        'post_id': docRef.id,
      });

      print('投稿完了');
      return docRef.id; // 作成した投稿のドキュメントIDを返す
    } on FirebaseException catch (e) {
      print('投稿エラー: $e');
      return null;
    }
  }

  static Future<List<Post>> getPostsFromIds(List<String> ids) async {
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
          postUserId: data['post_user_id'],
          createdTime: data['created_time'],
          isVideo: data['is_video'] ?? false, // is_videoが存在しない場合はfalseを設定
          mediaUrl: (data['media_url'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList(), // リストに変換
          reply: data['reply'] ?? null,
          postId: data['post_id'] ?? '',
          repost: data['repost'] ?? null,
          category: data['category'] ?? null,
          hide: data['hide'] ?? false,
          clip: data['clip'] ?? false,
          clipTime: data['clipTime'] ?? null,
          imageHeight: data['imageHeight'] ?? null,
          imageWidth: data['imageWidth'] ?? null,
        );
        postList.add(post);
      }
      print('自分の投稿を取得');
      return postList;
    } on FirebaseException catch (e) {
      print('投稿取得エラー: $e');
      return []; // エラーが発生した場合でも空のリストを返す
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
