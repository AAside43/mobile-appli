# Image Upload Feature - Implementation Guide

## Overview
Added image upload functionality to the Staff Add Room page, allowing staff to select and upload images when creating new rooms. Images are stored as base64-encoded strings in the database.

## Changes Made

### 1. Mobile App (Flutter)

#### Dependencies Added (`pubspec.yaml`)
```yaml
image_picker: ^1.0.4
```

#### Modified Files
- **`lib/staff/staff_add_room_page.dart`**
  - Added image picker functionality
  - Added image preview before upload
  - Converts selected image to base64 before sending to server
  
- **`lib/staff/staff_room_page.dart`**
  - Updated to display base64 images from database
  - Added fallback to default image if no custom image exists

### 2. Server (Node.js/Express)

#### New Endpoints
- **`POST /rooms`** - Create new room with image
  - Accepts: `name`, `description`, `capacity`, `is_available`, `image` (base64)
  - Returns: `201` with room ID on success

#### Modified Endpoints
- **`GET /rooms`** - Now includes `image` field in response

#### Database Migration
- Added `image` column (LONGTEXT) to `rooms` table
- Migration runs automatically on server startup

### 3. Database Schema

```sql
ALTER TABLE rooms ADD COLUMN image LONGTEXT;
```

## Setup Instructions

### 1. Install Flutter Dependencies
```bash
cd "g:\MFU\Y3_1\Moblie\Project Mobile\mobile-appli"
flutter pub get
```

### 2. Start the Server
The database migration will run automatically when you start the server:
```bash
cd server
node app.js
```

### 3. Configure Android Permissions (if needed)
For Android, the `image_picker` package automatically handles permissions. No additional configuration needed.

### 4. Configure iOS Permissions (if targeting iOS)
Add to `ios/Runner/Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select room images</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take room photos</string>
```

## How It Works

1. **Staff selects an image**
   - Taps on the image placeholder in Add Room page
   - Selects image from gallery
   - Image is displayed as preview

2. **Image processing**
   - Image is resized to max 1024x1024 pixels
   - Quality is set to 85% to reduce file size
   - Image is converted to base64 string

3. **Server storage**
   - Base64 string is stored in `rooms.image` column
   - LONGTEXT type supports up to 4GB (sufficient for images)

4. **Display**
   - When viewing rooms, images are decoded from base64
   - Fallback to default image if no custom image exists

## API Examples

### Create Room with Image
```javascript
POST /rooms
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "Conference Room A",
  "description": "Large meeting room",
  "capacity": 20,
  "is_available": true,
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
}
```

### Response
```json
{
  "message": "Room added successfully",
  "roomId": 5
}
```

## Notes

- Images are stored as base64 in the database (simple but not optimal for very large images)
- Consider migrating to file storage (e.g., AWS S3) for production with many rooms
- Current implementation limits image size through compression (1024x1024, 85% quality)
- Default fallback image is `assets/images/Room1.jpg`

## Troubleshooting

### Image not displaying
- Check if image column exists in database
- Verify server is returning image data in GET /rooms
- Check browser/app console for decoding errors

### Upload fails
- Verify image size isn't too large
- Check server logs for SQL errors
- Ensure database has sufficient storage

### "Column not found" error
- Restart the server to run auto-migration
- Or manually run: `ALTER TABLE rooms ADD COLUMN image LONGTEXT;`
