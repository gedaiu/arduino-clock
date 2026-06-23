import std.stdio;
import std.conv;
import std.algorithm;
import std.string;
import std.file;
import std.array;
import core.thread;
import std.datetime;
import serial.device;

import clock.datetime;
import clock.colors;


string[] serialDevices() {
  return dirEntries("/dev", SpanMode.shallow)
    .map!(a => a.name)
    .filter!(a => a.canFind("cu.usbmodem") || a.canFind("ACM"))
    .array;
}

struct Connection {
  SerialPort port;
  char[512] bufferForReading;
  string lastMessage;

  this(string path) {
    port = new SerialPort(path, 2.seconds, 2.seconds);
    port.speed = BaudRate.BR_9600;
    port.parity = Parity.none;
  }

  void send(int value) {
    send(cast(ubyte) value);
  }

  void send(ubyte value) {
    ubyte[] b = [value];
    port.write(b);
  }

  void setMeter(int index, int value) {
    this.send(index);
    this.send(value);
    this.lastMessage = this.read;
  }

  void setPixel(int index, int r, int g, int b) {
    send(3);
    send(index);
    send(r);
    send(g);
    send(b);
    this.lastMessage = this.read;
  }

  void setPixel(int index, Color color) {
    setPixel(index, color.r, color.g, color.b);
  }

  void setPixelSpeed(int speed) {
    this.send(5);
    this.send(speed);
    this.lastMessage = this.read;
  }

  void setLoopSpeed(int speed) {
    this.send(6);
    this.send(speed);
    this.lastMessage = this.read;
  }

  void sendWord(int value) {
    send(cast(ubyte)((value >> 8) & 0xFF));
    send(cast(ubyte)(value & 0xFF));
  }

  void playTone(int frequency, int duration) {
    send(7);
    sendWord(frequency);
    sendWord(duration);
    this.lastMessage = this.read;
  }

  void showPixels() {
    send(4);

    this.lastMessage = this.read;
  }

  void sayHello() {
    send(10);
    this.lastMessage = this.read;
  }

  string read() {
    try {
      auto res = port.read(this.bufferForReading);

      return this.bufferForReading[0..res].to!string.strip;
    } catch(Exception e) {
      return "";
    }
  }

  void close() {
    port.close;
  }
}

auto getConnection() {
  foreach(port; serialDevices) {
    writeln("connecting to: ", port);
    auto connection = Connection(port);
    connection.read.writeln;

    writeln("hello?");
    connection.sayHello;
    connection.lastMessage.writeln;

    if(connection.lastMessage == "waaazaa!") {
      "connected.".writeln;
      return connection;
    }

    connection.close;
  }

  throw new Exception("No device found!");
}

void playNote(ref Connection connection, int frequency, int duration) {
  connection.playTone(frequency, duration);
  Thread.sleep(duration.msecs);
}

void playConnectJingle(ref Connection connection) {
  connection.playNote(523, 120);
  connection.playNote(659, 120);
  connection.playNote(784, 120);
  connection.playNote(1047, 220);
}

void chime(ref Connection connection, SysTime time) {
  foreach(_; 0 .. chimeCount(time)) {
    connection.playNote(330, 300);
    Thread.sleep(150.msecs);
  }
}

void main() {
  auto connection = getConnection;

  connection.playConnectJingle;

  connection.setMeter(1, 0);
  connection.setMeter(2, 0);
  connection.setPixelSpeed(200);
  connection.setLoopSpeed(1);

  auto meter1 = nowByte;
  auto meter2 = weekByte;

  foreach (int i; 0..max(nowByte, weekByte)) {
    connection.setMeter(2, min(nowByte, i));
    connection.setPixel(17, min(nowByte, i).toDayColor);
    connection.setPixel(18, min(nowByte, i).toDayColor);

    connection.setMeter(1, min(weekByte, i));

    Thread.sleep(5.msecs);
  }

  int i = 0;
  auto lastChimeHour = Clock.currTime.hour;

  connection.setPixelSpeed(1);
  connection.setLoopSpeed(30);

  while(true) {
    connection.setMeter(2, nowByte);
    connection.setMeter(1, weekByte);
    connection.lastMessage.writeln;

    connection.setPixel(17, toDayColor(nowByte));
    connection.setPixel(18, toDayColor(nowByte));

    auto currentTime = Clock.currTime;
    if(currentTime.hour != lastChimeHour) {
      connection.chime(currentTime);
      lastChimeHour = currentTime.hour;
    }

    i++;
    Thread.sleep(5.seconds);
  }
}
