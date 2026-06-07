import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/admin_provider.dart';
import '../../models/user_model.dart';
import '../../models/offer_model.dart';
import '../../models/appointment_model.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

/// شاشة تفاصيل المستخدم للإدارة
/// تعرض: بياناته + إحصائياته + عروضه + مواعيده + التبليغات عليه + إجراءات سريعة
class UserDetailsScreen extends StatefulWidget {
  final String userId;
  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  List<OfferModel> _offers = [];
  List<AppointmentModel> _appointments = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _activity = [];
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sb = SupabaseService().client;
    try {
      // المستخدم
      final userData = await sb
          .from(DbTables.users)
          .select()
          .eq('id', widget.userId)
          .maybeSingle();
      if (userData == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _user = UserModel.fromSupabase(
          Map<String, dynamic>.from(userData), widget.userId);

      // العروض
      final offData = await sb
          .from(DbTables.offers)
          .select()
          .eq('usr_id', widget.userId)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);
      _offers = (offData as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();

      // المواعيد (own_id = صاحب العرض)
      final appData = await sb
          .from(DbTables.appointments)
          .select()
          .or('own_id.eq.${widget.userId},req_id.eq.${widget.userId}')
          .order('ts_crt', ascending: false)
          .limit(50);
      _appointments = (appData as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();

      // التبليغات عليه
      final repData = await sb
          .from(DbTables.reports)
          .select()
          .eq('tgt_uid', widget.userId)
          .order('ts_crt', ascending: false);
      _reports = (repData as List)
          .map((d) => Map<String, dynamic>.from(d))
          .toList();

      // النشاط
      final actData = await sb
          .from(DbTables.activityLog)
          .select()
          .eq('uid', widget.userId)
          .order('ts_crt', ascending: false)
          .limit(30);
      _activity = (actData as List)
          .map((d) => Map<String, dynamic>.from(d))
          .toList();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ load user details: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callUser() async {
    if (_user == null || _user!.ph.isEmpty) return;
    final uri = Uri.parse('tel:${_user!.ph}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsappUser() async {
    if (_user == null || _user!.ph.isEmpty) return;
    final clean = _user!.ph.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _changeStatus(int status) async {
    final admin = context.read<AdminProvider>();
    String? reason;
    if (status != 0) {
      final ctrl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: Text(
            status == 1 ? 'تجميد الحساب' : 'حظر الحساب',
            style: const TextStyle(color: AppTheme.textWhite),
          ),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(hintText: 'السبب'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppTheme.textGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (reason == null) return;
    }

    final ok = await admin.setUserStatus(
      widget.userId,
      status,
      reason: reason ?? '',
    );
    if (ok && mounted) {
      _snack('✅ تم تحديث الحالة');
      _load();
    }
  }

  Future<void> _changeRole(int newRole) async {
    final admin = context.read<AdminProvider>();
    final ok = await admin.updateUserRole(widget.userId, newRole);
    if (ok && mounted) {
      _snack('✅ تم تحديث الدور');
      _load();
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    if (_user == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepBlack,
        appBar: AppBar(title: const Text('تفاصيل المستخدم')),
        body: const Center(
            child: Text('المستخدم غير موجود',
                style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceBlack,
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _header(),
            ),
            bottom: TabBar(
              controller: _tab,
              isScrollable: true,
              indicatorColor: AppTheme.primaryGold,
              labelColor: AppTheme.primaryGold,
              unselectedLabelColor: AppTheme.textGrey,
              tabs: [
                Tab(text: 'العروض (${_offers.length})'),
                Tab(text: 'المواعيد (${_appointments.length})'),
                Tab(text: 'التبليغات (${_reports.length})'),
                Tab(text: 'النشاط (${_activity.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _offersTab(),
            _appointmentsTab(),
            _reportsTab(),
            _activityTab(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final u = _user!;
    final statusInfo = _statusInfo(u.sts);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryGold,
                backgroundImage: u.img.isNotEmpty
                    ? NetworkImage(u.img) as ImageProvider
                    : null,
                child: u.img.isEmpty
                    ? Text(
                        u.nm.isNotEmpty ? u.nm[0].toUpperCase() : '؟',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.nm.isEmpty ? 'مستخدم بدون اسم' : u.nm,
                      style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(u.ph,
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 13)),
                    if (u.eml?.isNotEmpty == true)
                      Text(u.eml!,
                          style: const TextStyle(
                              color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              ),
              if (u.ph.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: _callUser,
                ),
                IconButton(
                  icon: const Icon(Icons.chat, color: AppTheme.primaryGold),
                  onPressed: _whatsappUser,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(u.roleName, Colors.blue),
            _chip(u.badgeName, AppTheme.primaryGold),
            _chip(statusInfo.$1, statusInfo.$2),
            _chip('${u.pt} نقطة', Colors.purple),
            if (u.isBroker) _chip('وسيط مفعّل', Colors.green),
            // 🛡️ حالة التوثيق الرسمي (LOGIC_SPEC §2.1)
            if (u.isVerifiedOfficial)
              _chip('✓ موثق رسمياً', Colors.green)
            else if (u.vrf == 1)
              _chip('⏳ توثيق قيد المراجعة', Colors.orange)
            else
              _chip('غير موثق', Colors.grey),
          ]),
          const SizedBox(height: 10),
          _quickActions(),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final u = _user!;
    return Row(children: [
      if (u.sts == 0) ...[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _changeStatus(1),
            icon: const Icon(Icons.pause_circle, color: Colors.orange, size: 14),
            label: const Text('تجميد',
                style: TextStyle(color: Colors.orange, fontSize: 11)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _changeStatus(2),
            icon: const Icon(Icons.block, color: Colors.red, size: 14),
            label: const Text('حظر',
                style: TextStyle(color: Colors.red, fontSize: 11)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ] else
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _changeStatus(0),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 14),
            label: const Text('تفعيل',
                style: TextStyle(color: Colors.green, fontSize: 11)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      const SizedBox(width: 6),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _showRoleDialog(),
          icon: const Icon(Icons.swap_horiz,
              color: AppTheme.primaryGold, size: 14),
          label: const Text('الدور',
              style: TextStyle(color: AppTheme.primaryGold, fontSize: 11)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primaryGold),
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    ]);
  }

  void _showRoleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تغيير الدور',
            style: TextStyle(color: AppTheme.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            const names = ['مستخدم', 'وسيط', 'مشرف', 'نائب', 'مدير'];
            return ListTile(
              leading: const Icon(Icons.person, color: AppTheme.primaryGold),
              title: Text(names[i],
                  style: const TextStyle(color: AppTheme.textWhite)),
              selected: _user!.role == i,
              onTap: () {
                Navigator.pop(context);
                _changeRole(i);
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _offersTab() {
    if (_offers.isEmpty) {
      return const Center(
          child: Text('لا توجد عروض',
              style: TextStyle(color: AppTheme.textGrey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _offers.length,
      itemBuilder: (_, i) {
        final o = _offers[i];
        return Card(
          color: AppTheme.surfaceBlack,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: o.imgs.isNotEmpty
                    ? Image.network(o.imgs.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.image, color: AppTheme.textGrey))
                    : const Icon(Icons.image, color: AppTheme.textGrey),
              ),
            ),
            title: Text(o.ttl,
                style: const TextStyle(color: AppTheme.textWhite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'} • ${_offerStatusText(o.sts)}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_left, color: AppTheme.primaryGold),
            onTap: () => context.push('/offer/${o.id}'),
          ),
        );
      },
    );
  }

  Widget _appointmentsTab() {
    if (_appointments.isEmpty) {
      return const Center(
          child: Text('لا توجد مواعيد',
              style: TextStyle(color: AppTheme.textGrey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _appointments.length,
      itemBuilder: (_, i) {
        final a = _appointments[i];
        return Card(
          color: AppTheme.surfaceBlack,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.event, color: AppTheme.primaryGold),
            title: Text('موعد #${a.id.substring(0, 6)}',
                style: const TextStyle(color: AppTheme.textWhite)),
            subtitle: Text(
              '${a.dt.year}/${a.dt.month}/${a.dt.day} ${a.dt.hour}:${a.dt.minute.toString().padLeft(2, '0')} • ${_apptStatusText(a.sts)}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ),
        );
      },
    );
  }

  Widget _reportsTab() {
    if (_reports.isEmpty) {
      return const Center(
          child: Text('لا توجد تبليغات عليه ✅',
              style: TextStyle(color: Colors.green)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reports.length,
      itemBuilder: (_, i) {
        final r = _reports[i];
        return Card(
          color: Colors.red.withValues(alpha: 0.1),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.flag, color: Colors.red),
            title: Text('تبليغ #${r['id'].toString().substring(0, 6)}',
                style: const TextStyle(color: AppTheme.textWhite)),
            subtitle: Text(
              '${r['det'] ?? 'بدون تفاصيل'}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              AppUtils.formatTimestamp(r['ts_crt']),
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _activityTab() {
    if (_activity.isEmpty) {
      return const Center(
          child: Text('لا نشاط حديث',
              style: TextStyle(color: AppTheme.textGrey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activity.length,
      itemBuilder: (_, i) {
        final a = _activity[i];
        return Card(
          color: AppTheme.surfaceBlack,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: const Icon(Icons.history, color: AppTheme.primaryGold, size: 18),
            title: Text(a['action']?.toString() ?? '—',
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 13)),
            subtitle: Text(
              AppUtils.formatTimestamp(a['ts_crt']),
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  (String, Color) _statusInfo(int s) {
    switch (s) {
      case 0:
        return ('نشط', Colors.green);
      case 1:
        return ('مجمّد', Colors.orange);
      case 2:
        return ('محظور', Colors.red);
      default:
        return ('غير معروف', Colors.grey);
    }
  }

  String _offerStatusText(int s) {
    const m = {
      0: 'مسودة',
      1: 'قيد المراجعة',
      2: 'منشور',
      3: 'مرفوض',
      4: 'منتهي',
      5: 'محجوز',
      6: 'مكتمل',
    };
    return m[s] ?? 'غير معروف';
  }

  String _apptStatusText(int s) {
    const m = {
      0: 'قيد الانتظار',
      1: 'مقبول',
      2: 'مرفوض',
      3: 'مكتمل',
      4: 'ملغي',
      5: 'لم يحضر',
    };
    return m[s] ?? 'غير معروف';
  }
}
