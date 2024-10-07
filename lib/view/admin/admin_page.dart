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

Future<List<QueryDocumentSnapshot>> _fetchReportsByPostAccountId(
    String postAccountId) async {
  // reportsコレクションからpostAccountIdに該当するドキュメントを取得
  final querySnapshot = await FirebaseFirestore.instance
      .collection('reports')
      .where('postAccountId', isEqualTo: postAccountId)
      .get();
  return querySnapshot.docs;
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('管理者ページ'), actions: [
        IconButton(
          icon: Icon(Icons.visibility_off),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HiddenPostsPage()),
            );
          },
        ),
      ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, reportSnapshot) {
          if (reportSnapshot.hasData) {
            List<String> reportedPostIds = reportSnapshot.data!.docs
                .map((doc) => doc['postId'] as String)
                .toList();

            // report_content とそのカウントを保持するマップ
            Map<String, int> reportCounts = {};
            Map<String, String> reportTypes = {};

            for (var doc in reportSnapshot.data!.docs) {
              String postId = doc['postId'];
              String reportContent = doc['report_reason'] ?? 'Unknown';

              // カウントを増やす
              reportCounts[postId] = (reportCounts[postId] ?? 1);
              reportTypes[postId] = reportContent;
            }

            if (reportedPostIds.isNotEmpty) {
              return StreamBuilder<QuerySnapshot>(
                stream: PostFirestore.posts
                    .where(FieldPath.documentId, whereIn: reportedPostIds)
                    .orderBy('created_time', descending: false)
                    .snapshots(),
                builder: (context, postSnapshot) {
                  if (postSnapshot.hasData) {
                    List<String> postAccountIds = [];
                    for (var doc in postSnapshot.data!.docs) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      if (!postAccountIds.contains(data['post_account_id'])) {
                        postAccountIds.add(data['post_account_id']);
                      }
                    }

                    return FutureBuilder<Map<String, Account>?>(
                      future: UserFirestore.getPostUserMap(postAccountIds),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData &&
                            userSnapshot.connectionState ==
                                ConnectionState.done) {
                          List<Post> visiblePosts = postSnapshot.data!.docs
                              .map((doc) => Post.fromDocument(doc))
                              .toList();

                          return ListView.builder(
                            itemCount: visiblePosts.length,
                            itemBuilder: (context, index) {
                              Post post = visiblePosts[index];
                              Account postAccount =
                                  userSnapshot.data![post.postAccountId]!;

                              String reportContent =
                                  reportTypes[post.id] ?? 'Unknown';
                              int reportCount = reportCounts[post.id] ?? 0;

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
                                    userId: postAccount.id,
                                  ),
                                  Row(
                                    children: [
                                      // report_content とそのカウントを表示
                                      Text('タイプ：$reportContent'),
                                      SizedBox(width: 15),
                                      Text('カウント：$reportCount'),
                                      SizedBox(width: 30),
                                      PopupMenuButton(
                                        onSelected: (String value) {
                                          if (value == '1')
                                            _hidePost(context, post);
                                          if (value == '2')
                                            _releasePost(context, post);
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return [
                                            PopupMenuItem<String>(
                                              value: '1',
                                              child: Text(
                                                'サイレント',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: '2',
                                              child: Text(
                                                '解除',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                            ),
                                          ];
                                        },
                                        icon: const Icon(Icons.view_cozy),
                                      ),
                                    ],
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
              return const Center(child: Text('報告がありません'));
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<void> _hidePost(BuildContext context, Post post) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(post.id).update({
        'hide': true,
      });

      final reportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('postId', isEqualTo: post.id)
          .get();

      for (var reportDoc in reportsQuery.docs) {
        await reportDoc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を非表示にしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を非表示にできませんでした: $e')),
      );
    }
  }

  Future<void> _releasePost(BuildContext context, Post post) async {
    try {
      final reportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('postId', isEqualTo: post.id)
          .get();

      for (var reportDoc in reportsQuery.docs) {
        await reportDoc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解除しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解除できませんでした: $e')),
      );
    }
  }
}
