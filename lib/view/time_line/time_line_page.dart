import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/float_bottom.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cymva/view/post_detail_page.dart';

class TimeLinePage extends StatefulWidget {
  const TimeLinePage({super.key});

  @override
  State<TimeLinePage> createState() => _TimeLineState();
}

class _TimeLineState extends State<TimeLinePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('タイムライン'),
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PostFirestore.posts
            .orderBy('created_time', descending: true)
            .snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.hasData) {
            List<String> postAccountIds = [];
            postSnapshot.data!.docs.forEach((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              // print(doc.data());
              //取得したデータにpost_account_idが含まれていない場合追加する。
              if (!postAccountIds.contains(data['post_account_id'])) {
                postAccountIds.add(data['post_account_id']);
              }
            });
            return FutureBuilder<Map<String, Account>?>(
              future: UserFirestore.getPostUserMap(postAccountIds),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData &&
                    userSnapshot.connectionState == ConnectionState.done) {
                  return ListView.builder(
                    itemCount: postSnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> data = postSnapshot.data!.docs[index]
                          .data() as Map<String, dynamic>;
                      Post post = Post(
                        id: postSnapshot.data!.docs[index].id,
                        content: data['content'],
                        postAccountId: data['post_account_id'],
                        createdTime: data['created_time'],
                        mediaUrl: data['media_url'],
                        isVideo: data['is_video'] ?? false,
                      );
                      Account postAccount =
                          userSnapshot.data![post.postAccountId]!;
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                post: post,
                                postAccountName: postAccount.name,
                                postAccountUserId: postAccount.userId,
                                postAccountImagePath: postAccount.imagePath,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: index == 0
                                ? const Border(
                                    top: BorderSide(
                                        color: Colors.grey, width: 0),
                                    bottom: BorderSide(
                                        color: Colors.grey, width: 0),
                                  )
                                : const Border(
                                    bottom: BorderSide(
                                        color: Colors.grey, width: 0),
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AccountPage(
                                          userId: post.postAccountId),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(8.0), // 角を丸める
                                  child: Image.network(
                                    postAccount.imagePath,
                                    width: 44, // 高さをCircleAvatarの直径に合わせる
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
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              postAccount.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              '@${postAccount.userId}',
                                              style: const TextStyle(
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        Text(DateFormat('yyyy/M/d').format(
                                            post.createdTime!.toDate())),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(post.content),
                                        const SizedBox(height: 10),
                                        if (post.isVideo)
                                          AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: VideoPlayer(
                                                VideoPlayerController
                                                    .networkUrl(Uri.parse(
                                                        post.mediaUrl!))),
                                          )
                                        else if (post.mediaUrl != null)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FullScreenImagePage(
                                                          imageUrl:
                                                              post.mediaUrl!),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxHeight: 400,
                                              ),
                                              child: Image.network(
                                                post.mediaUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              ),
                                            ),
                                          )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Container();
                }
              },
            );
          } else {
            return Container();
          }
        },
      ),
      floatingActionButton: FloatBottom(),
      bottomNavigationBar: NavigationBarPage(
        selectedIndex: 0,
      ),
    );
  }
}
