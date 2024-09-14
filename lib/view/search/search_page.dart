import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/edit_page/account_top_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/utils/favorite_post.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

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
  String _lastQuery = ''; // 最後に検索したクエリを保存

  @override
  void initState() {
    super.initState();

    // リアルタイムでテキストフィールドの変化を監視
    _searchController.addListener(() {
      _lastQuery = _searchController.text; // クエリを保存
      if (_currentPage == 0) {
        _searchPosts(_lastQuery); // 投稿を検索
      } else {
        _searchAccounts(_lastQuery); // アカウントを検索
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
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '検索...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // ナビゲーション
          _buildNavigationBar(),
          // スワイプでページ遷移するPageView
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (pageIndex) {
                setState(() {
                  _currentPage = pageIndex;
                });

                // ページ切り替え時に再検索せず、保存されたクエリで結果を表示
                if (_currentPage == 0 && _postSearchResults.isEmpty) {
                  _searchPosts(_lastQuery); // 投稿を再表示
                } else if (_currentPage == 1 && _accountSearchResults.isEmpty) {
                  _searchAccounts(_lastQuery); // アカウントを再表示
                }
              },
              children: [
                _buildSearchByTextPage(), // 投稿の検索結果ページ
                _buildSearchByAccountNamePage(), // アカウント名での検索結果ページ
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 2),
    );
  }

  // 投稿の検索結果を表示するウィジェット
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
              return Container(); // アカウント情報が取得できない場合は何も表示しない
            }

            final postAccount = accountSnapshot.data!;

            return PostItemWidget(
              post: post,
              postAccount: postAccount,
              favoriteUsersNotifier:
                  _favoritePost.favoriteUsersNotifiers[post.id] ??
                      ValueNotifier<int>(0),
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
            );
          },
        );
      },
    );
  }

  // アカウント名での検索結果を表示するウィジェット
  Widget _buildSearchByAccountNamePage() {
    return ListView.builder(
      itemCount: _accountSearchResults.length,
      itemBuilder: (context, index) {
        final account = _accountSearchResults[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              // アイコンを表示
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  account.imagePath, // アカウントのプロフィール画像パス
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              // アカウント名とユーザーIDを表示
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
                            account.name, // アカウント名
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '@${account.userId}', // ユーザーID
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 自己紹介文を最大23文字に制限
                      Text(
                        account.selfIntroduction.length > 230
                            ? '${account.selfIntroduction.substring(0, 231)}...'
                            : account.selfIntroduction, // 23文字以下の場合はそのまま表示
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        maxLines: 4, // 最大1行
                        overflow: TextOverflow.ellipsis, // オーバーフロー時に"..."を表示
                        softWrap: true, // 行があふれた場合の自動改行を許可
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

  // テキストフィールドで投稿を検索する
  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _postSearchResults = [];
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await firestore.collection('posts').get();

    // 取得したドキュメントに対して、文字列に `query` が含まれているかをフィルタリング
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

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await firestore.collection('users').get();

    // 取得したドキュメントに対して、文字列に `query` が含まれているかをフィルタリング
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

  // 投稿のアカウント情報を取得する
  Future<Account?> _getPostAccount(String accountId) async {
    final firestore = FirebaseFirestore.instance;

    final doc = await firestore.collection('users').doc(accountId).get();

    if (doc.exists) {
      return Account.fromDocument(doc);
    } else {
      return null;
    }
  }

  // ナビゲーションバーを構築する
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
        ],
      ),
    );
  }
}
