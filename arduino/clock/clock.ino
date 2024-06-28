#include <Adafruit_NeoPixel.h>

#define analogPin1     5   // potentiometer connected to analog pin 5
#define analogPin2     10   // potentiometer connected to analog pin 6
#define pixelPin       11
#define pixelCount     19

Adafruit_NeoPixel pixels(pixelCount, pixelPin, NEO_GRB + NEO_KHZ800);

enum SerialAction {
  setMeter1 = 1,
  setMeter2 = 2,
  setPixel = 3,
  renderPixels = 4,
  unknownAction = 99
};

void setup() {
  pinMode(analogPin1, OUTPUT);
  pinMode(analogPin2, OUTPUT);
  Serial.begin(9600);
  pixels.begin();

  delay(1000);
  Serial.println("Ready.");

  pixels.clear();

  analogWrite(analogPin1, 255);
  analogWrite(analogPin2, 255);

  for(int i=0; i<pixelCount; i++) {
    pixels.setPixelColor(i, pixels.Color(20, 0, 0));
  }

  pixels.show();
}

int readValue() {
  while (Serial.available() == 0) {
    delay(30);
  }

  return Serial.read();
}

SerialAction readAction() {
  if (Serial.available() == 0) {
    return unknownAction;
  }

  int value = Serial.read();

  switch (value) {
    case 1:
      return setMeter1;

    case 2:
      return setMeter2;

    case 3:
      return setPixel;

    case 4:
      return renderPixels;

    default:
      return unknownAction;
  }
}

void loop() {
  SerialAction action = readAction();

  int value;

  switch(action) {
    case setMeter1:
      value = readValue();
      analogWrite(analogPin1, value);
      break;

    case setMeter2:
      value = readValue();
      analogWrite(analogPin2, value);

      pixels.setPixelColor(0, pixels.Color(value, 0, 0));
      pixels.show();

      break;

    case setPixel:
      int i = readValue();
      int r = readValue();
      int g = readValue();
      int b = readValue();

      pixels.setPixelColor(i, pixels.Color(r, g, b));
      break;

    case renderPixels:
      pixels.show();
      break;

    default:
      break;
  }

  if(action == unknownAction) {
    delay(30);
  }
}
