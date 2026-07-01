import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../models/offer_model.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';

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
  List<String> _bookedSlots = [];
  bool _loadingSlots = false;
  bool _submitting = false;

  static const List<String> _weekKeys = [
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'
  ];

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

  /// هل صاحب العرض "جاهز للمعاينة في أي وقت"؟ (avl تحتوي المفتاح any)
  bool get _isAnytime => widget.offer.avl.containsKey('any');

  /// أيام الحجز المعروضة: كل أيام الأسبوع في حالة any،
  /// وإلا الأيام التي حددها صاحب العرض حصراً (القاعدة 1)
  List<String> get _availableDays {
    if (_isAnytime) return _weekKeys;
    return _weekKeys.where((k) => (widget.offer.avl[k] ?? []).isNotEmpty).toList();
  }

  /// فترات اليوم المختار: في حالة any يكون الدوام من إعدادات app_config
  /// (appt.any_from — appt.any_to، افتراضياً 09:00-21:00)
  List<String> _slotsForDay(String dayKey) {
    if (_isAnytime) {
      final cfg = context.read<ConfigProvider>().config;
      final from = cfg?.apptAnyFrom ?? '09:00';
      final to = cfg?.apptAnyTo ?? '21:00';
      return ['$from-$to'];
    }
    return widget.offer.avl[dayKey] ?? [];
  }

  /// الفارق الأدنى بين المواعيد بالدقائق (قاعدة الساعة) — من app_config
  int get _gapMins {
    final cfg = context.read<ConfigProvider>().config;
    return cfg?.apptGapMins ?? 60;
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedDayKey == null) return;

    setState(() => _loadingSlots = true);

    final targetWeekday = _weekKeys.indexOf(_selectedDayKey!) + 1;
    final now = DateTime.now();
    var daysAhead = (targetWeekday - now.weekday) % 7;
    if (daysAhead < 0) daysAhead += 7;
    final date = DateTime(now.year, now.month, now.day + daysAhead);

    final slots = await context.read<AppointmentProvider>().fetchBookedSlots(
      widget.offer.id,
      date,
    );

    if (mounted) {
      setState(() {
        _bookedSlots = slots;
        _loadingSlots = false;
      });
    }
  }

  int? _timeToMins(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// هل هذا الوقت محظور بقاعدة عدم التعارض؟
  /// محظور إذا وقع ضمن أقل من gap_mins (ساعة) من أي موعد نشط على العرض
  /// — موعد 10:00 يحظر كل الأوقات قبل 11:00 وبعد 09:00 (القاعدة 3)
  bool _isBlocked(String time) {
    final mins = _timeToMins(time);
    if (mins == null) return false;
    for (final booked in _bookedSlots) {
      final bMins = _timeToMins(booked);
      if (bMins == null) continue;
      if ((mins - bMins).abs() < _gapMins) return true;
    }
    return false;
  }

  /// توليد أوقات (كل 30 دقيقة) بناءً على الفترة المختارة
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

  String _errorMessage(BookingResult result) {
    switch (result.errorCode) {
      case 'NO_SUPERVISOR_AVAILABLE':
        if (result.suggestedDt != null) {
          final s = AppUtils.formatTimestamp(
            result.suggestedDt,
            pattern: 'yyyy/MM/dd — HH:mm',
          );
          return 'لا يوجد مشرف متاح للتوقيت الذي اخترته.\nأقرب موعد متاح: $s\nيمكنك اختياره أو اختيار وقت آخر.';
        }
        return 'لا يوجد مشرف متاح للتوقيت الذي اخترته حالياً. يرجى اختيار وقت آخر.';
      case 'TIME_CONFLICT_ON_OFFER':
        return 'يوجد موعد آخر على هذا العرض قريب من التوقيت المختار — يجب فارق ساعة على الأقل بين المواعيد. اختر وقتاً آخر.';
      case 'DUPLICATE_APPOINTMENT':
        return 'لديك موعد نشط مسبقاً على هذا العرض.';
      case 'DAY_NOT_AVAILABLE':
      case 'TIME_NOT_IN_AVAILABLE_SLOTS':
        return 'التوقيت المختار خارج المواعيد التي حددها صاحب العرض.';
      case 'NO_AVAILABILITY':
        return 'هذا العرض لا يحتوي مواعيد معاينة متاحة.';
      case 'OFFER_HAS_PENDING_COMPLETION':
        return 'يوجد طلب إتمام معلق على هذا العرض — لا يمكن الحجز حالياً.';
      case 'INVALID_APPOINTMENT_TIME':
        return 'التوقيت المختار أصبح في الماضي. اختر وقتاً لاحقاً.';
      case 'NETWORK':
        return 'تعذّر الاتصال بالخادم. تحقق من الشبكة وأعد المحاولة.';
      default:
        return 'تعذّر حجز الموعد. قد يكون الوقت محجوزاً أو يوجد طلب إتمام معلق.';
    }
  }

  Future<void> _confirm() async {
    if (_selectedDayKey == null || _selectedSlot == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار اليوم والفترة والوقت')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final provider = context.read<AppointmentProvider>();
    final userId = auth.userModel?.uid ?? '';

    final result = await provider.bookAppointment(
      userId: userId,
      offerId: widget.offer.id,
      selectedDayKey: _selectedDayKey!,
      selectedTime: _selectedTime!,
      brokerId: widget.offer.brkId.isNotEmpty ? widget.offer.brkId : null,
      requestId: widget.requestId,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      final activeCount = result.activeCount;
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
      // تحديث الأوقات المحجوزة بعد الفشل (قد يكون سببه تعارضاً حديثاً)
      _loadBookedSlots();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(result)),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final days = _availableDays;
    final hasAvailability = widget.offer.avl.isNotEmpty && days.isNotEmpty;
    final media = MediaQuery.of(context);

    // ارتفاع أقصى + تمرير داخلي لمنع الـ Overflow مهما بلغ عدد الأوقات
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            // تنبيه الدور والمكتب
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الحجز يتم عبر إدارة المكتب لضمان الجدية. يرجى ملاحظة أنه قد يكون هناك طلبات أخرى تسبقك في الدور.',
                    style: TextStyle(
                        color: AppTheme.primaryGold, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            if (!hasAvailability)
              const Center(
                child: Text('لا توجد مواعيد متاحة حالياً للمعاينة.',
                    style: TextStyle(color: AppTheme.textGrey)),
              )
            else ...[
              if (_isAnytime) ...[
                Row(children: [
                  const Icon(Icons.event_available,
                      color: AppTheme.primaryGold, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'صاحب العرض جاهز للمعاينة في أي يوم — الدوام من '
                      '${context.read<ConfigProvider>().config?.apptAnyFrom ?? '09:00'}'
                      ' حتى '
                      '${context.read<ConfigProvider>().config?.apptAnyTo ?? '21:00'}',
                      style: const TextStyle(
                          color: AppTheme.textGrey, fontSize: 12, height: 1.4),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
              ],
              const Text('1. اختر اليوم:',
                  style: TextStyle(
                      color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days.map((key) {
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
                        _loadBookedSlots();
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
                  children: _slotsForDay(_selectedDayKey!).map((slot) {
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
                if (_loadingSlots)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: AppTheme.primaryGold),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _generateTimeSlots(_selectedSlot!).map((time) {
                      // قاعدة عدم التعارض: يُحظر الوقت الواقع ضمن أقل من
                      // ساعة من أي موعد نشط على هذا العرض
                      final isBooked = _isBlocked(time);
                      final selected = _selectedTime == time;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isBooked
                            ? null
                            : () => setState(() => _selectedTime = time),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? AppTheme.textGrey.withOpacity(0.1)
                                  : (selected ? AppTheme.primaryGold : AppTheme.surfaceBlack),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBooked
                                    ? AppTheme.textGrey.withOpacity(0.2)
                                    : (selected ? AppTheme.primaryGold : AppTheme.textGrey.withOpacity(0.3)),
                              ),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isBooked
                                    ? AppTheme.textGrey
                                    : (selected ? AppTheme.deepBlack : AppTheme.textWhite),
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                if (_bookedSlots.isNotEmpty && !_loadingSlots) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppTheme.textGrey),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'الأوقات المظللة محجوزة أو ضمن فارق الساعة من موعد آخر',
                          style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_selectedTime != null && !_submitting) ? _confirm : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.deepBlack),
                        )
                      : const Text('تأكيد طلب الموعد',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
