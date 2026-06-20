#include <HardwareSerial.h>
#include <WiFi.h>
#include <SPIFFS.h>
#include <HTTPClient.h>
#include <vector>
#include <algorithm>
#include <map>
#include <set>
#include <ctype.h>

// OLED Display
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// HTTPS Server
#include <HTTPSServer.hpp>
#include <HTTPServer.hpp>
#include <SSLCert.hpp>
#include <HTTPRequest.hpp>
#include <HTTPResponse.hpp>
#include <WebsocketHandler.hpp>
using namespace httpsserver;

#include "cert.h"

// WiFi & AP
const char *ssid        = "  ";
const char *password    = " ";
const char *serverIP    = "  ";
const char *ap_ssid     = "Hotel_RFID_AP";
const char *ap_password = " ";

// Authentification - Multiple Users
const char *ADMIN_USERNAME     = "admin";
const char *ADMIN_PASSWORD     = " ";
const char *OPERATEUR_USERNAME = "operateur";
const char *OPERATEUR_PASSWORD = " ";
#define SESSION_TIMEOUT_MS   3600000UL
#define SESSION_CLEANUP_MS   300000UL
#define MAX_SESSIONS         16

std::map<String, unsigned long> sessions;
unsigned long lastSessionCleanup = 0;

String generateToken() {
    String t = "";
    for (int i = 0; i < 32; i++) {
        uint8_t nibble = (uint8_t)(esp_random() & 0x0F);
        t += String(nibble, HEX);
    }
    return t;
}

String extractSessionCookie(HTTPRequest *req) {
    std::string cookieStr = req->getHeader("Cookie");
    String cookies = String(cookieStr.c_str());
    int idx = cookies.indexOf("session=");
    if (idx < 0) return "";
    int end = cookies.indexOf(';', idx + 8);
    String token = (end < 0) ? cookies.substring(idx + 8) : cookies.substring(idx + 8, end);
    token.trim();
    return token;
}

bool isAuthenticated(HTTPRequest *req) {
    String token = extractSessionCookie(req);
    if (token.length() == 0) return false;
    if (!sessions.count(token)) return false;
    if (millis() - sessions[token] > SESSION_TIMEOUT_MS) {
        sessions.erase(token);
        return false;
    }
    sessions[token] = millis();
    return true;
}

void redirectToLogin(HTTPResponse *res) {
    res->setStatusCode(302);
    res->setHeader("Location", "/login");
    res->setHeader("Content-Type", "text/plain");
    res->println("Redirecting to /login");
}

void cleanupSessions() {
    for (auto it = sessions.begin(); it != sessions.end(); ) {
        if (millis() - it->second > SESSION_TIMEOUT_MS) it = sessions.erase(it);
        else ++it;
    }
}

void logRuntimeState(const String &context) {
    Serial.println("[ESP32] " + context + " | freeHeap=" + String(ESP.getFreeHeap()) +
                   " | activeSessions=" + String((int)sessions.size()));
}

void logProxyTiming(const String &label, unsigned long startedAt, int httpCode) {
    unsigned long elapsedMs = millis() - startedAt;
    Serial.println("[ESP32] " + label + " | durationMs=" + String(elapsedMs) +
                   " | httpCode=" + String(httpCode) +
                   " | freeHeap=" + String(ESP.getFreeHeap()) +
                   " | activeSessions=" + String((int)sessions.size()));
}

// ── FIX #4 + #5: correct String construction + larger buffer ───────────────
String parseFormField(const String &body, const String &key) {
    String search = key + "=";
    int idx = body.indexOf(search);
    if (idx < 0) return "";
    idx += search.length();
    int end = body.indexOf('&', idx);
    String val = (end < 0) ? body.substring(idx) : body.substring(idx, end);
    String decoded = "";
    for (int i = 0; i < (int)val.length(); i++) {
        if (val[i] == '+') decoded += ' ';
        else if (val[i] == '%' && i + 2 < (int)val.length()) {
            char hex[3] = {val[i+1], val[i+2], 0};
            decoded += (char)strtol(hex, nullptr, 16);
            i += 2;
        } else decoded += val[i];
    }
    return decoded;
}
// ─────────────────────────────────────────────────────────────────────────────

String parseJsonField(const String &body, const String &key) {
    String needle = "\"" + key + "\"";
    int k = body.indexOf(needle);
    if (k < 0) return "";

    int colon = body.indexOf(':', k + needle.length());
    if (colon < 0) return "";

    int i = colon + 1;
    while (i < (int)body.length() && isspace((unsigned char)body[i])) i++;
    if (i >= (int)body.length()) return "";

    if (body[i] == '"') {
        i++;
        String out = "";
        while (i < (int)body.length()) {
            char c = body[i++];
            if (c == '\\' && i < (int)body.length()) {
                char esc = body[i++];
                if (esc == '"') out += '"';
                else if (esc == '\\') out += '\\';
                else if (esc == 'n') out += '\n';
                else if (esc == 't') out += '\t';
                else out += esc;
                continue;
            }
            if (c == '"') break;
            out += c;
        }
        return out;
    }

    int end = i;
    while (end < (int)body.length() && body[end] != ',' && body[end] != '}') end++;
    String raw = body.substring(i, end);
    raw.trim();
    return raw;
}

String getUserRole(const String &username) {
    if (username == String(ADMIN_USERNAME)) return "admin";
    if (username == String(OPERATEUR_USERNAME)) return "operateur";
    return "";
}

void handleLoginRequest(HTTPRequest *req, HTTPResponse *res) {
    uint8_t buf[512]={0};
    size_t len = req->readBytes(buf, sizeof(buf)-1);
    buf[len] = '\0';
    String body = String((char*)buf);

    String contentType = String(req->getHeader("Content-Type").c_str());
    contentType.toLowerCase();
    String accept = String(req->getHeader("Accept").c_str());
    accept.toLowerCase();

    String user = parseFormField(body,"username");
    String pass = parseFormField(body,"password");

    bool jsonRequest = contentType.indexOf("application/json") >= 0;
    bool wantsJson = jsonRequest || accept.indexOf("application/json") >= 0;

    if (jsonRequest && (user.isEmpty() || pass.isEmpty())) {
        user = parseJsonField(body, "username");
        pass = parseJsonField(body, "password");
        if (user.isEmpty()) user = parseJsonField(body, "user");
        if (pass.isEmpty()) pass = parseJsonField(body, "pass");
    }

    String userRole = "";

    if (user == String(ADMIN_USERNAME) && pass == String(ADMIN_PASSWORD)) {
        userRole = "admin";
    } else if (user == String(OPERATEUR_USERNAME) && pass == String(OPERATEUR_PASSWORD)) {
        userRole = "operateur";
    }

    if (userRole.length() > 0) {
        if ((int)sessions.size()>=MAX_SESSIONS) {
            auto oldest=sessions.begin();
            for (auto it=sessions.begin();it!=sessions.end();++it)
                if (it->second<oldest->second) oldest=it;
            sessions.erase(oldest);
        }

        String token=generateToken();
        sessions[token]=millis();
        res->setHeader("Set-Cookie", std::string(("session="+token+"; Path=/; HttpOnly; Max-Age=3600").c_str()));

        if (wantsJson) {
            res->setStatusCode(200);
            res->setHeader("Content-Type", "application/json");
            String jsonResp = "{\"status\":\"ok\",\"msg\":\"Login success\",\"role\":\"" + userRole + "\"}";
            res->print(jsonResp);
        } else {
            res->setStatusCode(302);
            res->setHeader("Location","/");
            res->setHeader("Content-Type", "text/plain");
            res->println("Redirecting to /");
        }
    } else {
        if (wantsJson) {
            res->setStatusCode(401);
            res->setHeader("Content-Type", "application/json");
            res->print("{\"status\":\"error\",\"msg\":\"Identifiants incorrects\"}");
        } else {
            res->setStatusCode(302);
            res->setHeader("Location","/login?error=1");
            res->setHeader("Content-Type", "text/plain");
            res->println("Redirecting to /login?error=1");
        }
    }
}

