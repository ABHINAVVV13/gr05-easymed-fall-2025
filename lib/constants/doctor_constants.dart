/// Constants related to doctor functionality
class DoctorConstants {
  DoctorConstants._(); // Private constructor to prevent instantiation

  /// Available medical specializations
  static const List<String> specializations = [
    'Cardiology',
    'Dermatology',
    'Pediatrics',
    'Orthopedics',
    'Neurology',
    'General Medicine',
  ];

  /// Default working hours start time
  static const String defaultStartTime = '09:00';

  /// Default working hours end time
  static const String defaultEndTime = '17:00';

  /// Days of the week
  static const List<String> weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Minimum consultation fee (if validation is needed)
  static const double minConsultationFee = 0.0;
}

