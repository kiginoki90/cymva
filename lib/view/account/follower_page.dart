import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/user_profile_page.dart';

class FollowerPage extends StatelessWidget {
  final String userId;

  const FollowerPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('フォロワー')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー'));
          }
          final followerDocs = snapshot.data?.docs ?? [];

          return ListView(
            children: followerDocs.map((followerDoc) {
              final followerId = followerDoc.id;

              // フォロワーのユーザーデータを取得
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (userSnapshot.hasError) {
                    return Center(child: Text('エラー'));
                  }

                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  // userDataがnullまたは空の場合はスキップ
                  if (userData == null || userData.isEmpty) {
                    return SizedBox.shrink(); // 空のウィジェットを返す
                  }

                  print('Follower data: $userData'); // フォロワーデータをコンソールに出力

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(userData['image_path']),
                    ),
                    title: Text(userData['name']),
                    subtitle: Text('@${userData['user_id']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfilePage(userId: followerId),
                        ),
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
