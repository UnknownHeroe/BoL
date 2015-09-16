local Version = 2.00

class 'ScriptUpdate'
class 'HTTF_Viktor'

function Custom(msg) PrintChat("<font color=\"#daa520\"><b>[Support Heroes]</b></font> <font color=\"#FFFFFF\">"..msg.."</font>")
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function ScriptUpdate:__init(LocalVersion,UseHttps, Host, VersionPath, ScriptPath, SavePath, CallbackUpdate, CallbackNoUpdate, CallbackNewVersion,CallbackError)
  self.LocalVersion = LocalVersion
  self.Host = Host
  self.VersionPath = '/BoL/TCPUpdater/GetScript'..(UseHttps and '5' or '6')..'.php?script='..self:Base64Encode(self.Host..VersionPath)..'&rand='..math.random(99999999)
  self.ScriptPath = '/BoL/TCPUpdater/GetScript'..(UseHttps and '5' or '6')..'.php?script='..self:Base64Encode(self.Host..ScriptPath)..'&rand='..math.random(99999999)
  self.SavePath = SavePath
  self.CallbackUpdate = CallbackUpdate
  self.CallbackNoUpdate = CallbackNoUpdate
  self.CallbackNewVersion = CallbackNewVersion
  self.CallbackError = CallbackError
  AddDrawCallback(function() self:OnDraw() end)
  self:CreateSocket(self.VersionPath)
  self.DownloadStatus = 'Connect to Server for VersionInfo'
  AddTickCallback(function() self:GetOnlineVersion() end)
end

function ScriptUpdate:print(str)
  print('<font color="#FFFFFF">'..os.clock()..': '..str)
end

function ScriptUpdate:OnDraw()

  if self.DownloadStatus ~= 'Downloading Script (100%)' and self.DownloadStatus ~= 'Downloading VersionInfo (100%)'then
    DrawText('Download Status: '..(self.DownloadStatus or 'Unknown'),50,10,50,ARGB(0xFF,0xFF,0xFF,0xFF))
  end
  
end

function ScriptUpdate:CreateSocket(url)

  if not self.LuaSocket then
    self.LuaSocket = require("socket")
  else
    self.Socket:close()
    self.Socket = nil
    self.Size = nil
    self.RecvStarted = false
  end
  
  self.LuaSocket = require("socket")
  self.Socket = self.LuaSocket.tcp()
  self.Socket:settimeout(0, 'b')
  self.Socket:settimeout(99999999, 't')
  self.Socket:connect('sx-bol.eu', 80)
  self.Url = url
  self.Started = false
  self.LastPrint = ""
  self.File = ""
end

function ScriptUpdate:Base64Encode(data)

  local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  
  return ((data:gsub('.', function(x)
  
    local r,b='',x:byte()
    
    for i=8,1,-1 do
      r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0')
    end
    
    return r;
  end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
  
    if (#x < 6) then
      return ''
    end
    
    local c=0
    
    for i=1,6 do
      c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0)
    end
    
    return b:sub(c+1,c+1)
  end)..({ '', '==', '=' })[#data%3+1])
  
end

function ScriptUpdate:GetOnlineVersion()

  if self.GotScriptVersion then
    return
  end
  
  self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)
  
  if self.Status == 'timeout' and not self.Started then
    self.Started = true
    self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: sx-bol.eu\r\n\r\n")
  end
  
  if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
    self.RecvStarted = true
    self.DownloadStatus = 'Downloading VersionInfo (0%)'
  end
  
  self.File = self.File .. (self.Receive or self.Snipped)
  
  if self.File:find('</s'..'ize>') then
  
    if not self.Size then
      self.Size = tonumber(self.File:sub(self.File:find('<si'..'ze>')+6,self.File:find('</si'..'ze>')-1))
    end
    
    if self.File:find('<scr'..'ipt>') then
    
      local _,ScriptFind = self.File:find('<scr'..'ipt>')
      local ScriptEnd = self.File:find('</scr'..'ipt>')
      
      if ScriptEnd then
        ScriptEnd = ScriptEnd-1
      end
      
      local DownloadedSize = self.File:sub(ScriptFind+1,ScriptEnd or -1):len()
      
      self.DownloadStatus = 'Downloading VersionInfo ('..math.round(100/self.Size*DownloadedSize,2)..'%)'
    end
    
  end
  
  if self.File:find('</scr'..'ipt>') then
    self.DownloadStatus = 'Downloading VersionInfo (100%)'
    
    local a,b = self.File:find('\r\n\r\n')
    
    self.File = self.File:sub(a,-1)
     self.NewFile = ''
    
    for line,content in ipairs(self.File:split('\n')) do
    
      if content:len() > 5 then
        self.NewFile = self.NewFile .. content
      end
      
    end
    
    local HeaderEnd, ContentStart = self.File:find('<scr'..'ipt>')
    local ContentEnd, _ = self.File:find('</sc'..'ript>')
    
    if not ContentStart or not ContentEnd then
    
      if self.CallbackError and type(self.CallbackError) == 'function' then
        self.CallbackError()
      end
      
    else
      self.OnlineVersion = (Base64Decode(self.File:sub(ContentStart+1,ContentEnd-1)))
      self.OnlineVersion = tonumber(self.OnlineVersion)
      
      if self.OnlineVersion > self.LocalVersion then
      
        if self.CallbackNewVersion and type(self.CallbackNewVersion) == 'function' then
          self.CallbackNewVersion(self.OnlineVersion,self.LocalVersion)
        end
        
        self:CreateSocket(self.ScriptPath)
        self.DownloadStatus = 'Connect to Server for ScriptDownload'
        AddTickCallback(function() self:DownloadUpdate() end)
      else
        
        if self.CallbackNoUpdate and type(self.CallbackNoUpdate) == 'function' then
          self.CallbackNoUpdate(self.LocalVersion)
        end
        
      end
      
    end
    
    self.GotScriptVersion = true
  end
  
end

function ScriptUpdate:DownloadUpdate()

  if self.GotScriptUpdate then
    return
  end
  
  self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)
  
  if self.Status == 'timeout' and not self.Started then
    self.Started = true
    self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: sx-bol.eu\r\n\r\n")
  end
  
  if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
    self.RecvStarted = true
    self.DownloadStatus = 'Downloading Script (0%)'
  end
  
  self.File = self.File .. (self.Receive or self.Snipped)
  
  if self.File:find('</si'..'ze>') then
  
    if not self.Size then
      self.Size = tonumber(self.File:sub(self.File:find('<si'..'ze>')+6,self.File:find('</si'..'ze>')-1))
    end
    
    if self.File:find('<scr'..'ipt>') then
    
      local _,ScriptFind = self.File:find('<scr'..'ipt>')
      local ScriptEnd = self.File:find('</scr'..'ipt>')
      
      if ScriptEnd then
        ScriptEnd = ScriptEnd-1
      end
      
      local DownloadedSize = self.File:sub(ScriptFind+1,ScriptEnd or -1):len()
      
      self.DownloadStatus = 'Downloading Script ('..math.round(100/self.Size*DownloadedSize,2)..'%)'
    end
    
  end
  
  if self.File:find('</scr'..'ipt>') then
    self.DownloadStatus = 'Downloading Script (100%)'
    
    local a,b = self.File:find('\r\n\r\n')
    
    self.File = self.File:sub(a,-1)
    self.NewFile = ''
    
    for line,content in ipairs(self.File:split('\n')) do
    
      if content:len() > 5 then
        self.NewFile = self.NewFile .. content
      end
      
    end
    
    local HeaderEnd, ContentStart = self.NewFile:find('<sc'..'ript>')
    local ContentEnd, _ = self.NewFile:find('</scr'..'ipt>')
    
    if not ContentStart or not ContentEnd then
      
      if self.CallbackError and type(self.CallbackError) == 'function' then
        self.CallbackError()
      end
      
    else
      
      local newf = self.NewFile:sub(ContentStart+1,ContentEnd-1)
      local newf = newf:gsub('\r','')
      
      if newf:len() ~= self.Size then
      
        if self.CallbackError and type(self.CallbackError) == 'function' then
          self.CallbackError()
        end
        
        return
      end
      
      local newf = Base64Decode(newf)
      
      if type(load(newf)) ~= 'function' then
      
        if self.CallbackError and type(self.CallbackError) == 'function' then
          self.CallbackError()
        end
        
      else
      
        local f = io.open(self.SavePath,"w+b")
        
        f:write(newf)
        f:close()
        
        if self.CallbackUpdate and type(self.CallbackUpdate) == 'function' then
          self.CallbackUpdate(self.OnlineVersion,self.LocalVersion)
        end
        
      end
      
    end
    
    self.GotScriptUpdate = true
  end
  
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function OnLoad()

  HTTF_Viktor = HTTF_Viktor()
  
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function HTTF_Viktor:__init()
  self:Update()
  
end

---------------------------------------------------------------------------------

function HTTF_Viktor:Update()

  local ToUpdate = {}
  
  ToUpdate.Host = "raw.githubusercontent.com"
  ToUpdate.VersionPath = "/UnknownHeroe/BoL/master//version/SupportHeroes.version"
  ToUpdate.ScriptPath =  "/UnknownHeroe/BoL/master/SupportHeroes.lua"
  ToUpdate.SavePath = SCRIPT_PATH .. GetCurrentEnv().FILE_NAME
  ToUpdate.CallbackUpdate = function(NewVersion, OldVersion) print("<font color=\"#00FA9A\"><b>[Support Heroes] </b></font> <font color=\"#FFFFFF\">Updated to "..NewVersion..". </b></font>") end
  ToUpdate.CallbackNoUpdate = function(OldVersion) print("<font color=\"#00FA9A\"><b>[Support Heroes] </b></font> <font color=\"#FFFFFF\">No Updates Found</b></font>") end
  ToUpdate.CallbackNewVersion = function(NewVersion) print("<font color=\"#00FA9A\"><b>[Support Heroes] </b></font> <font color=\"#FFFFFF\">New Version found ("..NewVersion.."). Please wait until its downloaded</b></font>") end
  ToUpdate.CallbackError = function(NewVersion) print("<font color=\"#00FA9A\"><b>[Support Heroes] </b></font> <font color=\"#FFFFFF\">Error while Downloading. Please try again.</b></font>") end
  ScriptUpdate(Version, true, ToUpdate.Host, ToUpdate.VersionPath, ToUpdate.ScriptPath, ToUpdate.SavePath, ToUpdate.CallbackUpdate,ToUpdate.CallbackNoUpdate, ToUpdate.CallbackNewVersion,ToUpdate.CallbackError)
end
----------------------
--    Requirements  --
---------------------- 

-- Champion not supported --
if not (myHero.charName == "Alistar" or myHero.charName == "Annie" or myHero.charName == "Bard" or myHero.charName == "Blitzcrank" or myHero.charName == "Braum" or myHero.charName == "Janna" or
	myHero.charName == "Karma" or myHero.charName == "Leona" or myHero.charName == "Lulu" or myHero.charName == "Lux" or myHero.charName == "Malphite" or myHero.charName == "Morgana" or myHero.charName == "Nami" or
	myHero.charName == "Nautilus" or myHero.charName == "Nunu" or myHero.charName == "Shen" or myHero.charName == "Sona" or myHero.charName == "Soraka" or myHero.charName == "TahmKench" or 
	myHero.charName == "Taric" or myHero.charName == "Thresh" or myHero.charName == "Zilean" or myHero.charName == "Zyra") then 
		Customprint(myHero.charName .. " isn't currently supported")
		return 
end

if FileExist(LIB_PATH .. "/UPL.lua") then
  require("UPL")
  UPL = UPL()
else 
  Customprint("Downloading UPL, please don't press F9")
  DelayAction(function() DownloadFile("https://raw.github.com/nebelwolfi/BoL/master/Common/UPL.lua".."?rand="..math.random(1,10000), LIB_PATH.."UPL.lua", function () Customprint("Successfully downloaded UPL. Press F9 twice.") end) end, 3) 
  return
end

if FileExist(LIB_PATH .. "/SPrediction.lua") then
    Customprint("Remove SPrediction from Common, it will cause errors.")
end

if FileExist(LIB_PATH .. "/VPrediction.lua") then
	require("VPrediction")
else
	Customprint("VPrediction is required, please download it and reload")
	return
end

if FileExist(LIB_PATH .. "/SourceLib.lua") then
	require("SourceLib")
else
	Customprint("SourceLib is required, please download it and reload")
	return
end

----------------------
--   Script Status  --
----------------------

assert(load(Base64Decode("G0x1YVIAAQQEBAgAGZMNChoKAAAAAAAAAAAAAQIKAAAABgBAAEFAAAAdQAABBkBAAGUAAAAKQACBBkBAAGVAAAAKQICBHwCAAAQAAAAEBgAAAGNsYXNzAAQNAAAAU2NyaXB0U3RhdHVzAAQHAAAAX19pbml0AAQLAAAAU2VuZFVwZGF0ZQACAAAAAgAAAAgAAAACAAotAAAAhkBAAMaAQAAGwUAABwFBAkFBAQAdgQABRsFAAEcBwQKBgQEAXYEAAYbBQACHAUEDwcEBAJ2BAAHGwUAAxwHBAwECAgDdgQABBsJAAAcCQQRBQgIAHYIAARYBAgLdAAABnYAAAAqAAIAKQACFhgBDAMHAAgCdgAABCoCAhQqAw4aGAEQAx8BCAMfAwwHdAIAAnYAAAAqAgIeMQEQAAYEEAJ1AgAGGwEQA5QAAAJ1AAAEfAIAAFAAAAAQFAAAAaHdpZAAEDQAAAEJhc2U2NEVuY29kZQAECQAAAHRvc3RyaW5nAAQDAAAAb3MABAcAAABnZXRlbnYABBUAAABQUk9DRVNTT1JfSURFTlRJRklFUgAECQAAAFVTRVJOQU1FAAQNAAAAQ09NUFVURVJOQU1FAAQQAAAAUFJPQ0VTU09SX0xFVkVMAAQTAAAAUFJPQ0VTU09SX1JFVklTSU9OAAQEAAAAS2V5AAQHAAAAc29ja2V0AAQIAAAAcmVxdWlyZQAECgAAAGdhbWVTdGF0ZQAABAQAAAB0Y3AABAcAAABhc3NlcnQABAsAAABTZW5kVXBkYXRlAAMAAAAAAADwPwQUAAAAQWRkQnVnc3BsYXRDYWxsYmFjawABAAAACAAAAAgAAAAAAAMFAAAABQAAAAwAQACBQAAAHUCAAR8AgAACAAAABAsAAABTZW5kVXBkYXRlAAMAAAAAAAAAQAAAAAABAAAAAQAQAAAAQG9iZnVzY2F0ZWQubHVhAAUAAAAIAAAACAAAAAgAAAAIAAAACAAAAAAAAAABAAAABQAAAHNlbGYAAQAAAAAAEAAAAEBvYmZ1c2NhdGVkLmx1YQAtAAAAAwAAAAMAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAUAAAAFAAAABQAAAAUAAAAFAAAABQAAAAUAAAAFAAAABgAAAAYAAAAGAAAABgAAAAUAAAADAAAAAwAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAHAAAABwAAAAcAAAAHAAAABwAAAAcAAAAHAAAABwAAAAcAAAAIAAAACAAAAAgAAAAIAAAAAgAAAAUAAABzZWxmAAAAAAAtAAAAAgAAAGEAAAAAAC0AAAABAAAABQAAAF9FTlYACQAAAA4AAAACAA0XAAAAhwBAAIxAQAEBgQAAQcEAAJ1AAAKHAEAAjABBAQFBAQBHgUEAgcEBAMcBQgABwgEAQAKAAIHCAQDGQkIAx4LCBQHDAgAWAQMCnUCAAYcAQACMAEMBnUAAAR8AgAANAAAABAQAAAB0Y3AABAgAAABjb25uZWN0AAQRAAAAc2NyaXB0c3RhdHVzLm5ldAADAAAAAAAAVEAEBQAAAHNlbmQABAsAAABHRVQgL3N5bmMtAAQEAAAAS2V5AAQCAAAALQAEBQAAAGh3aWQABAcAAABteUhlcm8ABAkAAABjaGFyTmFtZQAEJgAAACBIVFRQLzEuMA0KSG9zdDogc2NyaXB0c3RhdHVzLm5ldA0KDQoABAYAAABjbG9zZQAAAAAAAQAAAAAAEAAAAEBvYmZ1c2NhdGVkLmx1YQAXAAAACgAAAAoAAAAKAAAACgAAAAoAAAALAAAACwAAAAsAAAALAAAADAAAAAwAAAANAAAADQAAAA0AAAAOAAAADgAAAA4AAAAOAAAACwAAAA4AAAAOAAAADgAAAA4AAAACAAAABQAAAHNlbGYAAAAAABcAAAACAAAAYQAAAAAAFwAAAAEAAAAFAAAAX0VOVgABAAAAAQAQAAAAQG9iZnVzY2F0ZWQubHVhAAoAAAABAAAAAQAAAAEAAAACAAAACAAAAAIAAAAJAAAADgAAAAkAAAAOAAAAAAAAAAEAAAAFAAAAX0VOVgA="), nil, "bt", _ENV))() ScriptStatus("TGJIIJIFJHN") 

----------------------
--     Variables    --
----------------------

--    Auto Shield   --
local typeshield
local typeheal

local spellslot
local healslot
local typeult
local ultslot
local wallslot

local range = 0
local healrange = 0
local ultrange = 0
local shealrange = 300
local lisrange = 600
local FotMrange = 700

local sbarrier = nil
local sheal = nil
local sflash = nil
local useitems = true
local spelltype = nil
local casttype = nil
local BShield,SShield,Shield,CC = false,false,false,false
local shottype,radius,maxdistance = 0,0,0
local hitchampion = false

-- Interrupt Spells --
local Interrupt = {
	["Katarina"] = {charName = "Katarina", stop = {["KatarinaR"] = {name = "Death lotus", spellName = "KatarinaR", ult = true }}},
	["Nunu"] = {charName = "Nunu", stop = {["AbsoluteZero"] = {name = "Absolute Zero", spellName = "AbsoluteZero", ult = true }}},
	["Malzahar"] = {charName = "Malzahar", stop = {["AlZaharNetherGrasp"] = {name = "Nether Grasp", spellName = "AlZaharNetherGrasp", ult = true}}},
	["Caitlyn"] = {charName = "Caitlyn", stop = {["CaitlynAceintheHole"] = {name = "Ace in the hole", spellName = "CaitlynAceintheHole", ult = true, projectileName = "caitlyn_ult_mis.troy"}}},
	["FiddleSticks"] = {charName = "FiddleSticks", stop = {["Crowstorm"] = {name = "Crowstorm", spellName = "Crowstorm", ult = true}}},
	["Galio"] = {charName = "Galio", stop = {["GalioIdolOfDurand"] = {name = "Idole of Durand", spellName = "GalioIdolOfDurand", ult = true}}},
	["Janna"] = {charName = "Janna", stop = {["ReapTheWhirlwind"] = {name = "Monsoon", spellName = "ReapTheWhirlwind", ult = true}}},
	["MissFortune"] = {charName = "MissFortune", stop = {["MissFortune"] = {name = "Bullet time", spellName = "MissFortuneBulletTime", ult = true}}},
	["MasterYi"] = {charName = "MasterYi", stop = {["MasterYi"] = {name = "Meditate", spellName = "Meditate", ult = false}}},
	["Pantheon"] = {charName = "Pantheon", stop = {["PantheonRJump"] = {name = "Skyfall", spellName = "PantheonRJump", ult = true}}},
	["Shen"] = {charName = "Shen", stop = {["ShenStandUnited"] = {name = "Stand united", spellName = "ShenStandUnited", ult = true}}},
	["Urgot"] = {charName = "Urgot", stop = {["UrgotSwap2"] = {name = "Position Reverser", spellName = "UrgotSwap2", ult = true}}},
	["Warwick"] = {charName = "Warwick", stop = {["InfiniteDuress"] = {name = "Infinite Duress", spellName = "InfiniteDuress", ult = true}}},
}

dashSpells = {}
isDash = {
	["Ezreal"] = {true, spell = _E, speed = math.huge, range = 475, variable_distance = true},
	["Kassadin"] = {true, spell = _R, speed = math.huge, range = 500, variable_distance = true},
	["Katarina"] = {true, spell = E, speed = math.huge, target = true},
	["Shaco"] = {true, spell = _Q, speed = math.huge, range = 400, variable_distance = true},
	["Talon"] = {true, spell = E, speed = math.huge, target = true},
	
	["Alistar"] = {true, spell = W, speed = 1200, target = true},
	["Leona"] = {true, spell = _E, speed = 2000, range = 875, variable_distance = false},
}

dangerousSpells = {
	["Akali"] = {true, spell = _R},
	["Alistar"] = {true, spell = _W},
	["Amumu"] = {true, spell = _R},
	["Annie"] = {true, spell = _R},
	["Ashe"] = {true, spell = _R},
	["Akali"] = {true, spell = _R},
	["Brand"] = {true, spell = _R},
	["Braum"] = {true, spell = _R},
	["Caitlyn"] = {true, spell = _R},
	["Cassiopeia"] = {true, spell = _R},
	["Chogath"] = {true, spell = _R},
	["Darius"] = {true, spell = _R},
	["Diana"] = {true, spell = _R},
	["Draven"] = {true, spell = _R},
	["Ekko"] = {true, spell = _R},
	["Evelynn"] = {true, spell = _R},
	["Fiora"] = {true, spell = _R},
	["Fizz"] = {true, spell = _R},
	["Galio"] = {true, spell = _R},
	["Garen"] = {true, spell = _R},
	["Gnar"] = {true, spell = _R},
	["Graves"] = {true, spell = _R},
	["Hecarim"] = {true, spell = _R},
	["JarvanIV"] = {true, spell = _R},
	["Jinx"] = {true, spell = _R},
	["Katarina"] = {true, spell = _R},
	["Kennen"] = {true, spell = _R},
	["LeBlanc"] = {true, spell = _R},
	["LeeSin"] = {true, spell = _R},
	["Leona"] = {true, spell = _R},
	["Lissandra"] = {true, spell = _R},
	["Lux"] = {true, spell = _R},
	["Malphite"] = {true, spell = _R},
	["Malzahar"] = {true, spell = _R},
	["Morgana"] = {true, spell = _R},
	["Nautilus"] = {true, spell = _R},
	["Nocturne"] = {true, spell = _R},
	["Orianna"] = {true, spell = _R},
	["Rammus"] = {true, spell = _E},
	["Riven"] = {true, spell = _R},
	["Sejuani"] = {true, spell = _R},
	["Shen"] = {true, spell = _E},
	["Skarner"] = {true, spell = _R},
	["Sona"] = {true, spell = _R},
	["Symdra"] = {true, spell = _R},
	["Tristana"] = {true, spell = _R},
	["Urgot"] = {true, spell = _R},
	["Varus"] = {true, spell = _R},
	["Veigar"] = {true, spell = _R},
	["Vi"] = {true, spell = _R},
	["Viktor"] = {true, spell = _R},
	["Warwick"] = {true, spell = _R},
	["Yasuo"] = {true, spell = _R},
	["Zed"] = {true, spell = _R},
	["Ziggs"] = {true, spell = _R},
	["Zyra"] = {true, spell = _R},
}

immuneEffects = {
	{'zhonyas_ring_activate.troy', 2.55, 'zhonyashourglass'},
	{'Aatrox_Passive_Death_Activate.troy', 3},
	{'LifeAura.troy', 4},
	{'nickoftime_tar.troy', 7},
	{'eyeforaneye_self.troy', 2},
	{'UndyingRage_buf.troy', 5},
	{'EggTimer.troy', 6},
	{'LOC_Suppress.troy', 1.75, 'infiniteduresschannel'},
	{'OrianaVacuumIndicator.troy', 0.50},
	{'NocturneUnspeakableHorror_beam.troy', 2},
	{'GateMarker_green.troy', 1.5},
	{'_stasis_skin_ful', 2.6},
}

-- Constants --
local TIME_BETWEEN_FARM_REQUESTS = 0.2

-- General Variables --
local EnemyMinions = nil
local AllyMinions = nil
local ts = nil
local LastFarmRequest = 0
local orbwalker = nil

-- Champion Variables --
local myTrueRange = myHero.range + GetDistance(myHero.minBBox)
local spells = {}
local buffs = {}
local objects = {}
local championVariables = {}
local auto = {}
local special = {}
local flashPos = nil

auto["interrupt"] = nil
special["interrupt"] = false

auto["snare"] = nil
special["snare"] = false

auto["ks"] = nil
special["ks"] = false

auto["clear"] = nil
auto["combo"] = nil
auto["dash"] = nil
auto["attack"] = false
auto["immobile"] = nil
auto["marathon"] = nil
auto["heal"] = nil

-- General settings --
buffs["moveBlock"] = false
buffs["recall"] = false

local ccTable = { 'Stun', 'Silence', 'Taunt', 'Slow', 'Root', 'Flee', 'Blind', 'Supress' }
local ccP = {5, 7, 8, 10, 11, 28, 25, 24}  

-- Champion Specific Variables --
if myHero.charName == "Alistar" then
	typeheal, healslot, healrange = 2, _E, 575
	
	spells[_Q] = {range = 365, center = myHero}
	spells[_W] = {range = 650, knock = 650}
	spells[_E] = {range = 575}
	spells[_R] = {}
	
	auto["interrupt"] = {_Q, _W}
	auto["snare"] = {_Q}
	auto["dash"] = {_Q, _W}
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _W}
	auto["heal"] = {_E}
