import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('プライバシーポリシー'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('プライバシーポリシー'),
            _buildSectionContent('''
本プライバシーポリシー（以下、「本ポリシー」といいます。）は、cymva（以下、「本サービス」といいます。）を運営する本サービス提供者（以下、「当方」といいます。）が、ユーザーの個人情報をどのように収集、利用、管理するかを定めたものです。
          '''),
            _buildSectionTitle('第1条（収集する個人情報）'),
            _buildSectionContent('''
当方が収集する個人情報は以下のとおりです：
- メールアドレス（アカウント作成時にご提供いただきます。）
- 広告配信に関連する匿名情報（後述の「広告の配信について」に詳細を記載）
            '''),
            _buildSectionTitle('第2条（個人情報の利用目的）'),
            _buildSectionContent('''
当方は、取得した個人情報を以下の目的で利用します：
- 本サービスの提供、運営、改善のため
- ユーザーからのお問い合わせへの対応のため
- 本サービスに関する重要な通知（変更、アップデート等）のため
- 広告配信や効果測定のため（匿名情報のみ）
            '''),
            _buildSectionTitle('第3条（個人情報の管理）'),
            _buildSectionContent('''
当方は、ユーザーの個人情報を適切に管理し、不正アクセス、紛失、破損、改ざん、漏洩などを防止するために、以下の措置を講じます：
- SSL（Secure Socket Layer）による通信の暗号化
- 個人情報へのアクセス制限
            '''),
            _buildSectionTitle('第4条（第三者への提供）'),
            _buildSectionContent('''
当方は、個人データについてあらかじめ利用者の同意を得ることなく、第三者に提供いたしません。ただし、次に掲げる場合はその限りではありません：
　（1）法令に基づき開示が必要な場合
　（2）合併、売却などの事由による承継が生じた場合
　（3）広告事業者が匿名情報を収集する場合（詳細は第6条を参照）
　（4）その他個人情報保護法その他の法令で認められる場合 
            '''),
            _buildSectionTitle('第5条（個人情報の開示、訂正、削除）'),
            _buildSectionContent('''
ユーザーは、当方に対し、以下の権利を行使できます：
- 自身の個人情報の開示を請求する権利
- 訂正、更新、削除を要求する権利
これらの要求については、[お問い合わせ方法を記載]にて受付いたします。
            '''),
            _buildSectionTitle('第6条（広告の配信について）'),
            _buildSectionContent('''
広告配信のための情報収集
本サービスでは、第三者による広告配信サービスを利用しています。これらの広告配信事業者（以下、「広告事業者」といいます。）は、ユーザーの興味や関心に基づいた広告を表示するために、クッキー、広告ID（例：Google広告ID、AppleのIdentifier for Advertisers）などを使用して、匿名の情報を自動的に収集する場合があります。

広告事業者が収集する情報
広告事業者は、次のような情報を収集することがあります：
- デバイス情報（端末の種類、OS、広告IDなど）
- アプリの利用状況（広告表示履歴、クリック履歴、利用時間など）

情報の利用目的
広告事業者は、収集した情報を以下の目的で利用します：
- ユーザーの興味や関心に基づく広告の配信
- 広告効果の測定および最適化

広告事業者のプライバシーポリシーについて
本サービスで使用する広告事業者のプライバシーポリシーについては、以下をご参照ください：
- Google AdMob: https://policies.google.com/privacy

クッキーや広告IDの管理について
ユーザーは、デバイス設定を変更することで、クッキーや広告IDの利用を制限または無効化することができます。ただし、その場合、一部の機能が利用できなくなる可能性があります。
            '''),
            _buildSectionTitle('第7条（ポリシーの変更）'),
            _buildSectionContent('''
当方は、利用者情報の取り扱いについて適宜見直し継続的な改善を努めるものとし、必要に応じて改定される場合があります。重要な変更がある場合は、本サービス上で通知いたします。改定後のポリシーは、本サービスに掲載した時点から効力を生じます。なお、法令上利用者の同意が必要とされるような内容の変更の場合は、改定後のポリシーをご確認いただいた上で、利用者の同意を得るものとします。
            '''),
            _buildSectionTitle('第8条（お問い合わせ）'),
            _buildSectionContent('''
本ポリシーに関するご質問やお問い合わせは、以下の連絡先までご連絡ください：
- メールアドレス：info@cymva.jp
            '''),
            SizedBox(height: 30),
            Text(
              '【2024年12月7日制定】',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(color: Colors.black),
      ],
    );
  }

  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: TextStyle(fontSize: 13),
    );
  }
}
