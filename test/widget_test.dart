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
  // Standard flutter test setup
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Basic App Load Test', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();
    
    // We check if MyApp is successfully rendered
    expect(find.byType(MyApp), findsOneWidget);
  });
}
