import 'package:flutter/material.dart';

// buildVerticalText 関数を独立させる
Widget buildVerticalText(String content) {
  List<String> lines = content.split('\n');

  return Row(
    mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
    crossAxisAlignment: CrossAxisAlignment.start, // 上寄せ
    children: lines
        .map((line) {
          List<String> characters = line.split('');

          // 各文字を縦に配置
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // 行の間隔を広げる
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: characters.map((char) {
                return Text(
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
