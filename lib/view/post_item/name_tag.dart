import 'package:cymva/model/account.dart';
import 'package:flutter/material.dart';

class NameTag extends StatelessWidget {
  final Account postAccount;

  const NameTag({
    Key? key,
    required this.postAccount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (postAccount.lockAccount) // ロックアイコンの表示
              const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(
                  Icons.lock, // 南京錠のアイコン
                  size: 16, // アイコンのサイズ
                  color: Colors.grey, // アイコンの色
                ),
              ),
            Text(
              postAccount.name.length > 25
                  ? '${postAccount.name.substring(0, 25)}...' // 名前を25文字で切り取って表示
                  : postAccount.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis, // 名前が長い場合は省略
              maxLines: 1,
            ),
          ],
        ),
        Text(
          '@${postAccount.userId.length > 25 ? '${postAccount.userId.substring(0, 25)}...' : postAccount.userId}', // userIdを25文字で切り取る
          style: const TextStyle(color: Colors.grey),
          overflow: TextOverflow.ellipsis, // 長い場合は省略
          maxLines: 1,
        ),
      ],
    );
  }
}