elseif myHero.charName == "Annie" then
	typeshield = 3
	spellslot = _E

	spells[_Q] = {range = 625}
	spells[_W] = {range = 625, delay = 0.25, speed = math.huge, width = 200, type = "linear", collision = false, aoe = true}
	spells[_E] = {}
	spells[_R] = {range = 600, delay = 0.25, speed = math.huge, width = 200, type = "circular", collision = false, aoe = true}
	
	auto["interrupt"] = {_Q, _W, _R}
	special["interrupt"] = true
	
	auto["snare"] = {_Q, _W, _R}
	special["snare"] = true
	
	auto["dash"] = {_Q, _W}
	auto["clear"] = {_Q, _W}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["ks"] = {_Q, _W, _R}
	
	buffs["passive"] = 0
	buffs["canStun"] = false
	buffs["hasTibbers"] = false
elseif myHero.charName == "Bard" then
	spells[_Q] = {range = 900, speed = 1500, delay = 0.25, width = 100, type = "linear", collision = false, aoe = false}
	spells[_W] = {range = 800}
	spells[_E] = {range = 900}
	spells[_R] = {}
	
	auto["combo"] = {_Q}
	auto["ks"] = {_Q}
	auto["interrupt"] = {_Q}
	auto["snare"] = {_Q}
	auto["dash"] = {_Q}
	auto["immobile"] = {_Q}
	auto["marathon"] = {_W}
	
	LastBardQ = 0
elseif myHero.charName == "Blitzcrank" then
	spells[_Q] = {range = 1050, delay = 0.25, speed = 1800, width = 70, type = "linear", collision = true, aoe = false, select = true}
	spells[_W] = {}
	spells[_E] = {range = math.ceil(myTrueRange)}
	spells[_R] = {range = 600, center = myHero, collision = false, aoe = true}
	
	auto["interrupt"] = {_E, _Q, _R}
	auto["snare"] = {_Q, _E}
	auto["clear"] = {_R}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["dash"] = {_Q}
	auto["ks"] = {_Q, _R}
	auto["immobile"] = {_Q}
	auto["marathon"] = {_W}
	
	buffs["PowerFist"] = false
	buffs["rocketgrab2"] = false
elseif myHero.charName == "Braum" then
	wallslot = _E
	
	spells[_Q] = {range = 1000, delay = 0.25, width = 100, speed = 1700, type = "linear", collision = true, aoe = false}
	spells[_W] = {range = 650}
	spells[_E] = {}
	spells[_R] = {range = 1250, delay = 0.25, width = 210, speed = math.huge, type = "linear", collision = false, aoe = true}
	
	auto["interrupt"] = {_R}
	auto["snare"] = {_R, _Q}
	auto["combo"] = {_Q, _W, _R}
	auto["dash"] = {_Q}
	auto["ks"] = {_Q}
	auto["attack"] = true

elseif myHero.charName == "Janna" then
	typeshield, spellslot, range = 1, _E, 800
	
	spells[_Q] = {range = 1100, delay = 0.3, width = 120, speed = 900, type = "linear", collision = false, aoe = true}
	spells[_W] = {range = 600}
	spells[_E] = {range = 800}
	spells[_R] = {range = 725, knock = 875}
	
	auto["interrupt"] = {_Q, _R}	
	auto["snare"] = {_Q}	
	auto["dash"] = {_Q}
	auto["immobile"] = {_Q}
	
	objects["Q"] = nil
	
	auto["combo"] = {_Q, _W}
elseif myHero.charName == "Karma" then
	typeshield, spellslot, range = 1, _E, 800
	
	spells[_Q] = {range = 950, delay = 0.25, width = 70, speed = 1800, type = "linear", collision = true, aoe = false}
	spells[_W] = {range = 675}
	spells[_E] = {range = 800}
	spells[_R] = {}
	
	auto["clear"] = {_Q}
	auto["snare"] = {_W}
	auto["combo"] = {_Q, _W, _R}
	auto["ks"] = {_Q}
	auto["marathon"] = {_E}
	auto["snare"] = {_Q}
	
	objects["W"] = nil
elseif myHero.charName == "Leona" then
	typeshield = 3
	spellslot = _W

	spells[_Q] = {range = math.ceil(myTrueRange)}
	spells[_W] = {}
	spells[_E] = {range = 875, delay = 0.25, width = 70, speed = 2000, type = "linear", collision = false, aoe = false}
	spells[_R] = {range = 1200, width = 250, delay = 0.625, type = "circular", collision = false, aoe = true}
	
	auto["interrupt"] = {_Q, _R}
	auto["snare"] = {_Q, _R}
	auto["combo"] = {_Q, _W, _E, _R}
	
	buffs["LeonaShieldOfDaybreak"] = false
elseif myHero.charName == "Lulu" then
	typeshield, spellslot, range = 1, _E, 650
	typeult, ultslot, ultrange = 1, _R, 900
	
	spells[_Q] = {range = 925, delay = 0.25, width = 60, speed = 1600, type = "linear", collision = false, aoe = true}
	spells[_W] = {range = 650, select = true}
	spells[_E] = {range = 650}
	spells[_R] = {range = 900, width = 150}
	
	auto["interrupt"] = {_W,_R}
	special["interrupt"] = true
	
	auto["snare"] = {_Q}
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _W}
	auto["ks"] = {_Q}
	auto["marathon"] = {_W}
	
	objects["faerie"]  = myHero
elseif myHero.charName == "Lux" then
	typeshield, spellslot, range = 2, _W, 1075
	
	spells[_Q] = {range = 1175, delay = 0.5, width = 60, speed = 1800, type = "linear", collision = true, aoe = false}
	spells[_W] = {range = 1075}
	spells[_E] = {range = 1100, delay = 0.25, speed = 1500, width = 350, type = "circular", collision = false, aoe = true}
	spells[_R] = {range = 3340, delay = 0.75, speed = math.huge, width = 190, type = "linear", collision = false, aoe = true}
	
	auto["snare"] = {_Q, _E}
	auto["clear"] = {_E}
	auto["combo"] = {_Q, _E, _R}
	auto["dash"] = {_Q}
	auto["ks"] = {_Q, _R}
	auto["immobile"] = {_Q}
	
	objects["E"] = nil
elseif myHero.charName == "Malphite" then
	spells[_Q] = {range = 625}
	spells[_W] = {range = math.ceil(myTrueRange)}
	spells[_E] = {range = 150 + math.ceil(myTrueRange), center = myHero}
	spells[_R] = {range = 1200, delay = 0.25, width = 200, speed = 2000, type = "linear", collision = false, aoe = true}
	
	auto["snare"] = {_Q}
	auto["clear"] = {_E}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["ks"] = {_Q, _E, _R}
elseif myHero.charName == "Morgana" then
	typeshield, spellslot, range = 5, _E, 750
	
	spells[_Q] = {range = 1175, delay = 0.25, width = 80, speed = 1200, type = "linear", collision = true, aoe = false}
	spells[_W] = {range = 900, delay = 0.5, speed = math.huge, width = 350, type = "circular", collision = false, aoe = true}
	spells[_E] = {range = 750}
	spells[_R] = {range = 600, width = 0, type = "circular", collision = false, aoe = true}
	
	auto["snare"] = {_Q}	
	auto["clear"] = {_W}
	auto["combo"] = {_Q, _W, _R}
	auto["dash"] = {_Q}
	auto["ks"] = {_Q}
	auto["immobile"] = {_Q}
	
	buffs["DarkBindingMissile"] = nil
elseif myHero.charName == "Nami" then
	typeheal, healslot, healrange = 1, _W, 725
	
	spells[_Q] = {range = 875, delay = 0.5, width = 162, speed = 1500, type = "circular", collision = false, aoe = true}
	spells[_W] = {range = 725}
	spells[_E] = {range = 800}
	spells[_R] = {range = 2750, delay = 0.5, speed = 1200, width = 700, type = "linear", collision = false, aoe = true}
	
	auto["interrupt"] = {_Q, _R}
	auto["snare"] = {_Q, _R}
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["dash"] = {_Q}
	auto["ks"] = {_W}
	auto["immobile"] = {_Q}
	auto["marathon"] = {_E}
	auto["heal"] = {_W}
elseif myHero.charName == "Nautilus" then
	typeshield, spellslot = 3, _W
	
	spells[_Q] = {range = 950, delay = 0.5, width = 120, speed = 2000, type = "linear", collision = true, aoe = false, select = true}
	spells[_W] = {range = math.ceil(myTrueRange)}
	spells[_E] = {range = 500, center = myHero}
	spells[_R] = {range = 850}
	
	auto["interrupt"] = {_Q, _R}
	auto["snare"] = {_Q, _R, _E}
	auto["clear"] = {_E}
	auto["combo"] = {_Q, _W, _E}
	auto["immobile"] = {_Q}
	auto["attack"] = true
elseif myHero.charName == "Nunu" then
	spells[_Q] = {range = 125}
	spells[_W] = {range = 700}
	spells[_E] = {range = 550}
	spells[_R] = {range = 650, center = myHero}
	
	auto["snare"] = {_E}
	auto["clear"] = {_Q, _E}
	auto["combo"] = {_Q, _W, _E}
	auto["dash"] = {_E}
	auto["ks"] = {_E}
	auto["marathon"] = {_W}
elseif myHero.charName == "Shen" then
	typeshield, spellslot = 3, _W
	typeult, ultslot, ultrange = 3, _R, 25000

	spells[_Q] = {range = 475}
	spells[_W] = {}
	spells[_E] = {range = 600, delay = 0.25, width = 40, speed = 1600, type = "linear", collision = false, aoe = true}
	spells[_R] = {}
	
	auto["snare"] = {_E}
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _E}
	auto["ks"] = {_Q, _E}
	auto["interrupt"] = {_E}
	auto["immobile"] = {_E}
elseif myHero.charName == "Sona" then
	typeheal, healslot, healrange = 2, _W, 1000
	
	spells[_Q] = {range = 825}
	spells[_W] = {range = 1000}
	spells[_E] = {range = 350}
	spells[_R] = {range = 1000, delay = 0.25, width = 280, speed = 2400, type = "linear", collision = false, aoe = true}
	
	auto["interrupt"] = {_R}
	auto["snare"] = {_R}
	auto["combo"] = {_Q, _E, _R}
	auto["ks"] = {_R}
	auto["marathon"] = {_E}
	auto["heal"] = {_W}
	
	buffs["SonaQProcAttacker"] = false
elseif myHero.charName == "Soraka" then
	typeheal, healslot, healrange = 1, _W, 750
	typeult, ultslot, ultrange = 2, _R, math.huge
	
	spells[_Q] = {range = 970, delay = 0.25, width = 200, speed = 1300, type = "circular", collision = false, aoe = true}
	spells[_W] = {range = 550}
	spells[_E] = {range = 925, delay = 1, width = 200, speed = math.huge, type = "circular", collision = false, aoe = true}
	spells[_R] = {range = math.huge}
	
	auto["interrupt"] = {_E}
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _E}
	auto["ks"] = {_Q}
	auto["immobile"] = {_E}
	auto["heal"] = {_W}
elseif myHero.charName == "TahmKench" then
	typeshield, spellslot = 3, _E
	
	spells[_Q] = {range = 820, delay = 0.25, width = 70, speed = 2000, type = "linear", collision = true, aoe = false}
	spells[_W] = {range = 250}
	spells[_E] = {}
	spells[_R] = {}
	
	auto["interrupt"] = {_Q, _W}
	auto["snare"] = {_Q}
	auto["dash"] = {_Q}
	auto["combo"] = {_Q, _W}
	auto["ks"] = {_Q}
	auto["immobile"] = {_Q}
	
	auto["attack"] = true
	
	buffs["minion"] = false
elseif myHero.charName == "Taric" then
	typeheal, healslot, healrange = 1, _Q, 750
	
	spells[_Q] = {range = 750}
	spells[_W] = {range = 375, width = 0, type = "circular", collision = false, aoe = true}
	spells[_E] = {range = 625}
	spells[_R] = {range = 500}
	
	auto["interrupt"] = {_E}
	auto["snare"] = {_E}
	
	auto["dash"] = {_E}
	auto["clear"] = {_W}
	auto["combo"] = {_W, _E}
	auto["heal"] = {_Q}
elseif myHero.charName == "Thresh" then
	spells[_Q] = {range = 1100, delay = 0.5, speed = 1800, width = 80, type = "linear", collision = true, aoe = false, select = true}
	spells[_W] = {range = 950}
	spells[_E] = {range = 500}
	spells[_E] = {range = 500}
	spells[_R] = {range = 450, delay = 0.25, speed = math.huge, width = 0, type = "circular", collision = false, aoe = true}
	
	auto["interrupt"] = {_Q, _E}
	auto["snare"] = {_Q, _E, _R}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["dash"] = {_E, _Q}
	auto["immobile"] = {_Q}
	
	buffs["ThreshQ"] = false
elseif myHero.charName == "Zilean" then
	typeult, ultslot, ultrange = 1, _R, 900
	
	spells[_Q] = {range = 900, delay = 0.25, speed = 1800, width = 100, type = "circular", collision = false, aoe = false}
	spells[_W] = {}
	spells[_E] = {range = 700}
	spells[_R] = {range = 900}
	
	auto["clear"] = {_Q}
	auto["combo"] = {_Q, _W, _E}
	auto["ks"] = {_Q}
	auto["immobile"] = {_Q}
	auto["marathon"] = {_E}
	
	objects["Q"] = nil
elseif myHero.charName == "Zyra" then
	spells["P"] = {range = 1500, delay = 0.5, speed = 2000, width = 60, type = "linear", collision = false, aoe = true}
	spells[_Q] = {range = 800, delay = 0.5, speed = 1400, width = 220, type = "circular", collision = false, aoe = true}
	spells[_W] = {range = 850, delay = 0.25}
	spells[_E] = {range = 1100, delay = 0.25, speed = 1150, width = 70, type = "linear", collision = false, aoe = true}
	spells[_R] = {range = 700, delay = 1, speed = math.huge, width = 500, type = "circular", collision = false, aoe = true}
	
	auto["interrupt"] = {_R}
	auto["snare"] = {_E, _R}
	auto["clear"] = {_Q, _E}
	auto["combo"] = {_Q, _W, _E, _R}
	auto["dash"] = {_E}
	auto["ks"] = {_Q, E}
	auto["immobile"] = {_E}
	
	championVariables["seeds"] = 0
end 

if auto["attack"] then
	attack = {}
	for i, enemy in pairs(GetEnemyHeroes()) do
		attack[enemy.charName] = true
	end
end

----------------------
--       Hooks      --
----------------------

function OnLoad()
	-- Get summoner spells --
	if myHero:GetSpellData(SUMMONER_1).name:find("summonerbarrier") then sbarrier = SUMMONER_1
	elseif myHero:GetSpellData(SUMMONER_2).name:find("summonerbarrier") then sbarrier = SUMMONER_2 end
	if myHero:GetSpellData(SUMMONER_1).name:find("summonerheal") then sheal = SUMMONER_1
	elseif myHero:GetSpellData(SUMMONER_2).name:find("summonerheal") then sheal = SUMMONER_2 end
	if myHero:GetSpellData(SUMMONER_1).name:find("summonerflash") then sflash = SUMMONER_1
	elseif myHero:GetSpellData(SUMMONER_2).name:find("summonerflash") then sflash = SUMMONER_2 end
	
	Menu()
	LoadSpells()
	HTTF_Viktor = HTTF_Viktor()

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, BiggestRange(auto["combo"]), DAMAGE_MAGIC, true)
	EnemyMinions = minionManager(MINION_ENEMY, BiggestRange(auto["clear"]), myHero, MINION_SORT_MAXHEALTH_DES)
	if myHero.charName == "Braum" then AllyMinions = minionManager(MINION_ALLY, GetRange(_W) + 100, myHero, MINION_SORT_MAXHEALTH_DES) end
	VPred = VPrediction()
	
	Customprint("Sucessfully Loaded! Good Luck!")
end

