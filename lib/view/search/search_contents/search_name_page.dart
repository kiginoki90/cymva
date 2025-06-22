import 'package:flutter/material.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/view/account/account_page.dart';

class SearchByAccountNamePage extends StatefulWidget {
  final List<Account> accountSearchResults;

  const SearchByAccountNamePage({
    Key? key,
    required this.accountSearchResults,
  }) : super(key: key);

  @override
  _SearchByAccountNamePageState createState() =>
      _SearchByAccountNamePageState();
}

class _SearchByAccountNamePageState extends State<SearchByAccountNamePage>
    with AutomaticKeepAliveClientMixin {
  int _displayLimit = 15; // 表示する件数の上限
  bool _isLoadingMore = false; // ローディング状態を管理
  bool _isLoading = true; // 初期ローディング状態を管理

  @override
  bool get wantKeepAlive => true; // 状態を保持する

  Future<void> _loadMoreAccounts() async {
    if (_displayLimit < widget.accountSearchResults.length) {
      setState(() {
        _isLoadingMore = true;
        _displayLimit += 15; // 表示件数を増やす
      });

      await Future.delayed(const Duration(milliseconds: 500)); // ローディングのための遅延

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 初期ローディングをシミュレーション
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false; // ローディング完了
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin を使用する場合に必要

    if (_isLoading) {
      return const Center(child: Text('読み込み中...'));
    }

    if (widget.accountSearchResults.isEmpty) {
      return const Center(child: Text('検索結果がありません'));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels ==
                    scrollInfo.metrics.maxScrollExtent &&
                !_isLoadingMore &&
                _displayLimit < widget.accountSearchResults.length) {
              _loadMoreAccounts(); // 一番下までスクロールしたら次のアカウントを表示
            }
            return true;
          },
          child: ListView.builder(
            itemCount: _displayLimit + (_displayLimit ~/ 5) + 1,
            itemBuilder: (context, index) {
              if (index == _displayLimit + (_displayLimit ~/ 5)) {
                return const Center(child: Text("結果は以上です"));
              }

              if (index >= _displayLimit ||
                  index >= widget.accountSearchResults.length) {
                return Container();
              }

              final account = widget.accountSearchResults[index];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountPage(
                              postUserId: account.id,
                              withDelay: false,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          account.imagePath ??
                              'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountPage(
                                postUserId: account.id,
                                withDelay: false,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    account.name.length > 25
                                        ? '${account.name.substring(0, 25)}...'
                                        : account.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '@${account.userId.length > 25 ? '${account.userId.substring(0, 25)}...' : account.userId}',
                                    style: const TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account.selfIntroduction,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
