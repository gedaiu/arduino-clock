// Isolation test: plays three clearly different tones in a loop, on its own.
// Uses tone() with the duration arg, exactly like the real firmware does.
// Hear low-mid-high stepping up and repeating -> the Micro sequences tones fine,
// so the bug is server/serial side. Hear only one -> it's tone() on the Micro.
#define piezoPin 8

void setup() {}

void loop() {
  tone(piezoPin, 2000, 250);
  delay(500);

  tone(piezoPin, 3000, 250);
  delay(500);

  tone(piezoPin, 4000, 250);
  delay(500);

  delay(1000);
}
