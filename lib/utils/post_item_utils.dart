import 'package:flutter/material.dart';

// buildVerticalText 関数を独立させる
Widget buildVerticalText(String content) {
  List<String> lines = content.split('\n');

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: lines
        .map((line) {
          List<String> characters = line.split('');

          // 各文字を縦に配置
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: characters.map((char) {
                return char == 'ー' || char == 'ｰ' // 全角「ー」または半角「ｰ」の場合のみ回転を適用
                    ? Transform.rotate(
                        angle: 90 * 3.1415926535897932 / 180, // 90度をラジアンに変換
                        child: Text(
                          char,
                          style: const TextStyle(fontSize: 15, height: 1.1),
                        ),
                      )
                    : Text(
                        char,
                        style: const TextStyle(fontSize: 15, height: 1.1),
                      );
              }).toList(),
            ),
          );
        })
        .toList()
        .reversed
        .toList(), // 右から左に表示するため逆順に
  );
}
