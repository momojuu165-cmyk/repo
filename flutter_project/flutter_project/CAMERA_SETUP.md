# Camera & Barcode Scanner Setup

Add the following permissions **once** when you first run `flutter create` or after cloning.

---

## Android

In `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` before `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

---

## iOS

In `ios/Runner/Info.plist`, inside `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>يستخدم التطبيق الكاميرا لمسح باركود المنتجات</string>
```

---

## After adding permissions

```bash
flutter pub get
flutter run
```

The scanner button (orange camera icon) on the invoice screen will work immediately.
