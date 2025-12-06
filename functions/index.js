const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin - use getApps() check for v5 compatibility
const adminApps = admin.apps;
if (adminApps.length === 0) {
  admin.initializeApp();
}

// Create Stripe Payment Intent
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { amount, appointmentId, currency = 'usd' } = data;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Amount must be greater than 0');
  }

  if (!appointmentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Appointment ID is required');
  }

  try {
    const stripe = require('stripe');
    const config = functions.config();
    const secretKey = config.stripe?.secret_key;
    
    if (!secretKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Stripe secret key not configured');
    }
    
    const stripeClient = stripe(secretKey);
    const paymentIntent = await stripeClient.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency: currency,
      metadata: {
        appointmentId: appointmentId,
        patientId: context.auth.uid,
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error) {
    console.error('Error creating payment intent:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create payment intent: ' + error.message);
  }
});

// Confirm payment after successful Stripe payment
exports.confirmPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { paymentIntentId, paymentId } = data;

  if (!paymentIntentId || !paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Payment Intent ID and Payment ID are required');
  }

  try {
    const stripe = require('stripe');
    const config = functions.config();
    const secretKey = config.stripe?.secret_key;
    
    if (!secretKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Stripe secret key not configured');
    }
    
    const stripeClient = stripe(secretKey);
    const paymentIntent = await stripeClient.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== 'succeeded') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not completed');
    }

    const db = admin.firestore();
    await db.collection('payments').doc(paymentId).update({
      status: 'completed',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      stripePaymentIntentId: paymentIntentId,
    });

    const paymentDoc = await db.collection('payments').doc(paymentId).get();
    const appointmentId = paymentDoc.data()?.appointmentId;

    if (appointmentId) {
      await db.collection('appointments').doc(appointmentId).update({
        isPaid: true,
        paymentId: paymentId,
      });
    }

    return { success: true };
  } catch (error) {
    console.error('Error confirming payment:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to confirm payment: ' + error.message);
  }
});