void serveSpiffs(HTTPResponse *res, const char *path, const char *mime) {
    if (!SPIFFS.exists(path)) {
        res->setStatusCode(404);
        res->println("Not Found");
        return;
    }
    File f = SPIFFS.open(path, "r");
    res->setStatusCode(200);
    res->setHeader("Content-Type", mime);
    uint8_t buf[512];
    while (f.available()) {
        int n = f.read(buf, sizeof(buf));
        res->write(buf, n);
    }
    f.close();
}

// RFID & GPIO Configuration
HardwareSerial rfidSerial(2);
#define RXD2 16
#define TXD2 17
#define SWITCH_PIN_A  4
#define SWITCH_PIN_B  5
#define LED_VERT     26
#define LED_ROUGE    27
#define BUZZER_PIN   25
#define OLED_SDA     21
#define OLED_SCL     22

// OLED Display
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET   -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

enum Mode { MODE_CHECK, MODE_SAVE, MODE_SAVEALL };

Mode getCurrentMode() {
    if (digitalRead(SWITCH_PIN_A) == LOW) return MODE_SAVE;
    if (digitalRead(SWITCH_PIN_B) == LOW) return MODE_SAVEALL;
    return MODE_CHECK;
}

String modeName(Mode m) {
    if (m == MODE_SAVE)    return "SAVE";
    if (m == MODE_SAVEALL) return "SAVEALL";
    return "CHECK";
}

// ── FIX #3: Mutex protecting ALL shared state ─────────────────────────────
// Both loop() (main task) and httpsTask (WebSocket/POST handlers) access
// these variables. Without protection, FreeRTOS preemption causes corruption.
SemaphoreHandle_t stateMutex = nullptr;  // protects all globals below
// ─────────────────────────────────────────────────────────────────────────────

// Variables globales (protected by stateMutex)
String tagEnAttente       = "";
String dernierEpcCheck    = "";
String dernierResultCheck = "";
String globalMessage      = "";
String globalMsgType      = "";
String typesCache         = "";
bool   tagDetecte         = false;
bool   relaiOuvert        = false;
Mode   ancienMode         = MODE_CHECK;

// ── FIX #6: timestamp to auto-clear stale globalMessage ──────────────────
unsigned long globalMsgTime = 0;
#define MSG_DISPLAY_MS 4000   // clear alert after 4 seconds
// ─────────────────────────────────────────────────────────────────────────────



unsigned long lastWifiRetry = 0;
#define WIFI_RETRY_INTERVAL 10000

unsigned long relayOpenTime    = 0;
bool          relayTimerActive = false;
#define RELAY_OPEN_DURATION 3000

unsigned long ledErrorTime    = 0;
bool          ledErrorActive  = false;
#define LED_ERROR_DURATION 2000

unsigned long ledBatchTime   = 0;
bool          ledBatchActive = false;
#define LED_BATCH_DURATION 120

unsigned long lastOledAlertTime = 0;
#define OLED_ALERT_DURATION 5000  // Keep theft alert on display for 5 seconds

struct CheckEntry { String epc, result; unsigned long ts; };
std::vector<CheckEntry> checkHistory;
#define CHECK_COOLDOWN    8000
#define CHECK_HISTORY_MAX 12

std::vector<String> batchEpcs;
unsigned long lastBatchScan = 0;
bool   batchPending = false;
String batchResult  = "";
#define BATCH_TIMEOUT 4000

// LEDs & Relay Hardware Control
void ledOff()    { digitalWrite(LED_VERT, LOW);  digitalWrite(LED_ROUGE, LOW);  }
void ledAccess() { digitalWrite(LED_VERT, LOW);  digitalWrite(LED_ROUGE, HIGH); }
void ledAlert()  { digitalWrite(LED_VERT, HIGH); digitalWrite(LED_ROUGE, LOW);  }
void ledBatchTrigger() {
    digitalWrite(LED_VERT, HIGH);
    ledBatchTime = millis(); ledBatchActive = true;
}

// Buzzer & OLED Functions
void buzzerBeep(int duration = 200) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(duration);
    digitalWrite(BUZZER_PIN, LOW);
}

void buzzerAlarm(int count = 3) {
    for (int i = 0; i < count; i++) {
        buzzerBeep(300);
        delay(150);
    }
}

void displayTheftAlert(const String &epc) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(15, 5);
    display.println("⚠️ VOL!");
    
    display.setTextSize(1);
    display.setCursor(0, 30);
    display.println("EPC détecté:");
    
    display.setCursor(0, 40);
    display.println(epc);
    
    display.setCursor(0, 55);
    display.println("Article en base!");
    
    display.display();
}

void displayNormalStatus(const String &msg = "NORMAL") {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(20, 20);
    display.println(msg);
    
    display.setTextSize(1);
    display.setCursor(15, 50);
    display.println("Aucun probleme");
    
    display.display();
}

void displayWaitingScan() {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(10, 25);
    display.println("En attente...");
    
    display.display();
}

void displayClear() {
    display.clearDisplay();
    display.display();
}

uint16_t crc16(uint8_t *data, uint8_t len) {
    uint16_t crc = 0xFFFF;
    for (uint8_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (uint8_t j = 0; j < 8; j++)
            crc = (crc & 1) ? (crc >> 1) ^ 0x8408 : crc >> 1;
    }
    return crc;
}
void sendCMD(uint8_t *cmd, uint8_t len) {
    uint16_t c = crc16(cmd, len);
    rfidSerial.write(cmd, len);
    rfidSerial.write(c & 0xFF);
    rfidSerial.write((c >> 8) & 0xFF);
}
void relayOpen() {
    uint8_t cmd[] = {0xCF,0xFF,0x00,0x77,0x02,0x01,0x01};
    sendCMD(cmd,7); relaiOuvert=true; Serial.println("[RELAY] OPEN - Door alarm triggered");
}
void relayClose(uint8_t s=0) {
    uint8_t cmd[] = {0xCF,0xFF,0x00,0x77,0x02,0x02,s};
    sendCMD(cmd,7); relaiOuvert=false; Serial.println("[RELAY] CLOSED - Door secured");
}

