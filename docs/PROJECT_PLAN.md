# 📋 خطة المشروع — عقارات السويداء

> **آخر تحديث:** 2026-06-05  
> **Backend:** Supabase (PostgreSQL + Auth + Realtime + Storage + RPC)  
> **Frontend:** Flutter

---

## 📊 حالة التنفيذ

| المرحلة | الحالة | الشاشات المكتملة | الشاشات المتبقية |
|---|---|---|---|
| ✅ المرحلة 0: الأساس | مكتملة | Splash + Firebase removal + Router | — |
| ✅ المرحلة 1: شاشات المستخدم | **مكتملة** | 8/8 | — |
| ✅ المرحلة 2: لوحة السمسار | **مكتملة** | 4/4 | — |
| ✅ المرحلة 3: لوحة الإدارة | **مكتملة** | 9/9 | — |
| ⏳ المرحلة 4: المنطق الخلفي | لم تبدأ | 0/7 ميزة | 7 |
| ⏳ المرحلة 5: التحسينات | لم تبدأ | 0/6 تحسين | 6 |
| ⏳ المرحلة 6: البناء والنشر | لم تبدأ | 0/4 عنصر | 4 |

**النسبة الإجمالية: ~52% مكتمل**

---

## 📌 المرحلة 1: شاشات المستخدم (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 1.1 | `user_home_screen.dart` | الرئيسية + بحث + فلترة حسب النوع | ✅ |
| 1.2 | `my_requests_screen.dart` | طلباتي + FAB + حالات الطلب | ✅ |
| 1.3 | `my_appointments_screen.dart` | مواعيدي + إلغاء + حالات | ✅ |
| 1.4 | `favorites_screen.dart` | مفضلة (SharedPreferences) | ✅ |
| 1.5 | `profile_screen.dart` | ملف شخصي + بادج + نقاط + إحصائيات | ✅ |
| 1.6 | `settings_screen.dart` | إعدادات إشعارات + خروج | ✅ |
| 1.7 | `add_request_screen.dart` | نموذج Stepper 3 خطوات | ✅ |
| 1.8 | `bottom_nav_bar.dart` | BottomNavigationBar 5 أيقونات | ✅ |

---

## 📌 المرحلة 2: لوحة السمسار (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 2.1 | `broker_dashboard_screen.dart` | إحصائيات سريعة (4 بطاقات) + تنقّل للأقسام | ✅ |
| 2.2 | `broker_offers_screen.dart` | عروض السمسار (خاصة + مُسندة) + فلترة بالحالة | ✅ |
| 2.3 | `broker_deals_screen.dart` | الصفقات النشطة/المكتملة + ملخّص العمولات | ✅ |
| 2.4 | `broker_stats_screen.dart` | إحصائيات تفصيلية + أشرطة نسب (بدون مكتبات) | ✅ |

> **`BrokerProvider`** موسّع بـ: `fetchBrokerStats` · `fetchBrokerOffers` · `fetchBrokerDeals` · `fetchBrokerAppointments` · `handleAppointment` · `completeAppointment`.  
> **الدخول:** أزرار "لوحة الوسيط" و"لوحة الإدارة" في `profile_screen.dart` (تظهر حسب الدور).

---

## 📌 المرحلة 3: لوحة الإدارة (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 3.1 | `admin_dashboard_screen.dart` | لوحة رئيسية + إحصائيات + عدّادات إجراءات | ✅ |
| 3.2 | `users_management_screen.dart` | بحث + حظر/تجميد/تفعيل + تغيير الدور | ✅ |
| 3.3 | `appointments_management_screen.dart` | كل المواعيد + فلترة + فرض/إكمال/إلغاء | ✅ |
| 3.4 | `deals_management_screen.dart` | صفقات + إتمام + تسجيل العمولة | ✅ |
| 3.5 | `payments_screen.dart` | موافقة/رفض + تفعيل الباقة + إثبات الدفع | ✅ |
| 3.6 | `reports_screen.dart` | تبليغات + إجراء (تحذير/تجميد/حظر) | ✅ |
| 3.7 | `config_editor_screen.dart` | تعديل النقاط/العمولة/الحصص (دمج آمن) | ✅ |
| 3.8 | `analytics_screen.dart` | إحصائيات شاملة + أشرطة نسب | ✅ |

> **`AdminProvider`** موسّع: `getAllUsers/setUserStatus/ban/freeze/activate/updateUserRole/softDeleteUser` · `getAllAppointments/updateAppointmentStatus/forceAppointment` · `getAllDeals/createDeal/completeDeal` · `getAllPayments/approvePayment/rejectPayment` · `getAllReports/handleReport` · `getStats/getActionCounts`.

---

## 📌 المرحلة 4: المنطق الخلفي

| # | العنصر | التفاصيل |
|---|---|---|
| 4.1 | Config Loading | تحميل من app_config + Hive cache |
| 4.2 | المطابقة التلقائية | RPC: ربط الطلبات بالعروض |
| 4.3 | نظام النقاط | RPC: add_points + update_user_badge |
| 4.4 | نظام الباقات | مجاني/فضي/ذهبي + حدود |
| 4.5 | Streak System | تسجيل يومي متتالي |
| 4.6 | Social Media | توليد نص المنشور |
| 4.7 | رفع الصور | Supabase Storage + ضغط |

---

## 📌 المرحلة 5: التحسينات

| # | العنصر | التفاصيل |
|---|---|---|
| 5.1 | Realtime | Supabase stream |
| 5.2 | Push Notifications | FCM |
| 5.3 | Offline | Hive caching |
| 5.4 | Error Handling | معالجة أخطاء |
| 5.5 | Loading | Shimmer animations |
| 5.6 | Splash Polish | Progress bar + native |

---

## 📌 المرحلة 6: البناء والنشر

| # | العنصر |
|---|---|
| 6.1 | Android APK + Bundle |
| 6.2 | iOS IPA + TestFlight |
| 6.3 | Security Review |
| 6.4 | Testing شامل |

---

## 📈 ملخص

- **الشاشات المكتملة:** 28/39 (المستخدم 8 · السمسار 5 · الإدارة 9 + أساسيات)
- **الميزات المكتملة:** 0/7
- **التحسينات المكتملة:** 0/6
- **إجمالي التقدم:** ~52%
