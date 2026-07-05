import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/rating_dialog.dart';
import '../../core/utils/app_utils.dart';
import '../../models/appointment_model.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<AppointmentModel> _myAppts = [];    // مواعيد حجزتها أنا
  List<AppointmentModel> _ownerAppts = []; // مواعيد على عروضي
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    final prov = context.read<AppointmentProvider>();
    final results = await Future.wait([
      prov.fetchMyAppointments(uid).then((_) => prov.myAppointments.toList()),
      prov.fetchAppointmentsForMyOffers(uid),
    ]);
    if (mounted) {
      setState(() {
        _myAppts    = results[0];
        _ownerAppts = results[1];
        _loading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text('المواعيد',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textGrey,
          tabs: [
            Tab(text: 'مواعيدي (${_myAppts.length})'),
            Tab(text: 'على عروضي (${_ownerAppts.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : TabBarView(
              controller: _tab,
              children: [
                _buildMyList(),
                _buildOwnerList(),
              ],
            ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }

  // ─────────────────────────────────────
  // تبويب 1: مواعيد حجزتها أنا
  // ─────────────────────────────────────
  Widget _buildMyList() {
    if (_myAppts.isEmpty) return _emptyState('ما عندك مواعيد محجوزة حالياً');
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _myAppts.length,
        itemBuilder: (_, i) => _myApptCard(_myAppts[i]),
      ),
    );
  }

  Widget _myApptCard(AppointmentModel appt) {
    final sts = appt.sts;
    final statusColors = {
      0: Colors.orange, 1: Colors.blue, 2: Colors.green,
      3: Colors.red, 4: Colors.redAccent, 5: Colors.deepOrange,
    };
    final statusTexts = {
      0: 'قيد الانتظار', 1: 'مؤكد', 2: 'منتهي',
      3: 'ملغي', 4: 'مرفوض', 5: 'لم يتم الحضور',
    };

    // هل هناك وقت بديل مقترح من صاحب العرض بانتظار ردي؟
    final pendingCounter = sts == 0 &&
        appt.lastProposedBy == 'owner' &&
        appt.lastProposedDt != null;

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.event, color: AppTheme.primaryGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'معاينة عرض #${appt.offId.length >= 8 ? appt.offId.substring(0, 8) : appt.offId}',
                  style: TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (statusColors[sts] ?? Colors.grey).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusTexts[sts] ?? '—',
                  style: TextStyle(
                      color: statusColors[sts] ?? Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const Divider(color: Colors.white12, height: 20),
            Row(children: [
              Icon(Icons.calendar_today, size: 15, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(AppUtils.formatTimestamp(appt.dt),
                  style: TextStyle(color: AppTheme.textGrey)),
            ]),

            // وقت بديل مقترح من صاحب العرض
            if (pendingCounter) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔄 اقترح صاحب العرض وقتاً بديلاً:',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      AppUtils.formatTimestamp(appt.lastProposedDt!),
                      style: TextStyle(
                          color: AppTheme.textWhite, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _requesterAccept(appt),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text('✅ قبول'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _requesterCounter(appt),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange)),
                          child: const Text('🔄 وقت آخر',
                              style: TextStyle(color: Colors.orange)),
                        ),
                      ),
                    ]),
                    if (appt.neogMaxReached)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('⚠️ آخر جولة — بعدها يُلغى تلقائياً',
                            style: TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],

            // إلغاء (للمواعيد المعلقة والمؤكدة)
            if (sts <= 1 && !pendingCounter) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(appt),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  label: const Text('إلغاء الموعد',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                ),
              ),
            ],

            // تقييم للموعد المنتهي
            if (sts == 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => RatingDialog.show(
                    context: context,
                    targetUid: appt.ownId,
                    targetName: 'مالك العرض',
                    refLabel: 'بعد موعد المعاينة',
                  ),
                  icon: const Icon(Icons.star_rate, color: AppTheme.deepBlack),
                  label: const Text('تقييم تجربتك ⭐',
                      style: TextStyle(
                          color: AppTheme.deepBlack,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // تبويب 2: مواعيد على عروضي
  // ─────────────────────────────────────
  Widget _buildOwnerList() {
    if (_ownerAppts.isEmpty) {
      return _emptyState('لا توجد طلبات حجز على عروضك حالياً');
    }
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _ownerAppts.length,
        itemBuilder: (_, i) => _ownerApptCard(_ownerAppts[i]),
      ),
    );
  }

  Widget _ownerApptCard(AppointmentModel appt) {
    final sts = appt.sts;
    final isPending = sts == 0;

    // هل الدور الآن على صاحب العرض للرد؟
    final myTurn = isPending &&
        (appt.lastProposedBy == null || appt.lastProposedBy == 'requester');

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: myTurn
              ? AppTheme.primaryGold.withOpacity(0.6)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(children: [
              const Icon(Icons.event_available,
                  color: AppTheme.primaryGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'طلب موعد على عرض #${appt.offId.length >= 8 ? appt.offId.substring(0, 8) : appt.offId}',
                  style: TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              _statusBadge(sts),
            ]),
            const Divider(color: Colors.white12, height: 18),

            // التاريخ
            Row(children: [
              Icon(Icons.calendar_today,
                  size: 15, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(AppUtils.formatTimestamp(appt.dt),
                  style: TextStyle(color: AppTheme.textGrey)),
            ]),

            // تاريخ التراشق
            if (appt.neogRounds > 0) ...[
              const SizedBox(height: 6),
              Text(
                'جولة التفاوض: ${appt.neogRounds}/5',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],

            const SizedBox(height: 14),

            // بطاقة الطلب — بدون أي معلومة عن الطالب
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.deepBlack,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryGold.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يوجد طلب حجز موعد بتاريخ:\n${AppUtils.formatTimestamp(appt.dt)}',
                    style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(لا تظهر معلومات الطالب — التواصل عبر المكتب)',
                    style: TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            // أزرار الرد (فقط إذا الدور على صاحب العرض)
            if (myTurn) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _ownerAccept(appt),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    child: const Text('✅ موافقة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _ownerReject(appt),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                    child: const Text('❌ رفض',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ]),
            ],

            // بانتظار رد الطالب
            if (isPending && appt.lastProposedBy == 'owner') ...[
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                SizedBox(width: 6),
                Text('بانتظار رد طالب الموعد على وقتك البديل',
                    style: TextStyle(color: Colors.orange, fontSize: 13)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // إجراءات صاحب العرض
  // ─────────────────────────────────────

  /// رسالة فشل التفاوض حسب رمز الخطأ من السيرفر (LOGIC_SPEC §7)
  String _negotiationError(BookingResult result) {
    switch (result.errorCode) {
      case 'NO_SUPERVISOR_AVAILABLE':
        if (result.suggestedDt != null) {
          final s = AppUtils.formatTimestamp(
            result.suggestedDt,
            pattern: 'yyyy/MM/dd — HH:mm',
          );
          return 'لا يوجد مشرف متاح للوقت المقترح.\nأقرب وقت متاح: $s — اقترحه أو اختر وقتاً آخر.';
        }
        return 'لا يوجد مشرف متاح للوقت المقترح حالياً. اقترح وقتاً آخر.';
      case 'TIME_CONFLICT_ON_OFFER':
        return 'يوجد موعد آخر على هذا العرض قريب من الوقت المقترح — يجب فارق ساعة على الأقل. اقترح وقتاً آخر.';
      case 'INVALID_APPOINTMENT_TIME':
        return 'الوقت المقترح أصبح في الماضي. اختر وقتاً لاحقاً.';
      case 'NETWORK':
        return 'تعذّر الاتصال بالخادم. تحقق من الشبكة وأعد المحاولة.';
      default:
        return 'حدث خطأ، حاول مجدداً';
    }
  }

  Future<void> _ownerAccept(AppointmentModel appt) async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final result = await context.read<AppointmentProvider>()
        .ownerRespondAppointment(
          ownerUid: uid,
          appointmentId: appt.id,
          accept: true,
        );
    if (!mounted) return;
    if (result.success) {
      _snack('✅ تمت الموافقة على الموعد');
      _load();
    } else {
      _snack(_negotiationError(result));
    }
  }

  Future<void> _ownerReject(AppointmentModel appt) async {
    int? reason;
    final textCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: Text('سبب الرفض',
              style: TextStyle(color: AppTheme.textWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                value: 0,
                groupValue: reason,
                onChanged: (v) => setS(() => reason = v),
                title: Text('الوقت لا يناسبني',
                    style: TextStyle(color: AppTheme.textWhite)),
                activeColor: AppTheme.primaryGold,
              ),
              RadioListTile<int>(
                value: 1,
                groupValue: reason,
                onChanged: (v) => setS(() => reason = v),
                title: Text('لم أعد مهتماً بالبيع/الإيجار',
                    style: TextStyle(color: AppTheme.textWhite)),
                activeColor: AppTheme.primaryGold,
              ),
              RadioListTile<int>(
                value: 2,
                groupValue: reason,
                onChanged: (v) => setS(() => reason = v),
                title: Text('آخر',
                    style: TextStyle(color: AppTheme.textWhite)),
                activeColor: AppTheme.primaryGold,
              ),
              if (reason == 2) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  style: TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'اكتب السبب...',
                    hintStyle: TextStyle(color: AppTheme.textGrey),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: TextStyle(color: AppTheme.textGrey)),
            ),
            ElevatedButton(
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || reason == null || !mounted) return;

    // إذا الوقت لا يناسب → نطلب وقتاً بديلاً
    if (reason == 0) {
      await _ownerProposeTime(appt, rejectReason: 0);
      return;
    }

    // إذا غير مهتم → تأكيد مزدوج
    if (reason == 1) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: Text('تأكيد إزالة العرض',
              style: TextStyle(color: AppTheme.textWhite)),
          content: Text(
            'سيتم إزالة عرضك تلقائياً عند الرفض بهذا السبب. هل أنت متأكد؟',
            style: TextStyle(color: AppTheme.textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('لا', style: TextStyle(color: AppTheme.textGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('نعم، إزالة العرض'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }

    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final result = await context.read<AppointmentProvider>()
        .ownerRespondAppointment(
          ownerUid: uid,
          appointmentId: appt.id,
          accept: false,
          rejectReason: reason!,
          rejectText: reason == 2 ? textCtrl.text.trim() : '',
        );
    if (!mounted) return;
    if (result.success) {
      _snack(reason == 1 ? 'تم الرفض وإزالة العرض' : 'تم إرسال الرفض');
      _load();
    } else {
      _snack(_negotiationError(result));
    }
  }

  Future<void> _ownerProposeTime(AppointmentModel appt,
      {int rejectReason = 0}) async {
    final proposed = await _pickDateTime();
    if (proposed == null || !mounted) return;

    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final result = await context.read<AppointmentProvider>()
        .ownerRespondAppointment(
          ownerUid: uid,
          appointmentId: appt.id,
          accept: false,
          rejectReason: rejectReason,
          proposedDt: proposed,
        );
    if (!mounted) return;
    if (result.success) {
      _snack('🔄 تم إرسال الوقت البديل لطالب الموعد');
      _load();
    } else {
      _snack(_negotiationError(result));
    }
  }

  // ─────────────────────────────────────
  // إجراءات طالب الحجز (تبويب 1)
  // ─────────────────────────────────────

  Future<void> _requesterAccept(AppointmentModel appt) async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final result = await context.read<AppointmentProvider>()
        .requesterCounterAppointment(
          userUid: uid,
          appointmentId: appt.id,
          accept: true,
        );
    if (!mounted) return;
    if (result.success) {
      _snack('✅ تم قبول الوقت البديل — الموعد مؤكد');
      _load();
    } else {
      _snack(_negotiationError(result));
    }
  }

  Future<void> _requesterCounter(AppointmentModel appt) async {
    final proposed = await _pickDateTime();
    if (proposed == null || !mounted) return;

    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final result = await context.read<AppointmentProvider>()
        .requesterCounterAppointment(
          userUid: uid,
          appointmentId: appt.id,
          accept: false,
          proposedDt: proposed,
        );
    if (!mounted) return;
    if (result.success) {
      _snack('🔄 تم إرسال وقتك البديل لصاحب العرض');
      _load();
    } else {
      _snack(_negotiationError(result));
    }
  }

  // ─────────────────────────────────────
  // مساعدات
  // ─────────────────────────────────────

  Future<DateTime?> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'اختر التاريخ',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'اختر الوقت',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showCancelDialog(AppointmentModel appt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('إلغاء الموعد',
            style: TextStyle(color: AppTheme.textWhite)),
        content: Text('هل أنت متأكد من إلغاء هذا الموعد؟',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('لا',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              final uid =
                  context.read<AuthProvider>().userModel?.uid ?? '';
              await context.read<AppointmentProvider>()
                  .cancelAppointment(appt.id, uid, 'إلغاء من المستخدم');
              Navigator.pop(ctx);
              _snack('تم إلغاء الموعد');
              _load();
            },
            child: const Text('نعم، إلغاء',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(int sts) {
    final colors = {
      0: Colors.orange, 1: Colors.green, 2: Colors.teal,
      3: Colors.grey, 4: Colors.red, 5: Colors.deepOrange,
    };
    final texts = {
      0: 'انتظار', 1: 'مؤكد', 2: 'مكتمل',
      3: 'ملغي', 4: 'مرفوض', 5: 'لم يحضر',
    };
    final color = colors[sts] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(texts[sts] ?? '—',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 80,
                color: AppTheme.textGrey.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(msg,
                style:
                    TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          ],
        ),
      );

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }
}
