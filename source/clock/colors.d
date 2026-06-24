module clock.colors;

import std.stdio;
import std.conv;

struct Color {
  int r;
  int g;
  int b;

  this(byte r, byte g, byte b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }

  this(int r, int g, int b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }

  this(double r, double g, double b) {
    this(r.to!int, g.to!int, b.to!int);
  }

  Color transitionTo(Color target, double step) {
    auto r = r + (target.r - r) * step;
    auto g = g + (target.g - g) * step;
    auto b = b + (target.b - b) * step;

    return Color(r, g, b);
  }
}

/// get the percentage inside a interval

double percentage(int value, int start, int end) {
  auto a = (value.to!double - start.to!double);
  auto b = (end.to!double - start.to!double);

  return a / b;
}

///
unittest {
  assert(percentage(0, 0, 100) == 0);
  assert(percentage(50, 50, 100) == 0);
  assert(percentage(100, 0, 100) == 1);
}

/// Returns the color at position t (0 to 1) along an evenly spaced list of stops
Color gradient(Color[] stops, double t) {
  if(t <= 0) {
    return stops[0];
  }

  if(t >= 1) {
    return stops[$ - 1];
  }

  auto scaled = t * (stops.length - 1);
  auto index = scaled.to!int;
  auto local = scaled - index;

  return stops[index].transitionTo(stops[index + 1], local);
}

/// returns the first stop at 0
unittest {
  auto stops = [Color(0, 0, 0), Color(100, 100, 100)];
  assert(gradient(stops, 0) == Color(0, 0, 0));
}

/// returns the last stop at 1
unittest {
  auto stops = [Color(0, 0, 0), Color(100, 100, 100)];
  assert(gradient(stops, 1) == Color(100, 100, 100));
}

/// returns the midpoint at 0.5
unittest {
  auto stops = [Color(0, 0, 0), Color(100, 100, 100)];
  assert(gradient(stops, 0.5) == Color(50, 50, 50));
}

/// lands on the middle stop at 0.5 of a three stop gradient
unittest {
  auto stops = [Color(0, 0, 0), Color(100, 100, 100), Color(200, 200, 200)];
  assert(gradient(stops, 0.5) == Color(100, 100, 100));
}

/// Maps a day byte (0 to 255) to a smooth red to yellow to cyan to purple gradient
Color toDayColor(int value) {
  auto stops = [
    Color(200, 30, 0),
    Color(200, 250, 0),
    Color(100, 250, 200),
    Color(150, 100, 200)
  ];

  return gradient(stops, percentage(value, 0, 255));
}

/// starts on the first color at 0
unittest {
  assert(toDayColor(0) == Color(200, 30, 0));
}

/// ends on the last color at 255
unittest {
  assert(toDayColor(255) == Color(150, 100, 200));
}

/// actually reaches a bright yellow a third of the way through the day
unittest {
  assert(toDayColor(85).g > 240);
}