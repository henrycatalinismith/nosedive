#include <iostream>
#include <algorithm>
#include <array>
#include <math.h>
#include <numeric>
#include <vector>
#include "SDL.h"
#include "SDL_image.h"

#define TOUCH_0_B 0x4300
#define DRAW_CAMERA_X_LO 0x5f28
#define DRAW_CAMERA_X_HI 0x5f29
#define DRAW_CAMERA_Y_LO 0x5f2a
#define DRAW_CAMERA_Y_HI 0x5f2b

SDL_Window *window;
SDL_Renderer *renderer;
SDL_Surface *spritesheet;
SDL_Texture *canvas;
int palette[16][3] = {
  {0, 0, 0},
  {29, 43, 83},
  {126, 37, 83},
  {0, 135, 81},
  {171, 82, 54},
  {95, 87, 79},
  {194, 195, 199},
  {255, 241, 232},
  {255, 0, 77},
  {255, 163, 0},
  {255, 236, 39},
  {0, 228, 54},
  {41, 173, 255},
  {131, 118, 156},
  {255, 119, 168},
  {255, 204, 170},
};
uint8_t memory[0x8000];
uint8_t pixels[128 * 128 * 4];

typedef struct glyph {
  char *c;
  bool px[5][3];
} glyph;

glyph font[97] = {
  {" ", {
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"!", {
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 0, 0},
    {0, 1, 0}
  }},

  {"\"", {
    {1, 0, 1},
    {1, 0, 1},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"#", {
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1}
  }},

  {"$", {
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"%", {
    {1, 0, 1},
    {0, 0, 1},
    {0, 1, 0},
    {1, 0, 0},
    {1, 0, 1}
  }},

  {"&", {
    {1, 1, 0},
    {1, 1, 0},
    {1, 1, 0},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"'", {
    {0, 1, 0},
    {0, 1, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"(", {
    {0, 1, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {0, 1, 0}
  }},

  {")", {
    {0, 1, 0},
    {0, 0, 1},
    {0, 0, 1},
    {0, 0, 1},
    {0, 1, 0}
  }},

  {"*", {
    {1, 0, 1},
    {0, 1, 0},
    {1, 1, 1},
    {0, 1, 0},
    {1, 0, 1}
  }},

  {",", {
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 1},
    {0, 1, 0}
  }},

  {"-", {
    {0, 0, 0},
    {0, 0, 0},
    {1, 1, 1},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {".", {
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 1, 0}
  }},

  {"/", {
    {0, 0, 1},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {1, 0, 0}
  }},

  {"+", {
    {0, 0, 0},
    {0, 1, 0},
    {1, 1, 1},
    {0, 1, 0},
    {0, 0, 0}
  }},

  {"0", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"1", {
    {1, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {1, 1, 1}
  }},

  {"2", {
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"3", {
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1}
  }},

  {"4", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {0, 0, 1},
    {0, 0, 1}
  }},

  {"5", {
    {1, 1, 1},
    {1, 0, 0},
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1}
  }},

  {"6", {
    {1, 0, 0},
    {1, 0, 0},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"7", {
    {1, 1, 1},
    {0, 0, 1},
    {0, 0, 1},
    {0, 0, 1},
    {0, 0, 1}
  }},

  {"8", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"9", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {0, 0, 1},
    {0, 0, 1}
  }},

  {":", {
    {0, 0, 0},
    {0, 1, 0},
    {0, 0, 0},
    {0, 1, 0},
    {0, 0, 0}
  }},

  {";", {
    {0, 0, 0},
    {0, 1, 0},
    {0, 0, 0},
    {0, 1, 0},
    {1, 0, 0}
  }},

  {"<", {
    {0, 0, 1},
    {0, 1, 0},
    {1, 0, 0},
    {0, 1, 0},
    {0, 0, 1}
  }},

  {"=", {
    {0, 0, 0},
    {1, 1, 1},
    {0, 0, 0},
    {1, 1, 1},
    {0, 0, 0}
  }},

  {">", {
    {1, 0, 0},
    {0, 1, 0},
    {0, 0, 1},
    {0, 1, 0},
    {1, 0, 0}
  }},

  {"?", {
    {1, 1, 1},
    {0, 0, 1},
    {0, 1, 1},
    {0, 0, 0},
    {0, 1, 0}
  }},

  {"@", {
    {0, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 0},
    {0, 1, 1}
  }},

  {"A", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"B", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 0},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"C", {
    {0, 1, 1},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {0, 1, 1}
  }},

  {"D", {
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"E", {
    {1, 1, 1},
    {1, 0, 0},
    {1, 1, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"F", {
    {1, 1, 1},
    {1, 0, 0},
    {1, 1, 0},
    {1, 0, 0},
    {1, 0, 0}
  }},

  {"G", {
    {0, 1, 1},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"H", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"I", {
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {1, 1, 1}
  }},

  {"J", {
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {1, 1, 0}
  }},

  {"K", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"L", {
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"M", {
    {1, 1, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"N", {
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"O", {
    {0, 1, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 0}
  }},

  {"P", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 0},
    {1, 0, 0}
  }},

  {"Q", {
    {0, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 0},
    {0, 1, 1}
  }},

  {"R", {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"S", {
    {0, 1, 1},
    {1, 0, 0},
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 0}
  }},

  {"T", {
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0}
  }},

  {"U", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {0, 1, 1}
  }},

  {"V", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {0, 1, 0}
  }},

  {"W", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 1, 1}
  }},

  {"X", {
    {1, 0, 1},
    {1, 0, 1},
    {0, 1, 0},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"Y", {
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1}
  }},

  {"Z", {
    {1, 1, 1},
    {0, 0, 1},
    {0, 1, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"[", {
    {1, 1, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 1, 0}
  }},

  {"\\", {
    {1, 0, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 0, 1}
  }},

  {"]", {
    {0, 1, 1},
    {0, 0, 1},
    {0, 0, 1},
    {0, 0, 1},
    {0, 1, 1}
  }},

  {"^", {
    {0, 1, 0},
    {1, 0, 1},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"_", {
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0},
    {1, 1, 1}
  }},

  {"`", {
    {0, 1, 0},
    {0, 0, 1},
    {0, 0, 0},
    {0, 0, 0},
    {0, 0, 0}
  }},

  {"a", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1},
  }},

  {"b", {
    {0, 0, 0},
    {1, 1, 0},
    {1, 1, 0},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"c", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 0, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"d", {
    {0, 0, 0},
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 0}
  }},

  {"e", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 1, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"f", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 1, 0},
    {1, 0, 0},
    {1, 0, 0}
  }},

  {"g", {
    {0, 0, 0},
    {0, 1, 1},
    {1, 0, 0},
    {1, 0, 1},
    {1, 1, 1}
  }},

  {"h", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 1}
  }},

  {"i", {
    {0, 0, 0},
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {1, 1, 1}
  }},

  {"j", {
    {0, 0, 0},
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {1, 1, 0}
  }},

  {"k", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"l", {
    {0, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"m", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 1, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"n", {
    {0, 0, 0},
    {1, 1, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"o", {
    {0, 0, 0},
    {0, 1, 1},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 0}
  }},

  {"p", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 0, 0}
  }},

  {"q", {
    {0, 0, 0},
    {0, 1, 0},
    {1, 0, 1},
    {1, 1, 0},
    {0, 1, 1}
  }},

  {"r", {
    {0, 0, 0},
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 0},
    {1, 0, 1}
  }},

  {"s", {
    {0, 0, 0},
    {0, 1, 1},
    {1, 0, 0},
    {0, 0, 1},
    {1, 1, 0}
  }},

  {"t", {
    {0, 0, 0},
    {1, 1, 1},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0}
  }},

  {"u", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 0, 1},
    {0, 1, 1}
  }},

  {"v", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {0, 1, 0}
  }},

  {"w", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 1, 1}
  }},

  {"x", {
    {0, 0, 0},
    {1, 0, 1},
    {0, 1, 0},
    {1, 0, 1},
    {1, 0, 1}
  }},

  {"y", {
    {0, 0, 0},
    {1, 0, 1},
    {1, 1, 1},
    {0, 0, 1},
    {1, 1, 1}
  }},

  {"z", {
    {0, 0, 0},
    {1, 1, 1},
    {0, 0, 1},
    {1, 0, 0},
    {1, 1, 1}
  }},

  {"{", {
    {0, 1, 1},
    {0, 1, 0},
    {1, 1, 0},
    {0, 1, 0},
    {0, 1, 1},
  }},

  {"|", {
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
    {0, 1, 0},
  }},

  {"}", {
    {1, 1, 0},
    {0, 1, 0},
    {0, 1, 1},
    {0, 1, 0},
    {1, 1, 0},
  }},

  {"~", {
    {0, 0, 0},
    {0, 0, 1},
    {1, 1, 1},
    {1, 0, 0},
    {0, 0, 0},
  }},

  {NULL, NULL}
};

