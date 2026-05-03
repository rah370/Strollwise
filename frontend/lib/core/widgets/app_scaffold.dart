import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.body, this.appBar, this.fab, super.key});

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: appBar, body: body, floatingActionButton: fab);
  }
}
