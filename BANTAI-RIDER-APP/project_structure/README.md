# Project Structure Template

This folder stores the standard architecture to follow whenever a new feature, module, or screen is added to the app.

## Team rule

- Keep the app layered: `core` → `data` → `domain` → `features`
- Feature folders should be created per business module
- Reusable services, constants, utilities, and theme settings live in `core`
- Business logic belongs in `domain`, data access in `data`, and UI logic in `features`
- Every new feature must match this template before implementation begins

## Recommended structure

```text
lib/
├── core/
│   ├── constants/
│   │   └── api_endpoints.dart
│   ├── network/
│   │   └── network_info.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│       └── validators.dart
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
│   ├── auth/
│   │   ├── controllers/
│   │   │   └── auth_notifier.dart
│   │   └── screens/
│   │       └── login_screen.dart
│   ├── home/
│   │   ├── controllers/
│   │   │   └── home_notifier.dart
│   │   └── screens/
│   │       └── home_screen.dart
│   └── live_trip/
│       ├── controllers/
│       │   └── live_trip_notifier.dart
│       ├── screens/
│       │   └── live_trip_screen.dart
│       └── widgets/
│           └── trip_stats_card.dart
├── main.dart
└── app.dart
```

## How to use this

1. Create a new feature folder under `lib/features`
2. Add matching `controllers/`, `screens/`, and `widgets/` folders if needed
3. If the feature needs API work, add the datasource/model/repository layers under `data` and `domain`
4. Keep the UI screen files thin and move business logic to controllers or use-cases

## Template backup

A usable scaffold is stored in `./scaffold` for quick copy/paste when creating a new feature.