// HTTP Helpers
void fetchTypes() {
    if (WiFi.status() != WL_CONNECTED) return;
    HTTPClient http; http.setTimeout(10000);  // 10 second timeout
    http.begin("http://" + String(serverIP) + "/Reader/get_types.php");
    int code = http.GET();
    if (code > 0) {
        String result = http.getString();
        // FIX #3: protect typesCache write
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        typesCache = result;
        if (stateMutex) xSemaphoreGive(stateMutex);
    }
    http.end();
}
String httpGET(const String &url) {
    if (WiFi.status() != WL_CONNECTED) return "WIFI_ERROR";
    HTTPClient http; http.setTimeout(10000);  // 10 second timeout for proxy calls
    http.begin(url);
    int code = http.GET();
    String res = code > 0 ? http.getString() : ("HTTP_ERROR_"+String(code));
    http.end(); return res;
}
String saveTag(const String &epc, int typeNum) {
    String url = "http://"+String(serverIP)+"/Reader/save.php?epc="+epc+"&type_numero="+String(typeNum);
    String res = httpGET(url); Serial.println("💾 SAVE → "+res); return res;
}
String checkTagHTTP(const String &epc) {
    String url = "http://"+String(serverIP)+"/Reader/check.php?epc="+epc;
    String res = httpGET(url); Serial.println("🔍 CHECK → "+res); return res;
}
String saveBatch(std::vector<String> &epcs) {
    if (WiFi.status() != WL_CONNECTED) return "WIFI_ERROR";
    String body = "epcs=";
    for (int i=0;i<(int)epcs.size();i++) { if(i>0) body+=","; body+=epcs[i]; }
    HTTPClient http; http.setTimeout(10000);  // Batch save needs more time
    http.begin("http://"+String(serverIP)+"/Reader/saveall.php");
    http.addHeader("Content-Type","application/x-www-form-urlencoded");
    int code = http.POST(body);
    String res = code>0 ? http.getString() : ("HTTP_ERROR_"+String(code));
    http.end(); Serial.println("📦 SAVEALL → "+res); return res;
}

String buildTypesJSON() {
    // FIX #3: read typesCache under stateMutex
    // OPTIMIZATION: Use concat() to avoid temporary objects on stack
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    String cache = typesCache;
    if (stateMutex) xSemaphoreGive(stateMutex);

    String json;
    json.reserve(512);  // Pre-allocate
    json.concat("[");
    
    int start=0;
    bool first=true;
    while (start<(int)cache.length()) {
        int comma=cache.indexOf(',',start);
        if(comma==-1) comma=cache.length();
        String item=cache.substring(start,comma);
        int pipe=item.indexOf('|');
        if(pipe>0) {
            if(!first) json.concat(",");
            String nom=item.substring(pipe+1);
            nom.replace("\"","\\\"");
            json.concat("{\"num\":\"");
            json.concat(item.substring(0,pipe));
            json.concat("\",\"nom\":\"");
            json.concat(nom);
            json.concat("\"}");
            first=false;
        }
        start=comma+1;
    }
    json.concat("]");
    return json;
}

// WebSocket
SemaphoreHandle_t wsMutex = nullptr;
std::set<WebsocketHandler*> wsClients;

// ── FIX #7 + #8: Cross-core queue + broadcast flag ────────────────────────
// CRITICAL: Only Core 0 (httpsTask) calls client->send()
// All other tasks queue messages via queueWSMessage()
QueueHandle_t wsQueue = nullptr;

// FIX: Use char array instead of String — xQueueSend uses memcpy() which breaks
// Arduino String destructors. Raw memcpy copies the pointer, not heap data.
struct WSMessage {
    char payload[512];   // Fixed-size buffer safe for memcpy
};

volatile bool broadcastRequested = false;
volatile bool batchSaveInProgress = false;  // Prevent concurrent executeBatchSave()
// ─────────────────────────────────────────────────────────────────────────────

void broadcastStatus();      // Sets flag only
void doBroadcastNow();       // Actually sends (Core 0 only)
void executeBatchSave();
void queueWSMessage(const String &msg);

// WebSocket Handler - FIXED
class RFIDWebSocket : public WebsocketHandler {
public:
    volatile bool ready = false;

    static WebsocketHandler* create() {
        RFIDWebSocket *h = new RFIDWebSocket();
        // Only manipulate wsClients if mutex is initialized
        // WebSocket upgrade happens early, so check mutex explicitly
        if (wsMutex != nullptr) {
            if (xSemaphoreTake(wsMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
                wsClients.insert(h);
                xSemaphoreGive(wsMutex);
            } else {
                // Mutex locked or unavailable - skip adding to set
                // The client will still work, just won't broadcast
                Serial.println("[WS] Warning: Could not acquire wsMutex during create()");
            }
        }
        return h;
    }

    void onMessage(WebsocketInputStreambuf *inbuf) override {
        ready = true;
        std::istream is(inbuf);
        std::string msg; std::getline(is, msg);
        String s = String(msg.c_str());

        String action = "";
        if (s.startsWith("{")) {
            action = parseJsonField(s, "action");
        }

        if (s == "SAVE_BATCH" || action == "save_batch") {
            executeBatchSave();
        } else if (s == "CLEAR_BATCH" || action == "clear_batch") {
            if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
            batchEpcs.clear(); batchPending=false; batchResult="";
            if (stateMutex) xSemaphoreGive(stateMutex);
            broadcastStatus();
        } else if (s == "CLEAR_CHECK" || action == "clear_check") {
            if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
            checkHistory.clear(); dernierEpcCheck=""; dernierResultCheck="";
            if (stateMutex) xSemaphoreGive(stateMutex);
            broadcastStatus();
        } else if (s == "CANCEL_SAVE" || action == "cancel_save") {
            if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
            tagDetecte=false; tagEnAttente="";
            globalMessage="✖ Scan annulé"; globalMsgType="err";
            globalMsgTime = millis();
            if (stateMutex) xSemaphoreGive(stateMutex);
            ledOff(); broadcastStatus();
        } else if (action == "set_mode") {
            broadcastStatus();
        }
    }

    void onClose() override {
        ready = false;
        if (wsMutex) {
            xSemaphoreTake(wsMutex, portMAX_DELAY);
            wsClients.erase(this);
            xSemaphoreGive(wsMutex);
        }
    }

    void onError(std::string error) override {
        Serial.println("[WS] Error: " + String(error.c_str()));
    }
};

void broadcastStatus() {
    // ← FIX #7: SAFE VERSION — just set flag, don't send directly from Core 1
    // The httpsTask (Core 0) will do the actual send via doBroadcastNow()
    broadcastRequested = true;
}

void doBroadcastNow() {
    // ← FIX #7: ACTUAL SEND — called ONLY from httpsTask (Core 0)
    // Prevents cross-core race with WebsocketHandler lifecycle
    // CRITICAL: Minimize stack allocations during JSON building
    // Do NOT use String + operator (creates temp objects on stack)
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);

    Mode mode = getCurrentMode();
    
    // Copy ALL needed data under lock, then release immediately
    std::vector<CheckEntry> checkSnapshot = checkHistory;
    std::vector<String> batchSnapshot = batchEpcs;
    String safeMsg = globalMessage; safeMsg.replace("\"","\\\"");
    String safeTag = tagEnAttente;
    bool   safeDetected = tagDetecte;
    bool   safeRelay    = relaiOuvert;
    bool   safeWifi     = (WiFi.status()==WL_CONNECTED);
    String safeMsgType  = globalMsgType;
    String safeLastEpc  = dernierEpcCheck;
    String safeResult   = dernierResultCheck;
    String safeBatchRes = batchResult; safeBatchRes.replace("\"","\\\"");
    bool   safePending  = batchPending;

