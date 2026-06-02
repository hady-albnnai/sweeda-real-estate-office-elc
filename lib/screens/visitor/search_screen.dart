import 'package:flutter/material.dart';

/// شاشة البحث
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث'),
      ),
      body: const Center(
        child: Text('شاشة البحث — قيد التطوير'),
      ),
    );
  }
}