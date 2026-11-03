pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
 cartdata("nosedive")
 high_score = dget(0)
 -- high_score = nil
 if high_score == nil then
  high_score = 0
  dset(0, 0)
 end
 new_record = false

 update_mode = 0
 update_camera = 1
 update_cave = 2
 update_helicopter = 4
 update_rotor = 8
 update_hitbox = 16
 update_debris = 32
 update_coins = 64
 update_smoke = 128
 update_menu = 256
 update_dead = 512
 update_fuel = 1024

 update_enable(update_camera)
 update_enable(update_cave)
 update_enable(update_helicopter)
 update_enable(update_rotor)
 update_enable(update_hitbox)
 update_enable(update_coins)
 update_enable(update_debris)
 update_enable(update_smoke)

 draw_mode = 0
 draw_cave = 1
 draw_helicopter = 2
 draw_rotor = 4
 draw_hitbox = 8
 draw_debris = 16
 draw_coins = 32
 draw_debug = 64
 draw_smoke = 128
 draw_menu = 256
 draw_dead = 512
 draw_fuel = 1024

 draw_enable(draw_cave)
 draw_enable(draw_helicopter)
 draw_enable(draw_rotor)
 -- draw_enable(draw_hitbox)
 draw_enable(draw_coins)
 draw_enable(draw_debris)
 draw_enable(draw_debug)
 draw_enable(draw_smoke)

 clock_frame = 0
 score = 0
 score_display = 0
 score_changed_frame = nil
 score_multiplier = {1, 5, 20, 50}
 camera_shake_intensity = 0
 camera_shake_decay = 0.7
 camera_x1 = 0
 camera_y1 = 0
 boost_engaged_frame = nil
 boost_charge_armed = false
 boost_disabled_after_rotor = false
 boost_blast_radius = 8
 boost_debris_per_frame = 3
 tunnel_powerup_duration = 64
 tunnel_powerup_grace = 16
 tunnel_powerup_frame = nil
 tunnel_last_carve_frame = nil
 tunnel_powerup_active = false
 previous_tunnel_powerup_active = false
 previous_tunneling = false
 tunnel_sfx_interval = 16
 coin_cooldown_slow = 48
 coin_cooldown_fast = 32
 coin_cooldown_very_fast = 32
 coin_reachable_y = 24
 coin_fuel_gain = 16
 rock_wall_clearance = 16
 rock_min_gap = 12
 fuel_drain_slow = 8
 fuel_drain_fast = 4
 fuel_drain_interval = fuel_drain_slow
 rotor_sfx_interval = 16
 fuel = 64
 fuel_max = 64
 fuel_empty_threshold = 32
 fuel_speed3_threshold = 48
 fuel_speed4_threshold = 56
 speed_up_flash_duration = 32
 speed_up_frame = nil
 fuel_gained_frame = nil
 fuel_gained_from = 0
 helicopter_speed_x_offset = 12
 helicopter_x_follow_speed = 0.25
 death_min_frames = 180
 dead_age = 0
 mode("menu")
end