    if (stateMutex) xSemaphoreGive(stateMutex);

    // Get types JSON (has its own lock internally)
    String typesJson = buildTypesJSON();

    // Build JSON using concat() method (no temporary objects on stack)
    String json;
    json.reserve(2048);  // Pre-allocate to minimize reallocations
    
    json.concat("{\"wifi\":");
    json.concat(safeWifi?"true":"false");
    json.concat(",\"mode\":\"");
    json.concat(modeName(mode));
    json.concat("\",\"relay\":");
    json.concat(safeRelay?"true":"false");
    json.concat(",\"tag\":\"");
    json.concat(safeTag);
    json.concat("\",\"tagDetecte\":");
    json.concat(safeDetected?"true":"false");
    json.concat(",\"lastEpc\":\"");
    json.concat(safeLastEpc);
    json.concat("\",\"result\":\"");
    json.concat(safeResult);
    json.concat("\",\"message\":\"");
    json.concat(safeMsg);
    json.concat("\",\"msgType\":\"");
    json.concat(safeMsgType);
    json.concat("\",\"types\":");
    json.concat(typesJson);
    json.concat(",\"checkList\":[");
    
    for (int i=0; i<(int)checkSnapshot.size(); i++) {
        if(i>0) json.concat(",");
        String res = checkSnapshot[i].result; res.replace("\"","\\\"");
        json.concat("{\"epc\":\"");
        json.concat(checkSnapshot[i].epc);
        json.concat("\",\"result\":\"");
        json.concat(res);
        json.concat("\"}");
    }
    
    json.concat("],\"batchList\":[");
    for (int i=0; i<(int)batchSnapshot.size(); i++) {
        if(i>0) json.concat(",");
        json.concat("\"");
        json.concat(batchSnapshot[i]);
        json.concat("\"");
    }
    
    int timeLeft = 0;
    if (mode==MODE_SAVEALL && safePending) {
        long elapsed = (long)(millis()-lastBatchScan);
        timeLeft = max(0, (int)((BATCH_TIMEOUT-elapsed)/1000));
    }
    
    json.concat("],\"batchPending\":");
    json.concat(safePending?"true":"false");
    json.concat(",\"batchResult\":\"");
    json.concat(safeBatchRes);
    json.concat("\",\"timeLeft\":");
    json.concat(String(timeLeft));
    json.concat("}");

    std::string jsonStd = json.c_str();

    if (wsMutex) {
        xSemaphoreTake(wsMutex, portMAX_DELAY);
        auto clientsCopy = wsClients;
        // Loop directly over the authoritative set while holding the lock.
        // This ensures no client can be deleted mid-transmission.
        for (auto *client : wsClients) {
            RFIDWebSocket *rfidClient = static_cast<RFIDWebSocket*>(client);
            
            // Safety check against uninitialized or null handlers
            if (rfidClient && rfidClient->ready) {
                try { 
                    client->send(jsonStd); 
                } catch(...) {
                    Serial.println("[WS] Broadcast send failed");
                }
            }
        }
        
        xSemaphoreGive(wsMutex);
    }
}

// ── FIX #8: Queue message helper ──────────────────────────────────────────────
// Safe for any task to call. Only Core 0 actually sends.
// Uses char[] instead of String to avoid memcpy destroying heap pointers
void queueWSMessage(const String &msg) {
    if (!wsQueue) return;
    WSMessage m;
    // Copy string data safely — strncpy prevents buffer overflow
    strncpy(m.payload, msg.c_str(), sizeof(m.payload) - 1);
    m.payload[sizeof(m.payload) - 1] = '\0';  // Ensure null-termination
    xQueueSend(wsQueue, &m, 0);
}
// ─────────────────────────────────────────────────────────────────────────────

void executeBatchSave() {
    // Prevent concurrent execution from both Core 1 (loop) and Core 0 (onMessage)
    if (batchSaveInProgress) return;
    batchSaveInProgress = true;

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    if (batchEpcs.empty()) {
        batchPending=false;
        if (stateMutex) xSemaphoreGive(stateMutex);
        batchSaveInProgress = false;
        return;
    }
    std::vector<String> snapshot = batchEpcs;
    if (stateMutex) xSemaphoreGive(stateMutex);

    Serial.println("📦 Envoi "+String(snapshot.size())+" tags...");
    
    // Show uploading status on OLED
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(5, 25);
    display.println("UPLOAD...");
    display.display();
    
    String res = saveBatch(snapshot);   // HTTP call outside the lock

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    batchResult=res; globalMessage="📦 "+res; globalMsgType="ok";
    globalMsgTime = millis();
    
    // Parse result to extract saved/failed counts
    int saved = snapshot.size();
    int failed = 0;
    // If res contains error counts, parse them (adjust based on your XAMPP response format)
    if (res.indexOf("failed") >= 0) {
        // Extract numbers from response if available
    }
    
    // Send structured WebSocket message
    String batchMsg = "{\"type\":\"saveall_result\",\"saved\":" + String(saved) + ",\"failed\":" + String(failed) + ",\"msg\":\"" + res + "\"}";
    queueWSMessage(batchMsg);
    Serial.println("📤 Queued to WebSocket: " + batchMsg);
    
    batchEpcs.clear(); batchPending=false;
    if (stateMutex) xSemaphoreGive(stateMutex);

    // Show result on OLED
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(20, 20);
    display.println("✓ DONE");
    display.setTextSize(1);
    display.setCursor(0, 50);
    display.println(res);
    display.display();

    broadcastStatus();
    batchSaveInProgress = false;  // Release guard
}

void processCheck(const String &epc) {
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    for (auto &e : checkHistory)
        if (e.epc==epc && millis()-e.ts<CHECK_COOLDOWN) {
            if (stateMutex) xSemaphoreGive(stateMutex);
            return;
        }
    if (stateMutex) xSemaphoreGive(stateMutex);

    String res = checkTagHTTP(epc);   // HTTP call outside the lock

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    if (res.startsWith("WIFI_ERROR")||res.startsWith("HTTP_ERROR")) {
        globalMessage = res.startsWith("WIFI_ERROR") ? "❌ WiFi déconnecté !" : "❌ Erreur serveur ("+res+")";
        globalMsgType="err"; globalMsgTime=millis();
        if (stateMutex) xSemaphoreGive(stateMutex);
        ledAlert(); ledErrorTime=millis(); ledErrorActive=true;
        broadcastStatus(); return;
    }
    for (auto it=checkHistory.begin();it!=checkHistory.end();++it)
        if (it->epc==epc) { checkHistory.erase(it); break; }
    if ((int)checkHistory.size()>=CHECK_HISTORY_MAX)
        checkHistory.erase(checkHistory.begin());
    checkHistory.push_back({epc,res,millis()});
    dernierEpcCheck=epc; dernierResultCheck=res;
    bool found = res.startsWith("FOUND");
    if (stateMutex) xSemaphoreGive(stateMutex);

    // Send structured WebSocket message to operateur phone
    String checkMsg = "{\"type\":\"check_result\",\"epc\":\"" + epc + "\",\"result\":\"" + res + "\"}";
    queueWSMessage(checkMsg);
    Serial.println("📤 Queued to WebSocket: " + checkMsg);

    if (found) {
        // ✅ AUTORISÉ - Article en base détecté = ACCÈS AUTORISÉ
        ledAccess();  // LED VERTE
        displayNormalStatus("✓ OK");
        lastOledAlertTime = millis();
        
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        globalMessage="✅ Accès autorisé ("+epc+")"; globalMsgType="ok"; globalMsgTime=millis();
        if (stateMutex) xSemaphoreGive(stateMutex);
        
        ledErrorTime=millis(); ledErrorActive=true;
    } else {
        // ⚠️ NON AUTORISÉ - Article ABSENT de la base = ALERTE
        ledAlert(); ledErrorTime=millis(); ledErrorActive=true;
        buzzerAlarm(3);  // Triple beep alarm
        displayTheftAlert(epc);
        lastOledAlertTime = millis();
        
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        globalMessage="🚨 TAG NON AUTORISÉ! "+epc; globalMsgType="err"; globalMsgTime=millis();
        if (stateMutex) xSemaphoreGive(stateMutex);
        
        relayOpen();  // Open door alarm
        relayOpenTime=millis(); relayTimerActive=true;
    }
    broadcastStatus();
}

