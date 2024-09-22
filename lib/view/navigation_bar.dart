import 'package:cymva/view/post_page/post_page.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/account_page.dart';

class NavigationBarPage extends StatefulWidget {
  final int selectedIndex;
  final String userId; // ここでuserIdを追加

  const NavigationBarPage({
    super.key,
    required this.selectedIndex,
    required this.userId, // コンストラクタにも追加
  });

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  late List<Widget> pageList;

  @override
  void initState() {
    super.initState();
    // 必要なデータを用意して初期化
    pageList = [
      TimeLineBody(userId: widget.userId),
      AccountPage(userId: widget.userId),
      SearchPage(userId: widget.userId),
      PostPage(userId: widget.userId)
    ];
  }

  void _handleItemTapped(int index) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => pageList[index],
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.perm_identity_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: ''),
      ],
      currentIndex: widget.selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: _handleItemTapped, // タップされたときの処理
    );
  }
}
