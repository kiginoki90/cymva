import 'package:cymva/ad_widget.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/view/account/post_item_account_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PostList extends ConsumerStatefulWidget {
  final Account myAccount;
  final Account postAccount;
  final bool? withDelay;

  const PostList({
    Key? key,
    required this.myAccount,
    required this.postAccount,
    this.withDelay = false,
  }) : super(key: key);

  @override
  _PostListState createState() => _PostListState();
}

class _PostListState extends ConsumerState<PostList> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<Post> posts = [];
  bool _isLoading = true;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    posts = [];
    _loadPosts();
    _scrollController.addListener(_scrollListener);
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
      await ref.read(viewModelProvider).getPostsNext(widget.postAccount.id);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    await ref.read(viewModelProvider).getPosts(widget.postAccount.id);
  }

  Future<void> _refreshPosts() async {
    await ref.read(viewModelProvider).getPosts(widget.postAccount.id);
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
                : StreamBuilder<String?>(
                    stream: _userIdStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final myUserId = snapshot.data;

                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: model.postList.length +
                            (model.postList.length ~/ 10) +
                            1,
                        itemBuilder: (context, index) {
                          if (index ==
                              model.postList.length +
                                  (model.postList.length ~/ 10)) {
                            return _isLoadingMore
                                ? const Center(child: Text(" Loading..."))
                                : const Center(child: Text("結果は以上です"));
                          }

                          if (index % 8 == 7) {
                            return BannerAdWidget() ??
                                SizedBox(height: 50); // 広告ウィジェットを表示
                          }

                          final postIndex = index - (index ~/ 11);
                          if (postIndex >= model.postList.length) {
                            return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                          }

                          final post = model.postList[postIndex];

                          // post.postAccountIdとmyUserIdが一致しない場合は非表示
                          if (post.postAccountId != myUserId) {
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
                            postAccount: widget.postAccount,
                            favoriteUsersNotifier:
                                _favoritePost.favoriteUsersNotifiers[post.id]!,
                            isFavoriteNotifier: ValueNotifier<bool>(
                              _favoritePost.favoritePostsNotifier.value
                                  .contains(post.id),
                            ),
                            onFavoriteToggle: () =>
                                _favoritePost.toggleFavorite(
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
                            onBookMsrkToggle: () =>
                                _bookmarkPost.toggleBookmark(
                              post.id,
                              _bookmarkPost.bookmarkPostsNotifier.value
                                  .contains(post.id),
                            ),
                            replyFlag: ValueNotifier<bool>(false),
                            userId: widget.myAccount.id,
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Stream<String?> _userIdStream() async* {
    if (widget.withDelay == true) {
      await for (var user in FirebaseAuth.instance.userChanges()) {
        // ユーザーIDを取得
        String? userId = await storage.read(key: 'account_id') ?? user?.uid;
        yield userId;
      }
    } else {
      // withDelayがfalseの場合は現在のユーザーIDを1回だけ返す
      String? userId = widget.postAccount.id;
      yield userId;
    }
  }
}

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocumentTrue;
  DocumentSnapshot? _lastDocumentFalse;

  Future<List<Post>> getPosts(String userId) async {
    List<Post> posts = [];

    // clipがtrueの投稿を取得
    Query queryTrue = _firestore
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .where('clip', isEqualTo: true)
        .orderBy('clipTime', descending: true)
        .limit(15);

    final querySnapshotTrue = await queryTrue.get();
    if (querySnapshotTrue.docs.isNotEmpty) {
      _lastDocumentTrue = querySnapshotTrue.docs.last;
      List<Post> truePosts = querySnapshotTrue.docs.map((doc) {
        // final data = doc.data() as Map<String, dynamic>;
        return Post.fromDocument(doc);
      }).toList();
      posts.addAll(truePosts);
    }

    // clipがfalseの投稿を取得
    Query queryFalse = _firestore
        .collection('posts')
        .where('post_account_id', isEqualTo: userId)
        .where('clip', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .limit(15);

    final querySnapshotFalse = await queryFalse.get();
    if (querySnapshotFalse.docs.isNotEmpty) {
      _lastDocumentFalse = querySnapshotFalse.docs.last;
      List<Post> falsePosts = querySnapshotFalse.docs.map((doc) {
        return Post.fromDocument(doc);
      }).toList();
      posts.addAll(falsePosts);
    }

    if (posts.isEmpty) {
      print("No posts found.");
    }

    return posts;
  }

  Future<List<Post>> getPostsNext(String userId) async {
    List<Post> posts = [];

    // clipがtrueの投稿を取得
    if (_lastDocumentTrue != null) {
      Query queryTrue = _firestore
          .collection('posts')
          .where('post_account_id', isEqualTo: userId)
          .where('clip', isEqualTo: true)
          .orderBy('clipTime', descending: true)
          .startAfterDocument(_lastDocumentTrue!)
          .limit(15);

      final querySnapshotTrue = await queryTrue.get();
      if (querySnapshotTrue.docs.isNotEmpty) {
        _lastDocumentTrue = querySnapshotTrue.docs.last;
        List<Post> truePosts = querySnapshotTrue.docs.map((doc) {
          return Post.fromDocument(doc);
        }).toList();
        posts.addAll(truePosts);
      }
    }
    // clipがfalseの投稿を取得
    if (_lastDocumentFalse != null) {
      Query queryFalse = _firestore
          .collection('posts')
          .where('post_account_id', isEqualTo: userId)
          .where('clip', isEqualTo: false)
          .orderBy('created_time', descending: true)
          .startAfterDocument(_lastDocumentFalse!)
          .limit(15);

      final querySnapshotFalse = await queryFalse.get();
      if (querySnapshotFalse.docs.isNotEmpty) {
        _lastDocumentFalse = querySnapshotFalse.docs.last;
        List<Post> falsePosts = querySnapshotFalse.docs.map((doc) {
          return Post.fromDocument(doc);
        }).toList();
        posts.addAll(falsePosts);
      }
    }

    if (posts.isEmpty) {
      print("No posts found.");
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