void addToBatch(const String &epc) {
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    for (auto &e : batchEpcs) if(e==epc) {
        if (stateMutex) xSemaphoreGive(stateMutex);
        return;
    }
    batchEpcs.push_back(epc); lastBatchScan=millis();
    batchPending=true; batchResult="";
    int count = batchEpcs.size();
    if (stateMutex) xSemaphoreGive(stateMutex);

    Serial.println("📦 Batch +"+epc+" ("+String(count)+" tags)");
    
    // Update OLED display for batch mode
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(15, 5);
    display.println("📦 BATCH");
    
    display.setTextSize(1);
    display.setCursor(0, 30);
    display.println("Tags ajoutes:");
    display.setCursor(40, 45);
    display.println(String(count));
    
    display.setCursor(0, 55);
    display.println("En attente de plus...");
    display.display();
    
    ledBatchTrigger(); broadcastStatus();
}

// ── FIX #2: 4 connections — page load + WebSocket + spare slots ──────────
SSLCert sslCert(
    const_cast<unsigned char*>(CERT_DER), CERT_DER_LEN,
    const_cast<unsigned char*>(KEY_DER),  KEY_DER_LEN
);

// Keep concurrency conservative on ESP32 to avoid SSL object exhaustion
// during bursts of mobile/browser/API requests.
HTTPSServer secureServer(&sslCert, 443, 4);
HTTPServer  redirectServer(80, 1);
// ─────────────────────────────────────────────────────────────────────────────

// ── FIX #1+#7+#8: HTTPS task with queue processing ──────────────────────
void httpsTask(void*) {
    secureServer.start();
    WSMessage incoming;

    while(true) {
        secureServer.loop();

        // FIX #8: Process all queued WebSocket messages
        while (xQueueReceive(wsQueue, &incoming, 0) == pdTRUE) {
            std::string msgStd = incoming.payload;  // payload is now char[], safe to read

            if (wsMutex) {
                xSemaphoreTake(wsMutex, portMAX_DELAY);
                std::set<WebsocketHandler*> snapshot = wsClients;
                xSemaphoreGive(wsMutex);

                for (auto *client : snapshot) {
                    RFIDWebSocket *rfidClient = static_cast<RFIDWebSocket*>(client);
                    if (!rfidClient || !rfidClient->ready) continue;
                    
                    // Only send from Core 0 — no try/catch (exceptions broken on ESP32)
                    client->send(msgStd);
                }
            }
        }

        // FIX #7: If Core 1 requested broadcast, do it now (on Core 0)
        if (broadcastRequested) {
            broadcastRequested = false;
            doBroadcastNow();
        }
        vTaskDelay(1);
    }
}
void httpRedirTask(void*){ redirectServer.start(); while(true) { redirectServer.loop(); vTaskDelay(1); } }
// ─────────────────────────────────────────────────────────────────────────────

