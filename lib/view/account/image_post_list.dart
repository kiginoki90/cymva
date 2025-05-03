import 'package:cymva/ad_widget.dart';
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
    // _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
    // _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
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
                    itemCount: model.postList.length +
                        (model.postList.length ~/ 7) +
                        1,
                    itemBuilder: (context, index) {
                      if (index ==
                          model.postList.length +
                              (model.postList.length ~/ 7)) {
                        return _isLoadingMore
                            ? const Center(child: Text(" Loading..."))
                            : const Center(child: Text("結果は以上です"));
                      }

                      if (index % 8 == 7) {
                        return BannerAdWidget() ??
                            SizedBox(height: 50); // 広告ウィジェットを表示
                      }

                      final postIndex = index - (index ~/ 8);
                      if (postIndex >= model.postList.length) {
                        return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                      }

                      final post = model.postList[postIndex];

                      // お気に入りユーザー数の初期化と更新
                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _bookmarkPost.updateBookmarkUsersCount(post.id);

                      return PostItetmAccounWidget(
                        post: post,
                        postAccount: widget.myAccount,
                        favoriteUsersNotifier:
                            _favoritePost.favoriteUsersNotifiers[post.id]!,
                        isFavoriteNotifier: ValueNotifier<bool>(
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        onFavoriteToggle: () => _favoritePost.toggleFavorite(
                          post.id,
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        bookmarkUsersNotifier:
                            _bookmarkPost.bookmarkUsersNotifiers[post.id]!,
                        isBookmarkedNotifier: ValueNotifier<bool>(
                          _bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                          post.id,
                          _bookmarkPost.bookmarkPostsNotifier.value
                              .contains(post.id),
                        ),
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.myAccount.id,
                      );
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
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .orderBy('created_time', descending: true)
        .limit(15);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      for (var doc in querySnapshot.docs) {
        final post = Post.fromDocument(doc);
        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
          posts.add(post);
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
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(15);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      for (var doc in querySnapshot.docs) {
        final post = Post.fromDocument(doc);
        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
          posts.add(post);
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
