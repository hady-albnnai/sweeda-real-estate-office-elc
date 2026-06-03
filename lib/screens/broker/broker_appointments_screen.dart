import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_provider.dart';
import '../../models/appointment_model.dart';
import '../../core/theme/app_theme.dart';

class BrokerAppointmentsScreen extends StatelessWidget {
  const BrokerAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brokerProvider = Provider.of<BrokerProvider>(context);
    final String brokerId = 'current_broker_id'; // Replace with actual auth userId

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات المعاينة'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<AppointmentModel>>(
        future: brokerProvider.getBrokerAppointments(brokerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد طلبات مواعيد حالياً', style: TextStyle(color: AppTheme.textGrey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final appt = snapshot.data![index];
              return Card(
                color: AppTheme.surfaceBlack,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  title: Text('طلب معاينة - ${appt.day} ${appt.time}', style: const TextStyle(color: AppTheme.textWhite)),
                  subtitle: Text('رقم الطلب: ${appt.id}', style: const TextStyle(color: AppTheme.textGrey)),
                  trailing: appt.sts == 0 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: AppTheme.primaryGold),
                              onPressed: () async {
                                await brokerProvider.handleAppointment(appt.id, 1);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الموعد')));
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrokerAppointmentsScreen()));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await brokerProvider.handleAppointment(appt.id, 2);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الموعد')));
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrokerAppointmentsScreen()));
                              },
                            ),
                          ],
                        )
                      : Text('الحالة: ${appt.sts}', style: const TextStyle(color: AppTheme.primaryGold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
