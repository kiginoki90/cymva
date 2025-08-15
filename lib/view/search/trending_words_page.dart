import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/search/search_page.dart';

class TrendingWordsPage extends StatefulWidget {
  const TrendingWordsPage({Key? key}) : super(key: key);

  @override
  _TrendingWordsPageState createState() => _TrendingWordsPageState();
}

class _TrendingWordsPageState extends State<TrendingWordsPage> {
  final FlutterSecureStorage storage = FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> fetchTrendingWords() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('trend')
          .orderBy('ranking',
              descending: false) // 修正: ascending -> descending: false
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました: $e', backgroundColor: Colors.red);
      return [];
    }
  }

  void navigateToSearchPage(String word) async {
    try {
      // wordをストレージに保存
      await storage.write(key: 'query', value: word);

      // 現在ログインしているユーザーIDを取得
      final userId = await storage.read(key: 'account_id');
      if (userId == null) {
        showTopSnackBar(context, 'ユーザーIDが見つかりません', backgroundColor: Colors.red);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SearchPage(userId: userId, notdDleteStotage: true),
        ),
      );
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました: $e', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchTrendingWords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('トレンドワードが見つかりません'));
          }

          final trendingWords = snapshot.data!;

          return ListView.builder(
            itemCount: trendingWords.length,
            itemBuilder: (context, index) {
              final word = trendingWords[index]['word'] ?? '不明';

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: ListTile(
                  title: Text(word),
                  onTap: () => navigateToSearchPage(word),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
