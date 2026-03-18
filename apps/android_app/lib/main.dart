import 'package:flutter/material.dart';
import 'package:android_app/home_screen.dart';

void main() => runApp(const AndroidApp());

class AndroidApp extends StatelessWidget {
  const AndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Client',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
    );
  }
}