function OnProcessSpell(object,spell)	
	if object.isMe and spell.name:lower():find("attack") and settings.humanizer.block then
		DisableMovement()
		DelayAction(function() EnableMovement() end, (1 / (spell.animationTime * myHero.attackSpeed)) - Latency())
	end
	
	if myHero.charName == "Leona" then
		if settings.spell[GetSpellData(_Q).name].ward and object.isMe and spell.name:lower():find("attack") and spell.target.name:lower():find("ward") then
			DelayAction(function() CastSpell(_Q, myHero) Attack(object.target) end, (1 / (spell.animationTime * myHero.attackSpeed)) - Latency())
			
		end
	elseif myHero.charName == "Nami" then
		if IsReady(_E) and not object.isMe and object.team == myHero.team and GetDistance(object) < GetRange(_E) and settings.spell[GetSpellData(_E).name].autoE and spell.target ~= nil and spell.target.type == myHero.type and spell.name:lower():find("attack") then
			CastSpell(_E, object)
		end
	elseif myHero.charName == "Shen" then
		if IsReady(_Q) and not object.isMe and object.team == myHero.team and object.type == myHero.type and settings.spell[GetSpellData(_Q).name].autoQ and spell.target 
		and spell.target.health > 500 and object.health ~= object.maxHealth and spell.name:lower():find("attack") and GetDistance(spell.target) < GetRange(_Q) then
			if settings.spell[GetSpellData(_Q).name].save and GetSpellData(_E).level > 0 and myHero.mana + GetSpellData(_E).currentCd * myHero.mpRegen < 60 + 105 - 5 * GetSpellData(_E).level then return end
			CastSpell(_Q, spell.target)
		end
	elseif myHero.charName == "Zyra" and object.isMe then
		if true then
			if IsReady(_W) and UseSpell(_W) then
				championVariables["seeds"] = settings.spell[GetSpellData(_W).name].autoW
				ZyraCastSeed(spell.endPos.x, spell.endPos.z, spell.name)
			end
		end
	end

	if auto["snare"] ~= nil then
		if spell and object and spell.name:lower():find("turret") and object.team == myHero.team then
			for i = 1, heroManager.iCount, 1 do
				local enemy = heroManager:getHero(i)
				if enemy.team ~= myHero.team and spell.target == enemy then
					if GetDistance(enemy, tower) < settings.snare.distance and settings.snare[enemy.charName] and GetDistance(myHero, enemy) < 1000 then
						if myHero.charName == "Bard" then BardCastQ(enemy) return end
						CastArray(auto["snare"], settings.snare, special["snare"], enemy, settings.humanizer.snareDelay)
					end
				end
			end
		end
	end
	
	if object.isMe then
		if spell.name == "ReapTheWhirlwind" then
			buffs["moveBlock"] = true
			DelayAction(function() buffs["moveBlock"] = false end, 3)
		end
	end
	
	-- Auto Shield Process Spell --
	if object.team ~= myHero.team and not myHero.dead and object.name ~= nil and not (object.name:find("Minion_") or object.name:find("Odin")) then
		local leesinW = myHero.charName ~= "LeeSin" or myHero:GetSpellData(_W).name == "BlindMonkWOne"
		local nidaleeE = myHero.charName ~= "Nidalee" or myHero:GetSpellData(_E).name == "PrimalSurge"
		
		local shieldREADY = typeshield ~= nil and myHero:CanUseSpell(spellslot) == READY and leesinW
		local healREADY = typeheal ~= nil and myHero:CanUseSpell(healslot) == READY and nidaleeE
		local ultREADY = typeult ~= nil and myHero:CanUseSpell(ultslot) == READY
		local wallREADY = wallslot ~= nil and myHero:CanUseSpell(wallslot) == READY
		local sbarrierREADY = sbarrier ~= nil and myHero:CanUseSpell(sbarrier) == READY
		local shealREADY = sheal ~= nil and myHero:CanUseSpell(sheal) == READY
		
		local lisslot = CustomGetInventorySlotItem("IronStylus", myHero)
		local seslot = CustomGetInventorySlotItem("ItemSeraphsEmbrace", myHero)
		local FotMslot = CustomGetInventorySlotItem("HealthBomb", myHero)
		
		local lisReady = lisslot ~= nil and myHero:CanUseSpell(lisslot) == READY
		local seREADY = seslot ~= nil and myHero:CanUseSpell(seslot) == READY
		local FotMREADY = FotMslot ~= nil and myHero:CanUseSpell(FotMslot) == READY
		
		local HitFirst = false
		local shieldtarget,SLastDistance,SLastDmgPercent = nil,nil,nil
		local healtarget,HLastDistance,HLastDmgPercent = nil,nil,nil
		local ulttarget,ULastDistance,ULastDmgPercent = nil,nil,nil
		
		YWall,BShield,SShield,Shield,CC = false,false,false,false,false
		shottype,radius,maxdistance = 0,0,0
		
		if object.type == "AIHeroClient" then
			spelltype, casttype = getSpellType(object, spell.name)
			
			if casttype == 4 or casttype == 5 or casttype == 6 then return end
			
			if spelltype == "BAttack" or spelltype == "CAttack" then
				Shield = true
				YWall = true
			elseif spell.name:find("SummonerDot") then
				Shield = true
			elseif spelltype == "Q" or spelltype == "W" or spelltype == "E" or spelltype == "R" or spelltype == "P" or spelltype == "QM" or spelltype == "WM" or spelltype == "EM" then
				if skillShield[object.charName] == nil then return end
				HitFirst = skillShield[object.charName][spelltype]["HitFirst"]
				YWall = skillShield[object.charName][spelltype]["YWall"]
				BShield = skillShield[object.charName][spelltype]["BShield"]
				SShield = skillShield[object.charName][spelltype]["SShield"]
				Shield = skillShield[object.charName][spelltype]["Shield"]
				CC = skillShield[object.charName][spelltype]["CC"]
				shottype = skillData[object.charName][spelltype]["type"]
				radius = skillData[object.charName][spelltype]["radius"]
				maxdistance = skillData[object.charName][spelltype]["maxdistance"]
			end
		else
			Shield = true
		end
		
		for i=1, heroManager.iCount do
			local allytarget = heroManager:GetHero(i)
			if allytarget.team == myHero.team and not allytarget.dead and allytarget.health > 0 then
				hitchampion = false
				
				local allyHitBox = allytarget.boundingRadius
				if shottype == 0 then hitchampion = spell.target and spell.target.networkID == allytarget.networkID
				elseif shottype == 1 then hitchampion = checkhitlinepass(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 2 then hitchampion = checkhitlinepoint(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 3 then hitchampion = checkhitaoe(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 4 then hitchampion = checkhitcone(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 5 then hitchampion = checkhitwall(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 6 then hitchampion = checkhitlinepass(object, spell.endPos, radius, maxdistance, allytarget, allyHitBox) or checkhitlinepass(object, Vector(object)*2-spell.endPos, radius, maxdistance, allytarget, allyHitBox)
				elseif shottype == 7 then hitchampion = checkhitcone(spell.endPos, object, radius, maxdistance, allytarget, allyHitBox)
				end
				
				if hitchampion and object.team ~= myHero.team then
					if myHero.charName == "TahmKench" and not allytarget.isMe then
						if IsReady(_W) and GetDistance(allytarget) < GetRange(_W) and settings.spell[GetSpellData(_W).name].save then
							if dangerousSpells[object.charName] and GetSpellData(dangerousSpells[object.charName].spell).name == spell.name then
								CastSpell(_W, allytarget)
							end
						end
					end
				
					if (allytarget.isMe and (_G.Evadeee_Enabled and _G.Evadeee_Loaded and _G.Evadeee_impossibleToEvade) or not _G.Evadeee_Enabled) or not allytarget.isMe then
						if shieldREADY and settings.as["teammateshield"..i] and ((typeshield<=4 and Shield) or (typeshield==5 and BShield) or (typeshield==6 and SShield)) then
							if (((typeshield==1 or typeshield==2 or typeshield==5) and GetDistance(allytarget)<=range) or allytarget.isMe) then
								local shieldflag, dmgpercent = shieldCheck(object,spell,allytarget,"shields")
								if shieldflag then
									if HitFirst and (SLastDistance == nil or GetDistance(allytarget,object) <= SLastDistance) then
										shieldtarget,SLastDistance = allytarget,GetDistance(allytarget,object)
									elseif not HitFirst and (SLastDmgPercent == nil or dmgpercent >= SLastDmgPercent) then
										shieldtarget,SLastDmgPercent = allytarget,dmgpercent
									end
								end
							end
						end
						
						if healREADY and settings.ah["teammateheal"..i] and Shield then
							if ((typeheal==1 or typeheal==2) and GetDistance(allytarget)<=healrange) or allytarget.isMe then
								local healflag, dmgpercent = shieldCheck(object,spell,allytarget,"heals")
								if healflag then
									if HitFirst and (HLastDistance == nil or GetDistance(allytarget,object) <= HLastDistance) then
										healtarget,HLastDistance = allytarget,GetDistance(allytarget,object)
									elseif not HitFirst and (HLastDmgPercent == nil or dmgpercent >= HLastDmgPercent) then
										healtarget,HLastDmgPercent = allytarget,dmgpercent
									end
								end		
							end
						end
						
						if ultREADY and settings.au["teammateult"..i] and Shield then
							if typeult==2 or (typeult==1 and GetDistance(allytarget)<=ultrange) or (typeult==4 and allytarget.isMe) or (typeult==3 and not allytarget.isMe) and object.type == myHero.type then
								if myHero.charName == "Shen" and GetDistance(allytarget) < 1000 then return end
								if myHero.charName == "Shen" and CountObjectsInCircle(allytarget, 1000, GetEnemyHeroes()) - CountObjectsInCircle(allytarget, 1000, GetAllyHeroes()) > 1 then return end
								
								local ultflag, dmgpercent = shieldCheck(object,spell,allytarget,"ult")
								if ultflag then
									if HitFirst and (ULastDistance == nil or GetDistance(allytarget,object) <= ULastDistance) then
										ulttarget,ULastDistance = allytarget,GetDistance(allytarget,object)
									elseif not HitFirst and (ULastDmgPercent == nil or dmgpercent >= ULastDmgPercent) then
										ulttarget,ULastDmgPercent = allytarget,dmgpercent
									end
								end
							end
						end
						
						if wallREADY and settings.aw.wallon and allytarget.isMe and YWall then
							local wallflag, dmgpercent = shieldCheck(object,spell,allytarget,"wall")
							if wallflag then
								DelayAction(function() CastSpell(wallslot,object.x,object.z) end, settings.humanizer.shieldDelay / 1000)
							end
						elseif myHero.charName == "Braum" and wallREADY and settings.aw.wallon and GetDistance(allytarget) < GetRange(_W) and YWall and IsReady(_W) and IsReady(_E) then
							local wallflag, dmgpercent = shieldCheck(object,spell,allytarget,"wall")
							if wallflag then
								local x, z = object.x,object.z
								DelayAction(function() CastSpell(_W,allytarget) end, settings.humanizer.shieldDelay / 1000)
								DelayAction(function() CastSpell(wallslot,x, z) end, (settings.humanizer.shieldDelay + 250) / 1000)
							end
						end
						
						if sbarrierREADY and settings.asb.barrieron and allytarget.isMe and Shield then
							local barrierflag, dmgpercent = shieldCheck(object,spell,allytarget,"barrier")
							if barrierflag then
								DelayAction(function() CastSpell(sbarrier) end, settings.humanizer.shieldDelay / 1000)
							end
						end
						
						if shealREADY and settings.ash["teammatesheal"..i] and Shield then
							if GetDistance(allytarget)<=shealrange then
								local shealflag, dmgpercent = shieldCheck(object,spell,allytarget,"sheals")
								if shealflag then
									DelayAction(function() CastSpell(sheal) end, settings.humanizer.shieldDelay / 1000)
								end
							end
						end
						
						if lisReady and settings.asi["teammateshieldi"..i] and Shield then
							if GetDistance(allytarget)<=lisrange then
								local lisflag, dmgpercent = shieldCheck(object,spell,allytarget,"items")
								if lisflag then
									DelayAction(function() CastSpell(lisslot) end, settings.humanizer.shieldDelay / 1000)
								end
							end
						end
						
						if FotMREADY and settings.asi["teammateshieldi"..i] and Shield then
							if GetDistance(allytarget)<=FotMrange then
								local FotMflag, dmgpercent = shieldCheck(object,spell,allytarget,"items")
								if FotMflag then
									DelayAction(function() CastSpell(FotMslot, allytarget) end, settings.humanizer.shieldDelay / 1000)
								end
							end
						end
						
						if seREADY and settings.asi["teammateshieldi"..i] and allytarget.isMe and Shield then
							local seflag, dmgpercent = shieldCheck(object,spell,allytarget,"items")
							if seflag then
								DelayAction(function() CastSpell(seslot) end, settings.humanizer.shieldDelay / 1000)
							end
						end
					end
				end
			end
		end
		
		if shieldtarget ~= nil then
			if myHero.charName == "Karma" and UseSpell(_R) and UseRWith() == 2 then CustomCast(_R, myHero) end
			if myHero.charName == "Karma" and UseSpell(_R) and UseRWith() == 3 and CountObjectsInCircle(myHero, 600, GetAllyHeroes()) == 1 then CustomCast(_R, myHero) end
		
			if typeshield==1 or typeshield==5 then DelayAction(function() CastSpell(spellslot,shieldtarget) end, settings.humanizer.shieldDelay / 1000)
			elseif typeshield==2 or typeshield==4 then DelayAction(function() CastSpell(spellslot,shieldtarget.x,shieldtarget.z) end, settings.humanizer.shieldDelay / 1000)
			elseif typeshield==3 or typeshield==6 then DelayAction(function() CastSpell(spellslot) end, settings.humanizer.shieldDelay / 1000) end
		end
		
		if healtarget ~= nil then
			if typeheal==1 then DelayAction(function() CastSpell(healslot,healtarget) end, settings.humanizer.shieldDelay / 1000)
			elseif typeheal==2 or typeheal==3 then DelayAction(function() CastSpell(healslot) end, settings.humanizer.shieldDelay / 1000) end
		end
		
		if ulttarget ~= nil then
			if typeult==1 or typeult==3 then DelayAction(function() CastSpell(ultslot,ulttarget) end, settings.humanizer.shieldDelay / 1000)
			elseif typeult==2 or typeult==4 then DelayAction(function() CastSpell(ultslot) end, settings.humanizer.shieldDelay / 1000) end		
		end
	end	
	
	--Anti Dash --
	if auto["dash"] then
		if object.type == myHero.type and object.team ~= myHero.team and GetDistance(object) < 2000 then
			if settings.dash[object.charName] then
				if spell.name == "summonerflash" then
					if GetDistance(object, spell.endPos) < 425 then
						castPos = spell.endPos
					else
						castPos = Vector(object) + 425 * (Vector(spell.endPos) - Vector(object)):normalized()
					end
					
					table.insert(dashSpells, {unit = object.charName,
											unitPosition = {x = object.x, y = object.y, z = object.y},
											startPosition = {x  = spell.startPos.x, y = spell.startPos.y, z  = spell.startPos.z},
											endPosition = {x  = castPos.x, y = castPos.y, z  = castPos.z}, 
											time = os.clock(), 
											delay = spell.windUpTime, 
											speed = math.huge})
				end
			
				if isDash[object.charName] and spell.name == object:GetSpellData(isDash[object.charName].spell).name and target and isDash[object.charName] then
					table.insert(dashSpells,{unit = object.charName, 
											unitPosition = {x = object.x, y = object.y, z = object.y},
											startPosition = {x  = spell.startPos.x, y = spell.startPos.y, z  = spell.startPos.z}, 
											endPosition = {x  = spell.target.x, y = spell.target.y, z = spell.target.z}, 
											time = os.clock(), 
											delay = spell.windUpTime, 
											speed = isDash[object.charName].speed})
				end
				
				for _,effect in pairs(immuneEffects) do
					if effect[3] and spell.name:lower():find(effect[3]) then
						table.insert(dashSpells, {unit = object.charName,
							unitPosition = {x = 0, y = 0, z = 0},
							startPosition = {x  = 0, y = 0, z  = 0},
							endPosition = {x  = object.x, y = object.y, z  = object.z}, 
							time = os.clock(), 
							delay = effect[2], 
							speed = math.huge})
					end
				end
			end
		end
	end

	-- Auto Interrupt --
	if auto["interrupt"] ~= nil then
		if not myHero.dead and myHero.team ~= object.team then
			if Interrupt[object.charName] ~= nil then
				if Interrupt[object.charName].stop[spell.name] ~= nil then
					if settings.interrupt[spell.name] then
						if myHero.charName == "Bard" then BardCastQ(object) return end
						CastArray(auto["interrupt"], settings.interrupt, special["interrupt"], object, settings.humanizer.interruptDelay)
					end
				end
			end
		end
	end
end

function OnNewPath(unit,startPos,endPos,isDash,dashSpeed,dashGravity,dashDistance)
	if unit.type == myHero.type and unit.team ~= myHero.team and settings.dash and settings.dash[unit.charName] then
		if isDash then 
			for i, spell in ipairs(dashSpells) do
				if spell.unit == unit.charName then
					table.remove(dashSpells, i)
				end
			end
			
			table.insert(dashSpells,{unit = unit.charName, 
						unitPosition = {x = unit.x, y = unit.y, z = unit.y},
						startPosition = {x  = startPos.x, y = startPos.y, z  = startPos.z}, 
						endPosition = {x  = endPos.x, y = endPos.y, z = endPos.z}, 
						time = os.clock(), 
						delay = 0, 
						speed = dashSpeed})
		end
	end
end

-- Block movement --
function OnSendPacket(p)
	if tostring(p.header) == "38" and buffs["moveBlock"] and settings.key.comboKey then 
		p:Block() 
	end
end

-- On Update Buff --
function OnUpdateBuff(unit, buff, stacks)
	if unit and unit.isMe and buff then
		if (buff.name == "pyromania") then buffs["passive"] = stacks end
	end 
end

-- On Apply Buff --
function OnApplyBuff(unit, target, buff)
	if unit ~= nil and buff and unit.isMe and buff.name:lower() == "recall" or buff.name:lower() == "summonerteleport" or buff.name:lower() == "recallimproved" then buffs["recall"] = true end
	
	local slot = CustomGetInventorySlotItem("ItemMorellosBane", myHero)	
	if slot ~= nil and IsReady(slot) then
		for i,v in ipairs(ccTable) do
			if ccP[i] == buff.type and settings.items.mikaels['ccType'..i] then
				if target.team == myHero.team and not target.isMe and settings.items.mikaels[target.charName] and unit.type == myHero.type then
					if GetDistance(target) < 750 and not target.dead then
						CastSpell(slot, target)
					end
				end
			end
		end
	end
	
	if auto["attack"] then
		if unit and buff and target.type == myHero.type and target.team ~= myHero.team then
			if buff.name == "braummarkcounter" or buff.name == "braummarkstunreduction" or buff.name == "nautiluspassivecheck" then
				attack[target.charName] = false
			end
			
			if buff.name == "tahmkenchpdevourable" then
				attack[target.charName] = true
			end
		end
	end
	
	if myHero.charName == "TahmKench" and unit and buff and target and target.type ~= myHero.type and unit.isMe then
		if buff.name == "tahmkenchwdevoured" then
			buffs["minion"] = true
		end
	end
	
	if unit and unit.isMe and buff then 
		if buff.name == "lulufaerieshield" or buff.name == "lulufaerieburn" then objects["faerie"] = target end
		if buff.name == "pyromania_particle" then buffs["canStun"] = true end
		if buff.name == "infernalguardiantimer" then buffs["hasTibbers"] = true end
		if buff.name == "PowerFist" then 
			buffs["PowerFist"] = true
			buffs["rocketgrab2"] = false
		end 
		if buff.name == "ReapTheWhirlwind" then buffs["moveBlock"] = true end
		if buff.name == "LeonaShieldOfDaybreak" then buffs["LeonaShieldOfDaybreak"] = true end
		if buff.name == "SonaQProcAttacker" then buffs["SonaQProcAttacker"] = true end
		
		if target.type == myHero.type then
			if target.team ~= myHero.team then
				if buff.name == "rocketgrab2" then buffs["rocketgrab2"] = true end
				if buff.name == "DarkBindingMissile" then  buffs["DarkBindingMissile"] = target end
				if buff.name == "ThreshQ" then ThreshCastQ2() buffs["ThreshQ"] = true end
			end
		end
	end
end

-- On Remove Buff --
function OnRemoveBuff(unit, buff)
	if unit ~= nil and buff and unit.isMe and buff.name:lower() == "recall" or buff.name:lower() == "summonerteleport" or buff.name:lower() == "recallimproved" then buffs["recall"] = false end
	
	if auto["attack"] then
		if unit and buff and unit.type == myHero.type and unit.team ~= myHero.team then
			if buff.name == "braummarkcounter" or buff.name == "braummarkstunreduction" or buff.name == "nautiluspassivecheck" then
				attack[unit.charName] = true
			end
			
			if buff.name == "tahmkenchpdevourable" then
				attack[unit.charName] = false
			end
		end
	end
	
	if myHero.charName == "TahmKench" and unit and buff and unit.isMe then
		if buff.name == "tahmkenchwhasdevouredtarget" then
			buffs["minion"] = false
		end
	end
	
	if unit and unit.isMe and buff then
		if buff.name == "pyromania" then buffs["passive"] = 0 end 
		if buff.name == "pyromania_particle" then buffs["canStun"] = false end
		if buff.name == "infernalguardiantimer" then buffs["hasTibbers"] = false end 
		if buff.name == "PowerFist" then buffs["PowerFist"] = false end 
		if buff.name == "ReapTheWhirlwind" then buffs["moveBlock"] = false end
		if buff.name == "LeonaShieldOfDaybreak" then buffs["LeonaShieldOfDaybreak"] = false end
		if buff.name == "SonaQProcAttacker" then buffs["SonaQProcAttacker"] = false end
	end
	
	if buff.name == "lulufaerieshield" or buff.name == "lulufaerieburn" then  objects["faerie"] = myHero end
	
	if unit and unit.team ~= myHero.team then
		if unit.type == myHero.type then
			if buff.name == "DarkBindingMissile" then buffs["DarkBindingMissile"] = nil end
			if buff.name == "ThreshQ" then buffs["ThreshQ"] = false end
		end
	end
end

function OnCreateObj(object)
	if myHero.charName == "Leona" then
		if settings.spell[GetSpellData(_Q).name].ward and object.name:lower():find("ward") and object.team ~= myHero.team and GetDistance(object) < myTrueRange + 100 then
			Attack(object)
		end
	end

	if object.name == "Zilean_Base_Q_TimeBomb_green.troy" or object.name == "Zilean_Base_Q_Attach.troy" then
		objects["Q"] = object
	end

	if GetDistance(object) < 100 and object.name == "HowlingGale_Frost_cas.troy" then
		objects["Q"] = object
	end
	
	if (object.name == "Karma_Base_W_beam.troy" or object.name == "Karma_Base_W_beam_R.troy") then
		objects["W"] = object
	end
	
	if object.name == "Lux_Base_E_tar_aoe_green.troy" and GetSpellData(_E).name == "luxlightstriketoggle" then
		objects["E"] = object
	end
	
	if object.name == "Lux_Base_E_tar_nova.troy" and GetSpellData(_E).name == "LuxLightStrikeKugel" then
		objects["E"] = nil
	end
	
	if object and object.valid then
		for _, effect in pairs(immuneEffects) do
			if object.name:lower():find(effect[1]) then
				local nearestHero = nil

				for i, hero in pairs(GetEnemyHeroes()) do
					if nearestHero and nearestHero.valid and hero and hero.valid then
						if GetDistanceSqr(hero, object) < GetDistanceSqr(nearestHero, object) then
							nearestHero = hero
						end
					else
						nearestHero = hero
					end
				end

				if nearestHero.type == myHero.type and nearestHero.team ~= myHero.team then
					table.insert(dashSpells, {unit = nearestHero.charName,
						unitPosition = {x = 0, y = 0, z = 0},
						startPosition = {x  = 0, y = 0, z  = 0},
						endPosition = {x  = nearestHero.x, y = nearestHero.y, z  = nearestHero.z}, 
						time = os.clock(), 
						delay = effect[2], 
						speed = math.huge})
				end
			end
		end
	end
end

function OnDeleteObj(object)
	if object.name == "Zilean_Base_Q_TimeBomb_green.troy" or object.name == "Zilean_Base_Q_Attach.troy" then
		objects["Q"] = nil
	end

	if objects["Q"] ~= nil and object.name == "HowlingGale_Frost_cas.troy" then
		objects["Q"] = nil
	end
	
	if GetDistance(object) < 1000 and (object.name == "Karma_Base_W_beam.troy" or object.name == "Karma_Base_W_beam_R.troy") then
		objects["W"] = nil
	end
end

function OnTick()
	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, BiggestRange(auto["combo"]), DAMAGE_MAGIC, true)
	EnemyMinions = minionManager(MINION_ENEMY, BiggestRange(auto["clear"]), myHero, MINION_SORT_MAXHEALTH_DES)
	
	local Target = myHero.charName == "Zilean" and ZileanTarget() or GetTarget()
	
	CastDash()
	Combo(Target)
	Automatic()
	
	if auto["clear"] ~= nil and settings.key.clearKey then LaneClear() end
end

function OnDraw()
	Target = GetTarget()		
	if settings.draw.target and ValidTarget(Target) then
		DrawCircle(Target.x, Target.y, Target.z, 150, 0xffffff00)
	end
	
	for slot = _Q, _R  do
		if settings.draw[GetSpellData(slot).name]  ~= nil and settings.draw[GetSpellData(slot).name] == true and IsReady(slot) then
			DrawCircle(myHero.x, myHero.y, myHero.z, GetRange(slot), 0xFFFF0000)
		end
		
		if ValidTarget(Target) and settings.draw[GetSpellData(slot).name .. "collision"] ~= nil and settings.draw[GetSpellData(slot).name .. "collision"] == true and IsReady(slot) then
			local IsCollision = VPred:CheckMinionCollision(Target, Target.pos, spells[slot].delay, spells[slot].width, GetRange(slot), spells[slot].speed, myHero.pos,nil, true)
			DrawLine3D(myHero.x, myHero.y, myHero.z, Target.x, Target.y, Target.z, 5, IsCollision and ARGB(125, 255, 0,0) or ARGB(125, 0, 255,0))
		end
	end
	
	if not IsReady(sflash) or Target == nil then flashPos = nil end	
	if flashPos ~= nil and settings.draw.flashCombo ~= nil and settings.draw.flashCombo then
		if GetDistance(flashPos) < 425 and GetDistance(flashPos) > 405 then
			DrawCircle(flashPos.x, flashPos.y, flashPos.z, 50, 0xFF00FF00)
			DrawCircle(flashPos.x, flashPos.y, flashPos.z, 60, 0xFF00FF00)
			
			if myHero.charName == "Alistar" and IsReady(_W) then
				local endPos = Target + 650 * (Vector(Target) - Vector(flashPos)):normalized()
				DrawLine3D(Target.x, Target.y, Target.z, endPos.x, endPos.y, endPos.z, 5, ARGB(125, 0, 255,0))
			elseif myHero.charName == "Janna" and IsReady(_R) then
				for i, enemy in pairs(GetEnemyHeroes()) do
					if not enemy.dead and GetDistance(enemy) < 725 then
						local endPos = enemy + (875 - math.sqrt((enemy.x - flashPos.x) ^ 2 + (enemy.z - flashPos.z) ^ 2)) * (Vector(enemy) - Vector(flashPos)):normalized()
						DrawLine3D(enemy.x, enemy.y, enemy.z, endPos.x, endPos.y, endPos.z, 5, ARGB(125, 0, 255,0))
					end
				end
			end
		end
	end
	
	if myHero.charName == "Karma" then
		if objects["W"] ~= nil and settings.draw[GetSpellData(_W).name]  ~= nil and settings.draw[GetSpellData(_W).name] == true then
			DrawCircle(myHero.x, myHero.y, myHero.z, 1000, 0xFF00FF00)
		end
	end
end

function OnWndMsg(msg,key)
	if msg == WM_LBUTTONDOWN then
		local enemy, distance = ClosestEnemy(mousePos) 
		
		if distance < 150 then SelectedTarget = enemy end
	end
end

----------------------
--     Functions    --
----------------------
-- Menu --
function Menu()
	settings = scriptConfig("Support Heroes", "Support Heroes")
	
	-- Anti gap-close --
	if auto["dash"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName .. "] - Anti Dash", "dash")
			for i, slot in pairs(auto["dash"]) do
			
			settings.dash:addParam("info2", "-- Anti Dash Targets  --", SCRIPT_PARAM_INFO, "")
			
			for _, enemy in pairs(GetEnemyHeroes()) do
				settings.dash:addParam(enemy.charName, enemy.charName, SCRIPT_PARAM_ONOFF, true)
			end	
		settings.dash:addParam("info", "-- Settings  --", SCRIPT_PARAM_INFO, "")
				
				settings.dash:addParam(GetSpellData(slot).name, "Use " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
			
			settings.dash:addParam("buffer", "Range On Q", SCRIPT_PARAM_SLICE, 50, 0, 500, 0)	
	end
	
	-- Auto Interrupt --
	if auto["interrupt"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName .. "] - Auto-Interrupt", "interrupt")
			for i, slot in pairs(auto["interrupt"]) do
				settings.interrupt:addParam(GetSpellData(slot).name, "Use " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
			
			settings.interrupt:addParam("info", "-- Auto Interrupt Spells --", SCRIPT_PARAM_INFO, "")
			
			for i, enemy in pairs(GetEnemyHeroes()) do
				if Interrupt[enemy.charName] ~= nil then
					for i, spell in pairs(Interrupt[enemy.charName].stop) do
						settings.interrupt:addParam(spell.spellName, enemy.charName .." - " .. spell.name, SCRIPT_PARAM_ONOFF, true)
					end
				end
			end
	end
	
	-- Auto Snare Under Tower --
	if auto["snare"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName .. "] - Auto-Snare U/ Tower", "snare")
			for i, slot in pairs(auto["snare"]) do
				settings.snare:addParam(GetSpellData(slot).name, "Use " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
			
			settings.snare:addParam("distance", "Enemy distance from tower", SCRIPT_PARAM_SLICE, 800, 0, 875, 0)
			settings.snare:addParam("info", "-- Auto Snare Enemies --", SCRIPT_PARAM_INFO, "")
			
			for i, enemy in pairs(GetEnemyHeroes()) do
				settings.snare:addParam(enemy.charName, "Use on " .. enemy.charName, SCRIPT_PARAM_ONOFF, true)
			end
	end
	
		-- Anti gap-close --
	if auto["immobile"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName .. "] - Cast on Immobile", "immobile")
			for i, slot in pairs(auto["immobile"]) do
				settings.immobile:addParam(GetSpellData(slot).name, "Use " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
			
			settings.immobile:addParam("info", "-- Use on  --", SCRIPT_PARAM_INFO, "")
			
			for i, enemy in pairs(GetEnemyHeroes()) do
				settings.immobile:addParam(enemy.charName, enemy.charName, SCRIPT_PARAM_ONOFF, true)
			end
	end
	
	--Draws
	settings:addSubMenu("[" .. myHero.charName.. "] - Draw Settings", "draw")
		settings.draw:addParam("target", "Draw Target", SCRIPT_PARAM_ONOFF, true)
		settings.draw:addParam("permashow", "Draw PermaShow (reload)", SCRIPT_PARAM_ONOFF, true)
		
		for slot = _Q, _R  do
			if spells[slot].range ~= nil then
				settings.draw:addParam(GetSpellData(slot).name, "Draw " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
			
			if spells[slot].collision ~= nil and spells[slot].type ~= nil and spells[slot].collision == true and spells[slot].type == "linear" then
				settings.draw:addParam(GetSpellData(slot).name .. "collision", "Draw collision for " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, true)
			end
		end
		
		-- Humanizer --
	settings:addSubMenu("[" .. myHero.charName .. "] - Humanizer", "humanizer")
		settings.humanizer:addParam("interruptDelay", "Auto-Interrupt delay (ms)", SCRIPT_PARAM_SLICE, 200, 0, 500, 0)
		settings.humanizer:addParam("snareDelay", "Auto-Snare delay (ms)", SCRIPT_PARAM_SLICE, 0, 0, 500, 0)
		settings.humanizer:addParam("shieldDelay", "Auto Shield delay (ms)", SCRIPT_PARAM_SLICE, 50, 0, 500, 0)
		settings.humanizer:addParam("mikaelsDelay", "Mikaels delay (ms)", SCRIPT_PARAM_SLICE, 200, 0, 500, 0)
		settings.humanizer:addParam("block", "Block AA cancel with movement", SCRIPT_PARAM_ONOFF, true)
	
	-- Item Usage --
	settings:addSubMenu("[" .. myHero.charName .. "] - Item Settings", "items")
		settings.items:addParam("zhonya", "Use Zhonya below %", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
		settings.items:addParam("fqs", "Use Frost Queens in combo", SCRIPT_PARAM_ONOFF, true)
		
		settings.items:addSubMenu("Mikaels", "mikaels")
			settings.items.mikaels:addParam("info", "-- Use on Allies --", SCRIPT_PARAM_INFO, "")
			
			for i, ally in pairs(GetAllyHeroes()) do
				settings.items.mikaels:addParam(ally.charName, ally.charName, SCRIPT_PARAM_ONOFF, true)
			end
			
			settings.items.mikaels:addParam("info", "-- Use to remove --", SCRIPT_PARAM_INFO, "")
			
			for i,v in ipairs(ccTable) do
				if ccP[i] == 10 or ccP[i] == 11 or ccP[i] == 25 then settings.items.mikaels:addParam('ccType'..i, v, SCRIPT_PARAM_ONOFF, false)
				else settings.items.mikaels:addParam('ccType'..i, v, SCRIPT_PARAM_ONOFF, true) end
			end
			
			--Keys
			settings:addSubMenu("[" .. myHero.charName.. "] - Keys", "key")
		settings.key:addParam("comboKey", "Combo Key", SCRIPT_PARAM_ONKEYDOWN, false, 32)
		settings.key:addParam("harassKey", "Harass Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("C"))
		settings.key:addParam("harassToggle", "Harass Toggle", SCRIPT_PARAM_ONKEYTOGGLE, false, string.byte("T"))
		settings.key:addParam("clearKey", "Lane Clear Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("V"))
		settings.key:addParam("WardAssist", "Ward Assist", SCRIPT_PARAM_ONKEYDOWN, false, 32)
			
		if settings.draw.permashow then
			settings.key:permaShow("comboKey")
			settings.key:permaShow("harassKey")
			settings.key:permaShow("harassToggle")
			settings.key:permaShow("clearKey")
		end
			
			-- Anti gap-close --
	if auto["ks"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName .. "] - KS", "ks")
			for i, slot in pairs(auto["ks"]) do
				settings.ks:addParam(GetSpellData(slot).name, "Use " .. SpellPosition(slot), SCRIPT_PARAM_ONOFF, false)
			end
	end
			
	-- Lane Clear --
	if auto["clear"] ~= nil then 
		settings:addSubMenu("[" .. myHero.charName.. "] - Lane Clear", "clear")
			settings.clear:addParam("mana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
		
			for i, slot in pairs(auto["clear"]) do
				if (spells[slot].type == nil and spells[slot].center == nil) or (spells[slot].type == "linear" and spells[slot].collision == true) then
					settings.clear:addParam(GetSpellData(slot).name,"Use " .. SpellPosition(slot) .. "", SCRIPT_PARAM_ONOFF, true)
				else
					settings.clear:addParam(GetSpellData(slot).name,"Use " .. SpellPosition(slot) .. " for x minions", SCRIPT_PARAM_SLICE, 3, 0, 10, 0)
				end
			end
	end
	
	-- Spell Settings --
	settings:addSubMenu("[" .. myHero.charName .. "] - Spell Settings", "spell")
		if auto["attack"] then
			settings.spell:addSubMenu("[" .. myHero.charName .. "] - Passive", "passive")
			settings.spell.passive:addParam("apply", "Apply passive on enemies in range", SCRIPT_PARAM_ONOFF, true)
		end
	
		for i, slot in pairs(auto["combo"]) do
			settings.spell:addSubMenu("[" .. myHero.charName .. "] - " .. SpellPosition(slot), GetSpellData(slot).name)
			
			settings.spell[GetSpellData(slot).name]:addParam("combo", "Combo", SCRIPT_PARAM_ONOFF, true)
			if not (myHero.charName == "Sona" and slot == _E) then
				if slot ~= _R then 
					settings.spell[GetSpellData(slot).name]:addParam("harass", "Harass", SCRIPT_PARAM_ONOFF, true)
				else
					settings.spell[GetSpellData(slot).name]:addParam("harass", "Harass", SCRIPT_PARAM_ONOFF, false) 
				end
			end
			
			if spells[slot].range ~= nil then
				if myHero.charName == "Braum" and slot == _R then
					settings.spell[GetSpellData(slot).name]:addParam("range", "Maximum range", SCRIPT_PARAM_SLICE, spells[slot].range - 200, 0, spells[slot].range, 0)
				elseif myHero.charName == "Nami" and slot == _R then
					settings.spell[GetSpellData(slot).name]:addParam("range", "Maximum range", SCRIPT_PARAM_SLICE, 1500, 0, spells[slot].range, 0)
				else
					settings.spell[GetSpellData(slot).name]:addParam("range", "Maximum range", SCRIPT_PARAM_SLICE, spells[slot].range, 0, spells[slot].range, 0)
				end
			end
			
			if spells[slot].collision == false and spells[slot].aoe == true and myHero.charName ~= "Zilean" then
				if slot == _R then
					settings.spell[GetSpellData(slot).name]:addParam("enemies", "Minimum enemies hit", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
				elseif spells[slot].type == "circular" then
					settings.spell[GetSpellData(slot).name]:addParam("enemiesHarass", "Minimum enemies hit in Harass", SCRIPT_PARAM_SLICE, 1, 0, 5, 0)
					settings.spell[GetSpellData(slot).name]:addParam("enemiesCombo", "Minimum enemies hit in Combo", SCRIPT_PARAM_SLICE, 1, 0, 5, 0)
				end
			end
			
			if myHero.charName == "Thresh" and slot == _Q then
				settings.spell[GetSpellData(_Q).name]:addParam("cast", "Use Q2", SCRIPT_PARAM_ONOFF, true)
			end
			
			if spells[slot].select ~= nil and spells[slot].select == true then
				settings.spell[GetSpellData(slot).name]:addParam("info", "-- Use " .. SpellPosition(slot) .. " on --", SCRIPT_PARAM_INFO, "")
				settings.spell[GetSpellData(slot).name]:addParam("useBlackList", "Use Black List", SCRIPT_PARAM_ONKEYTOGGLE, true, string.byte("Y"))
				
				for i, enemy in pairs(GetEnemyHeroes()) do
					settings.spell[GetSpellData(slot).name]:addParam(enemy.charName, enemy.charName, SCRIPT_PARAM_ONOFF, true)
				end

				settings.spell[GetSpellData(slot).name]:permaShow("useBlackList")
			end
			
			if myHero.charName == "Karma" and slot == _W then
				settings.spell:addSubMenu("[" .. myHero.charName .. "] - E", GetSpellData(_E).name)
			end
		end

	-- Champion specific menu fields --
	if myHero.charName == "Annie" then
		settings.spell[GetSpellData(_W).name]:addParam("autoW", "Use in Fountain", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_E).name]:addParam("autoE", "Use when enemies are far", SCRIPT_PARAM_SLICE, 800, 0, 1000, 0)
		settings.spell[GetSpellData(_R).name]:addParam("autoR", "Move Tibbers automatically", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Braum" then
		settings.spell[GetSpellData(_W).name]:addParam("autoW", "Use W automatically", SCRIPT_PARAM_ONOFF, true)
	elseif  myHero.charName == "Blitzcrank" then
		settings.spell[GetSpellData(_E).name]:addParam("attack", "Automatically attack after use", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_E).name]:addParam("cast", "Automatically cast after landing Q", SCRIPT_PARAM_ONOFF, true) 
	elseif myHero.charName == "Karma" then
		settings.spell[GetSpellData(_E).name]:addParam("near", "Use in Combo if enemies are close", SCRIPT_PARAM_SLICE, 2000, 0, 3000, 0)
	
		settings.spell[GetSpellData(_R).name]:addParam("comboR", "In Combo use R with", SCRIPT_PARAM_LIST, 1, { "Q", "W", "E"})
		settings.spell[GetSpellData(_R).name]:addParam("harassR", "In Harass use R with", SCRIPT_PARAM_LIST, 1, { "Q", "W", "E"})
	elseif myHero.charName == "Leona" then
		settings.spell[GetSpellData(_Q).name]:addParam("ward", "Automatically clear wards", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_Q).name]:addParam("attack", "Automatically attack after use", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Morgana" then
		settings.spell[GetSpellData(_W).name]:addParam("cast", "Only use on enemies hit by Q", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Nami" then
		settings.spell[GetSpellData(_E).name]:addParam("autoE", "Auto use when someone attacks enemy", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Shen" then
		settings.spell[GetSpellData(_Q).name]:addParam("autoQ", "Auto use when someone attacks enemy", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_Q).name]:addParam("save", "Save energy for E", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Sona" then
		settings.spell[GetSpellData(_E).name]:addParam("near", "Only use if enemies are close", SCRIPT_PARAM_SLICE, 2000, 0, 3000, 0)
	elseif myHero.charName == "TahmKench" then
		settings.spell[GetSpellData(_W).name]:addParam("save", "Save allies from dangerous spells", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_W).name]:addParam("throw", "Auto throw minions", SCRIPT_PARAM_ONOFF, true)
	elseif myHero.charName == "Thresh" then
		settings.spell[GetSpellData(_W).name]:addParam("cast", "Use after Q", SCRIPT_PARAM_ONOFF, true)
		settings.spell[GetSpellData(_W).name]:addParam("hp", "Use if someone below % hp", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
	elseif myHero.charName == "Zilean" then
		settings.spell[GetSpellData(_E).name]:addParam("near", "Use on self if enemies are close", SCRIPT_PARAM_SLICE, 2000, 0, 3000, 0)
	elseif myHero.charName == "Zyra" then
		settings.spell[GetSpellData(_W).name]:addParam("autoW", "Use X seeds automatically", SCRIPT_PARAM_SLICE, 1, 0, 2, 0)
	end
		
		--Smart Heal
	if auto["heal"] ~= nil then
		settings:addSubMenu("[" .. myHero.charName .. "] - Smart Heal", "heal")
			settings.heal:addParam("coefficient", "Smart Heal Coefficient", SCRIPT_PARAM_SLICE, 20, 0, 50, 0)
			settings.heal:addParam("info", "Bigger coefficient = More heals", SCRIPT_PARAM_INFO, "")
	end
	
	--Target Selector
		settings:addSubMenu("[" .. myHero.charName .. "] - Target Selector", "target")
		settings.target:addParam("sac", "Get SAC:R target", SCRIPT_PARAM_ONOFF, false)
		settings.target:addParam("focus", "Prioritize focus", SCRIPT_PARAM_ONOFF, true)
		settings.target:addParam("range", "Focus even if out of range by", SCRIPT_PARAM_SLICE, 0, 0, 1000, 0)
		
	-- Flash Combo --
	if (myHero.charName == "Alistar" or myHero.charName == "Annie" or myHero.charName == "Janna" or myHero.charName == "Blitzcrank" or myHero.charName == "Thresh" or myHero.charName == "Morgana" or myHero.charName == "Lux" or myHero.charName == "Nautilus" or myHero.charName == "Shen") and sflash ~= nil then
		settings.draw:addParam("flashCombo", "Flash Combo", SCRIPT_PARAM_ONOFF, true)
		settings.key:addParam("flashKey", "Flash Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("H"))
		settings.key:permaShow("flashKey")
	end
	
	-- Flash Combo --
	if auto["marathon"] ~= nil then
		settings.key:addParam("marathon", "Marathon Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("Y"))
		settings.key:permaShow("marathon")
	end
	
	-- Auto Shield --
	if typeshield ~= nil then
		settings:addSubMenu("[AS] - Auto Shield", "as")
		for i=1, heroManager.iCount do
			local teammate = heroManager:GetHero(i)
			if teammate.team == myHero.team then settings.as:addParam("teammateshield"..i, "Shield "..teammate.charName, SCRIPT_PARAM_ONOFF, true) end
		end
		
		if myHero.charName == "TahmKench" then settings.as:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 15, 0, 100, 0)
		else settings.as:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)	end
		
		if myHero.charName == "TahmKench" then settings.as:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 10, 0, 100, 0)
		else settings.as:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 10, 0, 100, 0) end 
		
		settings.as:addParam("skillshots", "Shield Skillshots", SCRIPT_PARAM_ONOFF, true)
		settings.as:addParam("shieldcc", "Auto Shield Hard CC", SCRIPT_PARAM_ONOFF, true)
		settings.as:addParam("shieldslow", "Auto Shield Slows", SCRIPT_PARAM_ONOFF, true)
	end
	
	-- Auto Heal -- 
	if typeheal ~= nil then
		settings:addSubMenu("[AS] - Auto Heal", "ah")
		for i=1, heroManager.iCount do
			local teammate = heroManager:GetHero(i)
			if teammate.team == myHero.team then settings.ah:addParam("teammateheal"..i, "Heal "..teammate.charName, SCRIPT_PARAM_ONOFF, true) end
		end
		settings.ah:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)	
		settings.ah:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 10, 0, 100, 0)
		settings.ah:addParam("skillshots", "Heal Skillshots", SCRIPT_PARAM_ONOFF, true)
	end
	
	-- Auto Ult --
	if typeult ~= nil then
		settings:addSubMenu("[AS] - Auto Ultimate", "au")
		for i=1, heroManager.iCount do
			local teammate = heroManager:GetHero(i)
			if teammate.team == myHero.team then settings.au:addParam("teammateult"..i, "Ult "..teammate.charName, SCRIPT_PARAM_ONOFF, true) end
		end
		settings.au:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)	
		settings.au:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 50, 0, 100, 0)
		settings.au:addParam("skillshots", "Skillshots", SCRIPT_PARAM_ONOFF, true)
	end
	
	-- Auto Wall --
	if wallslot ~= nil then
		settings:addSubMenu("[AS] - Auto Wall", "aw")
		settings.aw:addParam("wallon", "Auto Wall", SCRIPT_PARAM_ONOFF, true)
		settings.aw:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)	
		settings.aw:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 10, 0, 100, 0)
		settings.aw:addParam("skillshots", "Shield Skillshots", SCRIPT_PARAM_ONOFF, true)
		settings.aw:addParam("shieldcc", "Auto Shield Hard CC", SCRIPT_PARAM_ONOFF, true)
		settings.aw:addParam("shieldslow", "Auto Shield Slows", SCRIPT_PARAM_ONOFF, true)
	end
	
	-- Auto Barrier --
	if sbarrier ~= nil then
		settings:addSubMenu("[AS] - Auto Summoner Barrier", "asb")
		settings.asb:addParam("barrieron", "Barrier", SCRIPT_PARAM_ONOFF, true)
		settings.asb:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)
		settings.asb:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 95, 0, 100, 0)
		settings.asb:addParam("skillshots", "Shield Skillshots", SCRIPT_PARAM_ONOFF, true)
	end
	
	-- Auto Heal --
	if sheal ~= nil then
		settings:addSubMenu("[AS] - Auto Summoner Heal", "ash")
		for i=1, heroManager.iCount do
			local teammate = heroManager:GetHero(i)
			if teammate.team == myHero.team then settings.ash:addParam("teammatesheal"..i, "Heal "..teammate.charName, SCRIPT_PARAM_ONOFF, false) end
		end
		settings.ash:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)
		settings.ash:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 95, 0, 100, 0)
		settings.ash:addParam("skillshots", "Heal Skillshots", SCRIPT_PARAM_ONOFF, true)
	end

	-- Auto Items --
	if useitems then
		settings:addSubMenu("[AS] - Auto Shield Items", "asi")
		for i=1, heroManager.iCount do
			local teammate = heroManager:GetHero(i)
			if teammate.team == myHero.team then settings.asi:addParam("teammateshieldi"..i, "Shield "..teammate.charName, SCRIPT_PARAM_ONOFF, true) end
		end
		settings.asi:addParam("maxhppercent", "Max percent of hp", SCRIPT_PARAM_SLICE, 100, 0, 100, 0)
		settings.asi:addParam("mindmgpercent", "Min dmg percent", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		settings.asi:addParam("skillshots", "Shield Skillshots", SCRIPT_PARAM_ONOFF, true)
	end
	
	settings:addSubMenu("Ward Assist", "Ward")
	WA = WA(settings.Ward)
	
	settings:addSubMenu("Orbwalk Settings", "orb")
	
	SetupOrbwalk()
    UPL:AddToMenu(settings) 
end

function SetupOrbwalk()
	if _G.AutoCarry then
		if _G.Reborn_Initialised then
			Customprint("Found SAC: Reborn")
			settings.orb:addParam("Info", "SAC: Reborn detected!", SCRIPT_PARAM_INFO, "")
			orbwalker = "sac"
		end
	elseif _G.Reborn_Loaded then
		DelayAction(function() SetupOrbwalk() end, 1)
	elseif FileExist(LIB_PATH .. "SxOrbWalk.lua") then
		require 'SxOrbWalk'
		SxOrb = SxOrbWalk()
		SxOrb:LoadToMenu(settings.orb)
		Customprint("Found SxOrb.")
		orbwalker = "vp"
	else
		Customprint("No valid Orbwalker found")
	end
end

-- Auto Shield Function --
function shieldCheck(object,spell,target,typeused)
	local configused
	
	if typeused == "shields" then configused = settings.as
	elseif typeused == "heals" then configused = settings.ah
	elseif typeused == "ult" then configused = settings.au
	elseif typeused == "wall" then configused = settings.aw
	elseif typeused == "barrier" then configused = settings.asb 
	elseif typeused == "sheals" then configused = settings.ash
	elseif typeused == "items" then configused = settings.asi end
	
	local shieldflag = false
	if (not configused.skillshots and shottype ~= 0) then return false, 0 end
	local adamage = object:CalcDamage(target,object.totalDamage)
	local InfinityEdge,onhitdmg,onhittdmg,onhitspelldmg,onhitspelltdmg,muramanadmg,skilldamage,skillTypeDmg = 0,0,0,0,0,0,0,0

	if object.type ~= "AIHeroClient" then
		if spell.name:find("BasicAttack") then skilldamage = adamage
		elseif spell.name:find("CritAttack") then skilldamage = adamage*2 end
	else
		if GetInventoryHaveItem(3091,object) then onhitdmg = onhitdmg+getDmg("WITSEND",target,object) end
		if GetInventoryHaveItem(3057,object) then onhitdmg = onhitdmg+getDmg("SHEEN",target,object) end
		if GetInventoryHaveItem(3078,object) then onhitdmg = onhitdmg+getDmg("TRINITY",target,object) end
		if GetInventoryHaveItem(3100,object) then onhitdmg = onhitdmg+getDmg("LICHBANE",target,object) end
		if GetInventoryHaveItem(3025,object) then onhitdmg = onhitdmg+getDmg("ICEBORN",target,object) end
		if GetInventoryHaveItem(3087,object) then onhitdmg = onhitdmg+getDmg("STATIKK",target,object) end
		if GetInventoryHaveItem(3153,object) then onhitdmg = onhitdmg+getDmg("RUINEDKING",target,object) end
		if GetInventoryHaveItem(3042,object) then muramanadmg = getDmg("MURAMANA",target,object) end
		if GetInventoryHaveItem(3184,object) then onhittdmg = onhittdmg + 80 end
		
		if spelltype == "BAttack" then
			skilldamage = (adamage+onhitdmg+muramanadmg)*1.07+onhittdmg
		elseif spelltype == "CAttack" then
			if GetInventoryHaveItem(3031,object) then InfinityEdge = .5 end
			skilldamage = (adamage*(2.1+InfinityEdge)+onhitdmg+muramanadmg)*1.07+onhittdmg --fix Lethality
		elseif spelltype == "Q" or spelltype == "W" or spelltype == "E" or spelltype == "R" or spelltype == "P" or spelltype == "QM" or spelltype == "WM" or spelltype == "EM" then
			if GetInventoryHaveItem(3151,object) then onhitspelldmg = getDmg("LIANDRYS",target,object) end
			muramanadmg = skillShield[object.charName][spelltype]["Muramana"] and muramanadmg or 0
			
			if spelltype == "Q" or spelltype == "QM" then
				level = object:GetSpellData(_Q).level
			elseif spelltype == "W" or spelltype == "WM" then
				level = object:GetSpellData(_W).level
			elseif spelltype == "E" or spelltype == "EM" then
				level = object:GetSpellData(_E).level
			elseif spelltype == "R" then
				level = object:GetSpellData(_R).level
			else
				level = 1
			end
				
			
			
			if casttype == 1 or casttype == 2 or casttype == 3 then
				skilldamage, skillTypeDmg = getDmg(spelltype,target,object, casttype, level)
			end
						
			if skillTypeDmg == 2 then
				skilldamage = (skilldamage+adamage+onhitspelldmg+onhitdmg+muramanadmg)*1.07+onhittdmg+onhitspelltdmg
			else
				if skilldamage > 0 then skilldamage = (skilldamage+onhitspelldmg+muramanadmg)*1.07+onhitspelltdmg end
			end
			
		elseif spell.name:lower():find("summonerdot") then
			skilldamage = getDmg("IGNITE",target,object)
		end
	end
	
	local dmgpercent = skilldamage*100/target.health
	local dmgneeded = dmgpercent >= configused.mindmgpercent
	local hpneeded = configused.maxhppercent >= (target.health-skilldamage)*100/target.maxHealth
	
	if dmgneeded and hpneeded then
		shieldflag = true
	elseif (typeused == "shields" or typeused == "wall") and ((CC == 2 and configused.shieldcc) or (CC == 1 and configused.shieldslow)) then
		shieldflag = true
	end
	
	return shieldflag, dmgpercent
end

-- Load Spells Into UPL --
function LoadSpells()
	for spell = _Q, _R  do
		if spells[spell].type ~= nil then
			UPL:AddSpell(spell, { speed = spells[spell].speed, delay = spells[spell].delay, range = spells[spell].range, width = spells[spell].width, collision = spells[spell].collision, aoe = spells[spell].aoe, type = spells[spell].type })
		end
	end
end

-- Get Health between 0-100 --
function GetHealthPercent(unit)
    local obj = unit or myHero
    return (obj.health / obj.maxHealth) * 100
end

-- Get Mana between 0-100 --
function GetManaPercent(unit)
    local obj = unit or myHero
    return (obj.mana / obj.maxMana) * 100
end

-- Get inventory slot --
function CustomGetInventorySlotItem(item, unit)
	for slot = ITEM_1, ITEM_7 do
		if unit:GetSpellData(slot).name:lower() == item:lower() then
			return slot
		end
	end
	
	return nil
end

-- Get the spell with biggest range --
function BiggestRange(spellList)
	local range = myTrueRange
	local spellRange = 0
	
	if spellList == nil and myHero.charName == "Braum" then return GetRange(_W) + 300 end
	if spellList == nil then return range end
	
	for i, slot in pairs(spellList) do
		if IsReady(slot) then
			spellRange = GetRange(slot) or 0	
			if spells[slot].type == "circular" then spellRange = spellRange + spells[slot].width end
			if myHero.charName == "Zilean" and slot == _W then spellRange = GetRange(_Q) end
			if myHero.charName == "Lulu" and slot == _Q then spellRange = GetDistance(objects["faerie"]) + GetRange(_Q) end

			if spellRange > 2000 then
				spellRange = 0
			end
			
			if range < spellRange then
				range = spellRange
			end
		end
	end
	
	return range
end

function ClosestEnemy(pos)
	if pos == nil then return math.huge, nil end
	local closestEnemy, distanceEnemy = nil, math.huge
	
	for i, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.dead then 
			if GetDistance(pos, enemy) < distanceEnemy then
				distanceEnemy = GetDistance(pos, enemy)
				closestEnemy = enemy
			end
		end
	end
	
	return closestEnemy, distanceEnemy
end

function AngleDifference(from, p1, p2)
	local p1Z = p1.z - from.z
	local p1X = p1.x - from.x
	local p1Angle = math.atan2(p1Z , p1X) * 180 / math.pi
	
	local p2Z = p2.z - from.z
	local p2X = p2.x - from.x
	local p2Angle = math.atan2(p2Z , p2X) * 180 / math.pi
	
	return math.sqrt((p1Angle - p2Angle) ^ 2)
end

-- Get a position that is in range of the spell --
function Normalize(pos, start, range)
	local castX = start.x + range * ((pos.x - start.x) / GetDistance(pos))
	local castZ = start.z + range * ((pos.z - start.z) / GetDistance(pos))
	
	return {x = castX, z = castZ}
end

-- Get Target --
function GetTarget()
	ts:update()
	if _G.AutoCarry and _G.AutoCarry.Crosshair and ValidTarget(_G.AutoCarry.Crosshair:GetTarget()) and settings.target.sac then _G.AutoCarry.Crosshair:SetSkillCrosshairRange(BiggestRange(auto["combo"])) return _G.AutoCarry.Crosshair:GetTarget() end
	if SelectedTarget ~= nil and not SelectedTarget.dead and SelectedTarget.type == myHero.type and SelectedTarget.team ~= myHero.team and settings.target.focus then
		if GetDistance(SelectedTarget) > BiggestRange(auto["combo"]) + settings.target.range and ts.target ~= nil then
			return ts.target
		else
			return SelectedTarget
		end
	end
	return ts.target
end

-- Get Target only for Zilean --
function ZileanTarget()
	if objects["Q"] ~= nil then
		if GetDistance(objects["Q"]) < GetRange(_Q) then
			for i = 1, heroManager.iCount, 1 do
				local hero = heroManager:getHero(i)
				if GetDistance(hero, objects["Q"]) < 20 then
					if hero.team ~= myHero.team then
						return hero
					end
				end
			end
		end
	end
	
	return GetTarget()
end

-- Checks the menu for minimum enemy hits to proceed --
function HitsRequired(slot)
	if settings.key.comboKey and settings.spell[GetSpellData(slot).name].enemiesCombo ~= nil then return settings.spell[GetSpellData(slot).name].enemiesCombo
	elseif settings.spell[GetSpellData(slot).name].enemiesHarass ~= nil then return settings.spell[GetSpellData(slot).name].enemiesHarass
	elseif settings.spell[GetSpellData(slot).name].enemies ~= nil then return settings.spell[GetSpellData(slot).name].enemies
	else return 1 end
end

-- Finds the best position for cast --
function FindBestCircle(target, range, radius, slot)
	local points = {}
	
	local rgDsqr = (range + radius) * (range + radius)
	local diaDsqr = (radius * 2) * (radius * 2)

	local Position = VPred:GetPredictedPos(target, spells[slot].delay)

	table.insert(points,Position)
	
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if enemy.networkID ~= target.networkID and not enemy.dead and GetDistanceSqr(enemy) <= rgDsqr and GetDistanceSqr(target,enemy) < diaDsqr then
			local Position = VPred:GetPredictedPos(enemy, spells[slot].delay)
			table.insert(points, Position)
		end
	end
	
	while true do
		local MECObject = MEC(points)
		local OurCircle = MECObject:Compute()
		
		if OurCircle.radius <= radius then
			return OurCircle.center, #points
		end
		
		local Dist = -1
		local MyPoint = points[1]
		local index = 0
		
		for i=2, #points, 1 do
			local DistToTest = GetDistanceSqr(points[i], MyPoint)
			if DistToTest >= Dist then
				Dist = DistToTest
				index = i
			end
		end
		if index > 0 then
			table.remove(points, index)
		else
			return points[1], 1
		end
	end
end

function SpellPosition(slot)
	if slot == _Q then return "Q"
	elseif slot == _W then return "W"
	elseif slot == _E then return "E"
	elseif slot == _R then return "R"
	end
end

function SmartHeal(slot, unit)
	local points = 0
	
	if unit.health + GetHeal(unit) + unit.maxHealth * 0.1 > unit.maxHealth then return math.huge end
	 
	if myHero.charName == "Soraka" then
		if unit.health / unit.maxHealth > 0.90 then return math.huge end
		if myHero.health / myHero.maxHealth > 0.5 then
			points = (100 / myHero.mpRegen) * (1.01 - (myHero.health / myHero.maxHealth)) * (unit.health / unit.maxHealth)
		else
			points = (100 / myHero.mpRegen) * (1.01 - (myHero.health / myHero.maxHealth)) * (unit.health / unit.maxHealth) * 2
		end
	else
		points = (100 / myHero.mpRegen) * (1.01 - (myHero.mana / myHero.maxMana)) * (unit.health / unit.maxHealth)
	end
	
	return points
end

function CountObjectHitOnLine(slot, from, target, objects)
	return CountObjectsOnLineSegment(from, Normalize(target, from, spells[slot].range), spells[slot].width, objects)
end
----------------------
-- Clear Functions  --
----------------------

-- Gets Best Position To Cast Spell For Farming --
function GetBestFarmPosition(range, width, objects, type, collision)
    local BestPos 
    local BestHit = 0
    for i, object in ipairs(objects) do
		local hit, EndPos = 0, nil
	
		if type == "circular" then
			if GetDistance(object) < range then
				hit = CountObjectsInCircle(object, width, objects)
			end
		elseif type == "linear" and collision == false then
			EndPos = Vector(myHero) + range * (Vector(object) - Vector(myHero)):normalized()
			hit = CountObjectsOnLineSegment(myHero, EndPos, width, objects)
		else
			return object, 1
		end
			
        if hit > BestHit then
            BestHit = hit
            BestPos = object
            if BestHit == #objects then
               break
            end
         end
    end
    return BestPos, BestHit
end

-- Gets amount of minions on a line --
function CountObjectsOnLineSegment(StartPos, EndPos, width, objects)
    local n = 0
    for i, object in ipairs(objects) do
		if not object.dead then
			local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, object)
			if isOnSegment and GetDistanceSqr(pointSegment, object) < width * width and GetDistanceSqr(StartPos, EndPos) > GetDistanceSqr(StartPos, object) then
				n = n + 1
			end
		end
    end
    return n
end

-- Gets amount of minions in a circle --
function CountObjectsInCircle(pos, radius, array)
	if not pos then return -1 end
	if not array then return -1 end

    local n = 0
    for _, object in pairs(array) do
        if GetDistance(pos, object) <= radius and not object.dead then n = n + 1 end 
    end
    return n
end

----------------------
--  Spell Functions --
----------------------
----------------------
--     General      --
----------------------

-- Custom Cast Function --
function CustomCast(spell, target, from, antiKS, chance)
	antiKS = antiKS or true
	from = from or myHero
	chance = chance or 2
	
	if myHero.charName == "Janna" and buffs["moveBlock"] then return end
	if not target or target.dead then return end
	if myHero.dead then return end
	if not IsReady(spell) then return end
	if spells[spell].range ~= nil and GetDistance(from, target) > GetRange(spell) then return end
	
	if target.isMe then CastSpell(spell) end
	if spells[spell].type ~= nil and spells[spell].width ~= nil and spells[spell].delay ~= nil and spells[spell].range ~= nil and spells[spell].width ~= nil then
		local CastPosition, HitChance, HeroPosition = UPL:Predict(spell, from, target)		
		if HitChance >= chance and GetDistance(CastPosition) < GetRange(spell) then
			if myHero.charName == "Nautilus" and spell == _Q and CalculatePath(myHero, D3DXVECTOR3(CastPosition.x, CastPosition.y, CastPosition.z)).count ~= 2 then return end
		
			CastSpell(spell, CastPosition.x, CastPosition.z)
		end
	else
		CastSpell(spell, target)
	end
end

-- Check if spell is ready --
function IsReady(spell)
	if not spell then return false end
	if CanUseSpell(spell) == READY then return true end
	return false
end

function GetHeal(unit)
	if myHero.charName == "Alistar" and not unit.isMe then return 15 + 15 * GetSpellData(healslot).level + myHero.ap * 0.1 end
	if myHero.charName == "Alistar" and unit.isMe then return 30 + 30 * GetSpellData(healslot).level + myHero.ap * 0.2 end
	if myHero.charName == "Taric" and not unit.isMe then return 20 + 40 * GetSpellData(healslot).level + myHero.ap * 0.3 end
	if myHero.charName == "Taric" and unit.isMe then return (20 + 40 * GetSpellData(healslot).level + myHero.ap * 0.3) * 1.4 end
	if myHero.charName == "Nami" then return 35 + 30 * GetSpellData(healslot).level + myHero.ap * 0.3 end
	if myHero.charName == "Sona" then return (10 + 20 * GetSpellData(healslot).level + myHero.ap * 0.2) * (1 + (1 - (unit.health / unit.maxHealth)) / 2) end
	if myHero.charName == "Soraka" then return (15 + 10 * GetSpellData(healslot).level + myHero.ap * 0.4) * (1 + (1 - (myHero.health / myHero.maxHealth))) end
end

-- Lane Clear --
function LaneClear()
	if GetManaPercent(myHero) >= settings.clear.mana and os.clock() - LastFarmRequest > TIME_BETWEEN_FARM_REQUESTS then
		EnemyMinions:update()
		
		for i, minion in pairs(EnemyMinions.objects) do
			for i, slot in pairs(auto["clear"]) do
				if GetDistance(minion) < spells[slot].range and not minion.dead then

					if spells[slot].type == nil and spells[slot].center == nil and IsReady(slot) and settings.clear[GetSpellData(slot).name] then
						local BestPos, Count = GetBestFarmPosition(spells[slot].range, spells[slot].width, EnemyMinions.objects, spells[slot].type, spells[slot].collision)
						if BestPos ~= nil then 
							CastSpell(slot, BestPos) 
						end
					elseif spells[slot].type == nil and spells[slot].center and IsReady(slot) and settings.clear[GetSpellData(slot).name] > 0 then
						local Count = CountObjectsInCircle(spells[slot].center, spells[slot].range, EnemyMinions.objects)
						if Count >= settings.clear[GetSpellData(slot).name] then
							CastSpell(slot) 
						end
					elseif spells[slot].type == "linear" and spells[slot].collision == true and IsReady(slot) and settings.clear[GetSpellData(slot).name] then
						local BestPos, Count = GetBestFarmPosition(spells[slot].range, spells[slot].width, EnemyMinions.objects, spells[slot].type, spells[slot].collision)
						if BestPos ~= nil then 
							CastSpell(slot, Normalize(BestPos, myHero, spells[slot].range).x, Normalize(BestPos, myHero, spells[slot].range).z) 
						end
					elseif settings.clear[GetSpellData(slot).name] ~=  nil and settings.clear[GetSpellData(slot).name] ~= true and  settings.clear[GetSpellData(slot).name] ~= false and settings.clear[GetSpellData(slot).name] > 0 and IsReady(slot) then
						local BestPos, Count = nil, 0
						
						if myHero.charName == "Zilean" and slot == _Q then
							BestPos, Count = GetBestFarmPosition(spells[slot].range, 330, EnemyMinions.objects, spells[slot].type, spells[slot].collision)
						else
							BestPos, Count = GetBestFarmPosition(spells[slot].range, spells[slot].width, EnemyMinions.objects, spells[slot].type, spells[slot].collision)
						end
							
						if BestPos ~= nil and Count >= settings.clear[GetSpellData(slot).name] then 
							if spells[slot].type == "Linear" then
								CastSpell(slot, Normalize(BestPos, myHero, spells[slot].range).x, Normalize(BestPos, myHero, spells[slot].range).z) 
							else
								CastSpell(slot, BestPos) 
							end
						end
					end
				end
			end
        end
		
		LastFarmRequest = os.clock()
	end
end

-- Checks if spell can be used for Combo or Harass --
function UseSpell(slot)
	if not IsReady(slot) then return false end
	if not settings.spell[GetSpellData(slot).name] then return false end
	if settings.key.comboKey and settings.spell[GetSpellData(slot).name].combo then return true end
	if (settings.key.harassKey or settings.key.harassToggle) and settings.spell[GetSpellData(slot).name].harass then return true end
	return false
end
 
 -- Gets the wanted range of a spell --
function GetRange(slot)
	if settings.spell[GetSpellData(slot).name] ~= nil and settings.spell[GetSpellData(slot).name].range ~= nil then return settings.spell[GetSpellData(slot).name].range end
	if spells[slot].range ~= nil then return spells[slot].range end
	return 0
end

-- Checks if enemy is enabled in the menu --
function SelectedEnemy(slot, unit)
	if settings.spell[GetSpellData(slot).name] == nil then return true end
	if settings.spell[GetSpellData(slot).name].info == nil then return true end
	if settings.spell[GetSpellData(slot).name].useBlackList == false then return true end
	if settings.spell[GetSpellData(slot).name][unit.charName] then return true end
	return false
end

-- Get point on a line closest to the target --
function pointOnLine(End, Start, unit, extra, range)
	local toUnit = {x = unit.x - Start.x, z = unit.z - Start.z}
	local toEnd = {x = End.x - Start.x, z = End.z - Start.z}

	local magitudeToEnd = toEnd.x ^ 2 + toEnd.z ^ 2
	local dotP = toUnit.x * toEnd.x + toUnit.z * toEnd.z

	local distance = dotP / magitudeToEnd
	local x, z = Start.x + toEnd.x * (distance + extra), Start.z + toEnd.z * (distance + extra)
	
	if math.sqrt((x - myHero.x) ^ 2 + (z - myHero.z) ^ 2) < range then 
		return {x = x, z = z}
	else
		return Normalize({x = Start.x + toEnd.x * (distance + extra), z = Start.z + toEnd.z * (distance + extra)}, myHero, range)
	end
end

function Latency()
	return GetLatency() / 2000
end

----------------------
--    Champion      --
----------------------

-- Cast array of spells --
function CastArray(spellList, setting, special, object, delay, damage)
	damage = damage or false
	
	for i, slot in pairs(spellList) do
		if damage then
			if getDmg("Q", object, myHero) < object.health then return end
		end
		
		if setting[GetSpellData(slot).name] and GetSpellData(_Q).name ~= "threshqleap" then
			if special then
				if myHero.charName == "Annie" then
					AnnieStun(slot, object, delay)
				elseif myHero.charName == "Lulu" then
					if slot == _W then
						DelayAction(function() CustomCast(slot, object) end, delay / 1000)
					else
						local bestTarget = nil
						
						for _, ally in ipairs(GetAllyHeroes()) do
							if GetDistance(ally, object) < spells[slot].width then
								if bestTarget == nil then bestTarget = ally end
								if ally.health < bestTarget.health then bestTarget = ally end
							end
						end
						
						if bestTarget then CustomCast(slot, bestTarget) end
					end
				end
			else
				DelayAction(function() CustomCast(slot, object) end, delay / 1000)
			end
		end
	end 
end

-- Cast Anti Dash --
function CastDash()
	if myHero.charName == "Janna" and buffs["moveBlock"] then return end
	for i, spell in ipairs(dashSpells) do
		if GetDistance(spell.startPosition, spell.endPosition) < (os.clock() -  spell.delay - spell.time) * spell.speed then
			table.remove(dashSpells, i)
		end
		
		if auto["dash"] then
			for i, slot in pairs(auto["dash"]) do
				local timeToHit = 0
				local castPos
			
				if spells[slot].delay and spells[slot].speed then
					timeToHit = spells[slot].delay + (GetDistance(spell.endPosition) / spells[slot].speed)
				end
				
				if (os.clock() - spell.delay - spell.time + timeToHit) < 0 then
					castPos = spell.startPosition
				else		
					if (os.clock() - spell.delay - spell.time + timeToHit) * spell.speed > GetDistance(spell.startPosition, spell.endPosition) then castPos = spell.endPosition
					else castPos = Vector(spell.startPosition) + (Vector(spell.endPosition) - Vector(spell.startPosition)):normalized() * (os.clock() - spell.delay - spell.time + timeToHit) * spell.speed end
				end
				
				if GetSpellData(_Q).name ~= "threshqleap" and settings.dash[GetSpellData(slot).name] then
					local target = castPos
					antiKS = antiKS or true
					from = from or myHero
					
					if myHero.dead then return end
					if CanUseSpell(slot) ~= READY then return end
					if spells[slot].range ~= nil and GetDistance(from, target) > GetRange(slot) - settings.dash.buffer then return end
					
					if spells[slot].type and spells[slot].width and spells[slot].delay and spells[slot].range and spells[slot].width then	
						local IsCollision = VPred:CheckMinionCollision(target, target, spells[slot].delay, spells[slot].width, GetRange(slot), spells[slot].speed, myHero.pos,nil, true)
						
						if IsCollision == false or spells[slot].collision == false then
							if GetDistance(castPos) > 200 then
							
								CastSpell(slot, castPos.x, castPos.z)
								table.remove(dashSpells, i)
								return
							end
						end
					else
						if myHero.charName == "Thresh" then ThreshCastE(spell.unitPosition)
						else CastSpell(slot, castPos.x, castPos.z) end
						
						table.remove(dashSpells, i)
						return
					end
				end
			end
		end
	end
end

function Attack(unit)
	if unit == nil then return end
	if unit.type == myHero.type then
		if GetDistance(unit) > myTrueRange then return end
		if orbwalker == "sac" and _G.AutoCarry then
			_G.AutoCarry.Crosshair:ForceTarget(_G.AutoCarry.Orbwalker:CanOrbwalkTarget(unit) and unit or nil)
		elseif orbwalker == "vp" then
			SxOrb:ForceTarget(unit)
		else
			myHero:Attack(unit)
		end
	else
		myHero:Attack(unit)
	end
end

function DisableMovement()
	if orbwalker == "vp" then SxOrb:DisableMove() end
	buffs["moveBlock"] = true
end

function EnableMovement()
	if orbwalker == "vp" then SxOrb:EnableMove() end
	buffs["moveBlock"] = false
end

function FlashCombo(slot, target, block)
	if IsReady(slot) then
		buffs["moveBlock"] = true
		CastSpell(slot, target)
	else	
		buffs["moveBlock"] = block
		return
	end
	
	DelayAction(function() FlashCombo(slot, target, block) end, 0.01)
end

function FlashComboPosition(slot, x, z)
	if IsReady(slot) and type(x) == "number" and type(z) == "number" and type(slot) == "number" then
		CastSpell(slot, x, z)
	else	
		return
	end
	
	DelayAction(function() FlashComboPosition(slot, x, z) end, 0.01)
end

function ShenFlash(slot, shenTarget)
	if IsReady(slot) and shenTarget and type(slot) == "number" and GetDistance(shenTarget) < 425 then
		CastSpell(slot, shenTarget.x, shenTarget.z)
	elseif not IsReady(slot) or GetDistance(shenTarget) > 1200 then	
		return
	end
	
	DelayAction(function() ShenFlash(slot, shenTarget) end, 0.01)
end

function Combo(unit)
	if not ValidTarget(unit) then return end
	
	local hasTower = false
	if settings.key.flashKey ~= nil then
		if not IsReady(sflash) then 
			flashPos = nil
		end
	
		if myHero.charName == "Annie" then
			if IsReady(sflash) and GetDistance(unit) <= 425 + GetRange(_R) and IsReady(_R) and buffs["canStun"] then
				local Position = FindBestCircle(unit, GetRange(_R) + 425, spells[_R].width, _R)
				flashPos = myHero + 425 * (Vector(Position) - Vector(myHero)):normalized()
				
				if GetDistance(flashPos) > 425 then
					flashPos = nil
				end
				
				if flashPos ~= nil and settings.key.flashKey then
					if myHero.mana > 100 then
						if GetDistance(unit) > GetRange(_R) then
							CastSpell(sflash, flashPos.x, flashPos.z)
						end
						FlashCombo(_R, unit, false)
					end
				end
			end
		end
		
		if myHero.charName == "Thresh" then
			if IsReady(sflash) and IsReady(_E) and myHero.mana > 55 + 5 * GetSpellData(_E).level and GetDistance(unit) <= 425 + GetRange(_E) and GetDistance(unit) > GetRange(_E) then
				flashPos = myHero + 425 * (Vector(unit) - Vector(myHero)):normalized()
				local castPosition = Vector(flashPos) + 400 * (Vector(flashPos) - Vector(unit)):normalized()
				
				if settings.key.flashKey then	
					CastSpell(sflash, flashPos.x, flashPos.z)
					FlashComboPosition(_E, castPosition.x, castPosition.z)
				end
			end
		end
		
		if myHero.charName == "Blitzcrank" or myHero.charName == "Thresh" or myHero.charName == "Morgana" or myHero.charName == "Lux" or myHero.charName == "Nautilus" then
			if IsReady(sflash) and IsReady(_Q) and myHero.mana > GetSpellData(_Q).mana and GetDistance(unit) <= 425 + GetRange(_Q) then
				if GetDistance(unit) < 425 then
					flashPos = myHero + (GetDistance(unit) - 50) * (Vector(unit) - Vector(myHero)):normalized()
				else
					flashPos = myHero + 425 * (Vector(unit) - Vector(myHero)):normalized()
				end
				
				if settings.key.flashKey then
					local CastPosition, HitChance = UPL:Predict(_Q, flashPos, unit)		
					
					if HitChance >= 2 and type(CastPosition.x) == "number" and type(CastPosition.z) == "number" then
						flashPos = myHero + 425 * (Vector(CastPosition) - Vector(myHero)):normalized()
						
						CastSpell(sflash, flashPos.x, flashPos.z)
						FlashComboPosition(_Q, CastPosition.x, CastPosition.z)
					end
				end
			end
		end
		
		if myHero.charName == "Shen" then
			if IsReady(sflash) and IsReady(_E) and myHero.mana > 110 - 10 * GetSpellData(_E).level then
				flashPos = unit
				
				if settings.key.flashKey then
					local Position = VPred:GetPredictedPos(unit, 0.5)
					local lastPosition = VPred:GetPredictedPos(unit, 1)						
					
					if GetDistance(lastPosition) <= 1000 and GetDistance(Position) > 600 then
						CastSpell(_E, Position.x, Position.z)
						ShenFlash(sflash, flashPos)
					end
				end
			end
		end
	
		if myHero.charName == "Alistar" or myHero.charName == "Janna" then
			for name, tower in pairs(GetTurrets()) do
				if tower and tower.team == myHero.team and GetDistance(tower) < 2000 and IsReady(sflash) then
					local Position = VPred:GetPredictedPos(unit, 0.1)
					flashPos = Position + 100 * (Vector(Position) - Vector(tower)):normalized()
					
					if GetDistance(flashPos) > 425 then
						flashPos = nil
					end
					
					if GetDistance(Position, flashPos) > 100 then
						flashPos = nil
					end
					
					hasTower = true
					
					if flashPos ~= nil and settings.key.flashKey then					
						if myHero.charName == "Alistar" and IsReady(_W) and IsReady(_Q) and myHero.mana > GetSpellData(_W).mana + GetSpellData(_Q).mana then
							buffs["moveBlock"] = true
							CastSpell(sflash, flashPos.x, flashPos.z)
							FlashCombo(_Q, unit, true)
							FlashCombo(_W, unit, false)
						elseif myHero.charName == "Janna" and IsReady(_R) and IsReady(sflash) and myHero.mana > GetSpellData(_R).mana then
							buffs["moveBlock"] = true
							CastSpell(sflash, flashPos.x, flashPos.z)
							FlashCombo(_R, unit, true)
						end
					end
				end
			end
			
			local useAlly = nil
			local damage = 0
			for i, ally in pairs(GetAllyHeroes()) do
				if not ally.dead and GetDistance(ally) < 800 then
					if ally.damage > damage then
						useAlly = ally
						damage = ally.damage
					end
				end
			end
			
			if useAlly ~= nil and hasTower == false then
				local Position = VPred:GetPredictedPos(unit, 0.1)
				local flashPos = Position + 100 * (Vector(Position) - Vector(useAlly)):normalized()
				
				if GetDistance(flashPos) > 425 then
					flashPos = nil
				end
				
				if GetDistance(Position, flashPos) > 100 then
					flashPos = nil
				end
				
				if flashPos ~= nil and settings.key.flashKey then					
					if myHero.charName == "Alistar" and IsReady(_W) and IsReady(sflash) and myHero.mana > GetSpellData(_W).mana then
						buffs["moveBlock"] = true
						CastSpell(sflash, flashPos.x, flashPos.z)
						FlashCombo(_Q, unit, true)
						FlashCombo(_W, unit, false)
					elseif myHero.charName == "Janna" and IsReady(_R) and IsReady(sflash) and myHero.mana > GetSpellData(_R).mana then
						buffs["moveBlock"] = true
						CastSpell(sflash, flashPos.x, flashPos.z)
						FlashCombo(_R, unit, true)
					end
				end
			end
		end
	end
	
	if settings.key.comboKey and settings.items.fqs  then
		local slot = CustomGetInventorySlotItem("ItemGlacialSpikeCast", myHero)
		
		if slot ~= nil and IsReady(slot) then
			local Position = VPred:GetPredictedPos(unit, 0.5)
			if GetDistance(Position) < 850 then
				CastSpell(slot, Position.x, Position.z)
			end
		end
	end
	
	if myHero.charName == "Alistar" then
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then
			CustomCast(_Q, unit)
		end
		if UseSpell(_Q) and UseSpell(_W) and myHero.mana > (60 + 5 * GetSpellData(_Q).level) + (60 + 5 * GetSpellData(_W).level) and GetDistance(unit) < GetRange(_W) and GetDistance(unit) > GetRange(_Q) then
			CustomCast(_W, unit)
			DelayAction(function() CustomCast(_Q, unit) end, (math.max(0 , GetDistance(unit) - 500 ) * 0.4 + 25) / 1000)
		end	
	elseif myHero.charName == "Annie" then
		if GetSpellData(_R).name == "InfernalGuardian" and UseSpell(_R) and HitsRequired(_R) <= CountObjectsInCircle(unit, spells[_R].width, GetEnemyHeroes()) and not buffs["hasTibbers"] and GetDistance(unit) < GetRange(_R) then
			local Position = FindBestCircle(unit, GetRange(_R), spells[_R].width, _R)
			CastSpell(_R, Position.x, Position.z)
		end
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then CustomCast(_W, unit) end
		
		if GetSpellData(_R).name == "infernalguardianguide" then
			CastSpell(_R, unit)
		end
	elseif myHero.charName == "Bard" then
		if UseSpell(_Q) then BardCastQ(unit) end
	elseif myHero.charName == "Blitzcrank" then
		if UseSpell(_Q) and SelectedEnemy(_Q, unit) then CustomCast(_Q, unit) end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) and settings.spell[GetSpellData(_E).name].attack then CustomCast(_E, myHero) end
		if buffs["rocketgrab2"] and GetDistance(unit) < GetRange(_E) and IsReady(_E) and settings.spell[GetSpellData(_E).name].cast then CustomCast(_E, myHero) end
		if buffs["PowerFist"] and GetDistance(unit) < GetRange(_E) then  Attack(unit) end
		if UseSpell(_W) then CustomCast(_W, myHero) end
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then CustomCast(_R, myHero) end
	elseif myHero.charName == "Braum" then
		if UseSpell(_W) then
			for i, ally in pairs(GetAllyHeroes()) do
				if not ally.dead and GetDistance(ally) < GetRange(_W) and GetDistance(ally, unit) < GetDistance(unit) - 100 then
					CustomCast(_W, ally)
				end
			end
		end
		if UseSpell(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
			local Position = UPL:Predict(_R, myHero, unit)
			if CountObjectHitOnLine(_R, myHero, Position, GetEnemyHeroes()) >= HitsRequired(_R) then
				CastSpell(_R, Position.x, Position.z) 
			end
		end	
	elseif myHero.charName == "Janna" then
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then CustomCast(_W, unit) end
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, unit) JannaCastQ2() end
	elseif myHero.charName == "Karma" then
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then 
			if UseSpell(_R) and UseRWith() == 2 then CustomCast(_R, myHero) end
			if UseSpell(_R) and UseRWith() == 3 and CountObjectsInCircle(myHero, 600, GetAllyHeroes()) == 1 then CustomCast(_R, myHero) end
			
			CustomCast(_W, unit)
		end
		if UseSpell(_Q) then 
			local IsCollision = VPred:CheckMinionCollision(unit, unit.pos, spells[_Q].delay, spells[_Q].width, GetRange(_Q), spells[_Q].speed, myHero.pos,nil, true)
			
			if IsCollision == false and GetDistance(unit) < GetRange(_Q) then
				if UseSpell(_R) and UseRWith() == 1 then CustomCast(_R, myHero) end
				CustomCast(_Q, unit)
			end
		end
		if GetDistance(unit) < settings.spell[GetSpellData(_E).name].near and GetDistance(unit) > GetRange(_W) and IsReady(_E) and settings.key.comboKey then
			CustomCast(_E, myHero)
		end
	elseif myHero.charName == "Leona" then
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) and GetDistance(unit) > GetRange(_Q) then CustomCast(_E, unit) end
		if buffs["LeonaShieldOfDaybreak"] and GetDistance(unit) < GetRange(_Q) and settings.spell[GetSpellData(_Q).name].attack then Attack(unit) end
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, myHero) end
		if UseSpell(_R) and HitsRequired(_R) <= CountObjectsInCircle(unit, spells[_R].width, GetEnemyHeroes()) and GetDistance(unit) < GetRange(_R) then 
			local Position = FindBestCircle(unit, GetRange(_R), spells[_R].width, _R)
			CastSpell(_R, Position.x, Position.z)
		end
	elseif myHero.charName == "Lulu" then
		if UseSpell(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_Q) and GetDistance(objects["faerie"], unit) < GetRange(_Q) then
			local Position = VPred:GetPredictedPos(unit, spells[_Q].delay + GetDistance(objects["faerie"], unit) / spells[_Q].speed)
			
			if math.sqrt((Position.x - objects["faerie"].x) ^ 2 + (Position.z - objects["faerie"].z) ^ 2) < GetRange(_W) then
				CastSpell(_Q, Position.x, Position.z)
			end
		end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) and SelectedEnemy(_W, unit) then CustomCast(_W, unit) end
	elseif myHero.charName == "Lux" then
		if UseSpell(_Q) then CustomCast(_Q, unit) end
		if GetSpellData(_E).name == "LuxLightStrikeKugel" and UseSpell(_E) and GetDistance(unit) < GetRange(_E) then
			local Position = UPL:Predict(_E, myHero, unit)
			if HitsRequired(_E) <= CountObjectsInCircle(Position, spells[_E].width, GetEnemyHeroes()) then
				CastSpell(_E, Position.x, Position.z) 
			end
		end 
		
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
			local Position = UPL:Predict(_R, myHero, unit)
			if CountObjectHitOnLine(_R, myHero, Position, GetEnemyHeroes()) >= HitsRequired(_R) then
				CastSpell(_R, Position.x, Position.z) 
			end
		end	
		
		if UseSpell(_R) and not IsReady(_Q) and GetDistance(unit) < GetRange(_R) then 
			local Position = UPL:Predict(_R, myHero, unit)
			if CountObjectHitOnLine(_R, myHero, Position, GetEnemyHeroes()) >= HitsRequired(_R) then
				CastSpell(_R, Position.x, Position.z) 
			end
		end
	elseif myHero.charName == "Malphite" then
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then CustomCast(_W, unit) end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then CustomCast(_E, unit) end
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
			local CastPosition, HitChance = UPL:Predict(_R, myHero, unit)	
		
			if HitChance >= 2 and HitsRequired(_R) <= CountObjectsInCircle(CastPosition, spells[_R].width + 100, GetEnemyHeroes()) then
				for i, enemy in pairs(GetEnemyHeroes()) do
					if enemy ~= unit then
						if VPred:CheckCol(unit, enemy, CastPosition, spells[_R].delay, spells[_R].width, GetRange(_R), spells[_R].speed, myHero) and GetDistance(unit, enemy) > 500 then
							return
						end
					end
				end
				
				CastSpell(_R, CastPosition.x, CastPosition.z)
			end
		end
	elseif myHero.charName == "Morgana" then
		if UseSpell(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) and settings.spell[GetSpellData(_W).name].cast == false then 
			local Position = UPL:Predict(_W, myHero, unit)
			if HitsRequired(_W) <= CountObjectsInCircle(Position, spells[_W].width, GetEnemyHeroes()) then
				CastSpell(_W, Position.x, Position.z) 
			end
		end
		if UseSpell(_R) and HitsRequired(_R) <= CountObjectsInCircle(myHero, spells[_R].range, GetEnemyHeroes()) then CastSpell(_R) end
	elseif myHero.charName == "Nami" then
		if UseSpell(_Q) then 
			local Position = UPL:Predict(_Q, myHero, unit)
			if HitsRequired(_Q) <= CountObjectsInCircle(Position, spells[_Q].width, GetEnemyHeroes()) then
				CastSpell(_Q, Position.x, Position.z) 
			end
		end
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
			local Position = UPL:Predict(_R, myHero, unit)
			if CountObjectHitOnLine(_R, myHero, Position, GetEnemyHeroes()) >= HitsRequired(_R) then
				CastSpell(_R, Position.x, Position.z) 
			end
		end
		if UseSpell(_E) then
			local bestAlly, as = nil, 0
			for i, ally in pairs(GetAllyHeroes()) do
				if not ally.dead and ally.attackSpeed > as and GetDistance(ally) < GetRange(_E) then
					if GetDistance(ally, unit) < ally.range + GetDistance(ally, ally.minBBox) then
						as = ally.attackSpeed
						bestAlly = ally
					end
				end
			end
			
			if bestAlly ~= nil then
				CastSpell(_E, bestAlly)
			elseif GetDistance(unit) < myTrueRange then
				CastSpell(_E, myHero)
 			end
		end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then CustomCast(_W, unit) end
	elseif myHero.charName == "Nautilus" then
		if UseSpell(_Q) and SelectedEnemy(_Q, unit) then CustomCast(_Q, unit) end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then CustomCast(_E, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) then CustomCast(_W, unit) end
	elseif myHero.charName == "Nunu" then
		if UseSpell(_W) then
			local bestAlly, ad = nil, 0
			for i, ally in pairs(GetAllyHeroes()) do
				if not ally.dead and ally.damage > ad and GetDistance(ally) < GetRange(_W) then
					if GetDistance(ally, unit) < ally.range + GetDistance(ally, ally.minBBox) then
						ad = ally.damage
						bestAlly = ally
					end
				end
			end
			
			if bestAlly ~= nil then
				CastSpell(_W, bestAlly)
			elseif GetDistance(unit) < myTrueRange then
				CastSpell(_W, myHero)
 			end
		end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then CustomCast(_E, unit) end
	elseif myHero.charName == "Shen" then
		if UseSpell(_E) then 
			local Position, HitChance = UPL:Predict(_E, myHero, unit)
			if HitChance >= 2 then
				Position = Vector(myHero) + (GetDistance(Position) + 50) * (Vector(Position) - Vector(myHero)):normalized()
				CastSpell(_E, Position.x, Position.z) 
			end
		end
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then 
			if settings.spell[GetSpellData(_Q).name].save and GetSpellData(_E).level > 0 and myHero.mana + GetSpellData(_E).currentCd * myHero.mpRegen < 60 + 105 - 5 * GetSpellData(_E).level then return end
			CustomCast(_Q, unit) 
		end
	elseif myHero.charName == "Sona" then	
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
			local Position = UPL:Predict(_R, myHero, unit)
			if CountObjectHitOnLine(_R, myHero, Position, GetEnemyHeroes()) >= HitsRequired(_R) then
				CastSpell(_R, Position.x, Position.z) 
			end
		end	
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, unit) end
		if buffs["SonaQProcAttacker"] and GetDistance(unit) < myTrueRange then  Attack(unit) end
		if GetDistance(unit) < settings.spell[GetSpellData(_E).name].near and GetDistance(unit) > myTrueRange and IsReady(_E) and settings.key.comboKey then
			CustomCast(_E, myHero)
		end
	elseif myHero.charName == "Soraka" then
		if UseSpell(_Q) then 
			local Position = UPL:Predict(_Q, myHero, unit)
			if HitsRequired(_Q) <= CountObjectsInCircle(Position, spells[_Q].width, GetEnemyHeroes()) then
				CastSpell(_Q, Position.x, Position.z) 
			end
		end
		if UseSpell(_E) then 
			local Position = UPL:Predict(_E, myHero, unit)
			if HitsRequired(_E) <= CountObjectsInCircle(Position, spells[_E].width, GetEnemyHeroes()) then
				CastSpell(_E, Position.x, Position.z) 
			end
		end
	elseif myHero.charName == "TahmKench" then
		if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) and attack[unit.charName] then CastSpell(_W, unit) end
		if IsReady(_W) and GetDistance(unit) < GetRange(_Q) and buffs["minion"] and settings.spell[GetSpellData(_W).name].throw then 
			local CastPosition, HitChance, HeroPosition = UPL:Predict(_Q, myHero, unit)		
			if HitChance >= 2 then
				CastSpell(_W, CastPosition.x, CastPosition.z)
			end
		end
	elseif myHero.charName == "Taric" then
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then CustomCast(_E, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_W) and HitsRequired(_W) <= CountObjectsInCircle(myHero, spells[_W].range, GetEnemyHeroes()) then CastSpell(_W) end
	elseif myHero.charName == "Thresh" then
		if UseSpell(_R) and GetDistance(unit) < GetRange(_R) and HitsRequired(_R) <= CountObjectsInCircle(myHero, spells[_R].range, GetEnemyHeroes()) then CastSpell(_R) end
		if GetSpellData(_Q).name ~= "threshqleap" and UseSpell(_Q) and SelectedEnemy(_Q, unit) then
			if GetDistance(unit) > GetRange(_E) or not IsReady(_E) then
				CustomCast(_Q, unit) 
			end
		end
		if IsReady(_W) and GetSpellData(_Q).name == "threshqleap" and buffs["ThreshQ"] and settings.spell[GetSpellData(_W).name].cast then ThreshCastWCombo(unit) end
		if IsReady(_W) and GetSpellData(_Q).name ~= "threshqleap" and buffs["ThreshQ"] and UseSpell(_W) then ThreshCastWEngage(unit) end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then ThreshCastE(unit) end
	elseif myHero.charName == "Zilean" then
		if UseSpell(_Q) then CustomCast(_Q, unit) end
		if UseSpell(_W) and GetDistance(unit) < GetRange(_Q) and not IsReady(_Q) then CustomCast(_W, myHero) end
		if UseSpell(_E) and GetDistance(unit) < GetRange(_E) and unit.ms > 220 then CustomCast(_E, unit) end
		if GetDistance(unit) < settings.spell[GetSpellData(_E).name].near and GetDistance(unit) > GetRange(_E) and IsReady(_E) and settings.key.comboKey then
			CustomCast(_E, myHero)
		end
	elseif myHero.charName == "Zyra" then
		if GetSpellData(_Q).name == "zyrapassivedeathmanager" then
			local CastPosition, HitChance, Position  = VPred:GetLineCastPosition(unit, spells["P"].delay, spells["P"].width, spells["P"].range, spells["P"].speed, myHero, false)
			
			if HitChance >= 2 then
				CastSpell(_Q, CastPosition.x, CastPosition.z)
			end
		else 			
			if UseSpell(_E) and GetDistance(unit) < GetRange(_E) then 
				local Position = UPL:Predict(_E, myHero, unit)
				CastSpell(_E, Position.x, Position.z) 
			end	
			
			if UseSpell(_Q) and GetDistance(unit) < GetRange(_Q) then 
				local Position = UPL:Predict(_Q, myHero, unit)
				if HitsRequired(_Q) <= CountObjectsInCircle(Position, spells[_Q].width, GetEnemyHeroes()) then
					CastSpell(_Q, Position.x, Position.z) 
				end
			end
			
			if UseSpell(_R) and GetDistance(unit) < GetRange(_R) then 
				local Position = UPL:Predict(_R, myHero, unit)
				if HitsRequired(_R) <= CountObjectsInCircle(Position, spells[_R].width, GetEnemyHeroes()) then
					CastSpell(_R, Position.x, Position.z) 
				end
			end
		end
	end
