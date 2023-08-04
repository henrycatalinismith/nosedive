#include <iostream>
#include "SDL.h"
#include "SDL_image.h"

SDL_Window *window;
SDL_Renderer *renderer;
SDL_Surface *spritesheet;

std::size_t target_frame_duration = 16;
Uint32 title_timestamp;
int frame_count = 0;
bool running = true;

void init();
void loop();
void tick();
void draw();

int main() {
 init();
 loop();
}

void init() {
 window = SDL_CreateWindow(
  "nosedive",
  SDL_WINDOWPOS_CENTERED,
  SDL_WINDOWPOS_CENTERED,
  128,
  128,
  SDL_WINDOW_SHOWN
 );
 renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
 spritesheet = IMG_Load("nosedive.png");
}

void loop() {
 while (running) {
  tick();
  draw();
 }
}

void tick() {
 Uint32 frame_start = SDL_GetTicks();
 SDL_Event e;

 while (SDL_PollEvent(&e)) {
  if (e.type == SDL_QUIT) {
   running = false;
  } else if (e.type == SDL_KEYDOWN) {
   switch (e.key.keysym.sym) {
    case SDLK_UP:
     running = false;
     break;
   }
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

void draw() {
 // SDL_Surface *s = IMG_Load("nosedive.png");
 SDL_Texture *t = IMG_LoadTexture(renderer, "nosedive.png");

 SDL_Rect src;
 src.x = 0;
 src.y = 0;
 src.w = 128;
 src.h = 128;

 SDL_Rect dst;
 dst.x = 0;
 dst.y = 0;
 dst.w = 128;
 dst.h = 128;

 SDL_RenderCopy(renderer, t, &src, &dst);
 SDL_RenderPresent(renderer);
 // SDL_DestroyTexture(t);
}
