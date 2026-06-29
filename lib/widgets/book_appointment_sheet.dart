import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../models/offer_model.dart';
import '../core/theme/app_theme.dart';

class BookAppointmentSheet extends StatefulWidget {
  final OfferModel offer;
  final String? requestId;
  const BookAppointmentSheet({super.key, required this.offer, this.requestId});

  @override
  State<BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<BookAppointmentSheet> {
  String? _selectedDayKey;
  String? _selectedSlot; // "HH:MM-HH:MM"
  String? _selectedTime; // "HH:MM"

  String _dayName(String d) => {
        'mon': 'الاثنين',
        'tue': 'الثلاثاء',
        'wed': 'الأربعاء',
        'thu': 'الخميس',
        'fri': 'الجمعة',
        'sat': 'السبت',
        'sun': 'الأحد',
      }[d] ??
      d;

  /// توليد فترات زمنية (كل 30 دقيقة) بناءً على النطاق المختار
  List<String> _generateTimeSlots(String slotStr) {
    final parts = slotStr.split('-');
    if (parts.length != 2) return [];

    final fromParts = parts[0].trim().split(':');
    final toParts = parts[1].trim().split(':');

    int startHour = int.tryParse(fromParts[0]) ?? 0;
    int startMin = int.tryParse(fromParts[1]) ?? 0;
    int endHour = int.tryParse(toParts[0]) ?? 0;
    int endMin = int.tryParse(toParts[1]) ?? 0;

    final startTotalMins = startHour * 60 + startMin;
    final endTotalMins = endHour * 60 + endMin;

    final List<String> slots = [];
    for (int total = startTotalMins; total < endTotalMins; total += 30) {
      final h = (total ~/ 60).toString().padLeft(2, '0');
      final m = (total % 60).toString().padLeft(2, '0');
      slots.add('$h:$m');
    }
    return slots;
  }

  Future<void> _confirm() async {
    if (_selectedDayKey == null || _selectedSlot == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار اليوم والفترة والوقت')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final provider = context.read<AppointmentProvider>();
    final userId = auth.userModel?.uid ?? '';

    final success = await provider.bookAppointment(
      userId: userId,
      offerId: widget.offer.id,
      selectedDayKey: _selectedDayKey!,
      selectedTime: _selectedTime!,
      brokerId: widget.offer.brkId.isNotEmpty ? widget.offer.brkId : null,
      requestId: widget.requestId,
    );

    if (!mounted) return;
    if (success) {
      final activeCount = provider.lastBookingActiveCount;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activeCount > 1
                ? '✅ تم إرسال طلب الموعد ليوم ${_dayName(_selectedDayKey!)} — '
                  'يوجد $activeCount مواعيد نشطة على هذا العرض. سيتم التأكيد عبر المكتب.'
                : '✅ تم إرسال طلب الموعد ليوم ${_dayName(_selectedDayKey!)} — '
                  'سيتم التأكيد عبر المكتب',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر حجز الموعد. قد يكون الوقت محجوزاً أو لا يوجد مشرف متاح أو يوجد طلب إتمام معلق.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avl = widget.offer.avl;
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;

    // الزائر غير المسجّل — نعرض رسالة تسجيل الدخول بدل الـ sheet
    if (!isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: AppTheme.deepBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, color: AppTheme.primaryGold, size: 60),
          const SizedBox(height: 16),
          const Text('يجب تسجيل الدخول',
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'لحجز موعد معاينة يجب أن تكون مسجّلاً في التطبيق.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/login');
              },
              child: const Text('تسجيل الدخول',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50, height: 5,
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('حجز موعد معاينة',
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // توضيح المكتب
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.business_center, color: AppTheme.primaryGold, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الحجز يتم عبر إدارة المكتب لضمان جدية الطرفين وحماية خصوصية المالك.',
                  style: TextStyle(
                      color: AppTheme.primaryGold, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          if (avl.isEmpty)
            const Center(
              child: Text('لا توجد مواعيد متاحة حالياً للمعاينة.',
                  style: TextStyle(color: AppTheme.textGrey)),
            )
          else ...[
            const Text('1. اختر اليوم:',
                style: TextStyle(
                    color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: avl.keys.map((key) {
                final selected = _selectedDayKey == key;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDayKey = key;
                        _selectedSlot = null;
                        _selectedTime = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryGold
                            : AppTheme.surfaceBlack,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryGold),
                      ),
                      child: Text(
                        _dayName(key),
                        style: TextStyle(
                          color: selected ? AppTheme.deepBlack : AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (_selectedDayKey != null) ...[
              const Text('2. اختر الفترة:',
                  style: TextStyle(
                      color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (avl[_selectedDayKey!] ?? []).map((slot) {
                  final selected = _selectedSlot == slot;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedSlot = slot;
                      _selectedTime = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryGold.withOpacity(0.2)
                            : AppTheme.surfaceBlack,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryGold
                              : AppTheme.textGrey.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        slot.replaceAll('-', ' — '),
                        style: TextStyle(
                          color: selected ? AppTheme.primaryGold : AppTheme.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedSlot != null) ...[
              const Text('3. اختر الوقت المحدد:',
                  style: TextStyle(
                      color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _generateTimeSlots(_selectedSlot!).map((time) {
                  final selected = _selectedTime == time;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = time),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryGold : AppTheme.surfaceBlack,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppTheme.primaryGold : AppTheme.textGrey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedTime != null ? _confirm : null,
                child: const Text('تأكيد طلب الموعد',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
