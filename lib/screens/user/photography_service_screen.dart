import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../models/photography_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة خدمة التصوير العقاري — للمستخدمين العاديين والوسطاء (ليس للإدارة).
/// تشرح الخدمة بشكل واضح + نموذج طلب تصوير + قائمة بطلبات المستخدم وحالتها.
/// ════════════════════════════════════════════════════════════════════
class PhotographyServiceScreen extends StatefulWidget {
  const PhotographyServiceScreen({super.key});

  @override
  State<PhotographyServiceScreen> createState() =>
      _PhotographyServiceScreenState();
}

class _PhotographyServiceScreenState extends State<PhotographyServiceScreen> {
  List<PhotographyTaskModel> _myRequests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyRequests());
  }

  bool get _hasActiveRequest =>
      _myRequests.any((t) => t.sts == 0 || t.sts == 1 || t.sts == 2);

  Future<void> _loadMyRequests() async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isEmpty) {
      setState(() {
        _loading = false;
        _myRequests = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await SupabaseService().invokeFunction(
        'admin-photography',
        body: {
          'action': 'my_photo_requests',
          'user_uid': uid,
        },
      );
      final data =
          response.data is Map ? Map<String, dynamic>.from(response.data) : null;
      if (!mounted) return;
      if (data != null && data['success'] == true) {
        final list = (data['tasks'] as List? ?? [])
            .map((row) => PhotographyTaskModel.fromSupabase(
                  Map<String, dynamic>.from(row as Map),
                  row['id'].toString(),
                ))
            .toList();
        setState(() {
          _myRequests = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = data?['error']?.toString() ?? 'فشل تحميل الطلبات';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل الطلبات — تحقق من اتصال الإنترنت';
        _loading = false;
      });
    }
  }

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    AppTheme.showSnackBar(
      context,
      SnackBar(
        content: Text(m),
        backgroundColor: ok ? Colors.green : null,
      ),
    );
  }

  // ═══════════════════════════════════════
  // نموذج طلب التصوير
  // ═══════════════════════════════════════
  Future<void> _showRequestForm() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.nm);
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: user.ph);
    final notesCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.camera_alt, color: AppTheme.primaryGold, size: 24),
                  SizedBox(width: 10),
                  Text('طلب تصوير عقار',
                      style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _field(nameCtrl, 'الاسم الثلاثي *', 'مثال: محمد أحمد الخطيب',
                  Icons.person),
              const SizedBox(height: 12),
              _field(descCtrl, 'وصف العقار *', 'مثال: شقة 3 غرف طابق ثاني',
                  Icons.home_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'حدد الموقع بدقة: المدينة ← الحي ← الشارع ← أقرب معلم',
                        style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _field(
                locCtrl,
                'موقع العقار التفصيلي *',
                'مثال: السويداء، حي المطار، شارع المدرسة الثانوية، بجانب صيدلية النور',
                Icons.location_on,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'هاتف التواصل *', 'رقمك للتواصل وتأكيد الموعد',
                  Icons.phone,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(notesCtrl, 'ملاحظات إضافية (اختياري)',
                  'مثال: أفضل وقت بعد الظهر...', Icons.note_alt_outlined,
                  maxLines: 2),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء',
                          style: TextStyle(color: AppTheme.textGrey)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty ||
                            descCtrl.text.trim().isEmpty ||
                            locCtrl.text.trim().isEmpty ||
                            phoneCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold),
                      child: const Text('إرسال الطلب',
                          style: TextStyle(
                              color: AppTheme.deepBlack,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await SupabaseService().invokeFunction(
        'admin-photography',
        body: {
          'action': 'request_photography',
          'user_uid': user.uid,
          'full_name': nameCtrl.text.trim(),
          'property_desc': descCtrl.text.trim(),
          'property_location': locCtrl.text.trim(),
          'contact_phone': phoneCtrl.text.trim(),
          'notes': notesCtrl.text.trim(),
        },
      );
      final data =
          response.data is Map ? Map<String, dynamic>.from(response.data) : null;
      if (!mounted) return;
      if (data != null && data['success'] == true) {
        _snack('✅ تم إرسال طلب التصوير بنجاح', ok: true);
        _loadMyRequests();
      } else {
        final err = data?['error'] ?? 'خطأ غير معروف';
        if (err == 'ACTIVE_PHOTOGRAPHY_REQUEST_EXISTS') {
          _snack('لديك طلب تصوير نشط بالفعل — سيتم التواصل معك قريباً');
        } else {
          _snack('فشل إرسال طلب التصوير: $err');
        }
      }
    } catch (e) {
      _snack('فشل إرسال طلب التصوير — تحقق من الاتصال وحاول مجدداً');
    }
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: AppTheme.primaryGold, size: 20),
      ),
    );
  }

  // ═══════════════════════════════════════
  // الواجهة
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('خدمة التصوير العقاري'),
        backgroundColor: AppTheme.scaffoldBackground,
        foregroundColor: AppTheme.primaryGold,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryGold,
        onRefresh: _loadMyRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── بطاقة شرح الخدمة ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withOpacity(0.18),
                    AppTheme.primaryGold.withOpacity(0.05),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.primaryGold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.photo_camera_front_rounded,
                          color: AppTheme.primaryGold, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'صوّر عقارك باحتراف مع مصور المكتب',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _explainRow(Icons.location_on_outlined,
                      'مصوّر محترف يزور عقارك في الموعد المتفق عليه'),
                  const SizedBox(height: 8),
                  _explainRow(Icons.photo_library_outlined,
                      'التقاط صور وفيديو احترافية للعقار'),
                  const SizedBox(height: 8),
                  _explainRow(Icons.trending_up_rounded,
                      'وسائط عالية الجودة تُنشر في عرضك وتزيد فرص البيع أو الإيجار'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── زر طلب جديد ───
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showRequestForm,
                icon: const Icon(Icons.add_a_photo_outlined,
                    color: AppTheme.deepBlack),
                label: Text(
                  _hasActiveRequest
                      ? 'طلب تصوير جديد (لديك طلب نشط)'
                      : 'طلب تصوير جديد',
                  style: const TextStyle(
                      color: AppTheme.deepBlack,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── طلبات التصوير الخاصة بي ───
            const Row(
              children: [
                Icon(Icons.history, color: AppTheme.primaryGold, size: 18),
                SizedBox(width: 8),
                Text('طلبات التصوير الخاصة بي',
                    style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryGold),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: AppTheme.textGrey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loadMyRequests,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else if (_myRequests.isEmpty)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.no_photography_outlined,
                        size: 44,
                        color: AppTheme.textGrey.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    const Text('ما عندك طلبات تصوير بعد',
                        style: TextStyle(color: AppTheme.textGrey)),
                    const SizedBox(height: 4),
                    const Text('اضغط "طلب تصوير جديد" لطلب أول جلسة تصوير',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              )
            else
              ..._myRequests.map(_requestCard),

            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  Future<void> _cancelRequest(PhotographyTaskModel t) async {
    // شاشة إدخال سبب الإلغاء الإلزامي
    final reasonCtrl = TextEditingController();
    String? validationError;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('إلغاء طلب التصوير',
                  style: TextStyle(color: AppTheme.textWhite, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إلغاء الطلب نهائي ولن تتمكن من استعادته.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء *',
                  hintText: 'مثال: غيرت رأيي، لا أحتاج الخدمة...',
                  errorText: validationError,
                  filled: true,
                  fillColor: AppTheme.deepBlack,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.edit_note,
                      color: AppTheme.primaryGold),
                ),
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع',
                  style: TextStyle(color: AppTheme.textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = reasonCtrl.text.trim();
                if (txt.isEmpty) {
                  setDialogState(
                      () => validationError = 'سبب الإلغاء مطلوب');
                  return;
                }
                Navigator.pop(ctx, txt);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    try {
      final response = await SupabaseService().invokeFunction(
        'admin-photography',
        body: {
          'action': 'cancel_photo_request',
          'user_uid': uid,
          'task_id': t.id,
          'cancel_reason': reason,
        },
      );
      final data =
          response.data is Map ? Map<String, dynamic>.from(response.data) : null;
      if (!mounted) return;
      if (data != null && data['success'] == true) {
        _snack('✅ تم إلغاء طلب التصوير', ok: true);
        _loadMyRequests();
      } else {
        _snack('تعذر الإلغاء — الطلب لم يعد بانتظار');
      }
    } catch (e) {
      _snack('فشل الإلغاء — تحقق من الاتصال وحاول مجدداً');
    }
  }

  Widget _explainRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryGold.withOpacity(0.9), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppTheme.textWhite, fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _requestCard(PhotographyTaskModel t) {
    final (label, color) = _statusInfo(t.sts);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.ttl.isNotEmpty ? t.ttl : 'طلب تصوير عقار',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 13, color: AppTheme.textGrey),
              const SizedBox(width: 4),
              Text(
                'أُرسل: ${_fmtDate(t.tsCrt)}',
                style:
                    const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          if (t.tsScheduled != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_available,
                    size: 13, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'الموعد المجدول: ${_fmtDate(t.tsScheduled!)}',
                  style:
                      const TextStyle(color: Colors.green, fontSize: 11),
                ),
              ],
            ),
          ],
          // الوسائط المعتمدة تظهر للمستخدم بعد اكتمال الجلسة
          if (t.sts == 3 && t.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('وسائط جلسة التصوير:',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
            const SizedBox(height: 6),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: t.media.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      t.media[i],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: AppTheme.deepBlack,
                        child: const Icon(Icons.broken_image,
                            color: AppTheme.textGrey, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // زر الإلغاء — فقط للطلبات المعلّقة (لم يبدأ المصور بعد)
          if (t.sts == 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _cancelRequest(t),
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.red, size: 16),
                label: const Text('إلغاء الطلب',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, Color) _statusInfo(int sts) {
    switch (sts) {
      case 0:
        return ('بانتظار المراجعة', Colors.orange);
      case 1:
        return ('قيد التنفيذ', Colors.blue);
      case 2:
        return ('مرسلة للمكتب', Colors.purple);
      case 3:
        return ('مكتملة', Colors.green);
      case 4:
        return ('مرفوضة', Colors.red);
      case 5:
        return ('ملغاة', Colors.grey);
      default:
        return ('غير معروف', Colors.grey);
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}
