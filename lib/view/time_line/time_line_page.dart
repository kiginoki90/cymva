import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';

// TimeLinePage クラス
class TimeLinePage extends ConsumerStatefulWidget {
  final String userId;
  const TimeLinePage({
    super.key,
    required this.userId,
  });

  @override
  _TimeLinePageState createState() => _TimeLinePageState();
}

class _TimeLinePageState extends ConsumerState<TimeLinePage> {
  final ScrollController _scrollController = ScrollController();
  late Future<List<String>>? _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(viewModelProvider).getPosts(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => model.getPosts(widget.userId),
        child: model.stackedPostList.isEmpty
            ? const Center(child: Text("まだ投稿がありません"))
            : ListView.builder(
                controller: _scrollController,
                itemCount: model.stackedPostList.length + 1,
                itemBuilder: (context, int index) {
                  if (index == model.stackedPostList.length) {
                    return model.currentPostList.isNotEmpty
                        ? TextButton(
                            onPressed: () async {
                              final currentScrollPosition =
                                  _scrollController.position.pixels;
                              await model.getPostsNext(widget.userId);
                              _scrollController.jumpTo(currentScrollPosition);
                            },
                            child: const Text("もっと読み込む"),
                          )
                        : const Center(child: Text("結果は以上です"));
                  }

                  if (index >= model.stackedPostList.length) {
                    return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                  }

                  final postDoc = model.stackedPostList[index];
                  final post = Post.fromDocument(postDoc);
                  final postAccount = model.postUserMap[post.postAccountId];

                  // blockedUserIds に postAccount.id が含まれている場合は表示をスキップ
                  if (postAccount == null ||
                      postAccount.lockAccount ||
                      model.blockedAccounts.contains(postAccount.id)) {
                    return Container();
                  }

                  _favoritePost.favoriteUsersNotifiers[post.id] ??=
                      ValueNotifier<int>(0);
                  _favoritePost.updateFavoriteUsersCount(post.id);

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
                    onFavoriteToggle: () => _favoritePost.toggleFavorite(
                      post.id,
                      _favoritePost.favoritePostsNotifier.value
                          .contains(post.id),
                    ),
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              ),
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
        .orderBy('created_time', descending: true)
        .limit(50);
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
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(50);
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

  Future<void> getPosts(String userId) async {
    stackedPostList = [];
    currentPostList = await ref.read(dbManagerProvider).getPosts();
    favoritePosts = await ref.read(dbManagerProvider).getFavoritePosts(userId);
    blockedAccounts =
        await ref.read(dbManagerProvider).fetchBlockedAccounts(userId);
    stackedPostList.addAll(currentPostList);
    postUserMap = await UserFirestore.getPostUserMap(
          stackedPostList
              .map((doc) => (doc.data()
                  as Map<String, dynamic>)['post_account_id'] as String)
              .toList(),
        ) ??
        {};
    notifyListeners();
  }

  Future<void> getPostsNext(String userId) async {
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
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