int window_width;
int window_height;
int window_scale;

bool upagain = false;
std::size_t target_frame_duration = 16;
Uint32 title_timestamp;
int frame_count = 0;
bool running = true;

void init();
void tick();
void draw();

int pow2(int n);

void camera(int x, int y);
void circ (int x, int y, int r, int col);
void circfill(int x, int y, int r, int col);
void cls(int col);
void line(int x0, int y0, int x1, int y1, int col);
double mid(double a, double b, double c);
int nibble(int addr, bool high);
void nobble(int addr, bool high, int val);
int peek(int addr);
void poke(int addr, int val);
int pget(int x, int y);
void print(const char *str, int x, int y, int col);
void pset(int x, int y, int c);
void rect(int x0, int y0, int x1, int y1, int col);
void rectfill(int x0, int y0, int x1, int y1, int col);
int sget(int x, int y);
void sset(int x, int y, int c);
void sspr(int sx, int sy, int sw, int sh, int dx, int dy);
bool touch();

void getpixel(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b);

Uint32 update_mode = 0;
#define UPDATE_MENU 1
#define UPDATE_CAMERA 2
#define UPDATE_CAVE 4
#define UPDATE_HELICOPTER 8
#define UPDATE_ROTOR 16
#define UPDATE_HITBOX 32
#define UPDATE_DEBRIS 64
#define UPDATE_COINS 128
#define UPDATE_SMOKE 256
#define UPDATE_DEAD 512

