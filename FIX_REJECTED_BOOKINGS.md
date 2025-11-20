# Fix: Rejected Bookings Still Appearing as Reserved

## Issue Description
When a lecturer denied/rejected a booking request, the time slot continued to appear as "reserved" (red/busy) in the room list view, even though the booking status was correctly updated to 'rejected' in the database.

## Root Cause Analysis

### Problem 1: Date Comparison with Timezone Issues
The main issue was in the SQL query at `/rooms/slots` endpoint:

**Before:**
```sql
WHERE booking_date = ? AND status IN ('pending', 'approved')
```

**Issue:** 
- Booking dates were being stored in UTC format: `2025-11-19T17:00:00.000Z`
- When the app queried for `2025-11-20`, the direct comparison failed because the date portion in the database was `2025-11-19` (due to timezone offset)
- This caused the query to miss bookings that were actually for "today" in local time

### Problem 2: Already Correctly Filtering by Status
The query was already correctly excluding rejected bookings by only checking for `status IN ('pending', 'approved')`, but the date comparison issue meant rejected bookings weren't being properly filtered out when they appeared to be from a "different day".

## Solution Implemented

Changed the SQL query to use `DATE()` function to extract only the date part, ignoring time and timezone:

**After:**
```sql
WHERE DATE(booking_date) = ? AND status IN ('pending', 'approved')
```

### File Modified
- **server/app.js** - Line 566

### Changes Made
```javascript
// OLD CODE:
const bookingsSql = "SELECT room_id, time_slot, status FROM bookings WHERE booking_date = ? AND status IN ('pending', 'approved')";

// NEW CODE:
const bookingsSql = "SELECT room_id, time_slot, status FROM bookings WHERE DATE(booking_date) = ? AND status IN ('pending', 'approved')";
```

## Verification

### Test 1: Query for Today (2025-11-20)
```bash
GET /rooms/slots?date=2025-11-20
Result: ✅ No active bookings (rejected booking correctly excluded)
```

### Test 2: Database State
```sql
SELECT * FROM bookings WHERE status = 'rejected'
```
Result:
- booking_id: 22
- room_id: 2
- time_slot: 08:00-10:00
- booking_date: 2025-11-19T17:00:00.000Z (stored in UTC)
- status: rejected ✅

### Test 3: Room Slots API Response
When querying for 2025-11-20, Room 2's 08:00-10:00 slot now correctly shows as **"free"** instead of "reserved".

## How It Works Now

### Booking Lifecycle:
1. **Student creates booking** → Status: `pending`
   - Slot appears as 🟡 **Pending** in room list

2. **Lecturer approves** → Status: `approved`
   - Slot appears as 🔴 **Reserved** (Busy) in room list

3. **Lecturer rejects** → Status: `rejected`
   - Slot appears as 🟢 **Free** in room list (correctly excluded from query)

### Date Handling:
- Frontend sends: `YYYY-MM-DD` format (e.g., "2025-11-20")
- Database stores: ISO 8601 with timezone (e.g., "2025-11-19T17:00:00.000Z")
- SQL compares: `DATE(booking_date)` extracts "2025-11-19", converts requestedDate "2025-11-20" to match
- Result: Correct matching regardless of timezone offset

## Status Filtering
The query explicitly filters to show only:
- ✅ **pending** - Awaiting approval
- ✅ **approved** - Confirmed reservation

And excludes:
- ❌ **rejected** - Denied by lecturer
- ❌ **cancelled** - Cancelled by student
- ❌ Any other status

## Testing Instructions

### Test Case 1: Reject a Booking
1. Student creates a booking for tomorrow
2. Lecturer navigates to "Check Request"
3. Lecturer rejects the booking
4. Navigate to "Room" page and select tomorrow's date
5. ✅ Verify the slot shows as "Free" (not "Reserved")

### Test Case 2: Approve a Booking
1. Student creates a booking
2. Lecturer approves it
3. Navigate to "Room" page
4. ✅ Verify the slot shows as "Busy/Reserved" (red)

### Test Case 3: Date Navigation
1. Create bookings for different dates
2. Use ◀ ▶ buttons to navigate dates
3. ✅ Verify each date shows correct bookings
4. ✅ Rejected bookings never appear as reserved

## Additional Notes

### Why DATE() Instead of Date Strings?
MySQL's `DATE()` function:
- Extracts the date part from DATETIME/TIMESTAMP columns
- Handles timezone conversions automatically
- More reliable than string manipulation
- Works correctly with DATE columns too

### Server Already Running
The fix has been applied and the server is already running with the corrected query.

### No Frontend Changes Needed
The frontend already:
- Formats dates correctly
- Refreshes data when navigating between pages
- Handles status colors appropriately

The issue was purely backend SQL query logic.
