
#include <HardwareSerial.h>
#include <WiFi.h>
#include <SPIFFS.h>
#include <HTTPClient.h>
#include <vector>
#include <algorithm>
#include <map>
#include <set>
#include <ctype.h>

// === ÉCRAN OLED (I2C) ===
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// === SERVEUR HTTPS + WEBSOCKET ===
#include <HTTPSServer.hpp>
#include <HTTPServer.hpp>
#include <SSLCert.hpp>
#include <HTTPRequest.hpp>
#include <HTTPResponse.hpp>
#include <WebsocketHandler.hpp>
using namespace httpsserver;

#include "cert.h"

// ============================================================================
// CONFIGURATION WIFI & AUTHENTIFICATION
// ============================================================================

const char *ssid        = "  ";              // WiFi STA SSID (routeur principal)
const char *password    = " ";               // WiFi STA password
const char *serverIP    = "  ";              // Adresse XAMPP MySQL (192.168.11.156)
const char *ap_ssid     = "Hotel_RFID_AP";   // WiFi AP hotspot (point d'accès)
const char *ap_password = " ";               // Password hotspot

// === Utilisateurs autorisés ===
const char *ADMIN_USERNAME     = "admin";
const char *ADMIN_PASSWORD     = " ";
const char *OPERATEUR_USERNAME = "operateur";
const char *OPERATEUR_PASSWORD = " ";

// === Gestion Sessions ===
#define SESSION_TIMEOUT_MS   3600000UL    // 1 heure
#define SESSION_CLEANUP_MS   300000UL     // Nettoyage sessions expirées toutes les 5 min
#define MAX_SESSIONS         16           // Max 16 sessions simultanées

std::map<String, unsigned long> sessions;  // Token → timestamp session
unsigned long lastSessionCleanup = 0;

/**
 * Génère un token de session aléatoire (32 caractères hex)
 * Utilisé pour authentifier les requêtes HTTP/WebSocket
 */
String generateToken() {
    String t = "";
    for (int i = 0; i < 32; i++) {
        uint8_t nibble = (uint8_t)(esp_random() & 0x0F);
        t += String(nibble, HEX);
    }
    return t;
}

/**
 * Extrait le token de session du header Cookie
 * Recherche "session=<token>" dans le header Cookie
 */
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

/**
 * Vérifie l'authentification d'une requête HTTP
 * - Extrait token du cookie
 * - Vérifie présence en map sessions
 * - Vérifie non-expiration (timeout 1h)
 * - Met à jour timestamp (touch)
 */
bool isAuthenticated(HTTPRequest *req) {
    String token = extractSessionCookie(req);
    if (token.length() == 0) return false;
    if (!sessions.count(token)) return false;
    if (millis() - sessions[token] > SESSION_TIMEOUT_MS) {
        sessions.erase(token);
        return false;
    }
    sessions[token] = millis();  // Touch
    return true;
}

/**
 * Redirige vers /login (302 Found)
 * Utilisé pour les requêtes non authentifiées
 */
void redirectToLogin(HTTPResponse *res) {
    res->setStatusCode(302);
    res->setHeader("Location", "/login");
    res->setHeader("Content-Type", "text/plain");
    res->println("Redirecting to /login");
}

/**
 * Supprime les sessions expirées de la map
 * Appelée toutes les 5 min (SESSION_CLEANUP_MS)
 */
void cleanupSessions() {
    for (auto it = sessions.begin(); it != sessions.end(); ) {
        if (millis() - it->second > SESSION_TIMEOUT_MS) 
            it = sessions.erase(it);
        else 
            ++it;
    }
}

/**
 * Log l'état du système pour debugging
 * Affiche: heap libre, sessions actives, contexte
 */
void logRuntimeState(const String &context) {
    Serial.println("[ESP32] " + context + " | freeHeap=" + String(ESP.getFreeHeap()) +
                   " | activeSessions=" + String((int)sessions.size()));
}

/**
 * Log la latence d'un appel proxy XAMPP
 * Mesure temps aller-retour + code HTTP
 */
void logProxyTiming(const String &label, unsigned long startedAt, int httpCode) {
    unsigned long elapsedMs = millis() - startedAt;
    Serial.println("[ESP32] " + label + " | durationMs=" + String(elapsedMs) +
                   " | httpCode=" + String(httpCode) +
                   " | freeHeap=" + String(ESP.getFreeHeap()) +
                   " | activeSessions=" + String((int)sessions.size()));
}