Uint32 draw_mode = 0;
#define DRAW_MENU 1
#define DRAW_CAMERA 2
#define DRAW_CAVE 4
#define DRAW_HELICOPTER 8
#define DRAW_ROTOR 16
#define DRAW_HITBOX 32
#define DRAW_DEBRIS 64
#define DRAW_COINS 128
#define DRAW_SMOKE 256
#define DRAW_DEAD 512

void _init();
void _tick();
void _draw();

#define MODE_MENU 0
#define MODE_PLAY 1
#define MODE_DEAD 2

int loop(int n, int m, int o);
void mode(int mode);

std::array<int,128> cave_floor;
std::array<int,128> cave_roof;

double camera_x1;
double camera_y1;
double camera_x2;
double camera_y2;
double camera_vx;
double camera_vy;
double camera_ideal_y1;
double camera_error_y1;
double camera_offset_y1;
double camera_error_count;

#define HELICOPTER_HOVERING 1
#define HELICOPTER_DROPPING 2
#define HELICOPTER_CLIMBING 3

double helicopter_x;
double helicopter_y;
double helicopter_gravity = 0.1;
double helicopter_min_vy = -1.5;
double helicopter_max_vy = 2;
double helicopter_vx;
double helicopter_vy;
int helicopter_inclination;
int helicopter_collision_frame;

bool rotor_engaged;
double rotor_vy = 0;
double rotor_power = -0.3;
int rotor_collision_frame;

