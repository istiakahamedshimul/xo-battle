# XO Battle — Online Tic Tac Toe

## Setup

### 1. Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
2. Enable **Authentication** → Anonymous sign-in
3. Enable **Cloud Firestore** in production mode
4. Register your Android app (package: `com.xobattle.xo_battle`)
5. Download `google-services.json` → place in `android/app/`

### 2. FlutterFire CLI (auto-generate firebase_options.dart)
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This will overwrite `lib/firebase_options.dart` with correct values.

### 3. Firestore Rules
Copy `firestore.rules` contents into Firebase Console → Firestore → Rules.

### 4. Install dependencies & run
```bash
flutter pub get
flutter run
```

## Project Structure
```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   ├── room_model.dart
│   └── chat_message.dart
├── providers/
│   └── providers.dart
├── services/
│   ├── auth_service.dart
│   └── room_service.dart
└── screens/
    ├── splash_screen.dart
    ├── login_screen.dart
    ├── profile_setup_screen.dart
    ├── home_screen.dart
    ├── create_room_screen.dart
    ├── join_room_screen.dart
    ├── lobby_screen.dart
    ├── game_screen.dart
    ├── result_screen.dart
    ├── leaderboard_screen.dart
    ├── profile_screen.dart
    └── settings_screen.dart
```

## Scoring
| Result | Points |
|--------|--------|
| Win | +3 |
| Draw | +1 |
| Lose | +0 |
| Opponent left | +2 |

## Game Flow
Open App → Login as Guest → Set Name → Create/Join Room → Lobby → Game → Result → Rematch or Home
