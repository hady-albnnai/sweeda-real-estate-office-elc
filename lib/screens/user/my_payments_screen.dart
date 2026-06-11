import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/payment_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

/// شاشة سجل دفعات المستخدم — يرى حالة دفعاته (معلقة/مقبولة/مرفوضة)
class MyPaymentsScreen extends StatefulWidget {
  const MyPaymentsScreen({super.key});

  @override
  State<MyPaymentsScreen> createState() => _MyPaymentsScreenState();
}

class _MyPaymentsScreenState extends State<MyPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid != null) {
      await context.read<PaymentProvider>().fetchPayments(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payProv = context.watch<PaymentProvider>();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('سجل دفعاتي'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: payProv.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : payProv.payments.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryGold,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: payProv.payments.length,
                    itemBuilder: (_, i) => _card(payProv.payments[i]),
                  ),
                ),
    );
  }

  Widget _card(PaymentModel p) {
    final stsColor = p.sts == 1
        ? Colors.green
        : p.sts == 2
            ? Colors.red
            : Colors.orange;
    final stsLabel = p.sts == 1
        ? '✅ مقبولة'
        : p.sts == 2
            ? '❌ مرفوضة'
            : '⏳ معلقة';
    final pkgName = p.pkg == 1
        ? 'الفضية'
        : p.pkg == 2
            ? 'الذهبية'
            : 'المجانية';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stsColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الرأس
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'باقة $pkgName',
                style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stsColor.withValues(alpha: 0.5)),
                ),
                child: Text(stsLabel,
                    style: TextStyle(
                        color: stsColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // التفاصيل
          _row('المبلغ',
              '${p.amt.toStringAsFixed(0)} ${p.cur == 0 ? '\$' : 'ل.س'}'),
          _row('قناة الدفع', p.channelDisplayName()),
          if (p.ref.isNotEmpty) _row('رقم المرجع', p.ref),
          _row('التاريخ', AppUtils.formatTimestamp(p.tsCrt)),

          // رسالة الحالة
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: stsColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(
                p.sts == 1
                    ? Icons.check_circle_outline
                    : p.sts == 2
                        ? Icons.cancel_outlined
                        : Icons.pending_outlined,
                color: stsColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.sts == 1
                      ? 'تم قبول دفعتك وتفعيل الباقة. شكراً!'
                      : p.sts == 2
                          ? 'لم تُقبل الدفعة. يرجى التحقق من البيانات والمحاولة مجدداً أو التواصل مع الإدارة.'
                          : 'دفعتك قيد المراجعة من الإدارة. عادةً خلال 24 ساعة.',
                  style: TextStyle(color: stsColor, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),

          // زر تجديد إذا مرفوضة
          if (p.sts == 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/user/payment?pkg=${p.pkg}'),
                icon: const Icon(Icons.refresh,
                    color: AppTheme.primaryGold, size: 16),
                label: const Text('محاولة مجدداً',
                    style: TextStyle(color: AppTheme.primaryGold)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('$label: ',
              style:
                  const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80,
                color: AppTheme.textGrey.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            const Text('لا توجد دفعات بعد',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/user/packages'),
              child: const Text('تصفح الباقات'),
            ),
          ],
        ),
      );
}
