#include <iostream>
#include <algorithm>
#include "SDL.h"
#include "SDL_image.h"

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

int window_width;
int window_height;
int window_scale;

int camera_x0;
int camera_x1;
int camera_x2;
int camera_y0;
int camera_y1;
int camera_y2;

std::size_t target_frame_duration = 16;
Uint32 title_timestamp;
int frame_count = 0;
bool running = true;

void init();
void loop();
void tick();
void draw();

int pow2(int n);

void camera(int x, int y);
void circ (int x, int y, int r, int col);
void circfill(int x, int y, int r, int col);
void line(int x0, int y0, int x1, int y1, int col);
int nibble(int addr, bool high);
void nobble(int addr, bool high, int val);
int peek(int addr);
void poke(int addr, int val);
int pget(int x, int y);
void pset(int x, int y, int c);
void rect(int x0, int y0, int x1, int y1, int col);
void rectfill(int x0, int y0, int x1, int y1, int col);
int sget(int x, int y);
void sset(int x, int y, int c);
void sspr(int sx, int sy, int sw, int sh, int dx, int dy);

void getpixel(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b);

int main()
{
 init();
 loop();
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
 camera_x0 = 0;
 camera_x1 = 0;
 camera_x2 = 127;
 camera_y0 = 0;
 camera_y1 = 0;
 camera_y2 = 127;

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
}

void loop()
{
 while (running) {
  tick();
  draw();
 }
}

void tick()
{
 Uint32 frame_start = SDL_GetTicks();
 SDL_Event e;

 while (SDL_PollEvent(&e)) {
  switch (e.type) {

   case SDL_KEYDOWN:
    switch (e.key.keysym.sym) {
     case SDLK_UP:
      running = false;
      break;
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
      bar_height = (window_height - window_width) / 2;
      camera_y0 = camera_y1 - (bar_height / window_scale);
      camera_x0 = camera_x1;
     }
     if (window_width > window_height) {
      bar_width = (window_width - window_height) / 2;
      camera_x0 = camera_x1 - (bar_width / window_scale);
      camera_y0 = camera_y1;
     }
     printf("bar height: %d\n", bar_height);
     printf("bar width: %d\n", bar_width);
    }
    break;

  }
 }

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
 SDL_Rect src;
 src.x = 0;
 src.y = 0;
 src.w = 128;
 src.h = 128;

 SDL_Rect dst;
 dst.x = 0;
 dst.y = 0 - camera_y0 * window_scale;
 dst.w = window_width;
 dst.h = window_height;

 // SDL_RenderCopy(renderer, spritesheet, &src, &dst);

 pset(0, 0, 8);
 pset(127, 127, 8);
 line(32, 32, 64, 64, 9);
 rectfill(100, 8, 108, 16, 10);
 rect(0, 0, 127, 127, 11);
 sspr(0, 0, 128, 128, 0, 0);
 
 // camera(camera_x1 + 1, 0);

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
 camera_x1 = x;
 camera_x2 = x + 128;
 camera_y0 = y;
 camera_y1 = y;
 camera_y2 = y + 128;
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