end

function Automatic()
	if buffs["recall"] then	return end
	if GetTarget() == nil and flashPos ~= nil then flashPos = nil end
	
	if auto["ks"] ~= nil then
		for i, enemy in pairs(GetEnemyHeroes()) do
			if not enemy.dead and enemy.visible then
				CastArray(auto["ks"], settings.ks, special["ks"], enemy, 0, true)
			end
		end
	end
	
	if settings.key.flashKey ~= nil and settings.key.flashKey and IsReady(sflash) then
		myHero:MoveTo(mousePos.x, mousePos.z)
	end
	
	if GetHealthPercent(myHero) < settings.items.zhonya then 
		local slot = CustomGetInventorySlotItem("ZhonyasHourglass", myHero)
		if slot ~= nil and IsReady(slot) then
			CastSpell(slot)
		end
	end
	
	if auto["attack"] and settings.spell.passive.apply and (settings.key.comboKey or settings.key.harassKey) then
		for i, enemy in pairs(GetEnemyHeroes()) do
			if not enemy.dead and enemy.visible and GetDistance(enemy) < myTrueRange and attack[enemy.charName] then
				Attack(enemy)
			end
		end
	end
	
	if auto["immobile"] ~= nil then
		for i, enemy in pairs(GetEnemyHeroes()) do
			if not enemy.dead and enemy.visible and (enemy.ms == 0 or not unit.canMove) then
				for i, slot in pairs(auto["immobile"]) do
					if GetSpellData(slot).name ~= "threshqleap" and IsReady(slot) and GetDistance(enemy) < GetRange(slot) and settings.immobile[GetSpellData(slot).name] and settings.immobile[enemy.charName] then
						if myHero.charName == "Bard" then BardCastQ(enemy) return end
						local IsCollision = VPred:CheckMinionCollision(enemy, enemy.pos, spells[slot].delay, spells[slot].width, GetRange(slot), spells[slot].speed, myHero.pos,nil, true)
						if IsCollision == false then
							CastSpell(slot, enemy)
						end
					end
				end
			end
		end
	end
	
	if auto["marathon"] ~= nil then
		if settings.key.marathon then
			myHero:MoveTo(mousePos.x, mousePos.z)
			
			for i, slot in pairs(auto["marathon"]) do
				if IsReady(slot) then
					CastSpell(slot, myHero)
				end
			end
		end
	end
	
	if auto["heal"] ~= nil and not InFountain() then
		local points = math.huge
		local target 
	
		for i, slot in pairs(auto["heal"]) do
			for i, ally in pairs(GetAllyHeroes()) do
				if not ally.dead and GetDistance(ally) < GetRange(slot) then
					if SmartHeal(slot, ally) < points then
						points = SmartHeal(slot, ally)
						target = ally
					end
				end
			end
			
			if myHero.charName ~= "Soraka" then
				if SmartHeal(slot, myHero) < points then
					points = SmartHeal(slot, myHero)
					target = myHero
				end
			end

			if points < settings.heal.coefficient then
				if IsReady(slot) then
					CastSpell(slot, target)
				end
			end
		end
	end
	
	if myHero.charName == "Annie" then
		if InFountain() and settings.spell[GetSpellData(_W).name].autoW and not buffs["canStun"] and IsReady(_W) then
			CastSpell(_W, myHero.x, myHero.z)
		end
		if settings.spell[GetSpellData(_E).name].autoE > 0 and not buffs["canStun"] and CountObjectsInCircle(myHero, settings.spell[GetSpellData(_E).name].autoE, GetEnemyHeroes()) == 0 and IsReady(_E) and not settings.key.clearKey then
			CastSpell(_E, myHero)
		end
		if settings.spell["InfernalGuardian"].autoR and buffs["hasTibbers"] then
			if GetTarget() and (settings.key.comboKey or settings.key.harassKey) then
				CastSpell(_R, GetTarget())
			else
				local positionTarget = nil
				local towerUsed = nil
				
				for name, tower in pairs(GetTurrets()) do
					if tower and tower.team ~= myHero.team and GetDistance(tower) < 2000 then
						positionTarget =  myHero
						towerUsed = tower
						
						for i, ally in pairs(GetAllyHeroes()) do 
							if GetDistance(ally, tower) < GetDistance(tower) then 
								positionTarget = ally
							end
						end
					end
				end
				
				if positionTarget and towerUsed then
					local tibbersPosition = towerUsed + (GetDistance(positionTarget, towerUsed) - 150) * (Vector(positionTarget) - Vector(towerUsed)):normalized()
					CastSpell(_R, tibbersPosition.x, tibbersPosition.z)
				end
			end
		end
	elseif myHero.charName == "Braum" then
		if myHero.hasMovePath and myHero.path.count > 1 and settings.spell[GetSpellData(_W).name].autoW then
			local path = myHero.path:Path(2)
			if GetDistance(path) < GetRange(_W) + 100 then return end
			if path ~= nil then
				local bestJump, bestRange = nil, 0
				
				for i, ally in pairs(GetAllyHeroes()) do
					if GetDistance(pointOnLine(path, myHero, ally, 0, GetRange(_W)), ally) < 100 and GetDistance(ally) < GetRange(_W) and GetDistance(ally) > bestRange and AngleDifference(myHero, path, ally) < 15 then
						bestRange = GetDistance(ally)
						bestJump = ally
					end
				end
				
				if bestRange == 0 then
					AllyMinions:update()
					for i, minion in pairs(AllyMinions.objects) do
						if GetDistance(pointOnLine(path, myHero, minion, 0, GetRange(_W)), minion) < 100 and GetDistance(minion) < GetRange(_W) and GetDistance(minion) > bestRange and AngleDifference(myHero, path, minion) < 30 then
							bestRange = GetDistance(minion)
							bestJump = minion
						end
					end
				end
				
				if bestRange > GetRange(_W) - 100 then
					local count = 0
					for _ in pairs(EnemyMinions.objects) do count = count + 1 end
					
					if count == 0 then
						CustomCast(_W, bestJump)
					end
				end
			end
		end
	elseif myHero.charName == "Janna" then
		if objects["Q"] ~= nil then
			JannaCastQ2()
		end
	elseif myHero.charName == "Karma" then	
		if settings.key.comboKey and IsReady(_E) and CountObjectsInCircle(myHero, settings.spell[GetSpellData(_E).name].near, GetEnemyHeroes()) > 0 then
			CustomCast(_E, myHero)
		end
	elseif myHero.charName == "Lux" then
		if objects["E"] ~= nil then
			if settings.key.clearKey then
				CastSpell(_E)
			end
		
			for i, enemy in pairs(GetEnemyHeroes()) do
				if not enemy.dead and GetDistance(objects["E"], enemy) < spells[_E].width then
					CastSpell(_E)
				end
			end
		end
	elseif myHero.charName == "Morgana" then
		if buffs["DarkBindingMissile"] ~= nil and IsReady(_W) and GetDistance(buffs["DarkBindingMissile"]) < GetRange(_W) then CastSpell(_W, buffs["DarkBindingMissile"]) end
	elseif myHero.charName == "Nunu" then
		if UseSpell(_Q) then
			EnemyMinions:update()
			for i, minion in pairs(EnemyMinions.objects) do
				if GetDistance(minion) < GetRange(_Q) and myHero.health + (25 + GetSpellData(_Q).level * 45 + myHero.ap * 0.75) < myHero.maxHealth then
					CastSpell(_Q, minion)
				end
			end
		end
	elseif myHero.charName == "Soraka" then
		if settings.spell[GetSpellData(_E).name].cast then
			for i, enemy in ipairs(GetEnemyHeroes()) do
				if enemy.ms == 0 and GetDistance(enemy) < GetRange(_E) and not enemy.dead then
					CustomCast(_E, enemy)
				end
			end
		end
	elseif myHero.charName == "Thresh" then
		if settings.spell[GetSpellData(_W).name].hp > 0 and IsReady(_W) then ThreshCastWLowHP() end
	end
