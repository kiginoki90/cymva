import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = user?.email;
    });
  }

  Future<void> _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      // SMTPサーバーの設定
      final smtpServer = gmail('kzkk194@gmail.com', 'cvdk mnjy xrug ajkl');

      final message = Message()
        ..from = Address('info@cymva.jp', 'Cymva Support')
        ..recipients.add('info@cymva.jp')
        ..subject = _subjectController.text
        ..text = '送信元: $_userEmail\n\n${_messageController.text}';

      try {
        final sendReport = await send(message, smtpServer);
        print('Message sent: ' + sendReport.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メールが送信されました。')),
        );
      } on MailerException catch (e) {
        print('Message not sent. \n' + e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メールの送信に失敗しました。')),
        );
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '件名を入力してください';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              _buildLabel('お問い合わせ内容'),
              SizedBox(height: 10),
              _buildTextField(
                controller: _messageController,
                hintText: 'お問い合わせ内容を入力してください',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'お問い合わせ内容を入力してください';
                  }
                  return null;
                },
              ),
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
                style: TextStyle(fontSize: 12),
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
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
