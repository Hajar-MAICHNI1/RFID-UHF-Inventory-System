#include <HardwareSerial.h>

// ═══ Serial2 pour lecteur RFID ═══
HardwareSerial rfidSerial(2);
#define RXD2 16
#define TXD2 17

// ═══ LEDs + Buzzer ═══
#define LED_VERTE 18
#define LED_ROUGE 19
#define BUZZER    21

String dernierEPC = "";

void setup() {
  Serial.begin(115200);
  rfidSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);

  pinMode(LED_VERTE, OUTPUT);
  pinMode(LED_ROUGE, OUTPUT);
  pinMode(BUZZER,    OUTPUT);

  // Au démarrage → LED rouge
  digitalWrite(LED_ROUGE, HIGH);
  digitalWrite(LED_VERTE, LOW);
  digitalWrite(BUZZER,    LOW);

  Serial.println("=== Lecteur RFID UHF ESP32 ===");
  Serial.println("Approche un tag...");
  Serial.println("==============================");
}

// ═══ 1 bip court ═══
void bipCourt() {
  digitalWrite(BUZZER, HIGH);
  delay(100);
  digitalWrite(BUZZER, LOW);
}

void loop() {
  if (rfidSerial.available() && rfidSerial.peek() == 0xCF) {

    unsigned long startTime = millis();
    while (rfidSerial.available() < 25) {
      if (millis() - startTime > 100) break;
    }

    if (rfidSerial.available() >= 25) {

      uint8_t buf[25];
      for (int i = 0; i < 25; i++) {
        buf[i] = rfidSerial.read();
      }

      // Debug trame brute
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

          // LED VERTE + bip ✅
          digitalWrite(LED_ROUGE, LOW);
          digitalWrite(LED_VERTE, HIGH);
          bipCourt();

          delay(2000);

          // Retour LED ROUGE
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
