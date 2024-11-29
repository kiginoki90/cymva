import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';

class SearchItem {
  final FirebaseFirestore firestore;

  SearchItem(this.firestore);

//コンテンツの検索条件
  Future<void> searchPosts(
    String query,
    String? selectedCategory,
    DocumentSnapshot? lastDocument,
    int limit,
    Function(List<DocumentSnapshot>) updateResults,
  ) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty)) {
      updateResults([]);
      return;
    }

    // 投稿コレクションのクエリ
    Query queryRef =
        firestore.collection('posts').orderBy('created_time', descending: true);

    // カテゴリーが選択されている場合はカテゴリーでフィルタリング
    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: selectedCategory);
    }

    // 前回の最後のドキュメントから続けて取得
    if (lastDocument != null) {
      queryRef = queryRef.startAfterDocument(lastDocument);
    }

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await queryRef.get();

    // クエリを小文字に変換し、スペースで分割
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 取得したドキュメントに対して、すべての単語が含まれているかをフィルタリング
    final filteredPosts = querySnapshot.docs
        .where((doc) {
          final content =
              (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
          return queryWords.every((word) => content.contains(word));
        })
        .take(100) // ここで結果を100件までに制限
        .toList();

    updateResults(filteredPosts);
  }

  Future<void> searchAccounts(
    String query,
    Function(List<Account>) updateResults,
  ) async {
    if (query.isEmpty) {
      updateResults([]);
      return;
    }

    // クエリを小文字に変換
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 検索結果を格納するリスト
    final Set<String> uniqueAccountIds = {}; // 重複を防ぐためのセット
    final List<DocumentSnapshot> allDocs = [];

    // ユーザー名に対するクエリ
    Query nameQuery = firestore.collection('users');
    // ユーザーIDに対するクエリ
    Query userIdQuery = firestore.collection('users');

    for (String word in queryWords) {
      if (word.isNotEmpty) {
        nameQuery = nameQuery
            .where('name', isGreaterThanOrEqualTo: word)
            .where('name', isLessThanOrEqualTo: word + '\uf8ff');
        userIdQuery = userIdQuery
            .where('user_id', isGreaterThanOrEqualTo: word)
            .where('user_id', isLessThanOrEqualTo: word + '\uf8ff');
      }
    }

    // `name`フィールドに対するクエリ
    final nameQuerySnapshot = await nameQuery.get();
    // `user_id`フィールドに対するクエリ
    final userIdQuerySnapshot = await userIdQuery.get();

    // 名前の結果を追加
    for (var doc in nameQuerySnapshot.docs) {
      if (uniqueAccountIds.add(doc.id)) {
        allDocs.add(doc);
      }
    }

    // ユーザーIDの結果を追加
    for (var doc in userIdQuerySnapshot.docs) {
      if (uniqueAccountIds.add(doc.id)) {
        allDocs.add(doc);
      }
    }

    // 最終的な結果を100件までに制限
    final limitedResults = allDocs.take(100).toList();

    updateResults(limitedResults.map((doc) {
      return Account.fromDocument(doc);
    }).toList());
  }

  Future<Account?> getPostAccount(String accountId) async {
    final doc = await firestore.collection('users').doc(accountId).get();

    if (doc.exists) {
      return Account.fromDocument(doc);
    } else {
      return null;
    }
  }

//人気の検索条件
  Future<void> fetchRecentFavorites(
    String query,
    String? selectedCategory,
    Map<String, int> postFavoriteCounts,
    Function(List<DocumentSnapshot>) updateResults,
  ) async {
    Query queryRef = firestore.collection('posts');

    // カテゴリーが選択されている場合は、カテゴリーでフィルタリング
    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: selectedCategory);
    }

    try {
      final querySnapshot = await queryRef.get();

      final List<DocumentSnapshot> postWithFavorites = [];

      // クエリを小文字に変換し、スペースで分割
      final lowerCaseQuery = query.toLowerCase();
      final queryWords = lowerCaseQuery.split(' ');

      // 各投稿に対してFutureのリストを作成
      final futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;

        // お気に入りユーザーを取得
        final favoriteUsersSnapshot = await firestore
            .collection('posts')
            .doc(postId)
            .collection('favorite_users')
            .where('added_at',
                isGreaterThanOrEqualTo:
                    DateTime.now().subtract(Duration(hours: 24)))
            .get();

        final recentFavoriteCount = favoriteUsersSnapshot.size;

        // 投稿の内容がクエリに含まれているかをチェック
        final content =
            (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
        if (query.isNotEmpty &&
            !queryWords.every((word) => content.contains(word))) {
          return;
        }

        // お気に入り数を記録しておく
        postWithFavorites.add(doc);
        postFavoriteCounts[postId] = recentFavoriteCount;
      });

      // すべてのFutureが完了するのを待つ
      await Future.wait(futures);

      // お気に入りの数で降順に並べ替え
      postWithFavorites.sort((a, b) {
        final countA = postFavoriteCounts[a.id] ?? 0;
        final countB = postFavoriteCounts[b.id] ?? 0;
        return countB.compareTo(countA);
      });

      // 最終的な結果を100件までに制限
      final limitedResults = postWithFavorites.take(100).toList();

      updateResults(limitedResults);
    } catch (error) {
      // エラーハンドリング
      print('Error fetching recent favorites: $error');
    }
  }

  Future<void> searchImagePosts(
    String query,
    String? selectedCategory,
    Function(List<DocumentSnapshot>) updateResults,
  ) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty)) {
      updateResults([]);
      return;
    }

    // 投稿コレクションのクエリ
    Query queryRef =
        firestore.collection('posts').orderBy('created_time', descending: true);

    // カテゴリーが選択されている場合はカテゴリーでフィルタリング
    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      queryRef = queryRef.where('category', isEqualTo: selectedCategory);
    }

    // クエリを使って、候補となるドキュメントを取得
    final querySnapshot = await queryRef.get();

    // クエリを小文字に変換し、スペースで分割
    final lowerCaseQuery = query.toLowerCase();
    final queryWords = lowerCaseQuery.split(' ');

    // 取得したドキュメントに対して、文字列に query が含まれているかをフィルタリング
    final filteredPosts = querySnapshot.docs
        .where((doc) {
          final content =
              (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
          final mediaUrl =
              doc['media_url'] as List<dynamic>?; // media_urlのフィールド

          // 投稿の内容がすべての単語を含むかつmedia_urlが存在するかをチェック
          return queryWords.every((word) => content.contains(word)) &&
              mediaUrl != null &&
              mediaUrl.isNotEmpty;
        })
        .take(100)
        .toList(); // ここで結果を100件までに制限

    updateResults(filteredPosts);
  }
}
