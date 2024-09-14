import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';

class SearchAccountPage extends StatefulWidget {
  const SearchAccountPage({super.key});

  @override
  State<SearchAccountPage> createState() => _SearchAccountPageState();
}

class _SearchAccountPageState extends State<SearchAccountPage> {
  List<DocumentSnapshot> _searchResults = [];

  Future<void> _searchAccounts(String query) async {
    final firestore = FirebaseFirestore.instance;

    final querySnapshot = await firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _searchResults = querySnapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final userDoc = _searchResults[index];
        final account = Account.fromDocument(userDoc);

        return ListTile(
          title: Text(account.name), // アカウント名を表示
          // subtitle: Text(account.bio), // アカウントの説明などを表示
          onTap: () {
            // アカウント詳細ページに遷移する処理など
          },
        );
      },
    );
  }
}
