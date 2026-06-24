#include <Adafruit_NeoPixel.h>

#define analogPin1     5   // meter wired to pin 5 = OC3A/Timer3 — the SAME timer tone() steals for the piezo.
#define analogPin2     10  // meter wired to pin 10 = OC1B/Timer1 — independent, never disturbed by tone().
#define pixelPin       11
#define pixelCount     19
#define piezoPin       8

Adafruit_NeoPixel pixels(pixelCount, pixelPin, NEO_GRB + NEO_KHZ800);

uint8_t pixelSpeed = 1;
int loopSpeed = 10;
unsigned long lastTime;
int meter1Value = 255;     // last value pushed to the pin-5 meter; re-applied once a tone frees Timer3

struct Color {
  uint8_t r;
  uint8_t g;
  uint8_t b;

  uint32_t color() {
    return pixels.Color(r, g, b);
  }

  uint32_t nextColor(Color* expected) {
    this->r = this->nextColor(r, expected->r, pixelSpeed);
    this->g = this->nextColor(g, expected->g, pixelSpeed);
    this->b = this->nextColor(b, expected->b, pixelSpeed);

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
  setPixelSpeed = 5,
  setLoopSpeed = 6,
  playTone = 7,
  playJingle = 20,
  playChime = 21,
  playTick = 22,
  hello = 10,
  unknownAction = 99
};

void setDefaults() {
  analogWrite(analogPin2, 255);
  meter1Value = 255;
  analogWrite(analogPin1, 255);

  for(int i=0; i<pixelCount; i++) {
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

int readWord() {
  int high = readValue();
  int low = readValue();

  return (high << 8) | low;
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

    case 5:
      return setPixelSpeed;

    case 6:
      return setLoopSpeed;

    case 7:
      return playTone;

    case 20:
      return playJingle;

    case 21:
      return playChime;

    case 22:
      return playTick;

    case 10:
      return hello;

    default:
      return unknownAction;
  }
}

#define noteQueueSize 64

struct QueuedNote {
  int frequency;
  int duration;
};

QueuedNote noteQueue[noteQueueSize];
int queueHead = 0;
int queueTail = 0;
bool tonePlaying = false;
unsigned long toneStart = 0;
int toneDuration = 0;

void enqueueNote(int frequency, int duration) {
  int next = (queueTail + 1) % noteQueueSize;
  if(next == queueHead) {
    return;
  }

  noteQueue[queueTail].frequency = frequency;
  noteQueue[queueTail].duration = duration;
  queueTail = next;
}

// tone() commandeers Timer3 (CTC mode) to clock the piezo, but the pin-5 meter rides OC3A
// on that same timer. Once the piezo is quiet, put Timer3 back into the 8-bit phase-correct
// PWM mode init() set up, then re-apply the needle so it snaps back to the server's value.
void restoreMeter1() {
  TCCR3A = _BV(WGM30);
  TCCR3B = _BV(CS31) | _BV(CS30);
  analogWrite(analogPin1, meter1Value);
}

// Advances the non-blocking player and returns ms left on the current note (0 when idle).
int updatePlayer() {
  unsigned long now = millis();

  if(tonePlaying) {
    if(now - toneStart < (unsigned long) toneDuration) {
      return toneDuration - (now - toneStart);
    }

    noTone(piezoPin);
    tonePlaying = false;

    if(queueHead == queueTail) {
      restoreMeter1();
      return 0;
    }
  }

  if(queueHead == queueTail) {
    return 0;
  }

  QueuedNote note = noteQueue[queueHead];
  queueHead = (queueHead + 1) % noteQueueSize;

  if(note.frequency > 0) {
    tone(piezoPin, note.frequency);
  } else {
    noTone(piezoPin);
  }

  tonePlaying = true;
  toneStart = now;
  toneDuration = note.duration;
  return note.duration;
}

#define NOTE_C5  523
#define NOTE_E5  659
#define NOTE_G5  784
#define NOTE_C6  1047
#define NOTE_E6  1319
#define NOTE_G6  1568
#define NOTE_C7  2093

// Tick-tock, played at :00 and :31. Low frequencies stay soft (off the piezo's
// ~2-4kHz resonance), so it sounds like a real clock rather than an alarm.
#define TICK_FREQ      120
#define TOCK_FREQ      80
#define TICK_MS        10

// Arcade power-up: a fast C-major run straight up, capped with a high held sparkle.
void enqueueJingle() {
  enqueueNote(NOTE_C5, 70);
  enqueueNote(NOTE_E5, 70);
  enqueueNote(NOTE_G5, 70);
  enqueueNote(NOTE_C6, 70);
  enqueueNote(NOTE_E6, 70);
  enqueueNote(NOTE_G6, 70);
  enqueueNote(NOTE_C7, 260);
}

// Each hour-count is an 8-bit "coin" blip: a quick G6 grace note into a high C7 ding.
void enqueueChime(int count) {
  if(count > 12) {
    count = 12;
  }

  for(int i = 0; i < count; i++) {
    enqueueNote(NOTE_G6, 60);
    enqueueNote(NOTE_C7, 190);
    enqueueNote(0, 150);
  }
}

// Connect chirp (on hello): a bouncy zig-zag greeting, distinct from the straight startup run.
void enqueueHello() {
  enqueueNote(NOTE_C6, 80);
  enqueueNote(NOTE_E6, 80);
  enqueueNote(NOTE_G5, 80);
  enqueueNote(NOTE_C6, 80);
  enqueueNote(NOTE_G6, 240);
}

// Tick-tock marker (server sends this at :00 and :31): a soft tick, a beat, then a tock.
void enqueueTickTock() {
  enqueueNote(TICK_FREQ, TICK_MS);
  enqueueNote(0, 130);
  enqueueNote(TOCK_FREQ, TICK_MS);
}

void setup() {
  pinMode(analogPin1, OUTPUT);
  pinMode(analogPin2, OUTPUT);
  Serial.begin(9600);
  pixels.begin();

  delay(2000);
  Serial.println("Ready.");
  Serial.flush();

  pixels.clear();
  for(int i=0; i<pixelCount; i++) {
    pixelColors[i].r = 0;
    pixelColors[i].g = 0;
    pixelColors[i].b = 0;
  }

  setDefaults();

  enqueueChime(1);
  enqueueNote(0, 1000);
  enqueueJingle();
  enqueueNote(0, 1000);
}

void loop() {
  if(!tonePlaying && queueHead == queueTail && millis() - lastTime > 6000) {
    setDefaults();
  }

  SerialAction action = readAction();

  int value;

  switch(action) {
    case setMeter1:
      value = readValue();
      meter1Value = value;
      if(!tonePlaying) {
        analogWrite(analogPin1, value);   // mid-tone this would clobber OCR3A and detune the piezo
      }
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

    case setPixelSpeed:
      pixelSpeed = readValue();
      break;

    case setLoopSpeed:
      loopSpeed = readValue();
      break;

    case playTone: {
      int frequency = readWord();
      int duration = readWord();
      enqueueNote(frequency, duration);
      break;
    }

    case playJingle:
      enqueueJingle();
      break;

    case playChime: {
      int count = readValue();
      enqueueChime(count);
      break;
    }

    case playTick:
      enqueueTickTock();
      break;

    case hello:
      break;

    default:
      break;
  }

  int remaining = updatePlayer();

  if(action == hello) {
    Serial.print("waaazaa!");
    enqueueHello();
    Serial.flush();
    return;
  }

  if(action != unknownAction) {
    lastTime = millis();
    // Build the ack in one buffer and send it atomically. Two separate prints can be
    // split across USB frames, so the server reads "o" alone and the digits leak into
    // the next read — offsetting every reply by one from then on.
    char reply[8];
    reply[0] = 'o';
    itoa((int) action, reply + 1, 10);
    Serial.print(reply);
    Serial.flush();
    return;
  }

  // While a note is sounding, leave the NeoPixels alone — pixels.show() disables
  // interrupts and would chop tone()'s interrupt-driven square wave into a buzz.
  if(remaining == 0) {
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
  }

  // Constant cadence: every idle loop lasts exactly loopSpeed so playback and
  // rendering stay locked to a fixed tick. A note longer than one tick just spans
  // several of them (updatePlayer times it off millis), so we never shorten here.
  delay(loopSpeed);
}
