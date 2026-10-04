const { onCall } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const crypto = require('crypto');
admin.initializeApp();

// Chamado exclusivamente no fluxo de aprovação do responsável.
exports.validatePin = onCall({ region: 'southamerica-east1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login necessário.');
  const responsibleUid = request.auth.uid;
  const responsible = await admin.firestore().doc(`users/${responsibleUid}`).get();
  if (!responsible.exists || responsible.data().role !== 'responsavel') {
    throw new HttpsError('permission-denied', 'Somente o responsável pode aprovar.');
  }
  const pin = String(request.data?.pin || '');
  if (!/^\d{4,6}$/.test(pin)) throw new HttpsError('invalid-argument', 'PIN inválido.');
  const privateDoc = await admin.firestore().doc(`users/${responsibleUid}/private/pin`).get();
  const stored = privateDoc.data()?.pinHash;
  if (!stored || stored.length !== 64) throw new HttpsError('failed-precondition', 'PIN ainda não configurado.');
  const hash = crypto.createHash('sha256').update(pin).digest('hex');
  return { valid: crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(stored)) };
});

// O reset preserva histórico e zera apenas entradas da semana corrente.
exports.resetWeeklyRanking = onSchedule({ schedule: '0 0 * * 1', timeZone: 'America/Sao_Paulo', region: 'southamerica-east1' }, async () => {
  const db = admin.firestore();
  const weekId = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(new Date());
  const snapshot = await db.collection(`rankings/${weekId}/entries`).get();
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.update(doc.ref, { approvedMinutes: 0, resetAt: admin.firestore.FieldValue.serverTimestamp() }));
  await batch.commit();
});
