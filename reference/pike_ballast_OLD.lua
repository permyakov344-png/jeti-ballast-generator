-- ============================================================
--  PIKE F3F 2026 - Ballast Table
--  Jeti DC-24 G2 | Lua App Script
--  Управление: Энкодер вверх/вниз — страницы, ESC — выход
-- ============================================================
local data = {
  { "0",  "45", "0",   "103", "98", "2300" },
  { "15", "45", "0.5", "102", "98", "2500" },
  { "15", "45", "1",   "102", "98", "2700" },
  { "15", "45", "1.5", "102", "98", "2850" },
  { "15", "45", "2",   "102", "98", "3000" },
  { "15", "45", "2.5", "102", "98", "3150" },
  { "15", "45", "3",   "102", "98", "3300" },
  { "15", "45", "3.5", "102", "98", "3450" },
  { "15", "45", "4",   "102", "98", "3600" },
  { "15", "45", "4.5", "102", "98", "3750" },
  { "15", "45", "5",   "102", "98", "3900" },
  { "15", "45", "5.5", "102", "98", "4050" },
  { "15", "45", "6",   "102", "98", "4200" },
  { "15", "--", "--",  "--",  "--", "--"   },
}
local HDR_TITLE = "PIKE F3F 2026"
local HDR_SLUGS = {"2300","45/98","30/100","15/102","20/101","40/99"}
local HDR_RIGHT = "MED'"
local APP_NAME  = "PIKE F3F 2026"

local pages = {}
for i = 1, #data, 2 do
  pages[#pages+1] = {i, data[i+1] and (i+1) or nil}
end
local page  = 1
local PAGES = #pages

local W,H        = 320,240
local HDR_H      = 18
local COLH_H     = 16
local ROW_H      = 98
local SUB_H      = 49
local C = {
  num  = {x=0,   w=36},
  nos  = {x=36,  w=72},
  wing = {x=108, w=70},
  cg   = {x=178, w=72},
  ves  = {x=250, w=70},
}

local function ctext(col, y, h, str, fnt)
  lcd.setFont(fnt)
  local tw = lcd.getTextWidth(fnt, str)
  lcd.drawText(col.x + (col.w - tw)/2, y + (h-14)/2, str)
end

local function drawVariant(y0, idx)
  local v  = data[idx]
  local y1 = y0 + SUB_H
  lcd.color(lcd.RGB(200,200,200)); lcd.drawFilledRect(C.num.x,  y0, C.num.w,  ROW_H)
  lcd.color(lcd.RGB(205,205,205)); lcd.drawFilledRect(C.nos.x,  y0, C.nos.w,  ROW_H)
  lcd.color(lcd.RGB(200,100,0));   lcd.drawFilledRect(C.wing.x, y0, C.wing.w, ROW_H)
  lcd.color(lcd.RGB(205,205,205)); lcd.drawFilledRect(C.cg.x,   y0, C.cg.w,   ROW_H)
  lcd.color(lcd.RGB(80,170,0));    lcd.drawFilledRect(C.ves.x,  y0, C.ves.w,  ROW_H)
  lcd.color(lcd.RGB(150,150,150))
  lcd.drawFilledRect(C.nos.x, y1-1, C.nos.w, 1)
  lcd.drawFilledRect(C.cg.x,  y1-1, C.cg.w,  1)
  lcd.color(lcd.RGB(120,120,120))
  lcd.drawFilledRect(C.nos.x-1,  y0, 1, ROW_H)
  lcd.drawFilledRect(C.wing.x-1, y0, 1, ROW_H)
  lcd.drawFilledRect(C.cg.x-1,   y0, 1, ROW_H)
  lcd.drawFilledRect(C.ves.x-1,  y0, 1, ROW_H)
  lcd.color(lcd.RGB(100,100,100))
  lcd.drawFilledRect(0, y0+ROW_H-1, W, 1)
  lcd.color(lcd.RGB(10,10,10))
  ctext(C.num,  y0, ROW_H, tostring(idx), FONT_BIG)
  ctext(C.nos,  y0, SUB_H, v[1], FONT_BIG)
  ctext(C.nos,  y1, SUB_H, v[2], FONT_BIG)
  ctext(C.wing, y0, ROW_H, v[3], FONT_BIG)
  ctext(C.cg,   y0, SUB_H, v[4], FONT_BIG)
  ctext(C.cg,   y1, SUB_H, v[5], FONT_BIG)
  ctext(C.ves,  y0, ROW_H, v[6], FONT_BIG)
end

local function draw()
  lcd.color(lcd.RGB(30,30,30));  lcd.drawFilledRect(0,0,W,H)
  lcd.color(lcd.RGB(90,90,90));  lcd.drawFilledRect(0,0,W,HDR_H)
  local x = 3
  lcd.setFont(FONT_MINI)
  lcd.color(lcd.RGB(0,220,255)); lcd.drawText(x,3,HDR_TITLE)
  x = x + lcd.getTextWidth(FONT_MINI,HDR_TITLE) + 4
  lcd.color(lcd.RGB(255,238,136))
  for _,s in ipairs(HDR_SLUGS) do
    lcd.drawText(x,3,s)
    x = x + lcd.getTextWidth(FONT_MINI,s) + 4
  end
  lcd.color(lcd.RGB(255,100,30))
  lcd.drawText(W - lcd.getTextWidth(FONT_MINI,HDR_RIGHT)-3, 3, HDR_RIGHT)
  local y = HDR_H
  lcd.color(lcd.RGB(210,210,210)); lcd.drawFilledRect(0,y,W,COLH_H)
  local hdrs = {
    {C.num,"No",lcd.RGB(20,20,20)},{C.nos,"NOS",lcd.RGB(20,20,20)},
    {C.wing,"KRYLO",lcd.RGB(20,20,20)},{C.cg,"CG",lcd.RGB(200,0,0)},
    {C.ves,"VES",lcd.RGB(20,20,20)},
  }
  lcd.setFont(FONT_MINI)
  for _,h in ipairs(hdrs) do
    lcd.color(h[3])
    lcd.drawText(h[1].x+(h[1].w-lcd.getTextWidth(FONT_MINI,h[2]))/2, y+3, h[2])
  end
  lcd.color(lcd.RGB(120,120,120)); lcd.drawFilledRect(0,y+COLH_H-1,W,1)
  local p    = pages[page]
  local yDat = HDR_H+COLH_H
  drawVariant(yDat, p[1])
  if p[2] then drawVariant(yDat+ROW_H, p[2]) end
  local foot = "p."..page.."/"..PAGES
  lcd.color(lcd.RGB(100,100,100)); lcd.setFont(FONT_MINI)
  lcd.drawText(W-lcd.getTextWidth(FONT_MINI,foot)-3, H-11, foot)
end

local function keyDown(key)
  if     key==KEY_UP   then page=page-1; if page<1     then page=PAGES end
  elseif key==KEY_DOWN then page=page+1; if page>PAGES then page=1 end
  elseif key==KEY_ESC  then system.exitScript() end
end

local function init()
  system.registerForm(1, MENU_APPS, APP_NAME, nil, keyDown, draw)
end

return { init=init, loop=function() end, destroy=function() end }
