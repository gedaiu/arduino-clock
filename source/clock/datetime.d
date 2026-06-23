module clock.datetime;

import std.datetime;
import std.conv;
import std.math;
import std.stdio;

static immutable double daySeconds = 24 * 3600 - 1;
static immutable double weekSeconds = daySeconds * 7;

ubyte nowByte() {
  auto now = Clock.currTime;

  return (now.dayPercentage * 255).to!ubyte;
}

ubyte weekByte() {
  auto now = Clock.currTime;

  return (now.weekPercentage * 255).to!ubyte;
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

/// Returns a value between 0 and 1 with the passed time as percentage of given week
double weekPercentage(SysTime time) @safe nothrow {
  auto day = (cast(double) time.dayOfWeek) - 1;
  if(day == -1) {
    day = 6;
  }

  double weekTimeSeconds = day * daySeconds;
  double dayTimeSeconds = time.hour * 3600 + time.minute * 60 + time.second;

  return (dayTimeSeconds + weekTimeSeconds) / weekSeconds;
}

/// returns 0 on Monday at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T00:00:00").weekPercentage == 0);
}

/// returns 0.14 on Tuesday at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-09T00:00:00").weekPercentage.isClose(0.142857, 0.01));
}

/// returns 0.28 on Wen at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-10T00:00:00").weekPercentage.isClose(0.285714, 0.01));
}

/// returns 0.28 on Sat at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-13T00:00:00").weekPercentage.isClose(0.714286, 0.01));
}

/// returns 1 on Sunday at 23:59:59
unittest {
  assert(SysTime.fromISOExtString("2024-07-14T23:59:59").weekPercentage == 1);
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
  assert(SysTime.fromISOExtString("2022-03-02T12:00:00").dayPercentage.isClose(0.5, 0.01));
}

/// Returns the 12-hour chime count (1 to 12) for the passed time
int chimeCount(SysTime time) @safe nothrow {
  auto hour = time.hour % 12;

  return hour == 0 ? 12 : hour;
}

/// chimes 12 times at 00:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T00:00:00").chimeCount == 12);
}

/// chimes 1 time at 01:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T01:00:00").chimeCount == 1);
}

/// chimes 12 times at 12:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T12:00:00").chimeCount == 12);
}

/// chimes 1 time at 13:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T13:00:00").chimeCount == 1);
}

/// chimes 11 times at 23:00:00
unittest {
  assert(SysTime.fromISOExtString("2024-07-08T23:00:00").chimeCount == 11);
}