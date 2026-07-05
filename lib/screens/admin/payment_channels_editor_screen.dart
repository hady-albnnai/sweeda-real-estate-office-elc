import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/config_provider.dart';
import '../../services/storage_service.dart';

/// 💳 محرّر قنوات الدفع — المرحلة 11 (Config-Driven)
///
/// يقرأ `config.payChannels` ويسمح بـ:
///   - تفعيل/تعطيل كل قناة
///   - تعديل البيانات (اسم المستقبل، رقم الحساب...)
///   - رفع صورة QR لشام كاش إلى bucket `config_assets`
///   - تعديل نص التعليمات
class PaymentChannelsEditorScreen extends StatefulWidget {
  const PaymentChannelsEditorScreen({super.key});

  @override
  State<PaymentChannelsEditorScreen> createState() =>
      _PaymentChannelsEditorScreenState();
}

class _PaymentChannelsEditorScreenState
    extends State<PaymentChannelsEditorScreen> {
  bool _saving = false;
  Map<String, Map<String, dynamic>> _channels = {};
  Map<String, Map<String, TextEditingController>> _controllers = {};
  Map<String, bool> _enabled = {};

  final _storage = StorageService();

  /// الحقول لكل قناة (ما عدا enabled, name, icon, instructions)
  static const Map<String, List<String>> _channelFields = {
    'haram': ['recipient_name', 'recipient_phone'],
    'sham_cash': ['account_number'], // qr_image_url منفصل
    'balance': ['syriatel_number', 'mtn_number'],
    'bank': [
      'bank_name',
      'account_holder',
      'account_number',
      'iban',
      'branch',
    ],
  };

  static const Map<String, String> _fieldLabels = {
    'recipient_name': 'اسم المستقبل (ثلاثي)',
    'recipient_phone': 'رقم هاتف المستقبل',
    'account_number': 'رقم الحساب',
    'syriatel_number': 'رقم سيرياتل',
    'mtn_number': 'رقم MTN',
    'bank_name': 'اسم البنك',
    'account_holder': 'اسم صاحب الحساب',
    'iban': 'IBAN',
    'branch': 'الفرع',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<ConfigProvider>();
    if (prov.config == null) await prov.loadConfig();
    final pay = prov.config?.payChannels ?? {};

    _disposeControllers();
    _channels = {};
    _controllers = {};
    _enabled = {};

    for (final key in ['haram', 'sham_cash', 'balance', 'bank']) {
      final data =
          Map<String, dynamic>.from(pay[key] ?? <String, dynamic>{});
      _channels[key] = data;
      _enabled[key] = data['enabled'] == true;

      final ctrls = <String, TextEditingController>{};
      for (final f in _channelFields[key] ?? <String>[]) {
        ctrls[f] = TextEditingController(text: (data[f] ?? '').toString());
      }
      ctrls['instructions'] =
          TextEditingController(text: (data['instructions'] ?? '').toString());
      // qr_image_url لشام كاش — حقل خاص (للعرض والتعديل اليدوي إن لزم)
      if (key == 'sham_cash') {
        ctrls['qr_image_url'] = TextEditingController(
            text: (data['qr_image_url'] ?? '').toString());
      }
      _controllers[key] = ctrls;
    }

    if (mounted) setState(() {});
  }

  void _disposeControllers() {
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _uploadShamCashQR() async {
    final XFile? file = await _storage.pickImage(fromCamera: false);
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final storage = SupabaseService().storage;
      final fileName = 'sham_cash_qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'payment_channels/$fileName';

      final bytes = kIsWeb
          ? await file.readAsBytes()
          : await (await _storage.compressImage(File(file.path)) ??
                  File(file.path))
              .readAsBytes();

      await storage.from(StorageService.configAssetsBucket).uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: true),
          );
      final url =
          storage.from(StorageService.configAssetsBucket).getPublicUrl(path);

      setState(() {
        _controllers['sham_cash']!['qr_image_url']!.text = url;
        _saving = false;
      });
      _snack('✅ تم رفع QR بنجاح');
    } catch (e) {
      setState(() => _saving = false);
      _snack('❌ فشل الرفع: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prov = context.read<ConfigProvider>();
    final current = Map<String, dynamic>.from(prov.config?.data ?? {});
    final payChannels =
        Map<String, dynamic>.from(current['payChannels'] ?? {});

    for (final key in ['haram', 'sham_cash', 'balance', 'bank']) {
      final existing =
          Map<String, dynamic>.from(payChannels[key] ?? _channels[key] ?? {});
      existing['enabled'] = _enabled[key] ?? true;
      // نُبقي name و icon كما هي (للعرض)
      final ctrls = _controllers[key] ?? {};
      for (final entry in ctrls.entries) {
        existing[entry.key] = entry.value.text.trim();
      }
      payChannels[key] = existing;
    }
    current['payChannels'] = payChannels;

    final ok = await prov.updateConfig(current);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(ok ? '✅ تم حفظ قنوات الدفع' : '❌ فشل الحفظ');
  }

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('💳 قنوات الدفع'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _channels.isEmpty
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryGold))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _infoBanner(),
                    const SizedBox(height: 16),
                    for (final key in ['haram', 'sham_cash', 'balance', 'bank'])
                      _channelCard(key),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.deepBlack))
                            : const Icon(Icons.save),
                        label: Text(_saving
                            ? 'جارٍ الحفظ...'
                            : 'حفظ جميع التغييرات'),
                        style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
                if (_saving)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryGold),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _infoBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.lightBlueAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'هذه القنوات تظهر للمستخدمين في شاشة الدفع.\nالقنوات المعطّلة لا تظهر، والحقول الفارغة تخفى تلقائياً.',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _channelCard(String key) {
    final data = _channels[key] ?? {};
    final ctrls = _controllers[key] ?? {};
    final icon = (data['icon'] ?? '💳').toString();
    final name = (data['name'] ?? key).toString();
    final enabled = _enabled[key] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? AppTheme.primaryGold.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Switch(
                value: enabled,
                activeColor: AppTheme.primaryGold,
                onChanged: (v) => setState(() => _enabled[key] = v),
              ),
            ],
          ),
          const Divider(color: AppTheme.textGrey, height: 18),

          // حقول القناة العامة
          for (final f in _channelFields[key] ?? <String>[])
            _textField(_fieldLabels[f] ?? f, ctrls[f]!),

          // QR لشام كاش
          if (key == 'sham_cash') ...[
            _textField('رابط QR (يدوي)', ctrls['qr_image_url']!),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadShamCashQR,
                    icon: const Icon(Icons.qr_code,
                        color: AppTheme.primaryGold),
                    label: const Text('رفع صورة QR',
                        style: TextStyle(color: AppTheme.primaryGold)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppTheme.primaryGold)),
                  ),
                ),
              ],
            ),
            if ((ctrls['qr_image_url']!.text).isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    ctrls['qr_image_url']!.text,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('فشل تحميل',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 10),

          // التعليمات
          _textField('التعليمات (يدعم الأسطر المتعددة)',
              ctrls['instructions']!,
              maxLines: 3),
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textWhite),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.deepBlack,
          labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
        ),
      ),
    );
  }
}
