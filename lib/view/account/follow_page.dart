import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/account/user_profile_page.dart';

class FollowPage extends StatelessWidget {
  final String userId;

  const FollowPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('フォローしている人')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('follow')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー'));
          }
          final followDocs = snapshot.data?.docs ?? [];

          return ListView(
            children: followDocs.map((followDoc) {
              final followId = followDoc.id;

              // フォローしているユーザーデータを取得
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followId)
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
                              UserProfilePage(userId: followId),
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