end

----------------------
--    Champion      --
----------------------

-- Annie --
function AnnieStun(slot, object, delay)
	if (slot == _R and not buffs["hasTibbers"]) or slot ~= _R then
		if buffs["canStun"] then
			DelayAction(function() CustomCast(slot, object) end, delay / 1000)
		elseif not buffs["canStun"] and buffs["passive"] == 3 and IsReady(_E) then
			CustomCast(_E, myHero)
			DelayAction(function() CustomCast(slot, object) end, delay / 1000 + 0.25)
		end
	end
end

-- Bard --

function BardCastQ(unit)
	if not IsReady(_Q) then return end
	if os.clock() - LastBardQ < 0.2 then return else LastBardQ = os.clock() end
	
	local CastPosition, HitChance = UPL:Predict(_Q, myHero, unit)	
	if CastPosition then 
		local dp = GetDistance(myHero.pos, CastPosition)
		if dp < GetRange(_Q) then
			local extend = GetRange(_Q) - dp - 20
			if extend > 1 then
				local extendedCollision = Vector(CastPosition) + (Vector(CastPosition) - Vector(myHero)):normalized() * (extend)
				if HitChance >= 2 then
					for i, enemy in pairs(GetEnemyHeroes()) do
						if enemy ~= unit then
							if VPred:CheckCol(extendedCollision, enemy, CastPosition, spells[_Q].delay, spells[_Q].width, GetRange(_Q), spells[_Q].speed, myHero) then
								CastSpell(_Q, CastPosition.x, CastPosition.z)
								return
							end
						end
					end
					
					local col = VPred:CheckMinionCollision(unit, extendedCollision, spells[_Q].delay, spells[_Q].width, extend, spells[_Q].speed, CastPosition, false, true)
					if col then
						CastSpell(_Q, CastPosition.x, CastPosition.z)
						return
					end
					
					local amount = extend/10
					local count = 1
					while count <= 10 do
						local extendedWall = Vector(CastPosition) + (Vector(CastPosition) - Vector(myHero)):normalized() * (amount*count)
						local vec1 = D3DXVECTOR3(extendedWall.x, extendedWall.y,extendedWall.z)
						if IsWall(vec1) then
							CastSpell(_Q, CastPosition.x, CastPosition.z)
							return
						end
						count = count + 1
					end
				end
				
				local mBool, mTable = GetMinionCollision(myHero, CastPosition, 100)
				if mBool and mTable ~= nil and #mTable == 1 then
					CastSpell(_Q, CastPosition.x, CastPosition.z)
					return
				end
			end
		end
	end
