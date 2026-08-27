import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Privacy policy',
      body: '''
StrollWise is a crowd-sourced travel intelligence app for Metro Cebu.

What we collect
• Account details: email, display name, password hash, traveler type, origin city/country.
• Location when you submit a tag (when-in-use only), used to assign an H3 cell.
• Tag content: category, tags, optional notes and photos.
• Technical logs: coarse IP for rate limiting and optional crash reports.

How location is shown
Public APIs expose aggregated zones (traveler mix and place type). Individual trajectories and exact GPS are not shown on Explore. Raw reports are visible only to operators with admin accounts.

Research use
If you accept research consent at registration, tags may be converted into aggregated zone signals for academic research.

Retention
Data is kept while the hosted demo or research project is active. Backups may retain copies for a limited window after deletion.

Sharing
We do not sell personal data. Processors may include the database host, object storage, error monitoring, and Mapbox geocoding when configured.
''',
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Terms of use',
      body: '''
By creating an account or using StrollWise you agree to these terms. The service is a research-oriented crowd map, not a professional safety or navigation product.

Accounts
Keep your password secret. Operators may disable accounts that spam tags or try to deanonymize other people.

Your content
You grant StrollWise a licence to store your tags and photos, run the aggregation pipeline, and show aggregated results to other users.

Acceptable use
Do not flood fabricated locations, scrape the geocoding endpoint, or attempt to recover another user's GPS trail from public zone data.

Disclaimer
Zone colors and place types are crowd estimates and can be wrong. Do not rely on StrollWise as the sole source for personal safety decisions.
''',
    );
  }
}

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(
          body,
          style: const TextStyle(
            color: AppColors.secondaryText,
            height: 1.45,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
