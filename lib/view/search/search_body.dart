import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/search/search_page.dart';
import 'package:cymva/view/search/search_text_field.dart';
import 'package:cymva/view/search/search_account_page.dart';

class SearchBody extends StatefulWidget {
  const SearchBody({super.key});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  final PageController _pageController = PageController();
  final TextEditingController _textController = TextEditingController();
  int _currentPage = 0;

  List<Account> _accountResults = [];

  void _onQueryChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _accountResults = [];
      });
      return;
    }

    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('accountName', isGreaterThanOrEqualTo: query)
        .where('accountName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _accountResults = snapshot.docs.map((doc) {
        return Account.fromDocument(doc);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchTextField(
              controller: _textController,
              onQueryChanged: _onQueryChanged,
              pageController: _pageController,
              currentPage: _currentPage,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  SearchPage(),
                  SearchAccountPage(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 2),
    );
  }
}

// Accountクラスの定義例
class Account {
  final String accountName;
  final String id;

  Account({required this.accountName, required this.id});

  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      accountName: doc['accountName'] ?? '',
      id: doc.id,
    );
  }
}
