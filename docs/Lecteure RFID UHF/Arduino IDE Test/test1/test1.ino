#include <SoftwareSerial.h>

SoftwareSerial rfidSerial(10, 11);

void setup() {
  Serial.begin(9600);
  rfidSerial.begin(9600);
  Serial.println("EN ECOUTE...");
}

void loop() {
  // Affiche TOUT ce qui arrive, sans condition
  if (rfidSerial.available() > 0) {
    byte b = rfidSerial.read();
    Serial.print(b, HEX);
    Serial.print(" ");
  }
}