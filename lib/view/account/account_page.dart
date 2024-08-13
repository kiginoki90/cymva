import 'package:cymva/view/float_bottom.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/edit_account_page.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/view/post_detail_page.dart';

class AccountPage extends StatefulWidget {
  final String userId; // ユーザーIDを受け取る
  const AccountPage({super.key, required this.userId});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Account? myAccount; // myAccount を nullable に変更

  @override
  void initState() {
    super.initState();
    _getAccount();
  }

//userIDを利用してアカウント情報を取得する。
  Future<void> _getAccount() async {
    final Account? account = await UserFirestore.getUser(widget.userId);
    if (account == null) {
      // エラーメッセージを表示
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ユーザー情報が取得できませんでした')));
      // タイムラインページへ遷移
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const TimeLinePage()));
    } else {
      setState(() {
        myAccount = account;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(right: 15, left: 15, top: 20),
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0), // 角を丸める
                            child: Image.network(
                              myAccount!.imagePath,
                              width: 70, // 高さをCircleAvatarの直径に合わせる
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                myAccount!.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '@${myAccount!.userId}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          )
                        ],
                      ),
                      OutlinedButton(
                          onPressed: () async {
                            var result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditAccountPage()));
                            if (result == true) {
                              setState(() {
                                myAccount = Authentication.myAccount!;
                              });
                            }
                          },
                          child: const Text('編集'))
                    ],
                  ),
                  SizedBox(height: 15),
                  Text(myAccount!.selfIntroduction)
                ],
              ),
            ),
            Container(
              alignment: Alignment.center,
              width: double.infinity,
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.blue, width: 3))),
              child: const Text(
                '投稿',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: UserFirestore.users
                    .doc(myAccount!.id)
                    .collection('my_posts')
                    .orderBy('created_time', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    List<String> myPostIds =
                        List.generate(snapshot.data!.docs.length, (index) {
                      return snapshot.data!.docs[index].id;
                    });
                    return FutureBuilder<List<Post>?>(
                      future: PostFirestore.getPostsFromIds(myPostIds),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              Post post = snapshot.data![index];
                              bool hasMedia =
                                  post.isVideo || post.mediaUrl != null;
                              return InkWell(
                                //ポストをタップすると詳細ページへ
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailPage(
                                        post: post,
                                        postAccountName: myAccount!.name,
                                        postAccountUserId: myAccount!.userId,
                                        postAccountImagePath:
                                            myAccount!.imagePath,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  // height: hasMedia ? 550 : null,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      //アイコン
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0), // 角を丸める
                                        child: Image.network(
                                          myAccount!.imagePath,
                                          width: 44, // 高さをCircleAvatarの直径に合わせる
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      myAccount!.name,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    Text(
                                                      '@${myAccount!.userId}',
                                                      style: const TextStyle(
                                                          color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                                Text(DateFormat('yyyy/M/d')
                                                    .format(post.createdTime!
                                                        .toDate())),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
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
                                                            .networkUrl(
                                                                Uri.parse(post
                                                                    .mediaUrl!))),
                                                  )
                                                else if (post.mediaUrl != null)
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              FullScreenImagePage(
                                                                  imageUrl: post
                                                                      .mediaUrl!),
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      constraints:
                                                          BoxConstraints(
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
            )
          ],
        ),
      ),
      floatingActionButton: FloatBottom(),
      bottomNavigationBar: NavigationBarPage(
        selectedIndex: 1,
      ),
    );
  }
}
