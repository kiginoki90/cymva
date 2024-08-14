import 'package:cymva/view/poat/search_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/poat/time_line_page.dart';

class NavigationBarPage extends StatefulWidget {
  final int selectedIndex;

  const NavigationBarPage({
    super.key,
    required this.selectedIndex,
  });

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  late List<Widget> pageList;

  void initState() {
    super.initState();
    // 必要なデータを用意して初期化
    pageList = [
      const TimeLinePage(),
      AccountPage(userId: userId),
      SearchPage(),
    ];
  }

  void _handleItemTapped(int index) {
    if (index == 0) {
      // タイムラインページ
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TimeLinePage()),
      );
    } else if (index == 1) {
      // アカウントページ
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AccountPage(userId: userId)),
      );
    } else if (index == 2) {
      //検索ページ
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SearchPage()),
      );
      // widget.onItemTapped(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: ''),
        BottomNavigationBarItem(
            icon: Icon(Icons.perm_identity_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
      ],
      currentIndex: widget.selectedIndex,
      onTap: _handleItemTapped, // タップされたときの処理
    );
  }
}
