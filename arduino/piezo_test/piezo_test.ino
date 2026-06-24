// Minimal isolation test: continuously beeps the piezo and blinks the onboard
// LED in sync. No serial, no server, no NeoPixel. If the LED blinks the firmware
// is running; if pin 8 also beeps, the pin and piezo are good.
#define piezoPin 8

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  tone(piezoPin, 2000);
  delay(500);

  digitalWrite(LED_BUILTIN, LOW);
  noTone(piezoPin);
  delay(500);
}
