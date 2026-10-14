# CampusOS — Unified Smart Campus Operating System

CampusOS is a unified, mobile-first Smart Campus application built with Flutter, designed to integrate attendance, geo-verification, ERP & leave management, and virtual practical labs.

---

## 🏛 Team & Module Ownership

| Role | Member | Git Branch | Module / Area | Directory |
|---|---|---|---|---|
| **Person 1** | Core App & Integration Lead | `feature/core-app` | Core Foundation, Dashboard, Design System, Auth, Attendance Adapter, GeoCam Bridge | `lib/core/`, `lib/app/`, `lib/features/auth/`, `lib/features/dashboard/`, `lib/features/attendance/`, `lib/features/geocam/` |
| **Person 2** | Teammate | `feature/erp-leave` | ERP & Leave Management Portal | `lib/features/erp/` |
| **Person 3** | Teammate | `feature/practiverse` | PractiVerse (Labs, Practical Work & Projects) | `lib/features/practiverse/` |

> **Critical Rule:** Anesa is a separate, launch-ready project. Never modify its code, database, configuration, or deployment.

---

## 📁 Architecture Directory Structure

```
campus-os/
├── lib/
│   ├── main.dart                      # Application bootstrap & session restore
│   ├── app/
│   │   └── campus_app.dart            # MaterialApp, theme configuration, session listener
│   ├── core/
│   │   ├── network/
│   │   │   └── api_client.dart        # HTTP client with Bearer auth & timeout handling
│   │   ├── theme/
│   │   │   └── app_theme.dart         # Colors, typography, spacing, Material 3 theme
│   │   └── widgets/
│   │       └── shared_widgets.dart    # StatusBadge, ModuleCard, LoadingView, ErrorStateView
│   └── features/
│       ├── auth/                      # Authentication & secure session handling
│       │   ├── models/user_session.dart
│       │   ├── services/auth_service.dart
│       │   └── screens/login_screen.dart
│       ├── dashboard/                 # Home dashboard & role-aware navigation
│       │   └── screens/dashboard_screen.dart
│       ├── attendance/                # Smart Attendance API adapter & UI
│       │   ├── services/attendance_service.dart
│       │   └── screens/attendance_screen.dart
│       ├── geocam/                    # GeoCam integration entry point
│       │   └── screens/geocam_screen.dart
│       ├── erp/                       # Boundary owned by Person 2
│       │   └── erp_module.dart
│       └── practiverse/               # Boundary owned by Person 3
│           └── practiverse_module.dart
└── test/
    └── widget_test.dart               # Core smoke & layout tests
```

---

## 🚀 Running the App

### Prerequisites
- Flutter SDK 3.22+ (verified on Flutter 3.47 / Dart 3.13)
- Android SDK (API 21+ supported)

### Launch locally
```bash
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run on specific emulator (e.g. Pixel 6)
flutter emulators --launch Pixel_6
flutter run -d Pixel_6

# Build Android APK
flutter build apk --debug
```

---

## 🔌 API & Integration Details

### 1. Smart Attendance System Integration
- Connected backend: `https://github.com/Ankush1298/smart_attendance_system`
- Endpoints consumed:
  - `POST /api/auth/login`: Authenticates ID + password, issues bearer token + role (`student`, `teacher`, `admin`).
  - `GET /api/health`: Health status probe.
  - `GET /api/me/student/overview`: Student attendance summary, face registration status, today's timetable slots.
  - `GET /api/me/teacher/overview`: Faculty slot schedule and live sessions.
- Secure Storage: Tokens are persisted securely using `flutter_secure_storage`.
- Instant Demo Mode: Built-in 1-tap switches for Student, Faculty, and Admin personas allow instant evaluation and testing even if the backend server is offline.

### 2. GeoCam Integration
- Connected repository: `https://github.com/Ankush1298/geocam`
- Provides tamper-proof photo verification with GPS coordinate watermarking and SHA-256 hash stamping.

### 3. Teammate Guidelines (Person 2 & Person 3)
1. Pull latest `main`:
   ```bash
   git pull origin main
   ```
2. Branch off `main`:
   - Person 2: `git checkout -b feature/erp-leave`
   - Person 3: `git checkout -b feature/practiverse`
3. Implement your screens inside your designated directory (`lib/features/erp/` or `lib/features/practiverse/`).
4. Wire your primary screen into `ErpModule.getEntryPoint(context)` or `PractiverseModule.getEntryPoint(context)`.
5. Run tests before submitting PR:
   ```bash
   flutter analyze
   flutter test
   ```
