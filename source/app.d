import std.stdio;
import std.datetime;
import std.conv;
import std.algorithm;
import std.string;
import core.thread;
import serial.device;

static immutable port = "/dev/cu.usbmodem1201";
static immutable double daySeconds = 24 * 3600 - 1;

struct Connection {
  SerialPort port;

  this(string path) {
    port = new SerialPort("/dev/cu.usbmodem1201", 2.seconds, 2.seconds);
    port.speed = BaudRate.BR_9600;
    port.parity = Parity.none;
  }

  void send(int value) {
    send(cast(ubyte) value);
  }

  void send(ubyte value) {
    ubyte[] b = [value];

    port.write(b);
    writeln(b);
  }

  void close() {
    port.close;
  }
}

ubyte nowByte() {
  auto now = Clock.currTime;

  return (now.dayPercentage * 255).to!ubyte;
}

ubyte bytePercentage(double percentage) {
  if(percentage <= 0) {
    return 0;
  }

  if(percentage >= 1) {
    return 255;
  }

  return (percentage * 255).to!ubyte;
}

/// Returns 0 for a negative value
unittest {
  assert(bytePercentage(-1) == 0);
}

/// Returns 0 for a 0
unittest {
  assert(0.bytePercentage == 0);
}

/// Returns 25 for a 0.1
unittest {
  assert(bytePercentage(0.1) == 25);
}

/// Returns 255 for a 1
unittest {
  assert(bytePercentage(1) == 255);
}

/// Returns 255 for a 1.1
unittest {
  assert(bytePercentage(1.1) == 255);
}

/// Returns a value between 0 and 1 with the passed time as percentage of given time
double dayPercentage(SysTime time) @safe nothrow {
  double dayTimeSeconds = time.hour * 3600 + time.minute * 60 + time.second;

  return dayTimeSeconds / daySeconds;
}

/// returns 0 at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2022-03-02T00:00:00").dayPercentage == 0);
}

/// returns 1 at 23:00:00
unittest {
  assert(SysTime.fromISOExtString("2022-03-02T23:59:59").dayPercentage == 1);
}

/// returns 0.5 at 12:00:00
unittest {
  import std.math;
  assert(SysTime.fromISOExtString("2022-03-02T12:00:00").dayPercentage.isClose(0.5, 0.01));
}

void main() {
  auto connection = Connection(port);
  auto now = Clock.currTime;
  double secondsToday = now.hour * 3600 + now.minute * 60 + now.second;
  double daySeconds = 24 * 3600;

  auto percentage = secondsToday / daySeconds;

  connection.send(0);

  foreach (int i; 0..nowByte) {
    connection.send(i);
    Thread.sleep(10.msecs);
  }

  while(true) {
    connection.send(nowByte);
    Thread.sleep(5.seconds);
  }
}
