import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweeda_real_estate_office_elc/app.dart';
import 'package:sweeda_real_estate_office_elc/providers/auth_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/config_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/offer_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/request_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/appointment_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/notification_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/payment_provider.dart';
import 'package:sweeda_real_estate_office_elc/providers/admin_provider.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    // Use a minimal provider setup for testing
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ConfigProvider()),
          ChangeNotifierProvider(create: (_) => OfferProvider()),
          ChangeNotifierProvider(create: (_) => RequestProvider()),
          ChangeNotifierProvider(create: (_) => AppointmentProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => PaymentProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MyApp), findsOneWidget);
  });
}