function _update60()
 clock_frame += 1

 -- Animate the HUD score toward its real value without jumping.
 if score_display < score then
  score_display += max(1, flr((score - score_display + 7) / 8))
 end

 if update(update_fuel) and clock_frame % fuel_drain_interval == 0 then
  fuel = max(0, fuel - 1)
 end

 if update(update_menu) then
  if btnp() > 0 then
   mode("play")
  end
 end

 -- Drive the lockout from the visible death state itself, so if the death
 -- screen is drawn its timer is guaranteed to advance.
 if draw(draw_dead) then
  dead_age += 1
  if dead_age == 128 then
   music(62)
  end
  if dead_age >= death_min_frames and (btn(4) or btn(5)) then
   mode("menu")
  end
 end

 if update(update_camera) then
  -- Don't chase the cave center: angular terrain made that oscillation
  -- nauseating. Keep the camera still inside a generous player dead zone,
  -- then follow gently only as the helicopter approaches a screen edge.
  local screen_y = helicopter_y - camera_y1
  camera_ideal_y1 = camera_y1

  if rotor_collision_frame then
   camera_ideal_y1 = helicopter_y - 64
  elseif screen_y < 44 then
   camera_ideal_y1 = helicopter_y - 44
  elseif screen_y > 84 then
   camera_ideal_y1 = helicopter_y - 84
  end

  camera_offset_y1 = camera_ideal_y1 - camera_y1
  -- Fast enough to catch the helicopter at terminal velocity, while the
  -- proportional response keeps small corrections from snapping.
  camera_vy = mid(-3, camera_offset_y1 * 0.25, 3)

  camera_y1 += camera_vy
  camera_y2 = camera_y1 + 128
 end

 if update(update_fuel) then
  -- Each time a non-full gauge is filled back to max, advance one speed
  -- tier, up to speed 4. Starting a run at max does not trigger it.
  if fuel < fuel_max then boost_charge_armed = true end
  if not boost_disabled_after_rotor
    and boost_charge_armed
    and fuel >= fuel_max
    and cave_vx < 4 then
   boost_engaged_frame = clock_frame
   tunnel_powerup_frame = clock_frame
   tunnel_last_carve_frame = clock_frame
   boost_charge_armed = false
   set_cave_vx(cave_vx + 1)
  end

  -- Higher tiers step down at progressively higher fuel reserves.
  if cave_vx >= 4 and fuel < fuel_speed4_threshold then
   set_cave_vx(3)
  elseif cave_vx == 3 and fuel < fuel_speed3_threshold then
   set_cave_vx(2)
  elseif cave_vx == 2 and fuel < fuel_empty_threshold then
   boost_engaged_frame = nil
   set_cave_vx(1)
  end
 end

 tunnel_powerup_active = false
 local tunneling = false
 if tunnel_powerup_frame ~= nil then
  local tunnel_age = clock_frame - tunnel_powerup_frame
  local recently_carving = tunnel_last_carve_frame ~= nil
    and clock_frame - tunnel_last_carve_frame < tunnel_powerup_grace
  tunnel_powerup_active = tunnel_age < tunnel_powerup_duration
    or recently_carving
    or helicopter_in_isolated_tunnel()
  if not tunnel_powerup_active then
   tunnel_powerup_frame = nil
   tunnel_last_carve_frame = nil
  end
 end

 if tunnel_powerup_active and not previous_tunnel_powerup_active then
  sfx(39, 2)
 elseif not tunnel_powerup_active and previous_tunnel_powerup_active then
  sfx(-1, 2)
 end
 previous_tunnel_powerup_active = tunnel_powerup_active

 if tunnel_powerup_active
   and helicopter_x ~= nil
   and cave_spans_arr ~= nil
   and boost_engaged_frame ~= nil then
  -- Briefly protect the player while a newly selected speed biome arrives.
  local carved = carve_terrain(
   helicopter_x + 4,
   helicopter_y,
   boost_blast_radius,
   boost_debris_per_frame
  )
  if carved then
   tunnel_last_carve_frame = clock_frame
   tunneling = true
  end
 end

 if tunneling
   and (not previous_tunneling or clock_frame % tunnel_sfx_interval == 0) then
  sfx(36, 1)
 elseif not tunneling and previous_tunneling then
  sfx(-1, 1)
 end
 previous_tunneling = tunneling

 if update(update_cave) then
  for i = 1,cave_vx do
   cave_head = (cave_head % chunk_length) + 1

   chunk_progress += 1
   local force_new_chunk = biome_policy_dirty
     or boost_engaged_frame == clock_frame and i == 1

   if chunk_progress < chunk_length and not force_new_chunk then
    chunk_p = chunk_progress / chunk_length
   elseif chunk_progress == chunk_length and not force_new_chunk then
    chunk_p = 1
    dbg("last chunk_progress=" .. chunk_progress)
   else
    dbg("nxtchunk " .. chunk_progress .. ", " .. cave_y2 - cave_y1)

    chunk_progress = 0
    chunk_p = 0
    chunk_y1 = cave_y1

    if biome_policy_dirty then
     next_biome()
     chunk_fn = biome_next_chunk()
     biome_policy_dirty = false
    else
     chunk_fn = biome_next_chunk()
     if chunk_fn == nil then
      next_biome()
      chunk_fn = biome_next_chunk()
     end
    end
    biome_chunk_count += 1

    dbg(chunk_y1)
   end

   next_slice = chunk_fn(chunk_p)

   add_cave(
    chunk_length,
    chunk_y1 + next_slice[1],
    chunk_y1 + next_slice[2],
    next_slice.rocks
   )
   cave_y1 = cave_roof_y(chunk_length)
   cave_y2 = cave_floor_y(chunk_length)
   cave_height = cave_y2 - cave_y1
   coin_height = cave_roof_y(128) + ((
    cave_floor_y(128) - cave_roof_y(128)
   ) / 2) - 4
  end
 end

 if update(update_rotor) then
  rotor_engaged = btn(5) and fuel > 0
  -- While tunneling outside the corridor, steer the throttle back toward it.
  if tunnel_powerup_active then
   local steer = tunnel_steer()
   if steer == "up" then
    rotor_engaged = fuel > 0
   elseif steer == "down" then
    rotor_engaged = false
   end
  end
  if rotor_engaged
    and (not previous_rotor_engaged or clock_frame % rotor_sfx_interval == 0) then
   sfx(34, 0)
  elseif not rotor_engaged and previous_rotor_engaged then
   sfx(-1, 0)
  end
  previous_rotor_engaged = rotor_engaged
  if rotor_engaged then
   rotor_vy = rotor_power
  else
   rotor_vy = 0
  end
 end

 if update(update_helicopter) then
  -- Higher speeds move the helicopter left for more look-ahead. Approach
  -- the target at a capped rate so speed transitions never cause a jump.
  local helicopter_target_x = 48 - (cave_vx - 1) * helicopter_speed_x_offset
  local helicopter_dx = helicopter_target_x - helicopter_x
  if abs(helicopter_dx) < 0.1 then
   helicopter_x = helicopter_target_x
  else
   helicopter_x += mid(
    -helicopter_x_follow_speed,
    helicopter_dx * 0.1,
    helicopter_x_follow_speed
   )
  end

  helicopter_vy += helicopter_gravity
  helicopter_vy += rotor_vy
  helicopter_vy = mid(
   helicopter_min_vy,
   helicopter_vy,
   helicopter_max_vy
  )
  helicopter_y += helicopter_vy

  if helicopter_vy > 0 and not rotor_engaged then
   helicopter_inclination = "dropping"
  elseif helicopter_vy < 0 and rotor_engaged then
   helicopter_inclination = "climbing"
  else
   helicopter_inclination = "hovering"
  end

 end

 if update(update_hitbox) then
  hitbox_x1 = helicopter_x - 4
  hitbox_y1 = helicopter_y - 4
  hitbox_x2 = hitbox_x1 + 8
  hitbox_y2 = hitbox_y1 + 6

  for x = hitbox_x1,hitbox_x2 do
   local i = flr(x)
   if not tunnel_powerup_active then
    local roof = cave_roof_y(i)
    local floor = cave_floor_y(i)
    for y = hitbox_y1,hitbox_y2 do
     if y < roof then
      rotor_collision()
      goto boom
     end
     if y > floor then
      helicopter_collision()
      goto boom
     end
     for span in all(cave_spans(i)) do
      if span.rock ~= nil and y >= span.top and y <= span.bottom then
       if y < helicopter_y - 2 then
        rotor_collision()
       else
        helicopter_collision()
       end
       goto boom
      end
     end
    end
   end

   for coin in all(coins) do
    if coin.x1 > hitbox_x2 then
     -- coin ahead
    elseif coin.x2 > hitbox_x1 then
     if coin.hit == nil
      and (coin.x1 < x and coin.x2 > x)
      and not (coin.y2 < hitbox_y1 or coin.y1 > hitbox_y2)
      then
      -- cave_vx += 1
      coin.hit = clock_frame
      score += score_multiplier[cave_vx]
      score_changed_frame = clock_frame
      sfx(35, 1)
      fuel_gained_from = fuel
      fuel = min(fuel_max, fuel + coin_fuel_gain)
      fuel_gained_frame = clock_frame
      camera_shake_intensity = 5
      camera_shake_decay = 0.6

      for i = 1,64 do
       add(debris, {
        color = choose({9,10}),
        x = coin.x1,
        y = coin.y1+2,
        vx = -2+rnd(4),
        vy = helicopter_vy + rnd(8) * (rnd(2) - 1),
        age = 0,
       })
      end
     end

    elseif coin.hit == nil and coin.miss == nil then
     coin.miss = clock_frame
    end

   end

  end
  ::boom::
 end

 if update(update_debris) then
  for d in all(debris) do
   d.x -= cave_vx
   d.age += 1
   if d.x <= 0 or d.x >= 128 or d.age > 120 then
    del(debris, d)
    goto continue_debris
   end
   if d.vx == 0 and d.vy == 0 then goto continue_debris end

   d.vy += 0.1
   d.vy = mid(-4, d.vy, 4)

   if is_space(d.x + d.vx, d.y) then
    d.x += d.vx
   else
    d.vx *= rnd(0.3) * -1 * d.vx
    d.vy = 0
   end

   local i = flr(d.x)
   if i > 128 or i < 1 then
    -- ignore out of screen debris
   elseif d.y + flr(d.vy) < cave_roof_y(i) then
    -- debris hits roof
    d.vy *= rnd(0.5) * - 1
    d.vx = rnd(0.2)
   elseif d.y + flr(d.vy) > cave_floor_y(i) then
    -- debris hits floor
    d.vy *= rnd(0.3) * - 1
    d.vx = rnd(0.2)
   else
    -- debris can move
    d.y += d.vy
   end

   ::continue_debris::
  end
 end

 if update(update_coins) then
  for coin in all(coins) do
   coin.x1 -= cave_vx
   coin.x2 -= cave_vx
   if coin.x2 < 0
    or coin.hit and clock_frame - coin.hit > 16 then
    del(coins, coin)
   end
  end

  if (#coins == 0 or coins[#coins].x2 < 120) and biome_id != "start" then
   if coin_cooldown_frame <= coin_cooldown_limit then
    coin_cooldown_frame += 1
   else
    coin_cooldown_frame = 0
    -- Spawn fully beyond the visible 0..127 screen, attached to the
    -- rightmost cave column so terrain and coin scroll in together.
    local x1 = 128
    local cx1 = 128

    local top = nil   -- will be filled: y of the boundary above the coin gap
    local btm = nil   -- y of the boundary below the coin gap

    local rock_span = nil
    for span in all(cave_spans(cx1)) do
     if span.rock ~= nil then rock_span = span end
    end

    if rock_span then
     top_gap = abs(cave_roof_y(cx1) - rock_span.top)
     btm_gap = abs(cave_floor_y(cx1) - rock_span.bottom)
     if top_gap > btm_gap then
      top = cave_roof_y(cx1)
      btm = rock_span.top
     else
      top = rock_span.bottom
      btm = cave_floor_y(cx1)
     end
    else
     top = cave_roof_y(cx1)
     btm = cave_floor_y(cx1)
    end

    local y1 = top + ((btm - top) / 2) - 4
    local valid_y1 = top + 1
    local valid_y2 = btm - 10

    if valid_y1 <= valid_y2 then
     y1 = mid(valid_y1, y1, valid_y2)
     if last_coin_y1 ~= nil then
      local reachable_y1 = last_coin_y1 - coin_reachable_y
      local reachable_y2 = last_coin_y1 + coin_reachable_y
      local biased_y1 = max(valid_y1, reachable_y1)
      local biased_y2 = min(valid_y2, reachable_y2)
      if biased_y1 <= biased_y2 then
       y1 = mid(biased_y1, y1, biased_y2)
      end
     end
    end

    last_coin_y1 = y1
    local x2 = x1+9
    local y2 = y1+9
    add(coins, {
      x1 = x1,
      y1 = y1,
      x2 = x2,
      y2 = y2,
    })
   end
  end
 end

 if update(update_smoke) then
  if fuel > 0 and helicopter_collision_frame == nil and clock_frame % 4 == 0 then
   local radius = 1
   if rotor_collision_frame then
    radius = 2
   elseif rotor_engaged then
    radius = 4 - rnd(2)
   end
   local smoke_color = 5
   if cave_vx >= 4 then
    smoke_color = 12
   elseif cave_vx == 3 then
    smoke_color = 8
   elseif cave_vx == 2 then
    -- Speed-2 exhaust communicates throttle state: large powered puffs
    -- are yellow; the smaller unpowered trail is orange.
    if rotor_engaged then
     smoke_color = 10
    else
     smoke_color = 9
    end
   end
   add(smoke, {
    x = helicopter_x - 8,
    y = helicopter_y,
    vx = 0,
    vy = helicopter_vy,
    radius = radius,
    color = smoke_color,
    age = 0,
   })
  end

  for i, puff in pairs(smoke) do
   puff.x -= cave_vx
   puff.x += puff.vx / 16
   puff.y += puff.vy / 8
   puff.age += 1
   if puff.age % 20 == 0 then
    puff.radius -= 1
   end
   if puff.radius < 0 or puff.x < 0 then
    del(smoke, puff)
   end
  end

  for b in all(booms) do
   b.age += 1
   if b.age > b.life then
    del(booms, b)
   end
  end

 end
end

function _draw()
 local camera_shake_x = rnd(camera_shake_intensity) - camera_shake_intensity/2
 local camera_shake_y = rnd(camera_shake_intensity) - camera_shake_intensity/2
 camera(camera_x1 + camera_shake_x, camera_y1 + camera_shake_y)
 camera_shake_intensity *= camera_shake_decay
 if camera_shake_intensity < 0.1 then
  camera_shake_intensity = 0
 end

 cls(0)

 if draw(draw_menu) then
  camera(0, 0)

  sspr(0, 64, 64, 12, 30, 48)

  if loop(clock_frame, 117, 2) == 0 then
   print("tap to start", 39, 64, 6)
  end

  if high_score then
   local hs_text = ""..high_score
   print(hs_text, 64 - #hs_text * 2, 80, 6)
  end
 end

 if draw(draw_coins) then
  for coin in all(coins) do
   local x = coin.x1+1
   local y = coin.y1
   y += loop(clock_frame + coin.x1, 48, 2)
   if coin.hit then
    spr(88 + clock_frame - coin.hit, x, y)
   else
    spr(64 + loop(clock_frame, 24, 24), x, y)
   end
  end
 end

 if draw(draw_cave) then

  local bright = 7
  local dim = 1

  for i = 1,128 do
   local x = i
   local roof = cave_roof_y(i)
   local floor = cave_floor_y(i)

   -- wall fill
   line(x, camera_y1, x, roof, 5)
   line(x, floor, x, camera_y2, 5)

   -- roof/floor blur + edge, derived from neighbours on the fly.
   -- band height = how much a neighbour protrudes into the cave, not
   -- the neighbour's full position (avoids tall blue zones on cliffs).
   local roof_protrude = 0
   local floor_protrude = 0
   for d = -2, 2 do
    if d ~= 0 then
     local nr = cave_roof_y(i + d)
     local nf = cave_floor_y(i + d)
     if roof - nr > roof_protrude then roof_protrude = roof - nr end
     if nf - floor > floor_protrude then floor_protrude = nf - floor end
    end
   end

   -- roof: short blur band + crisp edge where a neighbour dips
   roof_protrude = min(roof_protrude, 3)
   if roof_protrude > 0 then
    line(x, roof - roof_protrude, x, roof, 1)
   end
   local roof_edge_col = dim
   if helicopter_x < i and helicopter_collision_frame == nil
     and helicopter_y - roof - i/2 < 2 then
    roof_edge_col = bright
   end
   if roof_protrude > 0 then
    line(x, roof - roof_protrude, x, roof - roof_protrude, roof_edge_col)
   end

   -- floor: short blur band + crisp edge where a neighbour rises
   floor_protrude = min(floor_protrude, 3)
   if floor_protrude > 0 then
    line(x, floor, x, floor + floor_protrude, 1)
   end
   local floor_edge_col = dim
   if helicopter_x < i and helicopter_collision_frame == nil
     and floor - helicopter_y - i/2 < 8 then
    floor_edge_col = bright
   end
   if floor_protrude > 0 then
    line(x, floor + floor_protrude, x, floor + floor_protrude, floor_edge_col)
   end

   -- rocks: every span with an identity, drawn independently
   for span in all(cave_spans(i)) do
    if span.rock ~= nil then
     local rock_top = span.top
     local rock_bottom = span.bottom
     line(x, rock_top, x, rock_bottom, 5)

     -- rock top/bottom blur, derived from same-rock neighbours.
     -- the blur/edge band is only as tall as the *amount* a neighbour
     -- protrudes (its top being lower / bottom being higher), not the
     -- full distance to that neighbour ヌ█⬆️ otherwise a steep taper paints
     -- a tall blue column into the cave.
     local rt_protrude = 0
     local rb_protrude = 0
     for d = -2, 2 do
      if d ~= 0 then
       for nb in all(cave_spans(i + d)) do
        if nb.rock == span.rock then
         if rock_top - nb.top > rt_protrude then rt_protrude = rock_top - nb.top end
         if nb.bottom - rock_bottom > rb_protrude then rb_protrude = nb.bottom - rock_bottom end
        end
       end
      end
     end

     -- short blur band above the rock top / below the rock bottom.
     -- capped so a steep rock taper doesn't paint a tall solid band.
     rt_protrude = min(rt_protrude, 3)
     rb_protrude = min(rb_protrude, 3)
     if rt_protrude > 0 then
      line(x, rock_top - rt_protrude, x, rock_top, 1)
     end
     if rb_protrude > 0 then
      line(x, rock_bottom, x, rock_bottom + rb_protrude, 1)
     end

     if helicopter_x < i and helicopter_collision_frame == nil then
      local rt_edge_col = 1
      if helicopter_y - rock_top - i/2 < 8 then rt_edge_col = 7 end
      if rt_protrude > 0 then
       line(x, rock_top - rt_protrude, x, rock_top - rt_protrude, rt_edge_col)
      end

      local rb_edge_col = 1
      if rock_bottom - helicopter_y - i/2 < 8 then rb_edge_col = 7 end
      if rb_protrude > 0 then
       line(x, rock_bottom + rb_protrude, x, rock_bottom + rb_protrude, rb_edge_col)
      end
     end
    end
   end
  end
 end

 if tunnel_powerup_active and helicopter_x ~= nil then
  -- Draw the boost effect first so the helicopter remains in front of it.
  local frame = loop(clock_frame, 8, 8)
  local sprite = 192 + frame * 2
  spr(sprite, helicopter_x - 8, helicopter_y - 8, 2, 2)
 end

 if draw(draw_helicopter) or draw(draw_rotor) then
  helicopter_sprite_column = ({
   hovering = 1,
   dropping = 2,
   climbing = 3,
  })[helicopter_inclination]
  helicopter_sprite_x = (helicopter_sprite_column - 1) * 16
  tail_y_offset = ({
   hovering = 2,
   dropping = 0,
   climbing = 3,
  })[helicopter_inclination]
end

 if draw(draw_helicopter) then
  sspr(
   helicopter_sprite_x,
   0,
   16,
   8,
   helicopter_x - 8,
   helicopter_y - 4
  )
 end

 if draw(draw_rotor) then
  sspr(
   helicopter_sprite_x + 3,
   8 + loop(clock_frame, 32, 8) * 3,
   13,
   3,
   helicopter_x - 5,
   helicopter_y - 5
  )
  sspr(
   helicopter_sprite_x,
   8 + loop(clock_frame, 8, 8) * 3,
   3, 3,
   helicopter_x - 8,
   helicopter_y + tail_y_offset - 4
  )
 end

 if draw(draw_hitbox) then
  rect(
   hitbox_x1,
   hitbox_y1,
   hitbox_x2,
   hitbox_y2,
   11
  )

  for x = hitbox_x1,hitbox_x2 do
   local i = x
   pset(x, cave_floor_y(i), 11)
   pset(x, cave_roof_y(i), 11)
   for span in all(cave_spans(i)) do
    if span.rock ~= nil then
     pset(x, span.top, 11)
     pset(x, span.bottom, 11)
    end
   end
  end

  for coin in all(coins) do
   local coin_color = 11
   if coin.miss ~= nil then
    coin_color = 8
   end
   rect(
    coin.x1,
    coin.y1,
    coin.x2,
    coin.y2,
    coin_color
   )
  end
 end

 if draw(draw_debris) then
  for f in all(debris) do
   pset(
    f.x,
    f.y,
    f.color
   )
  end
 end

 if draw(draw_smoke) then
  for i, puff in pairs(smoke) do
   circ(puff.x, puff.y, puff.radius, puff.color)
  end


 end

 camera(0, 0)

 if draw(draw_fuel) then
  local fuel_disp = fuel
  if fuel_gained_frame ~= nil then
   local dt = clock_frame - fuel_gained_frame
   local dur = 30
   if dt < dur then
    local t = dt / dur
    t = t * t * (3 - 2 * t)
    fuel_disp = fuel_gained_from + (fuel - fuel_gained_from) * t
   end
  end

  local fuel_ratio = fuel_disp / fuel_max

  -- bar: 48px wide, 8px tall, top-left corner
  local bar_x = 4
  local bar_y = 4
  local bar_w = 32
  local bar_h = 8

  local fill_color = 6
  if cave_vx == 2 then
   fill_color = 10
  elseif cave_vx == 3 then
   fill_color = 8
  elseif cave_vx >= 4 then
   fill_color = 12
  end

  local border_outer = 1
  local border_inner = 6
  if speed_up_frame ~= nil
    and clock_frame - speed_up_frame < speed_up_flash_duration then
   local flash = clock_frame % 6 < 3
   if cave_vx == 2 then
    border_outer = flash and 9 or 10
    border_inner = flash and 10 or 9
   elseif cave_vx == 3 then
    border_outer = flash and 8 or 14
    border_inner = flash and 14 or 8
   elseif cave_vx >= 4 then
    border_outer = flash and 12 or 6
    border_inner = flash and 6 or 12
   end
  end

  -- Preview the next tier only if the nearest incoming coin can still fill
  -- the gauge after accounting for fuel burned before it arrives.
  local incoming_coin = next_incoming_coin()
  local predicted_fuel = incoming_coin and fuel_when_coin_arrives(incoming_coin)
  if boost_charge_armed
    and cave_vx < 4
    and predicted_fuel ~= nil
    and predicted_fuel + coin_fuel_gain >= fuel_max then
   if cave_vx == 1 then
    border_inner = 10
   elseif cave_vx == 2 then
    border_inner = 8
   else
    border_inner = 12
   end
  end

  -- two nested borders make the gauge readable against every cave color
  rect(bar_x - 2, bar_y - 2, bar_x + bar_w + 2, bar_y + bar_h + 2, border_outer)
  rect(bar_x - 1, bar_y - 1, bar_x + bar_w + 1, bar_y + bar_h + 1, border_inner)
  rectfill(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 0)
  rectfill(bar_x, bar_y, bar_x + bar_w * fuel_ratio, bar_y + bar_h, fill_color)

  -- flash the fuel sprite centered when nearly empty
  if fuel < fuel_empty_threshold and (clock_frame % 64 < 32) then
   sspr(48, 0, 64, 17, 4, 16)
  end

  local score_text = tostring(score_display)
  local border = 7
  if score_changed_frame ~= nil and clock_frame - score_changed_frame < 16 then
   border = ({8,9,10})[loop(clock_frame, 24, 4) + 1]
  end
  printr(score_text, 124 - #score_text * 4, 4, {border,1,11})
end

if draw(draw_debug) then
  for i,debug_message in pairs(debug_messages) do
   print(debug_message[1], 0, ((i-1)*8)+96, debug_message[2])
  end
  draw_bar("cpu", stat(1), 1, 123)
  -- print(cave_y1, 32, 1, 7)
  print(biome_id, 1, 1, 7)
 end

 if draw(draw_dead) then
  printr("dead", 64 - 4 * 2, 40, {7,1,11})
  if dead_age >= 60 then
   local score_text = score_display.." points"
   printr(score_text, 64 - #score_text * 2, 56, {7,1,11})
  end
  if dead_age >= 120 then
   if new_record then
    local rec_text = "new high score!!"
    local flash = ({8,9,10})[loop(clock_frame, 24, 3) + 1]
    printr(rec_text, 64 - #rec_text * 2, 72, {flash,1,11})
   else
    local hs_text = "high score: "..high_score
    printr(hs_text, 64 - #hs_text * 2, 72, {7,1,11})
   end
  end
  if dead_age >= death_min_frames then
   local tap_text = "tap to continue"
   printr(tap_text, 64 - #tap_text * 2, 88, {7,1,11})
  end
 end
end

-- Direction the throttle must take to return the helicopter to open cave
-- while tunneling: "down" when stuck up in a preserved roof mass, "up" when
-- stuck down in a preserved floor mass, nil when back in ordinary space.
function tunnel_steer()
 if helicopter_x == nil or cave_spans_arr == nil then return nil end
 for x = flr(helicopter_x - 4), flr(helicopter_x + 4) do
  if x >= 1 and x <= 128 then
   for span in all(cave_spans(x)) do
    if span.rock == tunnel_roof_rock and helicopter_y < span.top then
     return "down"
    end
    if span.rock == tunnel_floor_rock and helicopter_y > span.bottom then
     return "up"
    end
   end
  end
 end
 return nil
end

-- True while a preserved wall mass separates the helicopter from the main
-- cave. After the normal shield timer, this keeps tunneling active until the
-- helicopter has actually returned to ordinary cave space.
function helicopter_in_isolated_tunnel()
 return tunnel_steer() ~= nil
end

-- subtract a circular blast from every kind of solid terrain
function carve_terrain(cx, cy, radius, debris_budget)
 debris_budget = debris_budget or 0
 local carved = false
 local x1 = max(1, flr(cx - radius))
 local x2 = min(128, flr(cx + radius))

 for x = x1, x2 do
  local dx = x - cx
  local dy = sqrt(max(0, radius^2 - dx^2))
  local blast_top = cy - dy
  local blast_bottom = cy + dy
  local roof = cave_roof_y(x)
  local floor = cave_floor_y(x)

  -- If the blast is wholly beyond a wall, preserve the solid mass between
  -- the old cave and the new tunnel as an internal span. The outer edge of
  -- the blast becomes the new roof/floor heightfield.
  if blast_top < roof then
   carved = true
   if blast_bottom < roof then
    add_span(x, tunnel_roof_rock, blast_bottom, roof)
    debris_budget = carve_debris(x, blast_top, blast_bottom, debris_budget)
   else
    debris_budget = carve_debris(x, blast_top, roof, debris_budget)
   end
   cave_set_roof(x, blast_top)
  end
  if blast_bottom > floor then
   carved = true
   if blast_top > floor then
    add_span(x, tunnel_floor_rock, floor, blast_top)
    debris_budget = carve_debris(x, blast_top, blast_bottom, debris_budget)
   else
    debris_budget = carve_debris(x, floor, blast_bottom, debris_budget)
   end
   cave_set_floor(x, blast_bottom)
  end

  -- Internal spans can be shortened, removed, or split in two.
  local list = cave_spans_arr[cave_index(x)]
  if list ~= nil then
   for i = #list, 1, -1 do
    local span = list[i]
    if blast_top < span.bottom and blast_bottom > span.top then
     carved = true
     local old_top = span.top
     local old_bottom = span.bottom
     local cut_top = max(old_top, blast_top)
     local cut_bottom = min(old_bottom, blast_bottom)
     debris_budget = carve_debris(x, cut_top, cut_bottom, debris_budget)

     if blast_top <= old_top and blast_bottom >= old_bottom then
      deli(list, i)
     elseif blast_top <= old_top then
      span.top = blast_bottom
     elseif blast_bottom >= old_bottom then
      span.bottom = blast_top
     else
      span.bottom = blast_top
      add(list, {
       rock = span.rock,
       top = blast_bottom,
       bottom = old_bottom,
      })
     end
    end
   end
   sort_spans(list)
  end
 end
 return carved
end

function carve_debris(x, y1, y2, budget)
 if budget <= 0 or y2 <= y1 then return budget end
 add(debris, {
  color = choose({5,6,7,11,12,13}),
  x = x,
  y = y1 + rnd(y2 - y1),
  vx = -2 + rnd(4),
  vy = -2 + rnd(4),
  age = 0,
 })
 return budget - 1
end

function sort_spans(list)
 for i = 2, #list do
  local j = i
  while j > 1 and list[j].top < list[j - 1].top do
   list[j], list[j - 1] = list[j - 1], list[j]
   j -= 1
  end
 end
end

function add_cave(ci, new_roof, new_floor, rock_samples)
 -- Speed 1 and 2 need a reliably flyable passage. Recipe noise is allowed
 -- to vary freely, but it must never collapse the corridor below 72px.
 if cave_vx ~= nil and cave_vx <= 2 then
  new_floor = max(new_floor, new_roof + 72)
 end
 -- walls stored as two plain circular arrays (roof/floor); rocks as spans
 cave_set_roof(ci, new_roof)
 cave_set_floor(ci, new_floor)

 -- this column is being (re)written for the incoming chunk, so discard
 -- any spans a previous chunk left in this circular-buffer slot. Without
 -- this, wrapping slots accumulate stale rock spans over time.
 cave_spans_arr[cave_index(ci)] = nil

 -- rock_samples is a stable list of {top_offset,bottom_offset} pairs.
 -- Keeping absent rocks as empty pairs preserves each stacked rock's slot.
 rock_samples = rock_samples or empty_spans
 local cave_center = (new_roof + new_floor) / 2
 local slots = max(#rock_samples, rock_slot_count)
 local candidates = {}

 for slot = 1, slots do
  local sample = rock_samples[slot]
  local rock_top_offset = sample and sample[1]
  local rock_bottom_offset = sample and sample[2]
  if rock_top_offset == nil or rock_bottom_offset == nil then
   rock_chain[slot] = nil
  else
   local rock = rock_chain[slot]
   if rock == nil then
    rock = {id = next_rock_id}
    next_rock_id += 1
    rock_chain[slot] = rock
   end
   -- First clip every candidate against the actual noisy walls.
   local rock_top = max(
    cave_center + rock_top_offset,
    new_roof + rock_wall_clearance
   )
   local rock_bottom = min(
    cave_center + rock_bottom_offset,
    new_floor - rock_wall_clearance
   )
   if rock_top < rock_bottom then
    add(candidates, {rock = rock, top = rock_top, bottom = rock_bottom})
   end
  end
 end

 -- Wall clipping can make originally separate rocks overlap. Resolve the
 -- final spans together so noise can never turn them into a solid barrier.
 for i = 2, #candidates do
  local j = i
  while j > 1 and candidates[j].top < candidates[j - 1].top do
   candidates[j], candidates[j - 1] = candidates[j - 1], candidates[j]
   j -= 1
  end
 end

 local previous_bottom = nil
 for candidate in all(candidates) do
  local rock_top = candidate.top
  if previous_bottom ~= nil then
   rock_top = max(rock_top, previous_bottom + rock_min_gap)
  end
  if rock_top < candidate.bottom then
   add_span(ci, candidate.rock, rock_top, candidate.bottom)
   previous_bottom = candidate.bottom
  end
 end
 rock_slot_count = #rock_samples
end

function mode(m)
 update_disable(update_mode)
 draw_disable(draw_mode)

 if m == "menu" then
  music(0)
  update_enable(update_menu)
  draw_enable(draw_menu)
 elseif m == "play" then
  music(-1)
  update_enable(update_camera)
  update_enable(update_cave)
  update_enable(update_helicopter)
  update_enable(update_rotor)
  update_enable(update_hitbox)
  update_enable(update_coins)
  update_enable(update_debris)
  update_enable(update_smoke)
  update_enable(update_fuel)

  draw_enable(draw_cave)
  draw_enable(draw_helicopter)
  draw_enable(draw_rotor)
  draw_enable(draw_coins)
  draw_enable(draw_debris)
  -- draw_enable(draw_debug)
  draw_enable(draw_smoke)
  --draw_enable(draw_hitbox)
  draw_enable(draw_fuel)

  camera_x1 = 0
  camera_y1 = 0
  camera_y2 = camera_y1 + 128
  cave_vx = 1
  fuel_drain_interval = fuel_drain_slow
  next_biome = next_biome_angular
  biome_policy_dirty = false
  camera_vy = 0
  camera_ideal_y1 = camera_y1
  camera_offset_y1 = 0

  chunk_p = 0
  chunk_length = 128 * cave_vx
  chunk_progress = 0

  dead_age = 0
  boost_engaged_frame = nil
  boost_charge_armed = false
  boost_disabled_after_rotor = false
  tunnel_powerup_frame = nil
  tunnel_last_carve_frame = nil
  tunnel_powerup_active = false
  previous_tunnel_powerup_active = false
  previous_tunneling = false
  sfx(-1, 1)
  fuel = fuel_max
  fuel_gained_frame = nil
  fuel_gained_from = 0
  speed_up_frame = nil

  biome_chunk_count = 0
  biome_start()
  chunk_fn = biome_next_chunk()
  biome_chunk_count += 1

  local start_slice = chunk_fn(0)
  local start_roof = start_slice[1]
  local start_floor = start_slice[2]

  -- span-based terrain: walls + rocks as per-column span lists
  cave_roof_arr = fill(chunk_length, start_roof)
  cave_floor_arr = fill(chunk_length, start_floor)
  cave_spans_arr = {}
  next_rock_id = 1
  -- Wall masses isolated by tunneling become ordinary internal spans.
  tunnel_roof_rock = {id = next_rock_id}
  next_rock_id += 1
  tunnel_floor_rock = {id = next_rock_id}
  next_rock_id += 1
  rock_chain = {}
  rock_slot_count = 0

  cave_head = 1

  coin_height = 64
  coin_cooldown_frame = clock_frame
  coin_cooldown_limit = coin_cooldown_slow

  for x = 1,chunk_length do
   local slice = chunk_fn(x/chunk_length)
   add_cave(x, slice[1], slice[2], slice.rocks)
  end

  -- The initial buffer already contains the complete start chunk. Mark it
  -- consumed so gameplay immediately starts generating the first real biome
  -- instead of appending a second full start chunk.
  chunk_progress = chunk_length
  chunk_p = 1

  cave_y1 = cave_roof_y(chunk_length)
  cave_y2 = cave_floor_y(chunk_length)
  chunk_y1 = cave_y1

  coins = {}
  score = 0
  score_display = 0
  new_record = false
  last_coin_y1 = nil

  debug_messages = {}
  debug_color = 8

  helicopter_x = 48
  helicopter_y = 32
  helicopter_vy = 2
  helicopter_inclination = "dropping"
  helicopter_gravity = 0.1
  helicopter_min_vy = -1.5
  helicopter_max_vy = 2

  hitbox_x1 = helicopter_x - 4
  hitbox_y1 = helicopter_y - 4
  hitbox_x2 = hitbox_x1 + 8
  hitbox_y2 = hitbox_y1 + 6

  rotor_engaged = false
  previous_rotor_engaged = false
  rotor_vy = 0
  rotor_power = -0.3

  debris = {}

  rotor_collision_frame = nil
  helicopter_collision_frame = nil

  smoke = {}
  booms = {}
 elseif m == "dead" then
  music(-1)
  dead_age = 0
  update_enable(update_dead)
  update_enable(update_debris)
  update_enable(update_smoke)
  update_enable(update_camera)

  draw_enable(draw_dead)
  draw_enable(draw_cave)
  draw_enable(draw_coins)
  draw_enable(draw_debris)
  -- draw_enable(draw_debug)
  draw_enable(draw_smoke)
 end
end


function nearest(t, n)
 local v = 1
 for i = 2,#t do
  if abs(t[i] - n) < abs(t[v] - n) then
   v = i
  end
 end
 return v
end

function is_space(x, y)
 local i = flr(x)
 if i > 128 or i < 1 then
  return true
 end
 if y < cave_roof_y(i) then
  return false
 end
 if y > cave_floor_y(i) then
  return false
 end
 for span in all(cave_spans(i)) do
  if span.rock ~= nil then
   if y >= span.top and y <= span.bottom then
    return false
   end
  end
 end
 return true
end

function rotor_collision()
  dbg("rotor collision")
  if rotor_collision_frame then
   return
  end

  rotor_collision_frame = clock_frame
  sfx(38, 2)
  camera_shake_intensity = 6
  camera_shake_decay = 0.7

  for i = 1,32 do
   add(debris, {
    color = choose({0,0,0,0,0,0,0,0,0,5,6,6,7,11}),
    x = helicopter_x,
    y = helicopter_y + 4,
    vx = -2 + rnd(4),
    vy = 0 - rnd(2),
    age = 0,
   })
  end

  rotor_engaged = false
  previous_rotor_engaged = false
  sfx(-1, 0)
  rotor_vy = 0
  -- Hitting the ceiling ends the boost tunnel immediately. Clear the
  -- source timers too, otherwise the next update can restore invincibility.
  tunnel_powerup_active = false
  previous_tunnel_powerup_active = false
  previous_tunneling = false
  sfx(-1, 1)
  tunnel_powerup_frame = nil
  tunnel_last_carve_frame = nil
  boost_engaged_frame = nil
  boost_charge_armed = false
  boost_disabled_after_rotor = true
  helicopter_vy = 2
  helicopter_max_vy = 4
  update_disable(update_rotor)
  update_enable(update_debris)
  draw_disable(draw_rotor)
  draw_disable(draw_hitbox)
  draw_enable(draw_debris)
end

function helicopter_collision()
 dbg("helicopter collision")
 sfx(37, 2)
 helicopter_collision_frame = clock_frame
 camera_shake_intensity = 10
 camera_shake_decay = 0.85

 helicopter_y = min(helicopter_y, cave_floor_y(helicopter_x) - 2)

 for i = 1,128 do
  add(debris, {
   color = choose({3,4,11}),
   x = helicopter_x,
   y = helicopter_y,
   vx = -1 + rnd(2),
   vy = 0 - rnd(2),
   age = 0,
  })
 end

 rotor_engaged = false
 previous_rotor_engaged = false
 sfx(-1, 0)
 rotor_vy = 0
 helicopter_vy = 0
 cave_vx = 0

 if score > high_score then
  high_score = score
  new_record = true
  dset(0, high_score)
 end

 mode("dead")
end

function printr(text, x, y, colors)
 for ir, col in pairs(colors) do
  local r = #colors - ir
  for i = x-r, x+r do
   for j = y-r, y+r do
    print(text, i, j, col)
   end
  end
 end
end

function dbg(message)
 while #debug_messages >= 4 do
  del(debug_messages, debug_messages[1])
 end
 debug_color += 1
 if debug_color > 15 then
  debug_color = 8
 end
 add(debug_messages, { message, debug_color })
end

function update(flag)
 return (update_mode & flag) != 0
end

function update_enable(flag)
 update_mode |= flag
end

function update_disable(flag)
 update_mode &= ~flag
end

function draw(flag)
 return (draw_mode & flag) != 0
end

function draw_enable(flag)
 draw_mode |= flag
end

function draw_disable(flag)
 draw_mode &= ~flag
end

function loop(n, m, o)
 return flr(n % m / flr(m / o))
end

function next_incoming_coin()
 local nearest_coin = nil
 for coin in all(coins) do
  if coin.hit == nil and coin.miss == nil and coin.x2 >= helicopter_x then
   if nearest_coin == nil or coin.x1 < nearest_coin.x1 then
    nearest_coin = coin
   end
  end
 end
 return nearest_coin
end

function fuel_when_coin_arrives(coin)
 local distance = max(0, coin.x1 - helicopter_x)
 local frames = distance / max(1, cave_vx)
 local first_drain = fuel_drain_interval - (clock_frame % fuel_drain_interval)
 local drains = 0
 if frames >= first_drain then
  drains = 1 + flr((frames - first_drain) / fuel_drain_interval)
 end
 return max(0, fuel - drains)
end

function avg(l)
 local t = 0
 for i in all(l) do
  t += i
 end
 return t / #l
end

function fill(n, v)
 local tbl = {}
 for i = 1,n do
  add(tbl, v)
 end
 return tbl
end

function flrrnd(n)
 return flr(rnd(n))
end

function last(t)
 return t[#t]
end

function chunk(y1, y2, ...)
 -- each trailing argument is a {top_fn,bottom_fn} rock pair
 local c = {y1, y2}
 c.rocks = {...}
 setmetatable(c, {
  __add = chunk_add,
  __and = chunk_and,
  __call = chunk_call,
 })
 return c
end

function chunk_add(c1, c2)
 -- combining chunks preserves every rock instead of choosing only one
 local rocks = {}
 for r in all(c1.rocks) do add(rocks, r) end
 for r in all(c2.rocks) do add(rocks, r) end
 return chunk(
  terrain_add_nil(c1[1], c2[1]),
  terrain_add_nil(c1[2], c2[2]),
  unpack(rocks)
 )
end

function chunk_and(c1, c2)
 return chunk_add(c1, c2)
end

function chunk_call(c, p)
 local v = {}
 for i = 1, 2 do
  local t = c[i]
  if t ~= nil then
   local y = t(p)
   if y ~= nil then add(v, y) end
  end
 end
 sort(v)

 -- Keep one sample pair per rock even when that rock is absent at p.
 -- Stable slots let add_cave maintain separate identities for stacked rocks.
 v.rocks = {}
 for r in all(c.rocks) do
  add(v.rocks, {
   r[1] and r[1](p) or nil,
   r[2] and r[2](p) or nil,
  })
 end
 return v
end

function terrain_add_nil(t1, t2)
 if t1 == nil then return t2 end
 if t2 == nil then return t1 end
 return t1 + t2
end

function tunnel(d, h)
 return chunk(
  static(d) + noise(1),
  static(d + h) + noise(1)
 )
end

function taper_in(from_h, to_h)
 local exp = (from_h - to_h) / 2
 local roof = first_half(static(0))
  + second_half(cosinewave(-exp/2, 0.5) + static(exp/2))
 return chunk(roof, mirror(roof, from_h))
end

function taper_out(from_h, to_h)
 local exp = (to_h - from_h) / 2
 local roof = first_half(cosinewave(exp/2, 0.5) + static(-exp/2))
  + second_half(static(-exp))
 return chunk(roof, mirror(roof, from_h))
end

function zig(y)
 return chunk(
  linear(-y) % range(0, 0.5) + linear(y) % range(0.5, 1),
  linear(-y) % range(0, 0.5) + linear(y) % range(0.5, 1)
 )
end

function zag(y)
 return chunk(
  linear(y) % range(0, 0.5) + linear(-y) % range(0.5, 1),
  linear(y) % range(0, 0.5) + linear(-y) % range(0.5, 1)
 )
end

function zigzag(y)
 return chunk(
  linear(y) % range(0, 0.25)
  + linear(-y) % range(0.25, 0.5)
  + linear(y) % range(0.5, 0.75)
  + linear(-y) % range(0.75, 1),
  linear(y) % range(0, 0.25)
  + linear(-y) % range(0.25, 0.5)
  + linear(y) % range(0.5, 0.75)
  + linear(-y) % range(0.75, 1)
 )
end

function room(d)
 return chunk(
  static(d),
  static(d + 112)
 )
end

function corridor(d, h)
 return chunk(
  static(d),
  static(d + h)
 )
end

function resize1(y)
 return chunk(
  linear(y),
  linear(y)
 )
end

function resize(y1, y2)
 return chunk(
  linear(y1),
  linear(y2)
 )
end

function nbend(r1, r2)
 return chunk(
  nshape(r2, r1),
  nshape(r1, r2)
 )
end

function sbend(r1, r2)
 return chunk(
  sshape(r1, r2),
  sshape(r2, r1)
 )
end

function ubend(r1, r2)
 return chunk(
  ushape(r2, r1),
  ushape(r1, r2)
 )
end

function zbend(r1, r2)
 return chunk(
  zshape(r2, r1),
  zshape(r1, r2)
 )
end

function terrain(fn)
 local t = {fn}
 setmetatable(t, {
  __add = terrain_add,
  __call = terrain_call,
  __mod = terrain_mod,
  __mul = terrain_mul,
 })
 return t
end

function terrain_add(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   return (y1 or 0) + (y2 or 0)
  end
 )
end

function terrain_call(t, p)
 if p == nil then
  return nil
 else
  return t[1](p)
 end
end

function terrain_mod(t1, t2)
 return terrain(
  function(p)
   local y1 = t2(p)
   local y2 = t1(y1)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y2
  end
 )
end

function terrain_mul(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y1 * y2
  end
 )
end

function invert()
 return terrain(
  function(p)
   return -1
  end
 )
end

function mirror(t, center)
 return terrain(function(p)
  local y = t(p)
  if y == nil then return nil end
  return center - y
 end)
end

function linear(y)
 return terrain(
  function(p)
   return p * y
  end
 )
end

function noise(n)
 return terrain(
  function(p)
   if p == 1 then
    return 0
   else
    return flr(rnd(2^n)) - 2^n/2
   end
  end
 )
end

function pythagoras(r)
 return terrain(
  function(p)
   -- Keep the curve continuous. Quantizing r*p with flr() produced
   -- visible stair-steps that became harsh at higher cave speeds.
   return r - sqrt(r^2 - (r*p)^2)
  end
 )
end

function range(from, to)
 return terrain(
  function(p)
   if p <= from then
    return 0
   elseif p >= to then
    return 1
   else
    return (p-from)/(to-from)
   end
  end
 )
end

function reverse()
 return terrain(
  function(p)
   return 1 - p
  end
 )
end

function first_half(t)
 return terrain(function(p)
  if p >= 0.5 then return nil end
  return t(p * 2)
 end)
end

function second_half(t)
 return terrain(function(p)
  if p < 0.5 then return nil end
  return t((p - 0.5) * 2)
 end)
end

function fragment(x, y, r, d)
 return (
  static(y)
  + (linear(r*d) + sinewave(2, 1) + noise(1)) % range(0, 0.5)
  + (linear(r*-d) + sinewave(2, 1) + noise(1)) % range(0.5, 1)
 ) % trim() % range(x-(r*0.01), x+(r*0.01))
end

function nshape(r1, r2)
 return (
  sshape(r2, r1) % range(0, 0.5)
  + zshape(r1, r2) % range(0.5, 1)
 )
end

function sshape(r1, r2)
 return zshape(r1, r2) * static(-1)
end

function ushape(r1, r2)
 return (
  zshape(r1, r2) % range(0, 0.5)
  + sshape(r2, r1) % range(0.5, 1)
 )
end

function zshape(r1, r2)
 local p1 = r1 / (r1 + r2)
 return (
  static(r2) + pythagoras(r1) % range(0, p1)
  + pythagoras(r2) * invert() % reverse() % range(p1, 1)
 )
end

function sinechunk(m, f)
 return chunk(
  sinewave(m,f),
  sinewave(m,f)
 )
end

function roomchunk(pinch_gap, room_width)
 local expansion = (room_width - pinch_gap) / 2
 local roof = cosinewave(expansion/2, 1) + static(-expansion/2)
 return chunk(roof, mirror(roof, pinch_gap))
end

function rock_shape_circle()
 return terrain(function(p)
  return sqrt(1 - (2*p - 1)^2)
 end)
end

function rock_shape_linear()
 return terrain(function(p)
  return p
 end)
end

function rock(p_center, width, height, offset_y, shape)
 local half_width = width / 2
 local half_height = height / 2
 local p_start = p_center - half_width
 local p_end = p_center + half_width
 offset_y = offset_y or 0
 shape = shape or rock_shape_circle()

 return chunk(
  nil,
  nil,
  {
   terrain(function(p)
    if p >= p_start and p <= p_end then
     local rock_p = (p - p_start) / width
     local taper = shape(rock_p)
     return offset_y - half_height * taper
    end
    return nil
   end),
   terrain(function(p)
    if p >= p_start and p <= p_end then

     local rock_p = (p - p_start) / width
     local taper = shape(rock_p)
     return offset_y + half_height * taper
    end
    return nil
   end)
  }
 )
end


function biome_start()
 biome_id = "start"
 biome_next_chunk = function()
  if biome_chunk_count == 0 then
   -- return tunnel(0, 110)
   return chunk(
    static(0) + noise(3), --+ linear(200),
    static(0 + 96) + noise(3)--+ linear(250)
   )
  end
 end
end

function biome_boost()
 biome_id = "boost"
 biome_next_chunk = function()
  if biome_chunk_count == 0 then
   return tunnel(0, 110)
  end
 end
end

function biome_rooms()
 biome_id = "rooms"
 biome_next_chunk = function()
  if biome_chunk_count == 0 then
   return taper_in(110, 32)
  elseif biome_chunk_count == 1 then
   local rock_chunk = rock(0.5, 0.08, 20, -8 + rnd(16))
   return roomchunk(32, 120) + rock_chunk
  elseif biome_chunk_count == 2 then
   return taper_out(32, 110)
  end
 end
end

function biome_zigzag()
 biome_id = "zigzag"
 biome_next_chunk = function()
  local rock_chunk = rock(0.5, 0.1, 10, -20 + rnd(20))
  if biome_chunk_count == 0 then
   return taper_in(110, 96)
  elseif biome_chunk_count == 1 then
   return tunnel(0, 96) + ubend(32, 32) + rock_chunk
  elseif biome_chunk_count == 2 then
   return tunnel(0, 86) + zig(128) + rock_chunk
  elseif biome_chunk_count == 3 then
   return tunnel(0, 76) + zigzag(32) + rock_chunk
  elseif biome_chunk_count == 4 then
   return tunnel(0, 96) + zigzag(-32) + rock_chunk
  elseif biome_chunk_count == 5 then
   return taper_out(96, 110)
  end
 end
end

function biome_normal()
 biome_id = "normal"
 biome_next_chunk = function()
  if biome_chunk_count < 1 then
   local rock_chunk = rock(0.5, 0.1, 24, -12 + rnd(24))
   return tunnel(0, 110) + sinechunk(16, 0.5) + rock_chunk
  end
 end
end

function step_terrain(y)
 return first_half(static(0)) + second_half(static(y))
end

function width_change(delta)
 return chunk(
  delta * static(-0.5),
  delta * static(0.5)
 )
end

-- Noise that joins cleanly to adjacent chunks. Shared instances can move
-- roof and floor together; separate instances roughen each wall independently.
function chunk_noise(n)
 return terrain(function(p)
  if p == 0 or p == 1 then return 0 end
  return flr(rnd(2^n)) - 2^n/2
 end)
end

function shared_chunk_noise(n)
 local last_p = nil
 local last_y = 0
 return terrain(function(p)
  if p ~= last_p then
   last_p = p
   if p == 0 or p == 1 then
    last_y = 0
   else
    last_y = flr(rnd(2^n)) - 2^n/2
   end
  end
  return last_y
 end)
end

function angular_texture(n)
 local mode = flrrnd(4)
 if mode == 0 then
  local t = shared_chunk_noise(n)
  return chunk(t, t)
 elseif mode == 1 then
  return chunk(chunk_noise(n), chunk_noise(n))
 elseif mode == 2 then
  return chunk(chunk_noise(n), static(0))
 else
  return chunk(static(0), chunk_noise(n))
 end
end

function angular_feature(height)
 local mode = flrrnd(4)
 if mode == 0 then return chunk(nil, nil) end
 if mode < 3 then
  return rock(0.35 + rnd(0.3), 0.08 + rnd(0.05), 12 + rnd(10), -18 + rnd(36))
 end
 return rock(0.5, 0.1, 16, -12 + rnd(24))
end

function build_angular_chunk()
 -- Leave room for independent wall noise and width changes while keeping
 -- the final speed-1 corridor comfortably above the 72px invariant.
 local height = max(cave_height or 96, 112)
 local path_amount = choose({12,16,24,32})
 local path_roll = flrrnd(8)
 local path = static(0)
 local flat_step = false

 if path_roll == 2 or path_roll == 3 then
  path = linear(path_amount)
 elseif path_roll == 4 or path_roll == 5 then
  path = linear(-path_amount)
 elseif path_roll == 6 then
  path = step_terrain(path_amount)
  flat_step = true
 elseif path_roll == 7 then
  path = step_terrain(-path_amount)
  flat_step = true
 end

 local width = static(0)
 if not flat_step then
  local width_amount = choose({4,6,8})
  local width_roll = flrrnd(5)
  -- Bias back toward a useful passage width before applying random variation.
  if height < 80 then
   width = linear(width_amount)
  elseif height > 108 then
   width = linear(-width_amount)
  elseif width_roll == 1 then
   width = linear(-width_amount)
  elseif width_roll == 2 then
   width = linear(width_amount)
  elseif width_roll == 3 then
   width = linear(width_amount) % range(0,0.5)
     + linear(-width_amount) % range(0.5,1)
  elseif width_roll == 4 then
   width = linear(-width_amount) % range(0,0.5)
     + linear(width_amount) % range(0.5,1)
  end
 end

 local base = corridor(0, height) + chunk(path, path) + width_change(width)
 local texture = chunk(static(0), static(0))
 local feature = chunk(nil, nil)
 if not flat_step then
  texture = angular_texture(2 + flrrnd(4))
  feature = angular_feature(height)
 end
 -- A rock straddling an instantaneous step gets displaced with the cave
 -- center on each side, turning its two halves into an impassable barrier.
 -- Keep step recipes clean and let the wall transition be the obstacle.
 return base + texture + feature
end

-- Speed-1 chunks are procedural recipes rather than named layouts. Path,
-- width, texture, and features permute independently each time.
function next_biome_angular()
 biome_chunk_count = 0
 biome_id = "angular"
 local generated = build_angular_chunk()
 biome_next_chunk = function()
  if biome_chunk_count < 1 then return generated end
 end
end

function flowy_texture(min_noise, max_noise)
 min_noise = min_noise or 2
 max_noise = max_noise or 5
 local n = min_noise + flrrnd(max_noise - min_noise + 1)
 local mode = flrrnd(5)
 -- Shared noise dominates at speed 2, keeping the passage width calm.
 if mode < 3 then
  local t = shared_chunk_noise(n)
  return chunk(t, t)
 elseif mode == 3 then
  return chunk(chunk_noise(n), chunk_noise(n))
 else
  return choose({
   chunk(chunk_noise(n), static(0)),
   chunk(static(0), chunk_noise(n)),
  })
 end
end

function build_flowy_chunk()
 -- Speed 2 uses the same 72px minimum as speed 1, with extra recipe room
 -- so the safety clamp is only a fallback for unusual combinations.
 local height = max(cave_height or 104, 112)
 local motion = choose({
  resize1(0),
  resize1(12),
  resize1(-12),
  zig(16),
  zag(16),
  sinechunk(8, 0.5),
  nbend(20, 20),
  sbend(20, 20),
  ubend(20, 20),
  zbend(20, 20),
 })

 local width_amount = choose({2,4,6})
 local width_roll = flrrnd(5)
 local width = static(0)
 if height < 88 then
  width = linear(width_amount)
 elseif height > 112 then
  width = linear(-width_amount)
 elseif width_roll == 1 then
  width = linear(width_amount)
 elseif width_roll == 2 then
  width = linear(-width_amount)
 elseif width_roll == 3 then
  width = linear(width_amount) % range(0,0.5)
    + linear(-width_amount) % range(0.5,1)
 elseif width_roll == 4 then
  width = linear(-width_amount) % range(0,0.5)
    + linear(width_amount) % range(0.5,1)
 end

 local feature = chunk(nil, nil)
 if flrrnd(3) == 0 then
  feature = rock(0.35 + rnd(0.3), 0.08, 10 + rnd(8), -12 + rnd(24))
 end

 return corridor(0, height)
   + motion
   + width_change(width)
   + flowy_texture()
   + feature
end

-- Speed 2 uses procedural recipes too, biased toward curves but retaining
-- occasional ramps and small zigs from speed 1.
function next_biome_flowy()
 biome_chunk_count = 0
 biome_id = "flowy"
 local generated = build_flowy_chunk()
 biome_next_chunk = function()
  if biome_chunk_count < 1 then return generated end
 end
end

-- Speed 3 keeps the Pythagorean character but uses shallow elevation
-- changes; at three columns/frame larger bends were often unsurvivable.
function next_biome_very_flowy()
 biome_chunk_count = 0
 biome_id = "very flowy"
 biome_next_chunk = function()
  if biome_chunk_count < 1 then
   local shape = choose({
    nbend(12, 12),
    sbend(12, 12),
    ubend(12, 12),
    zbend(12, 12),
   })
   -- Occasionally carry the whole corridor gently uphill or downhill for
   -- the length of the chunk, without changing its usable height.
   local drift = choose({static(0), linear(6), linear(-6)})
   return corridor(0, 64)
     + drift
     + shape
     + sinechunk(2, 0.5)
     + flowy_texture(1, 3)
  end
 end
end

-- Speed 4 trades roughness and sharp elevation changes for broad curves.
-- Its slightly wider corridor preserves reaction room at four columns/frame.
function next_biome_ultra_flowy()
 biome_chunk_count = 0
 biome_id = "ultra flowy"
 biome_next_chunk = function()
  if biome_chunk_count < 1 then
   local shape = choose({
    nbend(8, 8),
    sbend(8, 8),
    ubend(8, 8),
    zbend(8, 8),
   })
   -- Keep the ultra-flowy mode calm, but give it occasional long climbs
   -- and descents so it does not feel visually frozen.
   local drift = choose({static(0), linear(32), linear(-32)})
   return corridor(0, 72)
     + drift
     + shape
     + sinechunk(4, 0.5)
     + flowy_texture(1, 2)
  end
 end
end

function set_cave_vx(v)
 if cave_vx == v then return end
 local previous_vx = cave_vx
 cave_vx = v
 if cave_vx > previous_vx then speed_up_frame = clock_frame end
 if cave_vx >= 4 then
  next_biome = next_biome_ultra_flowy
  coin_cooldown_limit = coin_cooldown_very_fast
  fuel_drain_interval = fuel_drain_fast
 elseif cave_vx == 3 then
  next_biome = next_biome_very_flowy
  coin_cooldown_limit = coin_cooldown_very_fast
  fuel_drain_interval = fuel_drain_fast
 elseif cave_vx == 2 then
  next_biome = next_biome_flowy
  coin_cooldown_limit = coin_cooldown_fast
  fuel_drain_interval = fuel_drain_fast
 else
  next_biome = next_biome_angular
  coin_cooldown_limit = coin_cooldown_slow
  fuel_drain_interval = fuel_drain_slow
 end
 -- Begin a chunk from the newly selected policy on the next cave update.
 biome_policy_dirty = true
end

function sinewave(magnitude, frequency)
 return terrain(
  function(p)
   return sin(p * frequency) * magnitude
  end
 )
end

function cosinewave(magnitude, frequency)
 return terrain(
  function(p)
   return cos(p * frequency) * magnitude
  end
 )
end

function static(y)
 return terrain(
  function(p)
   return y
  end
 )
end

function trim()
 return terrain(
  function(p)
   if p > 0 and p < 1 then
    return p
   end
  end
 )
end

function sort(a)
 for i=1,#a do
  local j = i
  while j > 1 and a[j-1] > a[j] do
   a[j],a[j-1] = a[j-1],a[j]
   j = j - 1
  end
 end
end

function choose(table)
 return table[flrrnd(#table) + 1]
end

function draw_bar(l, p, x, y)
 line(x+1, y+1, x+14, y+1, 5)
 line(x+1, y+1, x+14*p, y+1, 7)
 rect(x, y, x+15, y+2, 1)
 print(l, x+17, y-1, 7)
end

-- circular-buffer index for the span arrays
function cave_index(i)
 -- Screen positions such as the smoothly moving helicopter can be
 -- fractional; cave storage is indexed by integer pixel columns.
 i = flr(i)
 return ((cave_head + i - 2) % chunk_length) + 1
end

function cave_roof_y(i)
 return cave_roof_arr[cave_index(i)]
end

function cave_floor_y(i)
 return cave_floor_arr[cave_index(i)]
end

function cave_set_roof(i, v)
 cave_roof_arr[cave_index(i)] = v
end

function cave_set_floor(i, v)
 cave_floor_arr[cave_index(i)] = v
end

-- shared empty list so cave_spans() never allocates when a column has no rock
empty_spans = {}

-- all spans in a column (walls are not stored here; only rocks carry spans)
function cave_spans(i)
 local l = cave_spans_arr[cave_index(i)]
 if l == nil then return empty_spans end
 return l
end

function add_span(i, rock, top, bottom)
 local idx = cave_index(i)
 local list = cave_spans_arr[idx]
 if list == nil then
  list = {}
  cave_spans_arr[idx] = list
 end
 add(list, {rock = rock, top = top, bottom = bottom})
 -- keep sorted by top
 for k = #list, 2, -1 do
  if list[k].top < list[k - 1].top then
   list[k], list[k - 1] = list[k - 1], list[k]
  end
 end
end

__gfx__
000000000000000000000000000000000000000000000000000000000000dddddddd000000000000000000000000000000000000000000000000000000000000
000000000500000003000000050000000000000005000000000000000ddd00000000ddd000000000000000000000000000000000000000000000000000000000
000000003330000003bb00033330000000000000333366000000000dd000000d0000000dd0000000000000000000000000000000000000000000000000000000
0300003335536600033b3b3b355300000000003335533330000000d00000000d000000000d000000000000000000000000000000000000000000000000000000
03bb3b3b3bb33330055333333bb3660003003b3b3bb3333000000d00000000000000000000d00000000000000000000000000000000000000000000000000000
033b333333333330000555333333333003bb3333333355500000d00000000ddddd000000000d0000000000000000000000000000000000000000000000000000
00555555333355500000005555333330033b555533550000000d00d000000d000dd00000d000d000000000000000000000000000000000000000000000000000
00000000555500000000000005555500055500005500000000d0000d00000d000dddd00d00000d00000000000000000000000000000000000000000000000000
60000000000000006005660000000000600000000000666500d0000000000ddddd00d00000000d00000000000000000000000000000000000000000000000000
0605666666666665060000666660000006000000666600000d00000000000ddddd00d000000000d0000000000000000000000000000000000000000000000000
0060000000000000006000000066666500656666000000000d00000000000ddddd0d0000000000d0000000000000000000000000000000000000000000000000
0600000000000000060556000000000006000000000066660d00000000000ddddddd0000000000d0000000000000000000000000000000000000000000000000
060556666666666606000066666000000600000066660000d00dd00880888088dd888080800dd00d000000000000000000000000000000000000000000000000
060000000000000006000000006666660605566600000000d000000800888080800800808000000d000000000000000000000000000000000000000000000000
006000000000000000656600000000000060000000006665d000000880808088800800088000000d000000000000000000000000000000000000000000000000
060566666666666506000066666000000600000066660000d000000800808080000800008000000d000000000000000000000000000000000000000000000000
600000000000000060000000006666656005666600000000d000000880808080000800088000000d000000000000000000000000000000000000000000000000
00000000000000000006660000000000000000000000665500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666556660006666600000666000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000666655000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006005660000000000600000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000060000000666665006566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000605560000000000060000000000666600000000000000000000000000000000000000000000000000000000000000000000000000000000
06055666666666660600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000600000000666666060556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000000000000065660000000000006000000000666500000000000000000000000000000000000000000000000000000000000000000000000000000000
06056666666666650600006666600000060000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000000000006000000000666665600566660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006660000000000000000000000665500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666556660006666600000666000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000666655000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05055000005055000005055000005050000005000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999900009999000099990000999905009999050099990000999900009999000099990000999900009999000099990000999900009999000099990000999900
09aaaa9009aaaa9009aaaa9009aaaa9009aaaa9509aaaa9509aaaa9009aaaa9509aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
09a99a9009a99a9009a99a9009a99a9009a99a9009a99a9509a99a9509a99a9009a99a9509a99a9009a99a9009a99a9009a99a9009a99a9009a99a9009a99a90
09a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa9509a9aa9509a9aa9009a9aa9509a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009a9aa90
09aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9509aaaa9509aaaa9009aaaa9509aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
00999900009999000099990000999900009999000099990000999900009999000099990500999905009999000099990500999900009999000099990050999900
00000000000000000000000000000000000000000000000000000000000000000000000000000050000005500000550000055050005505000550500005050000
00000000000000000000000000000000000000000500000005500000005500000000000000000000000000000000000000000000000000000000000000000000
00999900009999000099990000999900509999005099990000999900509999000099990000999900009999000099990000999900009999000099990000999900
09aaaa9009aaaa9009aaaa9059aaaa9059aaaa9009aaaa9059aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
09a99a9009a99a9059a99a9059a99a9009a99a9059a99a9009a99a9009a99a9009a99a9009a99a9009aa9a9009a9aa9009a99a9009a09a9009a00a9009a00a90
09a9aa9059a9aa9059a9aa9009a9aa9059a9aa9009a9aa9009a9aa9009a9aa9009a9aa9009aa9a9009a99a9009a99a9009a0aa9009a0aa9009a0aa9009a00a90
59aaaa9059aaaa9009aaaa9059aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa9009aaaa90
50999900009999005099990000999900009999000099990000999900009999000099990000999900009999000099990000999900009999000099990000999900
00500000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa0000aaaa00000aa000000aa0000000a00000000a000000000000000000000000000000000000000000000000000000000000000000
00999900009999000a9999a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090aa09009000090a900009aa000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09a00a9009000090a900009aa000000aa000000aa000000aa0000000000000000000000000000000000000000000000000000000000000000000000000000000
09a00a9009000090a900009aa000000aa000000aa000000a0000000a000000000000000000000000000000000000000000000000000000000000000000000000
090aa09009000090a900009aa000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999900009999000a9999a00a0000a00a0000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa0000aaaa00000aa000000aa000000a0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000077077777777077777777077777777077777777077077000777077777777000000000000000000000000000000000000000000000000000000000000000
77700077077777777077777777077777777077777777077077007770077777777000000000000000000000000000000000000000000000000000000000000000
77770077077000077077000000000000000077000077077077077700000000000000000000000000000000000000000000000000000000000000000000000000
77777077077000077077777777077777777077000077077077777000077777777000000000000000000000000000000000000000000000000000000000000000
77077777077000077077777777077777777077000777077077770000077777777000000000000000000000000000000000000000000000000000000000000000
77007777077000077000000077000000000077007770077077700000000000000000000000000000000000000000000000000000000000000000000000000000
77000777077777777077777777077777777077077700077077000000077777777000000000000000000000000000000000000000000000000000000000000000
77000077077777777077777777077777777077777000077070000000077777777000000000000000000000000000000000000000000000000000000000000000
00000007000000000000000000000000000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000007000000000000000070000000000000000700000000000000007000000000000000070000000000000000070000
0000000088800000000700000990000000000a0000a0000000000bb00000000000000ccc0000000000000dddd000000000000eeeee0000000000004444400000
007000000008070000009000000900000000a700000a00000000b070000b00000000c007000000000000d0007000000000000000070000000000000000700000
00080000000080000009700000079000000a00000000a000000b00000000b000000c00000000c000000000000000000000000000000000000000000000000000
0080700000070000009000000000097000a0000000000a0000b0000000000b000000000000000c000000000000000d0000000000000000007000000000000000
080000000000000009000000000000000a000000000007a700000000000000b000000000000000c000000000000000d000000000000000e00470000000000000
08000000000000000900000000000000000000000000000000000000000007b700000000000000c000000000000000d07e700000000000e00400000000000040
080000000000000000000000000000000000000000000000000000000000000000000000000007c77d700000000000d00e000000000000e00400000000000040
00000000000000800000000000000000000000000000000000000000000000007c700000000000c00d000000000007d70e000000000000e00400000000000040
0000000000000080000000000000009000000000000000007b700000000000000c000000000000000d000000000000000e000000000007e70400000000000040
000000000000008000000000000000907a700000000000a00b000000000000000c000000000000000d000000000000000e000000000000000000000000000740
0000700000070800079000000000090000a0000000000a0000b0000000000b0000c000000000000000d000000000000000000000000000000000000000000007
00080000000080000009700000079000000a00000000a000000b00000000b000000c00000000c000000000000000000000000000000000000000000000000000
007080000000070000009000000900000000a000007a00000000b000070b000000000000700c000000000007000d000000000070000000000000070000000000
0000088800000000000009900000700000000a0000a00000000000000bb0000000000000ccc000000000000dddd00000000000eeeee000000000044444000000
00000000000000000000000000000000000000000070000000000000070000000000000070000000000000070000000000000070000000000000700000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010800000173401732017320173201732017350173401732017320173201732017350173401732017320173502100021000210002100001000010002100021000510005100051000510002100021000210002100
010700200c0331c5001c5001c50000000007010070100133000000000000000001030000000123000000063500000000000000000000000000000000000001330000000000000000012300000007000070000000
010700000e7340e735007000070000700007001a7341a73517734177350070000700127341273500700007000e7340e735007000070000700007000b7340b7351773417735000000000012734127350000000700
010700000e7340e735000000000000000000000e7340e73506734067350000000000127341273500000000000e7340e735000000000000000000000b7340b7350673406735000000000012734127351a70017700
010700001e7241e725000000000000000000001a7241a72517724177250000000000127241272500000000000e7240e725000000000000000000001a7241a7251772417725000000000012724127250b70017700
010700000e7340e735000000000000000000000b7340b73517734177350000000000127341273500000000000e7340e735000000000000000000000b7340b7350673406735000000000012734127350000000000
0107000015734157350000000000000000000021734217351e7341e73500000000001a7341a735000000000015734157350000000000000000000012734127351e7341e73500000000001a7341a735127000e700
0107000017734177350070000700007000070412734127350e7340e73500700007001a7341a735007000070017734177350070000700007000070012734127350e7340e73500700007001a7341a7352570000700
010700001973419735000000000000000000002573425735217342173500000000001e7341e73500000000001973419735000000000000000000001573415735217342173500000000001e7341e7351570014700
010700001a7341a73500000000000000000000157341573514734147350000000000207342073500000000001d7341d735000000000000000000001973419735147341473500000000001a7341a7350000000000
010700200102401022010220102201022010250102401022010220102201022010250102401022010220102501024010250102401025010000100001000010000400004000040000400004000040000400004000
01200000097500e750097500e75011750117530e7500e75009753117500e75011750157501575311750117500975315750117501575018750187530c7500c75009753117500c7531175015750157501575315100
010e000001023010270102401025010230102501023010211a7001a700157001a7001d7001d7001a7001a700010230102701024010250102301025010250102118700217001d7002170024700247002170021700
010e00000e0230e0270e0240e0250e0230e0250e0230e0211a7351a732157311a7311d7331d7321a7301a7340c0230c0270c0240c0250c0230c0250c02118735217321d731217312473324732217302173400000
010e00000402304027040240402504023040250402304021107351873215731187311c7331c73210730107340902309027090240902509023090250902309021157351d732187311d73121733217312173021734
010e00100102301027010240102501023010250102301021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00080102301027010240102501023010250102301021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0107000010043000000000000000000002000020400000000080422b0420300000000000020000204000000000010043000000000000000100430000000000000080422b0420300000000080420b042030000000
0107000010043000000000000000000002000020400000000080422b0420300000000000020000204000000000010043000000000000000100430000000000000080422b0420b0420804208042080420c0420804
010e0000100332460000000246000c6350c603186000c603100330060010033006000c635006050c63500600100332460000000246000c63524600186000c603100330060010033006000c6320c6330c6000c600
010e000002023020270202402025020230202502023020211a7321a732157311a7311d7331d7321a7301a734000230002700024000250002300025000250002418732217321d7312173124733247322173021734
010e00000402304027040240402504023040250402304021107321873215731187311c7351c73210730107340902309057090540905509053090550905309051157561d732187311d73121753217512175021734
010e00000254302547025440254502543025450254302541005430054700544005450054300545005430054104543045470454404545045430454504543045410954309547095440954509543095450954309541
010e00000000000000000000000000000000000000000000025430254702544025450254302545025430254100000000000000000000000000000000000000000054300547005440054500543005450054300541
010e00000000000000000000000000000000000000000000045430454704544045450454304545045430454100000000000000000000000000000000000000000954309547095440954509543095450954309541
010e00000000000000000000000000000000000000000000045430454704544045450454304545045430454100000000000000000000000000000000000000000080114b0114d0114d0114d0114d0114d0114d01
010e0000095530955709554095550b5530b5550b5530b5510c5530c5570c5540c5550e5530e5550e5530e55110555115551055511555105551155510555115551055511555105551155510555115551055511555
010e00001055511555105551155510555115551055511555105551155510555115551055511555105551155510550105511055110551105511055110551105511055110551105511055110500105001050010500
010e00000205302057020540205502053020550205302051007561a752157511a7511d7531d7521a7501a754000530005700054000550005300055000550005118756217521d7512175124753247522175021754
010e00000405304057040540405504053040550405304051107561875215751187511c7531c75210750107540905309057090540905509053090550905309051157561d752187511d75121753217512175021750
010e000002053020570205402055020530205502053020511b7541b751187540f7542075420751207512075100751000570005400055000530005500055000511b7541b754187511b75421754217542175121751
010e000004053040570405404055040530405504053040511b7541b751187541b7542175421751217512175109053090570905409055090530905509053090511a7541a7511f7542375426754267512675126751
010e00000205302057020540205502053020550205302051107001a700157001a7001d7001d7001a7001a700000530005700054000550005300055000550005118700217001d7002170024700247002170021700
010e000004053040570405404055040530405504053040511b7001b700187001b7002170021700217002170009053090570905409055090530905509053090511a7001a7001f7002370026700267002670026700
010300040b7440b7440b7440b7440b644011000110001100012000170001700017000170001700017000170000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000005100051000510005100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c5100c510301003010030100301003050030500305003050030500305003050030500
010600041d7430e7430b7430b7430b600011000110001100012000170001700017000170001700017000170000000000000000000000000000000000000000000000000000000000000000000000000000000000
016c00000061300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
012000000062300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000f1e7132a7151a715237151e7131a71526715237151e7131a71517713237151e7131a71517713004001e7002a7001a70000700007000070000700007000070000700007000070000700007000070000700
011000001a7141a7121a7121a7150070026714267122671523714237122371223715007001e7141e7101e7151a7141a7121a7121a7121a7121a7121a715007001a7141a7121a7121a71500700000000000000000
0110000017714177121771217715007002371423712237151e7141e7121e7121e715007001a7141a7121a71517714177121771217712177121771217715007001771417712177121771500700003000030000300
010e000002053020570205402055020530205502053020510e0230e0270e0240e0250e0230e0250e0230e02100053000570005400055000530005500055000510c0230c0270c0240c0250c0230c0250c0210c735
010e00000405304057040540405504053040550405304051100231002710024100251002310025100231002109053090570905409055090530905509053090511502315027150241502515023150251502315021
010e0000025430254702544025450e5310e5350e5330e531005430054700544005450c5310c5350c5330c53104543045470454404545105311053510533105310954309547095440954515731157351573315731
010e0000095530955709554095550b5530b5550b5530b5510c5530c5570c5540c5550e5530e5550e5530e55110555115551055511555105551155510555115551055511555105551155510555115551055511555
__music__
00 4041024f
00 4041034f
00 4041044f
00 4041054f
00 40510611
00 40120744
00 4c110850
00 4012094f
01 17134244
00 18134444
00 17134244
00 18134444
00 17134244
00 18134444
00 17134244
00 18134444
00 16134344
00 16134344
00 16134344
00 1a134344
00 1b134344
00 1c134344
00 1d134344
00 1c134344
00 1d134344
00 1e134344
00 1f134344
00 1e134344
00 1f134344
00 20134344
00 21134344
00 02132044
00 03132144
00 04132044
00 05132144
00 06132044
00 07132144
00 08132044
00 09132144
00 2a134344
00 2b134344
00 2a134344
00 2b134344
00 2c134344
00 2c134344
00 1a134344
00 1b134344
00 1c134344
00 1d134344
00 1e134344
00 1f134344
00 20134344
02 21134344
00 62534344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 28424344
00 29424344
