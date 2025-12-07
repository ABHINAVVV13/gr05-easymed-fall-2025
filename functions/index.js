const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin - this must be done at module level for Cloud Functions
if (admin.apps.length === 0) {
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
    let config;
    try {
      config = functions.config();
    } catch (e) {
      // Config might not be available during deployment
      config = {};
    }
    const secretKey = config.stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
    
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
    let config;
    try {
      config = functions.config();
    } catch (e) {
      // Config might not be available during deployment
      config = {};
    }
    const secretKey = config.stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
    
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

// Send push notification
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, title, body, notificationType, notificationData } = data;

  console.log('📤 sendPushNotification called with:', { userId, title, body });

  if (!userId || !title || !body) {
    console.error('❌ Missing required fields:', { userId: !!userId, title: !!title, body: !!body });
    throw new functions.https.HttpsError('invalid-argument', 'UserId, title, and body are required');
  }

  try {
    const db = admin.firestore();
    
    // Get user's FCM token
    console.log(`🔍 Looking up FCM token for user: ${userId}`);
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User document not found: ${userId}`);
      return { success: false, message: 'User not found' };
    }
    
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    console.log(`🔑 FCM token found: ${fcmToken ? 'YES' : 'NO'}`);

    if (!fcmToken) {
      console.log(`⚠️ No FCM token found for user ${userId}`);
      return { success: false, message: 'No FCM token found' };
    }

    // Send notification via FCM
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: notificationType || 'general',
        ...(notificationData || {}),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'easymed_notifications',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    console.log('📨 Sending FCM message...');
    const response = await admin.messaging().send(message);
    console.log('✅ Successfully sent message:', response);

    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    console.error('❌ Error stack:', error.stack);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to send push notification: ' + error.message);
  }
});
