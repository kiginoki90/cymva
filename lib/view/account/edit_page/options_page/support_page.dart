import 'package:flutter/material.dart';
import 'package:cymva/view/account/edit_page/options_page/support_page/terms_of_service_page.dart'
    as terms;
import 'package:cymva/view/account/edit_page/options_page/support_page/privacy_policy_page.dart'
    as privacy;
import 'package:cymva/view/account/edit_page/options_page/support_page/contact_us_page.dart'
    as contact;

class SupportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('サポート'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOptionItem(
              context,
              icon: Icons.description,
              label: '利用規約',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => terms.TermsOfServicePage(),
                  ),
                );
              },
            ),
            _buildOptionItem(
              context,
              icon: Icons.privacy_tip,
              label: 'プライバシーポリシー',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => privacy.PrivacyPolicyPage(),
                  ),
                );
              },
            ),
            _buildOptionItem(
              context,
              icon: Icons.contact_mail,
              label: 'お問い合わせ',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => contact.ContactUsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(BuildContext context,
      {required IconData icon,
      required String label,
      required Function onTap}) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF219DDD)),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
