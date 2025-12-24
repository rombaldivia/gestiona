import 'package:flutter/material.dart';
import '../data/company_service.dart';
import '../../home/ui/home_page.dart';
import 'create_company_page.dart';
import '../../auth/data/auth_service.dart';

class CompanyGate extends StatelessWidget {
  const CompanyGate({
    super.key,
    required this.auth,
    required this.companyService,
  });

  final AuthService auth;
  final CompanyService companyService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: companyService.firstCompanyIdStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final companyId = snap.data;

        if (companyId == null) {
          return CreateCompanyPage(companyService: companyService);
        }

        return HomePage(auth: auth, companyId: companyId);
      },
    );
  }
}
