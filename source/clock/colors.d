module clock.colors;

import std.stdio;
import std.math;
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
    auto easeStep = easeOutCubic(step);

    auto r = r + (target.r - r) * step;
    auto g = g + (target.g - g) * step;
    auto b = b + (target.b - b) * step;

    return Color(r, g, b);
  }
}

///
double easeOutCubic(double x) {
  return 1 - pow(1 - x, 3);
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

///
Color toDayColor(int value) {
  auto color1 = Color(200, 30, 0);
  auto color2 = Color(200, 250, 0);
  auto color3 = Color(100, 250, 200);
  auto color4 = Color(150, 100, 200);

  if(value < 90) {
    return color1.transitionTo(color2, percentage(value, 0, 150));
  }

  if(value >= 90 && value <= 140) {
    return color2.transitionTo(color3, percentage(value, 90, 190));
  }

  if(value > 140 && value <= 160) {
    return color3.transitionTo(color4, percentage(value, 140, 220));
  }

  if(value > 160 && value <= 255) {
    return color3.transitionTo(color4, percentage(value, 160, 255));
  }

  return Color(0, 0, 0);
}