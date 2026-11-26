local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local pc,tos=pcall,tostring
local sfind,ssub=string.find,string.sub
local RUN
local OKL,LOADERR=pc(function()
local W,H=LCD_W or 480,LCD_H or 272
local F_SML=SMLSIZE or 0
local F_DBL=DBLSIZE or 0
local RGT=RIGHT or 0
local SOLIDC=SOLID or 255
local E_NEXT=EVT_VIRTUAL_NEXT or-1
local E_NEXTR=EVT_VIRTUAL_NEXT_REP or E_NEXT
local E_PREV=EVT_VIRTUAL_PREV or-2
local E_PREVR=EVT_VIRTUAL_PREV_REP or E_PREV
local E_ENT=EVT_VIRTUAL_ENTER or EVT_ENTER_BREAK or-3
local E_ENTB=EVT_ENTER_BREAK or E_ENT
local E_BACK=EVT_VIRTUAL_PREV_PAGE or-4
local E_NEXTPG=EVT_VIRTUAL_NEXT_PAGE or-5
local E_ENTL=EVT_VIRTUAL_ENTER_LONG or-6
local E_EXIT=EVT_VIRTUAL_EXIT or-7
local T_FIRST=EVT_TOUCH_FIRST
local T_BREAK=EVT_TOUCH_BREAK
local T_SLIDE=EVT_TOUCH_SLIDE
local T_TAP=EVT_TOUCH_TAP
local function clamp(v,lo,hi)
if v==nil or v~=v then return lo end
if v<lo then return lo end
if v>hi then return hi end
return v
end
local function txt(v)
if v==nil then return"-"end
if type(v)=="table"then return"{t}"end
return tos(v)
end
local function padNZ(n)
n=floor(tonumber(n)or 0)
if n<0 then n=0 end
local s=tos(n)
if#s<2 then s="0"..s end
return s
end
local function oneDec(v)
if type(v)~="number"then return"-"end
local neg=v<0
if neg then v=-v end
local iv=floor(v)
local d=floor(v*10-iv*10+0.5)
if d>9 then iv=iv+1;d=0 end
local s=iv.."."..d
if neg then s="-"..s end
return s
end
local function pct(raw)
if type(raw)~="number"then return nil end
return clamp(floor(raw/10.24+0.5),-125,125)
end
local function fmtTime10(v)
if type(v)~="number"then return"-"end
local s=floor(v/10+0.5)
return tos(floor(s/60))..":"..padNZ(s%60)
end
local function padR(s,n)
s=tos(s or"")
while#s<n do s=s.." "end
return s
end
local TWOK=nil
local function tw(s)
if TWOK==nil then
TWOK=(type(lcd)=="table"and type(lcd.getTextWidth)=="function")
end
if TWOK then
local ok,w=pc(lcd.getTextWidth,txt(s))
if ok and type(w)=="number"and w>0 then return w end
end
return#txt(s)*7
end
local function PT(x,y,s,flags)
lcd.drawText(floor(x or 0),floor(y or 0),txt(s),flags or 0)
end
local INV=INVERS or 0
local C_W,C_B,C_BL,C_B2,C_LB,C_LN,C_GR,C_DK,C_RD=INV,0,SOLIDC,SOLIDC,0,0,0,0,0
local function FR(x,y,w,h,c)
lcd.drawFilledRectangle(floor(x),floor(y),
floor(w),floor(h),SOLIDC)
end
local function FRAME(x,y,w,h,c)
lcd.drawRectangle(floor(x),floor(y),
floor(w),floor(h),0)
end
local function LINE(x1,y1,x2,y2,c)
lcd.drawLine(floor(x1),floor(y1),
floor(x2),floor(y2),SOLIDC,0)
end
local function CLEAR()
lcd.clear()
end
local TB_H,ROW_H,BAR_H=30,24,20
local FB_Y,FB_BH=222,32
local CY=38
local CB=FB_Y-6
local VIS=floor((CB-CY)/ROW_H)
local F_MID=MIDSIZE or 0
local TZONES={}
local QUIT=false
local IDLET=0
local IDLEMSG=false
local TSCROLL=0
local TACT_T,TACT_X,TACT_Y=-1000,-1,-1
local function zone(x,y,w,h,act,a)
if T_BREAK and#TZONES<64 then
TZONES[#TZONES+1]={x=x,y=y,w=w,h=h,act=act,a=a}
end
end
local showMsg,pop,entOn,actOk,actNext,actYes,kbKey,kbSave,
scrollList,ssAdj,fAdd,fDel
local ui={stack={{k="main",i=1}}}
local function top()return ui.stack[#ui.stack]end
local function modelName()
local ok,info=pc(model.getInfo)
if ok and type(info)=="table"and info.name and info.name~=""then
return tos(info.name)
end
return"Default"
end
local function srcName(id)
if id==nil or id==0 then return"-"end
local ok,n=pc(getSourceName,id)
if ok and n~=nil then return tos(n)end
return"src"..txt(id)
end
local function swName(id)
if id==nil or id==0 then return"-"end
local ok,n=pc(getSwitchName,id)
if ok and n~=nil then return tos(n)end
return"sw"..txt(id)
end
local function txVolts()
local ok,v=pc(getValue,"tx-voltage")
if ok and type(v)=="number"then return v end
return nil
end
local function rssiVal()
local ok,v=pc(getValue,"RSSI")
if not(ok and type(v)=="number")then
ok,v=pc(getValue,"RSL")
end
if ok and type(v)=="number"then return floor(v)end
return nil
end
local function clockStr()
local ok,ms=pc(getTime)
if ok and type(ms)=="number"then
local s=floor(ms/100)%86400
return padNZ(floor(s/3600))..":"..
padNZ(floor(s/60)%60)..":"..padNZ(s%60)..
" "..floor((ms%100)/10)
end
local ok2,dt=pc(getDateTime)
if ok2 and type(dt)=="table"and dt.hour and dt.min then
return padNZ(dt.hour)..":"..padNZ(dt.min)..":"..padNZ(dt.sec or 0).." 0"
end
return"--:--:--"
end
local function sensorLive(name)
if name==nil or name==""then return nil end
local ok,v=pc(getValue,tos(name))
if ok and type(v)=="number"then return v end
return nil
end
local function chanLive(i)
local ok,v=pc(getValue,"out"..i)
if not(ok and type(v)=="number")then
ok,v=pc(getValue,"ch"..(i+1))
end
if ok then return pct(v)end
return nil
end
local function livePctStr(key)
local ok,v=pc(getValue,key)
local p=ok and pct(v)or nil
if p==nil then return"-"end
if p>=0 then return"+"..p.."%"end
return p.."%"
end
local CTRL={
{"P1","lside"},{"P2","rside"},{"P3","s1"},{"P4","s2"},
{"SA","sa"},{"SB","sb"},{"SC","sc"},{"SD","sd"},
{"SE","se"},{"SF","sf"},{"SG","sg"},{"SH","sh"},
{"SI","si"},{"SJ","sj"},{"LS","ls"},{"RS","rs"},
{"T1","trim-ail"},{"T2","trim-ele"},
{"T3","trim-thr"},{"T4","trim-rud"},
}
local function R(l,v,bar,arrow,nf)
return{l=l,v=v,bar=bar,arrow=arrow,nf=nf}
end
local cache={key="",rows={},t=0}
local function cachedRows(key,build)
local ok,now=pc(getTime)
now=(ok and type(now)=="number")and now or 0
if cache.key~=key or(now-cache.t)>250 then
local ok2,rows=pc(build)
if ok2 and type(rows)=="table"and#rows>0 then
cache.rows=rows
elseif not ok2 or type(rows)~="table"then
cache.rows={R("read error","-")}
end
cache.key=key
cache.t=now
end
return cache.rows
end
local function drawTopBar(t)
FR(0,0,W,TB_H,C_BL)
FR(0,TB_H,W,2,C_B2)
PT(10,4,t,C_W+F_MID)
local v=txVolts()
local st=((v and oneDec(v).."V")or"-").."  "..clockStr()
if tw(t)<W-170 then
PT(W-10,10,st,C_W+F_SML+RGT)
end
end
local function fAct(s)
if s=="Esc"or s=="Back"or s=="No"or s=="Cancel"then return"back"
elseif s=="Exit"then return"quit"
elseif s=="Next"then return"next"
elseif s=="Yes"then return"yes"
elseif s=="Ok"or s=="OK"then return"ok"
elseif s=="Save"then return"save"
elseif s=="Auto"then return"auto"
elseif s=="Add"then return"add"
elseif s=="Del."then return"del"
elseif s=="<"then return"up"
elseif s==">"then return"dn"
elseif s=="Clear"then return"clr"
end
return"msg",s
end
local function drawFBar(labels)
local n=#labels
if n==0 then return end
LINE(0,FB_Y-2,W,FB_Y-2,C_LN)
local slotW=W/n
for i=1,n do
local s=labels[i]
if s and s~=""then
local kx=floor(slotW*(i-1))+4
local kw=floor(slotW)-8
FRAME(kx,FB_Y,kw,FB_BH,C_LN)
FR(kx+1,FB_Y+1,kw-2,2,C_B2)
PT(kx+floor((kw-tw(s))/2),FB_Y+11,s,C_B)
local act,a=fAct(s)
zone(floor(slotW*(i-1)),FB_Y-6,floor(slotW),
H-FB_Y+6,act,a)
end
end
end
local function drawStrip(s)
FR(0,CY,W,1,C_LN)
FR(0,CY+20,W,1,C_LN)
PT(8,CY+3,s,C_DK+F_SML)
return CY+24
end
local function drawList(rows,sel,y0,t)
y0=y0 or CY
local n=#rows
if n==0 then rows={R("-")};n=1 end
sel=clamp(sel,1,n)
local vis=max(1,floor((CB-y0)/ROW_H))
local first=1
if sel>vis then first=sel-vis+1 end
local last=min(n,first+vis-1)
for i=first,last do
local y=y0+(i-first)*ROW_H
LINE(0,y+ROW_H,W,y+ROW_H,C_LN)
end
for i=first,last do
local y=y0+(i-first)*ROW_H
local r=rows[i]
if type(r)~="table"then r=R("-")end
local isSel=(i==sel)
if isSel then
FR(0,y+2,W,BAR_H,C_BL)
FR(0,y+2,4,BAR_H,C_B2)
end
PT(8,y+4,r.l,isSel and C_W or C_B)
if r.arrow then
PT(W-20,y+4,">",isSel and C_W or C_B)
end
if r.v~=nil then
PT(W-8,y+4,r.v,(isSel and C_W or C_B)+RGT)
end
if t then zone(0,y,W,ROW_H,"row",i)end
end
return n
end
local function drawGrid(rows,sel,xs,header,rowH,y0,t)
y0=y0 or CY
local n=#rows
if n==0 then rows={{"#"}};n=1 end
sel=clamp(sel,1,n)
local vis=max(1,floor((CB-y0)/rowH))
if header then vis=vis-1 end
if vis<1 then vis=1 end
local first=1
if sel>vis then first=sel-vis+1 end
local last=min(n,first+vis-1)
local cols=#xs-1
local ry=y0
if header then ry=y0+rowH end
local yEnd=ry+(last-first+1)*rowH
for i=first,last+1 do
local y=ry+(i-first)*rowH
if y<=yEnd+1 then LINE(0,y,xs[#xs],y,C_LN)end
end
for c=1,#xs do
LINE(xs[c],ry,xs[c],yEnd,C_LN)
end
if header then
for c=1,cols do
PT(xs[c]+4,y0+4,header[c]or"",C_GR+F_SML)
end
end
for i=first,last do
local y=ry+(i-first)*rowH
local r=rows[i]
if type(r)~="table"or type(r.cells)~="table"then r={cells={"-"}}end
local isSel=(i==sel)
if isSel then FR(0,y+2,W,rowH-4,C_BL)end
for c=1,cols do
local s=r.cells[c]
if s~=nil then PT(xs[c]+4,y+4,s,(isSel and C_W or C_B)+F_SML)end
end
if t then zone(0,y,W,rowH,"row",i)end
end
return n
end
local msg,msgT=nil,0
showMsg=function(s)msg=s;msgT=120 end
local function drawMsg()
if(msgT or 0)<=0 then return end
FR(W/2-152,108,304,34,C_BL)
PT(W/2-tw(msg)/2,118,msg,C_W)
msgT=msgT-1
end
local GROUPS={
{"Model",{"selmodel","newmodel","basprop","funcs","servoassign",
"servosetup","devexpl"}},
{"Fine Tuning",{"flmodes","digtrim","fmtrim","dratore","fcurves",
"aildiff","gyroset","thrmlim","vtailmix","butterfl",
"snaproll","freemix"}},
{"Advanced Properties",{"othropt","sticsw","wirltrain","logicsw",
"sndonev","sndprop","telemctl","sequenc","accelero"}},
{"Timers/Sensors",{"timers","alarms","vario","voiceout","senlog",
"disptel","mainscr"}},
{"Applications",{"dataanal","audiopl","jetibox","games"}},
{"System",{"config","servorange","viewin","recvout","syssound",
"sndvol","usb","info"}},
}
local TITLES={
selmodel="Select Model",newmodel="New Model",
newconfirm="",
basprop="Basic Properties",funcs="Functions Assignment",
servoassign="Servo Assignment",servosetup="Servo Setup",
devexpl="Device Explorer",flmodes="Flight Modes",
digtrim="Digital Trim",fmtrim="Flight Mode Trim",
dratore="Dual Rate/Expo",fcurves="Function Curves",
aildiff="Aileron Differential",gyroset="Gyro Settings (Heli)",
thrmlim="Throttle Limiter (Heli)",
vtailmix="V-Tail, Delta Mix, Ailevator Mix",
butterfl="Butterfly",snaproll="Snap Roll",
freemix="Free Mixes",othropt="Other Model Options",
sticsw="Sticks/Switches Setup",wirltrain="Wireless Modes/Trainer",
logicsw="Logical Switches",sndonev="Sound on Event",
sndprop="Sound of Prop. Controls",telemctl="Telemetry Controls",
sequenc="Sequencer",accelero="Accelerometer",
timers="Timers",alarms="Alarms",vario="Vario",
voiceout="Voice Output",senlog="Sensors/Logging Setup",
disptel="Displayed Telemetry",mainscr="Main Screen",
dataanal="Data Analyzer",audiopl="Audio Player",
jetibox="JETIBOX",games="Games",
config="Configuration",servorange="Servo & Range Test",
viewin="View Inputs",recvout="Receiver Output",
syssound="System Sound",sndvol="Sound Volume",
usb="USB",info="Info",
}
local FB1={"Esc","","","","Ok"}
local FB_BACK={"Back","","","","Next"}
local FB_NEXT={"","","","","Next"}
local FB_FUNC={"Back","Auto","Add","Del.","Next"}
local FB_SASS={"Back","Auto","","","Next"}
local FB_SET={"(1)","<",">","(*)","OK"}
local FB_NOYES={"No","","","","Yes"}
local KB_FB={"Cancel","","","","Save"}
local FB_SYM={"Sym.","","Apply","","Ok"}
local FB_MAIN={"Exit","Trim G","User","",""}
local FB_HL={"Esc","","(@)","","Ok"}
local FB_BOX={"T1+","","","T1-","Esc"}
local FB_DESK={"Opt","<",">","Start","Clr"}
local FM_MIX={"Back","","","Edit","Next"}
local STATIC={
othropt="Model:|Extended limits: -|Throttle trace: -|Disable warnings: -",
wirltrain="RF mode: Default @|Trainer: -||Caution: disabling TX with a|model attached may cause|a signal loss alarm.",
sequenc="Sequencer 1   -|Sequencer 2   -|Sequencer 3   -|Sequencer 4   -",
audiopl="Track 1   -|Track 2   -|Track 3   -|Player   Stop",
games="Snake   -|Tetris   -|Chess   -|Pong   -",
syssound="Beep sound   -|Wav/voice   -|Background   -",
sndvol="Speaker   -|Beeps   -|Wav/voice   -|Background   -",
usb="Mode   -|Charging   -||Connect cable (charge mode)",
newconfirm="|||Create and activate model?",
}
local MFM=false
local function bSelModel()
return{R(modelName(),nil,nil,nil)}
end
local NM_TYPE=1
local NM_NAME="Glider"
local NM_TYPES={"Aero","Heli","General"}
local WINGS={"0 Flaps  2 Ail","1 Flap  2 Ail","2 Flaps  2 Ail"}
local TAILS={"Normal 1H1V","Normal 2H2V","V-Tail"}
local NM_PROP={wing=1,tail=1,eng=1,air=0,gear=0}
local function drawTypeIcon(k,cx,cy)
cx=floor(cx);cy=floor(cy)
if k==1 then
FR(cx-3,cy-26,6,52,C_B)
FR(cx-38,cy-10,76,9,C_B)
FR(cx-15,cy+20,30,7,C_B)
FR(cx-2,cy+12,4,8,C_B)
elseif k==2 then
FRAME(cx-22,cy-6,30,20,C_B)
LINE(cx-27,cy-18,cx+27,cy-18,C_B)
LINE(cx,cy-18,cx,cy-6,C_B)
LINE(cx+8,cy+2,cx+36,cy+8,C_B)
else
FRAME(cx-26,cy-16,52,36,C_B)
FR(cx-15,cy+2,4,10,C_B)
FR(cx+11,cy+2,4,10,C_B)
LINE(cx+18,cy-16,cx+24,cy-28,C_B)
FRAME(cx-20,cy-12,26,8,C_B)
end
end
local function rowText(y,l,v,on)
if on then
FR(0,y+2,W,BAR_H,C_BL)
FR(0,y+2,4,BAR_H,C_B2)
PT(8,y+4,l,C_W)
if v then PT(W-8,y+4,v,C_W+RGT)end
else
PT(8,y+4,l,C_B)
if v then PT(W-8,y+4,v,C_B+RGT)end
end
end
local function drawNewModel()
local t=top()
local sel=clamp(t.i,1,2)
rowText(CY,"Name:",NM_NAME.." @",sel==1)
zone(0,CY,W,ROW_H,"row",1)
local yl=CY+ROW_H
rowText(yl,"Model type:","",sel==2)
zone(0,yl,W,ROW_H,"row",2)
local yB=yl+ROW_H+24
local bw,gap=118,22
local x0=floor((W-3*bw-2*gap)/2)
for k=1,3 do
local bx=floor(x0+(k-1)*(bw+gap))
local on=(NM_TYPE==k)
if on then
FRAME(bx-2,yB-2,bw+4,90,C_BL)
FR(bx+1,yB+1,bw-2,17,C_BL)
PT(bx+8,yB+3,NM_TYPES[k],C_W)
else
FRAME(bx,yB,bw,86,C_LN)
PT(bx+8,yB+3,NM_TYPES[k],C_B)
end
drawTypeIcon(k,bx+bw/2,yB+52)
zone(bx,yB,bw,86,"type",k)
end
end
local function drawBasProp()
local t=top()
local sel=clamp(t.i,1,5)
local y1=CY
local labels={"Wing type:","Tail type:","Engine count:",
"Airbrake servo:","Gear servos:"}
local values={WINGS[NM_PROP.wing].." @",TAILS[NM_PROP.tail].." @",
NM_PROP.eng.." @",NM_PROP.air.." @",NM_PROP.gear.." @"}
for r=1,5 do
local y=y1+(r-1)*24
rowText(y,labels[r],values[r],r==sel)
zone(0,y,W,24,"row",r)
end
local wx,wy,ww,wh=70,y1+130,W-140,48
FRAME(wx,wy,ww,wh,C_LN)
PT(wx+8,wy+3,"Preview",C_GR+F_SML)
local px,py=wx+floor(ww/2),wy+27
FR(px-1,py-16,3,32,C_B)
FR(px-26,py-4,52,8,C_B)
FR(px-8,py+13,16,4,C_B)
if NM_PROP.wing>=2 then FR(px+6,py-2,18,4,C_B2)end
if NM_PROP.wing>=3 then FR(px-24,py-2,18,4,C_B2)end
end
local function bBasProp()
return{R("Wing type:"),R("Tail type:"),R("Engine count:"),
R("Airbrake servo:"),R("Gear servos:")}
end
local NEXT_OF={
newmodel="basprop",basprop="funcs",
funcs="servoassign",servoassign="servosetup",
servosetup="newconfirm"}
local function doCreate()
local nm=(NM_NAME~="")and NM_NAME or"Glider"
local done=false
if type(model.createModel)=="function"then
done=pc(model.createModel,60,nm)
end
if done then
showMsg("Model "..nm.." created")
ui.stack[#ui.stack+1]={k="scr",id="servosetup",i=1}
cache.key=""
else
showMsg("fw 2.7.x: use MDL button")
end
end
local KB={buf="Glider"}
local KB_ROWS={
{"A","B","C","D","E","F","G","H","I","J"},
{"K","L","M","N","O","P","Q","R","S","T"},
{"U","V","W","X","Y","Z","0","1","2","3"},
{"4","5","6","7","8","9","-","_","Del","OK"},
}
kbKey=function(k)
if k=="Del"then
local b=KB.buf or""
KB.buf=ssub(b,1,#b-1)
elseif k=="OK"then
if kbSave then kbSave()end
elseif type(k)=="string"and#k==1 then
if#(KB.buf or"")<10 then KB.buf=(KB.buf or"")..k end
end
end
kbSave=function()
NM_NAME=(KB.buf~=nil and KB.buf~="")and KB.buf or"Glider"
if pop then pop()end
if showMsg then showMsg("Name: "..NM_NAME)end
end
local function drawKeyboard()
local t=top()
PT(10,CY,"Name:",C_B)
FRAME(70,CY-2,W-140,26,C_LN)
PT(78,CY+2,KB.buf or"",C_B)
local cx=78+tw(KB.buf or"")
LINE(cx+2,CY+2,cx+2,CY+20,C_BL)
local gy=CY+36
local cw,ch=floor((W-60)/10),34
for r=1,4 do
for c=1,10 do
local kx=30+(c-1)*cw
local ky=gy+(r-1)*ch
local k=KB_ROWS[r][c]
local on=(t.r==r and t.c==c)
if on then
FR(kx+1,ky+1,cw-2,ch-2,C_BL)
PT(kx+cw/2-tw(k)/2,ky+8,k,C_W)
else
FRAME(kx+1,ky+1,cw-2,ch-2,C_LN)
PT(kx+cw/2-tw(k)/2,ky+8,k,C_B)
end
zone(kx,ky,cw,ch,"kbkey",k)
end
end
end
local function bNmRows()
return{R("Name:"),R("Model type:")}
end
local function nmEnt()
local t=top()
if t and t.i==1 then
KB.buf=NM_NAME
ui.stack[#ui.stack+1]={k="kb",r=1,c=1}
else
NM_TYPE=(NM_TYPE%3)+1
end
end
local function drawPlane(cx,cy,fl,tl)
FR(cx-1,cy-42,3,2,C_B)
FR(cx-2,cy-40,5,80,C_B)
FR(cx-45,cy-12,91,12,C_B)
FR(cx-44,cy-12,12,3,C_B2)
FR(cx+33,cy-12,12,3,C_B2)
if tl==3 then
FR(cx-4,cy+26,5,4,C_B)
FR(cx-9,cy+29,5,4,C_B)
FR(cx-14,cy+32,5,4,C_B)
FR(cx-1,cy+26,5,4,C_B)
FR(cx+4,cy+29,5,4,C_B)
FR(cx+9,cy+32,5,4,C_B)
elseif tl==2 then
FR(cx-17,cy+28,13,8,C_B)
FR(cx+5,cy+28,13,8,C_B)
else
FR(cx-16,cy+28,33,8,C_B)
end
if fl>=1 then FR(cx+6,cy,26,5,C_B2)end
if fl>=2 then FR(cx-31,cy,26,5,C_B2)end
end
local function drawPick()
local t=top()
local list=(t.what=="wing")and WINGS or TAILS
local fl=(t.what=="wing")and(t.i-1)or 0
local tl=(t.what=="wing")and 1 or t.i
local cw,gap=146,8
local x0=floor((W-3*cw-2*gap)/2)
local y0=56
for k=1,3 do
local x=x0+(k-1)*(cw+gap)
if k==t.i then
FRAME(x-2,y0-2,cw+4,146,C_BL)
FRAME(x,y0,cw,142,C_LN)
else
FRAME(x,y0,cw,142,C_LN)
end
drawPlane(x+floor(cw/2),y0+54,fl,tl)
local ly=y0+114
if k==t.i then
FR(x+1,ly,cw-2,24,C_BL)
PT(x+floor((cw-tw(list[k]))/2),ly+5,list[k],C_W)
else
PT(x+floor((cw-tw(list[k]))/2),ly+5,list[k],C_B)
end
zone(x,y0,cw,142,"pick",k)
end
end
local function bpEnt()
local t=top()
local i=t and t.i or 1
if i==1 then
ui.stack[#ui.stack+1]={k="pick",what="wing",i=NM_PROP.wing}
cache.key=""
elseif i==2 then
ui.stack[#ui.stack+1]={k="pick",what="tail",i=NM_PROP.tail}
cache.key=""
elseif i==3 then NM_PROP.eng=(NM_PROP.eng+1)%3
elseif i==4 then NM_PROP.air=(NM_PROP.air+1)%3
else NM_PROP.gear=(NM_PROP.gear+1)%3 end
end
local function ncEnt()
if actYes then actYes()end
end
local FN={{"1","none / no API","-","-","-"}}
local FN_NAMES={"Aileron","Elevator","Throttle","Rudder",
"Flap","Gear"}
local FUNC_LOCAL=false
fAdd=function()
if FN[1][2]=="none / no API"and#FN==1 then
FN[1]={"1",FN_NAMES[1],"P1","-","-"}
else
local k=#FN
if k<16 then
FN[k+1]={tos(k+1),FN_NAMES[(k%#FN_NAMES)+1],"-","-","-"}
end
end
cache.key=""
end
fDel=function(cur)
if FN[1][2]=="none / no API"and#FN==1 then return end
local k=clamp(cur or#FN,1,#FN)
if#FN==1 then
FN[1]={"1","none / no API","-","-","-"}
else
table.remove(FN,k)
for j=1,#FN do FN[j][1]=tos(j)end
end
cache.key=""
end
local function bFuncs()
local rows,i={},0
for idx=0,31 do
local ok,inp=pc(model.getInputs,idx)
if not ok or inp==nil then break end
i=i+1
rows[#rows+1]={cells={tos(i),txt(inp.name),
srcName(inp.source).." w"..txt(inp.weight),"-","-"}}
if i>=VIS+4 then break end
end
FUNC_LOCAL=(i==0)
if FUNC_LOCAL then
rows={}
for k=1,#FN do rows[k]={cells=FN[k]}end
end
if#rows==0 then rows[1]={cells={"1","none / no API","-","-","-"}}end
return rows
end
local function fEnt()
local t=top()
if not FUNC_LOCAL then showMsg("assigned in EdgeTX")return end
local r=FN[t.i]
if not r then return end
local C={"-","P1","P2","P3","P4"}
local k=1
for j=1,#C do if C[j]==r[3]then k=j end end
r[3]=C[k%#C+1]
cache.key=""
end
local SNAMES={"Ail","Ele","Thr","Rud","CH5","CH6","CH7","CH8",
"CH9","CH10","CH11","CH12","CH13","CH14","CH15","CH16"}
local function outName(i)
local ok,o=pc(model.getOutput,i)
if ok and o and o.name and tos(o.name)~=""then
return tos(o.name)
end
return SNAMES[i+1]or"CH"..(i+1)
end
local function bServoAssign()
local rows={}
for ch=0,6 do
rows[#rows+1]={cells={tos(ch+1),outName(ch).." @",
tos(ch+8),outName(ch+7).." @"}}
end
return rows
end
local SERVO_SEL=0
local SSED={}
local function stripServo()
return"Servo No:  "..outName(SERVO_SEL).."  ("..(SERVO_SEL+1)..
")  "..(SERVO_SEL+1).."/16"
end
local function bServoSetup()
local ok,o=pc(model.getOutput,SERVO_SEL)
if not(ok and o)then
return{R("Center (Subtrim)","-"),R("Max. positive","-"),
R("Max. negative","-")}
end
local rev="No @"
if o.revert==1 or o.revert==true then rev="Yes @"end
local off=SSED.off or o.offset or 0
local mx=SSED.mx or o.max or 1000
local mn=SSED.mn or o.min or -1000
return{
R("Center (Subtrim)",txt(off),clamp(0.5+off/2048,0,1),nil,true),
R("Max. positive",txt(mx).."%",clamp(0.5+mx/2000,0,1),nil,true),
R("Max. negative",txt(mn).."%",clamp(0.5+mn/2000,0,1),nil,true),
R("Max. positive limit","125%",0.625,nil,true),
R("Max. negative limit","-125%",0.375,nil,true),
R("Reverse",rev),
R("Delay positive/negative","0.0s  0.0s"),
}
end
ssAdj=function(i,d)
local ok,o=pc(model.getOutput,SERVO_SEL)
o=(ok and o)or{}
if i==1 then
SSED.off=clamp((SSED.off or o.offset or 0)+d*10,-500,500)
elseif i==2 or i==4 then
SSED.mx=clamp((SSED.mx or o.max or 1000)+d*(i==2 and 50 or 10),0,2000)
elseif i==3 or i==5 then
SSED.mn=clamp((SSED.mn or o.min or -1000)+d*(i==3 and 50 or 10),-2000,0)
end
cache.key=""
end
local function bFlModes()
if not MFM then
return{R("FM0","-",nil,true),R("FM1","-",nil,true),
R("FM2","-",nil,true)}
end
local rows={}
for i=0,8 do
local ok,fm=pc(model.getFlightMode,i)
if not ok or fm==nil then break end
rows[#rows+1]=R("FM"..i.." "..txt(fm.name),
swName(fm.switch),nil,true)
end
return rows
end
local function trimRow(idx)
local ok,v=pc(getTrimValue,0,idx)
if ok and type(v)=="number"then
return R("Trim "..(idx+1),txt(v),clamp((v+512)/1024,0,1))
end
return R("Trim "..(idx+1),"-")
end
local function bDigTrim()
return{trimRow(0),trimRow(1),trimRow(2),trimRow(3)}
end
local function bDratore()
local rows,n={},0
for idx=0,31 do
local ok,inp=pc(model.getInputs,idx)
if not ok or inp==nil then break end
n=n+1
rows[#rows+1]=R(txt(inp.name),
srcName(inp.source).." w"..txt(inp.weight),nil,true)
if n>=VIS+6 then break end
end
if n==0 then rows[1]=R("none / no API")end
return rows
end
local CURVE_SEL=0
local function bFCurves()
local rows,n={},0
for i=0,31 do
local ok,c=pc(model.getCurve,i)
if not ok or c==nil then break end
n=n+1
local mark=(i==CURVE_SEL)and"> "or""
rows[#rows+1]=R(mark.."CV"..(i+1).." "..txt(c.name),
txt(c.points).." pts")
if n>=3 then break end
end
if n==0 then rows[1]=R("no curves")end
return rows
end
local function bAilDiff()
return{R("Ailerons",livePctStr("ail")),R("Differential","0%")}
end
local function bGyroSet()
return{R("Gyro gain","-"),R("Heading hold","-")}
end
local function bThrmLim()
return{R("Throttle",livePctStr("thr")),R("Limiter","OFF")}
end
local function bVtailMix()
return{R("Elevator",livePctStr("ele")),R("Rudder",livePctStr("rud"))}
end
local function drawButterfl()
local xs={0,150,250,340,470}
local hdr={"Control","Offset","Delay","Mode"}
local rows={
{cells={"P2","15%","0.5s","@"}},
}
drawGrid(rows,0,xs,hdr,24,CY)
local y=CY+2*24+10
PT(8,y,"Ailerons/Flaps Adjustment",C_B)
PT(W-20,y,">",C_B)
PT(8,y+24,"Elevator Adjustment",C_B)
PT(W-20,y+24,">",C_B)
PT(8,y+48,"Timing",C_B)
PT(W-20,y+48,">",C_B)
end
local function bSnaproll()
return{R("Ailerons",livePctStr("ail")),R("Elevator",livePctStr("ele")),
R("Rudder",livePctStr("rud")),R("Mode","OFF")}
end
local function bFreemix()
local rows,any={},false
for ch=0,15 do
for line=0,15 do
local ok,m=pc(model.getMix,ch,line)
if not ok or m==nil then break end
any=true
rows[#rows+1]=R("CH"..(ch+1).." "..txt(m.name),
srcName(m.source).." w"..txt(m.weight),nil,true)
if#rows>=VIS+8 then break end
end
if#rows>=VIS+8 then break end
end
if not any then rows[1]=R("none")end
return rows
end
local STIC_SEL=1
local function stripStic()
local c=CTRL[STIC_SEL]or CTRL[1]
return"Control No:  "..c[1].." @   "..STIC_SEL.."/"..#CTRL
end
local function bSticsw()
local c=CTRL[STIC_SEL]or CTRL[1]
local ok,v=pc(getValue,c[2])
local p=(ok and type(v)=="number")and pct(v)or nil
local ctype="Switch"
if STIC_SEL<=4 then ctype="2-Axis Stick"
elseif STIC_SEL>=17 then ctype="Trim"end
return{
R("Type of control",ctype),
R("Position",(p==nil)and"-"or(p.."%"),
(p~=nil)and clamp(p/100*0.5+0.5,0,1)or nil),
R("Switch On",(p and p>60)and"yes"or"-"),
R("Switch Off",(p and p<-60)and"yes"or"-"),
R("Required pre-fl. pos","None @"),
}
end
local function bLogicsw()
local rows={}
for i=0,63 do
local ok,ls=pc(model.getLogicalSwitch,i)
if not ok or ls==nil then break end
if(ls.func or 0)~=0 then
local ok2,st=pc(model.getLogicalSwitchValue,i)
local mark=(st==true)and"[x]"or(st==false)and"[ ]"or"[ ]"
rows[#rows+1]=R("L"..(i+1).." "..mark,
"f"..txt(ls.func).." "..txt(ls.v1).." "..txt(ls.v2),nil,true)
if#rows>=VIS+8 then break end
end
end
if#rows==0 then rows[1]=R("none defined")end
return rows
end
local function sfRows()
local rows={}
for i=0,63 do
local ok,sf=pc(model.getCustomFunction,i)
if not ok or sf==nil then break end
if(sf.switch or 0)~=0 then
rows[#rows+1]=R("SF"..(i+1).."  "..swName(sf.switch),
"fn"..txt(sf.func).." "..txt(sf.value),nil,true)
if#rows>=VIS+8 then break end
end
end
if#rows==0 then rows[1]=R("(none active)","-")end
return rows
end
local function bAccelero()
local rows={}
for i,key in ipairs({"acc1","acc2","acc3"})do
local ok,v=pc(getValue,key)
if ok and type(v)=="number"then
local g=floor(v*100+0.5)/100
rows[#rows+1]=R("Axis "..i,g.." g")
end
end
if#rows==0 then rows[1]=R("Accelerometer","-")end
return rows
end
local function bTimers()
local rows={}
for i=0,2 do
local ok,t=pc(model.getTimer,i)
if not ok or t==nil then break end
rows[#rows+1]=R("Timer "..(i+1),fmtTime10(t.value),
clamp((t.value or 0)/600000,0,1))
rows[#rows+1]=R("  start / mode",
fmtTime10(t.start or 0).." "..swName(t.sw or 0))
end
if#rows==0 then rows[1]=R("Timers","no API")end
return rows
end
local function bAlarms()
local v=txVolts()
local r=rssiVal()
return{
R("Battery",(v and(oneDec(v).."V"))or"-",
v and clamp((v-6.0)/2.4,0,1)or nil),
R("  low batt alarm",(v and v<6.6)and"ACTIVE"or"-"),
R("RSSI",(r and(txt(r).."dB"))or"-",
r and clamp(r/100,0,1)or nil),
R("  signal alarm",(r and r<45)and"ACTIVE"or"-"),
}
end
local function bVario()
local v=sensorLive("vario")or sensorLive("Vario")
return{
R("Vario",(v and oneDec(v).." m/s")or"-"),
R("Altitude",txt(sensorLive("Alt")or sensorLive("Altitude")or"-")),
}
end
local function bSenLog()
local rows={}
for i=0,31 do
local ok,s=pc(model.getSensor,i)
if not ok or s==nil then break end
local live=sensorLive(s.name)
rows[#rows+1]=R(txt(s.name),
"id"..txt(s.id).."  "..(live and txt(live)or"-"),nil,true)
if#rows>=VIS+4 then break end
end
if#rows==0 then rows[1]=R("no sensors")end
return rows
end
local function bDisptel()
local rows={}
for i=0,31 do
local ok,s=pc(model.getSensor,i)
if not ok or s==nil then break end
local live=sensorLive(s.name)
rows[#rows+1]=R(txt(s.name),live and txt(live)or"-")
if#rows>=VIS+2 then break end
end
local v=txVolts()
if v then rows[#rows+1]=R("Tx battery",oneDec(v).."V")end
local r=rssiVal()
if r then rows[#rows+1]=R("RSSI",txt(r).."dB")end
if#rows==0 then rows[1]=R("no sensors")end
return rows
end
local function drawMainScreen()
local cy=CY+14
PT(W/2-tw("JETI model")*2/2,cy,"JETI model",C_B+F_DBL)
PT(W/2-tw("TX16S")*2/2,cy+40,"TX16S",C_B+F_DBL)
local ok,t1=pc(model.getTimer,0)
local tv=(ok and t1)and fmtTime10(t1.value)or"-"
PT(W/2-tw("Timer "..tv)/2,cy+86,"Timer "..tv,C_B)
local bv=txVolts()
local bstr="Battery "..(bv and(oneDec(bv).."V")or"-")
PT(W/2-tw(bstr)/2,cy+114,bstr,C_B)
end
local DA={rows={}}
local DA_SERIES={{"Tx batt","tx-voltage"},{"RSSI","RSSI"},{"S1","s1"}}
local function bDataanal()
local ok,now=pc(getTime)
now=(ok and type(now)=="number")and now or 0
for i=1,#DA_SERIES do
local d=DA.rows[i]
if d==nil then d={min=nil,max=nil,sum=0,n=0};DA.rows[i]=d end
local ok2,v=pc(getValue,DA_SERIES[i][2])
if ok2 and type(v)=="number"then
d.min=(d.min==nil)and v or min(d.min,v)
d.max=(d.max==nil)and v or max(d.max,v)
d.sum=d.sum+v
d.n=d.n+1
end
end
local rows={}
for i=1,#DA_SERIES do
local d=DA.rows[i]
if d and d.n>0 then
local avg=floor(d.sum/d.n*100+0.5)/100
local mn=floor(d.min*100+0.5)/100
local mx=floor(d.max*100+0.5)/100
rows[i]=R(DA_SERIES[i][1],"min "..mn.." max "..mx.." avg "..avg)
else
rows[i]=R(DA_SERIES[i][1],"-")
end
end
return rows
end
local function drawJetibox()
local ok,t1=pc(model.getTimer,0)
local v=txVolts()
local r=rssiVal()
local bx,by,bw,bh=60,CY+12,W-120,CB-CY-30
FRAME(bx,by,bw,bh,C_BL)
FRAME(bx+4,by+4,bw-8,bh-8,C_LN)
local l1=padR("Battery: "..(v and(oneDec(v).."V")or"-"),24)
local l2=padR("RSSI: "..(r and(r.."dB")or"-")..
" T: "..((ok and t1)and fmtTime10(t1.value)or"-"),24)
PT(bx+12,by+16,l1,C_B+F_SML)
PT(bx+12,by+34,l2,C_B+F_SML)
PT(bx+12,by+bh-24,padR("JETIBOX emulation",24),C_B+F_SML)
end
local function bConfig()
local ok,ver=pc(getVersion)
local v=txVolts()
return{
R("Radio FW",(ok and ver)and txt(ver)or"-"),
R("Mode 1-4","-"),
R("Battery",(v and(oneDec(v).."V"))or"-"),
R("Clock",clockStr()),
R("Screen",W.."x"..H),
}
end
local function bServorange()
local rows={}
for i=0,7 do
local p=chanLive(i)or 0
rows[#rows+1]=R("CH"..(i+1),p.."%",clamp(p/100*0.5+0.5,0,1))
end
return rows
end
local function bViewin()
local rows={}
for i=1,#CTRL do
local c=CTRL[i]
local ok,v=pc(getValue,c[2])
local p=(ok and type(v)=="number")and pct(v)or nil
rows[#rows+1]=R(c[1],(p==nil)and"-"or(p.."%"),
(p~=nil)and clamp(p/100*0.5+0.5,0,1)or nil)
end
return rows
end
local function bRecvout()
local rows={}
for i=0,15 do
local ok,o=pc(model.getOutput,i)
local p=chanLive(i)
rows[#rows+1]=R("CH"..(i+1).." "..txt((ok and o)and o.name or""),
(p==nil)and"-"or(p.."%"),
(p~=nil)and clamp(p/100*0.5+0.5,0,1)or nil)
end
return rows
end
local function bInfo()
local ok,ver=pc(getVersion)
return{
R("JetiTX","v13.0"),
R("Menu replica of","JETI DC/DS-16"),
R("Manual","DC-DS-EN-2014 FW3.00"),
R("Radio FW",(ok and ver)and txt(ver)or"-"),
}
end
local REG={}
local function staticBuilder(id)
return function()
local rows={}
local s=STATIC[id]or""
local start=1
while start<=#s+1 do
local p=sfind(s,"|",start,true)
local part
if p then part=ssub(s,start,p-1)else part=ssub(s,start)end
if part==""then part=" "end
rows[#rows+1]=R(part)
if not p then break end
start=p+1
end
return rows
end
end
local function def(id,kind,b,fbar,draw,onEnt,strip,xs,hdr)
REG[id]={kind=kind,b=b or staticBuilder(id),fbar=fbar or FB1,
draw=draw,onEnt=onEnt,strip=strip,xs=xs,hdr=hdr}
end
def("selmodel","list",bSelModel,FB1,nil,
function()showMsg("Model: "..modelName())end)
def("newmodel","custom",bNmRows,FB_NEXT,drawNewModel,nmEnt)
def("basprop","custom",bBasProp,FB_BACK,drawBasProp,bpEnt)
def("newconfirm","text",nil,FB_NOYES,nil,ncEnt)
def("funcs","grid",bFuncs,FB_FUNC,nil,fEnt,
nil,{0,26,190,300,380,470},nil)
def("servoassign","grid",bServoAssign,FB_SASS,nil,
function()
local t=top()
SERVO_SEL=(t.i<=7)and(t.i-1)or(t.i+6)
if SERVO_SEL>15 then SERVO_SEL=15 end
SSED={}
ui.stack[#ui.stack+1]={k="scr",id="servosetup",i=1}
cache.key=""
end,nil,{0,26,240,266,470},nil)
def("servosetup","fields",bServoSetup,FB_SET,nil,
function()
local t=top()
if t.i and t.i<=5 then t.edit=t.i
else showMsg("wheel = change value, key = Ok")end
end,stripServo)
def("devexpl","list",bSenLog,FB1)
def("flmodes","list",bFlModes,FB_HL)
def("digtrim","fields",bDigTrim,FB1)
def("fmtrim","fields",bDigTrim,FB1)
def("dratore","list",bDratore,FB1)
def("fcurves","list",bFCurves,FB1,nil,
function()CURVE_SEL=(CURVE_SEL+1)%32 end)
def("aildiff","fields",bAilDiff,FB_BACK)
def("gyroset","fields",bGyroSet,FB_BACK)
def("thrmlim","fields",bThrmLim,FB_BACK)
def("vtailmix","fields",bVtailMix,FB_BACK)
def("butterfl","custom",nil,FB_SYM,drawButterfl)
def("snaproll","fields",bSnaproll,FB_BACK)
def("freemix","list",bFreemix,FM_MIX)
def("othropt","text",nil,FB_BACK)
def("sticsw","fields",bSticsw,FB_SET,nil,
function()STIC_SEL=(STIC_SEL%#CTRL)+1 end,stripStic)
def("wirltrain","text",nil,FB_BACK)
def("logicsw","list",bLogicsw,FB1)
def("sndonev","list",sfRows,FB_BACK)
def("sndprop","list",sfRows,FB_BACK)
def("telemctl","list",sfRows,FB_BACK)
def("sequenc","text",nil,FB_BACK)
def("accelero","fields",bAccelero,FB_BACK)
def("timers","fields",bTimers,FB_BACK)
def("alarms","fields",bAlarms,FB_BACK)
def("vario","fields",bVario,FB_BACK)
def("voiceout","list",sfRows,FB_BACK)
def("senlog","list",bSenLog,FB_BACK)
def("disptel","fields",bDisptel,FB_BACK)
def("mainscr","custom",bDisptel,FB_DESK,drawMainScreen)
def("dataanal","fields",bDataanal,{"Back","","","","Clear"},nil,
function()DA={rows={}};showMsg("Data Analyzer reset")end)
def("audiopl","text",nil,FB_BACK)
def("jetibox","custom",nil,FB_BOX,drawJetibox)
def("games","text",nil,FB_BACK)
def("config","fields",bConfig,FB_BACK)
def("servorange","fields",bServorange,FB_BACK)
def("viewin","fields",bViewin,FB_BACK)
def("recvout","fields",bRecvout,FB_BACK)
def("syssound","text",nil,FB_BACK)
def("sndvol","text",nil,FB_BACK)
def("usb","text",nil,FB_BACK)
def("info","fields",bInfo,FB_BACK)
pop=function()
if#ui.stack>1 then
ui.stack[#ui.stack]=nil
cache.key=""
end
end
local function rowsFor(t)
local s=REG[t.id]
if not s then return{R("(missing screen)","-")}end
return cachedRows(t.id,s.b)
end
entOn=function(t)
if not t then return end
if t.k=="main"then
ui.stack[#ui.stack+1]={k="group",g=t.i,i=1}
cache.key=""
elseif t.k=="group"then
local g=GROUPS[t.g]
if g then
ui.stack[#ui.stack+1]=
{k="scr",id=g[2][clamp(t.i,1,#g[2])],i=1}
cache.key=""
end
else
local s=REG[t.id]
if s and s.onEnt then s.onEnt()end
end
end
actOk=function()
if entOn then entOn(top())end
end
actNext=function()
local t=top()
local nxt=t and NEXT_OF[t.id]
if nxt then
ui.stack[#ui.stack+1]={k="scr",id=nxt,i=1}
cache.key=""
end
end
actYes=function()
doCreate()
end
local function frame(ev)
local t=top()
if t.k=="kb"then
if ev==E_NEXT or ev==E_NEXTR then
t.c=t.c+1
if t.c>10 then t.c=1;t.r=(t.r%4)+1 end
elseif ev==E_PREV or ev==E_PREVR then
t.c=t.c-1
if t.c<1 then t.c=10;t.r=(t.r-2)%4+1 end
elseif ev==E_ENT or ev==E_ENTL then
if kbKey then kbKey(KB_ROWS[t.r][t.c])end
elseif ev==E_BACK then
pop()
end
return 0
end
if t.k=="pick"then
if ev==E_NEXT or ev==E_NEXTR then t.i=(t.i%3)+1
elseif ev==E_PREV or ev==E_PREVR then t.i=(t.i-2)%3+1
elseif ev==E_ENT or ev==E_ENTL then
if t.what=="wing"then NM_PROP.wing=t.i else NM_PROP.tail=t.i end
cache.key=""
pop()
elseif ev==E_BACK then
pop()
end
return 0
end
if t.k=="main"then
if ev==E_NEXT or ev==E_NEXTR then t.i=(t.i%#GROUPS)+1
elseif ev==E_PREV or ev==E_PREVR then t.i=(t.i-2)%#GROUPS+1
elseif ev==E_ENT or ev==E_ENTL then
entOn(t)
elseif ev==E_BACK then
QUIT=true
end
return 0
end
if t.k=="group"then
local g=GROUPS[t.g]
if not g then pop();return 0 end
if ev==E_NEXT or ev==E_NEXTR then t.i=(t.i%#g[2])+1
elseif ev==E_PREV or ev==E_PREVR then t.i=(t.i-2)%#g[2]+1
elseif ev==E_ENT or ev==E_ENTL then
entOn(t)
elseif ev==E_BACK then
pop()
end
return 0
end
local s=REG[t.id]
if not s then pop();return 0 end
if t.edit then
if ev==E_NEXT or ev==E_NEXTR then
if ssAdj then ssAdj(t.edit,1)end
elseif ev==E_PREV or ev==E_PREVR then
if ssAdj then ssAdj(t.edit,-1)end
else
t.edit=nil
cache.key=""
end
return 0
end
local n=#rowsFor(t)
if ev==E_NEXT or ev==E_NEXTR then
t.i=clamp(t.i+1,1,max(n,1))
elseif ev==E_PREV or ev==E_PREVR then
t.i=clamp(t.i-1,1,max(n,1))
elseif ev==E_ENT or ev==E_ENTL then
if s.onEnt then s.onEnt()end
elseif ev==E_BACK then
pop()
elseif ev==E_NEXTPG then
if actNext then actNext()end
end
return 0
end
local function paint()
TZONES={}
CLEAR()
local t=top()
if t.k=="kb"then
drawTopBar("Model Name")
drawKeyboard()
drawFBar(KB_FB)
elseif t.k=="pick"then
drawTopBar(t.what=="wing"and"Wing Type"or"Tail Type")
drawPick()
drawFBar(FB1)
elseif t.k=="main"then
drawTopBar("Main Menu")
local rows={}
for i=1,#GROUPS do rows[i]=R(GROUPS[i][1])end
drawList(rows,t.i,nil,t)
drawFBar(FB_MAIN)
elseif t.k=="group"then
local g=GROUPS[t.g]
drawTopBar(g and g[1]or"?")
local rows={}
if g then
for i=1,#g[2]do rows[i]=R(TITLES[g[2][i]]or g[2][i])end
end
drawList(rows,t.i,nil,t)
drawFBar(FB1)
else
local s=REG[t.id]
if not s then pop();return end
local rows=rowsFor(t)
drawTopBar(TITLES[t.id]or t.id or"?")
local y0=CY
if s.strip then y0=drawStrip(s.strip())end
if s.kind=="grid"then
local xs=s.xs or{0,26,190,300,380,470}
drawGrid(rows,t.i,xs,s.hdr,24,y0,t)
elseif s.kind=="fields"then
drawList(rows,t.i,y0,t)
if t.edit then
FR(W/2-82,116,164,30,C_BL)
PT(W/2-tw("OK")/2,124,"OK",C_W)
end
elseif s.kind=="text"then
drawList(rows,t.i,y0,t)
elseif s.kind=="custom"then
if s.draw then s.draw()end
else
drawList(rows,t.i,y0,t)
end
if s.kind~="custom"and s.draw then s.draw()end
drawFBar(s.fbar)
end
drawMsg()
end
local function errorPaint(what)
CLEAR()
FR(0,0,W,30,C_RD)
lcd.drawText(10,6,"JetiTX error v13.0",C_W+F_MID)
local m=txt(what)
if#m>50 then m=ssub(m,1,50)end
PT(8,44,m,C_B)
PT(8,72,"EXIT=quit PAGE<=back touch=on",C_B+F_SML)
PT(8,H-22,"photo this screen, send to chat",C_B+F_SML)
end
local function hitZone(x,y)
for i=1,#TZONES do
local z=TZONES[i]
if x>=z.x and x<z.x+z.w and y>=z.y and y<z.y+z.h then
return z
end
end
return nil
end
local function doZone(z)
if not z then return end
local a=z.a
if z.act=="back"then
if pop then pop()end
elseif z.act=="quit"then
QUIT=true
elseif z.act=="next"then
if actNext then actNext()end
elseif z.act=="yes"then
if actYes then actYes()end
elseif z.act=="ok"then
if actOk then actOk()end
elseif z.act=="save"then
if kbSave then kbSave()end
elseif z.act=="kbkey"then
if kbKey then kbKey(a)end
elseif z.act=="row"then
local t=top()
if t then
if t.i==a then
if entOn then entOn(t)end
else
t.i=a
end
end
elseif z.act=="type"then
local t=top()
NM_TYPE=a or 1
if t then t.i=2 end
elseif z.act=="pick"then
local t=top()
if t and t.k=="pick"then
if t.what=="wing"then NM_PROP.wing=z.a or 1
else NM_PROP.tail=z.a or 1 end
cache.key=""
if pop then pop()end
end
elseif z.act=="auto"then
if showMsg then showMsg("Auto: not supported (API)")end
elseif z.act=="add"or z.act=="del"then
local t=top()
if t and t.id=="funcs"and fAdd then
if z.act=="add"then fAdd()else fDel(t.i)end
elseif showMsg then showMsg("not supported (API)")end
elseif z.act=="up"then
if scrollList then scrollList(-1)end
elseif z.act=="dn"then
if scrollList then scrollList(1)end
elseif z.act=="clr"then
DA.rows={}
if showMsg then showMsg("Data Analyzer reset")end
else
if showMsg then showMsg(a)end
end
end
local function touchActivate(x,y)
local ok,now=pc(getTime)
now=(ok and type(now)=="number")and now or 0
if now-TACT_T<15 and abs(x-TACT_X)<24 and
abs(y-TACT_Y)<24 then return end
local z=hitZone(x,y)
if z then
TACT_T,TACT_X,TACT_Y=now,x,y
doZone(z)
end
end
scrollList=function(dir)
local t=top()
if not t then return end
if t.k=="main"then
t.i=(t.i-1+dir+#GROUPS)%#GROUPS+1
elseif t.k=="group"then
local g=GROUPS[t.g]
if g then t.i=(t.i-1+dir+#g[2])%#g[2]+1 end
else
local s=REG[t.id]
if not s then return end
local n=#rowsFor(t)
if n>0 then t.i=clamp(t.i+dir,1,n)end
end
end
local function touchFrame(ev,ts)
local x=tonumber(ts.x)or 0
local y=tonumber(ts.y)or 0
if ev==T_BREAK or ev==T_TAP then
TSCROLL=0
touchActivate(x,y)
elseif ev==T_SLIDE then
local sy=tonumber(ts.slideY)or 0
if sy~=sy then sy=0 end
TSCROLL=TSCROLL+sy
if TSCROLL>260 then TSCROLL=260 end
if TSCROLL<-260 then TSCROLL=-260 end
while TSCROLL>=ROW_H do
scrollList(-1);TSCROLL=TSCROLL-ROW_H
end
while TSCROLL<=-ROW_H do
scrollList(1);TSCROLL=TSCROLL+ROW_H
end
end
end
local ERRN=0
local function run(event,touchState)
if QUIT then return 2 end
event=tonumber(event)or 0
local okn,now=pc(getTime)
now=(okn and type(now)=="number")and now or 0
if event~=0 then IDLET=now;IDLEMSG=false end
if event==E_EXIT then
QUIT=true
return 2
end
if T_FIRST and type(touchState)=="table"and
(event==T_BREAK or event==T_TAP or event==T_SLIDE or
event==T_FIRST)then
local ok,err=pc(touchFrame,event,touchState)
if not ok then
ERRN=ERRN+1
pc(errorPaint,err)
if ERRN>20 then return 2 end
return 0
end
end
local ok,res=pc(frame,event)
if not ok then
ERRN=ERRN+1
pc(errorPaint,res)
if ERRN>20 then return 2 end
return 0
end
if not pc(paint)then
ERRN=ERRN+1
pc(errorPaint,"paint error")
if ERRN>20 then return 2 end
else
ERRN=0
end
if not QUIT and now-IDLET>18000 then
QUIT=true
elseif not QUIT and now-IDLET>16500 and not IDLEMSG then
IDLEMSG=true
showMsg("Auto exit: press any key")
end
if QUIT then return 2 end
return 0
end
RUN=run
do local ok0,t0=pc(getTime)
if ok0 and type(t0)=="number"then IDLET=t0 end end
MFM=(type(model.getFlightMode)=="function")
end)
if not OKL or type(RUN)~="function"then
local m=tos(LOADERR or"load failed")
local EVX=EVT_VIRTUAL_EXIT or-7
RUN=function(ev)
if tonumber(ev)==EVX then return 2 end
pc(lcd.drawFilledRectangle,0,0,LCD_W or 480,LCD_H or 272,
SOLID or 0)
pc(lcd.drawText,6,6," JetiTX LOAD ERROR - photo this ",
(MIDSIZE or 0)+(INVERS or 0))
pc(lcd.drawText,8,36,m,(INVERS or 0))
return 0
end
end
return{run=RUN}
