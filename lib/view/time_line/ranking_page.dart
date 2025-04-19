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

class RankingPage extends ConsumerStatefulWidget {
  final String userId;
  const RankingPage({
    super.key,
    required this.userId,
  });

  @override
  _RankingPageState createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  final ScrollController _scrollController = ScrollController();
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // _favoritePost.getFavoritePosts();
    // _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(rankingViewModelProvider).getRankingPosts(widget.userId);
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
      await ref
          .read(rankingViewModelProvider)
          .getRankingPostsNext(widget.userId);
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
    final model = ref.watch(rankingViewModelProvider);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              // リフレッシュ機能
              child: RefreshIndicator(
                onRefresh: () => model.getRankingPosts(widget.userId),
                child: model.rankingPostList.isEmpty
                    ? const Center(child: Text("まだ投稿がありません"))
                    : ListView.builder(
                        //リストのスクロール位置を制御するためにScrollControllerを指定
                        controller: _scrollController,
                        itemCount: model.rankingPostList.length +
                            (model.rankingPostList.length ~/ 10) +
                            1,
                        itemBuilder: (context, int index) {
                          if (index ==
                              model.rankingPostList.length +
                                  (model.rankingPostList.length ~/ 10)) {
                            return _isLoadingMore
                                ? const Center(child: Text(" Loading..."))
                                : const Center(child: Text("結果は以上です"));
                          }

                          if (index % 8 == 7) {
                            return BannerAdWidget() ??
                                SizedBox(height: 50); // 広告ウィジェットを表示
                          }

                          final postIndex = index - (index ~/ 11);
                          if (postIndex >= model.rankingPostList.length) {
                            return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                          }

                          final postDoc = model.rankingPostList[postIndex];
                          final post = Post.fromDocument(postDoc);
                          final postAccount =
                              model.postUserMap[post.postAccountId];

                          // blockedUserIds に postAccount.id が含まれている場合は表示をスキップ
                          if (postAccount == null ||
                              postAccount.lockAccount ||
                              model.blockedAccounts.contains(postAccount.id)) {
                            return Container();
                          }

                          _favoritePost.favoriteUsersNotifiers[post.id] ??=
                              ValueNotifier<int>(0);
                          _favoritePost.updateFavoriteUsersCount(post.id);

                          _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                              ValueNotifier<int>(0);
                          _bookmarkPost.updateBookmarkUsersCount(post.id);

                          return PostItemWidget(
                            key: PageStorageKey(post.id),
                            post: post,
                            postAccount: postAccount,
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
                            replyFlag: ValueNotifier<bool>(false),
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
                            userId: widget.userId,
                          );
                        },
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 30.0, // ここで位置を調整
            right: 16.0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showScrollToTopButton,
              builder: (context, value, child) {
                return value
                    ? GestureDetector(
                        onDoubleTap: () {
                          _scrollController.animateTo(
                            0,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 56.0,
                          height: 56.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.lightBlue, width: 2.0),
                            color: Colors.transparent, // 内側を透明にする場合
                          ),
                          child: Icon(
                            Icons.keyboard_double_arrow_up,
                            color: Colors.lightBlue,
                            size: 40.0,
                          ),
                        ),
                      )
                    : Container();
              },
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
  Future<List<QueryDocumentSnapshot>> _fetchRankingPosts({
    required String userId,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      List<String> blockedAccounts = await fetchBlockedAccounts(userId);

      Query rankingQuery = _firestore
          .collection('ranking')
          .orderBy('count', descending: false)
          .limit(15);

      if (startAfter != null) {
        rankingQuery = rankingQuery.startAfterDocument(startAfter);
      }

      final rankingSnapshot = await rankingQuery.get();

      if (rankingSnapshot.docs.isEmpty) {
        return [];
      }

      List<String> postIds = rankingSnapshot.docs.map((doc) => doc.id).toList();

      Map<String, QueryDocumentSnapshot> postMap = {};
      for (int i = 0; i < postIds.length; i += 10) {
        // 投稿IDを10個ずつ分割してクエリを実行
        List<String> batch = postIds.sublist(
            i, i + 10 > postIds.length ? postIds.length : i + 10);
        Query postsQuery = _firestore
            .collection('posts')
            .where(FieldPath.documentId, whereIn: batch);
        final postsSnapshot = await postsQuery.get();

        // ブロックされたユーザーの投稿を除外し、マップに格納
        for (var doc in postsSnapshot.docs) {
          final postAccountId =
              (doc.data() as Map<String, dynamic>)['post_account_id'] as String;

          if (!blockedAccounts.contains(postAccountId)) {
            postMap[doc.id] = doc;
          }
        }
      }

// `ranking` コレクションの順序に従って投稿を並べ替え
      List<QueryDocumentSnapshot> allPosts = postIds
          .where((postId) => postMap.containsKey(postId)) // 存在する投稿IDのみ
          .map((postId) => postMap[postId]!) // マップから投稿を取得
          .toList();

// `_lastDocument` を更新
      if (rankingSnapshot.docs.isNotEmpty) {
        _lastDocument = rankingSnapshot.docs.last;
      }

      return allPosts;
    } catch (e) {
      print('Error fetching ranking posts: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> getRankingPosts(String userId) async {
    return _fetchRankingPosts(userId: userId);
  }

  Future<List<QueryDocumentSnapshot>> getRankingPostsNext(String userId) async {
    if (_lastDocument == null) return [];
    return _fetchRankingPosts(userId: userId, startAfter: _lastDocument);
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
final rankingViewModelProvider =
    ChangeNotifierProvider<RankingViewModel>((ref) => RankingViewModel(ref));

class RankingViewModel extends ChangeNotifier {
  RankingViewModel(this.ref);

  final Ref ref;
  List<QueryDocumentSnapshot> rankingPostList = [];
  List<String> blockedAccounts = [];
  Map<String, Account> postUserMap = {};

  Future<void> getRankingPosts(String userId) async {
    try {
      rankingPostList =
          await ref.read(dbManagerProvider).getRankingPosts(userId);

      // 投稿に関連するユーザー情報を取得
      postUserMap = await UserFirestore.getPostUserMap(
            rankingPostList
                .map((doc) => (doc.data()
                    as Map<String, dynamic>)['post_account_id'] as String)
                .toList(),
          ) ??
          {};

      notifyListeners();
    } catch (e) {
      print('Error fetching ranking posts: $e');
    }
  }

  Future<void> getRankingPostsNext(String userId) async {
    try {
      final nextPosts =
          await ref.read(dbManagerProvider).getRankingPostsNext(userId);

      if (nextPosts.isNotEmpty) {
        rankingPostList.addAll(nextPosts);

        // 新しい投稿に関連するユーザー情報を取得
        final newPostUserMap = await UserFirestore.getPostUserMap(
              nextPosts
                  .map((doc) => (doc.data()
                      as Map<String, dynamic>)['post_account_id'] as String)
                  .toList(),
            ) ??
            {};
        postUserMap.addAll(newPostUserMap);

        notifyListeners();
      }
    } catch (e) {
      print('Error fetching next ranking posts: $e');
    }
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
