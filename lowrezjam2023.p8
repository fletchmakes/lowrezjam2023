pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- canyon crisis
-- jammigans, mothense and fletch
-- made for #lowrezjam 2023

-- g_ for globals
-- k_ for keyboard keys
-- e_ for enumerated values
-- c_ for colors

-- globals
local g_current_state = nil
local g_debug = {false, false, false} -- 1 is CPU usage, 2 is player movement, 3 is length of particle
local g_muted = false
local g_music_playing = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_up = 2
local k_down = 3
local k_confirm = 4
local c_transparent = 9

-- constants
local g_game_states = {e_splash=0, e_menu=1, e_loading=2, e_playing=3, e_gameover=4}
local g_world_tilewidth = 12

-- tracked values
local g_particles = {}
local g_point_particles = {}
local g_tick = false
local g_ticklen = 8
local g_frame = 0
local g_shake_frame = 0
local g_shake = { x=0, y=0 }

-->8
-- lifecycle
function _init()
 -- enable alt palette in editor
 poke(0x5f2e, 1)

 -- 64x64 mode!
 poke(0x5f2c, 3)

 -- set transparencies
 palt(0, false)
 palt(c_transparent, true)

 -- alter palette
 pal({[0]=0,131,2,3,4,130,134,7,8,137,10,11,138,139,14,143},1)

 g_current_state = g_game_states.e_splash
end

local s = 8
local tx = 0
function _update60()
 g_frame += 1
 if (g_frame % g_ticklen == 0) then
  g_tick = true
 else
  g_tick = false
 end

 if (g_current_state == g_game_states.e_splash) then
  update_splashscreen()
 elseif (g_current_state == g_game_states.e_menu) then
  update_menu()
 elseif (g_current_state == g_game_states.e_loading) then
  init_playing()
 elseif (g_current_state == g_game_states.e_playing) then
  update_playing()
 elseif (g_current_state == g_game_states.e_gameover) then
  update_gameover()
 end

 update_particles()
end

