import 'package:flutter/material.dart';

/// شاشة تفاصيل العرض
class OfferDetailScreen extends StatelessWidget {
  final String offerId;

  const OfferDetailScreen({super.key, required this.offerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العرض'),
      ),
      body: const Center(
        child: Text('شاشة تفاصيل العرض — قيد التطوير'),
      ),
    );
  }
}