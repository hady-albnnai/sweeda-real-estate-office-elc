/**
 * 🔥 Cloud Functions — تطبيق عقارات السويداء
 *
 * المحرك الفعلي للتطبيق:
 * - لا تعتمد على العميل لتنفيذ المنطق الحساس
 * - كل العمليات المهمة تذهب عبر Cloud Function
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// 1. onNewOffer — عند إنشاء عرض جديد
// ============================================================
exports.onNewOffer = functions.firestore
  .document('offers/{offId}')
  .onCreate(async (snap, context) => {
    const offer = snap.data();
    const offId = context.params.offId;

    // 1. فحص التكرار (Duplicate check)
    // 2. بدء المطابقة التلقائية
    // 3. إرسال إشعار للإدارة

    await db.collection('notifications').add({
      uid: 'admin',
      tp: 0,
      ttl: 'عرض جديد',
      bdy: `تم إنشاء عرض جديد: ${offer.ttl || 'بدون عنوان'}`,
      act: '/admin/offers',
      refId: offId,
      iRd: 0,
      iDel: 0,
      tsCrt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`New offer created: ${offId}`);
  });

// ============================================================
// 2. onOfferApproved — عند الموافقة على العرض
// ============================================================
exports.onOfferApproved = functions.firestore
  .document('offers/{offId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // فقط إذا تغير iPub من 0 إلى 1
    if (before.iPub !== 0 || after.iPub !== 1) return null;

    const offId = context.params.offId;
    const ownerId = after.usrId;

    // 1. إشعار الناشر
    await db.collection('notifications').add({
      uid: ownerId,
      tp: 0,
      ttl: '✅ تم نشر عرضك',
      bdy: `عرضك "${after.ttl}" تم نشره بنجاح`,
      act: '/user/offers',
      refId: offId,
      iRd: 0,
      iDel: 0,
      tsCrt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Offer approved: ${offId}`);
  });

// ============================================================
// 3. onAppointmentCreated — عند حجز موعد
// ============================================================
exports.onAppointmentCreated = functions.firestore
  .document('appointments/{appId}')
  .onCreate(async (snap, context) => {
    const appt = snap.data();
    const appId = context.params.appId;

    // 1. إشعار صاحب العرض
    await db.collection('notifications').add({
      uid: appt.ownId,
      tp: 2,
      ttl: '📅 حجز موعد جديد',
      bdy: 'تم حجز موعد لمعاينة عرضك',
      act: '/user/appointments',
      refId: appId,
      iRd: 0,
      iDel: 0,
      tsCrt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. إشعار الوسيط (إن وجد)
    if (appt.bkrId) {
      await db.collection('notifications').add({
        uid: appt.bkrId,
        tp: 2,
        ttl: '📅 موعد جديد',
        bdy: 'تم حجز موعد تحت إشرافك',
        act: '/broker/appointments',
        refId: appId,
        iRd: 0,
        iDel: 0,
        tsCrt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info(`Appointment created: ${appId}`);
  });

// ============================================================
// 4. onDealInitiated — عند بدء الصفقة (عرض محجوز)
// ============================================================
exports.onDealInitiated = functions.firestore
  .document('offers/{offId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const offId = context.params.offId;

    // فقط إذا sts تغير إلى 5 (محجوز)
    if (before.sts === 5 || after.sts !== 5) return null;

    // 1. إلغاء باقي المواعيد
    const appointments = await db
      .collection('appointments')
      .where('offId', '==', offId)
      .where('sts', '==', 0) // قيد الانتظار
      .get();

    const batch = db.batch();
    appointments.docs.forEach((doc) => {
      batch.update(doc.ref, { sts: 3, cnlRsn: 'تم حجز العرض' }); // ملغي
    });
    await batch.commit();

    // 2. إشعارات
    await db.collection('notifications').add({
      uid: after.usrId,
      tp: 3,
      ttl: '💰 تم حجز عرضك',
      bdy: `عرضك "${after.ttl}" تم حجزه. يرجى متابعة الإجراءات`,
      act: '/user/deals',
      refId: offId,
      iRd: 0,
      iDel: 0,
      tsCrt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Deal initiated for offer: ${offId}`);
  });

// ============================================================
// 5. hourlyTick — تذكير المواعيد (كل ساعة)
// ============================================================
exports.hourlyTick = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const in2Hours = new Date(now.toMillis() + 2 * 60 * 60 * 1000);

    // جلب المواعيد التي ستبدأ خلال ساعتين
    const upcoming = await db
      .collection('appointments')
      .where('sts', '==', 1) // مؤكد
      .where('dt', '<=', admin.firestore.Timestamp.fromDate(in2Hours))
      .where('rmnd2', '==', 0) // لم يُرسل تذكير ساعتين
      .get();

    const batch = db.batch();
    upcoming.docs.forEach((doc) => {
      const data = doc.data();

      // إشعار صاحب العرض
      const notifRef = db.collection('notifications').doc();
      batch.set(notifRef, {
        uid: data.ownId,
        tp: 2,
        ttl: '⏰ تذكير موعد',
        bdy: 'موعد معاينة عرضك بعد ساعتين',
        act: '/user/appointments',
        refId: doc.id,
        iRd: 0,
        iDel: 0,
        tsCrt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // تحديث rmnd2
      batch.update(doc.ref, { rmnd2: 1 });
    });

    await batch.commit();

    functions.logger.info(`Hourly tick: ${upcoming.size} reminders sent`);
  });

// ============================================================
// 6. dailyTick — مهام يومية (كل يوم)
// ============================================================
exports.dailyTick = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // 1. إنهاء العروض المنتهية
    const expired = await db
      .collection('offers')
      .where('sts', '==', 2) // منشور
      .where('tsEnd', '<=', now)
      .get();

    const batch = db.batch();
    expired.docs.forEach((doc) => {
      batch.update(doc.ref, { sts: 4 }); // منتهي
    });

    // 2. تنظيف الإشعارات القديمة (أكثر من 30 يوم)
    const oldDate = new Date(now.toMillis() - 30 * 24 * 60 * 60 * 1000);
    const oldNotifs = await db
      .collection('notifications')
      .where('tsCrt', '<=', admin.firestore.Timestamp.fromDate(oldDate))
      .get();

    oldNotifs.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    functions.logger.info(`Daily tick: ${expired.size} expired, ${oldNotifs.size} cleaned`);
  });

// ============================================================
// 7. onUserReport — عند تبليغ
// ============================================================
exports.onUserReport = functions.firestore
  .document('reports/{rptId}')
  .onCreate(async (snap, context) => {
    const report = snap.data();

    await db.collection('notifications').add({
      uid: 'admin',
      tp: 4,
      ttl: '📢 تبليغ جديد',
      bdy: `تم تقديم تبليغ جديد: ${report.rsn}`,
      act: '/admin/reports',
      refId: context.params.rptId,
      iRd: 0,
      iDel: 0,
      tsCrt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`New report created: ${context.params.rptId}`);
  });
