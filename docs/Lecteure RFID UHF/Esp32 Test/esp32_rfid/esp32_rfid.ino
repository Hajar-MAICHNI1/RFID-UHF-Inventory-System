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

// ═══ LEDs + Buzzer ═══
#define LED_VERTE 18
#define LED_ROUGE 19
#define BUZZER    21

String dernierEPC   = "";
String epcToSave    = "";   // EPC waiting to be saved on 2nd scan
bool   waitingSave  = false; // true = waiting for 2nd scan to save

void setup() {
  Serial.begin(115200);
  rfidSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);

  pinMode(LED_VERTE, OUTPUT);
  pinMode(LED_ROUGE, OUTPUT);
  pinMode(BUZZER,    OUTPUT);

  digitalWrite(LED_ROUGE, HIGH);
  digitalWrite(LED_VERTE, LOW);
  digitalWrite(BUZZER,    LOW);

  // Connect WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());
  Serial.println("=== Lecteur RFID UHF ESP32 ===");
  Serial.println("1st scan = CHECK | 2nd scan = SAVE");
  Serial.println("==============================");
}

void bipCourt() {
  digitalWrite(BUZZER, HIGH);
  delay(100);
  digitalWrite(BUZZER, LOW);
}

void bipDouble() {
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);  delay(100);
  digitalWrite(BUZZER, HIGH); delay(100);
  digitalWrite(BUZZER, LOW);
}

// ═══ CHECK: call check.php ═══
String checkEPCinDB(String epc) {
  HTTPClient http;
  String url = "http://" + String(serverIP) + "/Reader/check.php?epc=" + epc;
  Serial.println("Checking: " + url);
  http.begin(url);
  int httpCode = http.GET();
  String response = "";
  if (httpCode > 0) {
    response = http.getString();
  }
  http.end();
  return response;
}

// ═══ SAVE: call save.php ═══
String saveEPCtoDB(String epc) {
  HTTPClient http;
  String url = "http://" + String(serverIP) + "/Reader/save.php?epc=" + epc;
  Serial.println("Saving: " + url);
  http.begin(url);
  int httpCode = http.GET();
  String response = "";
  if (httpCode > 0) {
    response = http.getString();
  }
  http.end();
  return response;
}

void loop() {
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
          Serial.println("------------------------------");

          // ═══════════════════════════════════════
          // 2nd SCAN → SAVE
          // ═══════════════════════════════════════
          if (waitingSave && epc == epcToSave) {
            Serial.println(">>> 2nd scan detected → SAVING...");
            String res = saveEPCtoDB(epc);
            Serial.println("Server response: " + res);

            if (res == "SAVED") {
              Serial.println("✅ Tag saved to database!");
              // Double bip + green LED
              digitalWrite(LED_ROUGE, LOW);
              digitalWrite(LED_VERTE, HIGH);
              bipDouble();
            } else if (res == "DUPLICATE") {
              Serial.println("⚠️  Tag already exists!");
              bipCourt();
            } else {
              Serial.println("❌ Error saving tag.");
            }

            waitingSave = false;
            epcToSave   = "";

          // ═══════════════════════════════════════
          // 1st SCAN → CHECK
          // ═══════════════════════════════════════
          } else {
            Serial.println(">>> 1st scan detected → CHECKING...");
            String res = checkEPCinDB(epc);
            Serial.println("Server response: " + res);

            if (res == "FOUND") {
              Serial.println("✅ Tag EXISTS in database!");
              Serial.println(">>> Scan again to save it anyway.");
            } else {
              Serial.println("❌ Tag NOT FOUND in database!");
              Serial.println(">>> Scan again to save it.");
            }

            // Remember this EPC for 2nd scan
            waitingSave = true;
            epcToSave   = epc;
            bipCourt();
          }

          // LED feedback
          digitalWrite(LED_ROUGE, LOW);
          digitalWrite(LED_VERTE, HIGH);
          delay(2000);
          digitalWrite(LED_VERTE, LOW);
          digitalWrite(LED_ROUGE, HIGH);
          dernierEPC = "";
        }
      }
    }

  } else if (rfidSerial.available()) {
    rfidSerial.read();
  }
}
