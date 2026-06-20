#include <SoftwareSerial.h>

SoftwareSerial rfidSerial(10, 11);

void setup() {
  Serial.begin(9600);
  rfidSerial.begin(9600);
  Serial.println("=== Lecteur RFID UHF pret ===");
  Serial.println("Approche un tag...");
  Serial.println("==============================");
}

void loop() {
  // Attend le header CF
  if (rfidSerial.available() && rfidSerial.peek() == 0xCF) {
    
    // Attend que les 25 octets arrivent (timeout 100ms)
    unsigned long startTime = millis();
    while (rfidSerial.available() < 25) {
      if (millis() - startTime > 100) break;
    }

    // Si on a bien 25 octets
    if (rfidSerial.available() >= 25) {
      
      uint8_t buf[25];
      for (int i = 0; i < 25; i++) {
        buf[i] = rfidSerial.read();
      }

      // Debug — affiche la trame brute
      Serial.print("TRAME: ");
      for (int i = 0; i < 25; i++) {
        if (buf[i] < 0x10) Serial.print("0");
        Serial.print(buf[i], HEX);
        Serial.print(" ");
      }
      Serial.println();

      // Vérifie header et longueur EPC
      if (buf[0] == 0xCF && buf[10] == 0x0C) {
        String epc = "";
        for (int i = 11; i <= 22; i++) {
          if (buf[i] < 0x10) epc += "0";
          epc += String(buf[i], HEX);
          if (i < 22) epc += ":";
        }
        epc.toUpperCase();

        Serial.println("------------------------------");
        Serial.print("TAG EPC : ");
        Serial.println(epc);
        Serial.println("------------------------------");
      }
    }
  } else if (rfidSerial.available()) {
    // Vide les octets parasites
    rfidSerial.read();
  }
}