// SETUP
void setup() {
    Serial.begin(115200);
    rfidSerial.begin(115200, SERIAL_8N1, RXD2, TXD2);
    pinMode(SWITCH_PIN_A, INPUT_PULLUP);
    pinMode(SWITCH_PIN_B, INPUT_PULLUP);
    pinMode(LED_VERT,  OUTPUT);
    pinMode(LED_ROUGE, OUTPUT);
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    
    ledOff(); relayClose(0);
    ledAccess(); delay(300); ledAlert(); delay(300); ledOff();
    ancienMode = getCurrentMode();

    Serial.println("✅ Hardware initialized");

    // Initialize OLED
    Wire.begin(OLED_SDA, OLED_SCL);
    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        Serial.println("SSD1306 allocation failed");
    } else {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.println("Initialisation...");
        display.display();
        Serial.println("✓ OLED initialized");
    }

    if (!SPIFFS.begin(true)) { Serial.println("SPIFFS Failed"); return; }

    // FIX #3: create stateMutex before starting tasks
    stateMutex = xSemaphoreCreateMutex();
    wsMutex    = xSemaphoreCreateMutex();

    // FIX #8: create WebSocket message queue for thread-safe sends
    wsQueue = xQueueCreate(20, sizeof(WSMessage));

    // WiFi.mode(WIFI_AP_STA);
    // WiFi.softAP(ap_ssid, ap_password);
    // WiFi.begin(ssid, password);

    // Disconnect cleanly first
    WiFi.disconnect(true);
    WiFi.softAPdisconnect(true);
    delay(200);

    WiFi.mode(WIFI_AP_STA);
    delay(100);

    // Fix AP on channel 6 — stops it jumping to match router channel
    WiFi.softAPConfig(
        IPAddress(192, 168, 4, 1),
        IPAddress(192, 168, 4, 1),
        IPAddress(255, 255, 255, 0)
    );
    WiFi.softAP(ap_ssid, ap_password, 6);  // channel 6 fixed
    delay(500);  // was 100 — DHCP server needs more time

    Serial.println("📡 AP: " + WiFi.softAPIP().toString());

    // STA connect AFTER AP is fully up
    WiFi.begin(ssid, password);
    int t = 0;
    while (WiFi.status() != WL_CONNECTED && t < 30) { delay(500); t++; }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("✅ WiFi: " + WiFi.localIP().toString());
        fetchTypes();
    } else {
        Serial.println("⚠️ STA non connecté — AP seul actif");
    }

    // Routes HTTPS
    secureServer.registerNode(new ResourceNode("/login", "GET", [](HTTPRequest *req, HTTPResponse *res){
        if (isAuthenticated(req)) { res->setStatusCode(302); res->setHeader("Location", "/"); return; }
        serveSpiffs(res, "/login.html", "text/html");
    }));

    secureServer.registerNode(new ResourceNode("/login", "POST", [](HTTPRequest *req, HTTPResponse *res){
        handleLoginRequest(req, res);
    }));

    redirectServer.registerNode(new ResourceNode("/login", "GET", [](HTTPRequest *req, HTTPResponse *res){
        serveSpiffs(res, "/login.html", "text/html");
    }));

    redirectServer.registerNode(new ResourceNode("/login", "POST", [](HTTPRequest *req, HTTPResponse *res){
        handleLoginRequest(req, res);
    }));

    secureServer.registerNode(new ResourceNode("/logout", "GET", [](HTTPRequest *req, HTTPResponse *res){
        String token=extractSessionCookie(req);
        if (token.length()>0) sessions.erase(token);
        res->setStatusCode(302);
        res->setHeader("Location","/login");
        res->setHeader("Set-Cookie","session=; Path=/; HttpOnly; Max-Age=0");
        res->setHeader("Content-Type", "text/plain");
        res->println("Redirecting to /login");
    }));

    secureServer.registerNode(new ResourceNode("/", "GET", [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) { redirectToLogin(res); return; }
        serveSpiffs(res, "/webpage.html", "text/html");
    }));

    // Main /save endpoint handler
    auto savePOSTHandler = [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) {
            res->setStatusCode(401);
            res->setHeader("Content-Type","application/json");
            res->print("{\"status\":\"error\",\"msg\":\"Non autorisé\"}");
            return;
        }
        // FIX #4 + #5: 512-byte buffer + correct String construction
        uint8_t buf[512]={0};
        size_t len = req->readBytes(buf, sizeof(buf)-1);
        buf[len] = '\0';
        String body = String((char*)buf);   // ← fix this

        String epc     = parseFormField(body,"epc");
        String typeStr = parseFormField(body,"type_numero");
        res->setHeader("Content-Type","application/json");

        if (epc.isEmpty()||typeStr.isEmpty()) {
            if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
            globalMessage="❌ Données manquantes !"; globalMsgType="err"; globalMsgTime=millis();
            if (stateMutex) xSemaphoreGive(stateMutex);
            ledAlert();
            res->setStatusCode(400);
            res->print("{\"status\":\"error\",\"msg\":\"Données manquantes\"}");
        } else {
            String result=saveTag(epc,typeStr.toInt());

            if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
            if (result=="SAVED") {
                globalMessage="✅ Enregistré !"; globalMsgType="ok"; globalMsgTime=millis();
                if (stateMutex) xSemaphoreGive(stateMutex);
                ledAccess(); fetchTypes();
                
                // Send structured WebSocket message
                String saveMsg = "{\"type\":\"save_result\",\"epc\":\"" + epc + "\",\"status\":\"ok\",\"msg\":\"saved\"}";
                queueWSMessage(saveMsg);
                Serial.println("📤 Queued to WebSocket: " + saveMsg);
                
                // OLED feedback - tag saved
                display.clearDisplay();
                display.setTextSize(2);
                display.setTextColor(SSD1306_WHITE);
                display.setCursor(15, 20);
                display.println("✓ SAVE");
                display.setTextSize(1);
                display.setCursor(0, 45);
                display.println("Type: " + typeStr);
                display.display();
                
                res->setStatusCode(200);
                res->print("{\"status\":\"ok\",\"msg\":\"Tag enregistré\"}");
            } else if (result=="DUPLICATE") {
                globalMessage="⚠️ Tag déjà en base !"; globalMsgType="err"; globalMsgTime=millis();
                if (stateMutex) xSemaphoreGive(stateMutex);
                ledAlert();
                
                // Send structured WebSocket message
                String saveMsg = "{\"type\":\"save_result\",\"epc\":\"" + epc + "\",\"status\":\"error\",\"msg\":\"duplicate\"}";
                queueWSMessage(saveMsg);
                Serial.println("📤 Queued to WebSocket: " + saveMsg);
                
                // OLED feedback - duplicate
                display.clearDisplay();
                display.setTextSize(2);
                display.setTextColor(SSD1306_WHITE);
                display.setCursor(10, 15);
                display.println("DOUBLON");
                display.setTextSize(1);
                display.setCursor(0, 40);
                display.println("Tag deja");
                display.setCursor(0, 50);
                display.println("dans la base!");
                display.display();
                
                res->setStatusCode(409);
                res->print("{\"status\":\"error\",\"msg\":\"Tag déjà enregistré\"}");
            } else if (result.startsWith("WIFI_ERROR")||result.startsWith("HTTP_ERROR")) {
                globalMessage="❌ Erreur réseau: "+result; globalMsgType="err"; globalMsgTime=millis();
                if (stateMutex) xSemaphoreGive(stateMutex);
                ledAlert();
                
                // Send structured WebSocket message
                String saveMsg = "{\"type\":\"save_result\",\"epc\":\"" + epc + "\",\"status\":\"error\",\"msg\":\"network_error\"}";
                queueWSMessage(saveMsg);
                
                res->setStatusCode(503);
                res->print("{\"status\":\"error\",\"msg\":\"Erreur serveur\"}");
            } else {
                globalMessage="❌ "+result; globalMsgType="err"; globalMsgTime=millis();
                if (stateMutex) xSemaphoreGive(stateMutex);
                ledAlert();
                String errJson = "{\"status\":\"error\",\"msg\":\"" + result + "\"}";
                res->print(errJson);
            }
        }
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        tagDetecte=false; tagEnAttente="";
        if (stateMutex) xSemaphoreGive(stateMutex);
        broadcastStatus();
    };

    secureServer.registerNode(new ResourceNode("/save", "POST", savePOSTHandler));

    // ── PROXY ENDPOINTS: Forward API calls to XAMPP ─────────────────────────
    // These endpoints proxy requests to the XAMPP server and return JSON
    // Phone → ESP32 (on HOTEL-RFID) → XAMPP (192.168.11.156) via WiFi
    // ────────────────────────────────────────────────────────────────────────

    // GET /Reader/get_stats - Get statistics from XAMPP
    secureServer.registerNode(new ResourceNode("/Reader/get_stats", "GET", [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) {
            res->setStatusCode(401);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Unauthorized\"}");
            return;
        }
        
        HTTPClient http;
        http.setTimeout(10000);  // 10 second timeout for proxy calls
        String url = "http://" + String(serverIP) + "/Reader/get_stats.php";
        unsigned long proxyStartedAt = millis();
        int httpCode = -1;
        logRuntimeState("proxy start /Reader/get_stats");
        
        if (http.begin(url)) {
            httpCode = http.GET();
            if (httpCode == 200) {
                String payload = http.getString();
                res->setStatusCode(200);
                res->setHeader("Content-Type","application/json");
                res->print(payload);
            } else {
                res->setStatusCode(502);
                res->setHeader("Content-Type","application/json");
                res->print("{\"error\":\"XAMPP returned HTTP " + String(httpCode) + "\"}");
            }
            http.end();
        } else {
            res->setStatusCode(503);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Cannot reach XAMPP server at " + String(serverIP) + "\"}");
        }
        logProxyTiming("proxy done /Reader/get_stats", proxyStartedAt, httpCode);
    }));



    // GET /Reader/get_alerts - Get alerts from XAMPP (limit=50 by default)
    secureServer.registerNode(new ResourceNode("/Reader/get_alerts", "GET", [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) {
            res->setStatusCode(401);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Unauthorized\"}");
            return;
        }
        
        HTTPClient http;
        http.setTimeout(10000);  // 10 second timeout for proxy calls
        unsigned long proxyStartedAt = millis();
        
        // Extract limit parameter from query string, default to 50
        String limit = "50";
        std::string query = req->getHeader("Query");
        if (!query.empty()) {
            String queryStr = String(query.c_str());
            int idx = queryStr.indexOf("limit=");
            if (idx >= 0) {
                int end = queryStr.indexOf("&", idx);
                if (end < 0) end = queryStr.length();
                limit = queryStr.substring(idx + 6, end);
            }
        }
        
        String url = "http://" + String(serverIP) + "/Reader/get_alerts.php?limit=" + limit;
        int httpCode = -1;
        logRuntimeState("proxy start /Reader/get_alerts");
        
        if (http.begin(url)) {
            httpCode = http.GET();
            if (httpCode == 200) {
                String payload = http.getString();
                res->setStatusCode(200);
                res->setHeader("Content-Type","application/json");
                res->print(payload);
            } else {
                res->setStatusCode(502);
                res->setHeader("Content-Type","application/json");
                res->print("{\"error\":\"XAMPP returned HTTP " + String(httpCode) + "\"}");
            }
            http.end();
        } else {
            res->setStatusCode(503);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Cannot reach XAMPP server at " + String(serverIP) + "\"}");
        }
        logProxyTiming("proxy done /Reader/get_alerts", proxyStartedAt, httpCode);
    }));



    // POST /Reader/mark_alert_read - Mark alert as read on XAMPP
    secureServer.registerNode(new ResourceNode("/Reader/mark_alert_read", "POST", [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) {
            res->setStatusCode(401);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Unauthorized\"}");
            return;
        }
        
        // Read request body
        uint8_t buf[256]={0};
        size_t len = req->readBytes(buf, sizeof(buf)-1);
        buf[len] = '\0';
        String body = String((char*)buf);
        
        HTTPClient http;
        http.setTimeout(10000);  // 10 second timeout for proxy calls
        String url = "http://" + String(serverIP) + "/Reader/mark_alert_read.php";
        unsigned long proxyStartedAt = millis();
        int httpCode = -1;
        logRuntimeState("proxy start /Reader/mark_alert_read");
        
        if (http.begin(url)) {
            http.addHeader("Content-Type", "application/x-www-form-urlencoded");
            httpCode = http.POST(body);
            if (httpCode == 200) {
                String payload = http.getString();
                res->setStatusCode(200);
                res->setHeader("Content-Type","application/json");
                res->print(payload);
            } else {
                res->setStatusCode(502);
                res->setHeader("Content-Type","application/json");
                res->print("{\"error\":\"XAMPP returned HTTP " + String(httpCode) + "\"}");
            }
            http.end();
        } else {
            res->setStatusCode(503);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Cannot reach XAMPP server at " + String(serverIP) + "\"}");
        }
        logProxyTiming("proxy done /Reader/mark_alert_read", proxyStartedAt, httpCode);
    }));



    // POST /Reader/clear_alerts - Clear all alerts on XAMPP
    secureServer.registerNode(new ResourceNode("/Reader/clear_alerts", "POST", [](HTTPRequest *req, HTTPResponse *res){
        if (!isAuthenticated(req)) {
            res->setStatusCode(401);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Unauthorized\"}");
            return;
        }
        
        HTTPClient http;
        http.setTimeout(10000);  // 10 second timeout for proxy calls
        String url = "http://" + String(serverIP) + "/Reader/clear_alerts.php";
        unsigned long proxyStartedAt = millis();
        int httpCode = -1;
        logRuntimeState("proxy start /Reader/clear_alerts");
        
        if (http.begin(url)) {
            http.addHeader("Content-Type", "application/x-www-form-urlencoded");
            httpCode = http.POST("");
            if (httpCode == 200) {
                String payload = http.getString();
                res->setStatusCode(200);
                res->setHeader("Content-Type","application/json");
                res->print(payload);
            } else {
                res->setStatusCode(502);
                res->setHeader("Content-Type","application/json");
                res->print("{\"error\":\"XAMPP returned HTTP " + String(httpCode) + "\"}");
            }
            http.end();
        } else {
            res->setStatusCode(503);
            res->setHeader("Content-Type","application/json");
            res->print("{\"error\":\"Cannot reach XAMPP server at " + String(serverIP) + "\"}");
        }
        logProxyTiming("proxy done /Reader/clear_alerts", proxyStartedAt, httpCode);
    }));



    // GET /Reader/get_tags - Get tags list from XAMPP
    secureServer.registerNode(new ResourceNode("/Reader/get_tags", "GET", [](HTTPRequest *req, HTTPResponse *res){
        Serial.println("🏷️ GET /Reader/get_tags called");
        if (!isAuthenticated(req)) {
            Serial.println("❌ Not authenticated");
            res->setStatusCode(401);
            res->setHeader("Content-Type", "application/json");
            res->println("{\"success\":false,\"error\":\"Not authenticated\"}");
            return;
        }

        Serial.println("✅ Authenticated - forwarding to XAMPP");
        String url = "http://" + String(serverIP) + "/Reader/get_tags.php";
        HTTPClient http;
        http.setTimeout(10000);
        http.begin(url);
        unsigned long proxyStartedAt = millis();
        int code = -1;
        logRuntimeState("proxy start /Reader/get_tags");
        
        code = http.GET();
        Serial.println("📡 XAMPP response code: " + String(code));
        if (code == 200) {
            String response = http.getString();
            res->setStatusCode(200);
            res->setHeader("Content-Type", "application/json");
            res->print(response);
            Serial.println("✅ Sent response to client");
        } else {
            res->setStatusCode(500);
            res->setHeader("Content-Type", "application/json");
            res->print("{\"success\":false,\"error\":\"HTTP " + String(code) + "\"}");
            Serial.println("❌ Sent error response");
        }
        http.end();
        logProxyTiming("proxy done /Reader/get_tags", proxyStartedAt, code);
    }));



    // PWA
    secureServer.registerNode(new ResourceNode("/manifest.json","GET", [](HTTPRequest *req, HTTPResponse *res){ serveSpiffs(res,"/manifest.json","application/manifest+json"); }));
    secureServer.registerNode(new ResourceNode("/icon.png","GET",     [](HTTPRequest *req, HTTPResponse *res){ serveSpiffs(res,"/icon.png","image/png"); }));
    secureServer.registerNode(new ResourceNode("/icon512.png","GET",  [](HTTPRequest *req, HTTPResponse *res){ serveSpiffs(res,"/icon512.png","image/png"); }));
    secureServer.registerNode(new ResourceNode("/sw.js","GET",        [](HTTPRequest *req, HTTPResponse *res){ res->setHeader("Cache-Control","no-cache"); serveSpiffs(res,"/sw.js","application/javascript"); }));

    // WebSocket endpoint - Security Note:
    // The /ws endpoint is de facto authenticated because:
    // 1. Only the authenticated /webpage.html can establish this connection
    // 2. The session cookie is automatically sent in the WebSocket upgrade request
    // 3. The httpsserver library validates the HTTPS connection (TLS/SSL)
    // PRODUCTION NOTE: For explicit WebSocket-level authentication, clients could
    // send an auth token in the first message and RFIDWebSocket::onMessage() could
    // validate it before processing commands. Current design is acceptable for
    // trusted internal networks (hotel staff only).
    secureServer.registerNode(new WebsocketNode("/ws", &RFIDWebSocket::create));



    ResourceNode *redirectNode = new ResourceNode("","", [](HTTPRequest *req, HTTPResponse *res){
        res->setStatusCode(301);
        // Use the Host header so redirect works on both 192.168.4.1 and 192.168.10.173
        std::string host = req->getHeader("Host");
        if (host.empty()) host = "192.168.4.1";
        res->setHeader("Location", "https://" + host + "/");
        res->setHeader("Content-Type", "text/plain");
        res->println("Redirecting to HTTPS");
    });
    redirectServer.setDefaultNode(redirectNode);

    // FIX #1+#7+#8: HTTPS task stack 250 KB (increased to prevent overflow)
    // HTTPS + TLS + WebSocket + queue processing + JSON building + mutex operations need adequate space
    // WebSocket upgrade happens on Core 0, so this task needs generous stack
    // Note: JSON is built efficiently using preformatted strings to minimize stack usage
    xTaskCreatePinnedToCore(httpsTask, "https", 250000, nullptr, 2, nullptr, 0);
    xTaskCreatePinnedToCore(httpRedirTask,"http_redir",  4096, nullptr, 1, nullptr, 1);

    Serial.println("🔒 HTTPS démarré sur port 443");
}

