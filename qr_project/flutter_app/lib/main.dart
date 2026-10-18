import 'package:flutter/material.dart';
import 'screens/connect_screen.dart';
import 'theme.dart';

void main() => runApp(const QrOrderApp());

class QrOrderApp extends StatelessWidget {
  const QrOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gọi món QR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ConnectScreen(),
    );
  }
}
