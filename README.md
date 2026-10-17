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

---

## 🧪 Hackathon Quick-Start, Hosting & Demo

### Two backends (important)
| Backend | Used for | Where |
|---|---|---|
| Smart Attendance API (external, Railway) | Login, Attendance, timetable | `API_BASE_URL` (default baked in; overridable at build time or on the login screen) |
| CampusOS ERP server (`server/server.py`, this repo) | Student leave, warden approval, audit history | `ERP_API_BASE_URL` (build-time) |

If `ERP_API_BASE_URL` is empty, ERP calls go to the same server as `API_BASE_URL` (useful when you run only the CampusOS server and point the app at it).
On login, the app signs into the ERP server with the same ID/password, so **accounts must exist on both servers with the same credentials** for a real (non-demo) session to use both.
**Demo sessions never contact any server**: Attendance shows labelled sample data and ERP shows a "DEMO MODE: stored on this device only" banner. Real sessions never fall back to local storage; if the server is down they get an error.

### Run the ERP server locally
```bash
export CAMPUSOS_DEMO_PASSWORD='<choose>'     # password for seeded demo student/teacher accounts
export CAMPUSOS_ADMIN_PASSWORD='<choose>'    # password for ADMIN01
export CAMPUSOS_SECRET_KEY="$(python3 -c 'import secrets;print(secrets.token_hex(32))')"
python3 server/server.py            # PORT env or argv[1], default 8000; GET /api/health
python3 -m unittest server/test_server.py   # backend tests (use its own temp DB)
```
Seeded accounts (only created when the two password variables are set): students `22CS1042`, `22EE2001`; wardens `FAC-CS-08` (CSE), `WARDEN-YAMUNA` (EE); admin `ADMIN01`.

### Server environment variables
| Variable | Required | Purpose |
|---|---|---|
| `CAMPUSOS_ENV` | Set to `production` on the host | In production the server refuses to start unless `CAMPUSOS_SECRET_KEY` is set (>= 32 chars). |
| `CAMPUSOS_SECRET_KEY` | Yes in production | Signs bearer tokens. If unset a random key is used and every restart logs everyone out. |
| `CAMPUSOS_DEMO_PASSWORD`, `CAMPUSOS_ADMIN_PASSWORD` | To seed demo accounts | Passwords are stored PBKDF2-hashed. No accounts are created without them. |
| `CAMPUSOS_DB_PATH` | Recommended | SQLite file path; point it at a persistent volume. |
| `CAMPUSOS_CORS_ORIGINS` | Only for browser clients | Comma-separated allowed origins. Native app needs none. |
| `PORT` | Set by most hosts | Listen port. |

### Hosting the server (Render / Railway / any VM)
- Runtime: Python 3.9+, **no pip dependencies**. Start command: `python3 server/server.py`. Health check: `/api/health`.
- **Persistence requires a persistent volume**: the SQLite file lives at `CAMPUSOS_DB_PATH` (parent folders are created). Without a mounted volume, data is lost on redeploy. Attach a persistent disk/volume and set `CAMPUSOS_DB_PATH` to a file on it (otherwise the DB resets on redeploy; for a demo that is acceptable, the seed data is recreated).
- Always serve over HTTPS (the platform proxy does this); tokens are bearer tokens.
- Build the app pointing at it: `flutter build apk --release --dart-define=ERP_API_BASE_URL=https://<your-erp-host>` (add `--dart-define=API_BASE_URL=...` to override the attendance backend).

### Demo walkthrough (live mode)
1. Launch app, log in as `22CS1042` -> Dashboard -> ERP & Leave -> Student Leave -> submit a request.
2. Log out, log in as `FAC-CS-08` -> ERP -> Warden Inbox -> open the request -> Approve/Reject with remarks.
3. Log in as `22CS1042` again -> Student Leave: status and audit history show the persisted decision.
4. Attendance (needs the Attendance backend), PractiVerse (deterministic in-app challenge/quiz checking; no code is executed), GeoCam (real camera + GPS, SHA-256 and Ed25519 stamp on the captured bytes).
- **Fallback if a server is down:** use the "Instant Demo Access" buttons on the login screen. Everything is clearly labelled demo/local-only.

### Known limitations
- Employee leave application/approval is device-local only (no server endpoint yet); the ERP banner says so.
- Warden routing uses only server records: `warden_assignments` (explicit student IDs) and the student's `users.department`. Client-supplied hostel/department is ignored for routing (hostel is display-only). There is no trusted student-to-hostel table, so hostel-based assignment is not supported; students with no matching warden are visible to admin only.
- Demo accounts share one password; rotate/replace before any real use. Login is rate-limited per ID (5 failures / 5 min) in memory only.
- `ERP_API_BASE_URL` is build-time only; the login screen's backend URL field changes the Attendance/primary URL.

### PractiVerse: practicals for ANY topic
`PractiVerse -> Syllabus Mapping -> Generate a practical for this text` works for any subject.
- **AI route (signed-in users):** the CampusOS server (`server/practical_gen.py`) asks Claude for a structured practical, then validates it (schema, lengths, quiz shape) before sending it on. Calculation practicals carry a formula that the app parses with its own safe engine (no `eval`) and grades itself, so numeric answers never depend on the model's text. The key never reaches the app. Set `GROQ_API_KEY` (free tier, default model `openai/gpt-oss-120b`) **or** `ANTHROPIC_API_KEY` (paid, default `claude-opus-5-5`) in the server environment; Groq wins when both are set (`CAMPUSOS_LLM_PROVIDER=groq|anthropic` forces one). Run `pip install -r server/requirements.txt` (the Render blueprint does both; `CAMPUSOS_LLM_MODEL` and `CAMPUSOS_GEN_PER_HOUR` are optional). Groq's free tier allows about 8,000 tokens per minute, i.e. only a few generations per minute: the server waits out short limits once and otherwise answers "busy, try again in a minute". Requests are authenticated, limited per user and cached for 24 h.
- **No-AI route:** with no server, no key, or in demo mode, questions are built locally from the notes you paste (needs about 4+ sentences; a bare title cannot be expanded without the AI). Every practical shows where it came from, and quiz answers from the AI are flagged as "check against your course material".
- Verified live against Groq with six unrelated topics (physics, finance, binary search, law, history, biology). The Anthropic path was only exercised against the official SDK with a local stand-in endpoint.
