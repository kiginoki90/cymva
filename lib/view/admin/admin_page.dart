import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/admin/hidden_post_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:flutter/widgets.dart';

class AdminPage extends StatefulWidget {
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Future<List<String>> _fetchReportedPostIds() async {
    // reportsコレクションからpostIdを取得
    final querySnapshot =
        await FirebaseFirestore.instance.collection('reports').get();
    return querySnapshot.docs.map((doc) => doc['postId'] as String).toList();
  }

  Future<List<QueryDocumentSnapshot>> _fetchPosts(List<String> postIds) async {
    // postsコレクションから該当するpostIdの投稿を取得し、古い順に並べ替え
    final querySnapshot = await PostFirestore.posts
        .where(FieldPath.documentId, whereIn: postIds)
        .orderBy('created_time', descending: false)
        .get();
    return querySnapshot.docs;
  }

  Future<void> _refreshPosts() async {
    setState(() {
      // 再描画をトリガーするためのsetState
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('管理者ページ'), actions: [
        IconButton(
          icon: Icon(Icons.visibility_off),
          onPressed: () {
            // アイコンが押されたときに画面遷移
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HiddenPostsPage()),
            );
          },
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<String>>(
          future: _fetchReportedPostIds(),
          builder: (context, reportSnapshot) {
            if (reportSnapshot.hasData) {
              List<String> reportedPostIds = reportSnapshot.data!;

              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchPosts(reportedPostIds),
                builder: (context, postSnapshot) {
                  if (postSnapshot.hasData) {
                    List<String> postAccountIds = [];
                    postSnapshot.data!.forEach((doc) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      if (!postAccountIds.contains(data['post_account_id'])) {
                        postAccountIds.add(data['post_account_id']);
                      }
                    });

                    return FutureBuilder<Map<String, Account>?>(
                      future: UserFirestore.getPostUserMap(postAccountIds),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData &&
                            userSnapshot.connectionState ==
                                ConnectionState.done) {
                          List<Post> visiblePosts = postSnapshot.data!
                              .map((doc) => Post.fromDocument(doc))
                              .toList();

                          return ListView.builder(
                            itemCount: visiblePosts.length,
                            itemBuilder: (context, index) {
                              Post post = visiblePosts[index];

                              Account postAccount =
                                  userSnapshot.data![post.postAccountId]!;

                              return Column(
                                children: [
                                  PostItemWidget(
                                    post: post,
                                    postAccount: postAccount,
                                    favoriteUsersNotifier:
                                        ValueNotifier<int>(0),
                                    isFavoriteNotifier:
                                        ValueNotifier<bool>(false),
                                    onFavoriteToggle: () {
                                      // 管理者ページではお気に入り機能を使わないか、または別のロジックを実装
                                    },
                                    isRetweetedNotifier:
                                        ValueNotifier<bool>(false),
                                    onRetweetToggle: () {
                                      // リツイート機能の処理
                                    },
                                    replyFlag: ValueNotifier<bool>(false),
                                    userId: postAccount.id, // 管理者として閲覧する場合
                                  ),
                                  PopupMenuButton(
                                    onSelected: (String value) {
                                      if (value == '1')
                                        _hidePost(context, post);
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return [
                                        PopupMenuItem<String>(
                                          value: '1',
                                          child: Text(
                                            'サイレント',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ];
                                    },
                                    icon: const Icon(Icons.view_cozy),
                                  ),
                                  Divider(
                                    color: Colors.black,
                                    thickness: 3,
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                      },
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<void> _hidePost(BuildContext context, Post post) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id) // post.id で該当ドキュメントを参照
          .update({
        'hide': true, // hide フィールドを true に更新
      });

      // 更新が成功したら表示するメッセージや処理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を非表示にしました')),
      );
    } catch (e) {
      // エラー時の処理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を非表示にできませんでした: $e')),
      );
    }
  }
}
