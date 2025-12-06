import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/payment_service.dart';
import '../../services/doctor_service.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final appointmentProvider = FutureProvider.family<AppointmentModel?, String>((ref, appointmentId) async {
  final appointmentService = ref.read(appointmentServiceProvider);
  return await appointmentService.getAppointmentById(appointmentId);
});

class PaymentScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final appointment = await ref.read(appointmentServiceProvider).getAppointmentById(widget.appointmentId);
      
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      // Get doctor's consultation fee
      final doctor = await ref.read(doctorServiceProvider).getDoctorById(appointment.doctorId);
      if (doctor == null) {
        throw Exception('Doctor not found');
      }
      
      if (doctor.consultationFee == null || doctor.consultationFee! <= 0) {
        throw Exception('Doctor has not set a consultation fee');
      }

      // Check if payment already exists
      var payment = await paymentService.getPaymentByAppointment(widget.appointmentId);
      
      if (payment == null) {
        // Create new payment with Stripe Payment Intent
        final currentUser = ref.read(authStateNotifierProvider).value;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        payment = await paymentService.createPayment(
          appointmentId: widget.appointmentId,
          patientId: currentUser.uid,
          doctorId: appointment.doctorId,
          amount: doctor.consultationFee!,
        );
      }

      // Update payment status to processing
      await paymentService.updatePaymentStatus(payment.id, PaymentStatus.processing);

      // Process payment with Stripe
      if (payment.stripeClientSecret == null) {
        throw Exception('Payment client secret not found. Please try again.');
      }

      await paymentService.processPaymentWithStripe(
        paymentId: payment.id,
        clientSecret: payment.stripeClientSecret!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment processed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e) {
      // Extract user-friendly error message
      String errorMessage = 'Payment failed. Please try again.';
      final errorString = e.toString();
      
      if (errorString.contains('canceled') || errorString.contains('Canceled')) {
        errorMessage = 'Payment was canceled';
      } else if (errorString.contains('Payment failed:')) {
        // Extract message after "Payment failed:"
        final match = RegExp(r'Payment failed:\s*(.+)').firstMatch(errorString);
        if (match != null) {
          errorMessage = match.group(1) ?? errorMessage;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      
      // Error is shown via snackbar, no need to update state
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentProvider(widget.appointmentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: appointmentAsync.when(
        data: (appointment) {
          if (appointment == null) {
            return const Center(child: Text('Appointment not found'));
          }
          
          if (appointment.isPaid) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Already Completed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<UserModel?>(
            future: ref.read(doctorServiceProvider).getDoctorById(appointment.doctorId),
            builder: (context, snapshot) {
              final doctor = snapshot.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Appointment Info Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Appointment Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFF2196F3),
                                  child: Text(
                                    doctor?.displayName?.substring(0, 1).toUpperCase() ?? 'D',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctor?.displayName ?? 'Doctor',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (doctor?.specialization != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          doctor!.specialization!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.calendar_today, 'Date', 
                                DateFormat('MMM d, yyyy').format(appointment.scheduledTime)),
                            _buildInfoRow(Icons.access_time, 'Time', 
                                DateFormat('h:mm a').format(appointment.scheduledTime)),
                            _buildInfoRow(Icons.check_circle, 'Status', 'Completed'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Payment Summary Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Consultation Fee',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  doctor?.consultationFee != null
                                      ? '\$${doctor!.consultationFee!.toStringAsFixed(2)}'
                                      : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  doctor?.consultationFee != null
                                      ? '\$${doctor!.consultationFee!.toStringAsFixed(2)}'
                                      : 'N/A',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Payment Method (Stripe)
                    Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.payment, color: Colors.purple.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Secure Payment via Stripe',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your payment will be processed securely through Stripe.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pay Button
                    if (doctor?.consultationFee == null || doctor!.consultationFee! <= 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This doctor has not set a consultation fee. Please contact the doctor.',
                                style: TextStyle(color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Pay \$${doctor!.consultationFee!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(appointmentProvider(widget.appointmentId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

