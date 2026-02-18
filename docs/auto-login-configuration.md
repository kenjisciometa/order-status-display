# Auto Login Configuration Guide

This document explains how auto-login works in the OSD (Order Status Display) application and the various configuration options available.

## Overview

The OSD app supports automatic login for kiosk mode deployments. There are two ways to configure auto-login credentials:

1. **`.env` file configuration** - Credentials embedded in the application bundle
2. **SharedPreferences storage** - Credentials saved via the app's GUI

## Authentication Flow Priority

```
1. .env AUTO_LOGIN_EMAIL/PASSWORD exists
   → Auto-login with .env credentials (legacy method)

2. SharedPreferences credentials exist
   → Auto-login with stored credentials (new method)

3. No credentials + Kiosk mode
   → Show Initial Setup Screen (new feature)

4. No credentials + Standard mode
   → Show Login Screen
```

## Configuration Methods

### Method 1: `.env` File (Legacy)

Edit the `.env` file in the application bundle:

```
# Location in bundle
data/flutter_assets/.env
```

Configuration:
```env
PLATFORM_MODE=kiosk
AUTO_LOGIN_EMAIL=user@example.com
AUTO_LOGIN_PASSWORD=yourpassword
```

**Pros:**
- Simple for mass deployment
- Credentials are bundled with the app

**Cons:**
- Requires rebuilding/editing the bundle to change credentials
- Not user-friendly for end users

### Method 2: SharedPreferences (GUI-based)

Credentials can be configured through:

1. **Initial Setup Screen** - Displayed on first launch when no credentials are configured
2. **Settings Screen** - "AUTO LOGIN SETTINGS" section allows changing credentials after setup

**Pros:**
- User-friendly GUI
- No need to edit files
- Can be changed without rebuilding the app

**Cons:**
- Requires initial manual setup on each device

## SharedPreferences Storage Location

SharedPreferences data is stored in the user's home directory, not in the application bundle.

| Platform | Storage Location |
|----------|------------------|
| **Linux** | `~/.local/share/osd_app/shared_preferences.json` |
| **macOS** | `~/Library/Preferences/<bundle_id>.plist` |
| **Windows** | `%APPDATA%\osd_app\shared_preferences.json` |

### Example Path (Linux/Raspberry Pi)
```
/home/pi/.local/share/osd_app/shared_preferences.json
```

### Stored Keys
```json
{
  "flutter.osd_auto_login_enabled": true,
  "flutter.stored_email": "user@example.com",
  "flutter.stored_password": "password123",
  "flutter.device_id": "abc123-def456-...",
  "flutter.auth_token": "eyJhbG..."
}
```

## Initial Setup Screen

When the app is launched in kiosk mode without any configured credentials, the Initial Setup Screen is displayed automatically.

### Features
- Step-by-step wizard interface
- Credential validation before saving
- Secure storage in SharedPreferences

### Flow
1. Welcome screen with feature overview
2. Credentials input form
3. Validation against the server
4. Save to SharedPreferences on success
5. Navigate to main application

## Settings Screen - Auto Login Section

The Settings screen includes an "AUTO LOGIN SETTINGS" section with the following options:

### When Auto Login is Enabled
- **Change Credentials** - Update email/password
- **Disable Auto Login** - Clear stored credentials

### When Auto Login is Disabled
- **Enable Auto Login** - Configure new credentials

## Deployment Scenarios

### Scenario 1: Mass Deployment with Same Account
Use `.env` configuration:
1. Edit `.env` with the shared credentials
2. Rebuild the bundle
3. Deploy to all devices

### Scenario 2: Individual Device Setup
Use SharedPreferences (GUI):
1. Deploy bundle without `.env` credentials (leave empty)
2. On first launch, Initial Setup Screen appears
3. User enters their credentials
4. Credentials are saved locally on that device

### Scenario 3: Hybrid Approach
1. Deploy with empty `.env` credentials
2. Users configure via Initial Setup Screen
3. Admins can later update via Settings screen if needed

## Security Considerations

### Current Implementation
- Credentials are stored in plain text in SharedPreferences
- `.env` credentials are also plain text

### Recommendations for Production
For enhanced security, consider migrating to `flutter_secure_storage` package which uses:
- **Linux**: libsecret (GNOME Keyring)
- **macOS**: Keychain
- **Windows**: Windows Credential Manager

## Troubleshooting

### Credentials Not Working
1. Check network connectivity
2. Verify credentials are correct by testing in standard login
3. Check server logs for authentication errors

### Initial Setup Screen Not Appearing
- Ensure `PLATFORM_MODE=kiosk` in `.env`
- Ensure `.env` does not have `AUTO_LOGIN_EMAIL` and `AUTO_LOGIN_PASSWORD` set

### Resetting Stored Credentials
Delete the SharedPreferences file:
```bash
# Linux
rm ~/.local/share/osd_app/shared_preferences.json

# macOS
rm ~/Library/Preferences/com.sciometa.osd_app.plist
```

## Related Files

- `lib/screens/initial_setup_screen.dart` - Initial setup wizard
- `lib/screens/settings_screen.dart` - Settings with auto-login section
- `lib/services/api_client_service.dart` - Credential storage methods
- `lib/main.dart` - Authentication flow logic
- `lib/screens/login_screen.dart` - Login screen with .env auto-login
