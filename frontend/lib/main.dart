import 'package:flutter/material.dart';
import 'services/theme.dart';
import 'screens/lock_screen.dart';

void main() {
  runApp(const VaultApp());
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LockScreen(),
    );
  }
}
