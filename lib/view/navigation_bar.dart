import 'package:cymva/view/post_page/post_page.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  List<Widget>? pageList;
  String? userId;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    userId = await storage.read(key: 'account_id') ??
        FirebaseAuth.instance.currentUser?.uid;

    // userIdが取得できたらpageListを初期化
    setState(() {
      pageList = [
        TimeLineBody(userId: userId!),
        AccountPage(postUserId: userId!),
        SearchPage(userId: userId!),
        PostPage(userId: userId!),
      ];
    });
  }

  void _handleItemTapped(int index) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) =>
            pageList![index], // nullチェック
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pageList == null) {
      return Center(child: CircularProgressIndicator()); // ローディング中の表示
    }

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
