#include <Arduino.h>

// Définition des broches pour l'ESP32
#define RXD2 16
#define TXD2 17

// Algorithme CRC16 (Polynomial: 0x8408, Preset: 0xFFFF)
uint16_t calculateCRC16(uint8_t *data, uint8_t len) {
    uint16_t uiCrcValue = 0xFFFF;
    for (uint8_t i = 0; i < len; i++) {
        uiCrcValue = uiCrcValue ^ data[i];
        for (uint8_t j = 0; j < 8; j++) {
            if (uiCrcValue & 0x0001) {
                uiCrcValue = (uiCrcValue >> 1) ^ 0x8408;
            } else {
                uiCrcValue = (uiCrcValue >> 1);
            }
        }
    }
    return uiCrcValue;
}

void setup() {
    // Moniteur série pour le débogage sur PC (USB)
    Serial.begin(115200);
    
    // Communication avec le lecteur via MAX3232 sur Serial2
    Serial2.begin(115200, SERIAL_8N1, RXD2, TXD2);
    
    delay(1000);
    Serial.println("\n--- Test de Communication RFID UHF ---");
    Serial.println("Initialisation en cours...");
}

void loop() {
    // 1. Construction de la trame d'initialisation (RFM_MODULE_INT)
    // Format : HEAD(CF) | ADDR(FF) | CMD_H(00) | CMD_L(50) | LEN(00)
    uint8_t command[] = {0xCF, 0xFF, 0x00, 0x50, 0x00};
    uint16_t crc = calculateCRC16(command, 5);
    
    // 2. Envoi de la trame au lecteur
    Serial2.write(command, 5);
    
    // Note : Sur beaucoup de modules UHF, le CRC s'envoie Low Byte en premier
    // Si la commande échoue, essayez d'inverser ces deux lignes.
    Serial2.write((uint8_t)(crc & 0xFF)); // Low Byte du CRC
    Serial2.write((uint8_t)(crc >> 8));   // High Byte du CRC

    Serial.println("Commande envoyee, attente de reponse...");
    
    // Attente de la réponse (timeout de 1 seconde)
    unsigned long startTime = millis();
    while (Serial2.available() < 5 && (millis() - startTime) < 1000) {
        delay(1);
    }

    // 3. Lecture de la réponse
    if (Serial2.available() >= 5) {
        uint8_t response[20]; // Buffer suffisant
        int bytesRead = Serial2.readBytes(response, Serial2.available());
        
        Serial.print("Reponse recue (HEX) : ");
        for(int i = 0; i < bytesRead; i++) { 
            Serial.printf("%02X ", response[i]); 
        }
        Serial.println();

        // ANALYSE DE LA RÉPONSE :
        // Index 0 : Header (0xCF)
        // Index 4 : Status (0x00 = Succès)
        if (response[0] == 0xCF) {
            if (response[4] == 0x00) {
                Serial.println("RESULTAT : Communication Reussie ! Le lecteur est pret.");
            } else {
                Serial.printf("ERREUR : Le lecteur a repondu avec un code d'erreur : 0x%02X\n", response[4]);
            }
        } else {
            Serial.println("ERREUR : Format de reponse invalide (Header incorrect).");
        }
    } else {
        Serial.println("ERREUR : Aucune reponse du lecteur (Timeout).");
        Serial.println("Verifiez : 1. Le cablage TX/RX 2. L'alimentation 5V/12V 3. Le module MAX3232");
    }

    Serial.println("---------------------------------------");
    delay(5000); // Répéter le test toutes les 5 secondes
}