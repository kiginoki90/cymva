import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/view/account/post_item_account_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImagePostList extends ConsumerStatefulWidget {
  final Account myAccount;

  const ImagePostList({Key? key, required this.myAccount}) : super(key: key);

  @override
  _ImagePostListState createState() => _ImagePostListState();
}

class _ImagePostListState extends ConsumerState<ImagePostList> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_scrollListener);
    _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
    _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });
      await ref.read(viewModelProvider).getPostsNext(widget.myAccount.id);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    await ref.read(viewModelProvider).getPosts(widget.myAccount.id);
  }

  Future<void> _refreshPosts() async {
    await ref.read(viewModelProvider).getPosts(widget.myAccount.id);
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            child: model.postList.isEmpty
                ? const Center(child: Text("まだ投稿がありません"))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: model.postList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == model.postList.length) {
                        return _isLoadingMore
                            ? const Center(child: Text(" Loading..."))
                            : const Center(child: Text("結果は以上です"));
                      }

                      if (index < model.postList.length) {
                        final post = model.postList[index];

                        // お気に入りユーザー数の初期化と更新
                        _favoritePost.favoriteUsersNotifiers[post.postId] ??=
                            ValueNotifier<int>(0);
                        _favoritePost.updateFavoriteUsersCount(post.postId);

                        _bookmarkPost.bookmarkUsersNotifiers[post.postId] ??=
                            ValueNotifier<int>(0);
                        _bookmarkPost.updateBookmarkUsersCount(post.postId);

                        return PostItetmAccounWidget(
                          post: post,
                          postAccount: widget.myAccount,
                          favoriteUsersNotifier: _favoritePost
                              .favoriteUsersNotifiers[post.postId]!,
                          isFavoriteNotifier: ValueNotifier<bool>(
                            _favoritePost.favoritePostsNotifier.value
                                .contains(post.postId),
                          ),
                          onFavoriteToggle: () => _favoritePost.toggleFavorite(
                            post.postId,
                            _favoritePost.favoritePostsNotifier.value
                                .contains(post.postId),
                          ),
                          bookmarkUsersNotifier: _bookmarkPost
                              .bookmarkUsersNotifiers[post.postId]!,
                          isBookmarkedNotifier: ValueNotifier<bool>(
                            _bookmarkPost.bookmarkPostsNotifier.value
                                .contains(post.postId),
                          ),
                          onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                            post.postId,
                            _bookmarkPost.bookmarkPostsNotifier.value
                                .contains(post.postId),
                          ),
                          replyFlag: ValueNotifier<bool>(false),
                          userId: widget.myAccount.id,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<Post>> getPosts(String userId) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('my_posts')
        .orderBy('created_time', descending: true)
        .limit(15);

    // if (_lastDocument != null) {
    //   query = query.startAfterDocument(_lastDocument!);
    // }

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['post_id'] as String;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final post = Post.fromMap(postData, documentSnapshot: postDoc);
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
            posts.add(post);
          }
        }
      }
    } else {
      print("No posts found.");
    }
    return posts;
  }

  Future<List<Post>> getPostsNext(String userId) async {
    if (_lastDocument == null) return [];

    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('my_posts')
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(15);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['post_id'] as String;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final post = Post.fromMap(postData, documentSnapshot: postDoc);
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
            posts.add(post);
          }
        }
      }
    } else {
      print("No more posts found.");
    }
    return posts;
  }
}

final viewModelProvider =
    ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

class ViewModel extends ChangeNotifier {
  ViewModel(this.ref);

  final Ref ref;
  List<Post> postList = [];
  List<Post> currentPostList = [];

  Future<void> getPosts(String userId) async {
    postList = [];
    final dbManager = ref.read(dbManagerProvider);

    currentPostList = await dbManager.getPosts(userId);
    postList.addAll(currentPostList);
    notifyListeners();
  }

  Future<void> getPostsNext(String userId) async {
    currentPostList = await ref.read(dbManagerProvider).getPostsNext(userId);
    if (currentPostList.isNotEmpty) {
      postList.addAll(currentPostList);
    }
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