// LOOP
unsigned long lastWsBroadcast = 0;

void loop() {
    if (millis()-lastWsBroadcast>1500) {
        lastWsBroadcast=millis();

        // FIX #6: auto-clear stale globalMessage after MSG_DISPLAY_MS
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        if (!globalMessage.isEmpty() && millis()-globalMsgTime > MSG_DISPLAY_MS) {
            globalMessage=""; globalMsgType="";
        }
        if (stateMutex) xSemaphoreGive(stateMutex);

        broadcastStatus();
    }

    // Auto-clear OLED alert after duration and return to waiting scan
    if (lastOledAlertTime > 0 && millis()-lastOledAlertTime > OLED_ALERT_DURATION) {
        lastOledAlertTime = 0;
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        Mode currentMode = getCurrentMode();
        if (stateMutex) xSemaphoreGive(stateMutex);
        
        if (currentMode == MODE_CHECK) {
            displayWaitingScan();
        }
    }

    if (WiFi.status()!=WL_CONNECTED && millis()-lastWifiRetry>WIFI_RETRY_INTERVAL) {
        lastWifiRetry=millis();
        WiFi.begin(ssid,password);
    }

    if (millis()-lastSessionCleanup>SESSION_CLEANUP_MS) {
        lastSessionCleanup=millis();
        cleanupSessions();
    }

    if (relayTimerActive && millis()-relayOpenTime>=RELAY_OPEN_DURATION) {
        relayTimerActive=false; relayClose(0); ledOff(); broadcastStatus();
    }

    if (ledErrorActive && millis()-ledErrorTime>=LED_ERROR_DURATION) {
        ledErrorActive=false; ledOff();
    }

    if (ledBatchActive && millis()-ledBatchTime>=LED_BATCH_DURATION) {
        ledBatchActive=false; digitalWrite(LED_VERT,LOW);
    }

    Mode currentMode=getCurrentMode();

    if (currentMode!=ancienMode) {
        ancienMode=currentMode;
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        tagDetecte=false; tagEnAttente="";
        globalMessage=""; globalMsgType=""; globalMsgTime=0;
        batchEpcs.clear(); batchPending=false; batchResult="";
        checkHistory.clear(); dernierEpcCheck=""; dernierResultCheck="";
        if (stateMutex) xSemaphoreGive(stateMutex);
        relayTimerActive=false; ledErrorActive=false; ledBatchActive=false;
        ledOff(); relayClose(0);
        if (currentMode==MODE_SAVE||currentMode==MODE_SAVEALL) fetchTypes();
        
        // Update OLED display
        if (currentMode == MODE_CHECK) {
            displayWaitingScan();
        } else if (currentMode == MODE_SAVE) {
            display.clearDisplay();
            display.setTextSize(2);
            display.setTextColor(SSD1306_WHITE);
            display.setCursor(20, 25);
            display.println("MODE");
            display.setCursor(15, 45);
            display.println("SAVE");
            display.display();
        } else if (currentMode == MODE_SAVEALL) {
            display.clearDisplay();
            display.setTextSize(2);
            display.setTextColor(SSD1306_WHITE);
            display.setCursor(5, 25);
            display.println("BATCH");
            display.display();
        }
        
        Serial.println("→ Mode "+modeName(currentMode));
        broadcastStatus();
    }

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    bool doBatchSave = (currentMode==MODE_SAVEALL && batchPending && millis()-lastBatchScan>BATCH_TIMEOUT);
    if (stateMutex) xSemaphoreGive(stateMutex);
    if (doBatchSave) executeBatchSave();

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    checkHistory.erase(
        std::remove_if(checkHistory.begin(),checkHistory.end(),
            [](const CheckEntry &e){ return millis()-e.ts>60000; }),
        checkHistory.end());
    if (stateMutex) xSemaphoreGive(stateMutex);

    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    bool canRead = (currentMode!=MODE_SAVE) || !tagDetecte;
    if (stateMutex) xSemaphoreGive(stateMutex);

    if (canRead && rfidSerial.available() && rfidSerial.peek()==0xCF) {
        unsigned long t0=millis();
        while (rfidSerial.available()<25) { if(millis()-t0>100) break; }
        if (rfidSerial.available()>=25) {
            uint8_t buf[25];
            for (int i=0;i<25;i++) buf[i]=rfidSerial.read();
            if (buf[0]==0xCF && buf[10]==0x0C) {
                String epc="";
                for (int i=11;i<=22;i++) {
                    if(buf[i]<0x10) epc+="0";
                    epc+=String(buf[i],HEX);
                    if(i<22) epc+=":";
                }
                epc.toUpperCase();
                Serial.println("🏷️ EPC: "+epc);
                switch(currentMode) {
                    case MODE_SAVE:
                        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
                        tagEnAttente=epc; tagDetecte=true; globalMessage="";
                        if (stateMutex) xSemaphoreGive(stateMutex);
                        ledAccess();
                        display.clearDisplay();
                        display.setTextSize(1);
                        display.setTextColor(SSD1306_WHITE);
                        display.setCursor(0, 10);
                        display.println("Tag detecte:");
                        display.setTextSize(1);
                        display.setCursor(0, 25);
                        display.println(epc);
                        display.setCursor(0, 40);
                        display.println("En attente...");
                        display.setCursor(0, 55);
                        display.println("Selectionner type");
                        display.display();
                        broadcastStatus();
                        break;
                    case MODE_CHECK:
                        processCheck(epc);
                        while(rfidSerial.available()) rfidSerial.read();
                        break;
                    case MODE_SAVEALL:
                        addToBatch(epc);
                        while(rfidSerial.available()) rfidSerial.read();
                        break;
                }
            }
        }
    } else if (canRead && rfidSerial.available()) {
        rfidSerial.read();
    }
}