#include <iostream>
#include <algorithm>
#include "SDL.h"
#include "SDL_image.h"

SDL_Window *window;
SDL_Renderer *renderer;
SDL_Texture *spritesheet;
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
void line(int x0, int y0, int x1, int y1, int col);
void pset(int x, int y, int c);
void rect(int x0, int y0, int x1, int y1, int col);
void rectfill(int x0, int y0, int x1, int y1, int col);

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
 spritesheet = IMG_LoadTexture(renderer, "nosedive.png");
 camera_x0 = 0;
 camera_x1 = 0;
 camera_x2 = 127;
 camera_y0 = 0;
 camera_y1 = 0;
 camera_y2 = 127;

 for (int addr = 0x6000; addr <= 0x7FFF; addr++) {
  memory[addr] = 0;
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

 SDL_RenderCopy(renderer, spritesheet, &src, &dst);

 pset(0, 0, 8);
 pset(127, 127, 8);
 line(32, 32, 64, 64, 9);
 rectfill(100, 8, 108, 16, 10);
 rect(0, 0, 127, 127, 11);
 
 // camera(camera_x1 + 1, 0);

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

void pset(int x, int y, int c)
{
 SDL_Rect rect;
 rect.x = (x - camera_x0) * window_scale;
 rect.y = (y - camera_y0) * window_scale;
 rect.w = 1 * window_scale;
 rect.h = 1 * window_scale;

 SDL_SetRenderDrawColor(renderer, 0, palette[c][0], palette[c][1], palette[c][2]);
 SDL_RenderFillRect(renderer, &rect);
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
