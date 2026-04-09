import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final List<_Section> _sections;

  const LegalScreen._({required this.title, required List<_Section> sections})
      : _sections = sections;

  factory LegalScreen.privacyPolicy() => const LegalScreen._(
        title: 'Privacy Policy',
        sections: [
          _Section(
            heading: 'Information We Collect',
            body:
                'AquaRythu collects information you provide directly: your phone number for login, '
                'farm name and location, pond details, feed records, and sampling data. '
                'This data is stored securely on Supabase servers.',
          ),
          _Section(
            heading: 'How We Use Your Data',
            body:
                'Your data is used solely to operate the AquaRythu app — to generate feed plans, '
                'track pond growth, and display your farm analytics. '
                'We do not sell or share your data with third parties.',
          ),
          _Section(
            heading: 'Data Ownership',
            body:
                'You own your farm data. You can request deletion of your account and all '
                'associated data at any time by contacting us.',
          ),
          _Section(
            heading: 'Data Security',
            body:
                'All data is transmitted over HTTPS and stored with row-level security. '
                'Only you can access your farm records.',
          ),
          _Section(
            heading: 'Contact',
            body:
                'For privacy concerns or data deletion requests, contact us at: '
                'support@aquarythu.com',
          ),
        ],
      );

  factory LegalScreen.termsAndConditions() => const LegalScreen._(
        title: 'Terms & Conditions',
        sections: [
          _Section(
            heading: 'Acceptance of Terms',
            body:
                'By using AquaRythu, you agree to these terms. If you do not agree, '
                'please do not use the app.',
          ),
          _Section(
            heading: 'Use of the App',
            body:
                'AquaRythu is a farm management tool. Feed recommendations are based on '
                'standard aquaculture guidelines and are advisory in nature. '
                'Always apply your own judgement and consult experts when needed.',
          ),
          _Section(
            heading: 'Account Responsibility',
            body:
                'You are responsible for maintaining the confidentiality of your account. '
                'Do not share your login OTP with anyone.',
          ),
          _Section(
            heading: 'Limitation of Liability',
            body:
                'AquaRythu is not liable for any financial losses resulting from the use '
                'of feed recommendations or data in the app.',
          ),
          _Section(
            heading: 'Changes to Terms',
            body:
                'We may update these terms from time to time. Continued use of the app '
                'after changes constitutes acceptance of the new terms.',
          ),
          _Section(
            heading: 'Contact',
            body: 'For questions about these terms, contact: support@aquarythu.com',
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Last updated: April 2025',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ..._sections.map((s) => _SectionWidget(section: s)),
        ],
      ),
    );
  }
}

class _Section {
  final String heading;
  final String body;
  const _Section({required this.heading, required this.body});
}

class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(section.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
