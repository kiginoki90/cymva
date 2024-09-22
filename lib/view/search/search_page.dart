import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/edit_page/account_top_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/utils/favorite_post.dart';

class SearchPage extends StatefulWidget {
  final String userId;
  const SearchPage({super.key, required this.userId});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  List<DocumentSnapshot> _postSearchResults = [];
  List<Account> _accountSearchResults = [];
  final FavoritePost _favoritePost = FavoritePost();
  int _currentPage = 0;
  List<String> _recentFavoritePosts = [];
  String _lastQuery = '';
  String? _selectedCategory;
  final List<String> categories = ['', '動物', 'AI', '漫画', 'イラスト', '写真', '俳句・短歌'];
  final Map<String, int> _postFavoriteCounts = {};

  @override
  void initState() {
    super.initState();

    _favoritePost.getFavoritePosts();

    _searchController.addListener(() {
      _lastQuery = _searchController.text;
      if (_currentPage == 0) {
        _searchPosts(_lastQuery);
      } else if (_currentPage == 1) {
        _searchAccounts(_lastQuery);
      } else if (_currentPage == 2) {
        _fetchRecentFavorites(_lastQuery);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '検索...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.category),
                      onPressed: () {
                        _showCategoryDialog();
                      },
                    ),
                    if (_selectedCategory != null &&
                        _selectedCategory!.isNotEmpty) // カテゴリーが選択されている場合
                      Text(
                        _selectedCategory!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                )
              ],
            ),
          ),
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
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          NavigationBarPage(selectedIndex: 2, userId: widget.userId),
    );
  }

  Widget _buildSearchByTextPage() {
    return ListView.builder(
      itemCount: _postSearchResults.length,
      itemBuilder: (context, index) {
        final postDoc = _postSearchResults[index];
        final post = Post.fromDocument(postDoc);

        return FutureBuilder<Account?>(
          future: _getPostAccount(post.postAccountId),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (accountSnapshot.hasError) {
              return Center(
                  child: Text('エラーが発生しました: ${accountSnapshot.error}'));
            } else if (!accountSnapshot.hasData) {
              return Container();
            }

            final postAccount = accountSnapshot.data!;

            _favoritePost.favoriteUsersNotifiers[post.id] ??=
                ValueNotifier<int>(0);
            _favoritePost.updateFavoriteUsersCount(post.id);

            return PostItemWidget(
              post: post,
              postAccount: postAccount,
              favoriteUsersNotifier:
                  _favoritePost.favoriteUsersNotifiers[post.id]!,
              isFavoriteNotifier: ValueNotifier<bool>(
                  _favoritePost.favoritePostsNotifier.value.contains(post.id)),
              onFavoriteToggle: () {
                final isFavorite =
                    _favoritePost.favoritePostsNotifier.value.contains(post.id);
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
    );
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  account.imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountTopPage(
                          userId: account.id,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '@${account.userId}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.selfIntroduction.length > 230
                            ? '${account.selfIntroduction.substring(0, 231)}...'
                            : account.selfIntroduction,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
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
    return ListView.builder(
      itemCount: _postSearchResults.length,
      itemBuilder: (context, index) {
        final postDoc = _postSearchResults[index];
        final post = Post.fromDocument(postDoc);

        return FutureBuilder<Account?>(
          future: _getPostAccount(post.postAccountId),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (accountSnapshot.hasError) {
              return Center(
                  child: Text('エラーが発生しました: ${accountSnapshot.error}'));
            } else if (!accountSnapshot.hasData) {
              return Container();
            }

            final postAccount = accountSnapshot.data!;

            // Firestoreから直近24時間のfavorite_usersを取得してcount
            final recentFavoriteCount = _postFavoriteCounts[post.id] ?? 0;

            // PostItemWidget に recentFavoriteCount をそのまま渡す
            return PostItemWidget(
              post: post,
              postAccount: postAccount,
              favoriteUsersNotifier:
                  _favoritePost.favoriteUsersNotifiers[post.id] ??
                      ValueNotifier<int>(recentFavoriteCount),
              isFavoriteNotifier: ValueNotifier<bool>(
                  _favoritePost.favoritePostsNotifier.value.contains(post.id)),
              onFavoriteToggle: () {
                final isFavorite =
                    _favoritePost.favoritePostsNotifier.value.contains(post.id);
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
    );
  }

  void _onPageChanged() {
    if (_currentPage == 0 && _postSearchResults.isEmpty) {
      _searchPosts(_lastQuery);
    } else if (_currentPage == 1 && _accountSearchResults.isEmpty) {
      _searchAccounts(_lastQuery);
    } else if (_currentPage == 2 && _postSearchResults.isEmpty) {
      _fetchRecentFavorites(_lastQuery);
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

    // 取得したドキュメントに対して、文字列に query が含まれているかをフィルタリング
    final filteredPosts = querySnapshot.docs.where((doc) {
      final content = doc['content'] as String;
      return content.contains(query);
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

    final querySnapshot = await firestore.collection('users').get();

    final filteredAccounts = querySnapshot.docs.where((doc) {
      final name = doc['name'] as String;
      return name.contains(query);
    }).toList();

    setState(() {
      _accountSearchResults = filteredAccounts.map((doc) {
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
    if (query.isEmpty &&
        (_selectedCategory == null || _selectedCategory!.isEmpty)) {
      setState(() {
        _postSearchResults = [];
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // 投稿コレクションのクエリ
    Query queryRef = firestore.collection('posts');

    // カテゴリーが選択されている場合はカテゴリーでフィルタリング
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: _selectedCategory);
    }

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await queryRef.get();

    // 各投稿ごとに、過去24時間以内に追加されたお気に入りの数を取得
    final List<DocumentSnapshot> postWithFavorites = [];

    for (var doc in querySnapshot.docs) {
      final postId = doc.id;

      // 過去24時間に追加されたお気に入りの数を取得
      final favoriteUsersSnapshot = await firestore
          .collection('posts')
          .doc(postId)
          .collection('favorite_users')
          .where('added_at',
              isGreaterThanOrEqualTo:
                  DateTime.now().subtract(Duration(hours: 24)))
          .get();

      final recentFavoriteCount = favoriteUsersSnapshot.size;

      // お気に入り数を記録しておく
      postWithFavorites.add(doc);

      // ここでリストを追加する（後で使うため）
      _postFavoriteCounts[postId] = recentFavoriteCount;
    }

    // お気に入りの数で降順に並べ替え
    postWithFavorites.sort((a, b) {
      final countA = _postFavoriteCounts[a.id] ?? 0;
      final countB = _postFavoriteCounts[b.id] ?? 0;
      return countB.compareTo(countA); // お気に入り数で降順
    });

    setState(() {
      _postSearchResults = postWithFavorites;
    });
  }

  Widget _buildNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
        ],
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
                      _searchPosts('');
                      _fetchRecentFavorites('');
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
