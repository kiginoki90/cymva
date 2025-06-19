import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/ad_widget.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';

// タイムライン表示ページ
class TimeLinePage extends ConsumerStatefulWidget {
  final String userId;
  const TimeLinePage({
    super.key,
    required this.userId,
  });

  @override
  _TimeLinePageState createState() => _TimeLinePageState();
}

class _TimeLinePageState extends ConsumerState<TimeLinePage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  bool _isLoadingMore = false;
  DateTime? _startTime; // 開始時刻を記録する変数

  // ValueNotifierを再利用するためのマップ
  final Map<String, ValueNotifier<int>> _favoriteUsersNotifiers = {};
  final Map<String, ValueNotifier<int>> _bookmarkUsersNotifiers = {};
  final Map<String, ValueNotifier<bool>> _isFavoriteNotifiers = {};
  final Map<String, ValueNotifier<bool>> _isBookmarkedNotifiers = {};

  @override
  bool get wantKeepAlive => true; // ページの状態を保持

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now(); // 開始時刻を記録
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(viewModelProvider).getPosts(widget.userId);
      final endTime = DateTime.now(); // 終了時刻を記録
      final duration = endTime.difference(_startTime!); // 処理時間を計算
      print('TimeLinePageの表示時間: ${duration.inMilliseconds}ミリ秒');
    });
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
      await ref.read(viewModelProvider).getPostsNext(widget.userId);
      setState(() {
        _isLoadingMore = false;
      });
    }

    if (_scrollController.offset >= 600) {
      _showScrollToTopButton.value = true;
    } else {
      _showScrollToTopButton.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin を使用する場合に必要
    final model = ref.watch(viewModelProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: RefreshIndicator(
                onRefresh: () => model.getPosts(widget.userId),
                child: model.isFirstLoad && model.isLoading
                    ? const Center(child: Text("データ取得中..."))
                    : model.stackedPostList.isEmpty
                        ? const Center(child: Text("データがありません"))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: model.stackedPostList.length +
                                (model.stackedPostList.length ~/ 7) +
                                1,
                            itemBuilder: (context, index) {
                              if (index ==
                                  model.stackedPostList.length +
                                      (model.stackedPostList.length ~/ 7)) {
                                return _isLoadingMore
                                    ? const Center(child: Text("Loading..."))
                                    : const Center(child: Text("結果は以上です"));
                              }

                              if (index % 8 == 7) {
                                return BannerAdWidget() ??
                                    const SizedBox(height: 50);
                              }

                              final postIndex = index - (index ~/ 8);
                              if (postIndex >= model.stackedPostList.length) {
                                return Container();
                              }

                              final postDoc = model.stackedPostList[postIndex];
                              final post = Post.fromDocument(postDoc);
                              final postAccount =
                                  model.postUserMap[post.postAccountId];

                              if (postAccount == null ||
                                  postAccount.lockAccount ||
                                  model.blockedAccounts
                                      .contains(postAccount.id)) {
                                return Container();
                              }

                              _favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              _bookmarkUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _bookmarkPost.updateBookmarkUsersCount(post.id);

                              _isFavoriteNotifiers[post.id] ??=
                                  ValueNotifier<bool>(
                                _favoritePost.favoritePostsNotifier.value
                                    .contains(post.id),
                              );

                              _isBookmarkedNotifiers[post.id] ??=
                                  ValueNotifier<bool>(
                                _bookmarkPost.bookmarkPostsNotifier.value
                                    .contains(post.id),
                              );

                              return PostItemWidget(
                                key: PageStorageKey(post.id),
                                post: post,
                                postAccount: postAccount,
                                favoriteUsersNotifier:
                                    _favoriteUsersNotifiers[post.id]!,
                                isFavoriteNotifier:
                                    _isFavoriteNotifiers[post.id]!,
                                onFavoriteToggle: () =>
                                    _favoritePost.toggleFavorite(
                                  post.id,
                                  _isFavoriteNotifiers[post.id]!.value,
                                ),
                                replyFlag: ValueNotifier<bool>(false),
                                bookmarkUsersNotifier:
                                    _bookmarkUsersNotifiers[post.id]!,
                                isBookmarkedNotifier:
                                    _isBookmarkedNotifiers[post.id]!,
                                onBookMsrkToggle: () =>
                                    _bookmarkPost.toggleBookmark(
                                  post.id,
                                  _isBookmarkedNotifiers[post.id]!.value,
                                ),
                                userId: widget.userId,
                              );
                            },
                          ),
              ),
            ),
          ),
          Positioned(
            bottom: 230.0,
            right: 16.0,
            child: GestureDetector(
              onTap: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.lightBlue, width: 2.0),
                  color: Colors.transparent,
                ),
                child: const Icon(
                  Icons.keyboard_double_arrow_up,
                  color: Colors.lightBlue,
                  size: 40.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// DbManager クラス
class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<QueryDocumentSnapshot>> getPosts() async {
    Query query = _firestore
        .collection('posts')
        .where('hide', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .limit(15);
    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    }
    return querySnapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> getPostsNext() async {
    if (_lastDocument == null) return [];

    Query query = _firestore
        .collection('posts')
        .where('hide', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(10);
    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    }
    return querySnapshot.docs;
  }

  Future<List<String>> getFavoritePosts(String userId) async {
    final snapshot = await _firestore
        .collection('favorites')
        .doc(userId)
        .collection('posts')
        .get();

    return snapshot.docs.map((doc) => doc['post_id'] as String).toList();
  }

  Future<List<String>> fetchBlockedAccounts(String userId) async {
    // blockUsers コレクションから blocked_user_id を取得
    final blockUsersSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockUsersSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // block ドキュメントから blocked_user_id を取得
    final blockDocSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('block')
        .get();

    List<String> blockDocUserIds = blockDocSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // 両方のリストを結合して返す
    blockedUserIds.addAll(blockDocUserIds);
    return blockedUserIds;
  }
}

// ViewModel クラス
final viewModelProvider =
    ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

class ViewModel extends ChangeNotifier {
  ViewModel(this.ref);

  final Ref ref;
  List<QueryDocumentSnapshot> stackedPostList = [];
  List<QueryDocumentSnapshot> currentPostList = [];
  List<String> favoritePosts = [];
  List<String> blockedAccounts = [];
  Map<String, Account> postUserMap = {};
  bool isLoading = false; // データ取得中の状態を管理
  bool isFirstLoad = true; // 初回データ取得中の状態を管理

  Future<void> getPosts(String userId) async {
    isLoading = true; // データ取得開始
    notifyListeners();

    stackedPostList = [];
    final dbManager = ref.read(dbManagerProvider);

    // 並列に非同期処理を実行
    final results = await Future.wait([
      dbManager.getPosts(),
      dbManager.getFavoritePosts(userId),
      dbManager.fetchBlockedAccounts(userId),
    ]);

    currentPostList = results[0] as List<QueryDocumentSnapshot>;
    favoritePosts = results[1] as List<String>;
    blockedAccounts = results[2] as List<String>;

    stackedPostList.addAll(currentPostList);
    postUserMap = await UserFirestore.getPostUserMap(
          stackedPostList
              .map((doc) => (doc.data()
                  as Map<String, dynamic>)['post_account_id'] as String)
              .toList(),
        ) ??
        {};

    isLoading = false; // データ取得完了
    isFirstLoad = false; // 初回データ取得完了
    notifyListeners();
  }

  Future<void> getPostsNext(String userId) async {
    isLoading = true; // データ取得開始
    notifyListeners();

    currentPostList = await ref.read(dbManagerProvider).getPostsNext();
    if (currentPostList.isNotEmpty) {
      stackedPostList.addAll(currentPostList);
      final newPostUserMap = await UserFirestore.getPostUserMap(
            currentPostList
                .map((doc) => (doc.data()
                    as Map<String, dynamic>)['post_account_id'] as String)
                .toList(),
          ) ??
          {};
      postUserMap.addAll(newPostUserMap);
    }

    isLoading = false; // データ取得完了
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
