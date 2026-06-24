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
    ubyte[] cmd = [
      cast(ubyte) 7,
      cast(ubyte)((frequency >> 8) & 0xFF),
      cast(ubyte)(frequency & 0xFF),
      cast(ubyte)((duration >> 8) & 0xFF),
      cast(ubyte)(duration & 0xFF)
    ];
    port.write(cmd);
    this.lastMessage = this.read;
  }

  void playJingle() {
    send(20);
    this.lastMessage = this.read;
  }

  void playChime(int count) {
    send(21);
    send(count);
    this.lastMessage = this.read;
  }

  void playTick() {
    send(22);
    this.lastMessage = this.read;
  }

  void showPixels() {
    send(4);

    this.lastMessage = this.read;
  }

  void sayHello() {
    send(10);
    this.lastMessage = this.read;
    writeln("hello: ", this.lastMessage);
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

    // hello is always our first command. Retry it: a server that died mid-command can
    // leave the firmware blocked mid-read, swallowing the first hello bytes as stale
    // args — so drain leftovers and greet again until it answers cleanly.
    foreach(_; 0 .. 5) {
      connection.read;
      writeln("hello?");
      connection.sayHello;
      connection.lastMessage.writeln;

      if(connection.lastMessage == "waaazaa!") {
        "connected.".writeln;
        return connection;
      }
    }

    connection.close;
  }

  throw new Exception("No device found!");
}

void playStartup(ref Connection connection) {
  auto count = chimeCount(Clock.currTime);
  connection.playChime(count);
}

void main() {
  auto connection = getConnection;


  connection.setMeter(1, 0);
  connection.setMeter(2, 0);
  connection.setPixelSpeed(200);
  connection.setLoopSpeed(1);

  foreach (int i; 0..max(nowByte, minuteByte)) {
    connection.setMeter(2, min(nowByte, i));
    connection.setPixel(17, min(nowByte, i).toDayColor);
    connection.setPixel(18, min(nowByte, i).toDayColor);

    connection.setMeter(1, min(minuteByte, i));

    Thread.sleep(5.msecs);
  }

  int i = 0;
  auto lastChimeHour = Clock.currTime.hour;
  auto lastTickMinute = Clock.currTime.minute;

  connection.setPixelSpeed(1);
  connection.setLoopSpeed(30);

  connection.playStartup;

  while(true) {
    connection.setMeter(2, nowByte);
    connection.setMeter(1, minuteByte);
    connection.lastMessage.writeln;

    connection.setPixel(17, toDayColor(nowByte));
    connection.setPixel(18, toDayColor(nowByte));

    auto currentTime = Clock.currTime;
    if(currentTime.hour != lastChimeHour) {
      connection.playChime(chimeCount(currentTime));
      lastChimeHour = currentTime.hour;
    }

    auto minute = currentTime.minute;
    if((minute == 0 || minute == 31) && minute != lastTickMinute) {
      connection.playTick();
      lastTickMinute = minute;
    }

    i++;
    Thread.sleep(5.seconds);
  }
}
