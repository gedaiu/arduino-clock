// Pin-9/pin-10 isolation test. No serial, no NeoPixel, no tone — nothing that
// can steal a timer or block. It ramps analogWrite on pin 9 AND pin 10 from 0
// to 254 and back, so a panel meter wired to either pin visibly sweeps.
//
// Stays at 254 (not 255): analogWrite(255) short-circuits to digitalWrite(HIGH)
// and would pin the needle instead of proving PWM works. The onboard LED ramps
// too, so even with nothing wired you can confirm the firmware is the new one.
//
// Needle on pin 9 sweeps  -> analogWrite(9) hardware/wiring is fine; the dead
//                            meter in the clock is a flash/firmware/wiring fault.
// Needle on pin 9 dead but pin 10 sweeps -> pin 9 output or its wiring is the
//                            fault, not the firmware.
#define meterPin1 9
#define meterPin2 10

void setup() {
  pinMode(meterPin1, OUTPUT);
  pinMode(meterPin2, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  for (int level = 0; level <= 254; level++) {
    analogWrite(meterPin1, level);
    analogWrite(meterPin2, level);
    analogWrite(LED_BUILTIN, level);
    delay(8);
  }

  for (int level = 254; level >= 0; level--) {
    analogWrite(meterPin1, level);
    analogWrite(meterPin2, level);
    analogWrite(LED_BUILTIN, level);
    delay(8);
  }
}