end

-- Janna --
function JannaCastQ2()
	if objects["Q"] ~= nil then
		DelayAction(function() JannaCastQ2() end, 0.01)
		CastSpell(_Q)
	end
end

-- Karma --
function UseRWith()
	if not IsReady(_R) then return 4 end
	if settings.key.comboKey and settings.spell[GetSpellData(_R).name].combo then return settings.spell[GetSpellData(_R).name].comboR end
	if (settings.key.harassKey or settings.key.harassToggle) and settings.spell[GetSpellData(_R).name].harass then return settings.spell[GetSpellData(_R).name].harassR end
	return 4
end

-- Thresh --
function wPosition(target)
	if target.hasMovePath and target.path.count > 1 then
		local endPoint = target.path:Path(2)
		
		if GetDistance(endPoint, target) < target.ms * 0.5 then
			return endPoint
		else
			return Vector(target) + target.ms * 0.5 * (Vector(endPoint) - Vector(target)):normalized()
		end
	else
		return target
	end
end

function ThreshCastQ2()
	if settings.spell["ThreshQ"].cast and GetSpellData(_Q).name == "threshqleap" then
		DelayAction(function() if settings.key.comboKey or settings.key.harassKey or settings.key.harassToggle or settings.key.flashKey then CastSpell(_Q) end end, ((15 / 1000) * 75))
	end
