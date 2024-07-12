import std.stdio;
import std.conv;
import std.algorithm;
import std.string;
import std.file;
import std.array;
import core.thread;
import serial.device;

import clock.datetime;
import clock.colors;


string[] serialDevices() {
  return dirEntries("/dev", SpanMode.shallow)
    .map!(a => a.name)
    .filter!(a => a.canFind("cu.usbmodem"))
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

void main() {
  auto connection = getConnection;

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

  connection.setPixelSpeed(1);
  connection.setLoopSpeed(30);

  while(true) {
    connection.setMeter(2, nowByte);
    connection.setMeter(1, weekByte);
    connection.lastMessage.writeln;

    connection.setPixel(17, toDayColor(nowByte));
    connection.setPixel(18, toDayColor(nowByte));

    i++;
    Thread.sleep(5.seconds);
  }
}