double hitbox_x1;
double hitbox_y1;
double hitbox_x2;
double hitbox_y2;

void rotor_collision();
void helicopter_collision();

int main()
{
 init();
 while (running) {
  tick();
  draw();
 }
}

void init()
{
 window_width = pow2(9);
 window_height = pow2(9);
 window_scale = window_width / 128;
 window = SDL_CreateWindow(
  "nosedive",
  SDL_WINDOWPOS_CENTERED,
  SDL_WINDOWPOS_CENTERED,
  window_width,
  window_height,
  SDL_WINDOW_RESIZABLE
 );
 renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
 // spritesheet = IMG_LoadTexture(renderer, "nosedive.png");
 spritesheet = IMG_Load("nosedive.png");
 // camera_x0 = 0;
 // camera_x1 = 0;
 // camera_x2 = 127;
 // camera_y0 = 0;
 // camera_y1 = 0;
 // camera_y2 = 127;

 for (int addr = 0x6000; addr <= 0x7FFF; addr++) {
  memory[addr] = 0;
 }

 canvas = SDL_CreateTexture(
  renderer,
  SDL_PIXELFORMAT_ARGB8888,
  SDL_TEXTUREACCESS_STREAMING,
  128,
  128
 );

 Uint8 r, g, b;
 for (int x = 0; x < 128; x++) {
  for (int y = 0; y < 128; y++) {
   bool found = false;
   int mindiff = 99999;
   int closest = 0;
   getpixel(spritesheet, x, y, &r, &g, &b);
   for (int c = 0; c < 16; c++) {
    int diff = (
     abs(r - palette[c][0]) +
     abs(g - palette[c][1]) +
     abs(b - palette[c][2])
    );
    if (diff < 200 && diff < mindiff) {
     mindiff = diff;
     closest = c;
     found = true;
    }
   }
   if (found) {
    sset(x, y, closest);
   } else {
    printf("sprite/palette mismatch @ %dx%d rgb(%d,%d,%d)\n", x, y, r, g, b);
   }
  }
 }

 _init();
}

void tick()
{
 Uint32 frame_start = SDL_GetTicks();
 SDL_Event e;
 bool down = false;

 if (upagain) {
  poke(TOUCH_0_B, false);
  // poke(TOUCH_0_X, 0);
  // poke(TOUCH_0_Y, 0);
  upagain = false;
 }

 while (SDL_PollEvent(&e)) {
  switch (e.type) {
   case SDL_FINGERDOWN:
    poke(TOUCH_0_B, true);
    break;

   case SDL_FINGERUP:
    poke(TOUCH_0_B, false);
    break;

   case SDL_KEYDOWN:
    switch (e.key.keysym.sym) {
     case SDLK_UP:
      running = false;
      break;
    }
    break;

   case SDL_MOUSEBUTTONDOWN:
    poke(TOUCH_0_B, true);
    down = true;
    break;

   case SDL_MOUSEBUTTONUP:
    if (down) {
     upagain = true;
    } else {
     poke(TOUCH_0_B, false);
    }
    break;

   case SDL_QUIT:
    running = false;
    break;

   case SDL_WINDOWEVENT:
    if (e.window.event == SDL_WINDOWEVENT_RESIZED) {
     printf("resize\n");
     SDL_GetWindowSize(window, &window_width, &window_height);
     window_scale = std::min(window_width, window_height) / 128;
     int bar_width;
     int bar_height;
     if (window_height > window_width) {
      // bar_height = (window_height - window_width) / 2;
      // camera_y0 = camera_y1 - (bar_height / window_scale);
      // camera_x0 = camera_x1;
     }
     if (window_width > window_height) {
      // bar_width = (window_width - window_height) / 2;
      // camera_x0 = camera_x1 - (bar_width / window_scale);
      // camera_y0 = camera_y1;
     }
     // printf("bar height: %d\n", bar_height);
     // printf("bar width: %d\n", bar_width);
    }
    break;

  }
 }

 _tick();

 Uint32 frame_end = SDL_GetTicks();
 frame_count++;
 Uint32 frame_duration = frame_end - frame_start;

 if (frame_end - title_timestamp >= 1000) {
  SDL_SetWindowTitle(window, std::to_string(frame_count).c_str());
  frame_count = 0;
  title_timestamp = frame_end;
 }

 if (frame_duration < target_frame_duration) {
  SDL_Delay(target_frame_duration - frame_duration);
 }
}

