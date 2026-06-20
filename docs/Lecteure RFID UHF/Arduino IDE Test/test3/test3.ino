#include <SoftwareSerial.h>

SoftwareSerial rfidSerial(10, 11);

String dernierEPC = "";

void setup() {
  Serial.begin(9600);
  rfidSerial.begin(9600);
  Serial.println("=== Lecteur RFID UHF pret ===");
  Serial.println("Approche un tag...");
  Serial.println("==============================");
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

      if (buf[0] == 0xCF && buf[10] == 0x0C) {

        // Extraire EPC
        String epc = "";
        for (int i = 11; i <= 22; i++) {
          if (buf[i] < 0x10) epc += "0";
          epc += String(buf[i], HEX);
          if (i < 22) epc += ":";
        }
        epc.toUpperCase();

        // Affiche seulement si tag différent du précédent
        if (epc != dernierEPC) {
          Serial.println("==============================");
          Serial.print("TAG EPC : ");
          Serial.println(epc);
          Serial.println("==============================");
          dernierEPC = epc;
        }
      }
    }

  } else if (rfidSerial.available()) {
    rfidSerial.read();
  }
}