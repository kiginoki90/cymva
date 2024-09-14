import 'package:flutter/material.dart';

class SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onQueryChanged;
  final PageController pageController;
  final int currentPage;

  const SearchTextField({
    Key? key,
    required this.controller,
    required this.onQueryChanged,
    required this.pageController,
    required this.currentPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: '検索...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10), // テキストフィールドとナビゲーションの間にスペースを追加
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('コンテンツ'),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 2,
                      width: 60,
                      color:
                          currentPage == 0 ? Colors.blue : Colors.transparent,
                    ),
                  ],
                ),
                onPressed: () {
                  pageController.jumpToPage(0);
                },
              ),
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ユーザー'),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 2,
                      width: 60,
                      color:
                          currentPage == 1 ? Colors.blue : Colors.transparent,
                    ),
                  ],
                ),
                onPressed: () {
                  pageController.jumpToPage(1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
