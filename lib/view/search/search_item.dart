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
    bool? star,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if ((query.isEmpty) &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        isFollowing != true &&
        star != true &&
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

    List<String> filteredDocumentIds = [];

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

      // フィルタリングされたドキュメントのIDをリストに追加
      filteredDocumentIds.addAll(filteredDocuments.map((doc) => doc.id));
    }

    List<String> followUserIds = [];
    List<String> favoritePostIds = [];

    // フォローしているかどうかでフィルタリング
    if (isFollowing == true && userId != null) {
      // フォローしているユーザーのリストを取得
      final followSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('follow')
          .get();

      followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

      if (followUserIds.isEmpty) {
        updateResults([]);
        return;
      }
    }

    // お気に入りユーザーのフィルタリング
    if (star == true && userId != null) {
      // お気に入りユーザーの投稿を取得
      final favoriteSnapshot = await FirebaseFirestore.instance
          .collectionGroup('favorite_users')
          .where('user_id', isEqualTo: userId)
          .orderBy('added_at', descending: true)
          .get();

      favoritePostIds = favoriteSnapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();

      if (favoritePostIds.isEmpty) {
        updateResults([]);
        return;
      }
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
    final filteredPosts = querySnapshot.docs.where((doc) {
      final content = (doc['content'] as String).toLowerCase(); // コンテンツを小文字に変換
      return queryWords.every((word) => content.contains(word));
    }).toList();

    // フォローしているユーザーとお気に入りユーザーのフィルタリングを適用
    List<DocumentSnapshot> finalFilteredPosts = filteredPosts;
    if (followUserIds.isNotEmpty && favoritePostIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) =>
              followUserIds.contains(doc['post_account_id']) &&
              favoritePostIds.contains(doc.id))
          .toList();
    } else if (followUserIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) => followUserIds.contains(doc['post_account_id']))
          .toList();
    } else if (favoritePostIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) => favoritePostIds.contains(doc.id))
          .toList();
    }

    // ユーザーIDでフィルタリングされたドキュメントのIDを適用
    if (filteredDocumentIds.isNotEmpty) {
      finalFilteredPosts = finalFilteredPosts
          .where((doc) => filteredDocumentIds.contains(doc.id))
          .toList();
    }

    return updateResults(finalFilteredPosts);
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

    // Firestoreからすべてのユーザーを取得
    final allUsersSnapshot = await firestore.collection('users').get();

    // クライアント側でフィルタリング
    for (var doc in allUsersSnapshot.docs) {
      if (doc.data().containsKey('name') && doc.data().containsKey('user_id')) {
        final name = (doc['name'] as String).toLowerCase();
        final userId = (doc['user_id'] as String).toLowerCase();

        // 名前またはユーザーIDがクエリのいずれかの単語を含む場合
        if (queryWords
            .any((word) => name.contains(word) || userId.contains(word))) {
          if (uniqueAccountIds.add(doc.id)) {
            allDocs.add(doc);
          }
        }
      }
    }

    // 結果をすべて返す
    updateResults(allDocs.map((doc) {
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
    bool? star,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        isFollowing != true &&
        star == null &&
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

      List<String> filteredDocumentIds = [];

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

        // フィルタリングされたドキュメントのIDをリストに追加
        filteredDocumentIds.addAll(filteredDocuments.map((doc) => doc.id));
      }

      List<String> followUserIds = [];
      List<String> favoritePostIds = [];

      // フォローしているかどうかでフィルタリング
      if (isFollowing == true && userId != null) {
        // フォローしているユーザーのリストを取得
        final followSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('follow')
            .get();

        followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

        if (followUserIds.isEmpty) {
          updateResults([]);
          return;
        }
      }

      // お気に入りユーザーのフィルタリング
      if (star == true && userId != null) {
        // お気に入りユーザーの投稿を取得
        final favoriteSnapshot = await FirebaseFirestore.instance
            .collectionGroup('favorite_users')
            .where('user_id', isEqualTo: userId)
            .orderBy('added_at', descending: true)
            .get();

        favoritePostIds = favoriteSnapshot.docs
            .map((doc) => doc.reference.parent.parent!.id)
            .toList();

        if (favoritePostIds.isEmpty) {
          updateResults([]);
          return;
        }
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

      // フォローしているユーザーとお気に入りユーザーのフィルタリングを適用
      List<DocumentSnapshot> finalFilteredPosts = limitedResults;
      if (followUserIds.isNotEmpty && favoritePostIds.isNotEmpty) {
        finalFilteredPosts = limitedResults
            .where((doc) =>
                followUserIds.contains(doc['post_account_id']) &&
                favoritePostIds.contains(doc.id))
            .toList();
      } else if (followUserIds.isNotEmpty) {
        finalFilteredPosts = limitedResults
            .where((doc) => followUserIds.contains(doc['post_account_id']))
            .toList();
      } else if (favoritePostIds.isNotEmpty) {
        finalFilteredPosts = limitedResults
            .where((doc) => favoritePostIds.contains(doc.id))
            .toList();
      }

      // ユーザーIDでフィルタリングされたドキュメントのIDを適用
      if (filteredDocumentIds.isNotEmpty) {
        finalFilteredPosts = finalFilteredPosts
            .where((doc) => filteredDocumentIds.contains(doc.id))
            .toList();
      }

      updateResults(finalFilteredPosts);
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
    bool? star,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (query.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty) &&
        (searchUserId == null || searchUserId.isEmpty) &&
        isFollowing != true &&
        star != true &&
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

    List<String> filteredDocumentIds = [];

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

      // フィルタリングされたドキュメントのIDをリストに追加
      filteredDocumentIds.addAll(filteredDocuments.map((doc) => doc.id));
    }

    List<String> followUserIds = [];
    List<String> favoritePostIds = [];

    // フォローしているかどうかでフィルタリング
    if (isFollowing == true && userId != null) {
      // フォローしているユーザーのリストを取得
      final followSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('follow')
          .get();

      followUserIds = followSnapshot.docs.map((doc) => doc.id).toList();

      if (followUserIds.isEmpty) {
        updateResults([]);
        return;
      }
    }

    // お気に入りユーザーのフィルタリング
    if (star == true && userId != null) {
      // お気に入りユーザーの投稿を取得
      final favoriteSnapshot = await FirebaseFirestore.instance
          .collectionGroup('favorite_users')
          .where('user_id', isEqualTo: userId)
          .orderBy('added_at', descending: true)
          .get();

      favoritePostIds = favoriteSnapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();

      if (favoritePostIds.isEmpty) {
        updateResults([]);
        return;
      }
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

    // フォローしているユーザーとお気に入りユーザーのフィルタリングを適用
    List<DocumentSnapshot> finalFilteredPosts = filteredPosts;
    if (followUserIds.isNotEmpty && favoritePostIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) =>
              followUserIds.contains(doc['post_account_id']) &&
              favoritePostIds.contains(doc.id))
          .toList();
    } else if (followUserIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) => followUserIds.contains(doc['post_account_id']))
          .toList();
    } else if (favoritePostIds.isNotEmpty) {
      finalFilteredPosts = filteredPosts
          .where((doc) => favoritePostIds.contains(doc.id))
          .toList();
    }

    // ユーザーIDでフィルタリングされたドキュメントのIDを適用
    if (filteredDocumentIds.isNotEmpty) {
      finalFilteredPosts = finalFilteredPosts
          .where((doc) => filteredDocumentIds.contains(doc.id))
          .toList();
    }

    updateResults(finalFilteredPosts);
  }
}
