import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/ad_widget.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/search/detailed_search_page.dart';
import 'package:cymva/view/search/search_item.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter/services.dart';

class SearchPage extends StatefulWidget {
  final String userId;
  final String? initialHashtag;
  const SearchPage({super.key, required this.userId, this.initialHashtag});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SearchItem _searchItem = SearchItem(FirebaseFirestore.instance);
  final PageController _pageController = PageController();
  List<DocumentSnapshot> _postSearchResults = []; // コンテンツ検索結果用
  List<DocumentSnapshot> _recentFavoritesResults = []; // 人気検索結果用
  List<DocumentSnapshot> _recentImageResults = [];
  List<Account> _accountSearchResults = [];
  final FavoritePost _favoritePost = FavoritePost();
  int _currentPage = 0;
  String _lastQuery = '';
  String? _selectedCategory;
  final List<String> categories = [
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '写真',
    '俳句・短歌',
    '改修要望/バグ',
    '憲章宣誓',
  ];
  final Map<String, int> _postFavoriteCounts = {};

  @override
  void initState() {
    super.initState();

    if (widget.initialHashtag != null) {
      _searchController.text = widget.initialHashtag!;

      if (_currentPage == 0) {
        _searchItem.searchPosts(
            _searchController.text, widget.userId, _selectedCategory, null, 5,
            (results) {
          setState(() {
            _postSearchResults = results;
          });
        });
      } else if (_currentPage == 1) {
        _searchItem.searchAccounts(_searchController.text, (results) {
          setState(() {
            _accountSearchResults = results;
          });
        });
      } else if (_currentPage == 2) {
        _searchItem.fetchRecentFavorites(_searchController.text, widget.userId,
            _selectedCategory, _postFavoriteCounts, (results) {
          setState(() {
            _recentFavoritesResults = results;
          });
        });
      } else if (_currentPage == 3) {
        _searchItem.searchImagePosts(
            _searchController.text, widget.userId, _selectedCategory,
            (results) {
          setState(() {
            _recentImageResults = results;
          });
        });
      }
    }

    _searchController.addListener(() {
      _lastQuery = _searchController.text;

      if (_currentPage == 0) {
        _searchItem.searchPosts(
            _searchController.text, widget.userId, _selectedCategory, null, 5,
            (results) {
          setState(() {
            _postSearchResults = results;
          });
        });
      } else if (_currentPage == 1) {
        _searchItem.searchAccounts(_lastQuery, (results) {
          setState(() {
            _accountSearchResults = results;
          });
        });
      } else if (_currentPage == 2) {
        _searchItem.fetchRecentFavorites(
            _lastQuery, widget.userId, _selectedCategory, _postFavoriteCounts,
            (results) {
          setState(() {
            _recentFavoritesResults = results;
          });
        });
      } else if (_currentPage == 3) {
        _searchItem.searchImagePosts(
            _lastQuery, widget.userId, _selectedCategory, (results) {
          setState(() {
            _recentImageResults = results;
          });
        });
      }
    });

    _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                inputFormatters: [
                  LengthLimitingTextInputFormatter(40), // 最大50文字に制限
                ],
                onSubmitted: (query) {
                  if (_currentPage == 0) {
                    _searchItem.searchPosts(
                        query, widget.userId, _selectedCategory, null, 5,
                        (results) {
                      setState(() {
                        _postSearchResults = results;
                      });
                    });
                  } else if (_currentPage == 1) {
                    _searchItem.searchAccounts(query, (results) {
                      setState(() {
                        _accountSearchResults = results;
                      });
                    });
                  } else if (_currentPage == 2) {
                    _searchItem.fetchRecentFavorites(query, widget.userId,
                        _selectedCategory, _postFavoriteCounts, (results) {
                      setState(() {
                        _recentFavoritesResults = results;
                      });
                    });
                  } else if (_currentPage == 3) {
                    _searchItem.searchImagePosts(
                        query, widget.userId, _selectedCategory, (results) {
                      setState(() {
                        _recentImageResults = results;
                      });
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.widgets),
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
    // blockUsers コレクションから blocked_user_id を取得
    final blockUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockUsersSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // block ドキュメントから blocked_user_id を取得
    final blockDocSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('block')
        .get();

    List<String> blockDocUserIds = blockDocSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // 両方のリストを結合して返す
    blockedUserIds.addAll(blockDocUserIds);
    return blockedUserIds;
  }

//コンテンツの検索結果を表示するWidget
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

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500), // 最大横幅を500に設定
            child: RefreshIndicator(
              onRefresh: _refreshSearchResults,
              child: ListView.builder(
                itemCount: _postSearchResults.length +
                    (_postSearchResults.length ~/ 10) +
                    1,
                itemBuilder: (context, index) {
                  if (index ==
                      _postSearchResults.length +
                          (_postSearchResults.length ~/ 10)) {
                    return const Center(child: Text("結果は以上です"));
                  }

                  if (index % 11 == 10) {
                    return BannerAdWidget(); // 広告ウィジェットを表示
                  }

                  final postIndex = index - (index ~/ 11);
                  if (postIndex >= _postSearchResults.length) {
                    return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                  }

                  final postDoc = _postSearchResults[postIndex];
                  final post = Post.fromDocument(postDoc);

                  return FutureBuilder<Account?>(
                    future: _searchItem.getPostAccount(post.postAccountId),
                    builder: (context, accountSnapshot) {
                      if (accountSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (accountSnapshot.hasError) {
                        return Center(
                            child:
                                Text('エラーが発生しました: ${accountSnapshot.error}'));
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
                        // isRetweetedNotifier: ValueNotifier<bool>(false),
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

// リストを更新するメソッド
  Future<void> _refreshSearchResults() async {
    // データを再取得して_stateを更新する
    await _searchItem.searchPosts(
        _searchController.text, widget.userId, _selectedCategory, null, 5,
        (results) {
      setState(() {
        _postSearchResults = results;
      });
    });
  }

  Widget _buildSearchByAccountNamePage() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: ListView.builder(
          itemCount: _accountSearchResults.length,
          itemBuilder: (context, index) {
            final account = _accountSearchResults[index];

            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // 画像の取得に失敗した場合のエラービルダー
                          return Image.network(
                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
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
        ),
      ),
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

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: RefreshIndicator(
              onRefresh: _refreshRecentFavorites,
              child: ListView.builder(
                itemCount: _recentFavoritesResults.length +
                    (_recentFavoritesResults.length ~/ 10) +
                    1,
                itemBuilder: (context, index) {
                  if (index ==
                      _recentFavoritesResults.length +
                          (_recentFavoritesResults.length ~/ 10)) {
                    return const Center(child: Text("結果は以上です"));
                  }

                  if (index % 11 == 10) {
                    return BannerAdWidget(); // 広告ウィジェットを表示
                  }

                  final postIndex = index - (index ~/ 11);
                  if (postIndex >= _recentFavoritesResults.length) {
                    return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                  }

                  final postDoc = _recentFavoritesResults[postIndex];
                  final post = Post.fromDocument(postDoc);

                  return FutureBuilder<Account?>(
                    future: _searchItem.getPostAccount(post.postAccountId),
                    builder: (context, accountSnapshot) {
                      if (accountSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (accountSnapshot.hasError) {
                        return Center(
                            child:
                                Text('エラーが発生しました: ${accountSnapshot.error}'));
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

                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      // PostItemWidget に recentFavoriteCount をそのまま渡す
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
                        // isRetweetedNotifier: ValueNotifier<bool>(false),
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // リストを更新するメソッド
  Future<void> _refreshRecentFavorites() async {
    // データを再取得して_stateを更新する
    await _searchItem.fetchRecentFavorites(
        _lastQuery, widget.userId, _selectedCategory, _postFavoriteCounts,
        (results) {
      setState(() {
        _recentFavoritesResults = results;
      });
    });
  }

// 画像の検索結果を表示するWidget
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

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: RefreshIndicator(
              onRefresh: _refreshPosts, // 更新時に呼び出されるメソッド
              child: ListView.builder(
                itemCount: _postSearchResults.length +
                    (_postSearchResults.length ~/ 10) +
                    1,
                itemBuilder: (context, index) {
                  if (index ==
                      _postSearchResults.length +
                          (_postSearchResults.length ~/ 10)) {
                    return const Center(child: Text("結果は以上です"));
                  }

                  if (index % 11 == 10) {
                    return BannerAdWidget(); // 広告ウィジェットを表示
                  }

                  final postIndex = index - (index ~/ 11);
                  if (postIndex >= _postSearchResults.length) {
                    return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                  }

                  final postDoc = _postSearchResults[postIndex];
                  final post = Post.fromDocument(postDoc);

                  // media_urlがある投稿のみ表示
                  if (post.mediaUrl == null || post.mediaUrl!.isEmpty) {
                    return Container(); // media_urlがない場合はスキップ
                  }

                  return FutureBuilder<Account?>(
                    future: _searchItem.getPostAccount(post.postAccountId),
                    builder: (context, accountSnapshot) {
                      if (accountSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (accountSnapshot.hasError) {
                        return Center(
                            child:
                                Text('エラーが発生しました: ${accountSnapshot.error}'));
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
                        // isRetweetedNotifier: ValueNotifier<bool>(false),
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

// リストを更新するメソッド
  Future<void> _refreshPosts() async {
    // データを再取得して_stateを更新する
    await _searchItem.searchImagePosts(
        _lastQuery, widget.userId, _selectedCategory, (results) {
      setState(() {
        _recentImageResults = results;
      });
    });
  }

  void _onPageChanged() {
    _lastQuery = _searchController.text;

    if (_currentPage == 0 && _postSearchResults.isEmpty) {
      _searchItem.searchPosts(
          _searchController.text, widget.userId, _selectedCategory, null, 5,
          (results) {
        setState(() {
          _postSearchResults = results;
        });
      });
    } else if (_currentPage == 1 && _accountSearchResults.isEmpty) {
      _searchItem.searchAccounts(_lastQuery, (results) {
        setState(() {
          _accountSearchResults = results;
        });
      });
    } else if (_currentPage == 2 && _recentFavoritesResults.isEmpty) {
      _searchItem.fetchRecentFavorites(
          _lastQuery, widget.userId, _selectedCategory, _postFavoriteCounts,
          (results) {
        setState(() {
          _recentFavoritesResults = results;
        });
      });
    } else if (_currentPage == 3 && _recentImageResults.isEmpty) {
      _searchItem.searchImagePosts(_lastQuery, widget.userId, _selectedCategory,
          (results) {
        setState(() {
          _recentImageResults = results;
        });
      });
    }
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('カテゴリーの選択'),
              IconButton(
                icon: Icon(
                  Icons.new_label,
                  size: 45.0, // アイコンのサイズを大きくする
                  color:
                      const Color.fromARGB(255, 170, 205, 222), // アイコンの色を水色にする
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  _navigateToDetailedSearchPage(); // 詳しい検索条件のページに遷移
                },
              )
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              children: categories.map((category) {
                return ListTile(
                  title: Text(category),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _searchItem.searchPosts(_searchController.text,
                          widget.userId, _selectedCategory, null, 5, (results) {
                        setState(() {
                          _postSearchResults = results;
                        });
                      });
                      _searchItem.fetchRecentFavorites(
                          _lastQuery,
                          widget.userId,
                          _selectedCategory,
                          _postFavoriteCounts, (results) {
                        setState(() {
                          _recentFavoritesResults = results;
                        });
                      });
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

  void _navigateToDetailedSearchPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9, // 画面の90%の高さに設定
          child: DetailedSearchPage(),
        );
      },
    ).then((result) {
      if (result != null) {
        // 検索条件を受け取る
        final query = result['query'] as String;
        final selectedCategory = result['selectedCategory'] as String?;
        final searchUserId = result['searchUserId'] as String?;
        final isFollowing = result['isFollowing'] as bool;
        final startDate = result['startDate'] as DateTime?;
        final endDate = result['endDate'] as DateTime?;

        // 検索条件を適用して検索を実行
        _searchItem.searchPosts(
          query,
          widget.userId,
          selectedCategory,
          null,
          5,
          (results) {
            setState(() {
              _postSearchResults = results;
            });
          },
          searchUserId: searchUserId,
          isFollowing: isFollowing,
          startDate: startDate,
          endDate: endDate,
        );

        // 検索条件を適用して検索を実行
        _searchItem.fetchRecentFavorites(
          query,
          widget.userId,
          selectedCategory,
          _postFavoriteCounts,
          (results) {
            setState(() {
              _recentFavoritesResults = results;
            });
          },
          searchUserId: searchUserId,
          isFollowing: isFollowing,
          startDate: startDate,
          endDate: endDate,
        );
      }
    });
  }
}
