import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFirestore {
  static final _firestoreInstance = FirebaseFirestore.instance;
  static final CollectionReference users =
      _firestoreInstance.collection('users');
  static final _userCollection = FirebaseFirestore.instance.collection('users');
  static final CollectionReference _users =
      _firestoreInstance.collection('users');

  // UID でアカウントを取得する
  static Future<Account?> getAccountByUID(String uid) async {
    var doc = await users.doc(uid).get();
    if (doc.exists) {
      return Account.fromDocument(doc);
    }
    return null;
  }

  // 現在のユーザーのメールアドレスから対応する UID を取得し、それに基づいてアカウントを取得する
  static Future<Account?> getAccountByCurrentUserEmail() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // UIDを使ってFirestoreからアカウントを取得
      return await getAccountByUID(currentUser.uid);
    } else {
      return null;
    }
  }

  // 新しいユーザーをFirestoreに作成
  static Future<void> createUser(Account account) async {
    await _userCollection.doc(account.id).set(account.toMap());
  }

  static Future<dynamic> setUser(Account newAccount) async {
    try {
      await users.doc(newAccount.id).set({
        'admin': 3,
        'parents_id': newAccount.id,
        'name': newAccount.name,
        'user_id': newAccount.userId,
        'self_introduction': newAccount.selfIntroduction,
        'image_path': newAccount.imagePath,
        'created_time': Timestamp.now(),
        'updated_time': Timestamp.now(),
        'passwordChangeToken': Timestamp.now(),
        'lock_account': false,
      });

      // await users
      //     .doc(newAccount.id)
      //     .collection('favorite_posts')
      //     .doc('initial')
      //     .set({});
      // await users
      //     .doc(newAccount.id)
      //     .collection('my_posts')
      //     .doc('initial')
      //     .set({});
      // await users
      //     .doc(newAccount.id)
      //     .collection('follow')
      //     .doc('initial')
      //     .set({});
      // await users
      //     .doc(newAccount.id)
      //     .collection('followers')
      //     .doc('initial')
      //     .set({});

      print('ユーザー作成が完了しました');
      return true;
    } on FirebaseException catch (e) {
      print('ユーザー作成エラー: $e');
      return false;
    }
  }

//データベースから情報を取得、それをAccountのインスタンスに変換するためのメソッド
  static Future<Account?> getUser(String uid) async {
    try {
      DocumentSnapshot documentSnapshot = await users.doc(uid).get();
      if (documentSnapshot.exists) {
        Map<String, dynamic> data =
            documentSnapshot.data() as Map<String, dynamic>;
        Account myAccount = Account(
          admin: data['admin'] ?? 3,
          id: uid,
          parents_id: data['parents_id'] ?? '',
          name: data['name'] ?? '',
          userId: data['user_id'] ?? '',
          selfIntroduction: data['self_introduction'] ?? '',
          imagePath: data['image_path'] ?? '',
          createdTime: data['created_time'] as Timestamp?,
          updatedTime: data['updated_time'] as Timestamp?,
          lockAccount: data['lock_account'] ?? '',
        );
        // 作成したオブジェクトをmyAccountに保存
        Authentication.myAccount = myAccount;
        print('ユーザー取得完了');
        return myAccount;
      } else {
        print('ユーザーが存在しません');
        return null;
      }
    } on FirebaseException catch (e) {
      print('user_error: $e');
      return null;
    }
  }

  static Future<dynamic> updataUser(Account updateAccount) async {
    try {
      await users.doc(updateAccount.id).update({
        'name': updateAccount.name,
        'image_path': updateAccount.imagePath,
        'self_introduction': updateAccount.selfIntroduction,
        'updated_time': Timestamp.now(),
        'lock_account': updateAccount.lockAccount,
      });
      print('ユーザー情報の更新完了');
      return true;
    } on FirebaseException catch (e) {
      print('ユーザー情報の更新エラー: $e');
      return false;
    }
  }

  static Future<Map<String, Account>?> getPostUserMap(
      List<String> accountIds) async {
    Map<String, Account> map = {};
    try {
      await Future.forEach(accountIds, (String accountId) async {
        var doc = await users.doc(accountId).get();
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Account postAccount = Account(
          id: accountId,
          name: data['name'],
          userId: data['user_id'],
          imagePath: data['image_path'],
          selfIntroduction: data['self_introduction'],
          createdTime: data['creaated_time'],
          updatedTime: data['uodated_time'],
          lockAccount: data['lock_account'],
          parents_id: data['parents_id'],
        );
        map[accountId] = postAccount;
      });
      print('投稿ユーザーの情報取得完了');
      return map;
    } on FirebaseException catch (e) {
      print('投稿ユーザーの情報取得エラー: $e');
      return null;
    }
  }

  static Future<dynamic> deleteUser(String accountId) async {
    users.doc(accountId).delete();
    PostFirestore.deletePosts(accountId);
  }

  // parents_idに基づいてアカウントの件数を取得するメソッド
  static Future<int> getAccountCountByParentsId(String parentsId) async {
    try {
      // Firestoreの 'users' コレクションから、parents_idが一致するアカウントを取得
      QuerySnapshot querySnapshot =
          await users.where('parents_id', isEqualTo: parentsId).get();

      // 一致したドキュメントの数を返す
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting account count by parents_id: $e');
      return 0; // エラーが発生した場合は0を返す
    }
  }

  static Future<Account?> getUserByUserId(String userId) async {
    var snapshot =
        await _userCollection.where('user_id', isEqualTo: userId).get();
    if (snapshot.docs.isNotEmpty) {
      return Account.fromDocument(snapshot.docs.first);
    } else {
      return null;
    }
  }

  // 自動IDを利用して新しいアカウントをFirestoreに追加
  static Future<bool> addAdditionalAccountWithAutoId(Account account) async {
    try {
      // Firestoreが自動的に生成するIDを使用
      var docRef = await _userCollection.add(account.toMap());
      account.id = docRef.id; // 生成されたIDをaccountオブジェクトに反映
      return true;
    } catch (e) {
      print('アカウントの追加に失敗しました: $e');
      return false;
    }
  }

  // 複数のUIDから対応するユーザー情報を取得
  static Future<Map<String, Account>> getUsersByIds(List<String> ids) async {
    Map<String, Account> accounts = {};
    try {
      // 各UIDに対応するドキュメントを順次取得
      for (String id in ids) {
        DocumentSnapshot doc = await users.doc(id).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          Account account = Account(
            admin: data['admin'] ?? 3,
            id: id,
            name: data['name'] ?? '',
            userId: data['user_id'] ?? '',
            imagePath: data['image_path'] ?? '',
            selfIntroduction: data['self_introduction'] ?? '',
            createdTime: data['created_time'] as Timestamp?,
            updatedTime: data['updated_time'] as Timestamp?,
            lockAccount: data['lock_account'] ?? '',
          );
          accounts[id] = account; // IDをキーとしてマップに追加
        }
      }
      return accounts;
    } catch (e) {
      print('Error getting users by IDs: $e');
      return {}; // エラー時は空のマップを返す
    }
  }

  static Future<void> updateLockAccount(String userId, bool isPrivate) async {
    try {
      await _users.doc(userId).update({
        'lock_account': isPrivate, // lock_account フィールドを更新
      });
      print('lock_account updated successfully');
    } catch (e) {
      print('Error updating lock_account: $e');
    }
  }
}
