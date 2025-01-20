import 'package:cymva/view/account/post_item_account_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/favorite_post.dart';

class PostList extends StatefulWidget {
  final Account myAccount;
  final Account postAccount;

  const PostList({Key? key, required this.myAccount, required this.postAccount})
      : super(key: key);

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final FavoritePost _favoritePost = FavoritePost();
  final ScrollController _scrollController = ScrollController();
  List<Post> _allPosts = [];
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
  }

  Stream<List<Post>> _postStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postAccount.id)
        .collection('my_posts')
        .orderBy('created_time', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Post> posts = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['post_id'] as String;
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          posts.add(Post.fromMap(postData, documentSnapshot: postDoc));
        }
      }

      // clipがtrueのものをcreated_timeの昇順で取得
      final clipTruePosts = await _fetchPosts(true);
      // clipがfalseのものをcreated_timeの降順で取得
      final clipFalsePosts = await _fetchPosts(false);

      // clipTruePostsを先に追加し、その後にclipFalsePostsを追加
      posts = [...clipTruePosts, ...clipFalsePosts];

      return posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: StreamBuilder<List<Post>>(
            stream: _postStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('データの取得に失敗しました'));
              }

              if (snapshot.hasData) {
                _allPosts = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: _allPosts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _allPosts.length) {
                      return _hasMore
                          ? TextButton(
                              onPressed: _fetchMorePosts,
                              child: const Text("もっと読み込む"),
                            )
                          : const Center(child: Text("結果は以上です"));
                    }

                    final post = _allPosts[index];
                    // お気に入りユーザー数の初期化と更新
                    _favoritePost.favoriteUsersNotifiers[post.postId] ??=
                        ValueNotifier<int>(0);
                    _favoritePost.updateFavoriteUsersCount(post.postId);

                    return PostItetmAccounWidget(
                      post: post,
                      postAccount: widget.postAccount,
                      favoriteUsersNotifier:
                          _favoritePost.favoriteUsersNotifiers[post.postId]!,
                      isFavoriteNotifier: ValueNotifier<bool>(
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.postId),
                      ),
                      onFavoriteToggle: () => _favoritePost.toggleFavorite(
                        post.postId,
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.postId),
                      ),
                      replyFlag: ValueNotifier<bool>(false),
                      userId: widget.myAccount.id,
                    );
                  },
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    final clipTruePosts = await _fetchPosts(true);
    final clipFalsePosts = await _fetchPosts(false);

    if (clipTruePosts.isNotEmpty || clipFalsePosts.isNotEmpty) {
      setState(() {
        _allPosts.addAll([...clipTruePosts, ...clipFalsePosts]);
        if (_allPosts.isNotEmpty) {
          _lastDocument = _allPosts.last.documentSnapshot;
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
    }
  }

  Future<List<Post>> _fetchPosts(bool clip) async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postAccount.id)
        .collection('my_posts')
        .where('clip', isEqualTo: clip)
        .orderBy(clip ? 'clipTime' : 'created_time', descending: true)
        .limit(30);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final querySnapshot = await query.get();
    List<Post> posts = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final postId = data['post_id'] as String;
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        posts.add(Post.fromMap(postData, documentSnapshot: postDoc));
      }
    }
    return posts;
  }
}
