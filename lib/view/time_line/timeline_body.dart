import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/edit_page/options_page/support_page/terms_of_service_page.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:cymva/view/time_line/follow_timeline_page.dart';
import 'package:cymva/view/time_line/ranking_page.dart';
import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:cymva/view/time_line/timeline_header.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TimeLineBody extends StatefulWidget {
  final String userId;
  final bool? fromLogin;

  const TimeLineBody({
    super.key,
    required this.userId,
    this.fromLogin = false, // デフォルトはfalseに設定
  });

  @override
  State<TimeLineBody> createState() => _TimeLineBodyState();
}

class _TimeLineBodyState extends State<TimeLineBody> {
  final PageController _pageController = PageController();
  bool _hasShownPopups = false; // ポップアップ表示制御フラグ
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveLastPageIndex(int index) async {
    await storage.write(
      key: 'TimeLine',
      value: index.toString(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // fromLoginがtrueで、まだポップアップを表示していない場合のみポップアップを表示
    if (widget.fromLogin == true && !_hasShownPopups) {
      // ビルド後にポップアップを表示するために、PostFrameCallbackを使用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFirstLoginAndShowPopups(context);
      });
      _hasShownPopups = true; // ポップアップを表示済みに設定
    }
  }

  Future<void> _checkFirstLoginAndShowPopups(BuildContext context) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && userDoc['first_login'] == true) {
        await _showTermsAndConditionsPopup(context);
        // 利用規約のポップアップが閉じられた後に、他のポップアップを表示
        await _showPopups(context);
      } else {
        await _showPopups(context);
      }
    } catch (e) {
      print('ユーザードキュメントの取得に失敗しました: $e');
    }
  }

  Future<void> _showTermsAndConditionsPopup(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          appBar: AppBar(
            title: Text('利用規約'),
            automaticallyImplyLeading: false, // 戻るボタンを非表示にする
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本サービスを利用するにあたり、以下の内容を含む投稿や送信を行うことは禁止されています。',
                        ),
                        SizedBox(height: 16),
                        _buildSectionContent([
                          '　（1）',
                          '過度に暴力的または露骨な性的表現を含む内容。',
                        ]),
                        _buildSectionContent([
                          '　（2）',
                          '差別、ヘイトスピーチ、または誹謗中傷を含む内容。',
                        ]),
                        _buildSectionContent([
                          '　（3）',
                          '犯罪行為を誘発または助長する内容。',
                        ]),
                        _buildSectionContent([
                          '　（4）',
                          '他者のプライバシーを侵害する内容。',
                        ]),
                        _buildSectionContent([
                          '　（5）',
                          '他者の著作権、商標権、プライバシー権を侵害する行為。',
                        ]),
                        SizedBox(height: 16),
                        Text(
                          '詳しい利用規約は下記を参照ください',
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TermsOfServicePage(),
                              ),
                            );
                          },
                          child: Text(
                            '詳しくみる',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 利用規約に同意したことを保存
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .update({'first_login': false});
                      Navigator.of(context).pop();
                    },
                    child: Text('同意する'),
                  ),
                ),
                SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionContent(List<String> contentParts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contentParts[0],
          style: TextStyle(fontSize: 13),
        ),
        Expanded(
          child: Text(
            contentParts[1],
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
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
                width: 340,
                height: 670,
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 280,
                          height: 620,
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
                                          imageUrls: const [
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0036%202.JPG?alt=media&token=30c2a267-2ed9-4b5a-9260-01560b98d0f5'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0036%202.JPG?alt=media&token=30c2a267-2ed9-4b5a-9260-01560b98d0f5',
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
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0037.JPG?alt=media&token=51d83dc5-5aeb-4534-9f60-c686aca6bd38'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0037.JPG?alt=media&token=51d83dc5-5aeb-4534-9f60-c686aca6bd38',
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
                                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0039.JPG?alt=media&token=748b8d99-15f3-49fa-87ea-ee2d564f29b1'
                                          ],
                                          initialIndex: 0,
                                        ),
                                        isSwipeUp: true,
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/IMG_0039.JPG?alt=media&token=748b8d99-15f3-49fa-87ea-ee2d564f29b1',
                                    fit: BoxFit.cover,
                                  ),
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
                            children: List.generate(3, (index) {
                              return Container(
                                margin: EdgeInsets.all(3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TimelineHeader(pageController: _pageController),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  _saveLastPageIndex(index);
                },
                children: [
                  TimeLinePage(userId: widget.userId),
                  RankingPage(userId: widget.userId),
                  FollowTimelinePage(userId: widget.userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
