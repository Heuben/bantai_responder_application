# banta_rider_app

A Flutter rider/responder application structured for backend integration.

## Backend configuration

The app now includes a centralized backend config and API client layer. Configure the backend target with environment variables before running the app:

- `APP_ENV=development|staging|production`
- `APP_NAME=BANTAI`
- `API_BASE_URL=http://localhost:3000/api`

A sample file is included at `.env.example`.

Example run:

```bash
flutter run --dart-define=APP_ENV=development --dart-define=APP_NAME=BANTAI --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Structure
lib/
├── core/
│   ├── constants/
│   │   └── api_endpoints.dart
│   └── network/
│       └── network_info.dart
├── data/
│   ├── datasources/
│   │   ├── rest_client.dart
│   │   ├── websocket_client.dart
│   │   └── webrtc_service.dart
│   ├── models/
│   │   └── trip_model.dart
│   └── repositories/
│       └── trip_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── trip_entity.dart
│   └── repositories/
│       └── trip_repository.dart
├── features/
│   └── live_trip/
│       ├── controllers/
│       │   └── live_trip_notifier.dart
│       └── screens/
│           └── live_trip_screen.dart
└── main.dart
example

lib/
│
├── core/                         # Shared utilities, constants, & themes
│   ├── constants/                # App constants (API endpoints, asset strings)
│   ├── theme/                    # App colors, text styles, and styling data
│   └── utils/                    # Helper functions (date formatters, validators)
│
├── data/                         # Data Layer (Raw network communication & data parsing)
│   ├── datasources/              # Where raw network calls happen
│   │   ├── rest_api_client.dart  # Custom Dio/Http client for NestJS REST endpoints
│   │   ├── websocket_client.dart # Manages the persistent WebSocket connection
│   │   └── webrtc_service.dart   # Initializes peer connections & signaling
│   ├── models/                   # JSON serialization / Deserialization models
│   │   ├── rider_model.dart
│   │   └── trip_model.dart
│   └── repositories/             # Combines datasources & converts models to domain entities
│
├── domain/                       # Business Rules Layer (Pure Dart, no UI/Framework code)
│   ├── entities/                 # Clean, immutable data structures used by the UI
│   └── repositories_interfaces/  # Contracts/Abstract classes defining data behavior
│
├── features/                     # Feature Layer (Broken down by app modules)
│   ├── auth/                     # Authentication feature (Login, Register)
│   │   ├── controllers/          # State management (Bloc, Riverpod, or Cubit)
│   │   └── screens/              # UI Views and Widgets
│   ├── home/                     # Dashboard / Map view
│   └── trip/                     # Active delivery/ride tracking feature
│       ├── controllers/          # Listens to WebSocket/WebRTC state changes
│       ├── screens/              # Active trip screen (real-time map updates)
│       └── widgets/              # Small, reusable widgets (e.g., TripStatsCard)
│
└── main.dart                     # App Initialization entry point

