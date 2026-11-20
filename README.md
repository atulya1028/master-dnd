# Master DND (Full-Stack Flutter + BLoC + Node.js + MongoDB)

Production-ready implementation of the **Master DND** application featuring a Flutter client with **BLoC state management** (`flutter_bloc`), and a Node.js + Express.js + MongoDB backend with phone number OTP authentication, onboarding profile setup form, real-time dashboard, profile editor, and live API integration.

---

## Architecture Overview

```
master_dnd/
├── backend/                       # Node.js + Express.js + MongoDB API Service
│   ├── src/
│   │   ├── config/db.js           # Mongoose connection & resilient dev fallback
│   │   ├── controllers/           # Auth, User, and DND controllers
│   │   ├── middleware/            # JWT auth & error handling
│   │   ├── models/                # Mongoose schemas (User, Otp, DndProfile, DndRule)
│   │   ├── routes/                # Express routes (/api/auth, /api/user, /api/dnd)
│   │   └── utils/                 # JWT tokens & OTP helpers
│   ├── server.js                  # Server entry point (Port 5001)
│   └── package.json
│
├── lib/                           # Flutter Client
│   ├── bloc/                      # BLoC State Management Layer
│   │   ├── auth/
│   │   │   ├── auth_bloc.dart     # Auth session, OTP, profile & DND toggle logic
│   │   │   ├── auth_event.dart    # Equatable auth events
│   │   │   └── auth_state.dart    # Equatable auth states
│   │   └── dnd/
│   │       ├── dnd_bloc.dart      # DND profiles fetching & active status toggle
│   │       ├── dnd_event.dart     # Equatable DND events
│   │       └── dnd_state.dart     # Equatable DND states
│   ├── core/
│   │   ├── api_service.dart       # REST client with JWT header management
│   │   ├── models.dart            # UserModel, DndProfile, DndRule models
│   │   ├── theme.dart             # Day & Night Figma themes
│   │   └── tokens.dart            # Color, spacing, and radius tokens
│   ├── screens/
│   │   ├── splash_screen.dart     # AuthGate (BlocBuilder listening to AuthBloc)
│   │   ├── auth/
│   │   │   ├── phone_login_screen.dart       # Step 1: Mobile phone entry (BlocConsumer)
│   │   │   ├── otp_verification_screen.dart  # Step 1b: 6-digit OTP verification
│   │   │   └── profile_form_screen.dart      # Step 2: Profile setup form
│   │   ├── profile/
│   │   │   └── edit_profile_screen.dart      # Edit profile & logout
│   │   ├── app_shell.dart         # Tab shell with reactive Night theme switching
│   │   ├── home_screen.dart       # Dashboard with live user greeting & DND toggle
│   │   ├── profiles_screen.dart   # DND profiles list powered by DndBloc
│   │   ├── profile_editor_screen.dart # Profile settings editor
│   │   ├── rules_screen.dart      # Automation rules
│   │   └── insights_screen.dart   # Silence & let-through insights
│   ├── widgets/
│   │   └── widgets.dart           # Reusable buttons, cards, chips, switches
│   └── main.dart                  # Initialized with MultiBlocProvider [AuthBloc, DndBloc]
└── pubspec.yaml
```

---

## BLoC State Management Design

### 1. `AuthBloc` (`lib/bloc/auth/`)
* **Events**:
  * `AuthCheckRequested`: Checks stored token and profile completeness on startup.
  * `AuthSendOtpRequested(phone)`: Requests 6-digit OTP code from backend.
  * `AuthVerifyOtpRequested(phone, otp)`: Verifies code, saves JWT token, and directs to either Profile Form or Dashboard.
  * `AuthResendOtpRequested(phone)`: Resends code with updated expiry.
  * `AuthCompleteProfileRequested(name, email, avatar, bio)`: Completes step 2 onboarding.
  * `AuthUpdateProfileRequested(name, email, avatar, bio)`: Edits profile from the dashboard.
  * `AuthToggleDndRequested(enabled)`: Toggles DND armed state with optimistic UI updates.
  * `AuthLogoutRequested`: Clears session token and returns to login.
* **States**:
  * `AuthInitial`
  * `AuthLoading`
  * `AuthUnauthenticated`
  * `AuthOtpSentState(phone, testOtp, expiresInSeconds)`
  * `AuthNeedsProfileFormState(user)`
  * `AuthenticatedState(user)`
  * `AuthFailureState(error, previousState)`

### 2. `DndBloc` (`lib/bloc/dnd/`)
* **Events**:
  * `DndLoadRequested`: Fetches DND profiles from backend.
  * `DndToggleProfileRequested(profileId, active)`: Toggles profile active status (ensures only one active at a time).
  * `DndSaveProfileRequested(profile)`: Creates or updates custom DND profile.
  * `DndDeleteProfileRequested(profileId)`: Removes profile.
* **States**:
  * `DndInitial`
  * `DndLoading`
  * `DndLoaded(profiles, activeCount, activeProfile)`
  * `DndError(message)`

---

## How to Run

### 1. Start the Backend Server

```bash
cd backend
npm install
npm run dev
```

* Backend server runs at `http://localhost:5001`.
* Health check: `http://localhost:5001/api/health`.

### 2. Run the Flutter App

```bash
# Get dependencies
flutter pub get

# Run on macOS / Chrome / Simulator / Device
flutter run
```
