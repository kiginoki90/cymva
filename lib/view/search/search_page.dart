import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/utils/favorite_post.dart';

class SearchPage extends StatefulWidget {
  final String userId;
  final String? initialHashtag;
  const SearchPage({super.key, required this.userId, this.initialHashtag});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  List<DocumentSnapshot> _postSearchResults = []; // コンテンツ検索結果用
  List<DocumentSnapshot> _recentFavoritesResults = []; // 人気検索結果用
  List<DocumentSnapshot> _recentImageResults = [];
  List<Account> _accountSearchResults = [];
  final FavoritePost _favoritePost = FavoritePost();
  int _currentPage = 0;
  String _lastQuery = '';
  String? _selectedCategory;
  final List<String> categories = ['', '動物', 'AI', '漫画', 'イラスト', '写真', '俳句・短歌'];
  final Map<String, int> _postFavoriteCounts = {};

  @override
  void initState() {
    super.initState();

    if (widget.initialHashtag != null) {
      _searchController.text = widget.initialHashtag!;

      if (_currentPage == 0) {
        _searchPosts(_searchController.text);
      } else if (_currentPage == 1) {
        _searchAccounts(_searchController.text);
      } else if (_currentPage == 2) {
        _fetchRecentFavorites(_searchController.text);
      } else if (_currentPage == 3) {
        _searchImagePosts(_searchController.text);
      }
    }

    _searchController.addListener(() {
      _lastQuery = _searchController.text;

      if (_currentPage == 0) {
        _searchPosts(_lastQuery);
      } else if (_currentPage == 1) {
        _searchAccounts(_lastQuery);
      } else if (_currentPage == 2) {
        _fetchRecentFavorites(_lastQuery);
      } else if (_currentPage == 3) {
        _searchImagePosts(_lastQuery);
      }
    });

    _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '検索...',
                  border: InputBorder.none,
                  filled: true, // 背景色を有効にする
                  fillColor: Colors.white, // 背景色
                  hintStyle: TextStyle(
                      color: Color.fromARGB(179, 131, 128, 128)), // ヒントのスタイル
                ),
                style: const TextStyle(color: Colors.black), // テキストの色
                onSubmitted: (query) {
                  if (_currentPage == 0) {
                    _searchPosts(query);
                  } else if (_currentPage == 1) {
                    _searchAccounts(query);
                  } else if (_currentPage == 2) {
                    _fetchRecentFavorites(query);
                  } else if (_currentPage == 3) {
                    _searchImagePosts(query);
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.category),
              onPressed: () {
                _showCategoryDialog();
              },
            ),
            if (_selectedCategory != null && _selectedCategory!.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _showCategoryDialog();
                },
                child: Text(
                  _selectedCategory!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildNavigationBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (pageIndex) {
                setState(() {
                  _currentPage = pageIndex;
                });
                _onPageChanged();
              },
              children: [
                _buildSearchByTextPage(),
                _buildSearchByAccountNamePage(),
                _buildRecentFavoritesPage(),
                _buildSearchByImagePage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 2),
    );
  }

  Future<List<String>> _fetchBlockedUserIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('blockUsers')
        .get();

    return snapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();
  }

  Widget _buildSearchByTextPage() {
    if (_postSearchResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return FutureBuilder<List<String>>(
      future: _fetchBlockedUserIds(), // ブロックされたユーザーIDを取得するFuture
      builder: (context, blockedUsersSnapshot) {
        if (blockedUsersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (blockedUsersSnapshot.hasError) {
          return Center(
              child: Text('エラーが発生しました: ${blockedUsersSnapshot.error}'));
        } else if (!blockedUsersSnapshot.hasData) {
          return Container();
        }

        final blockedUserIds = blockedUsersSnapshot.data!; // ブロックされたユーザーIDのリスト

        return RefreshIndicator(
          onRefresh: _refreshSearchResults,
          child: ListView.builder(
            itemCount: _postSearchResults.length,
            itemBuilder: (context, index) {
              final postDoc = _postSearchResults[index];
              final post = Post.fromDocument(postDoc);

              return FutureBuilder<Account?>(
                future: _getPostAccount(post.postAccountId),
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (accountSnapshot.hasError) {
                    return Center(
                        child: Text('エラーが発生しました: ${accountSnapshot.error}'));
                  } else if (!accountSnapshot.hasData) {
                    return Container();
                  }

                  final postAccount = accountSnapshot.data!;

                  // 自分のblockUsersサブコレクションでブロックされたユーザーIDと一致したらスキップする
                  if (blockedUserIds.contains(postAccount.id)) {
                    return Container(); // スキップして何も表示しない
                  }

                  // lock_accountがtrueで、自分ではないアカウントならスキップする
                  if (postAccount.lockAccount &&
                      postAccount.id != widget.userId) {
                    return Container(); // スキップして何も表示しない
                  }

                  // フォロワー数の処理
                  _favoritePost.favoriteUsersNotifiers[post.id] ??=
                      ValueNotifier<int>(0);
                  _favoritePost.updateFavoriteUsersCount(post.id);

                  return PostItemWidget(
                    post: post,
                    postAccount: postAccount,
                    favoriteUsersNotifier:
                        _favoritePost.favoriteUsersNotifiers[post.id]!,
                    isFavoriteNotifier: ValueNotifier<bool>(_favoritePost
                        .favoritePostsNotifier.value
                        .contains(post.id)),
                    onFavoriteToggle: () {
                      final isFavorite = _favoritePost
                          .favoritePostsNotifier.value
                          .contains(post.id);
                      _favoritePost.toggleFavorite(post.id, isFavorite);
                    },
                    isRetweetedNotifier: ValueNotifier<bool>(false),
                    onRetweetToggle: () {
                      // リツイートの状態をFirestoreに保存するロジックを追加
                    },
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

// リストを更新するメソッド
  Future<void> _refreshSearchResults() async {
    // データを再取得して_stateを更新する
    await _searchPosts(_lastQuery);
  }

  Widget _buildSearchByAccountNamePage() {
    return ListView.builder(
      itemCount: _accountSearchResults.length,
      itemBuilder: (context, index) {
        final account = _accountSearchResults[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountPage(
                        postUserId: account.id,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    account.imagePath ??
                        'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // 画像の取得に失敗した場合のエラービルダー
                      return Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountPage(
                          postUserId: account.id,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              account.name.length > 25
                                  ? '${account.name.substring(0, 25)}...' // 25文字を超える場合は切り捨てて「...」を追加
                                  : account.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '@${account.userId.length > 25 ? '${account.userId.substring(0, 25)}...' : account.userId}',
                              style: const TextStyle(color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.selfIntroduction,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        maxLines: 2, // 最大2行に設定
                        overflow: TextOverflow.ellipsis, // 省略記号を表示
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentFavoritesPage() {
    if (_recentFavoritesResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return FutureBuilder<List<String>>(
      future: _fetchBlockedUserIds(), // ブロックされたユーザーIDを取得するFuture
      builder: (context, blockedUsersSnapshot) {
        if (blockedUsersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (blockedUsersSnapshot.hasError) {
          return Center(
              child: Text('エラーが発生しました: ${blockedUsersSnapshot.error}'));
        } else if (!blockedUsersSnapshot.hasData) {
          return Container(); // データがない場合は空のコンテナを返す
        }

        final blockedUserIds = blockedUsersSnapshot.data!; // ブロックされたユーザーIDのリスト

        return RefreshIndicator(
          onRefresh: _refreshRecentFavorites,
          child: ListView.builder(
            itemCount: _recentFavoritesResults.length,
            itemBuilder: (context, index) {
              final postDoc = _recentFavoritesResults[index];
              final post = Post.fromDocument(postDoc);

              return FutureBuilder<Account?>(
                future: _getPostAccount(post.postAccountId),
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (accountSnapshot.hasError) {
                    return Center(
                        child: Text('エラーが発生しました: ${accountSnapshot.error}'));
                  } else if (!accountSnapshot.hasData) {
                    return Container();
                  }

                  final postAccount = accountSnapshot.data!;

                  // 自分のblockUsersサブコレクションでブロックされたユーザーIDと一致したらスキップする
                  if (blockedUserIds.contains(postAccount.id)) {
                    return Container(); // スキップして何も表示しない
                  }

                  // lock_accountがtrueで、自分ではないアカウントならスキップする
                  if (postAccount.lockAccount &&
                      postAccount.id != widget.userId) {
                    return Container(); // スキップして何も表示しない
                  }

                  // Firestoreから直近24時間のfavorite_usersを取得してcount
                  final recentFavoriteCount = _postFavoriteCounts[post.id] ?? 0;

                  // PostItemWidget に recentFavoriteCount をそのまま渡す
                  return PostItemWidget(
                    post: post,
                    postAccount: postAccount,
                    favoriteUsersNotifier:
                        _favoritePost.favoriteUsersNotifiers[post.id] ??
                            ValueNotifier<int>(recentFavoriteCount),
                    isFavoriteNotifier: ValueNotifier<bool>(_favoritePost
                        .favoritePostsNotifier.value
                        .contains(post.id)),
                    onFavoriteToggle: () {
                      final isFavorite = _favoritePost
                          .favoritePostsNotifier.value
                          .contains(post.id);
                      _favoritePost.toggleFavorite(post.id, isFavorite);
                    },
                    isRetweetedNotifier: ValueNotifier<bool>(false),
                    onRetweetToggle: () {
                      // リツイートの状態をFirestoreに保存するロジックを追加
                    },
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // リストを更新するメソッド
  Future<void> _refreshRecentFavorites() async {
    // データを再取得して_stateを更新する
    await _fetchRecentFavorites(_lastQuery);
  }

  // 検索結果を表示するWidget
  Widget _buildSearchByImagePage() {
    if (_postSearchResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }

    return FutureBuilder<List<String>>(
      future: _fetchBlockedUserIds(), // ブロックされたユーザーIDを取得するFuture
      builder: (context, blockedUsersSnapshot) {
        if (blockedUsersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (blockedUsersSnapshot.hasError) {
          return Center(
              child: Text('エラーが発生しました: ${blockedUsersSnapshot.error}'));
        } else if (!blockedUsersSnapshot.hasData) {
          return Container(); // データがない場合は空のコンテナを返す
        }

        final blockedUserIds = blockedUsersSnapshot.data!; // ブロックされたユーザーIDのリスト

        return RefreshIndicator(
          onRefresh: _refreshPosts, // 更新時に呼び出されるメソッド
          child: ListView.builder(
            itemCount: _postSearchResults.length,
            itemBuilder: (context, index) {
              final postDoc = _postSearchResults[index];
              final post = Post.fromDocument(postDoc);

              // media_urlがある投稿のみ表示
              if (post.mediaUrl == null || post.mediaUrl!.isEmpty) {
                return Container(); // media_urlがない場合はスキップ
              }

              return FutureBuilder<Account?>(
                future: _getPostAccount(post.postAccountId),
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (accountSnapshot.hasError) {
                    return Center(
                        child: Text('エラーが発生しました: ${accountSnapshot.error}'));
                  } else if (!accountSnapshot.hasData) {
                    return Container();
                  }

                  final postAccount = accountSnapshot.data!;

                  // 自分のblockUsersサブコレクションでブロックされたユーザーIDと一致したらスキップする
                  if (blockedUserIds.contains(postAccount.id)) {
                    return Container(); // スキップして何も表示しない
                  }

                  // lock_accountがtrueで、自分ではないアカウントならスキップする
                  if (postAccount.lockAccount &&
                      postAccount.id != widget.userId) {
                    return Container(); // スキップして何も表示しない
                  }

                  // フォロワー数の処理
                  _favoritePost.favoriteUsersNotifiers[post.id] ??=
                      ValueNotifier<int>(0);
                  _favoritePost.updateFavoriteUsersCount(post.id);

                  return PostItemWidget(
                    post: post,
                    postAccount: postAccount,
                    favoriteUsersNotifier:
                        _favoritePost.favoriteUsersNotifiers[post.id]!,
                    isFavoriteNotifier: ValueNotifier<bool>(_favoritePost
                        .favoritePostsNotifier.value
                        .contains(post.id)),
                    onFavoriteToggle: () {
                      final isFavorite = _favoritePost
                          .favoritePostsNotifier.value
                          .contains(post.id);
                      _favoritePost.toggleFavorite(post.id, isFavorite);
                    },
                    isRetweetedNotifier: ValueNotifier<bool>(false),
                    onRetweetToggle: () {
                      // リツイートの状態をFirestoreに保存するロジックを追加
                    },
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

// リストを更新するメソッド
  Future<void> _refreshPosts() async {
    // データを再取得して_stateを更新する
    await _searchImagePosts(_lastQuery);
  }

  void _onPageChanged() {
    _lastQuery = _searchController.text;

    if (_currentPage == 0 && _postSearchResults.isEmpty) {
      _searchPosts(_lastQuery);
    } else if (_currentPage == 1 && _accountSearchResults.isEmpty) {
      _searchAccounts(_lastQuery);
    } else if (_currentPage == 2 && _recentFavoritesResults.isEmpty) {
      _fetchRecentFavorites(_lastQuery);
    } else if (_currentPage == 3 && _recentImageResults.isEmpty) {
      _searchImagePosts(_lastQuery);
    }
  }

  Future<void> _searchPosts(String query) async {
    if (query.isEmpty &&
        (_selectedCategory == null || _selectedCategory!.isEmpty)) {
      setState(() {
        _postSearchResults = [];
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // 投稿コレクションのクエリ
    Query queryRef =
        firestore.collection('posts').orderBy('created_time', descending: true);

    // カテゴリーが選択されている場合はカテゴリーでフィルタリング
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: _selectedCategory);
    }

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await queryRef.get();

    // クエリを小文字に変換し、スペースで分割
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 取得したドキュメントに対して、すべての単語が含まれているかをフィルタリング
    final filteredPosts = querySnapshot.docs.where((doc) {
      final content = (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
      return queryWords.every((word) => content.contains(word));
    }).toList();

    setState(() {
      _postSearchResults = filteredPosts;
    });
  }

  Future<void> _searchAccounts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _accountSearchResults = [];
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // クエリを小文字に変換
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 検索結果を格納するリスト
    final Set<String> uniqueAccountIds = {}; // 重複を防ぐためのセット
    final List<DocumentSnapshot> allDocs = [];

    // ユーザー名に対するクエリ
    Query nameQuery = firestore.collection('users');
    // ユーザーIDに対するクエリ
    Query userIdQuery = firestore.collection('users');

    for (String word in queryWords) {
      if (word.isNotEmpty) {
        nameQuery = nameQuery
            .where('name', isGreaterThanOrEqualTo: word)
            .where('name', isLessThanOrEqualTo: word + '\uf8ff');
        userIdQuery = userIdQuery
            .where('user_id', isGreaterThanOrEqualTo: word)
            .where('user_id', isLessThanOrEqualTo: word + '\uf8ff');
      }
    }

    // `name`フィールドに対するクエリ
    final nameQuerySnapshot = await nameQuery.get();
    // `user_id`フィールドに対するクエリ
    final userIdQuerySnapshot = await userIdQuery.get();

    // 名前の結果を追加
    for (var doc in nameQuerySnapshot.docs) {
      if (uniqueAccountIds.add(doc.id)) {
        allDocs.add(doc);
      }
    }

    // ユーザーIDの結果を追加
    for (var doc in userIdQuerySnapshot.docs) {
      if (uniqueAccountIds.add(doc.id)) {
        allDocs.add(doc);
      }
    }

    setState(() {
      _accountSearchResults = allDocs.map((doc) {
        return Account.fromDocument(doc);
      }).toList();
    });
  }

  Future<Account?> _getPostAccount(String accountId) async {
    final firestore = FirebaseFirestore.instance;

    final doc = await firestore.collection('users').doc(accountId).get();

    if (doc.exists) {
      return Account.fromDocument(doc);
    } else {
      return null;
    }
  }

  Future<void> _fetchRecentFavorites(String query) async {
    final firestore = FirebaseFirestore.instance;
    Query queryRef = firestore.collection('posts');

    // カテゴリーが選択されている場合は、カテゴリーでフィルタリング
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: _selectedCategory);
    }

    try {
      final querySnapshot = await queryRef.get();

      final List<DocumentSnapshot> postWithFavorites = [];

      // クエリを小文字に変換し、スペースで分割
      final lowerCaseQuery = query.toLowerCase();
      final queryWords = lowerCaseQuery.split(' ');

      // 各投稿に対してFutureのリストを作成
      final futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;

        // お気に入りユーザーを取得
        final favoriteUsersSnapshot = await firestore
            .collection('posts')
            .doc(postId)
            .collection('favorite_users')
            .where('added_at',
                isGreaterThanOrEqualTo:
                    DateTime.now().subtract(Duration(hours: 24)))
            .get();

        final recentFavoriteCount = favoriteUsersSnapshot.size;

        // 投稿の内容がクエリに含まれているかをチェック
        final content =
            (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
        if (query.isNotEmpty &&
            !queryWords.every((word) => content.contains(word))) {
          return;
        }

        // お気に入り数を記録しておく
        postWithFavorites.add(doc);
        _postFavoriteCounts[postId] = recentFavoriteCount;
      });

      // すべてのFutureが完了するのを待つ
      await Future.wait(futures);

      // お気に入りの数で降順に並べ替え
      postWithFavorites.sort((a, b) {
        final countA = _postFavoriteCounts[a.id] ?? 0;
        final countB = _postFavoriteCounts[b.id] ?? 0;
        return countB.compareTo(countA);
      });

      setState(() {
        _recentFavoritesResults = postWithFavorites;
      });
    } catch (error) {
      // エラーハンドリング
      print('Error fetching recent favorites: $error');
    }
  }

  // 画像を検索するメソッド
  Future<void> _searchImagePosts(String query) async {
    if (query.isEmpty &&
        (_selectedCategory == null || _selectedCategory!.isEmpty)) {
      setState(() {
        _postSearchResults = [];
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // 投稿コレクションのクエリ
    Query queryRef =
        firestore.collection('posts').orderBy('created_time', descending: true);

    // カテゴリーが選択されている場合はカテゴリーでフィルタリング
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: _selectedCategory);
    }

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await queryRef.get();

    // クエリを小文字に変換し、スペースで分割
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 取得したドキュメントに対して、文字列に query が含まれているかをフィルタリング
    final filteredPosts = querySnapshot.docs.where((doc) {
      final content = (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
      final mediaUrl = doc['media_url'] as List<dynamic>?; // media_urlのフィールド

      // 投稿の内容がすべての単語を含むかつmedia_urlが存在するかをチェック
      return queryWords.every((word) => content.contains(word)) &&
          mediaUrl != null &&
          mediaUrl.isNotEmpty;
    }).toList();

    setState(() {
      _recentImageResults = filteredPosts;
    });
  }

  Widget _buildNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('コンテンツ'),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: _currentPage == 0 ? Colors.blue : Colors.transparent,
                  ),
                ],
              ),
              onPressed: () {
                _pageController.jumpToPage(0);
              },
            ),
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('アカウント'),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: _currentPage == 1 ? Colors.blue : Colors.transparent,
                  ),
                ],
              ),
              onPressed: () {
                _pageController.jumpToPage(1);
              },
            ),
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('人気'),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    height: 2,
                    width: 60,
                    color: _currentPage == 2 ? Colors.blue : Colors.transparent,
                  ),
                ],
              ),
              onPressed: () {
                _pageController.jumpToPage(2);
              },
            ),
            IconButton(
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('メディア'),
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    height: 2,
                    width: 60,
                    color: _currentPage == 3 ? Colors.blue : Colors.transparent,
                  ),
                ],
              ),
              onPressed: () {
                _pageController.jumpToPage(3);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('カテゴリーの選択'),
          content: SingleChildScrollView(
            child: Column(
              children: categories.map((category) {
                return ListTile(
                  title: Text(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _searchPosts(_lastQuery);
                      _fetchRecentFavorites(_lastQuery);
                      Navigator.of(context).pop();
                    });
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