void draw()
{
 _draw();
 SDL_Rect src;
 src.x = 0;
 src.y = 0;
 src.w = 128;
 src.h = 128;

 SDL_Rect dst;
 dst.x = 0;
 dst.y = 0;
 dst.w = window_width;
 dst.h = window_height;

 // SDL_RenderCopy(renderer, spritesheet, &src, &dst);

 for (int x = 0; x < 128; x++) {
  for (int y = 0; y < 128; y++) {
   int c = pget(x, y);
   const unsigned int offset = (128 * 4 * y ) + x * 4;
   pixels[offset + 0] = palette[c][2]; // b
   pixels[offset + 1] = palette[c][1]; // g
   pixels[offset + 2] = palette[c][0]; // r
   pixels[offset + 3] = SDL_ALPHA_OPAQUE;   // a
  }
 }
 SDL_UpdateTexture(canvas, NULL, &pixels[0], 128 * 4);
 SDL_RenderCopy(renderer, canvas, &src, &dst);

 SDL_RenderPresent(renderer);
}

int pow2(int n)
{
 return pow(2, n);
}

void camera(int x, int y)
{
 poke(DRAW_CAMERA_X_LO, x % 256);
 poke(DRAW_CAMERA_X_HI, (x >> 8) & 0xff);
 poke(DRAW_CAMERA_Y_LO, y % 256);
 poke(DRAW_CAMERA_Y_HI, (y >> 8) & 0xff);
}

void circ(int x, int y, int r, int col)
{
 int f = 1 - r;
 int ddF_x = 0;
 int ddF_y = -2 * r;
 int cx = 0;
 int cy = r;

 pset(x, y + r, col);
 pset(x, y - r, col);
 pset(x + r, y, col);
 pset(x - r, y, col);

 while (cx < cy) {
  if (f >= 0) {
   cy--;
   ddF_y += 2;
   f += ddF_y;
  }

  cx++;
  ddF_x += 2;
  f += ddF_x + 1;

  pset(x + cx, y + cy, col);
  pset(x - cx, y + cy, col);
  pset(x + cx, y - cy, col);
  pset(x - cx, y - cy, col);
  pset(x + cy, y + cx, col);
  pset(x - cy, y + cx, col);
  pset(x + cy, y - cx, col);
  pset(x - cy, y - cx, col);
 }
}

void circfill(int x, int y, int r, int col)
{
 int f = 1 - r;
 int ddF_x = 0;
 int ddF_y = -2 * r;
 int cx = 0;
 int cy = r;

 pset(x, y + r, col);
 pset(x, y - r, col);
 line(x + r, y, x - r, y, col);

 while (cx < cy) {
  if (f >= 0) {
   cy--;
   ddF_y += 2;
   f += ddF_y;
  }

  cx++;
  ddF_x += 2;
  f += ddF_x + 1;

  line(x + cx, y + cy, x - cx, y + cy, col);
  line(x + cx, y - cy, x - cx, y - cy, col);
  line(x + cy, y + cx, x - cy, y + cx, col);
  line(x + cy, y - cx, x - cy, y - cx, col);
 }
}

void cls(int col)
{
 rectfill(0, 0, 128, 128, col);
}

void line(int x0, int y0, int x1, int y1, int col)
{
 int dx = abs(x1 - x0);
 int dy = abs(y1 - y0);
 int sy = y0 < y1 ? 1 : -1;
 int sx = x0 < x1 ? 1 : -1;
 int err = (dx > dy ? dx : -dy) / 2;
 for (;;) {
  pset(x0, y0, col);
  if (x0 == x1 && y0 == y1) {
   break;
  }
  int e2 = err;
  if (e2 >- dx) {
   err -= dy;
   x0 += sx;
  }
  if (e2 < dy) {
   err += dx;
   y0 += sy;
  }
 }
}

