import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactUsPage extends StatefulWidget {
  @override
  _ContactUsPageState createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  String? _userEmail;
  int _subjectCharCount = 0;
  int _messageCharCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _subjectController.addListener(_updateSubjectCharCount);
    _messageController.addListener(_updateMessageCharCount);
  }

  void _updateSubjectCharCount() {
    setState(() {
      _subjectCharCount = _subjectController.text.length;
    });
  }

  void _updateMessageCharCount() {
    setState(() {
      _messageCharCount = _messageController.text.length;
    });
  }

  Future<void> _loadUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = user?.email;
    });
  }

  Future<void> _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      String? accountId = await storage.read(key: 'account_id') ??
          FirebaseAuth.instance.currentUser?.uid;

      // Firestoreからユーザー情報の取得
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(accountId)
          .get();
      String userName = userDoc['name'];
      String userId = userDoc['user_id'];

      // SMTPサーバーの設定
      final smtpServer = gmail('kzkk194@gmail.com', 'aqfj loyu bwft dacp');

      final message = Message()
        ..from = Address('info@cymva.jp', 'Cymva Support')
        ..recipients.add('info@cymva.jp')
        ..subject = _subjectController.text
        ..text =
            '送信元: $_userEmail\n\n${_messageController.text}\n\nAccount ID: $accountId\nName: $userName\nUser ID: $userId';

      try {
        final sendReport = await send(message, smtpServer);
        print('Message sent: ' + sendReport.toString());

        showTopSnackBar(context, 'メールが送信されました。', backgroundColor: Colors.green);
      } on MailerException catch (e) {
        print('Message not sent. \n' + e.toString());

        showTopSnackBar(context, 'メールの送信に失敗しました。', backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('お問い合わせ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('件名'),
              SizedBox(height: 10),
              _buildTextField(
                controller: _subjectController,
                hintText: '件名を入力してください',
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '件名を入力してください';
                  }
                  if (value.length > 50) {
                    return '件名は50文字以内で入力してください';
                  }
                  return null;
                },
              ),
              Text('$_subjectCharCount / 50',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 20),
              _buildLabel('お問い合わせ内容'),
              SizedBox(height: 10),
              _buildTextField(
                controller: _messageController,
                hintText: 'お問い合わせ内容を入力してください',
                maxLines: 10,
                maxLength: 1500,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'お問い合わせ内容を入力してください';
                  }
                  if (value.length > 1500) {
                    return 'お問い合わせ内容は1500文字以内で入力してください';
                  }
                  return null;
                },
              ),
              Text('$_messageCharCount / 1500',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _sendEmail,
                  child: Text('送信'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                '返信はご登録のメールアドレスにお送りいたします。',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'info@cymva.jp'));

                  showTopSnackBar(context, 'メールアドレスをコピーしました。',
                      backgroundColor: Colors.green);
                },
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'お問合せの送信に失敗する場合は、お手数ですが直接 ',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      TextSpan(
                        text: 'info@cymva.jp',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                      TextSpan(
                        text: ' までご連絡ください。',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    int? maxLength,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        counterText: '', // カウンターのテキストを非表示にする
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _subjectController.removeListener(_updateSubjectCharCount);
    _messageController.removeListener(_updateMessageCharCount);
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