function _draw()
 cls(c_transparent)

 if (g_current_state == g_game_states.e_splash) then
  draw_splashscreen()
 elseif (g_current_state == g_game_states.e_menu) then
  draw_menu()
 elseif (g_current_state == g_game_states.e_playing) then
  draw_playing()
 elseif (g_current_state == g_game_states.e_gameover) then
  draw_gameover()
 end

 if (g_debug[1]) then
  camera()
  rectfill(0, 0, 22, 4, 0)
  print(stat(1), 0, 0, 7)
 end

 if (g_debug[3]) then
  camera()
  rectfill(0, 0, 22, 4, 0)
  print(#g_particles, 0, 0, 7)
 end

 update_point_particles()
end

-->8
-- splashscreen
local g_splash = {
 cur_frame = 0,
 last_frame = 120,
}

function update_splashscreen()
 if g_splash.cur_frame == 0 then
  play_sfx(2)
 end

 g_splash.cur_frame += 1

 if (g_music_playing == false and g_splash.cur_frame >= 113) then
  music(0, 300, 0b1001)
  g_music_playing = true
 end
 
 if (g_splash.cur_frame > g_splash.last_frame) then
  g_current_state = g_game_states.e_menu
  g_splash.cur_frame = 0
 end
end

function draw_splashscreen()
 draw_menu()

 if (g_splash.cur_frame < 110) then
  rectfill(0, 0, 63, 63, 0)
  print("a game by", 14, 20, 7)
  print("jammigans", 14, 26, 7)
  print("mothense",  16, 32, 7)
  print("& fletch",  16, 38, 7)
 else
  if (g_splash.cur_frame >= 110 and g_splash.cur_frame < 113) then
   fillp(0b1111000000000000.1)
  elseif (g_splash.cur_frame >= 113 and g_splash.cur_frame < 116) then
   fillp(0b1111111100000000.1)
  elseif (g_splash.cur_frame >= 116 and g_splash.cur_frame <= 120) then
   fillp(0b1111111111110000.1)
  end
  rectfill(0, 0, 63, 63, 0)
  fillp()
 end
end

-->8
-- menu
local g_title = {
 x = 6,
 y = 15,
}

local g_menu = {
 options = { "play", "toggle sfx", "quit" },
 xtarget = { 24, -12, -48 }, -- calculated x values to center each option
 actions = {
  function() g_current_state = g_game_states.e_loading end, -- play
  function() g_muted = not g_muted end, -- mute sfx
  function() run() end -- quit
 },
 selected = 1,
 x = 24,
 y = 35
}

function update_menu()
 if (btnp(k_left) and g_menu.selected > 1) then
  g_menu.selected -= 1
  play_sfx(0)
 end

 if (btnp(k_right) and g_menu.selected < #g_menu.options) then
  g_menu.selected += 1
  play_sfx(0)
 end

 if (btnp(k_confirm)) then
  g_menu.actions[g_menu.selected]() -- run the function
  play_sfx(1)
 end

 g_menu.x = lerp(g_menu.x, g_menu.xtarget[g_menu.selected], 0.25)
end

function draw_menu()
 -- draw the background
 map(120, 4, 0, 0, 8, 8)
 map(0, 8, 0, 0, 8, 8)

 -- draw the player
 sspr(72, 0, 21, 18, 20, 45)

 -- draw the menu options
 rectfill(0, g_menu.y-1, 64, g_menu.y+5, 5)

 -- draw the title sprite
 sspr(0, 104, 58, 24, 3, 5)

 -- print the menu options
 print(g_menu.options[1], g_menu.x, g_menu.y, g_menu.selected == 1 and 7 or 6)
 print(g_menu.options[2], g_menu.x + 8 + (#g_menu.options[1]*4), g_menu.y, g_menu.selected == 2 and 7 or 6)
 print(g_menu.options[3], g_menu.x + 16 + (#g_menu.options[1]*4) + (#g_menu.options[2]*4), g_menu.y, g_menu.selected == 3 and 7 or 6)

 -- show mute state
 rectfill(54, 54, 64, 64, 5)
 local color = 7
 if (g_muted) then
  color = 2
  line(56, 57, 61, 61, color)
 end
 print(chr(141), 56, 57, color)
end

-->8
-- playing
local g_camera = {
 x = 0,
 y = -26,
 xtarget = 0,
 ytarget = 0,
 offset = -6
}

local g_player = nil
local g_mapregions = {}
local g_objects = {}
local g_timer = 180
local g_points = 0
local g_ammo = 6
local g_ammo_spawned = false
local g_aliens = 0
local g_alien_spawn_cd = 0
local g_aliens_killed = 0
local g_cows_saved = 0
local g_time_alive = 0

local g_ammo_flash = nil
local g_timer_flash = nil
local g_gameover_timer = 90

function init_playing()
 -- camera
 g_camera = {
  x = 0,
  y = -26,
  xtarget = 0,
  ytarget = 0,
  offset = -6
 }

 -- map regions
 g_mapregions = {}
 add(g_mapregions, -26)
 add(g_mapregions, -154)

 -- populate new region
 g_objects = {}
 g_player = new_player(6, 0)
 populate_region(g_mapregions[1])

 -- timer & points
 g_timer = 180
 g_points = 0
 g_aliens = 0
 g_alien_spawn_cd = 0
 g_aliens_killed = 0
 g_cows_saved = 0
 g_time_alive = 0
 g_frame = 1
 g_ammo = 6
 g_ammo_spawned = false
 g_ammo_flash = nil
 g_timer_flash = nil
 g_gameover_timer = 90

 g_current_state = g_game_states.e_playing
end

function update_playing()
 -- update timer
 if (g_frame % 60 == 0) then
  g_timer -= 1
  g_time_alive += 1
 end

 if (g_timer <= 0) then
  g_objects = {}
  g_particles = {}
  g_point_particles = {}
  g_current_state = g_game_states.e_gameover
 end

 if (g_alien_spawn_cd > 0) then
  g_alien_spawn_cd -= 1
 end

 -- objects first (makes sure we capture latest player movement)
 update_objects()

 -- attempt to spawn in a new alien
 spawn_alien()

 -- attempt to spawn in more ammo if needed
 if (g_ammo <= 0) then
  spawn_ammo()
 end

 -- camera movement
 if (g_player.x-g_camera.xtarget < 16) then
  g_camera.xtarget -= 16
 end

 if (g_player.x-g_camera.xtarget > 32) then
  g_camera.xtarget += 16
 end

 g_camera.ytarget = g_player.y - (48 + g_camera.offset)

 -- lerp towards our target
 g_camera.x = lerp(g_camera.x, g_camera.xtarget, 0.3)
 g_camera.y = lerp(g_camera.y, g_camera.ytarget, 0.3)

 -- adjust map regions
 if (g_camera.y + 64 < g_mapregions[1]) then
  g_mapregions[1] -= 256
  populate_region(g_mapregions[1])
 end

 -- pls don't ask me why populate_region goes in g_mapregions[1] and NOT g_mapregions[2] because idk and idc
 if (g_camera.y + 64 < g_mapregions[2]) then
  g_mapregions[2] -= 256
 end

 -- teleport prevents us from ever reaching g_camera.y == INT_MIN (allows for truly infinite gameplay)
 if (g_player.tiley > 32) then
  teleport()
 end

 -- update screenshake
 shake_screen()
end

function draw_playing()
 camera(g_camera.x+g_shake.x, g_camera.y+g_shake.y)
 
 -- draw the cracks in the ground pattern - last column in map data
 map(120, 0,  0,   g_mapregions[1], 8, 16)
 map(120, 0,  64,  g_mapregions[1], 8, 16)
 map(120, 0,  128, g_mapregions[1], 8, 16)
 map(120, 16, 0,   g_mapregions[2], 8, 16)
 map(120, 16, 64,  g_mapregions[2], 8, 16)
 map(120, 16, 128, g_mapregions[2], 8, 16)

 -- draw the canyon walls (left side)
 spr(128, -16, g_mapregions[1]-64, 2, 4)
 spr(130, -16, g_mapregions[1]-32, 2, 4)
 spr(128, -16, g_mapregions[1], 2, 4)
 spr(130, -16, g_mapregions[1]+32, 2, 4)
 spr(128, -16, g_mapregions[1]+64, 2, 4)
 spr(130, -16, g_mapregions[1]+96, 2, 4)
 spr(128, -16, g_mapregions[1]+128, 2, 4)
 spr(130, -16, g_mapregions[1]+160, 2, 4)
 spr(128, -16, g_mapregions[1]+192, 2, 4)
 spr(130, -16, g_mapregions[1]+224, 2, 4)

 -- draw the canyon walls (right side)
 spr(128, 192, g_mapregions[1]-64, 2, 4, true)
 spr(130, 192, g_mapregions[1]-32, 2, 4, true)
 spr(128, 192, g_mapregions[1], 2, 4, true)
 spr(130, 192, g_mapregions[1]+32, 2, 4, true)
 spr(128, 192, g_mapregions[1]+64, 2, 4, true)
 spr(130, 192, g_mapregions[1]+96, 2, 4, true)
 spr(128, 192, g_mapregions[1]+128, 2, 4, true)
 spr(130, 192, g_mapregions[1]+160, 2, 4, true)
 spr(128, 192, g_mapregions[1]+192, 2, 4, true)
 spr(130, 192, g_mapregions[1]+224, 2, 4, true)

 draw_objects()
 draw_particles()

 if (g_debug[2]) then
  camera()
  print(g_camera.y, 0, 0, 7)
 end

 -- timer ui
 camera()

 local timer_pct = flr((g_timer / 180) * 59)
 local color = 7
 if (timer_pct < 10) then
  color = 8
 end

 if (g_timer_flash ~= nil) then
  if (costatus(g_timer_flash) ~= 'dead') then
   coresume(g_timer_flash)
  else
   g_timer_flash = nil
   rectfill(1, 1, 3, 62, 5)
  end
 else
  rectfill(1, 1, 3, 62, 5)
 end
 line(2, 2, 2, 61, 2)
 line(2, 61-timer_pct, 2, 61, color)

 -- points ui
 local point_str = tostr(g_points, 0x2)
 rectfill(62-(#point_str*4), 1, 62, 7, 5)
 print(point_str, 63-(#point_str*4), 2, 10)

 -- ammo ui
 if (g_ammo_flash ~= nil) then
  if (costatus(g_ammo_flash) ~= 'dead') then
   coresume(g_ammo_flash)
  else
   g_ammo_flash = nil
   rectfill(60, 50, 62, 62, 5)
  end
 else
  rectfill(60, 50, 62, 62, 5)
 end
 for i=0,5 do
  if (i > g_ammo-1) then
    pset(61, 61-(i*2), 2)
  else
    pset(61, 61-(i*2), 10)
  end
 end
end

-->8
-- game over
function update_gameover()
 if (btnp(k_confirm) and g_gameover_timer <= 0) then
  g_current_state = g_game_states.e_loading
 end

 g_gameover_timer -= 1
end

function draw_gameover()
 camera()
 cls(5)
 print("game over!", 12, 6, 7)

 local points = tostr(g_points, 0x2)
 local cows = tostr(g_cows_saved)
 local time = tostr(g_time_alive)
 local aliens = tostr(g_aliens_killed)

 -- icons
 print(chr(146), 13, 20, 7)
 print(chr(147), 13, 26, 7)
 print(chr(130), 13, 32, 7)
 print(chr(136), 13, 38, 7)

 -- stats
 print(points, 50-(#points*4), 20, 7)
 print(time, 50-(#time*4), 26, 7)
 print(cows, 50-(#cows*4), 32, 7)
 print(aliens, 50-(#aliens*4), 38, 7)

 if (g_gameover_timer <= 0) then
  print(chr(142).." to restart", 7, 54, 7)
 end
end

-->8
-- objects
function update_objects()
 for obj in all(g_objects) do
  -- if the object is off camera below the player, delete it
  if (obj.y > g_camera.y + 64) then
   if (obj.type == 'alien') then
    g_aliens -= 1
   end
   del(g_objects, obj)
  else
   obj.update(obj)
  end
 end
end

local draw_comparator = function(a, b)
 local result = a.y - b.y
 if (result == 0) then
  -- draw the wide objects on top of nearby objects
  result = a.sortprio - b.sortprio
 end

 if (result == 0) then
  -- draw right x before left x
  result = a.x - b.x
 end
 return result
end

function draw_objects()
 heapsort(g_objects, draw_comparator)
 for obj in all(g_objects) do
  if not (obj.y < g_camera.y - 16) then
   obj.draw(obj)
  end
 end
end

-- a region is a section of the map() that is 4 tiles wide and 8 tiles high (8 cels by 16 cels)
-- when the function receives the y-value, it's offset by 6 because *reasons* so we fix that before doing math
function populate_region(yvalue)
 local y = yvalue - 6

 -- repeat this process 3 times for each section of the screen (12 tiles wide)
 for col=0,2 do
  -- select a random column from the available map sections (currently: 2)
  local region = flr(rnd(15))

  -- iterate over each tile in the region and determine what to spawn
  for i=0,3 do
   for j=15,0,-1 do
    local celx = i*2 + (region*8)
    local cely = 32 - (j*2)
    local sprite = mget(celx, cely)

    local tiley = j - (y \ 16)

    if (sprite == 32) then
     new_cactus(col*4 + i+1, tiley)
    elseif (sprite == 34) then
     new_barrel(col*4 + i+1, tiley)
    elseif (rnd() < 0.2 ) then -- cow freq 0.03
     new_cow(col*4 + i+1, tiley)
    end
   end
  end
 end
end

function check_for_collision(x, y, w, h)
 for obj in all(g_objects) do
  if (obj.collide == true) then
   if (obj.x < x+w and obj.x+obj.w > x and obj.y < y+h and obj.y+obj.h > y) then
    return obj
   end
  end
 end

 return nil
end

-- return 0 for false, 1 for true, and 2 for cow
function is_occupied(tilex, tiley, ignore_obj)
 for obj in all(g_objects) do
  if (obj.tilex == tilex and obj.tiley == tiley and obj ~= ignore_obj) then
   -- cow
   if (obj.type == 'cow') then 
    return 2, obj 
   end

   -- alien
   if (obj.type == 'alien' and obj.spawn_timer > 59) then
    return 0, obj
   end

   if (obj.type == 'ammo' or obj.type == 'soda') then
    return 0, obj
   end

   return 1, obj
  end
 end

 return 0, nil
end

function spawn_bullet(tilex, tiley)
 local bullet = {}
 bullet.type = 'bullet'
 bullet.sortprio = 5

 bullet.x = -2 + (16 * (tilex-1))
 bullet.y = -4 - (16 * (tiley-1))
 bullet.w = 8
 bullet.h = 8

 bullet.update = function(self)
  self.y -= 5
  
  -- the random "+9" looks weird but we center the bullet's collision hitbox
  -- so that we only scan for collisions in our column, not for adjacent columns of tiles
  local col = check_for_collision(self.x+9, self.y, 8, 8)
  if (col ~= nil and self.y > g_camera.y) then -- don't destroy off-screen targets
   if (col.explode ~= nil and col.type ~= "cow") then
    col.explode(col)
   end

   -- delete the bullet
   del(g_objects, self)
  end

  if (self.y < g_camera.y - 16) then
   del(g_objects, self)
  end
 end

 bullet.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 bullet.draw = function(self)
  spr(2, self.x, self.y, 1, 2)
 end

 add(g_objects, bullet)
end

function new_player(tilex, tiley)
 local player = {}
 player.type = 'player'
 player.collide = false
 player.sortprio = 2

 player.tilex = tilex
 player.tiley = tiley
 player.x = 16 * (tilex-1)
 player.y = -(16 * (tiley-1))
 player.shooting = 0
 player.shootdur = 20
 player.cd = 5
 player.strafe_cd = 0
 -- a table to tell us if the player is moving in a particular direction
 -- indexed by the directional buttons, k_left, k_right, and k_up
 player.moving = {false, false, false}
 player.flip = false

 player.update = function(self)
  -- player movement
  -- check left, check right, check up
  local tileleft, objleft = is_occupied(self.tilex-1, self.tiley, self)
  local tileright, objright = is_occupied(self.tilex+1, self.tiley, self)
  local tileup, objup =  is_occupied(self.tilex, self.tiley+1, self)

  if(btnp(k_left) and self.tilex > 1 and tileleft != 1 and self.strafe_cd <= 0) then
   -- strafe left
   play_sfx(7)
   self.tilex -= 1
   self.moving[k_left] = true
   self.moving[k_right] = false
   self.strafe_cd = 10
   remove_time(3, false)
  end

  if (btnp(k_right) and self.tilex < g_world_tilewidth and tileright != 1 and self.strafe_cd <= 0) then
   -- strafe right
   play_sfx(7)
   self.tilex += 1
   self.moving[k_right] = true
   self.moving[k_left] = false
   self.strafe_cd = 10
   remove_time(3, false)
  end

  if (btnp(k_up) and tileup != 1 and self.strafe_cd <= 0) then
   -- move up
   play_sfx(4+flr(rnd(3)))
   self.tiley += 1
   self.moving[k_up] = true
   remove_time(3, false)
  end

  -- player shooting
  if (btn(k_confirm) and self.cd == 0 and g_ammo > 0) then
   play_sfx(3)
   spawn_bullet(self.tilex, self.tiley)
   self.shooting = self.shootdur
   self.cd = player.shootdur * 1.5
   g_ammo -= 1
  end
  
  if self.shooting > 0 then
   self.shooting -= 1
  end
  
  -- decrease shoot and strafe cool downs
  if self.cd > 0 then
    self.cd -= 1
  end
  if self.strafe_cd > 0 then
    self.strafe_cd -= 1
  end
   
  -- calculate player x and y
  local prev_x, prev_y = self.x, self.y
  self.x = lerp(self.x, 16 * (self.tilex-1), 0.3)
  self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

  -- determine if we are still moving in that direction
  if (prev_x == self.x) then
    self.moving[k_left] = false
    self.moving[k_right] = false
  end

  if (prev_y == self.y) then
    self.moving[k_up] = false
  end

  -- toggle the flip
  if (g_tick) then
    self.flip = not self.flip
  end
 end

 player.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 player.harm = function(self)
  remove_time(20, true)
  g_shake_frame = 6
 end

 player.draw = function(self)
  -- shadow
  shadow(self)
  
  -- shoot duration
  local dur = self.shootdur

  -- muzzle flash
  if (self.shooting >= 0.75 * dur) then
   spr(4, self.x-6, self.y-11, 2, 2)
  elseif (self.shooting >= 0.65 * dur) then
   sspr(48,0,9,16,self.x-3,self.y-12,9,16)
  elseif (self.shooting >= 0.5 * dur) then
   circfill(self.x+1, self.y, 3, 8)
  end

  -- player
  if (self.moving[k_up]) then
    -- run forward
    sspr(0,32,16,18,self.x,self.y-3,16,18,self.flip,false)
  elseif (self.moving[k_right]) then
    -- strafe right
    sspr(16,32,19,18,self.x-2,self.y,19,18)
  elseif (self.moving[k_left]) then
    -- strafe left
    sspr(16,32,19,18,self.x-2,self.y,19,18,true)
  elseif (self.shooting >= 0.5 * dur) then
    -- shoot frame 1
    sspr(93,0,15,18,self.x,self.y-2)
  elseif (self.shooting >= 0.1 * dur) then
    -- shoot frame 2
    sspr(108,0,15,18,self.x,self.y-2)
  else
    -- idle
    sspr(72,0,21,18,self.x-4,self.y-2)
  end
 end

 add(g_objects, player)
 return player
end

function new_barrel(tilex, tiley)
 -- sprite num: 34
 local barrel = {}
 barrel.type = 'barrel'
 barrel.collide = true
 barrel.sortprio = 0

 barrel.tilex = tilex
 barrel.tiley = tiley

 barrel.x = 16 * (tilex-1)
 barrel.y = -(16 * (tiley-1))
 barrel.w = 16
 barrel.h = 10

 barrel.update = function(self)
  -- do nothing
 end

 barrel.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 barrel.explode = function(self)
  explode(34, self.tilex, self.tiley, false)
  if (rnd() < 0.1) then
   new_ammo(self.tilex, self.tiley)
  elseif (rnd() < 0.4) then
   new_soda(self.tilex, self.tiley)
  end
  del(g_objects, self)
 end

 barrel.draw = function(self)
  shadow(self)
  spr(34, self.x, self.y, 2, 2)
 end

 add(g_objects, barrel)
end

function new_cactus(tilex, tiley)
 -- sprite num: 32
 local cactus = {}
 cactus.type = 'cactus'
 cactus.collide = true
 cactus.sortprio = 0

 cactus.tilex = tilex
 cactus.tiley = tiley

 -- make the y hitbox smaller to have bullets collide with "center" of cactus
 cactus.x = 16 * (tilex-1)
 cactus.y = -(16 * (tiley-1))
 cactus.w = 16
 cactus.h = 10

 cactus.update = function(self)
  -- we really just need this object for bullet collisions, nothing else
 end

 cactus.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 cactus.draw = function(self)
  shadow(self)
  spr(32, self.x, self.y, 2, 2)
 end

 add(g_objects, cactus)
end

function new_alien(tilex, tiley)
 -- sprite num: 38
 play_sfx(8)
 local alien = {}
 alien.type = 'alien'
 alien.collide = false
 alien.sortprio = 3

 alien.tilex = tilex
 alien.tiley = tiley

 alien.x = 16 * (tilex-1)
 alien.y = -(16 * (tiley-1))
 alien.w = 16
 alien.h = 16

-- a table to tell us if the player is moving in a particular direction
 -- indexed by the directional buttons, k_left, k_right, k_up, and k_down
 alien.state = "warning"
 alien.moving = {false, false, false, false}
 alien.decision_timer = 0
 alien.warning_timer = 60
 alien.spawn_dur = 72
 alien.spawn_timer = alien.spawn_dur
 alien.kamikaze = false

 alien.update = function(self)
  -- check if we're colliding with player - if so, damage them
  if (self.collide == true and self.tilex == g_player.tilex and self.tiley == g_player.tiley and self.state ~= "moving" and self.state ~= "attacking") then
   g_player.harm(g_player)
   self.kamikaze = true
   self.explode(self)
  end

  -- check if we're touching a cow - if so, kill it
  local tile, obj = is_occupied(self.tilex, self.tiley, self)
  if (self.collide == true and tile > 0 and obj.type == 'cow' and self.state ~= "moving" and self.state ~= "attacking") then
   self.kamikaze = true
   self.explode(self)
   obj.explode(obj)
  end

  -- if we're not warning, and not spawning, then do this
  if (self.state ~= "warning" and self.state ~= "spawning") then
   if (self.decision_timer <= 0) then
    -- 5% chance to take an action
    if (rnd() < 0.05) then
     self.decision_timer = 60

     -- if the player is nearby, kamikaze toward them
     if (self.tilex-1 == g_player.tilex and self.tiley == g_player.tiley) or
        (self.tilex+1 == g_player.tilex and self.tiley == g_player.tiley) or
        (self.tilex == g_player.tilex and self.tiley-1 == g_player.tiley) or
        (self.tilex == g_player.tilex and self.tiley+1 == g_player.tiley) then

         self.tilex = g_player.tilex
         self.tiley = g_player.tiley
         self.state = "attacking"
         return
     end

     -- determine adjacencies
     local tileleft, objleft = 0, nil
     local tileright, objright = 0, nil
     if (self.tilex > 1) then
      tileleft, objleft = is_occupied(self.tilex-1, self.tiley, self)
     end
     if (self.tilex < g_world_tilewidth) then
      tileright, objright = is_occupied(self.tilex+1, self.tiley, self)
     end

     local tileup, objup = is_occupied(self.tilex, self.tiley+1, self)
     local tiledown, objdown = is_occupied(self.tilex, self.tiley-1, self)

     -- if there is a cow adjacent, target that instead
     if (tileleft > 0 and objleft.type == 'cow') then
      self.state = "attacking"
      self.tilex -= 1
      return
     end

     if (tileright > 0 and objright.type == 'cow') then
      self.state = "attacking"
      self.tilex += 1
      return
     end

     if (tileup > 0 and objup.type == 'cow') then
      self.state = "attacking"
      self.tiley += 1
      return
     end

     if (tiledown > 0 and objdown.type == 'cow') then
      self.state = "attacking"
      self.tiley -= 1
      return
     end

     -- otherwise, move randomly
     local dir = flr(rnd(4)) -- 0 - 3 only integers
     if (dir == k_left and tileleft ~= nil) then
      if (tileleft == 0) then -- empty tile
       self.tilex -= 1
       self.moving[k_left] = true
       self.state = "moving"
      end

     elseif (dir == k_right and tileright ~= nil) then
      if (tileright == 0) then -- empty tile
       self.tilex += 1
       self.moving[k_right] = true
       self.state = "moving"
      end

     elseif (dir == k_up and tileup ~= nil) then
      if (tileup == 0) then -- empty tile
       self.tiley += 1
       self.moving[k_up] = true
       self.state = "moving"
      end

     elseif (dir == k_down and tiledown ~= nil) then
      if (tiledown == 0) then -- empty tile
       self.tiley -= 1
       self.moving[k_down] = true
       self.state = "moving"
      end
     end
    end
   end

   local prev_x, prev_y = self.x, self.y
   self.x = lerp(self.x, (16 * (self.tilex-1)), 0.3)
   self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

   if (prev_x == self.x and prev_y == self.y) then
    self.moving = {false, false, false, false}
    self.state = "idle"
   end

   self.decision_timer -= 1
  end

  -- STATE MACHINE LOGIC
  -- if we are spawning...
  if (self.state == "warning") then
   self.warning_timer -= 1
   if (self.warning_timer <= 0) then
    self.state = "spawning"
    play_sfx(9)
   end
  elseif (self.state == "spawning") then
   self.spawn_timer -= 1

   if (self.spawn_timer == 60) then
    g_shake_frame=4
    self.collide = true
   end

   if (self.spawn_timer <= 0) then
    self.state = "idle"
   end
  end
 end

 alien.explode = function(self)
  if (self.kamikaze == false) then
   g_aliens_killed += 1
  end
  explode(38, self.tilex, self.tiley, self.kamikaze)
  g_aliens -= 1
  if (rnd() < 0.7 and self.kamikaze == false) then
   new_soda(self.tilex, self.tiley)
  end
  del(g_objects, self)
 end

 alien.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end
 
 alien.draw = function(self)
  if (self.state == "warning") then
    if self.warning_timer < 90 then
     shadow(self)
    end
    -- warning indicator
    local frame
    local t = time() % 0.5
    if t < 0.25 then
     frame = 76
    else
     frame = 78
    end
    spr(frame, self.x, self.y+6, 2, 2)
    print("!", self.x+6, self.y+12, 8)
    print("!", self.x+7, self.y+12, 8)
  elseif (self.state == "spawning") then
   local spawn_progress = self.spawn_timer / self.spawn_dur
   shadow(self)
   -- spawn animation
   if spawn_progress <= 1 and spawn_progress > 0.962 then
    -- smear 1
    sspr(48, 16, 16, 16, self.x, self.y-40, 16, 40)
   end
   if spawn_progress < 0.962 and spawn_progress > 0.924 then
    -- smear 2
    sspr(48, 16, 16, 16, self.x, self.y-16, 16, 32)
   end
   if spawn_progress < 0.924 and spawn_progress > 0.848 then
    -- impact
    spr(70, self.x, self.y+2, 2, 2)
   end
   if spawn_progress < 0.848 and spawn_progress > 0.772 then
    -- transition
    spr(72, self.x, self.y, 2, 2)
   end
   if spawn_progress < 0.772 and spawn_progress > 0 then
    -- roar
    spr(74, self.x, self.y-1, 2, 2)
   end
  elseif (self.state == "idle") then
   shadow(self)
   spr(38, self.x, self.y, 2, 2)
  elseif (self.state == "moving") then
   shadow(self)
   spr(38, self.x, self.y, 2, 2)
  elseif (self.state == "attacking") then
   shadow(self)
   pal(11, 8)
   pal(3, 2)
   spr(38, self.x, self.y, 2, 2)
   pal(11, 11)
   pal(3, 3)
  end
 end

 add(g_objects, alien)
end

function spawn_alien()
 local min_tilex = g_player.tilex - 2
 local max_tilex = g_player.tilex + 2
 local min_tiley = g_player.tiley + 1

 if (min_tilex < 0) then min_tilex = 1 end
 if (max_tilex > g_world_tilewidth) then max_tilex = g_world_tilewidth+1 end

 -- 1) pick a random number with 5% chance to spawn alien
 -- 2) pick a random tile from the list of options
 -- 3) check if that tile is occupied
 -- 4) if not occupied, spawn in the alien
 if (g_aliens < 2 and rnd() < 0.1 and g_alien_spawn_cd == 0) then
  local tilex = flr(rnd(max_tilex - min_tilex)) + min_tilex
  local tiley = flr(rnd(3)) + min_tiley
  local tile, obj = is_occupied(tilex, tiley)

  if (tile == 0 and obj == nil) then
   new_alien(tilex, tiley)
   g_aliens += 1
   g_alien_spawn_cd = 30
  end
 end
end

function new_cow(tilex, tiley)
 -- sprite num: 109
 local cow = {}
 cow.type = 'cow'
 cow.collide = true
 cow.sortprio = 1
 
 cow.tilex = tilex
 cow.tiley = tiley

 cow.x = (16 * (tilex-1))
 cow.y = -(16 * (tiley-1))
 cow.w = 16
 cow.h = 16

 cow.decision_timer = 0
 cow.flip = false
 
 -- mooooovement
 cow.update = function(self)
  if (self.tilex == g_player.tilex and self.tiley == g_player.tiley) then
   self.rescue(self)
   return
  end

  if (self.decision_timer <= 0) then
   -- 20% chance to take an action
   if (rnd() < 0.05) then
    self.decision_timer = 60

    local dir = flr(rnd(4)) -- 0 - 3 only integers
    if (dir == k_left and self.tilex > 1) then
     local tile, _ = is_occupied(self.tilex-1, self.tiley, self)
     if (tile == 0) then -- empty tile
      self.tilex -= 1
      self.flip = false
     end

    elseif (dir == k_right and self.tilex < g_world_tilewidth) then
     local tile, _ = is_occupied(self.tilex+1, self.tiley, self)
     if (tile == 0) then -- empty tile
      self.tilex += 1
      self.flip = true
     end

    elseif (dir == k_up) then
     local tile, _ = is_occupied(self.tilex, self.tiley+1, self)
     if (tile == 0) then -- empty tile
      self.tiley += 1
     end

    elseif (dir == k_down) then
     local tile, _ = is_occupied(self.tilex, self.tiley-1, self)
     if (tile == 0) then -- empty tile
      self.tiley -= 1
     end
    end
   end
  end

  self.x = lerp(self.x, (16 * (self.tilex-1)), 0.3)
  self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

  self.decision_timer -= 1
 end

 cow.rescue = function(self)
  add_points(10, cow.tilex, cow.tiley)
  add_time(5, false)
  g_cows_saved += 1
  del(g_objects, self)
 end

 cow.explode = function(self)
  del(g_objects, self)
 end

 cow.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 cow.draw = function(self)
  shadow(self)
  spr(107, self.x, self.y, 2, 2)
 end
 
 add(g_objects, cow)
end

function new_ammo(tilex, tiley)
 local item = {}

 item.type = 'ammo'
 item.collide = false
 item.sortprio = -1

 item.tilex = tilex
 item.tiley = tiley

 item.x = (16 * (tilex-1))
 item.y = -(16 * (tiley-1))
 item.w = 16
 item.h = 16

 item.update = function(self)
  if (g_player.tilex == self.tilex and g_player.tiley == self.tiley) then
   refill_ammo()
   g_ammo_spawned = false
   del(g_objects, self)
  end
 end

 item.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 item.draw = function(self)
  sspr(59, 8, 10, 8, self.x + 3, self.y + 6 + (cos(g_frame/60)*2))
 end

 add(g_objects, item)
end

function spawn_ammo()
 local min_tilex = g_player.tilex - 2
 local max_tilex = g_player.tilex + 2
 local min_tiley = g_player.tiley + 4

 if (min_tilex < 0) then min_tilex = 1 end
 if (max_tilex > g_world_tilewidth) then max_tilex = g_world_tilewidth+1 end

 if (rnd() < 0.01) then
  local tilex = flr(rnd(max_tilex - min_tilex)) + min_tilex
  local tiley = min_tiley
  local tile, obj = is_occupied(tilex, tiley)

  if (tile == 0 and obj == nil) then
   new_ammo(tilex, tiley)
   g_ammo_spawned = true
  end
 end
end

function new_soda(tilex, tiley)
 local item = {}

 item.type = 'soda'
 item.collide = false
 item.sortprio = -1

 item.tilex = tilex
 item.tiley = tiley

 item.x = (16 * (tilex-1))
 item.y = -(16 * (tiley-1))
 item.w = 16
 item.h = 16

 item.update = function(self)
  if (g_player.tilex == self.tilex and g_player.tiley == self.tiley) then
   add_time(35, true)
   del(g_objects, self)
  end
 end

 item.teleport = function(self, toffset, poffset)
  self.tiley += toffset
  self.y += poffset
 end

 item.draw = function(self)
  sspr(0, 50, 10, 10, self.x + 3, self.y + 6 + (cos(g_frame/60)*2))
 end

 add(g_objects, item)
end

-->8
-- helper functions

function shake_screen()
	local shakex= rnd(g_shake_frame) - (g_shake_frame / 2)
	local shakey=rnd(g_shake_frame) - (g_shake_frame / 2)

 g_shake = {x=shakex, y=shakey}

 g_shake_frame -= 1
	if g_shake_frame > 10 then
		g_shake_frame *= 0.875
	elseif g_shake_frame < 1 then
		g_shake_frame = 0
	end
end

function reset_palette()
 pal({[0]=0,131,2,3,4,130,134,7,8,137,10,11,138,139,14,143},1)
end

function lerp(from, to, weight)
 local dist = to - from
 if (abs(dist) < 0.2) then return to end
 return (dist * weight) + from
end

-- taken from: https://www.lexaloffle.com/bbs/?pid=18374#p
function heapsort(t, cmp)
 local n = #t
 local i, j, temp
 local lower = flr(n / 2) + 1
 local upper = n

 if (n < 2) then
  return
 end

 while 1 do
  if lower > 1 then
   lower -= 1
   temp = t[lower]
  else
   temp = t[upper]
   t[upper] = t[1]
   upper -= 1
   if upper == 1 then
    t[1] = temp
    return
   end
  end

  i = lower
  j = lower * 2
  while j <= upper do
   if j < upper and cmp(t[j], t[j+1]) < 0 then
    j += 1
   end
   if cmp(temp, t[j]) < 0 then
    t[i] = t[j]
    i = j
    j += i
   else
    j = upper + 1
   end
  end
  t[i] = temp
 end
end

function play_sfx(s)
 if (not g_muted) then
  sfx(s)
 end
end

function shadow(o)
 ovalfill(o.x, o.y+12, o.x+15, o.y+17, 4)
 ovalfill(o.x+1, o.y+12, o.x+14, o.y+17, 2)
end

-- we teleport the game area back to the origin to prevent integer overflow
function teleport()
 -- tile offset
 local toffset = -g_player.tiley + 1
 -- pixel offset
 local poffset = -g_player.y + 12

 -- add any pixel coordinates to the pixel offset
 g_camera.y = g_camera.y + poffset
 g_camera.ytarget = g_camera.ytarget + poffset
 g_mapregions[1] = g_mapregions[1] + poffset
 g_mapregions[2] = g_mapregions[2] + poffset

 -- loop through the tracked objects list and teleport them too
 for obj in all(g_objects) do
  obj.teleport(obj, toffset, poffset)
 end
end

function add_points(num, tilex, tiley)
 -- convert to screen coordinates
 local screenx = ((tilex-1)*16) - g_camera.x
 local screeny = -((tiley-1)*16) - g_camera.y

 -- add to point tracking
 g_points += num>>16

 -- point particle setup
 local particle = {}
 particle.coroutine = cocreate(function() 
  local x_offset = -4
  local y = 2
  local point_str = "+"..num
  if (num < 0) then
   point_str = tostr(num)
  end
  while (y != 15) do
   y = lerp(y, 15, 0.2)
   local actualx = screenx + (#point_str*2) + x_offset
   local actualy = screeny - y + 8
   rectfill(actualx-1, actualy-1, actualx+(#point_str*4)-1, actualy+5, 5)
   print(point_str, actualx, actualy, 10)
   yield()
  end
 end)

 add(g_point_particles, particle)
end

function refill_ammo()
 g_ammo = 6
 g_ammo_flash = cocreate(function()
  local flash = true
  for i=0,60 do
   if (i % 10 == 0) then
    flash = not flash
   end

   if (flash) then
    rectfill(60, 50, 62, 62, 7)
   else
    rectfill(60, 50, 62, 62, 5)
   end

   yield()
  end
 end)
end

function remove_time(time, harmed)
 g_timer -= time
 if (harmed) then
  g_timer_flash = cocreate(function()
   local flash = true
   for i=0,60 do
    if (i % 10 == 0) then
     flash = not flash
    end

    if (flash) then
     rectfill(1, 1, 3, 62, 8)
    else
     rectfill(1, 1, 3, 62, 5)
    end

    yield()
   end
  end)
 end
end

function add_time(time, pickup)
 g_timer += time
 if (g_timer > 180) then g_timer = 180 end

 if (pickup) then
  g_timer_flash = cocreate(function()
   local flash = true
   for i=0,60 do
    if (i % 10 == 0) then
     flash = not flash
    end

    if (flash) then
     rectfill(1, 1, 3, 62, 7)
    else
     rectfill(1, 1, 3, 62, 5)
    end

    yield()
   end
  end)
 end
end

function explode(sprnum, tilex, tiley, kamikaze)
 -- sound effect
 play_sfx(10)
 
 -- update points
 if (sprnum == 38 and not kamikaze) then -- alien
  add_points(5, tilex, tiley)
 end

 -- spritesheet cel coords
 local celx = sprnum % 16
 local cely = sprnum \ 16

 -- cel coords to pixel coords
 local px = celx * 8
 local py = cely * 8

 -- explosion particles
 for dx=0,15 do
  for dy=0,15 do
   local pcolor = sget(px+dx, py+dy)
   if (pcolor ~= c_transparent) then
    add(g_particles, {
     x=((tilex-1)*16)+dx,
     y=(-(tiley-1)*16)+dy,
     r=0,
     dx=2-rnd(4),
     dy=2-rnd(4),
     dr=0,
     c=pcolor,
     ttl=5+rnd(5)
    })
   end
  end
 end
end

-- ----------------
-- PARTICLE SYSTEM
-- ----------------
function update_particles()
 local delete = {}
 for idx,particle in ipairs(g_particles) do
  particle.x = particle.x + particle.dx
  particle.y = particle.y + particle.dy
  particle.r = particle.r + particle.dr
  particle.ttl -= 1

  if (particle.ttl <= 0) then
   add(delete, idx)
  end
 end

 for i=#delete,1,-1 do
  deli(g_particles, delete[i])
 end
end

function draw_particles()
 for particle in all(g_particles) do
  circfill(particle.x, particle.y, particle.r, particle.c)
 end
end

function clear_particles()
 g_particles = {}
end

function update_point_particles()
 for emitter in all(g_point_particles) do
  if (costatus(emitter.coroutine) ~= 'dead') then
   coresume(emitter.coroutine)
  else
   del(g_point_particles, emitter)
  end
 end
end

__gfx__
0000000099999999998889998f899889999999999999999999988899999777777779999999999999997777999999999779977779999999779977779999999999
000000009999999998fff899f7f98ff8999988888889999999888889999755555557999999999977976666797799997006766667999997006766667999999999
00700700999999998f777f89f7f98ff8999888fff8889999988fff88999756767755799999999700677667760079997677776667977997677776667977999999
00077000999999998f777f89f7f98ff89988f77777f8899998fffff8999755777755579999999766777777776679997677e77777600797677e77777600799999
00077000999999998f777f89f7f98ff8998f7777777f899988fffff88997555757557999999997677e7777e77679990777e77777766790777e77777766799999
00700700999999998f777f89f7f98ff8988f7777777f889988fffff889975555555799999999907677eeee7767099997777eeeee7767957777eeeee776799999
00000000999999998f777f89f7f98ff8988f7777777f88998fffffff899777777779999999999907777777777099995977777777777006077777777777099999
00000000999999998f777f89f7f98ff898f777777777f8998fffffff899999999999999999999990077777700999906000777777009907600777777009999999
99999999999999998f777f89f7f98ff898f777777777f8998fffffff899977777777999999999077600000067709907600000000044900000000000044999999
99999999999999448ff7ff89f7f9988998f777777777f8998fffffff89972888888279999999907ee222222ee70990007255500067099f776222000670999999
999999999994449998fff899f7f99999988777777777889988fffff8899758aaa885799999979507e7eeee7e705999f777222227e7090f7ee7ee227e70999999
999442222499999998fff899f7f99889988f7777777f889988fffff889975888888579999955044077e77e7704f090f77e7eeee7ee990407e7e7ee7ee9999999
9999999222229999988f88998f898ff8998f7777777f899998fffff89997288888827999995ff4006777777604f090407e7e77e77099044077777e7709999999
9944444994422244998889998f898ff89988f77777f88999988fff889997055555507999967ff55006666660000f004407e77777600990006666777600999999
44999999999999999988899988898ff899988f777f8899999988f8899997055555507999676f45500066660000ff090006666666000990000066666000999999
99999999999999999999999998999889999998878899999999998999999977777777999976090000000000000000990000066660000990024400660000999999
99999999a99a999999999ffffff99999999999999999999993333999999333399999999960999900550000550099990224600000000990224600000000999999
999999913aac1999999ff222222ff99999999999999999993bbbbb3993bbbbb39999999999999995005995005999990555009950059990555009950059999999
999999cddcaad99999f2244444422f9999999999999999993bbbbbb99bbbbbbb9999999999999999999999999999999999999999999999999999999999999999
99c9a993dccc399994f444ff22444f299992222499999999bb333b399b3333bb9999999999999999999999999999999999999999999999999999999999999999
99dcc99ddcdcdc9924f44422ff444f494222449999999999b30003399300003b9999999999999999999999999999999999999999999999999999999999999999
9ddccd933d3d39995f5ff444444ff5f099999999999999993000000cc00000039999999999999999999999999999999999999999999999999999999999999999
9dcdcd913d3d19995f445ffffff445f099999999999999993000000cc00000039999999999999999999999999999999999999999999999999999999999999999
91cdc0913d331c9944f4544544544f4099999999999999991300081bb18000319999999999999999999999999999999999999999999999999999999999999999
9131319013330999444ff445445ff44099999999999999999933081bb18033099999999999999999999999999999999999999999999999999999999999999999
913131011313199954444ffffff4444099999999999999999011003bb30003399999999999999999999999999999999999999999999999999999999999999999
90313110131309992f454454444544f094499999999999999bb0007337000bb99999999999999999999999999999999999999999999999999999999999999999
901113111313199904f5445444454f4099942499999999999b300078870003b09999999999999999999999999999999999999999999999999999999999999999
9901111013131999954ff454444ff559999992249999999907000008800907b09999999999999999999999999999999999999999999999999999999999999999
999000011311199990554ffffff54509422224999999999907709060060907709999999999999999999999999999999999999999999999999999999999999999
99999991111119999905555444555099999999999999999997799900009997709999999999999999999999999999999999999999999999999999999999999999
99999990111109999990055555500999999999999999999999799999999999799999999999999999999999999999999999999999999999999999999999999999
99999977779999999999999777709779999999999999999999999999999999999333399999933339999999999999999979999999999999979999999999999999
99779766667977999997797666676007999999999999999999999999999999993bbbbb3993bbbbb3333339999993333397999999999999799999999999999999
97006776677600799970067766777667999999999999999993333999999333393bbbbbb99bbbbbbb3bbbbb3993bbbbbb99799999999997999979999999999799
976677777777667999766777777e776799999999999999993bbbb339933bbbb3bb333b399b3333bbbbbbbbb99bbbbbbb99979999999979999997999999997999
97677e7777e77679997677e7777e767099999999999999993bbb3bb99bb3bbbbb30003399300003b30033b399b33300399999999999999999999799999979999
907677eeee7767099907677eeee7770999999999999999999333bb3993bb33393000000cc0000003000003399300000099999999999999999999979999799999
9007777777777099999077777777709999999999999999993bbbbb3993bbbbb33000000cc00000031000000cc000000199999999999999999999999999999999
0ff0077777700999999900777770000999999999999999993bbbbb0cc0bbbbb31300001cc10000311000000cc000000199999999999999999999999999999999
0f77600000067799990776000002677009999999999999991333330cc03333319933001cc10033099100081bb180001999999999999999999999999999999999
0f7ee222222ee7099907ee222227ee0ff0999999999999990100001bb10000109011083bb38003309033081bb180333999999999999999999999999999999999
0407e7eeee7e704099507e7eeee7e7004f099999999999999030011bb11003090bb0003bb3000bb09b110078870003b999999999999999999999979999799999
044077e77e77044090f4077e77e7709044099999999999990bb0003bb3000bb00b30001bb10003b0b3b0007887000b3b99999999999999999999799999979999
900067777776004090f406777777609900099999999999990b30022bb22003b007000001100907b0b33000088000033b99979999999979999997999999997999
9999066666650ff00f0000666666000999999999999999990b300013310003b00770906006090770779000088009097799799999999997999979999999999799
9999000002220ff00ff000066660052299999999999999990b707061160707b09779990000999770779090600609097797999999999999799999999999999999
99999000046400099000000000006005599999999999999997779900009977709979999999999979799999000099999779999999999999979999999999999999
99999900055509999990055500999559999999999999999999999999999999999999999999999999999999999999777007779999999666999999999999999999
99999999900099999999550099999999999999999999999999999999999999999999999999999999999999999997777744477999999966669999777777779999
99977779999777777779999999999999999999999999999999999999999999999999999999999999999999999907777744477099669766777977777777777999
99700007997055555507999999999999999999999999999999999999999999999999999999999999999999999904777777774099667767677777777777777799
970e77e0797577766657999999999999999999999999999999999999999999999999999999999999999999999900477777774099967767666677777777777799
70e777ee077576666657999999999999999999999999999999999999999999999999999999999999999999999900477777440099966770777677777777777709
70e77eee077566666657999999999999999999999999999999999999999999999999999999999999999999999947440000774499999770777666666666666670
70eeeeee077756666577999999999999999999999999999999999999999999999999999999999999999999999940007777000499999777776766666666666670
70eeeeee077770560777999999999999999999999999999999999999999999999999999999999999999999999900407777040099997777777666666666666670
970eeee0797752222577999999999999999999999999999999999999999999999999999999999999999999999904470770044099997777767666666666666676
99700007997522262257999999999999999999999999999999999999999999999999999999999999999999999900070770700099999669907666666666666676
99977779997522222257999999999999999999999999999999999999999999999999999999999999999999999900777777770099999999996699966666666606
9999999999705555550799999999999999999999999999999999999999999999999999999999999999999999999077eeee770999999999996699999999996606
99999999999777777779999999999999999999999999999999999999999999999999999999999999999999999990040ee0400999999999990999999999990090
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999990000000000999999999966999999999996690
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999077007709999999999966999999999996699
99999945520999499999999999099992999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999905220999499999999999499992999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999905209999929999999999499942999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999902099999929999999994099945999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999942999999929999999945099425999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999942999999409999999245099255999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994999999409999992255094552999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999299994259999945552094552999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999429992259999905522099429999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999902222529999902220999949999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999940225529999952004999949999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999940055249999950449999994999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999940052549999450499999994999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999990205599999450999999994999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999990299599999450999999992999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999990299959999450999999942999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999990299959999254999999942999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999902099949994204999994420999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999402099949442209999992220999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999402099942222259999922225999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999025999952225559999922555999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999025999955555509999925552999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994225999405552509999455222999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994252990222222549999405224999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994029902552225599999402249999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994029905555554999999250299999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999994099990524499999994250499999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999099999029999999942520499999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999409999099999999222520999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999409999409999999225202999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999940999409999994255202999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999990999909999994552509499999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
90000055555555555555555555555555555555555555555555555000099999999999999999999999999999999999999999999999999999999999999999999999
05222222222222222222222222222222222222222222222222222222559999999999999999999999999999999999999999999999999999999999999999999999
522222aaa2aa22222222222222222222222222222222222222222222259999999999999999999999999999999999999999999999999999999999999999999999
55222aaaaaaa22222222222222222222222222222222222222222222259999999999999999999999999999999999999999999999999999999999999999999999
5222aaa22aaa22aaa2aa2aa2aaa22aaa22aaa22aaaa22aa2aaa22222259999999999999999999999999999999999999999999999999999999999999999999999
0552aa2222222aaaaaaa2aaaaaaa2aaa22aaa2aaaaaa2aaaaaaa2222509999999999999999999999999999999999999999999999999999999999999999999999
0022aa2222222aa22aa222aa22aa22aa22aa22aa22aa22aa22aa2220009999999999999999999999999999999999999999999999999999999999999999999999
0552aaa222aa2aa22aa222aa22aa22aa22aa22aa22aa22aa22aa2222559999999999999999999999999999999999999999999999999999999999999999999999
52222aaaaaaa2aaaaaaa2aaaa2aaa2aaaaaa22aaaaaa2aaaa2aaa222259999999999999999999999999999999999999999999999999999999999999999999999
522222aaaaa222aaa2aa2aaaa2aaa22aaaaa222aaaa22aaaa2aaa222259999999999999999999999999999999999999999999999999999999999999999999999
5222222222222222222222222222222222aa22222222222222222222259999999999999999999999999999999999999999999999999999999999999999999999
9555222222222222222222222222222aaaaa22222222222222222225509999999999999999999999999999999999999999999999999999999999999999999999
9000000055555555555555555555552aaaa225555555555555500000009999999999999999999999999999999999999999999999999999999999999999999999
99005222222222222222222222222222222222222222222222222225099999999999999999999999999999999999999999999999999999999999999999999999
99995222222888882288888228888228888228888228888222222222099999999999999999999999999999999999999999999999999999999999999999999999
99992222228882282882228822882288888822882288888888222222999999999999999999999999999999999999999999999999999999999999999999999999
99990522888822222882228822882288222222882288222222225000999999999999999999999999999999999999999999999999999999999999999999999999
99992222228822222888888222882228888222882228888222222259999999999999999999999999999999999999999999999999999999999999999999999999
99992222288822222882288222282222228822282222228822222259999999999999999999999999999999999999999999999999999999999999999999999999
99992222228882222882228822282288888822282288888822222259999999999999999999999999999999999999999999999999999999999999999999999999
99995222222888882282228822888228888222888228888222222209999999999999999999999999999999999999999999999999999999999999999999999999
99990552222222222222222222222222222222222222222222222509999999999999999999999999999999999999999999999999999999999999999999999999
99999005555555555555555555555555555555555555555555550099999999999999999999999999999999999999999999999999999999999999999999999999
99999950000000000000000000000000000000000000000000000999999999999999999999999999999999999999999999999999999999999999999999999999
__label__
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp4444pppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp4444pppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442244pppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442244pppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp222244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp222244pppppppppppppppppppppppppppppppp
pppppppp0000000000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii00000000pppppppp
pppppppp0000000000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii00000000pppppppp
pppppp00ii222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iiiipppppp
pppppp00ii222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iiiipppppp
ppppppii2222222222aaaaaa22aaaa222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iipppppp
ppppppii2222222222aaaaaa22aaaa222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iipppppp
ppppppiiii222222aaaaaaaaaaaaaa222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iipppppp
ppppppiiii222222aaaaaaaaaaaaaa222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222iipppppp
ppppppii222222aaaaaa2222aaaaaa2222aaaaaa22aaaa22aaaa22aaaaaa2222aaaaaa2222aaaaaa2222aaaaaaaa2222aaaa22aaaaaa222222222222iipppppp
ppppppii222222aaaaaa2222aaaaaa2222aaaaaa22aaaa22aaaa22aaaaaa2222aaaaaa2222aaaaaa2222aaaaaaaa2222aaaa22aaaaaa222222222222iipppppp
pppppp00iiii22aaaa22222222222222aaaaaaaaaaaaaa22aaaaaaaaaaaaaa22aaaaaa2222aaaaaa22aaaaaaaaaaaa22aaaaaaaaaaaaaa22222222ii00pppppp
pppppp00iiii22aaaa22222222222222aaaaaaaaaaaaaa22aaaaaaaaaaaaaa22aaaaaa2222aaaaaa22aaaaaaaaaaaa22aaaaaaaaaaaaaa22222222ii00pppppp
pppppp00002222aaaa22222222222222aaaa2222aaaa222222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa222222000000pppppp
pppppp00002222aaaa22222222222222aaaa2222aaaa222222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa222222000000pppppp
pppppp00iiii22aaaaaa222222aaaa22aaaa2222aaaa222222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa22222222iiiipppppp
pppppp00iiii22aaaaaa222222aaaa22aaaa2222aaaa222222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa22222222iiiipppppp
ppppppii22222222aaaaaaaaaaaaaa22aaaaaaaaaaaaaa22aaaaaaaa22aaaaaa22aaaaaaaaaaaa2222aaaaaaaaaaaa22aaaaaaaa22aaaaaa22222222iipppppp
ppppppii22222222aaaaaaaaaaaaaa22aaaaaaaaaaaaaa22aaaaaaaa22aaaaaa22aaaaaaaaaaaa2222aaaaaaaaaaaa22aaaaaaaa22aaaaaa22222222iipppppp
ppppppii2222222222aaaaaaaaaa222222aaaaaa22aaaa22aaaaaaaa22aaaaaa2222aaaaaaaaaa222222aaaaaaaa2222aaaaaaaa22aaaaaa22222222iipppppp
ppppppii2222222222aaaaaaaaaa222222aaaaaa22aaaa22aaaaaaaa22aaaaaa2222aaaaaaaaaa222222aaaaaaaa2222aaaaaaaa22aaaaaa22222222iipppppp
ppppppii222222222222222222222222222222222222222222222222222222222222222222aaaa222222222222222222222222222222222222222222iipppppp
ppppppii222222222222222222222222222222222222222222222222222222222222222222aaaa222222222222222222222222222222222222222222iipppppp
ppppppppiiiiii222222222222222222222222222222222222222222222222222222aaaaaaaaaa22222222222222222222222222222222222222iiii00pppppp
ppppppppiiiiii222222222222222222222222222222222222222222222222222222aaaaaaaaaa22222222222222222222222222222222222222iiii00pppppp
pppppppp00000000000000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii22aaaaaaaa2222iiiiiiiiiiiiiiiiiiiiiiiiiiii00000000000000pppppp
pppppppp00000000000000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii22aaaaaaaa2222iiiiiiiiiiiiiiiiiiiiiiiiiiii00000000000000pppppp
pppppppppp0000ii2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222ii0022vvpppp
pppppppppp0000ii2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222ii0022vvpppp
ppppppppppppppii2222222222228888888888222288888888882222888888882222888888882222888888882222888888882222222222222222220044vv22pp
ppppppppppppppii2222222222228888888888222288888888882222888888882222888888882222888888882222888888882222222222222222220044vv22pp
pppppppppppppp222222222222888888222288228888222222888822228888222288888888888822228888222288888888888888882222222222224444vv44pp
pppppppppppppp222222222222888888222288228888222222888822228888222288888888888822228888222288888888888888882222222222224444vv44pp
pppppppppppppp00ii22228888888822222222228888222222888822228888222288882222222222228888222288882222222222222222ii000000vvvviivv00
pppppppppppppp00ii22228888888822222222228888222222888822228888222288882222222222228888222288882222222222222222ii000000vvvviivv00
pppppppppppppp2222222222228888222222222288888888888822222288882222228888888822222288882222228888888822222222222222iivv4444iivv00
pppppppppppppp2222222222228888222222222288888888888822222288882222228888888822222288882222228888888822222222222222iivv4444iivv00
pppppppppppppp2222222222888888222222222288882222888822222222882222222222228888222222882222222222228888222222222222iiii4444vv4400
pppppppppppppp2222222222888888222222222288882222888822222222882222222222228888222222882222222222228888222222222222iiii4444vv4400
pppppppppppppp2222222222228888882222222288882222228888222222882222888888888888222222882222888888888888222222222222iiiivvvv444400
pppppppppppppp2222222222228888882222222288882222228888222222882222888888888888222222882222888888888888222222222222iiiivvvv444400
ppppppppppppppii2222222222228888888888222288222222888822228888882222888888882222228888882222888888882222222222222200vv4444444400
ppppppppppppppii2222222222228888888888222288222222888822228888882222888888882222228888882222888888882222222222222200vv4444444400
pppppppppppppp00iiii22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222ii0044ii4444vv00
pppppppppppppp00iiii22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222ii0044ii4444vv00
pppppppppppppppp0000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii00004444ii44vv4400
pppppppppppppppp0000iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii00004444ii44vv4400
ppppppppppppppppppii00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444vvvviiiipp
ppppppppppppppppppii00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444vvvviiiipp
pppppppppppppppppppppppppppppppppppppp00000000jjjj33jjjjjjpppppppppppppppppppppppppppppppppppppppp00iiii44vvvvvvvvvvvvii44ii00pp
pppppppppppppppppppppppppppppppppppppp00000000jjjj33jjjjjjpppppppppppppppppppppppppppppppppppppppp00iiii44vvvvvvvvvvvvii44ii00pp
ppppppppppppppppppppppppppppppppppppppppppppppjjjjjjjjjjjjpppppppppppppppppppppppppppppppppppppppppp00iiiiiiii444444iiiiii00pppp
ppppppppppppppppppppppppppppppppppppppppppppppjjjjjjjjjjjjpppppppppppppppppppppppppppppppppppppppppp00iiiiiiii444444iiiiii00pppp
pppppppppppppppppppppppppppppppppppppppppppppp00jjjjjjjj00pppppppppppppppppppppppppppppppppppppppppppp0000iiiiiiiiiiii0000pppppp
pppppppppppppppppppppppppppppppppppppppppppppp00jjjjjjjj00pppppppppppppppppppppppppppppppppppppppppppp0000iiiiiiiiiiii0000pppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii777777ii77iiiiii777777ii77ii77iiiiiiiiiiiiiiiiiimmmmmmiiiimmmmiiiimmmmiiiimmmmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii777777ii77iiiiii777777ii77ii77iiiiiiiiiiiiiiiiiimmmmmmiiiimmmmiiiimmmmiiiimmmmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77ii77ii77iiiiii77ii77ii77ii77iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiiiiiimmiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77ii77ii77iiiiii77ii77ii77ii77iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiiiiiimmiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii777777ii77iiiiii777777ii777777iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiiiiiimmiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii777777ii77iiiiii777777ii777777iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiiiiiimmiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77iiiiii77iiiiii77ii77iiiiii77iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiimmiimmiimmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77iiiiii77iiiiii77ii77iiiiii77iiiiiiiiiiiiiiiiiiiimmiiiimmiimmiimmiimmiimmiimmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77iiiiii777777ii77ii77ii777777iiiiiiiiiiiiiiiiiiiimmiiiimmmmiiiimmmmmmiimmmmmmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii77iiiiii777777ii77ii77ii777777iiiiiiiiiiiiiiiiiiiimmiiiimmmmiiiimmmmmmiimmmmmmii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp4444pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp4444pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp444444pppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp444444pppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp44442222222244pppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp44442222222244pppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp2222222222pppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp2222222222pppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp777777774444444444pppp44442222224444pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp777777774444444444pppp44442222224444pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppp7777pp77mmmmmmmm77pp7777pppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppp7777pp77mmmmmmmm77pp7777pppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppp770000mm7777mmmm7777mm000077pppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppp770000mm7777mmmm7777mm000077pppppppppppppppppppppppppppppppppppppppppppppppppp
ppppppppppvvvvvvvvvvvvpppppppppppppppppppppppppppp77mmmm7777777777777777mmmm77ppppppppppppppppppppppppppppppppppaappppaapppppppp
ppppppppppvvvvvvvvvvvvpppppppppppppppppppppppppppp77mmmm7777777777777777mmmm77ppppppppppppppppppppppppppppppppppaappppaapppppppp
ppppppvvvv222222222222vvvvpppppppppppppppppppppppp77mm7777ee77777777ee7777mm77ppppppppppppppppppppppppppppppppjj33aaaaqqjjpppppp
ppppppvvvv222222222222vvvvpppppppppppppppppppppppp77mm7777ee77777777ee7777mm77ppppppppppppppppppppppppppppppppjj33aaaaqqjjpppppp
ppppvv22224444444444442222vvpppppppppppppppppppppp0077mm7777eeeeeeee7777mm7700ppppppppppppppppppppppppppppppqqrrrrqqaaaarrpppppp
ppppvv22224444444444442222vvpppppppppppppppppppppp0077mm7777eeeeeeee7777mm7700ppppppppppppppppppppppppppppppqqrrrrqqaaaarrpppppp
pp44vv444444vvvv2222444444vv22pppppppppppppppppppppp007777777777777777777700ppppppppppppppppppppppppqqppaapppp33rrqqqqqq33pppppp
pp44vv444444vvvv2222444444vv22pppppppppppppppppppppp007777777777777777777700ppppppppppppppppppppppppqqppaapppp33rrqqqqqq33pppppp
2244vv4444442222vvvv444444vv44pppppppppppppppppppppppp00007777777777770000pppppppppppppppppppppppppprrqqqqpppprrrrqqrrqqrrqqpppp
2244vv4444442222vvvv444444vv44pppppppppppppppppppppppp00007777777777770000pppppppppppppppppppppppppprrqqqqpppprrrrqqrrqqrrqqpppp
iivviivvvv444444444444vvvviivv00pppppppppppppppppp007777mm000000000000mm777700pppppppppppppppppppprrrrqqqqrrpp3333rr33rr33pppppp
iivviivvvv444444444444vvvviivv00pppppppppppppppppp007777mm000000000000mm777700pppppppppppppppppppprrrrqqqqrrpp3333rr33rr33pppppp
iivv4444iivvvvvvvvvvvv4444iivv00pppppppppppppppppp0077eeee222222222222eeee7700pppppppppppppppppppprrqqrrqqrriiiiiiiiiiiiiiiiiiii
iivv4444iivvvvvvvvvvvv4444iivv00pppppppppppppppppp0077eeee222222222222eeee7700pppppppppppppppppppprrqqrrqqrriiiiiiiiiiiiiiiiiiii
4444vv44ii4444ii4444ii4444vv4400pppppppppppppp77ppii0077ee77eeeeeeee77ee7700iippppppppppppppppppppjjqqrrqq00iiiiiiiiiiiiiiiiiiii
4444vv44ii4444ii4444ii4444vv4400pppppppppppppp77ppii0077ee77eeeeeeee77ee7700iippppppppppppppppppppjjqqrrqq00iiiiiiiiiiiiiiiiiiii
444444vvvv4444ii4444iivvvv444400ppppppppppppiiii004444007777ee7777ee77770044vv00ppppppppppppppppppjj33jj33jjiiiiiiiiiiiiiiiiiiii
444444vvvv4444ii4444iivvvv444400ppppppppppppiiii004444007777ee7777ee77770044vv00ppppppppppppppppppjj33jj33jjiiiiiiiiiiiiiiiiiiii
ii44444444vvvvvvvvvvvv4444444400ppppppppppppiivvvv440000mm777777777777mm0044vv00ppppppppppppppppppjj33jj33jjiiiiiiiiii777777iiii
ii44444444vvvvvvvvvvvv4444444400ppppppppppppiivvvv440000mm777777777777mm0044vv00ppppppppppppppppppjj33jj33jjiiiiiiiiii777777iiii
22vv44ii4444ii44444444ii4444vv00ppppppppppmm77vvvviiii0000mmmmmmmmmmmm00000000vv00pppppppppppppppp0033jj33jjiiiiiiiiii77iiiiiiii
22vv44ii4444ii44444444ii4444vv00ppppppppppmm77vvvviiii0000mmmmmmmmmmmm00000000vv00pppppppppppppppp0033jj33jjiiiiiiiiii77iiiiiiii
0044vvii4444ii44444444ii44vv4400ppppppppmm77mmvv44iiii000000mmmmmmmm00000000vvvv00pppppppppppppppp00jjjjjj33iiiiiiiiii77iiiiiiii
0044vvii4444ii44444444ii44vv4400ppppppppmm77mmvv44iiii000000mmmmmmmm00000000vvvv00pppppppppppppppp00jjjjjj33iiiiiiiiii77iiiiiiii
ppii44vvvv44ii44444444vvvviiiipppppppppp77mm00pp00000000000000000000000000000000pppppppppppppppppppp00jjjjjjiiiiii777777iiiiiiii
ppii44vvvv44ii44444444vvvviiiipppppppppp77mm00pp00000000000000000000000000000000pppppppppppppppppppp00jjjjjjiiiiii777777iiiiiiii
pp00iiii44vvvvvvvvvvvvii44ii00ppppppppppmm00pppppppp0000iiii00000000iiii0000pppppppppppppppppppppppppp000000iiiiii777777iiiiiiii
pp00iiii44vvvvvvvvvvvvii44ii00ppppppppppmm00pppppppp0000iiii00000000iiii0000pppppppppppppppppppppppppp000000iiiiii777777iiiiiiii
pppp00iiiiiiii444444iiiiii00ppppppppppppppppppppppppppii0000iippppii0000iippppppppppppppppppppppppppppppppppiiiiiiiiiiiiiiiiiiii
pppp00iiiiiiii444444iiiiii00ppppppppppppppppppppppppppii0000iippppii0000iippppppppppppppppppppppppppppppppppiiiiiiiiiiiiiiiiiiii
pppppp0000iiiiiiiiiiii0000ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppiiiiiiiiiiiiiiiiiiii
pppppp0000iiiiiiiiiiii0000ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppiiiiiiiiiiiiiiiiiiii

__map__
0000000000000000000000000000000000002223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024
0000000000000000000000000000000000003233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000020210000000022230000000000000000000000000000202100000000000022232223000000000000000000000000000000002223000022230000000000002223222300000000000000000000000000000000000000000000000000000000000000000000000000002223000000000000000000001011000000000000
0000000030310000000032330000000000000000000000000000303100000000000032333233000000000000000000000000000000003233000032330000000000003233323300000000000000000000000000000000000000000000000000000000000000000000000000003233000000000000000000000000000000000000
0000000000002021000000000000202100000000202100000000000000000000000022232223000000002223202100000000000000000000000000000000000000000000000000000000000022230000000020210000000000000000000000000000000000000000000020212223000000002223202100000000000000340000
0000000000003031000000000000303100000000303100000000000000000000000032333233000000003233303100000000000000000000000000000000000000000000000000000000000032330000000030310000000000000000000000000000000000000000000030313233000000003233303100000000000000000000
0000222300000000000000000000000000000000000022230000000020210000000000000000202100000000000000000000000000000000000000002021000000002021000000000000000000000000000000000000000000002223000000002223000000000000000000000000000000000000000000000000240000000000
0000323300000000000000000000000000000000000032330000000030310000000000000000303100000000000000000000000000000000000000003031000000003031000000000000000000000000000000000000000000003233000000003233000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222320210000000000000000000000000000000000000000000000000000000000000000000000000000222300000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000323330310000000000000000000000000000000000000000000000000000000000000000000000000000323300000000000000000000000000000000000000000000000000000000000010110000
0000202100002223000000000000000000002223202100000000202100000000000022230000000000000000222300000000000000000000000022230000000022230000000022230000202100000000000000000000000000000000000000000000000020210000000000000000000000000000000000000000000000000000
0000303100003233000000000000000000003233303100000000303100000000000032330000000000000000323300000000000000000000000032330000000032330000000032330000303100000000000000000000000000000000000000000000000030310000000000000000000000000000000000000024000000000000
0000000000000000000000000000000000000000000000002021000000000000000000002021000000002223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020210000000000002021000000000000000000000000
0000000000000000000000000000000000000000000000003031000000000000000000003031000000003233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030310000000000003031000000000000000000000034
2223000000002021000000002021000000000000000000000000000000000000000000000000000000000000000000000000000022230000000000000000202100000000000000000000000000000000000000000000000000002223202100000000000000002223000000000000000000000000000000000000000000000000
3233000000003031000000003031000000000000000000000000000000000000000000000000000000000000000000000000000032330000000000000000303100000000000000000000000000000000000000000000000000003233303100000000000000003233000000000000000000000000000000000000000000000000
0000000000000000000000000000000000002021000000000000000000000000000000000000000000000000202100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000
0000000000000000000000000000000000003031000000000000000000000000000000000000000000000000303100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000222300000000000000000000222300000000000000000000000000000000000000002223000000000000202100002223000022232021000000002223222300000000202120210000000000002223000000000000000000000000202100000000000022230000000000000000000000000000000000000000
0000000000000000323300000000000000000000323300000000000000000000000000000000000000003233000000000000303100003233000032333031000000003233323300000000303130310000000000003233000000000000000000000000303100000000000032330000000000000000000000000000000000000000
2021000022230000000000000000202100000000000000000000202100002021000000000000000000000000000000000000000000000000000000000000000000000000000000000000202120210000000000000000000000000000000000000000000020210000000022230000000000000000000000000000000000101100
3031000032330000000000000000303100000000000000000000303100003031000000000000000000000000000000000000000000000000000000000000000000000000000000000000303130310000000000000000000000000000000000000000000030310000000032330000000000000000000000000000000000000000
0000000000000000000000000000222300000000202100000000000000000000000000000000222300000000000000000000222300000000000000000000000000000000202100000000000000000000000000000000000000000000222300000000000000000000000000000000000000000000000000000000240000000000
0000000000000000000000000000323300000000303100000000000000000000000000000000323300000000000000000000323300000000000000000000000000000000303100000000000000000000000000000000000000000000323300000000000000000000000000000000000000000000000000000000000000000000
0000000020210000000000000000000022230000000000000000000000000000000000000000000000000000000000000000000000000000000000002021000000000000000000000000000020210000000000000000000000000000000000000000000000000000000000000000000000000000222300000000000000000000
0000000030310000000000000000000032330000000000000000000000000000000000000000000000000000000000000000000000000000000000003031000000000000000000000000000030310000000000000000000000000000000000000000000000000000000000000000000000000000323300000000000000340000
0000000000002223000022230000000000000000000000000000000000000000000000000000000000002021000000000000000000000000000022230000000022230000000022230000000000000000000000000000000000000000202100000000000020210000000000000000000000000000000000001011000000000000
0000000000003233000032330000000000000000000000000000000000000000000000000000000000003031000000000000000000000000000032330000000032330000000032330000000000000000000000000000000000000000303100000000000030310000000000000000000000000000000000000000000000000000
0000222300000000202100000000000000000000000000002021000000000000000022230000000000000000000000000000000000002223000000000000000000000000000000000000000000000000000000000000000000002021000000000000222300000000000000002021000000002021000000000000000000000000
0000323300000000303100000000000000000000000000003031000000000000000032330000000000000000000000000000000000003233000000000000000000000000000000000000000000000000000000000000000000003031000000000000323300000000000000003031000000003031000000000000000000002400
0000000000000000000000000000000000000000000000000000000000000000000000002021000000000000000022230000000000000000000000000000000000002021202100000000222300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000340000000000
0000000000000000000000000000000000000000000000000000000000000000000000003031000000000000000032330000000000000000000000000000000000003031303100000000323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
95030000100701007010070100751f000220002400024000290002b0002e000330003500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400002407024070240702407500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4908000028072280722b0722b07230072300723007230072300523003200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
05090000070730f143106430962309603156030160301603016030260302603006030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
010200000e060170511f0711a0050b0010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
010200000c06017051240711a005016010360101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
010200000c0601d071240611a005016010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
0104000013650006712a06102605026010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
0307000011b3011b5016b6016b701db701db6024b5024b3000b0000b001fb0000b0000b002ab0000b0000b0000b0000b0000b0000b0000b0000b0000b0009b0006b0000b0000b0000b0000b0000b0000b0000b00
03140000010540607304373026550263002640026200c7060c7000c7000c7030c703007031e703000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
010400001065010650106301061300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d0000293202932029320293252932029320293202b32029320293202632026320243202432522320223251f3201f325223202232522320223251b3201b3251d3201d3201d3201d32000300003001a3201a325
010d00001a3201a3201d3201d3201b3201b3201a3201a32018320183201b3201b3201a3201a320183201832016320163201a3201a320183201832516320163251832018320183201832018320183201832018320
010d000026320263202632026325263202632026325273202632026325243202432522320223252432024325263202632026320263251d3201d3201d3251f3201d3201d3201d3201d32000300003001a3201a325
010d00001a3201a3201d3201d3201b3201b3201a3201a32018320183201a3201a3201b3201b3201d3201d3251d3201d3201f3201f320213202132022320223202432024320243202432024320243202432024320
010d0000293202932029320293252932029320293202b32029320293202632026320243202432022320223201f3201f3252232022325223202232527320273252632026320263202632026320263202632026320
010d00001d3201d3201d3201d3251d3201d3251f3201f32522320223251f3201f3251d3201d3251f3201f32524320243252232022325243202432526320263252432024320243202432024320243202432024320
010d000029320293202932029320263202632529320293252e3202e3252d3202d3252e3202e32530320303252b3202b3202b3202b320283202832028320283202b3202b3202b3202b3202b3202b3202e3202e320
010d000029320293202932029320003000030026320263202932029320263202632029320293202e3202e3202d3202d3202d3202d320243202432024325263202432024320243202432000300003000030000300
010d0000263202632026320263202732027320283202832029320293202e3202e3202d3202d3202e3202e320303203032030320303202b3202b3202b325293202b3202b3202b3202b32000300003002d3202d320
010d00002e3202e3202e3202e3202e3202e3202d3202d3202b3202b32029320293202632026320223202232024320243202432024325243202432024325263202432024320243202432024320243202432024320
010d000029320293202932029320263202632529320293252e3202e3202e3202e3202d3202d3252e3202e3252b3202b3202b3202b320243202432024320243252b3202b3202b3202b32000300003002d3202d325
010d000029320293252932029325263202632529320293252e3202e3252d3202d3252e3202e32530320303252d3202d3202d3202d320243202432024325263202432024320243202432000300003000030000300
010d00002632026325263202632527320273252832028325293202932529320293252d3202d3252e3202e325303203032030320303202b3202b3202b325293202b3202b3202b3202b32000300003000030000300
010d00000030000300263202632527320273252832028325293202932029320293202e3202e3202e3202e3252d3202d3202d3202d3202d3202d3202d3202d3202432024320243202432024320243202432024325
010d00000000000000163101631500000000001631016315000000000016310163150000000000163101631500005000001631016315000000000016310163150000000000163101631500000000001631016315
010d00000000000000163101631500000000001631016315000000000013310133150000000000133101331500000000000000000000000000000016310163150000000000153101531500000000000000000000
010d00000000000000163101631500000000001631016315000000000013310133150000000000133101331500000000001131011315000000000011310113150000000000153101531500000000001530015300
010d000000000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001831018315000000000018310183150000000000183101831500000000001831018315
010d000000000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001b3101b3150000000000000000000000000000001a3101a31500000000000000000000
010d000000000000001a3101a315000000000000000000000f3100f3150f3000f3001631016310163101631500000000000000000000000000000000000000000000000000000000000000000000000000000000
010d000000000000001a3101a3150000000000000000000016310163100f3000f3001630016300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d000000000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001a3101a31500000000001b3101b3150000000000000000000000000000001a3101a31500000000001a3101a315
010d000000000000001a3101a31500000000001a3101a315000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d000000000000001a3101a31500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d000000000000001d3101d31500000000001d3101d31500000000001d3101d31500000000001d3101d31500000000001c3101c31500000000001c3101c31500000000001c3101c31500000000001c3101c315
010d000000000000001d3101d31500000000001d3101d31500000000001d3101d31500000000001d3101d31500000000002131021315000000000021310213150000000000213102131500000000002131021315
010d00000a0300a03511030110350a0300a03511030110350e0300e03511030110350a0300a03511030110350f0300f03513030130350a0300a03513030130350a0300a035110301103505030050351103011035
010d00000e0300e03511030110350a0300a03511030110350c0300c0350f0300f03507030070350f0300f0350a0300a0350e0300e03505030050350e0300e0350503005035110301103507030070350903009035
010d00000a0300a03511030110350e0300e03511030110350a0300a0350f0300f03505030050350f0300f0350a0300a0350e0300e03505030050350e0300e0350503005035050300503507030070350903009035
010d00000a0300a0300a0300a035050300503005030050350a0300a0300a0300a0350503005030050300503507030070300703007035000300003000030000350703007030070300703500030000300003000035
010d00000a0300a0300a0300a035050300503005030050350a0300a0300a0300a0350503005030050300503505030050300503005035000300003000030000350503005030050300503500030000300003000035
010d00000a0300a0300a0300a035050300503005030050350a0300a0300a0300a0350503005030050300503505030050300503005035000300003000030000350503005035050300503507030070350903009035
__music__
01 202e323a
00 212f333b
00 222e323a
00 2330343b
00 242e353a
00 2530363c
00 222e323a
00 2330373c
00 2631383d
00 2731393e
00 2831383d
00 2931393e
00 2a31383d
00 2b31393e
00 2c31383d
02 2d31393f

