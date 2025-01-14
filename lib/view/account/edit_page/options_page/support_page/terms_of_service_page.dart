import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('利用規約'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('第1条（適用）'),
            _buildSectionContent([
              '1.　',
              '本規約は，ユーザーと本サービス提供者（以下、「当方」といいます）との間のcymva(以下、本サービスといいます）の利用に関する一切の関係に適用されます。当方は本サービスに関連して，ご利用ルール等の個別規定を定める場合があります。これらの個別規定は，本規約の一部を構成するものとします。本規約と個別規定が矛盾する場合には，個別規定が優先されるものとします。',
            ]),
            _buildSectionContent([
              '2.　',
              'ユーザーは、本アプリをダウンロードし、サービスを利用することにより、本規約に同意したものとみなされます。',
            ]),
            _buildSectionContent([
              '3.　',
              '本利用規約は、以下の各号に該当する場合、当方の判断によりいつでも任意の理由で変更することができるものとします。',
            ]),
            _buildSectionContent([
              '　（1）',
              '法令やサービスの変更により、本規約の変更が必要となった場合',
            ]),
            _buildSectionContent([
              '　（2）',
              '本利用規約の変更が、ユーザーの一般の利益に適合する場合、またはユーザーの不利益を防ぐために必要である場合。',
            ]),
            _buildSectionContent([
              '　（3）',
              '本利用規約の変更が、本サービスの利用目的に反せず、かつ変更の必要性、変更内容の相当性、変更の内容その他変更に関わる事情に照らして合理的なものである場合。',
            ]),
            _buildSectionContent([
              '4.　',
              '前項各号のいずれにも該当しない本規約の重要な変更については変更後の利用規約の1ヶ月前までに。本規約を変更する旨及び変更後の利用規約の内容とその効力発生日を本アプリ上に表示するものとします。本規約が変更された後、ユーザーが本サービスの利用を継続した場合、ユーザーは本規約の変更に同意したものとみなされます。',
            ]),
            _buildSectionTitle('第2条（利用登録）'),
            _buildSectionContent([
              '1.　',
              '本サービスの利用には，当方が定める方法により利用登録を行い，アカウントを発行します。',
            ]),
            _buildSectionContent([
              '2.　',
              '当方は，以下の場合には利用登録を拒否することがあります。その理由の開示義務は負いません。',
            ]),
            _buildSectionContent([
              '　（1）',
              '本規約に違反するおそれがあると当方が判断した場合',
            ]),
            _buildSectionContent([
              '　（2）',
              '過去に規約違反がある場合',
            ]),
            _buildSectionContent([
              '　（3）',
              'その他，当方が適当でないと判断した場合',
            ]),
            _buildSectionTitle('第3条（アカウントの管理）'),
            _buildSectionContent([
              '1.　',
              'ユーザーは，登録情報を不正に利用されないよう、自己の責任においてアカウント情報を管理するものとします。',
            ]),
            _buildSectionContent([
              '2.　',
              'ユーザーは，アカウント情報を第三者に譲渡，貸与，共用することはできません。',
            ]),
            _buildSectionContent([
              '3.　',
              '当方は、ユーザーアカウントを使用して行われた一切の行為を、ユーザー自身の行為とみなすことができ、これによりユーザーに損害が生じた場合でも当方の故意、または重大な過失を除き一切の責任を負わないものとする。',
            ]),
            _buildSectionTitle('第4条（利用料金および支払い）'),
            _buildSectionContent([
              '1.　',
              '本サービスは無償でご利用いただけます。',
            ]),
            _buildSectionTitle('第5条（禁止事項）'),
            _buildSectionContent([
              '',
              'ユーザーは，本サービスの利用において以下の行為をしてはなりません。',
            ]),
            _buildSectionContent([
              '',
              '以下の行為が認められた場合、予告なく投稿の非表示化、投稿機能の停止等の措置を行うことがあります。また、当該措置を行うに至った理由又は経緯の説明は致しません。',
            ]),
            _buildSectionContent([
              '　（1）',
              '犯罪行為に関連する行為又は公序良俗に反する行為',
            ]),
            _buildSectionContent([
              '　（2）',
              'サーバーやネットワークの妨害、コンピューター・ウイルスその他の有害なコンピューター・プログラムを含む情報を送信する行為。',
            ]),
            _buildSectionContent([
              '　（3）',
              '他者の権利を侵害する行為',
            ]),
            _buildSectionContent([
              '　（4）',
              '不適切な表現（暴力的，性的，差別的表現など）を投稿する行為',
            ]),
            _buildSectionContent([
              '　（5）',
              'その他、当アプリの定める規則に従わない、当方が不適切と判断する行為',
            ]),
            _buildSectionTitle('第6条（利用条件等）'),
            _buildSectionContent([
              '1.　',
              'ユーザは、自己の責任において本アプリをユーザー自身の携帯端末にダウンロードし、インストールするものとします。また、当方は本アプリが全ての携帯端末に対応することを保証しません。',
            ]),
            _buildSectionContent([
              '2.　',
              'ユーザは、本アプリを利用するにあたり、自己の費用と責任において、必要な機器、ソフトウェア、通信手段等を用意し、これに関連する一切の費用を負担するものとします。',
            ]),
            _buildSectionContent([
              '3.　',
              '本アプリに関する著作権・その他権利は当方に帰属します。本利用規約に基づく本アプリの提供は、明示的に定めがある場合を除きユーザーに対して本アプリの著作権その他いかなる権利の転移ないし利用許諾を意味するものではありません。',
            ]),
            _buildSectionContent([
              '4.　',
              '本アプリの仕様・ルール・デザイン・視聴覚表現及び効果その他一切の事項については、当方が任意に設定、構築、変更できるものとし、ユーザーは予めこれを了承します。',
            ]),
            _buildSectionContent([
              '5.　',
              'ユーザーは以下の各号に対し該当、又は該当する恐れのある行為を行なってはならないものとします。',
            ]),
            _buildSectionContent([
              '　（1）',
              '本サービス内のデータを操作または変更しようとする行為。',
            ]),
            _buildSectionContent([
              '　（2）',
              '本サービスに影響を与える外部ツールの利用・作成・配布・販売等を行う行為。',
            ]),
            _buildSectionContent([
              '　（3）',
              '本サービスに関連するシステムに対し、不正アクセスを試みる行為。',
            ]),
            _buildSectionContent([
              '　（4）',
              '他のユーザーの個人情報を不正に収集、利用、または第三者に提供する行為。',
            ]),
            _buildSectionContent([
              '　（5）',
              '本サービスの正常な運営を妨害する行為（過剰なサーバー負荷を引き起こす行為など）。',
            ]),
            _buildSectionContent([
              '　（6）',
              '本サービスの運営者や他のユーザーになりすます行為。',
            ]),
            _buildSectionContent([
              '　（7）',
              '著作権、商標権、その他の知的財産権を侵害する行為。',
            ]),
            _buildSectionContent([
              '　（8）',
              '法令、公序良俗または本規約に違反する行為。',
            ]),
            _buildSectionContent([
              '　（9）',
              '本サービスを通じて、以下の内容を含む投稿や送信を行う行為。',
            ]),
            _buildSectionContent([
              '　',
              '　　・過度に暴力的または露骨な性的表現を含む内容。',
            ]),
            _buildSectionContent([
              '　',
              '　　・差別、ヘイトスピーチ、または誹謗中傷を含む内容。',
            ]),
            _buildSectionContent([
              '　',
              '　　・犯罪行為を誘発または助長する内容。',
            ]),
            _buildSectionContent([
              '　　　',
              '・他者のプライバシーを侵害する内容。',
            ]),
            _buildSectionContent([
              '　　　',
              '・他者の著作権、商標権、プライバシー権を侵害する行為。',
            ]),
            _buildSectionContent([
              '　（10）',
              '反社会的勢力に対する利益供与や、これを助長する行為。',
            ]),
            _buildSectionContent([
              '　（11）',
              'その他、運営者が不適切と判断する行為。',
            ]),
            _buildSectionTitle('第7条（違反者への措置）'),
            _buildSectionContent([
              '',
              '本規約に違反した場合、以下の措置を取ることがあります。',
            ]),
            _buildSectionContent([
              '　（1）',
              '軽微な違反の場合、警告メッセージを送信します。違反が継続する場合、アカウント停止を行います。',
            ]),
            _buildSectionContent([
              '　（2）',
              '重大な違反の場合、、該当するユーザーのアカウントを一時的または永久に停止します。',
            ]),
            _buildSectionContent([
              '　（3）',
              '違反するコンテンツが投稿された場合、事前通知なしに削除します。',
            ]),
            _buildSectionContent([
              '　（4）',
              '悪質な行為が確認された場合、必要に応じて法的措置を講じます。',
            ]),
            _buildSectionContent([
              '　（1）',
              '等アプリの提供に関わるシステムの保守作業や点検を定期または緊急に行う場合。',
            ]),
            _buildSectionContent([
              '　（2）',
              '天災や事故等の不可抗力により運営ができなくなった場合。',
            ]),
            _buildSectionContent([
              '　（3）',
              'その他，運営上必要と判断した場合。',
            ]),
            _buildSectionContent([
              '2.　',
              '当方は、当方の都合により本サービスの提供を終了することができます。この場合、当方はユーザーに1ヶ月以上の期間を定めて事前に通知するものとします。ただし、当方が緊急の事由により提供を終了する場合、予告なく提供を終了する場合があります。',
            ]),
            _buildSectionContent([
              '3.　',
              '当方は、本サービスの提供の停止または中断により、ユーザーまたは第三者が被った損害について一切の責任を負いません。',
            ]),
            _buildSectionTitle('第8条（著作権）'),
            _buildSectionContent([
              '',
              'ユーザーが本サービスを通じて投稿またはアップロードしたコンテンツの著作権は、全て作成・投稿を行ったユーザーに帰属します。当方は、投稿コンテンツについていかなる権利も主張いたしません。',
            ]),
            _buildSectionTitle('第9条（利用制限および登録抹消）'),
            _buildSectionContent([
              '',
              '当方は以下の場合，利用制限や登録抹消を行うことがあります。',
            ]),
            _buildSectionContent([
              '　（1）',
              '規約違反があった場合',
            ]),
            _buildSectionContent([
              '　（2）',
              '虚偽の登録情報が判明した場合',
            ]),
            _buildSectionContent([
              '　（3）',
              'その他，当方が適切でないと判断した場合',
            ]),
            _buildSectionContent([
              '',
              'これにより生じた損害について，当方は責任を負いません。',
            ]),
            _buildSectionTitle('第10条（退会）'),
            _buildSectionContent([
              '1.　',
              'ユーザーは，当方が定める手続により，自己の自由な意思で本サービスを退会又は本アプリのアンインストールをすることができます。ユーザーが本アプリのアンインストールを行った場合、退会したものとみなします。',
            ]),
            _buildSectionContent([
              '2.　',
              '退会により，ユーザーが本アプリに登録した情報は全て削除されます。当方は、退会したユーザーの個人情報等一切の情報を引き続き保管する義務を負わないものとします。',
            ]),
            _buildSectionTitle('第11条（免責事項）'),
            _buildSectionContent([
              '1.　',
              '当方は、本サービスの内容がユーザーの特定の目的に適合すること、コンテンツ及びソフトウェア等の情報についてその正確性、完全性、有用性、安全性を有すること、またはエラーがないことを保証するものではありません。',
            ]),
            _buildSectionContent([
              '2.　',
              'ユーザーが、本サービスを利用することにより第三者に対して損害を与えた場合、ユーザーは自己の費用と責任においてこれを賠償するものとします。',
            ]),
            _buildSectionContent([
              '3.　',
              '本サービスは、ユーザーの利用環境によっては正常に動作しない場合があります。当方は、これにより生じた損害について一切の責任を負いません。',
            ]),
            _buildSectionContent([
              '4.　',
              '本サービスを通じて得られる情報、他のユーザーによる投稿コンテンツ、または第三者による行為について、当方はその正確性や合法性を保証するものではなく、それらに起因して生じた損害について責任を負いません。',
            ]),
            _buildSectionContent([
              '5.　',
              '本サービスに関する当方とユーザーとの間の契約（本規約を含む）が、消費者契約法に定める消費者契約に該当する場合、当方の責任の一部免除規定は適用されない場合があります。ただし、その場合でも、当方は過失（重大な過失を除く）による損害については特別な事情による損害について責任を負いません。',
            ]),
            _buildSectionContent([
              '6.　',
              '当方は、本アプリのバグその他を補修する義務及び本アプリの改良又は改善する義務を負いません。ただし、当方はユーザーにアップデート版又はバージョンアップ情報を提供する場合があります。その場合、かかるアップデート版又はバージョンアップ情報等も本アプリとして扱い、本利用規約がこちらにも適用されます。',
            ]),
            _buildSectionTitle('第12条（サービス内容の変更等）'),
            _buildSectionContent([
              '1.　',
              '当方は、本サービスの運営上必要と判断した場合、以下の内容を変更、追加または廃止することができます。',
            ]),
            _buildSectionContent([
              '　（1）',
              '提供する機能やサービス内容の変更',
            ]),
            _buildSectionContent([
              '　（2）',
              'ユーザーインターフェースの改良または変更',
            ]),
            _buildSectionContent([
              '　（3）',
              '技術的要因に基づく仕様の変更',
            ]),
            _buildSectionContent([
              '　（4）',
              '運営方針の変更に伴うサービスの終了',
            ]),
            _buildSectionContent([
              '2.　',
              '前項に基づく変更等を行う際、当方は事前に適切な方法でユーザーに通知します。ただし、緊急を要する場合には、事後の通知となる場合があります。',
            ]),
            _buildSectionContent([
              '3.　',
              '本サービスの変更、追加または廃止により、ユーザーに生じた不利益や損害について、当方は一切の責任を負いません。ただし、当方の故意または重大な過失がある場合を除きます。',
            ]),
            _buildSectionContent([
              '4.　',
              'ユーザーが本サービスの変更内容に同意できない場合には、当方が定める手続きにより、サービスの利用を終了することができます。',
            ]),
            _buildSectionTitle('第13条（個人情報の取扱い）'),
            _buildSectionContent([
              '',
              '当方は，個人情報を「プライバシーポリシー」に従い適切に管理します。',
            ]),
            _buildSectionTitle('第14条（本利用規約の有効性）'),
            _buildSectionContent([
              '1.　',
              '本利用規約の各条項の一部又は全部が法令に基づいて無効と判断されても、一部が無効とされた条項の残りの部分及び当該条項以外の本利用規約のその他の規定は継続して完全にその効力を有するものとします。',
            ]),
            _buildSectionContent([
              '2.　',
              '本利用規約の一部、あるユーザーとの関係で無効とされ、又は取り消された場合でも、本利用規約はそのほかのユーザーとの関係では継続して完全にその効力を有するものとします。',
            ]),
            _buildSectionTitle('第15条（連絡・通知）'),
            _buildSectionContent([
              '',
              '本サービスに関する問い合わせやその他ユーザから当方に対する連絡又は通知は、当方の定める方法で行うものとします。',
            ]),
            _buildSectionTitle('第16条（権利義務の譲渡禁止）'),
            _buildSectionContent([
              '',
              'ユーザーは，当方の事前承諾なく，本規約上の権利または義務を第三者に貸与、交換、譲渡、売買、質入れすることはできません。また、方法の如何を問わず第三者に利用させてはいけないものとします。',
            ]),
            _buildSectionTitle('第17条（準拠法および裁判管轄）'),
            _buildSectionContent([
              '',
              '本規約の準拠法は日本法とし，本規約に起因しまたは関連する当方とユーザーの間の一切の紛争については，東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
            ]),
            SizedBox(height: 30),
            Text(
              '【2024年12月7日制定】',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildSectionContent(List<String> contentParts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contentParts[0],
          style: TextStyle(fontSize: 13),
        ),
        Expanded(
          child: Text(
            contentParts[1],
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
