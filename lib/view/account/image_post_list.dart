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
        !_isLoadingMore &&
        ref.read(viewModelProvider).hasMorePosts) {
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
                    itemCount: model.postList.length,
                    itemBuilder: (context, index) {
                      final post = model.postList[index];

                      // 投稿者と一致しない場合は非表示
                      if (post.postAccountId != widget.myAccount.id) {
                        return Container();
                      }

                      // メディアURLが空の場合はスキップ
                      if (post.mediaUrl == null || post.mediaUrl!.isEmpty) {
                        return Container();
                      }

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
    List<Post> posts = [];

    // created_timeで新しい順に投稿を取得
    Query query = _firestore
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .orderBy('created_time', descending: true)
        .limit(30);

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      posts = querySnapshot.docs.map((doc) {
        return Post.fromDocument(doc);
      }).toList();
    } else {
      print("No posts found.");
    }

    return posts;
  }

  Future<List<Post>> getPostsNext(String userId) async {
    if (_lastDocument == null) {
      print("No last document available for pagination.");
      return [];
    }

    List<Post> posts = [];

    // created_timeで新しい順に次の投稿を取得
    Query query = _firestore
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(30);

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last; // 次のページのために更新
      posts = querySnapshot.docs.map((doc) {
        return Post.fromDocument(doc);
      }).toList();
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
  bool hasMorePosts = true; // 全ての投稿を取得済みかどうかを管理するフラグ

  Future<void> getPosts(String userId) async {
    postList = [];
    hasMorePosts = true; // 初期化時にフラグをリセット
    final dbManager = ref.read(dbManagerProvider);

    currentPostList = await dbManager.getPosts(userId);
    postList.addAll(currentPostList);
    notifyListeners();
  }

  Future<void> getPostsNext(String userId) async {
    if (!hasMorePosts) return; // 全ての投稿を取得済みの場合は処理を中断

    currentPostList = await ref.read(dbManagerProvider).getPostsNext(userId);
    if (currentPostList.isNotEmpty) {
      postList.addAll(currentPostList);
    } else {
      hasMorePosts = false; // 追加の投稿がない場合はフラグを更新
    }
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
