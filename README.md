# EasyMed

A comprehensive telemedicine platform built with Flutter that connects patients with healthcare providers through a seamless digital experience.

## Features

- **Authentication**: Email/password and Google Sign-In
- **Patient Features**: Profile management, doctor search, appointment booking, medical reports, prescriptions
- **Doctor Features**: Profile setup, appointment management, prescription creation, patient management
- **Video Consultations**: Integrated video calls for remote consultations
- **AI-Powered**: Symptom analysis and doctor recommendations

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Authentication, Storage)
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Video**: Stream Video SDK

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase (add `google-services.json` for Android)
4. Set up environment variables (see `.env.example`)
5. Run `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=STRIPE_API_KEY --dart-define=STREAM_API_KEY=STREAM_API_KEY --dart-define=STREAM_APP_ID=STREAM_API_ID `

## Team

- Abhinav - Authentication, Setup, Video Calls, Routing
- Ryan - Patient Features, AI Questionnaire, Medical Reports
- Nick - Doctor Features, Prescriptions, Doctor Search
- Basim - Appointment System, Waiting Room
