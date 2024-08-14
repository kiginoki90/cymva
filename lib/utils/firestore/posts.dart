import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';

//投稿に関するプログラムFirestore
class PostFirestore {
  static final _firestoreInstance = FirebaseFirestore.instance;
  static final CollectionReference posts =
      _firestoreInstance.collection('posts');

  static Future<dynamic> addPost(Post newPost) async {
    try {
      final CollectionReference _userPost = _firestoreInstance
          .collection('users')
          .doc(newPost.postAccountId)
          .collection('my_posts');

      var result = await posts.add({
        'content': newPost.content,
        'post_account_id': newPost.postAccountId,
        'created_time': Timestamp.now(),
        'media_url': newPost.mediaUrl,
        'is_video': newPost.isVideo,
      });

      await _userPost.doc(result.id).set({
        'post_id': result.id,
        'created_time': Timestamp.now(),
      });

      // favorite_users サブコレクションを空で作成（スター一覧）
      await result.collection('favorite_users').doc('placeholder').set({});

      print('投稿完了');
      return true;
    } on FirebaseException catch (e) {
      print('投稿エラー: $e');
      return false;
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
          mediaUrl: data['media_url'], // media_urlが存在しない場合はnullになる
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
