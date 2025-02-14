import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';

class SearchItem {
  final FirebaseFirestore firestore;

  SearchItem(this.firestore);

  //コンテンツの検索条件
  Future<void> searchPosts(
    String query,
    String? userId,
    String? selectedCategory,
    DocumentSnapshot? lastDocument,
    Function(List<DocumentSnapshot>) updateResults, {
    String? searchUserId,
    bool? isExactMatch,
    bool? isFollowing,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        isFollowing == null &&
        startDate == null &&
        endDate == null) {
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

    // ユーザーIDでフィルタリング
    if (searchUserId != null && searchUserId.isNotEmpty) {
      // まずは全てのドキュメントを取得
      final allDocumentsSnapshot = await queryRef.get();

      // フィルタリングをクライアント側で行う
      final filteredDocuments = allDocumentsSnapshot.docs.where((doc) {
        final postUserId = doc['post_user_id'] as String;
        if (isExactMatch!) {
          // 完全一致検索
          return postUserId == searchUserId;
        } else {
          // 部分一致検索
          return postUserId.contains(searchUserId);
        }
      }).toList();

      // クエリ結果を更新
      queryRef = queryRef.where(FieldPath.documentId,
          whereIn: filteredDocuments.map((doc) => doc.id).toList());
    }

    // フォローしているかどうかでフィルタリング
    if (isFollowing == true && userId != null) {
      // フォローしているユーザーのリストを取得
      final followSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('follow')
          .get();

      final followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

      // フォローしているユーザーの投稿のみをフィルタリング
      queryRef = queryRef.where('post_account_id', whereIn: followUserIds);
    }

    // 日付範囲でフィルタリング
    if (startDate != null) {
      queryRef =
          queryRef.where('created_time', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      // endDateの時間部分を23:59:59に設定
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      queryRef = queryRef.where('created_time', isLessThanOrEqualTo: endOfDay);
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

  // 人気の検索条件
  Future<void> fetchRecentFavorites(
    String query,
    String? userId,
    String? selectedCategory,
    Map<String, int> postFavoriteCounts,
    Function(List<DocumentSnapshot>) updateResults, {
    String? searchUserId,
    bool? isExactMatch,
    bool? isFollowing,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (userId == null || userId.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        isFollowing == null &&
        startDate == null &&
        endDate == null) {
      updateResults([]);
      return;
    }

    try {
      // 投稿コレクションのクエリ
      Query queryRef = firestore.collection('posts');

      // カテゴリーが選択されている場合はカテゴリーでフィルタリング
      if (selectedCategory != null && selectedCategory.isNotEmpty) {
        queryRef = queryRef.where('category', isEqualTo: selectedCategory);
      }

      // ユーザーIDでフィルタリング
      if (searchUserId != null && searchUserId.isNotEmpty) {
        if (isExactMatch == true) {
          // 完全一致検索
          queryRef = queryRef.where('post_user_id', isEqualTo: searchUserId);
        } else {
          // 部分一致検索はクライアント側で行う必要があるため、全てのドキュメントを取得
          final allDocumentsSnapshot = await queryRef.get();

          // 部分一致検索をクライアント側で行う
          final filteredDocuments = allDocumentsSnapshot.docs.where((doc) {
            final postUserId = doc['post_user_id'] as String;
            return postUserId.contains(searchUserId);
          }).toList();

          // クエリ結果を更新
          queryRef = queryRef.where(FieldPath.documentId,
              whereIn: filteredDocuments.map((doc) => doc.id).toList());
        }
      }

      if (isFollowing == true && userId != null) {
        final filteredSnapshot = await queryRef.get();

        // フォローしているユーザーのリストを取得
        final followSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('follow')
            .get();

        final followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

        // フォローしているユーザーの投稿のみをフィルタリング
        queryRef = queryRef.where('post_account_id', whereIn: followUserIds);

        // フィルタリングされた結果の数を確認
        // final filteredSnapshot = await queryRef.get();
        print('フォロー結果の数: ${filteredSnapshot.size}');
      }

      // 日付範囲でフィルタリング
      if (startDate != null) {
        queryRef =
            queryRef.where('created_time', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        final endOfDay =
            DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        queryRef =
            queryRef.where('created_time', isLessThanOrEqualTo: endOfDay);
      }

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
            .get();

        // お気に入りの登録時間に基づいてポイントを計算
        int recentFavoriteCount = 0;
        for (var favoriteDoc in favoriteUsersSnapshot.docs) {
          final addedAt = favoriteDoc['added_at'] as Timestamp;
          final points = _calculateFavoritePoints(addedAt);
          recentFavoriteCount += points;
        }

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

      // お気に入りのポイントで降順に並べ替え
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

  int _calculateFavoritePoints(Timestamp favoriteTimestamp) {
    final now = DateTime.now();
    final favoriteDate = favoriteTimestamp.toDate();
    final difference = now.difference(favoriteDate).inHours;

    if (difference <= 24) {
      return 3;
    } else if (difference <= 48) {
      return 2;
    } else if (difference <= 72) {
      return 1;
    } else {
      return 0;
    }
  }

  // 画像の検索条件
  Future<void> searchImagePosts(
    String query,
    String? userId,
    String? selectedCategory,
    Function(List<DocumentSnapshot>) updateResults, {
    String? searchUserId,
    bool? isExactMatch,
    bool? isFollowing,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        (userId == null || userId.isEmpty) &&
        isFollowing == null &&
        startDate == null &&
        endDate == null) {
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

    // ユーザーIDでフィルタリング
    if (searchUserId != null && searchUserId.isNotEmpty) {
      // まずは全てのドキュメントを取得
      final allDocumentsSnapshot = await queryRef.get();

      // フィルタリングをクライアント側で行う
      final filteredDocuments = allDocumentsSnapshot.docs.where((doc) {
        final postUserId = doc['post_user_id'] as String;
        if (isExactMatch == true) {
          // 完全一致検索
          return postUserId == searchUserId;
        } else {
          // 部分一致検索
          return postUserId.contains(searchUserId);
        }
      }).toList();

      // クエリ結果を更新
      queryRef = queryRef.where(FieldPath.documentId,
          whereIn: filteredDocuments.map((doc) => doc.id).toList());
    }

    // フォローしているかどうかでフィルタリング
    if (isFollowing == true && userId != null) {
      // フォローしているユーザーのリストを取得
      final followSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('follow')
          .get();

      final followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

      // フォローしているユーザーの投稿のみをフィルタリング
      queryRef = queryRef.where('post_user_id', whereIn: followUserIds);
    }

    // 日付範囲でフィルタリング
    if (startDate != null) {
      queryRef =
          queryRef.where('created_time', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      queryRef = queryRef.where('created_time', isLessThanOrEqualTo: endOfDay);
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
