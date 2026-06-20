#include <HardwareSerial.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ═══ WiFi ═══
const char* ssid     = "ORANGE-DIGITAL-CENTER";
const char* password = "Welcome@2023";
const char* serverIP = "192.168.9.58";

// ═══ Serial2 pour lecteur RFID ═══
HardwareSerial rfidSerial(2);
#define RXD2 16
#define TXD2 17

// ═══ Toggle Switch ═══
#define SWITCH_PIN 4
// Switch ON  (LOW)  → SAVE mode  💾
// Switch OFF (HIGH) → CHECK mode 🔍

String dernierEPC = "";

void setup() {
  Serial.begin(115200);
  rfidSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);

  pinMode(SWITCH_PIN, INPUT_PULLUP);

  // Connect WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());
  Serial.println("=== Lecteur RFID UHF ESP32 ===");
  Serial.println("Switch ON  → 💾 SAVE mode");
  Serial.println("Switch OFF → 🔍 CHECK mode");
  Serial.println("==============================");
}

// ═══ CHECK → check.php ═══
String checkEPCinDB(String epc) {
  HTTPClient http;
  http.setTimeout(5000);
  String url = "http://" + String(serverIP) + "/Reader/check.php?epc=" + epc;
  Serial.println("Checking: " + url);
  http.begin(url);
  int httpCode = http.GET();
  String response = "";
  if (httpCode > 0) response = http.getString();
  http.end();
  return response;
}

// ═══ SAVE → save.php ═══
String saveEPCtoDB(String epc) {
  HTTPClient http;
  http.setTimeout(5000);
  String url = "http://" + String(serverIP) + "/Reader/save.php?epc=" + epc;
  Serial.println("Saving: " + url);
  http.begin(url);
  int httpCode = http.GET();
  String response = "";
  if (httpCode > 0) response = http.getString();
  http.end();
  return response;
}

void loop() {

  // ═══ Read switch position ═══
  bool saveMode = (digitalRead(SWITCH_PIN) == LOW);

  if (rfidSerial.available() && rfidSerial.peek() == 0xCF) {

    unsigned long startTime = millis();
    while (rfidSerial.available() < 25) {
      if (millis() - startTime > 100) break;
    }

    if (rfidSerial.available() >= 25) {

      uint8_t buf[25];
      for (int i = 0; i < 25; i++) buf[i] = rfidSerial.read();

      // Debug trame
      Serial.print("TRAME: ");
      for (int i = 0; i < 25; i++) {
        if (buf[i] < 0x10) Serial.print("0");
        Serial.print(buf[i], HEX);
        Serial.print(" ");
      }
      Serial.println();

      if (buf[0] == 0xCF && buf[10] == 0x0C) {

        String epc = "";
        for (int i = 11; i <= 22; i++) {
          if (buf[i] < 0x10) epc += "0";
          epc += String(buf[i], HEX);
          if (i < 22) epc += ":";
        }
        epc.toUpperCase();

        if (epc != dernierEPC) {
          dernierEPC = epc;

          Serial.println("------------------------------");
          Serial.print("TAG EPC : ");
          Serial.println(epc);

          // ═══════════════════════════════════
          // 💾 SAVE MODE (Switch ON)
          // ═══════════════════════════════════
          if (saveMode) {
            Serial.println("MODE: 💾 SAVE");
            Serial.println("------------------------------");
            String res = saveEPCtoDB(epc);
            Serial.println("Server response: " + res);

            if (res == "SAVED") {
              Serial.println("✅ Tag saved to database!");
            } else if (res == "DUPLICATE") {
              Serial.println("⚠️  Tag already exists, skipped.");
            } else {
              Serial.println("❌ Error: " + res);
            }

          // ═══════════════════════════════════
          // 🔍 CHECK MODE (Switch OFF)
          // ═══════════════════════════════════
          } else {
            Serial.println("MODE: 🔍 CHECK");
            Serial.println("------------------------------");
            String res = checkEPCinDB(epc);
            Serial.println("Server response: " + res);

            if (res == "FOUND") {
              Serial.println("✅ Tag EXISTS !");
            } else if (res == "NOT_FOUND") {
              Serial.println("❌ Tag NOT FOUND !");
            } else {
              Serial.println("⚠️ Erreur serveur : " + res);
            }
          }

          delay(2000);
          dernierEPC = "";
        }
      }
    }

  } else if (rfidSerial.available()) {
    rfidSerial.read();
  }
}