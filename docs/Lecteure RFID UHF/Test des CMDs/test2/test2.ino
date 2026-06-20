#include <SoftwareSerial.h>

SoftwareSerial RFID(13, 15); // RX=D7, TX=D8

void setup() {
  Serial.begin(115200);
  RFID.begin(115200);
  delay(1000);
  Serial.println("=== EN ATTENTE ===");
}

void loop() {
  if (RFID.available()) {
    uint8_t b = RFID.read();
    Serial.printf("%02X ", b);
  }
}