double mid(double a, double b, double c)
{
 double data[3] = { a, b, c };
 if (data[0] > data[1]) {
  std::swap(data[1], data[0]);
 }
 for (int j = 2; j > 0 && data[j - 1] > data[j]; --j) {
  std::swap(data[j], data[j - 1]);
 }
 return data[1];
}

int nibble(int addr, bool high)
{
 return high
  ? peek(addr) >> 4
  : peek(addr) & 0x0f;
}

void nobble(int addr, bool high, int val)
{
 poke(addr, high
  ? ((val << 4) | (peek(addr) & 0x0f))
  : (((peek(addr) >> 4) << 4) | val)
 );
}

int peek(int addr)
{
 return memory[addr];
}

void poke(int addr, int val)
{
 memory[addr] = val;
}

int pget(int x, int y)
{
 if (x < 0 || y < 0 || x > 127 || y > 127) {
  return 0;
 }
 uint16_t addr = 0x6000 + (y * 64) + floor(x / 2);
 return nibble(addr, x % 2 == 1);
}

void print(const char *str, int x, int y, int col)
{
  int len = strlen(str);
  for (int i = 0; i < len; i++) {
    int lx = x + (i * 4);
    int ly = y;

    for (int j = 0; j < 999; j++) {
      if (font[j].c == NULL) {
        break;
      }

      if (str[i] != font[j].c[0]) {
        continue;
      }

      for (int k = 0; k < 5; k++) {
        for (int l = 0; l < 3; l++) {
          if (font[j].px[k][l]) {
            pset(lx + l, ly + k, col);
          }
        }
      }
    }
  }
}

void pset(int x, int y, int c)
{
 /*
 SDL_Rect rect;
 rect.x = (x - camera_x0) * window_scale;
 rect.y = (y - camera_y0) * window_scale;
 rect.w = 1 * window_scale;
 rect.h = 1 * window_scale;

 SDL_SetRenderDrawColor(renderer, 0, palette[c][0], palette[c][1], palette[c][2]);
 SDL_RenderFillRect(renderer, &rect);
 */
 int16_t xoffset = peek(DRAW_CAMERA_X_LO) + peek(DRAW_CAMERA_X_HI) * 256;
 int16_t yoffset = peek(DRAW_CAMERA_Y_LO) + peek(DRAW_CAMERA_Y_HI) * 256;
 int16_t px = x - xoffset;
 int16_t py = y - yoffset;
 if (px < 0 || py < 0 || px > 127 || py > 127) {
  return;
 }
 uint16_t addr = 0x6000 + (py * 64) + floor(px / 2);
 nobble(addr, px % 2 == 1, c);
}

void rect(int x0, int y0, int x1, int y1, int col)
{
 line(x0, y0, x1, y0, col);
 line(x1, y0, x1, y1, col);
 line(x1, y1, x0, y1, col);
 line(x0, y1, x0, y0, col);
}

void rectfill(int x0, int y0, int x1, int y1, int col)
{
 for (int y = y0; y < y1; y++) {
  line(x0, y, x1, y, col);
 }
}

int sget(int x, int y)
{
  if (x < 0 || y < 0 || x > 127 || y > 127) {
    return 0;
  }
  Uint16 addr = 0x0000 + (y * 64) + floor(x / 2);
  return nibble(addr, x % 2 == 1);
}

void sset(int x, int y, int c)
{
  Uint16 addr = 0x0000 + (y * 64) + floor(x / 2);
  nobble(addr, x % 2 == 1, c);
}

void sspr(int sx, int sy, int sw, int sh, int dx, int dy)
{
 for (int x = 0; x < sw; x++) {
  for (int y = 0; y < sh; y++) {
   int c = sget(sx + x, sy + y);
   if (c != 0) {
    pset(dx + x, dy + y, c);
   }
  }
 }
}

