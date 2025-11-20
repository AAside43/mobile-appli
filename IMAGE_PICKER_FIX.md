# Image Picker Fix - Quick Guide

## What Was Fixed

The error "Unable to establish connection on channel" was caused by missing Android configuration for the image_picker plugin.

## Changes Made

### 1. AndroidManifest.xml
Added required permissions and queries:
- `READ_EXTERNAL_STORAGE` - Read images from gallery
- `WRITE_EXTERNAL_STORAGE` - For older Android versions
- `CAMERA` - For taking photos
- Added `requestLegacyExternalStorage="true"` for Android 10+
- Added intent queries for image picker and camera

### 2. build.gradle.kts
- Set `minSdk = 21` (required by image_picker)

### 3. Dependencies
- Cleaned and reinstalled all Flutter packages

## Next Steps

### 1. Rebuild the App
Stop the current app and rebuild it:
```bash
flutter run
```

Or in your IDE:
- Stop the app (red square button)
- Run again (green play button)

### 2. Grant Permissions on Device
When you first tap "Tap to select image":
- Android will ask for permission to access photos
- Click "Allow" or "While using the app"

## Testing

1. Open the app
2. Go to Staff Room Management
3. Click the "+" button to add a room
4. Tap on "Tap to select image"
5. Select an image from your gallery
6. The image should now display in the preview
7. Fill in room details and save

## Troubleshooting

### If permission dialog doesn't appear:
1. Go to Android Settings > Apps > Your App
2. Permissions > Photos and Videos (or Storage)
3. Enable it manually

### If still getting errors:
1. Completely uninstall the app from your device
2. Run `flutter clean`
3. Run `flutter pub get`
4. Rebuild: `flutter run`

## Important Notes

- The app needs to be **completely rebuilt** after these changes
- Hot reload/hot restart won't work for these changes
- The error will persist until the app is fully rebuilt and reinstalled
