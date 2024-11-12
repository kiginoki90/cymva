import 'package:cymva/model/account.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:cymva/view/time_line/follow_timeline_page.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:cymva/view/time_line/timeline_header.dart';
import 'package:flutter/material.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeLineBody extends StatefulWidget {
  final String userId;
  final bool fromLogin;

  const TimeLineBody({
    super.key,
    required this.userId,
    this.fromLogin = false, // デフォルトはfalseに設定
  });

  @override
  State<TimeLineBody> createState() => _TimeLineBodyState();
}

class _TimeLineBodyState extends State<TimeLineBody> {
  late Future<List<String>>? _favoritePostsFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final PageController _pageController = PageController();

  Account? myAccount;
  bool _hasShownPopups = false; // ポップアップ表示制御フラグ

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    _loadAccount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // fromLoginがtrueで、まだポップアップを表示していない場合のみポップアップを表示
    if (widget.fromLogin && !_hasShownPopups) {
      // ビルド後にポップアップを表示するために、PostFrameCallbackを使用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPopups(context);
      });
      _hasShownPopups = true; // ポップアップを表示済みに設定
    }
  }

  Future<void> _showPopups(BuildContext context) async {
    int _currentPage = 0;
    bool _isChecked = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 320,
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 280,
                          height: 280,
                          child: PageView(
                            onPageChanged: (int page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 46.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      SlideDirectionPageRoute(
                                        page: FullScreenImagePage(
                                          imageUrls: [
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%204.jpg?alt=media&token=bfee4359-e283-470b-ba4b-beb500050513'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%204.jpg?alt=media&token=bfee4359-e283-470b-ba4b-beb500050513',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 46.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      SlideDirectionPageRoute(
                                        page: FullScreenImagePage(
                                          imageUrls: [
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%203.jpg?alt=media&token=d06773e6-747d-4e2a-b05f-a37c3350ec0e'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%203.jpg?alt=media&token=d06773e6-747d-4e2a-b05f-a37c3350ec0e',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 46.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      SlideDirectionPageRoute(
                                        page: FullScreenImagePage(
                                          imageUrls: [
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%202.jpg?alt=media&token=b1c21b1f-4959-49d6-b5eb-4cea4585eea1'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export%202.jpg?alt=media&token=b1c21b1f-4959-49d6-b5eb-4cea4585eea1',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 100.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Checkbox(
                                            value: _isChecked,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                _isChecked = value ?? false;
                                              });
                                            },
                                          ),
                                          Text("私はロボットです"),
                                        ],
                                      ),
                                    ),
                                    // OKボタンを中央に配置
                                    if (_currentPage == 3)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 1, vertical: 1),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.blue),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text("OK"),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Page indicator
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Container(
                                margin: EdgeInsets.all(4),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    // Close button positioned at the top left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadAccount() async {
    myAccount = await getAccount(widget.userId);
    setState(() {});
  }

  Future<Account?> getAccount(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return Account.fromDocument(doc);
      } else {
        print('ユーザードキュメントが見つかりません');
      }
    } catch (e) {
      print('アカウント情報の取得に失敗しました: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (myAccount == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TimelineHeader(pageController: _pageController),
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  TimeLinePage(userId: widget.userId),
                  FollowTimelinePage(userId: widget.userId),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 0),
    );
  }
}