end

function ThreshCastWCombo(Target)
	if ValidTarget(Target) then	
		local bestAlly = nil
		
		for i = 1, heroManager.iCount, 1 do
            local ally = heroManager:getHero(i)
			
            if ally.team == myHero.team and ally.name ~= myHero.name  and not ally.dead then		
				if GetDistance(Target, ally) >= 600 and GetDistance(wPosition(ally)) <= GetRange(_W) then 
					if ValidTarget(bestAlly) then
						if GetDistance(ally) >= GetDistance(bestAlly) then
							bestAlly = ally
						end
					else
						bestAlly = ally
					end
				end
			end
		end
		
		if bestAlly ~= nil then
			local castPosition = wPosition(bestAlly)
			CastSpell(_W, castPosition.x, castPosition.z)
		end
	end
end

function ThreshCastWEngage(Target)
	if ValidTarget(Target) and GetDistance(Target) <= 200 then	
		local bestAlly = nil
		
		for i = 1, heroManager.iCount, 1 do
            local ally = heroManager:getHero(i)
			
            if ally.team == myHero.team and ally.name ~= myHero.name and not ally.dead then		
				if GetDistance(Target, ally) >= 600 and GetDistance(ally) > 300 and GetDistance(wPosition(ally)) <= GetRange(_W) then 
					if ValidTarget(bestAlly) then
						if GetDistance(ally) >= GetDistance(bestAlly) then
							bestAlly = ally
						end
					else
						bestAlly = ally
					end
				end
			end
		end
		
		if bestAlly ~= nil then
			local castPosition = wPosition(bestAlly)
			CastSpell(_W, castPosition.x, castPosition.z)
		end
	end
end

function ThreshCastWLowHP()
	for i = 1, heroManager.iCount, 1 do
		local ally = heroManager:getHero(i)
		
		if ally.team == myHero.team  and not ally.dead then
			if ally.health < (ally.maxHealth / 100) * settings.spell[GetSpellData(_W).name].hp and CountObjectsInCircle(ally, 600, GetEnemyHeroes()) > 0 then
				if GetDistance(ally) < GetRange(_W) then
					if GetDistance(ally) < 300 then
						local CastPosition,  HitChance,  Position = VPred:GetCircularCastPosition(ally, 0.5, 150, 950)
						CastSpell(_W, CastPosition.x, CastPosition.z) 
					else
						local castPosition = wPosition(ally)
						CastSpell(_W, castPosition.x, castPosition.z)
					end
				end
			end
		end
	end
end

function ThreshCastE(Target)
	if Target then
		if Target.hasMovePath and Target.path.count > 1 then
			if GetDistance(Target.path:Path(2)) < GetDistance(Target) then
				CastSpell(_E, Target)
				end
			else
		end
	
		local Pos = Vector(myHero) + 400 * (Vector(myHero) - Vector(Target)):normalized()
		CastSpell(_E, Pos.x, Pos.z)
	end  
end

-- Zyra --
function ZyraCastSeed(x, z, name)
	if name == GetSpellData(_Q).name then
		if championVariables["seeds"] > 0 then
			CastSpell(_W, x, z)
			DelayAction(function() ZyraCastSeed(x, z, name) end, 0.1)
		end
	elseif name == GetSpellData(_E).name and GetTarget() then
		if championVariables["seeds"] > 0 and GetTarget() then
			CastSpell(_W, pointOnLine({x = x, z = z}, myHero, GetTarget(), 0, GetRange(_W)).x, pointOnLine({x = x, z = z}, myHero, GetTarget(), 0, GetRange(_W)).z)
			DelayAction(function() ZyraCastSeed(x, z, name) end, 0.1)
		end
	elseif name == GetSpellData(_W).name then
		championVariables["seeds"] = championVariables["seeds"] - 1
	end

	DelayAction(function() championVariables["seeds"] = 0 end, 1)
end

----------------------
--       Draw       --
----------------------

function DrawCircle(x, y, z, radius, color)
	local vPos1 = Vector(x, y, z)
	local vPos2 = Vector(cameraPos.x, cameraPos.y, cameraPos.z)
	local tPos = vPos1 - (vPos1 - vPos2):normalized() * radius
	local sPos = WorldToScreen(D3DXVECTOR3(tPos.x, tPos.y, tPos.z))
		
	if OnScreen({ x = sPos.x, y = sPos.y }, { x = sPos.x, y = sPos.y }) then
		DrawCircleNextLvl(x, y, z, radius, 1, color, 300) 
	end
