# AQUA Manager (Flutter)

A starting point for an advanced aquaculture management mobile app.

## Key Features Included

- ✅ **User authentication** (placeholder via `AuthService` + secure storage)
- ✅ **Real-time monitoring** (API-driven pond list + provider state updates)
- ✅ **Offline support** (SQLite local database scaffold via `DBService`)
- ✅ **GPS tracking** (location helper via `LocationService`)
- ✅ **Camera integration** (capture pond photos via `CameraScreen`)
- ✅ **Analytics charts** (sample charts via `fl_chart`)
- ✅ **Modern UI + navigation** (Material 3, Provider, and named routes)

## Getting Started

### 1) Install dependencies

```bash
cd "d:\Quản lý thủy sản AQUA\aquaculture_app"
dart pub get
```

> ⚠️ **Windows note:** Flutter tools may require Developer Mode enabled to create symlinks for plugins. If you see errors about symlinks, run:
>
> ```powershell
> start ms-settings:developers
> ```

### 2) Run the app

```bash
flutter run
```

### 3) Configure API & Auth

- Update `lib/src/services/api_service.dart` with your backend base URL.
- Implement authentication endpoints in `lib/src/services/auth_service.dart`.

### 4) Improve offline sync

- Expand `lib/src/services/db_service.dart` to store pond readings and sync them when online.
- Use `ConnectivityProvider` to detect connectivity changes and trigger sync logic.

### 5) Add notifications

The project includes a placeholder `NotificationService`.
To enable real notifications:

1. Add a notification plugin (e.g., `flutter_local_notifications` or `awesome_notifications`).
2. Update `lib/src/services/notification_service.dart` to initialize and show notifications.

---

If you want, I can also add:

- A pond detail screen with map/GPS tracking and boundary drawing
- WebSocket support for real-time sensor streaming
- Background data sync + alerts
