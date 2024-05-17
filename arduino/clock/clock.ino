const int analogPin = 5;   // potentiometer connected to analog pin 3
int value = 100;           // for incoming serial data

void setup() {
  pinMode(analogPin, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  if (!Serial.available() > 0) {
    delay(30);
    return;
  }

  value = Serial.read();

  analogWrite(analogPin, value);
}
