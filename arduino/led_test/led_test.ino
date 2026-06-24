// Visual pin test. Blinks the onboard LED (needs no wiring) AND pin 8 together.
// Onboard "L" blinks  -> firmware is running. If your external LED on pin 8 stays
// dark while the onboard one blinks, you're on the wrong hole, not pin 8.
// Wire: pin 8 -> resistor (220-1k) -> LED long leg, LED short leg -> GND.
#define testPin 8

void setup() {
  pinMode(testPin, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(testPin, HIGH);
  digitalWrite(LED_BUILTIN, HIGH);
  delay(500);

  digitalWrite(testPin, LOW);
  digitalWrite(LED_BUILTIN, LOW);
  delay(500);
}
