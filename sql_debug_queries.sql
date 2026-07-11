-- ═══════════════════════════════════════════════════════════════
-- استعلامات فحص لإصلاح مشاكل التطبيق
-- شغّلها واحدة واحدة في SQL Editor في Supabase
-- ═══════════════════════════════════════════════════════════════

-- ━━━ 1. فحص create_offer_internal — هل حقل imgs موجود في INSERT؟ ━━━
-- إذا imgs غير موجود في الـ INSERT، فهذا سبب عدم وصول الصور للإدارة
SELECT routine_definition
FROM information_schema.routines
WHERE routine_name = 'create_offer_internal'
  AND routine_schema = 'public';

-- ━━━ 2. فحص عروض بدون صور (i_pub=0 يعني بانتظار المراجعة) ━━━
SELECT id, usr_id, ttl, imgs, doc_img, i_pub, ts_crt
FROM offers
WHERE i_pub = 0 AND i_del = 0
ORDER BY ts_crt DESC
LIMIT 10;

-- ━━━ 3. فحص طلبات التوثيق المعلقة ━━━
SELECT id, nm, ph, sid, img, vrf, role
FROM users
WHERE vrf = 1 AND i_del = 0;

-- ━━━ 4. فحص RPC admin_approve_verification_by_admin — هل موجودة؟ ━━━
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_name = 'admin_approve_verification_by_admin'
  AND routine_schema = 'public';

-- ━━━ 5. فحص طلبات المستخدم التي يجب أن تصل للإدارة ━━━
SELECT id, usr_id, typ, elm, cl_nm, sts, ts_crt
FROM requests
ORDER BY ts_crt DESC
LIMIT 10;

-- ━━━ 6. فحص RPC get_admin_requests_internal — هل ترجع الطلبات؟ ━━━
SELECT routine_definition
FROM information_schema.routines
WHERE routine_name = 'get_admin_requests_internal'
  AND routine_schema = 'public';

-- ━━━ 7. فحص bucket ids_private — هل الصور مرفوعة فعلاً؟ ━━━
SELECT id, name, (select count(*) from storage.objects where bucket_id = 'ids_private') as object_count
FROM storage.buckets
WHERE id = 'ids_private';
