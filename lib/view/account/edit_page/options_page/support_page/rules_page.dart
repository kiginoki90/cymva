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
                  '\n'
                  '漫画\n'
                  '　画像の選択が最大50枚まで可能になります。また、漫画用の表示となります。\n'
                  '\n'
                  'イラスト、写真\n'
                  '　カテゴリーを選択、画像の枚数が1枚、テキストがなしという条件下において、表示が変わります。\n'
                  '\n'
                  '俳句・短歌 \n'
                  '　縦書きになります。文字数の最大は40文字になります。\n'
                  '\n'
                  '音楽\n'
                  '　mp3,wav,m4a形式ファイルの投稿が可能になります。画像は1枚まで選択可能です。\n'
                  '\n'
                  '憲章宣誓\n'
                  '　憲章宣誓ができます。',
                ),
                SizedBox(height: 32),

                // 小見出し
                _buildSmallHeading('・保存ボタン'),

                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  '通常フォーム内のテキストは他のページへの遷移で消えてしまいますが、保存ボタンを押すことで、他のページへの遷移後もテキストが残ります。\n',
                ),
                SizedBox(height: 16),

                _buildMediumHeading('2. 投稿の詳細'),
                SizedBox(height: 8),

                // 小見出し
                _buildSmallHeading('・各投稿について'),
                SizedBox(height: 4),

                // 本文
                _buildBodyText(
                  '各投稿には、スター、引用、返信、栞の4つのナビゲーションがついています。\n'
                  '\n'
                  '・スター \n'
                  '　投稿をお気に入りとしてマークする機能です。スターをつけることで、投稿者に支持を示すことができます。\n'
                  '\n'
                  '・引用 \n'
                  '　投稿を引用して新しい投稿を作成する機能です。引用元の投稿を参照しながら、自分の意見や関連情報を追加できます。\n'
                  '\n'
                  '・返信 \n'
                  '　投稿に対してコメントや意見を直接返信する機能です。返信を通じて投稿者とコミュニケーションを取ることができます。\n'
                  '\n'
                  '・栞\n'
                  '　投稿をブックマークとして保存する機能です。後で簡単に見返すことができるようになります。栞挟んだ投稿は、誰にも知られることはありません。\n',
                ),
                SizedBox(height: 16),

                // 小見出し
                _buildSmallHeading('・投稿の報告'),
                SizedBox(height: 4),

                _buildBodyText(
                  '自分以外の投稿には、右上に投稿の報告ボタンがあります。不適切な投稿を発見した場合、このボタンをタップして報告フォームを送信することで、運営に通知することができます。\n'
                  '\n'
                  '報告フォームでは、問題の内容を具体的に記載することが推奨されます。これにより、運営が迅速かつ適切に対応することが可能になります。\n'
                  '\n'
                  '報告された投稿は運営によって確認され、必要に応じて削除や警告などの対応が行われます。不適切な投稿を見つけた際は、ぜひ報告機能をご利用ください。\n',
                ),
                SizedBox(height: 16),

                // 小見出し
                _buildSmallHeading('・投稿の機能'),
                SizedBox(height: 4),

                _buildBodyText(
                  '自分の投稿には、右上に各機能のボタンがあり、タップすることで下記の機能が使えるようになります。\n'
                  '\n'
                  '・削除ボタン\n'
                  '　投稿を削除することができます。この処理は取り消すことができません。\n'
                  '\n'
                  '・トップに固定/固定を解除\n'
                  '　自身のアカウントページのタイムラインの一番上に、指定した投稿を固定することができます。固定を行う投稿は複数指定でき、処理を行った順番が新しい順番に上から表示されます。\n'
                  '\n'
                  '・スターを見る\n'
                  '　投稿に付けられたスターをつけてくれたユーザーを確認することができます。\n'
                  '\n'
                  '・コメントを閉じる/開く\n'
                  '　投稿に返信が可能かどうかを選択できます。コメントを閉じた場合、自分以外の今まであった返信も投稿下には表示されません。\n'
                  '\n'
                  'グループを作る\n'
                  '　当該の投稿を含んだ新規のグループを作成することができます。\n'
                  '\n'
                  '既存のグループに入れる\n'
                  '　上記の処理で作成を行ったグループに当該の投稿を追加できます。\n',
                ),
                SizedBox(height: 16),

                _buildMediumHeading('3. 検索ページ'),
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

                _buildMediumHeading('4. 設定'),
                SizedBox(height: 8),

                // 本文
                _buildBodyText(
                  '設定ページは自身のアカウントページ右上の歯車アイコンをタップすることで遷移できます。\n',
                ),
                SizedBox(height: 8),

                // 本文
                _buildBodyText(
                  '・設定編集ページ\n'
                  '　設定編集ページでは、アカウント名やアイコンなど、基本的な設定の編集を行うことができます。\n',
                ),
                SizedBox(height: 8),

                _buildBodyText(
                  '・アカウント非公開\n'
                  '　自分の投稿を他のアカウントから見られないようになります。ただし、他のアカウントへの返信、引用、メンションなどを行うと、その投稿に限り他のアカウントからも見ることができる状態になります。\n',
                ),
                SizedBox(height: 8),
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