end

function DrawCircleNextLvl(x, y, z, radius, width, color, chordlength)
	radius = radius or 300
	quality = math.max(40, Round(180 / math.deg((math.asin((chordlength / (2 * radius)))))))
	quality = 2 * math.pi / quality
	radius = radius * .92
	local points = {}
		
	for theta = 0, 2 * math.pi + quality, quality do
		local c = WorldToScreen(D3DXVECTOR3(x + radius * math.cos(theta), y, z - radius * math.sin(theta)))
		points[#points + 1] = D3DXVECTOR2(c.x, c.y)
	end
	DrawLines2(points, width or 1, color or 4294967295)	
end

function Round(number)
	if number >= 0 then 
		return math.floor(number+.5) 
	else 
		return math.ceil(number-.5) 
	end
	end
	
----------------------
--    Ward Assist   --
----------------------

class "WA"
function WA:__init(menu)
	self.menu = menu
	self.menu:addParam("enable", "Enable Perfect Ward", SCRIPT_PARAM_ONOFF, true)
	self.menu:addParam("situational", "Enable Situational Spots", SCRIPT_PARAM_ONOFF, true)
	self.menu:addParam("printAvailable", "Message if Ward is available", SCRIPT_PARAM_ONOFF, true)
	self.menu:addParam("castWard", "Ward Casting", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("T"))
	
	self.drawWardSpots = false
	self.wardSlot = nil
	self.putSafeWard = nil
	
	self.wardSpot = {
        {x=3261.93, y=60, z=7773.65}, -- BLUE GOLEM
        {x=7831.46, y=60, z=3501.13}, -- BLUE LIZARD
        {x=10586.62, y=60, z=3067.93}, -- BLUE TRI BUSH
        {x=6483.73, y=60, z=4606.57}, -- BLUE PASS BUSH
        {x=7610.46, y=60, z=5000}, -- BLUE RIVER ENTRANCE
        {x=4717.09, y=50.83, z=7142.35}, -- BLUE ROUND BUSH
        {x=4882.86, y=27.83, z=8393.77}, -- BLUE RIVER ROUND BUSH
        {x=6951.01, y=52.26, z=3040.55}, -- BLUE SPLIT PUSH BUSH
        {x=5583.74, y=51.43, z=3573.83}, --BlUE RIVER CENTER CLOSE
 
        {x=11600.35, y=51.73, z=7090.37}, -- RED GOLEM
        {x=11573.9, y=51.71, z=6457.76}, -- RED GOLEM 2
        {x=12629.72, y=48.62, z=4908.16}, -- RED TRIBRUSH 2
        {x=7018.75, y=54.76, z=11362.12}, -- RED LIZARD
        {x=4232.69, y=47.56, z=11869.25}, -- RED TRI BUSH
        {x=8198.22, y=49.38, z=10267.89}, -- RED PASS BUSH
        {x=7202.43, y=53.18, z=9881.83}, -- RED RIVER ENTRANCE
        {x=10074.63, y=51.74, z=7761.62}, -- RED ROUND BUSH
        {x=9795.85, y=-12.21, z=6355.15}, -- RED RIVER ROUND BUSH
        {x=7836.85, y=56.48, z=11906.34}, -- RED SPLIT PUSH BUSH
 
        {x=10546.35, y=-60, z=5019.06}, -- DRAGON
        {x=9344.95, y=-64.07, z=5703.43}, -- DRAGON BUSH
        {x=4334.98, y=-60.42, z=9714.54}, -- BARON
        {x=5363.31, y=-62.70, z=9157.05}, -- BARON BUSH
 
        --{x=12731.25, y=50.32, z=9132.66}, -- RED BOT T2
        --{x=8036.52, y=45.19, z=12882.94}, -- RED TOP T2
        {x=9757.9, y=50.73, z=8768.25}, -- RED MID T1
 
        {x=4749.79, y=53.59, z=5890.76}, -- BLUE MID T1
        {x=5983.58, y=52.99, z=1547.98}, -- BLUE BOT T2
        {x=1213.70, y=58.77, z=5324.73}, -- BLUE TOP T2
 
        {x=6523.58, y=60, z=6743.31}, -- BLUE MIDLANE
        {x=8223.67, y=60, z=8110.15}, -- RED MIDLANE
        {x=9736.8, y=51.98, z=6916.26}, -- RED MID PATH
        {x=2222.31, y=53.2, z=9964.1}, -- BLUE TRI TOP
        {x=8523.9, y=51.24, z=4707.76}, -- DRAGON PASS BUSH
        {x=6323.9, y=53.62, z=10157.76} -- NASHOR PASS BUSH
	}
	
	self.situationalWards={
        {x=13512.60, y=51.37, z=2868},
        {x=1764.57, y=52.84, z=12892.7},
        {x=4222.72, y=53.61, z=7038.58},
        {x=4379.51, y=42.73, z=8093.74},
        {x=4978.19, y=54.34, z=3042.69},
        {x=5943.51, y=53.18, z=9792.40},
        {x=5597.66, y=39.73, z=12491.04},
        {x=5732.81, y=53.39, z=10289.76},
        {x=5973.48, y=54.34, z=11115.68},
        {x=9068.02, y=53.22, z=11186.68},
        {x=10070.2, y=-60.33, z=4132.45},
        {x=12073.18, y=52.32, z=4795.50},
        {x=12210.03, y=51.38, z=1411.44},
        {x=1245.83, y=52.84, z=12040.08},
        {x=2697.76, y=52.84, z=13567.86}      
	}
	
	self.safeWardSpots = {
-- DISABLED, IS NOT WORKING
        -- {    -- DRAGON -> TRI BUSH
        --      magneticSpot = {x=10072, y=-71.24, z=3908},
        --      clickPosition = {x=10297.93, y=49.03, z=3358.59},
        --      wardPosition =  {x=10273.9, y=49.03, z=3257.76},
        --      movePosition  = {x=10072,    y=-71.24, z=3908}
        -- },
        {    -- RED MID -> SOLO BUSH
                magneticSpot = {x=9223, y=52.95, z=7525.34},
                clickPosition = {x=9603.52, y=54.71, z=7872.23},
                wardPosition = {x=9873.90, y=51.52, z=7957.76},
                movePosition = {x=9223, y=52.95, z=7525.34}
        },
        {    -- RED MID FROM TOWER -> SOLO BUSH
                magneticSpot =  {x=9127.66, y=53.76, z=8337.72},
                clickPosition = {x=9624.05, y=72.46, z=8122.68},
                wardPosition =  {x=9873.90, y=51.52, z=7957.76},
                movePosition  = {x=9127.66, y=53.76, z=8337.72}
        },
        {    -- BLUE MID -> SOLO BUSH
                magneticSpot =  {x=5667.73, y=51.65, z=7360.45},
                clickPosition = {x=5148.87, y=50.41, z=7205.80},
                wardPosition =  {x=4923.90, y=50.64, z=7107.76},
                movePosition  = {x=5667.73, y=51.65, z=7360.45}
        },
        {    -- BLUE MID FROM TOWER -> SOLO BUSH
                magneticSpot =  {x=5621.65, y=52.81, z=6452.61},
                clickPosition = {x=5255.46, y=50.44, z=6866.24},
                wardPosition =  {x=4923.90, y=50.64, z=7107.76},
                movePosition  = {x=5621.65, y=52.81, z=6452.61}
        },
        {    -- NASHOR -> TRI BUSH
                magneticSpot =  {x=4724, y=-71.24, z=10856},
                clickPosition = {x=4627.26, y=-71.24, z=11311.69},
                wardPosition =  {x=4473.9, y=51.4, z=11457.76},
                movePosition  = {x=4724, y=-71.24, z=10856}
        },
        {    -- BLUE TOP -> SOLO BUSH
                magneticSpot  = {x=2824, y=54.33, z=10356},
                clickPosition = {x=3078.62, y=54.33, z=10868.39},
                wardPosition  = {x=3078.62, y=-67.95, z=10868.39},
                movePosition  = {x=2824, y=54.33, z=10356}
        },
        { -- BLUE MID -> ROUND BUSH
                magneticSpot  = {x=5474, y=51.67, z=7906},
                clickPosition = {x=5132.65, y=51.67, z=8373.2},
                wardPosition  = {x=5123.9, y=-21.23, z=8457.76},
                movePosition  = {x=5474, y=51.67, z=7906}
        },
        { -- BLUE MID -> RIVER LANE BUSH
                magneticSpot  = {x=5874, y=51.65, z=7656},
                clickPosition = {x=6202.24, y=51.65, z=8132.12},
                wardPosition  = {x=6202.24, y=-67.39, z=8132.12},
                movePosition  = {x=5874, y=51.65, z=7656}
        },
        { -- BLUE LIZARD -> DRAGON PASS BUSH
                magneticSpot  = {x=8022, y=53.72, z=4258},
                clickPosition = {x=8400.68, y=53.72, z=4657.41},
                wardPosition  = {x=8523.9, y=51.24, z=4707.76},
                movePosition  = {x=8022, y=53.72, z=4258}
        },
        { -- RED MID -> ROUND BUSH
                magneticSpot  = {x=9372, y=52.63, z=7008},
                clickPosition = {x=9703.5, y=52.63, z=6589.9},
                wardPosition  = {x=9823.9, y=23.47, z=6507.76},
                movePosition  = {x=9372, y=52.63, z=7008}
        },
        { -- RED MID -> RIVER ROUND BUSH // Inconsistent Placement
                magneticSpot  = {x=9072, y=53.04, z=7158},
                clickPosition = {x=8705.95, y=53.04, z=6819.1},
                wardPosition  = {x=8718.88, y=95.75, z=6764.86},
                movePosition  = {x=9072, y=53.04, z=7158}
        },
        --      { -- RED MID -> RIVER LANE BUSH
        --              magneticSpot  = {x=8530.27, y=46.98, z=6637.38},
        --              clickPosition = {x=8539.27, y=46.98, z=6637.38},
        --              wardPosition  = {x=8396.10, y=46.98, z=6464.81},
        --              movePosition  = {x=8779.17, y=46.98, z=6804.70}
        --      },
        { -- RED BOTTOM -> SOLO BUSH
                magneticSpot  = {x=12422, y=51.73, z=4508},
                clickPosition = {x=12353.94, y=51.73, z=4031.58},
                wardPosition  = {x=12023.9, y=-66.25, z=3757.76},
                movePosition  = {x=12422, y=51.73, z=4508}
        },
        { -- RED LIZARD -> NASHOR PASS BUSH -- FIXED FOR MORE VISIBLE AREA
                magneticSpot  = {x=6824, y=56, z=10656},
                clickPosition = {x=6484.47, y=53.5, z=10309.94},
                wardPosition  = {x=6323.9, y=53.62, z=10157.76},
                movePosition  = {x=6824, y=56, z=10656}
        },
        { -- BLUE GOLEM -> BLUE LIZARD
                magneticSpot  = {x=8272,    y=51.13, z=2908},
                clickPosition = {x=8163.7056, y=51.13, z=3436.0476},
                wardPosition  = {x=8163.71, y=51.6628, z=3436.05},
                movePosition  = {x=8272,    y=51.13, z=2908}
        },
        { -- RED GOLEM -> RED LIZARD
                magneticSpot  = {x=6574, y=56.48, z=12006},
                clickPosition = {x=6678.08, y=56.48, z=11477.83},
                wardPosition  = {x=6678.08, y=53.85, z=11477.83},
                movePosition  = {x=6574, y=56.48, z=12006}
        },
        { -- BLUE TOP SIDE BRUSH
                magneticSpot  = {x=1774, y=52.84, z=10756},
                clickPosition = {x=2302.36, y=52.84, z=10874.22},
                wardPosition  = {x=2773.9, y=-71.24, z=11307.76},
                movePosition  = {x=1774, y=52.84, z=10756}
        },
        { -- MID LANE DEATH BRUSH
                magneticSpot  = {x=5874, y=-70.12, z=8306},
                clickPosition = {x=5332.9, y=-70.12, z=8275.21},
                wardPosition  = {x=5123.9, y=-21.23, z=8457.76},
                movePosition  = {x=5874, y=-70.12, z=8306}
        },
        { -- MID LANE DEATH BRUSH RIGHT SIDE
                magneticSpot  = {x=9022, y=-71.24, z=6558},
                clickPosition = {x=9540.43, y=-71.24, z=6657.68},
                wardPosition  = {x=9773.9, y=9.56, z=6457.76},
                movePosition  = {x=9022, y=-71.24, z=6558}
        },
        { -- BLUE INNER TURRET JUNGLE
                magneticSpot  = {x=6874, y=50.52, z=1708},
                clickPosition = {x=6849.11, y=50.52, z=2252.01},
                wardPosition  = {x=6723.9, y=52.17, z=2507.76},
                movePosition  = {x=6874, y=50.52, z=1708}
        },
        { -- RED INNER TURRET JUNGLE
                magneticSpot  = {x=8122, y=52.84, z=13206},
                clickPosition = {x=8128.53, y=52.84, z=12658.41},
                wardPosition  = {x=8323.9, y=56.48, z=12457.76},
                movePosition  = {x=8122, y=52.84, z=13206}
        }
	}
	
	self.wardItems = {
		{ id = 2043, spellName = "VisionWard", screenName = "Vision Ward"},
		{ id = 2044, spellName = "sightward", screenName = "Sight Ward"},
		{ id = 3340, spellName = "TrinketTotemLvl1", screenName = "?"},
		{ id = 3350, spellName = "TrinketTotemLvl2", screenName = "?"},
		{ id = 3361, spellName = "TrinketTotemLvl3", screenName = "?"},
		{ id = 3362, spellName = "TrinketTotemLvl3B", screenName = "?"},
		{ id = 2045, spellName = "ItemGhostWard", screenName = "?"},
		{ id = 2049, spellName = "ItemGhostWard", screenName = "?"},
		{ id = 2050, spellName = "ItemMiniWard", screenName = "?"}
	}
	
	AddTickCallback(function() self:OnTick() end)
	AddDrawCallback(function() self:OnDraw() end)
	AddMsgCallback(function(msg, wParam) self:OnWndMsg(msg,wParam) end)
end

function WA:OnTick()
	if self.putSafeWard ~= nil then
		if GetDistance(self.safeWardSpots[self.putSafeWard].clickPosition, myHero) <= 600 then
			CastSpell(self.wardSlot, self.safeWardSpots[self.putSafeWard].clickPosition.x, self.safeWardSpots[self.putSafeWard].clickPosition.z)
			self.putSafeWard = nil
		end
	end
	
	if self.menu.castWard and self:checkWardsAvailable()~=nil then
		self.drawWardSpots = true
	end
end

function WA:checkWardsAvailable()
	for slot = ITEM_1, ITEM_7 do
		for i,wardItem in pairs(self.wardItems) do
			if GetSpellData(slot) and GetSpellData(slot).name == wardItem.spellName and myHero:CanUseSpell(slot) == READY then return slot end
		end
	end
	return nil
end

function WA:OnWndMsg(msg,wParam)
		if not self.menu.enable then return end
        if msg == KEY_DOWN and self.menu.castWard then
                self.wardSlot = nil
				
                if self.menu.enable then
                        self.wardSlot = self:checkWardsAvailable()
                else
                        self.wardSlot = nil
                        self.drawWardSpots = false
                end
				
                if self.wardSlot then
                        local item = myHero:getItem(self.wardSlot)
                        for i,wardItem in pairs(self.wardItems) do
                                if item and myHero:CanUseSpell(self.wardSlot) == READY then
                                        self.drawWardSpots = true
                                        return
                                end
                        end
                end
        elseif msg == WM_LBUTTONUP and self.drawWardSpots then
                self.drawWardSpots = false
        elseif msg == WM_LBUTTONDOWN and self.drawWardSpots then
                self.drawWardSpots = false
                for i,wardSpot in pairs(self.wardSpot) do
                        if GetDistance(wardSpot, mousePos) <= 250 then
                                CastSpell(self.wardSlot, wardSpot.x, wardSpot.z)
                                return
                        end
                end
                if self.menu.situational then
                        for i,wardSpot in pairs(self.situationalWards) do
                                if GetDistance(wardSpot, mousePos) <= 250 then
                                        CastSpell(self.wardSlot, wardSpot.x, wardSpot.z)
                                        return
                                end
                        end
                end
                for i,wardSpot in pairs(self.safeWardSpots) do
                        if GetDistance(wardSpot.magneticSpot, mousePos) <= 120 then
								myHero:MoveTo(wardSpot.movePosition.x, wardSpot.movePosition.z)
                                self.putSafeWard = i
                                return
                        end
                end
        elseif msg == WM_RBUTTONDOWN and self.drawWardSpots then
                self.drawWardSpots = false
        elseif msg == WM_RBUTTONDOWN then
                self.putSafeWard = nil
        end
end

function WA:get2DFrom3D(x, y, z)
        local pos = WorldToScreen(D3DXVECTOR3(x, y, z))
        return pos.x, pos.y, OnScreen(pos.x, pos.y)
end

function WA:round(num)
        if num >= 0 then return math.floor(num+.5) else return math.ceil(num-.5) end
end

function WA:DrawCircleNextLvl3D(x, y, z, radius, width, color, chordlength)
        radius = radius or 300
        quality = math.max(8, self:round(180 / math.deg((math.asin((chordlength / (2 * radius)))))))
        quality = math.pi / quality
        radius = radius * .92
        local points = {}
        for theta = 0, 2 * math.pi + quality, quality do
                local c = WorldToScreen(D3DXVECTOR3(x + radius * math.cos(theta), y, z - radius * math.sin(theta)))
                points[#points + 1] = D3DXVECTOR2(c.x, c.y)
        end
        DrawLines2(points, width or 1, color or 4294967295)
end
 
function WA:DrawCircles3D(x, y, z, radius, color)
        local vPos1 = Vector(x, y, z)
        local vPos2 = Vector(cameraPos.x, cameraPos.y, cameraPos.z)
        local tPos = vPos1 - (vPos1 - vPos2):normalized() * radius
        local sPos = WorldToScreen(D3DXVECTOR3(tPos.x, tPos.y, tPos.z))
        if OnScreen({x = sPos.x, y = sPos.y }, {x = sPos.x, y = sPos.y }) then
                self:DrawCircleNextLvl3D(x, y, z, radius, 1, color, 300)
        end
end

function WA:OnDraw()
	if not self.menu.enable then return end   
	
	local wardAvailable = self:checkWardsAvailable()
	if self.menu.printAvailable and wardAvailable~=nil then
		DrawText("WARD AVAILABLE TO CAST!", 21, 5, 100, 0xFFFFFFFF)      
	end
	
	if self.drawWardSpots then
		for i, wardSpot in pairs(self.wardSpot) do
			local wardColor = (GetDistance(wardSpot, mousePos) <= 250) and ARGB(255,0,255,0) or ARGB(255,255,255,255)
			local x, y, onScreen = self:get2DFrom3D(wardSpot.x, wardSpot.y, wardSpot.z)
			if onScreen then
				self:DrawCircles3D(wardSpot.x, wardSpot.y, wardSpot.z, 30, wardColor)
				self:DrawCircles3D(wardSpot.x, wardSpot.y, wardSpot.z, 250, wardColor)
			end
		end
		
		if self.menu.situational then
			for i, wardSpot in pairs(self.situationalWards) do
				local wardColor = (GetDistance(wardSpot, mousePos) <= 250) and ARGB(255,0,255,0) or ARGB(255,255,255,255)
				local x, y, onScreen = get2DFrom3D(wardSpot.x, wardSpot.y, wardSpot.z)
				
				if onScreen then
					self:DrawCircles3D(wardSpot.x, wardSpot.y, wardSpot.z, 30, wardColor)
					self:DrawCircles3D(wardSpot.x, wardSpot.y, wardSpot.z, 250, wardColor)
				end
			end
		end
			
		for i,wardSpot in pairs(self.safeWardSpots) do
			local wardColor  = (GetDistance(wardSpot.magneticSpot, mousePos) <= 100) and ARGB(255,0,255,0) or ARGB(255,255,255,255)
			local arrowColor = (GetDistance(wardSpot.magneticSpot, mousePos) <= 100) and ARGB(255,0,255,0) or ARGB(255,255,255,255)
			local x, y, onScreen = get2DFrom3D(wardSpot.magneticSpot.x, wardSpot.magneticSpot.y, wardSpot.magneticSpot.z)
			
			if onScreen then
					self:DrawCircles3D(wardSpot.wardPosition.x, wardSpot.wardPosition.y, wardSpot.wardPosition.z, 30, wardColor)
					self:DrawCircles3D(wardSpot.magneticSpot.x, wardSpot.magneticSpot.y, wardSpot.magneticSpot.z, 100, wardColor)
			end

			local magneticWardSpotVector = Vector(wardSpot.magneticSpot.x, wardSpot.magneticSpot.y, wardSpot.magneticSpot.z)
			local wardPositionVector = Vector(wardSpot.wardPosition.x, wardSpot.wardPosition.y, wardSpot.wardPosition.z)
			local directionVector = (wardPositionVector-magneticWardSpotVector):normalized()
			local line1Start = magneticWardSpotVector + directionVector:perpendicular() * 100
			local line1End = wardPositionVector + directionVector:perpendicular() * 30
			local line2Start = magneticWardSpotVector + directionVector:perpendicular2() * 100
			local line2End = wardPositionVector + directionVector:perpendicular2() * 30
			local p1 = WorldToScreen(D3DXVECTOR3(line1Start.x,line1Start.y,line1Start.z))
			local p2 = WorldToScreen(D3DXVECTOR3(line1End.x,line1End.y,line1End.z))
			local p3 = WorldToScreen(D3DXVECTOR3(line2Start.x,line2Start.y,line2Start.z))
			local p4 = WorldToScreen(D3DXVECTOR3(line2End.x,line2End.y,line2End.z))
			
			DrawLine(p1.x, p1.y, p2.x, p2.y, 1, arrowColor)
			DrawLine(p3.x, p3.y, p4.x, p4.y, 1, arrowColor)
		end
	end
end
