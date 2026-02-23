import 'package:flutter/material.dart';

import '../processes/ui/processes_page.dart';
import 'quotes_page.dart';

class QuotesTabsPage extends StatelessWidget {
  const QuotesTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cotizaciones'),
          bottom: TabBar(
            indicatorColor: scheme.onPrimary,
            tabs: const [
              Tab(
                icon: Icon(Icons.request_quote_outlined),
                text: 'Cotizaciones',
              ),
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'Procesos'),
            ],
          ),
        ),
        body: const TabBarView(children: [QuotesPage(), ProcessesPage()]),
      ),
    );
  }
}
