/**
 * REQUIRED BACKEND ENDPOINTS FOR FLUTTER APP
 * =============================================
 * 
 * The Flutter app now expects these PHP endpoints on the ESP32/server.
 * Implement these to fully integrate the theft detection system.
 */

/**
 * 1. GET STATISTICS
 * GET /Reader/get_stats.php
 * 
 * Returns overall system statistics including theft alerts
 * 
 * Response JSON:
 * {
 *   "total_tags": 247,
 *   "unknown_today": 3,
 *   "unread_alerts": 2,
 *   "by_type": [
 *     { "numero": 1, "nom_type": "Clé", "count": 150 },
 *     { "numero": 2, "nom_type": "Carte", "count": 97 }
 *   ]
 * }
 */

/**
 * 2. GET THEFT ALERTS
 * GET /Reader/get_alerts.php?limit=50
 * 
 * Returns all detected theft alerts (FOUND at door events)
 * 
 * Query Parameters:
 *   - limit: max number of alerts to return (default 50)
 * 
 * Response JSON:
 * {
 *   "alerts": [
 *     {
 *       "id": 1,
 *       "epc": "30:12:34:56:78:90",
 *       "type": "THEFT",
 *       "timestamp": "2026-04-24 15:32:45",
 *       "is_read": 0
 *     },
 *     {
 *       "id": 2,
 *       "epc": "30:AB:CD:EF:01:23",
 *       "type": "THEFT",
 *       "timestamp": "2026-04-24 14:15:20",
 *       "is_read": 1
 *     }
 *   ],
 *   "unread_count": 1
 * }
 */

/**
 * 3. MARK ALERT AS READ
 * POST /Reader/mark_alert_read.php
 * 
 * Mark a specific alert as read
 * 
 * Body (form-encoded):
 *   alert_id: integer
 * 
 * Response:
 *   HTTP 200 - Success
 *   HTTP 404 - Alert not found
 */

/**
 * 4. CLEAR ALL ALERTS
 * POST /Reader/clear_alerts.php
 * 
 * Delete all theft alerts from the database
 * 
 * Response:
 *   HTTP 200 - Success
 */

/**
 * INTEGRATION WITH EXISTING ENDPOINTS
 * ====================================
 * 
 * The app also uses these existing endpoints:
 * - Operateur: ESP32 is the active base URL
 *   - POST /save - Save a new tag (handled by ESP32)
 *   - POST /saveall - Batch save tags (handled by ESP32)
 *   - GET /check.php?epc=<epc> - Check if tag exists
 * - Admin: XAMPP is the active base URL
 *   - GET /Reader/get_stats.php
 *   - GET /Reader/get_alerts.php?limit=50
 *   - POST /Reader/mark_alert_read.php
 *   - POST /Reader/clear_alerts.php
 * - Shared:
 *   - GET /login - Login page
 *   - POST /login - Authenticate user
 *   - GET /logout - Logout
 *   - WebSocket /ws - Real-time state updates from ESP32
 * 
 * WebSocket Status Format (sent periodically by ESP32):
 * {
 *   "wifi": true,
 *   "mode": "CHECK",  // or "SAVE", "SAVEALL"
 *   "relay": false,
 *   "tag": "",
 *   "tagDetecte": false,
 *   "lastEpc": "30:12:34:56:78:90",
 *   "result": "FOUND|Clé",  // or "NOT_FOUND"
 *   "message": "🚨 VOL DÉTECTÉ!",
 *   "msgType": "err",  // or "ok"
 *   "types": [
 *     { "num": "1", "nom": "Clé" },
 *     { "num": "2", "nom": "Carte" }
 *   ],
 *   "checkList": [
 *     { "epc": "30:12:34:56:78:90", "result": "FOUND|Clé" }
 *   ],
 *   "batchList": [],
 *   "batchPending": false,
 *   "batchResult": "",
 *   "timeLeft": 0
 * }
 *
 * Client commands accepted on /ws:
 * - {"action":"set_mode","mode":"CHECK|SAVE|SAVEALL"}
 * - {"action":"clear_check"}
 * - {"action":"cancel_save"}
 * - {"action":"clear_batch"}
 * - {"action":"save_batch"}
 * 
 * THEFT DETECTION LOGIC (ESP32 C++):
 * ===================================
 * 
 * When mode = CHECK:
 *   1. Tag is presented at door (EPC read)
 *   2. Check if EPC exists in database: GET /check.php?epc=<EPC>
 *   3. If response = "FOUND|<type>":
 *      - Article IS in database → THEFT ALERT! 🚨
 *      - Red LED on
 *      - Buzzer beeps 3x (alarm pattern)
 *      - OLED shows "⚠️ VOL!"
 *      - Relay opens (door alarm)
 *      - Message: "🚨 VOL DÉTECTÉ!"
 *      - msgType: "err"
 *   
 *   4. If response starts with error or "NOT_FOUND":
 *      - Article NOT in database → SAFE ✅
 *      - Green LED on
 *      - OLED shows "✓ OK"
 *      - No alarm
 *      - Message: "✅ Aucun problème"
 *      - msgType: "ok"
 * 
 * FLUTTER APP CHANGES:
 * ====================
 * 
 * 1. New file: lib/services/api_service.dart
 *    - Handles all backend API calls
 *    - getStats(), getAlerts(), markAlertAsRead(), clearAllAlerts()
 * 
 * 2. Updated: lib/screens/admin/statistics_screen.dart
 *    - Calls get_stats.php
 *    - Displays total tags, daily alerts, unread alerts
 *    - Shows tags by type with count
 * 
 * 3. Updated: lib/screens/admin/alerts_screen.dart
 *    - Calls get_alerts.php
 *    - Displays theft alerts with timestamps
 *    - Mark alerts as read
 *    - Clear all alerts button
 * 
 * 4. Enhanced: lib/screens/home_screen.dart
 *    - _CheckModeWidget now interprets FOUND as THEFT (red alert)
 *    - Shows prominent theft alert dialog when theft detected
 *    - Displays "🚨 VOL" vs "✅ Aucun problème" based on result
 *    - Real-time threat detection with visual feedback
 * 
 * TESTING CHECKLIST:
 * ==================
 * 
 * □ Implement get_stats.php endpoint
 * □ Implement get_alerts.php endpoint
 * □ Implement mark_alert_read.php endpoint
 * □ Implement clear_alerts.php endpoint
 * □ Create theft_alerts table in database:
 *   - id (auto increment)
 *   - epc (string)
 *   - type (enum: THEFT)
 *   - timestamp (datetime)
 *   - is_read (boolean, default 0)
 * □ Test ESP32 sends theft alerts to database
 * □ Test Flutter app displays alerts correctly
 * □ Test marking alerts as read
 * □ Test clearing all alerts
 * □ Test statistics endpoint accuracy
 * □ Test WebSocket real-time status updates
 */
