#include <Adafruit_NeoPixel.h>

#define analogPin1     5   // potentiometer connected to analog pin 5
#define analogPin2     10  // potentiometer connected to analog pin 10
#define pixelPin       11
#define pixelCount     19

Adafruit_NeoPixel pixels(pixelCount, pixelPin, NEO_GRB + NEO_KHZ800);

struct Color {
  uint8_t r;
  uint8_t g;
  uint8_t b;

  uint32_t color() {
    return pixels.Color(r, g, b);
  }

  uint32_t nextColor(Color* expected) {
    this->r = this->nextColor(r, expected->r, 1);
    this->g = this->nextColor(g, expected->g, 1);
    this->b = this->nextColor(b, expected->b, 1);

    return pixels.Color(r, g, b);
  }

  uint8_t nextColor(uint8_t current, uint8_t target, uint8_t step) {
    if(current < target && current + step > current) {
      return max(min(current + step, target), 0);
    }

    if(current > target && current - step < current) {
      return min(max(current - step, target), 250);
    }
    
    return current;
  }
};

Color pixelColors[pixelCount];
Color expectedColors[pixelCount];

enum SerialAction {
  setMeter1 = 1,
  setMeter2 = 2,
  setPixel = 3,
  renderPixels = 4,
  unknownAction = 99
};

void setup() {
  delay(2000);

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
    pixelColors[i].r = 0;
    pixelColors[i].g = 0;
    pixelColors[i].b = 0;

    pixels.setPixelColor(i, pixelColors[i].color());

    expectedColors[i].r = 40;
    expectedColors[i].g = 0;
    expectedColors[i].b = 0;
  }

  pixels.show();
}

int readValue() {
  while (Serial.available() == 0) {
    delay(5);
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

      expectedColors[i].r = readValue();
      expectedColors[i].g = readValue();
      expectedColors[i].b = readValue();

      break;

    case renderPixels:
      pixels.show();
      break;

    default:
      break;
  }

  if(action != unknownAction) {
    Serial.print("o");
    return;
  }

  bool hasChange = false;
  for(int i=0; i<pixelCount; i++) {
    auto color = pixelColors[i].color();
    auto nextColor = pixelColors[i].nextColor(&expectedColors[i]);

    if(color != nextColor) {
      hasChange = true;
      pixels.setPixelColor(i, color);
    }
  }

  if(hasChange) {
    pixels.show();
  }


  delay(30);
}
