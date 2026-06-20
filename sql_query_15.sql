-- 2026_06_20_fix_rls_no_policy.sql

BEGIN;

-- 1. staff_sessions
-- نحن لا نريد أن يتفاعل المستخدمون العاديون مع هذا الجدول إطلاقاً (كل شيء عبر Edge Functions/RPCs).
-- لذلك نضيف سياسة تمنح صلاحيات كاملة لـ service_role فقط كنوع من التوثيق ولإخفاء التحذير.
CREATE POLICY "service_role_all_staff_sessions" 
ON public.staff_sessions
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- 2. stats
-- هذا الجدول عادة للإحصائيات الداخلية، ولا يجب أن يُقرأ أو يُعدل من العميل مباشرة.
CREATE POLICY "service_role_all_stats" 
ON public.stats
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- 3. user_daily_limits
-- حدود المستخدم اليومية، تتم إدارتها عبر الدوال والـ Triggers، ولا يجوز تعديلها من العميل.
CREATE POLICY "service_role_all_user_daily_limits" 
ON public.user_daily_limits
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

COMMIT;