bool touch()
{
 return peek(TOUCH_0_B);
}

void getpixel(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b)
{
 int bpp = surface->format->BytesPerPixel;
 Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp;
 Uint32 pixel;
 switch(bpp) {
  case 1:
   pixel = *p;
   break;
  case 2:
   pixel = *(Uint16 *)p;
   break;
  case 3:
   if(SDL_BYTEORDER == SDL_BIG_ENDIAN) {
    pixel = p[0] << 16 | p[1] << 8 | p[2];
   } else {
    pixel = p[0] | p[1] << 8 | p[2] << 16;
   }
   break;
  case 4:
   pixel = *(Uint32 *)p;
   break;
  default:
   return;
 }
 SDL_GetRGB(pixel, surface->format, r, g, b);
}

void _init()
{
 // mode(MODE_MENU);
 mode(MODE_PLAY);
}

void _tick()
{
 if (update_mode & UPDATE_MENU) {
  if (touch()) {
   mode(MODE_PLAY);
  }
 }

 if (update_mode & UPDATE_CAMERA) {

  if (rotor_collision_frame != NULL &&  helicopter_y-64>camera_y1) {
   camera_ideal_y1 = helicopter_y-64;
  } else {
   int src[] = {
    cave_roof[32] + 1,
    cave_floor[32],
    cave_roof[96] + 1,
    cave_floor[96],
   };
   int n = sizeof(src) / sizeof(src[0]);
   std::vector<int> vec(src, src + n);
   camera_ideal_y1 = std::accumulate(vec.begin(), vec.end(), 0.0) / vec.size();
  }

  camera_offset_y1 = camera_y1 - camera_ideal_y1;
  camera_error_y1 = abs(camera_offset_y1);

  if (camera_error_y1 < 1) {
   camera_error_count = 0;
  } else {
   camera_error_count += 1;
  }

  camera_vy = floor(
   camera_offset_y1
   * (camera_error_count / 256)
   * -1
  );

  camera_x1 += camera_vx;
  camera_y1 += camera_vy;
  camera_x2 = camera_x1 + 128;
  camera_y2 = camera_y1 + 128;
 }

 if (update_mode & UPDATE_CAVE) {
 }

 if (update_mode & UPDATE_HELICOPTER) {
  helicopter_vy += helicopter_gravity;
  helicopter_vy += rotor_vy;
  helicopter_vy = mid(
   helicopter_min_vy,
   helicopter_vy,
   helicopter_max_vy
  );
  helicopter_x += helicopter_vx;
  helicopter_y += helicopter_vy;

  if (helicopter_vy > 0 && !rotor_engaged) {
   helicopter_inclination = HELICOPTER_DROPPING;
  } else if (helicopter_vy < 0 && rotor_engaged) {
   helicopter_inclination = HELICOPTER_CLIMBING;
  } else {
   helicopter_inclination = HELICOPTER_HOVERING;
  }
 }

 if (update_mode & UPDATE_ROTOR) {
  rotor_engaged = touch();
  if (rotor_engaged) {
   rotor_vy = rotor_power;
  } else {
   rotor_vy = 0;
  }
 }

 if (update_mode & UPDATE_HITBOX) {
  hitbox_x1 = helicopter_x - 4;
  hitbox_y1 = helicopter_y - 4;
  hitbox_x2 = hitbox_x1 + 8;
  hitbox_y2 = hitbox_y1 + 6;

  for (int x = hitbox_x1; x < hitbox_x2; x++) {
   int i = x - camera_x1;
   int roof = cave_roof[i];
   int floor = cave_floor[i];
   for (int y = hitbox_y1; y < hitbox_y2; y++) {
    int j = x - camera_x1;
    if (y < cave_roof[i]) {
     rotor_collision();
    } else if (y > cave_floor[i]) {
     helicopter_collision();
    }
   }
  }
 }

 if (update_mode & UPDATE_DEAD) {
  if (touch()) {
   mode(MODE_MENU);
  }
 }

 // update_mode |= UPDATE_CAMERA;
 // update_mode |= UPDATE_CAVE;
 // update_mode |= UPDATE_HELICOPTER;
 // update_mode |= UPDATE_ROTOR;
 // update_mode |= UPDATE_HITBOX;
 // update_mode |= UPDATE_COINS;
 // update_mode |= UPDATE_DEBRIS;
 // update_mode |= UPDATE_SMOKE;
}

