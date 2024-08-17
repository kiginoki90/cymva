import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // UserProfilePageの実装
    return Scaffold(
      appBar: AppBar(title: Text('ユーザープロフィール')),
      body: Center(child: Text('ユーザーID: $userId')),
    );
  }
}
