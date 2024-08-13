import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/float_bottom.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cymva/view/post_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController =
      TextEditingController(); //テキスト入力を管理するためのクラス
  List<DocumentSnapshot> _searchResults = []; //Listは複数のアイテムを順序づけて保存するためのデータ構造

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller:
                  _searchController, //TextField の状態を管理するために TextEditingController を指定している。
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _searchPosts(query);
                } else {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: '検索...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, Account>?>(
        future:
            _getAccountsForPosts(), // 投稿に関連するアカウント情報を取得する。futureは非同期でデータを取得するプロパティ
        builder: (context, snapshot) {
          print(context);
          //リストが正常に取得できた場合
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            final userMap = snapshot.data!;
            return ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final post =
                    _searchResults[index].data() as Map<String, dynamic>;
                final postAccountId = post['post_account_id'];
                final account = userMap[postAccountId];

                if (account == null) return Container();

                final postContent = post['content'];
                final postCreatedTime = post['created_time'];
                final postMediaUrl = post['media_url'];
                final postIsVideo = post['is_video'] ?? false;

                return InkWell(
                  //InkWellはタップ可能な領域
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(
                          post: Post(
                            id: _searchResults[index].id,
                            content: postContent,
                            postAccountId: postAccountId,
                            createdTime: postCreatedTime,
                            mediaUrl: postMediaUrl,
                            isVideo: postIsVideo,
                          ),
                          postAccountName: account.name,
                          postAccountUserId: account.userId,
                          postAccountImagePath: account.imagePath,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: index == 0
                          ? const Border(
                              top: BorderSide(color: Colors.grey, width: 0),
                              bottom: BorderSide(color: Colors.grey, width: 0),
                            )
                          : const Border(
                              bottom: BorderSide(color: Colors.grey, width: 0),
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                // ユーザーのページに遷移
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AccountPage(userId: postAccountId),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  account.imagePath,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '@${account.userId}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('yyyy/M/d')
                                  .format(postCreatedTime.toDate()),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(postContent),
                        const SizedBox(height: 10),
                        if (postMediaUrl != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImagePage(
                                    imageUrl: postMediaUrl,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: 400,
                              ),
                              child: Image.network(
                                postMediaUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatBottom(),
      bottomNavigationBar: NavigationBarPage(
        selectedIndex: 2,
      ),
    );
  }

  Future<Map<String, Account>?> _getAccountsForPosts() async {
    // 検索結果の各投稿に関連するアカウント情報を一括で取得する
    List<String> postAccountIds = _searchResults
        .map((doc) => doc['post_account_id'] as String)
        .toSet()
        .toList();

    return await UserFirestore.getPostUserMap(postAccountIds);
  }

  Future<void> _searchPosts(String query) async {
    // FirebaseFirestoreのインスタンスを取得
    final firestore = FirebaseFirestore.instance;

    // クエリを実行
    final querySnapshot = await firestore
        .collection('posts') // コレクション名を指定
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _searchResults = querySnapshot.docs;
    });
  }
}
