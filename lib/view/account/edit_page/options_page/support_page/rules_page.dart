import 'package:flutter/material.dart';

class RulesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('cymva city使い方'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Container(
        color: Colors.grey[100], // 背景色を薄いグレーに設定
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 大見出し
                _buildLargeHeading('Cymva city規則'),
                SizedBox(height: 16),

                // 中見出し
                _buildMediumHeading('1. 人間の画像、動画の投稿の禁止'),
                SizedBox(height: 8),

                // 本文
                _buildBodyText(
                  'Cymvaでは人が写っている画像や動画の投稿を禁じております。\n'
                  'ただし、アニメーションやイラストなどの二次元キャラクターは許可されています。\n'
                  'また、画像や動画の主として扱われているものが人間以外であり、背景に偶発的に映るこんだものは制限の対象外とします。\n'
                  'その他、わからないことがあれば、サポートまでお問い合わせください。',
                ),
                SizedBox(height: 35),

                _buildLargeHeading('Cymva 使い方'),
                SizedBox(height: 16),

                _buildMediumHeading('1. 投稿ページ'),
                SizedBox(height: 8),

                // 小見出し
                _buildSmallHeading('・投稿ページ'),
                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  '投稿ページは、ナビゲーションバーの最も右側のアイコンをタップすることでアクセスできます。',
                ),
                SizedBox(height: 16),

                // 小見出し
                _buildSmallHeading('・カテゴリー'),
                SizedBox(height: 4),
                // 本文
                _buildBodyText(
                  'カテゴリーは全てで9種あり、そのうちの漫画、イラスト、写真、俳句・短歌、憲章宣誓にて表示が変わります。\n'
                  '漫画 ー 画像の選択が最大50枚まで可能になります。また、漫画用の表示となります。\n'
                  'イラスト、写真 ー カテゴリーを選択、画像の枚数が1枚、テキストがなしという条件下において、表示が変わります。\n'
                  '俳句・短歌 ー 縦書きになります。文字数の最大は40文字になります。\n'
                  '憲章宣誓 ー 憲章宣誓ができます。',
                ),
                SizedBox(height: 16),

                // 小見出し
                _buildSmallHeading('・クリアボタン'),

                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  'クリアボタンはカテゴリーを選択した際にカテゴリーをクリアするためのボタンです。',
                ),
                SizedBox(height: 16),

                // 小見出し
                _buildSmallHeading('・保存ボタン'),

                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  '通常フォーム内のテキストは他のページへの遷移で消えてしまいますが、保存ボタンを押すことで、他のページへの遷移後もテキストが残ります。\n',
                ),
                SizedBox(height: 16),

                _buildMediumHeading('2. 検索ページ'),
                SizedBox(height: 8),

                // 小見出し
                _buildSmallHeading('・検索ページ'),
                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  '検索ページは、左から2番目の虫眼鏡アイコンをタップすることでアクセスできます。\n',
                ),
                SizedBox(height: 8),

                // 本文
                _buildBodyText(
                  '一般的な検索はテキストフィールドとテキストフィールド右側のアイコンをタップすることでカテゴリーで絞り込むことができます。\n'
                  'また、カテゴリー選択の右側のアイコンをタップすることで、詳細な検索ができます。\n',
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 大見出し
  Widget _buildLargeHeading(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  // 中見出し
  Widget _buildMediumHeading(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey[800],
          ),
        ),
        SizedBox(height: 4), // 見出しとアンダーバーの間にスペースを追加
        Container(
          width: double.infinity,
          height: 2,
          color: Colors.blueGrey[200], // アンダーバーの色
        ),
      ],
    );
  }

  // 小見出し
  Widget _buildSmallHeading(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.blueGrey[600],
      ),
    );
  }

  // 本文
  Widget _buildBodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0), // 左側に空白を追加
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5, // 行間を調整
        ),
      ),
    );
  }
}