void _draw()
{
 cls(0);

 if (draw_mode == DRAW_MENU) {
  camera(0, 0);
  sspr(0, 64, 64, 12, 30, 48);
  if (loop(frame_count, 64, 2) == 0) {
   print("tap to start", 38, 64, 7);
  }
  return;
 }

 if (draw_mode & DRAW_CAMERA) {
  camera(camera_x1, camera_y1);
 }

 if (draw_mode & DRAW_CAVE) {
  for (int i = 0; i < 128; i++) {
   pset(i, cave_floor[i], 7);
   pset(i, cave_roof[i], 7);
  }
 }

 if (draw_mode & DRAW_HELICOPTER) {
  int helicopter_sprite_column = helicopter_inclination;
  int helicopter_sprite_x = (helicopter_sprite_column - 1) * 16;
  sspr(
   0,
   0,
   16,
   8,
   helicopter_x - 8,
   helicopter_y - 4
  );
 }

 if (draw_mode & DRAW_HITBOX) {
  rect(
   hitbox_x1,
   hitbox_y1,
   hitbox_x2,
   hitbox_y2,
   11
  );
  for (int x = hitbox_x1; x < hitbox_x2; x++) {
   int i = x - camera_x1;
   pset(x, cave_floor[i], 11);
   pset(x, cave_roof[i], 11);
  }
 }
}

int loop(int n, int m, int o)
{
 return floor(n % m / floor(m / o));
}

void mode(int mode)
{
 if (mode == MODE_MENU) {
  update_mode = UPDATE_MENU;
  draw_mode = DRAW_MENU;
  return;
 }

 if (mode == MODE_PLAY) {
  cave_floor.fill(118);
  cave_roof.fill(7);

  camera_x1 = 0;
  camera_y1 = 0;
  camera_x2 = 128;
  camera_y2 = 128;
  camera_vx = 2;
  camera_vy = 0;

  helicopter_x = 48;
  helicopter_y = 80;
  helicopter_vx = 2;
  helicopter_vy = 0;
  helicopter_inclination = HELICOPTER_DROPPING;
  helicopter_collision_frame = NULL;

  rotor_collision_frame = NULL;

  update_mode = (
   UPDATE_CAMERA
   | UPDATE_CAVE
   | UPDATE_HELICOPTER
   | UPDATE_ROTOR
   | UPDATE_HITBOX
  );

  draw_mode = (
   DRAW_CAMERA
   | DRAW_CAVE
   | DRAW_HELICOPTER
   | DRAW_ROTOR
   | DRAW_HITBOX
  );
 }

 if (mode == MODE_DEAD) {
  update_mode = (
   UPDATE_DEAD
  );
  draw_mode = (
   DRAW_CAVE
  );
 }
}

void rotor_collision()
{
 if (rotor_collision_frame != NULL) {
  return;
 }
 rotor_collision_frame = frame_count;
 rotor_engaged = false;
 rotor_vy = 0;
 helicopter_vy = 2;
 helicopter_max_vy = 4;
 update_mode &= ~UPDATE_ROTOR;
 draw_mode &= ~DRAW_ROTOR;
}

void helicopter_collision()
{
 if (helicopter_collision_frame != NULL) {
  return;
 }
 helicopter_collision_frame = frame_count;
 rotor_engaged = false;
 rotor_vy = 0;
 helicopter_vy = 0;
 helicopter_vx = 0;
 // camera_vx = 0;
 mode(MODE_DEAD);
}