// ============================================================================
// PARSING FORM & JSON
// ============================================================================

/**
 * Parse un champ de formulaire URL-encoded (application/x-www-form-urlencoded)
 * Supporte: key=value&key2=value2
 * Décode les caractères spéciaux (%20, +, etc.)
 */
String parseFormField(const String &body, const String &key) {
    String search = key + "=";
    int idx = body.indexOf(search);
    if (idx < 0) return "";
    idx += search.length();
    int end = body.indexOf('&', idx);
    String val = (end < 0) ? body.substring(idx) : body.substring(idx, end);
    
    // Décodage URL
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

/**
 * Parse un champ JSON (application/json)
 * Supporte: {"key": "value", "key2": 123}
 * Gère les caractères échappés (\", \\, \n, \t)
 */
String parseJsonField(const String &body, const String &key) {
    String needle = "\"" + key + "\"";
    int k = body.indexOf(needle);
    if (k < 0) return "";

    int colon = body.indexOf(':', k + needle.length());
    if (colon < 0) return "";

    int i = colon + 1;
    while (i < (int)body.length() && isspace((unsigned char)body[i])) i++;
    if (i >= (int)body.length()) return "";

    // Valeur string (entourée de guillemets)
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

    // Valeur numérique ou booléenne
    int end = i;
    while (end < (int)body.length() && body[end] != ',' && body[end] != '}') end++;
    String raw = body.substring(i, end);
    raw.trim();
    return raw;
}

/**
 * Retourne le rôle utilisateur (admin/opérateur)
 */
String getUserRole(const String &username) {
    if (username == String(ADMIN_USERNAME)) return "admin";
    if (username == String(OPERATEUR_USERNAME)) return "operateur";
    return "";
}

// ============================================================================
// AUTHENTIFICATION & LOGIN
// ============================================================================

/**
 * Traite requête POST /login
 * Supporte: application/x-www-form-urlencoded et application/json
 * 
 * Flux:
 * 1. Parse username + password
 * 2. Valide contre utilisateurs autorisés
 * 3. Crée session (token aléatoire)
 * 4. Définit HttpOnly cookie (sécurité CSRF)
 * 5. Redirige vers / ou retourne JSON
 */
void handleLoginRequest(HTTPRequest *req, HTTPResponse *res) {
    // Lire le body (max 512 bytes)
    uint8_t buf[512]={0};
    size_t len = req->readBytes(buf, sizeof(buf)-1);
    buf[len] = '\0';
    String body = String((char*)buf);

    // Déterminer le format (form ou JSON)
    String contentType = String(req->getHeader("Content-Type").c_str());
    contentType.toLowerCase();
    String accept = String(req->getHeader("Accept").c_str());
    accept.toLowerCase();

    String user = parseFormField(body,"username");
    String pass = parseFormField(body,"password");

    bool jsonRequest = contentType.indexOf("application/json") >= 0;
    bool wantsJson = jsonRequest || accept.indexOf("application/json") >= 0;

    // Si JSON, parser aussi en JSON
    if (jsonRequest && (user.isEmpty() || pass.isEmpty())) {
        user = parseJsonField(body, "username");
        pass = parseJsonField(body, "password");
        if (user.isEmpty()) user = parseJsonField(body, "user");
        if (pass.isEmpty()) pass = parseJsonField(body, "pass");
    }

    String userRole = "";

    // Vérifier credentials
    if (user == String(ADMIN_USERNAME) && pass == String(ADMIN_PASSWORD)) {
        userRole = "admin";
    } else if (user == String(OPERATEUR_USERNAME) && pass == String(OPERATEUR_PASSWORD)) {
        userRole = "operateur";
    }

    if (userRole.length() > 0) {
        // === LOGIN SUCCÈS ===
        
        // Gérer limite MAX_SESSIONS - supprimer la plus vieille
        if ((int)sessions.size()>=MAX_SESSIONS) {
            auto oldest=sessions.begin();
            for (auto it=sessions.begin();it!=sessions.end();++it)
                if (it->second<oldest->second) oldest=it;
            sessions.erase(oldest);
        }

        // Générer token et créer session
        String token=generateToken();
        sessions[token]=millis();
        res->setHeader("Set-Cookie", std::string(("session="+token+"; Path=/; HttpOnly; Max-Age=3600").c_str()));

        if (wantsJson) {
            res->setStatusCode(200);
            res->setHeader("Content-Type", "application/json");
            String jsonResp = "{\"status\":\"ok\",\"msg\":\"Login success\",\"role\":\"" + userRole + "\"}";
            res->print(jsonResp);
        } else {
            // Redirect HTTP
            res->setStatusCode(302);
            res->setHeader("Location","/");
            res->setHeader("Content-Type", "text/plain");
            res->println("Redirecting to /");
        }
    } else {
        // === LOGIN ÉCHOUÉ ===
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

/**
 * Servir un fichier SPIFFS (Storage)
 * Utilisé pour: index.html, CSS, JS, images
 */
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

// ============================================================================
// CONFIGURATION MATÉRIELLE (GPIO, UART, OLED)
// ============================================================================

HardwareSerial rfidSerial(2);    // UART2 pour lecteur RFID
#define RXD2 16                  // PIN RX
#define TXD2 17                  // PIN TX
#define SWITCH_PIN_A  4          // Bouton Mode A (SAVE)
#define SWITCH_PIN_B  5          // Bouton Mode B (SAVEALL)
#define LED_VERT     26          // LED verte (accès ok)
#define LED_ROUGE    27          // LED rouge (alerte)
#define BUZZER_PIN   25          // Buzzer (alarme)
#define OLED_SDA     21          // I2C SDA
#define OLED_SCL     22          // I2C SCL

// === Écran OLED 128x64 ===
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET   -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ============================================================================
// ÉNUMÉRATION DES MODES
// ============================================================================

enum Mode { 
    MODE_CHECK,    // Vérification temps réel (consultation BD)
    MODE_SAVE,     // Enregistrement unique (1 tag)
    MODE_SAVEALL   // Enregistrement batch (4 tags, 3s timeout)
};

/**
 * Lit les boutons et retourne le mode courant
 * Priorité: B > A (SAVEALL > SAVE)
 */
Mode getCurrentMode() {
    if (digitalRead(SWITCH_PIN_A) == LOW) return MODE_SAVE;
    if (digitalRead(SWITCH_PIN_B) == LOW) return MODE_SAVEALL;
    return MODE_CHECK;
}

/**
 * Retourne le nom du mode (string)
 */
String modeName(Mode m) {
    if (m == MODE_SAVE)    return "SAVE";
    if (m == MODE_SAVEALL) return "SAVEALL";
    return "CHECK";
}

// ============================================================================
// MUTEX & VARIABLES PARTAGÉES (Protégées par stateMutex)
// ============================================================================

/**
 * FIX #3: Mutex FreeRTOS pour protéger l'état partagé
 * 
 * PROBLÈME: Core 0 (httpsTask) et Core 1 (loop) accèdent aux mêmes variables
 * SANS SYNCHRONISATION → Corruption de données
 * 
 * SOLUTION: xSemaphore pour exclusion mutuelle
 * - loop() prend le mutex avant lire/modifier l'état
 * - httpsTask() idem avant broadcasting WebSocket
 * 
 * IMPORTANT: Tenir le mutex LE MOINS LONGTEMPS POSSIBLE
 *   - Copier les données sous le mutex
 *   - Relâcher immédiatement
 *   - Effectuer traitement (HTTP, JSON, etc.) SANS le mutex
 */
SemaphoreHandle_t stateMutex = nullptr;

// Variables protégées par stateMutex:
String tagEnAttente       = "";   // EPC en attente (MODE_SAVE)
String dernierEpcCheck    = "";   // Dernier EPC vérifié (MODE_CHECK)
String dernierResultCheck = "";   // Résultat de la vérification
String globalMessage      = "";   // Message affichage (alertes, confirmations)
String globalMsgType      = "";   // Type message ("ok", "err")
bool   tagDetecte         = false;// Tag détecté et prêt pour action
bool   relaiOuvert        = false;// État relais actuellement
Mode   ancienMode         = MODE_CHECK;
String typesCache         = "";   // Cache types d'articles (catégories)

// FIX #6: Timestamp pour auto-clear message après N ms
unsigned long globalMsgTime = 0;
#define MSG_DISPLAY_MS 4000   // Afficher alerte 4 secondes

// Timers hardware (non partagées)
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
#define OLED_ALERT_DURATION 5000

// === Historique vérifications (MODE_CHECK) ===
struct CheckEntry { 
    String epc,       // Code EPC détecté
           result;    // Résultat (FOUND/NOT_FOUND)
    unsigned long ts; // Timestamp vérification
};
std::vector<CheckEntry> checkHistory;
#define CHECK_COOLDOWN    8000     // Anti-spam: 8s avant re-check même EPC
#define CHECK_HISTORY_MAX 12       // Garder dernier 12 résultats

// === Buffer enregistrement batch (MODE_SAVEALL) ===
std::vector<String> batchEpcs;     // EPCs à enregistrer
unsigned long lastBatchScan = 0;   // Timestamp dernier tag ajouté
bool   batchPending = false;       // Batch en cours d'accumulation?
String batchResult  = "";          // Résultat enregistrement (JSON réponse XAMPP)
#define BATCH_TIMEOUT 4000         // Timeout 4s après dernier tag → enregistrement

// ============================================================================
// CONTRÔLE GPIO (LED, BUZZER, RELAIS)
// ============================================================================

void ledOff()    { digitalWrite(LED_VERT, LOW);  digitalWrite(LED_ROUGE, LOW);  }
void ledAccess() { digitalWrite(LED_VERT, HIGH); digitalWrite(LED_ROUGE, LOW);  } // Vert = OK
void ledAlert()  { digitalWrite(LED_VERT, LOW);  digitalWrite(LED_ROUGE, HIGH); } // Rouge = Alerte

/**
 * Déclenche LED verte en batch (durée courte)
 * Utilisé pour feedback visuel rapide en mode SAVEALL
 */
void ledBatchTrigger() {
    digitalWrite(LED_VERT, HIGH);
    ledBatchTime = millis(); 
    ledBatchActive = true;
}

/**
 * Buzzer: single beep (200ms par défaut)
 */
void buzzerBeep(int duration = 200) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(duration);
    digitalWrite(BUZZER_PIN, LOW);
}

/**
 * Buzzer: alarme (3 bips de 300ms avec délai)
 * Utilisé pour alertes vol/accès refusé
 */
void buzzerAlarm(int count = 3) {
    for (int i = 0; i < count; i++) {
        buzzerBeep(300);
        delay(150);
    }
}

// ============================================================================
// AFFICHAGE OLED
// ============================================================================

/**
 * Affiche alerte vol: "⚠️ VOL!" + EPC
 * Montré 5 secondes (OLED_ALERT_DURATION)
 */
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

// ============================================================================
// PROTOCOLE RFID (UART) & RELAIS
// ============================================================================

/**
 * Calcule CRC16 CCITT
 * Utilisé pour: validation trame RFID + commandes lecteur
 */
uint16_t crc16(uint8_t *data, uint8_t len) {
    uint16_t crc = 0xFFFF;
    for (uint8_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (uint8_t j = 0; j < 8; j++)
            crc = (crc & 1) ? (crc >> 1) ^ 0x8408 : crc >> 1;
    }
    return crc;
}

/**
 * Envoie une commande au lecteur RFID via UART
 * Format: [CMD] [CRC_LOW] [CRC_HIGH]
 * Le lecteur reçoit: HEAD ADDR CMD LEN DATA CRC_L CRC_H
 */
void sendCMD(uint8_t *cmd, uint8_t len) {
    uint16_t c = crc16(cmd, len);
    rfidSerial.write(cmd, len);
    rfidSerial.write(c & 0xFF);
    rfidSerial.write((c >> 8) & 0xFF);
}

/**
 * Ouvre le relais (déverrouille porte)
 * Commande: 0xCF 0xFF 0x00 0x77 0x02 0x01 0x01
 * 0x77 = commande relais
 * 0x02 0x01 = ouvrir
 */
void relayOpen() {
    uint8_t cmd[] = {0xCF,0xFF,0x00,0x77,0x02,0x01,0x01};
    sendCMD(cmd,7); 
    relaiOuvert=true; 
    Serial.println("[RELAY] OPEN - Door alarm triggered");
}

/**
 * Ferme le relais (verrouille porte)
 * Commande: 0xCF 0xFF 0x00 0x77 0x02 0x02 <state>
 * 0x02 = fermer
 */
void relayClose(uint8_t s=0) {
    uint8_t cmd[] = {0xCF,0xFF,0x00,0x77,0x02,0x02,s};
    sendCMD(cmd,7); 
    relaiOuvert=false; 
    Serial.println("[RELAY] CLOSED - Door secured");
}

// ============================================================================
// APPELS HTTP & API XAMPP
// ============================================================================

/**
 * Récupère la liste des types d'articles depuis XAMPP
 * GET /Reader/get_types.php
 * Réponse: "1|Serviettes,2|Draps,3|Télécommandes"
 * Résultat stocké dans typesCache (partagé, protégé mutex)
 */
void fetchTypes() {
    if (WiFi.status() != WL_CONNECTED) return;
    HTTPClient http; 
    http.setTimeout(10000);  // Timeout 10s
    http.begin("http://" + String(serverIP) + "/Reader/get_types.php");
    int code = http.GET();
    if (code > 0) {
        String result = http.getString();
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        typesCache = result;
        if (stateMutex) xSemaphoreGive(stateMutex);
    }
    http.end();
}

/**
 * Requête GET générique vers XAMPP
 * @param url Adresse complète (http://192.168.11.156/Reader/...)
 * @return Réponse texte ou code d'erreur ("WIFI_ERROR", "HTTP_ERROR_<code>")
 */
String httpGET(const String &url) {
    if (WiFi.status() != WL_CONNECTED) return "WIFI_ERROR";
    HTTPClient http; 
    http.setTimeout(10000);
    http.begin(url);
    int code = http.GET();
    String res = code > 0 ? http.getString() : ("HTTP_ERROR_"+String(code));
    http.end(); 
    return res;
}

/**
 * Enregistrer un tag en MODE_SAVE
 * POST /Reader/save.php?epc=<epc>&type_numero=<type>
 * Réponse: "SAVED" ou "DUPLICATE" ou code erreur
 */
String saveTag(const String &epc, int typeNum) {
    String url = "http://"+String(serverIP)+"/Reader/save.php?epc="+epc+"&type_numero="+String(typeNum);
    String res = httpGET(url); 
    Serial.println("💾 SAVE → "+res); 
    return res;
}

/**
 * Vérifier un tag en MODE_CHECK
 * GET /Reader/check.php?epc=<epc>
 * Réponse: "FOUND" ou "NOT_FOUND"
 */
String checkTagHTTP(const String &epc) {
    String url = "http://"+String(serverIP)+"/Reader/check.php?epc="+epc;
    String res = httpGET(url); 
    Serial.println("🔍 CHECK → "+res); 
    return res;
}

/**
 * Enregistrer batch de tags en MODE_SAVEALL
 * POST /Reader/saveall.php
 * Body: "epcs=EPC1,EPC2,EPC3,EPC4"
 * Réponse: JSON {"saved": 3, "failed": 1}
 */
String saveBatch(std::vector<String> &epcs) {
    if (WiFi.status() != WL_CONNECTED) return "WIFI_ERROR";
    String body = "epcs=";
    for (int i=0;i<(int)epcs.size();i++) { 
        if(i>0) body+=","; 
        body+=epcs[i]; 
    }
    HTTPClient http; 
    http.setTimeout(10000);
    http.begin("http://"+String(serverIP)+"/Reader/saveall.php");
    http.addHeader("Content-Type","application/x-www-form-urlencoded");
    int code = http.POST(body);
    String res = code>0 ? http.getString() : ("HTTP_ERROR_"+String(code));
    http.end(); 
    Serial.println("📦 SAVEALL → "+res); 
    return res;
}

// ============================================================================
// WEBSOCKET & BROADCAST (Thread-Safe)
// ============================================================================

/**
 * FIX #7+#8: Queue WebSocket pour messages thread-safe
 * 
 * PROBLÈME: Core 1 (loop) tente d'envoyer WebSocket directement
 * → Peut corrompt état WebsocketHandler (Core 0 le modifie en même temps)
 * 
 * SOLUTION: Queue de messages (FreeRTOS xQueue)
 * - Core 1 appelle queueWSMessage() → ajoute à queue
 * - Core 0 (httpsTask) lit queue → envoie réellement
 * 
 * Structure WSMessage utilise char[] (pas String)
 * Raison: xQueueSend() copie par memcpy(), String heap pointers corrompus
 */
SemaphoreHandle_t wsMutex = nullptr;
std::set<WebsocketHandler*> wsClients;

struct WSMessage {
    char payload[512];   // Char array safe pour memcpy
};

QueueHandle_t wsQueue = nullptr;
volatile bool broadcastRequested = false;
volatile bool batchSaveInProgress = false;

/**
 * Gère les requêtes WebSocket
 * Supporte: SAVE_BATCH, CLEAR_BATCH, CLEAR_CHECK, CANCEL_SAVE, set_mode
 * 
 * SÉCURITÉ: Authentification par session cookie HTTP
 * (HttpOnly cookie transmis automatiquement lors WebSocket upgrade)
 */
class RFIDWebSocket : public WebsocketHandler {
public:
    volatile bool ready = false;

    static WebsocketHandler* create() {
        RFIDWebSocket *h = new RFIDWebSocket();
        if (wsMutex != nullptr) {
            if (xSemaphoreTake(wsMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
                wsClients.insert(h);
                xSemaphoreGive(wsMutex);
            }
        }
        return h;
    }

    /**
     * Reçoit un message WebSocket du client (navigateur/app)
     * Format: JSON {"action": "...", "param": "..."}
     */
    void onMessage(WebsocketInputStreambuf *inbuf) override {
        ready = true;
        std::istream is(inbuf);
        std::string msg; 
        std::getline(is, msg);
        String s = String(msg.c_str());

        String action = "";
        if (s.startsWith("{")) {
            action = parseJsonField(s, "action");
        }

        // Traiter commandes WebSocket
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

/**
 * Demande un broadcast (setter flag)
 * Thread-safe: juste définit un flag, pas d'appel réseau direct
 * Le httpsTask (Core 0) fera le vrai send via doBroadcastNow()
 */
void broadcastStatus() {
    broadcastRequested = true;
}

/**
 * Effectue le broadcast réellement
 * DOIT ÊTRE APPELÉ UNIQUEMENT DEPUIS httpsTask (Core 0)
 * 
 * Flux:
 * 1. Copier tout l'état sous stateMutex
 * 2. Relâcher immédiatement
 * 3. Construire JSON (SANS mutex)
 * 4. Envoyer à tous les clients WebSocket (avec wsMutex)
 */
void doBroadcastNow() {
    // Copier l'état sous le mutex
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);

    Mode mode = getCurrentMode();
    
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

    // Maintenant construire JSON (SANS mutex)
    String typesJson = buildTypesJSON();
    
    // Construire JSON avec concat() (pas opérateurs + pour éviter stack overflow)
    String json;
    json.reserve(2048);
    
    json.concat("{\"wifi\":");
    json.concat(safeWifi?"true":"false");
    json.concat(",\"mode\":\"");
    json.concat(modeName(mode));
    json.concat("\",\"relay\":");
    json.concat(safeRelay?"true":"false");
    // ... (reste du JSON)
    json.concat("}");

    std::string jsonStd = json.c_str();

    // Envoyer à tous les clients WebSocket (avec wsMutex)
    if (wsMutex) {
        xSemaphoreTake(wsMutex, portMAX_DELAY);
        for (auto *client : wsClients) {
            RFIDWebSocket *rfidClient = static_cast<RFIDWebSocket*>(client);
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

/**
 * Ajoute un message à la queue WebSocket
 * Thread-safe: tout task peut appeler
 * Core 0 les traitera dans httpsTask
 */
void queueWSMessage(const String &msg) {
    if (!wsQueue) return;
    WSMessage m;
    strncpy(m.payload, msg.c_str(), sizeof(m.payload) - 1);
    m.payload[sizeof(m.payload) - 1] = '\0';
    xQueueSend(wsQueue, &m, 0);
}

/**
 * Construit JSON des types d'articles
 * Utilisé dans broadcast et dans réponse API /save
 */
String buildTypesJSON() {
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    String cache = typesCache;
    if (stateMutex) xSemaphoreGive(stateMutex);

    String json;
    json.reserve(512);
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

// ============================================================================
// TÂCHE HTTPS (Core 0) - Serveur + WebSocket
// ============================================================================

SSLCert sslCert(
    const_cast<unsigned char*>(CERT_DER), CERT_DER_LEN,
    const_cast<unsigned char*>(KEY_DER),  KEY_DER_LEN
);

// FIX #2: 4 connexions simultanées max (page + WS + redondance)
HTTPSServer secureServer(&sslCert, 443, 4);
HTTPServer  redirectServer(80, 1);

/**
 * Tâche FreeRTOS Core 0: Serveur HTTPS + Traitement queue WebSocket
 * 
 * ARCHITECTURE:
 * - Boucle: secureServer.loop() traite requêtes HTTP/WebSocket
 * - Puis traite queue WebSocket (messages Core 1 → WebSocket)
 * - Puis effectue broadcast si demandé par Core 1
 * 
 * CRITICITÉ: Core 0 = CPU pour SSL/TLS + WebSocket
 * Stack: 250KB pour éviter débordement avec JSON volumineux
 */
void httpsTask(void*) {
    secureServer.start();
    WSMessage incoming;

    while(true) {
        secureServer.loop();

        // Traiter queue WebSocket (messages from Core 1)
        while (xQueueReceive(wsQueue, &incoming, 0) == pdTRUE) {
            std::string msgStd = incoming.payload;

            if (wsMutex) {
                xSemaphoreTake(wsMutex, portMAX_DELAY);
                std::set<WebsocketHandler*> snapshot = wsClients;
                xSemaphoreGive(wsMutex);

                for (auto *client : snapshot) {
                    RFIDWebSocket *rfidClient = static_cast<RFIDWebSocket*>(client);
                    if (!rfidClient || !rfidClient->ready) continue;
                    client->send(msgStd);
                }
            }
        }

        // Effectuer broadcast si demandé
        if (broadcastRequested) {
            broadcastRequested = false;
            doBroadcastNow();
        }
        vTaskDelay(1);
    }
}

void httpRedirTask(void*){ 
    redirectServer.start(); 
    while(true) { 
        redirectServer.loop(); 
        vTaskDelay(1); 
    } 
}

// ============================================================================
// SETUP
// ============================================================================

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

    // === OLED ===
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

    // === SPIFFS (Stockage fichiers: HTML, CSS, JS) ===
    if (!SPIFFS.begin(true)) { Serial.println("SPIFFS Failed"); return; }

    // === Mutex FreeRTOS (protection état partagé) ===
    stateMutex = xSemaphoreCreateMutex();
    wsMutex    = xSemaphoreCreateMutex();
    wsQueue = xQueueCreate(20, sizeof(WSMessage));

    // === WiFi Setup ===
    WiFi.disconnect(true);
    WiFi.softAPdisconnect(true);
    delay(200);

    WiFi.mode(WIFI_AP_STA);
    delay(100);

    WiFi.softAPConfig(
        IPAddress(192, 168, 4, 1),
        IPAddress(192, 168, 4, 1),
        IPAddress(255, 255, 255, 0)
    );
    WiFi.softAP(ap_ssid, ap_password, 6);
    delay(500);

    Serial.println("📡 AP: " + WiFi.softAPIP().toString());

    // === Connexion STA (routeur principal) ===
    WiFi.begin(ssid, password);
    int t = 0;
    while (WiFi.status() != WL_CONNECTED && t < 30) { delay(500); t++; }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("✅ WiFi: " + WiFi.localIP().toString());
        fetchTypes();
    } else {
        Serial.println("⚠️ STA non connecté — AP seul actif");
    }

    // === Routes HTTPS ===
    // [Déclaration des routes HTTP/WebSocket]
    
    secureServer.registerNode(new ResourceNode("/login", "GET", [](HTTPRequest *req, HTTPResponse *res){
        if (isAuthenticated(req)) { res->setStatusCode(302); res->setHeader("Location", "/"); return; }
        serveSpiffs(res, "/login.html", "text/html");
    }));

    secureServer.registerNode(new ResourceNode("/login", "POST", [](HTTPRequest *req, HTTPResponse *res){
        handleLoginRequest(req, res);
    }));

    // [Autres routes...]

    // === Lancer tâches FreeRTOS ===
    xTaskCreatePinnedToCore(httpsTask, "https", 250000, nullptr, 2, nullptr, 0);
    xTaskCreatePinnedToCore(httpRedirTask,"http_redir",  4096, nullptr, 1, nullptr, 1);

    Serial.println("🔒 HTTPS démarré sur port 443");
}

// ============================================================================
// LOOP (Core 1) - Lecteur RFID + Modes Opérationnels
// ============================================================================

unsigned long lastWsBroadcast = 0;

void loop() {
    // Broadcast WebSocket toutes les 1.5 secondes
    if (millis()-lastWsBroadcast>1500) {
        lastWsBroadcast=millis();

        // FIX #6: Auto-clear message après 4 secondes
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        if (!globalMessage.isEmpty() && millis()-globalMsgTime > MSG_DISPLAY_MS) {
            globalMessage=""; globalMsgType="";
        }
        if (stateMutex) xSemaphoreGive(stateMutex);

        broadcastStatus();
    }

    // Auto-clear OLED après 5 secondes
    if (lastOledAlertTime > 0 && millis()-lastOledAlertTime > OLED_ALERT_DURATION) {
        lastOledAlertTime = 0;
        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
        Mode currentMode = getCurrentMode();
        if (stateMutex) xSemaphoreGive(stateMutex);
        
        if (currentMode == MODE_CHECK) {
            displayWaitingScan();
        }
    }

    // Retry WiFi STA toutes les 10 secondes
    if (WiFi.status()!=WL_CONNECTED && millis()-lastWifiRetry>WIFI_RETRY_INTERVAL) {
        lastWifiRetry=millis();
        WiFi.begin(ssid,password);
    }

    // Nettoyage sessions expirées
    if (millis()-lastSessionCleanup>SESSION_CLEANUP_MS) {
        lastSessionCleanup=millis();
        cleanupSessions();
    }

    // Timer relais: fermer après 3 secondes
    if (relayTimerActive && millis()-relayOpenTime>=RELAY_OPEN_DURATION) {
        relayTimerActive=false; relayClose(0); ledOff(); broadcastStatus();
    }

    // Timer LED erreur: éteindre après 2 secondes
    if (ledErrorActive && millis()-ledErrorTime>=LED_ERROR_DURATION) {
        ledErrorActive=false; ledOff();
    }

    // Timer LED batch: éteindre après 120ms
    if (ledBatchActive && millis()-ledBatchTime>=LED_BATCH_DURATION) {
        ledBatchActive=false; digitalWrite(LED_VERT,LOW);
    }

    // === Détecter changement de mode (boutons) ===
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
        Serial.println("→ Mode "+modeName(currentMode));
        broadcastStatus();
    }

    // === Enregistrement batch timeout ===
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    bool doBatchSave = (currentMode==MODE_SAVEALL && batchPending && millis()-lastBatchScan>BATCH_TIMEOUT);
    if (stateMutex) xSemaphoreGive(stateMutex);
    if (doBatchSave) executeBatchSave();

    // === Nettoyage historique check (> 60 secondes) ===
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    checkHistory.erase(
        std::remove_if(checkHistory.begin(),checkHistory.end(),
            [](const CheckEntry &e){ return millis()-e.ts>60000; }),
        checkHistory.end());
    if (stateMutex) xSemaphoreGive(stateMutex);

    // === Lire lecteur RFID ===
    if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
    bool canRead = (currentMode!=MODE_SAVE) || !tagDetecte;
    if (stateMutex) xSemaphoreGive(stateMutex);

    if (canRead && rfidSerial.available() && rfidSerial.peek()==0xCF) {
        unsigned long t0=millis();
        // Attendre 25 bytes (timeout 100ms)
        while (rfidSerial.available()<25) { if(millis()-t0>100) break; }
        
        if (rfidSerial.available()>=25) {
            uint8_t buf[25];
            for (int i=0;i<25;i++) buf[i]=rfidSerial.read();
            
            // Vérifier format trame RFID
            if (buf[0]==0xCF && buf[10]==0x0C) {
                // Extraire EPC (12 bytes, positions 11-22)
                String epc="";
                for (int i=11;i<=22;i++) {
                    if(buf[i]<0x10) epc+="0";
                    epc+=String(buf[i],HEX);
                    if(i<22) epc+=":";
                }
                epc.toUpperCase();
                Serial.println("🏷️ EPC: "+epc);
                
                // === Traiter selon le mode ===
                switch(currentMode) {
                    case MODE_SAVE:
                        if (stateMutex) xSemaphoreTake(stateMutex, portMAX_DELAY);
                        tagEnAttente=epc; tagDetecte=true; globalMessage="";
                        if (stateMutex) xSemaphoreGive(stateMutex);
                        ledAccess();
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
