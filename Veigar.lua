local Version = 1.03

class 'ScriptUpdate'
class 'Veigar'

function CustomPrint(msg) PrintChat("<font color=\"#FF3300\"><b>[Veigar, The Unknown Hero]</b></font> <font color=\"#FFFFFF\">"..msg.."</font>")
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

  Veigar = Veigar()
  
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function Veigar:__init()
  self:Update()
  
end

function Veigar:Update()

  local ToUpdate = {}
  
  ToUpdate.Host = "raw.githubusercontent.com"
  ToUpdate.VersionPath = "/UnknownHeroe/BoL/master//version/Veigar.version"
  ToUpdate.ScriptPath =  "/UnknownHeroe/BoL/master/Veigar.lua"
  ToUpdate.SavePath = SCRIPT_PATH .. GetCurrentEnv().FILE_NAME
  ToUpdate.CallbackUpdate = function(NewVersion, OldVersion) print("<font color=\"#FF3300\"><b>[Veigar, The Unknown Hero] </b></font> <font color=\"#FFFFFF\">Updated to version ("..NewVersion..") Please F9 Twice! </b></font>") end
  ToUpdate.CallbackNoUpdate = function(OldVersion) print("<font color=\"#FF3300\"><b>[Veigar, The Unknown Hero] </b></font> <font color=\"#FFFFFF\">No Updates Found!</b></font>") end
  ToUpdate.CallbackNewVersion = function(NewVersion) print("<font color=\"#FF3300\"><b>[Veigar, The Unknown Hero] </b></font> <font color=\"#FFFFFF\">New Version found ("..NewVersion.."). Please wait until its downloaded!</b></font>") end
  ToUpdate.CallbackError = function(NewVersion) print("<font color=\"#FF3300\"><b>[Veigar, The Unknown Hero] </b></font> <font color=\"#FFFFFF\">Error while Downloading. Please try again.</b></font>") end
  ScriptUpdate(Version, true, ToUpdate.Host, ToUpdate.VersionPath, ToUpdate.ScriptPath, ToUpdate.SavePath, ToUpdate.CallbackUpdate,ToUpdate.CallbackNoUpdate, ToUpdate.CallbackNewVersion,ToUpdate.CallbackError)
end

if myHero.charName ~= "Veigar" then return end

----------------------
--   Script Status  --
----------------------
assert(load(Base64Decode("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"), nil, "bt", _ENV))() ScriptStatus("SFIIIHIKKHN") 

if FileExist(LIB_PATH .. "/VPrediction.lua") then
	require("VPrediction")
else
	CustomPrint("VPrediction is required, please download it and reload")
	return
end

if FileExist(LIB_PATH .. "/UPL.lua") then
  require("UPL")
  UPL = UPL()
else 
  CustomPrint("Downloading UPL, please don't press F9")
  DelayAction(function() DownloadFile("https://raw.github.com/nebelwolfi/BoL/master/Common/UPL.lua".."?rand="..math.random(1,10000), LIB_PATH.."UPL.lua", function () CustomPrint("Successfully downloaded UPL. Press F9 twice.") end) end, 3) 
  return
end

function OnLoad()
	Variables()
	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, 1500, DAMAGE_MAGIC, true)
	VP = VPrediction()
	LoadSpells()
	Menu()
	Veigar = Veigar()
	CustomPrint("Succsesufully Loaded Version "..Version.."!")
end

function OnTick()
	Target = GetTarget()
	KS()
	autoFarm()
	
	if settings.key.comboKey then
		if IsReady(_E) and settings.spell.E.ComboE == true and settings.spell.E.manaECombo <= 100*myHero.mana/myHero.maxMana then
			UseStun(Target)
		end
		
		if IsReady(_W) and settings.spell.W.ComboW == true and settings.spell.W.manaWCombo <= 100*myHero.mana/myHero.maxMana then
			CustomCast(_W, Target)
		end
		
		if IsReady(_Q) and settings.spell.Q.ComboQ == true and settings.spell.Q.manaQCombo <= 100*myHero.mana/myHero.maxMana then
			CustomCast(_Q, Target)
		end
		
		 if IsReady(_R) and settings.spell.R.ComboR == true and Target.health < GetDmg(_R, myHero, Target) then
      CastSpell(_R, Target)
	end
		end
	
	if settings.key.harassKey then
			if IsReady(_E) and settings.spell.E.HarassE == true and settings.spell.E.manaEHarass <= 100*myHero.mana/myHero.maxMana then
			UseStun(Target)
		end
		
		if IsReady(_W) and settings.spell.W.HarassW == true and settings.spell.W.manaWHarass <= 100*myHero.mana/myHero.maxMana then
			CustomCast(_W, Target)
		end
		
		if IsReady(_Q) and settings.spell.Q.HarassQ == true and settings.spell.Q.manaQHarass <= 100*myHero.mana/myHero.maxMana then
			CustomCast(_Q, Target)
		end
		
		 if IsReady(_R) and settings.spell.R.HarassR == true and settings.spell.R.manaRHarass and Target.health < GetDmg(_R, myHero, Target) then
      CastSpell(_R, Target)
end
	
	if settings.key.lastHit or settings.key.laneClear then
		Farm()
	end
	
	hitWInE()
end
	end
	
function CustomCast(spell, target, from, chance)
	from = from or myHero
	chance = chance or 2
	
	if spell == _Q and UPL:ActivePred() == "HPrediction" then chance = 1 end
	if spell == _W and UPL:ActivePred() == "HPrediction" then chance = 1.25 end
	
	if not target or target.dead then return end
	if myHero.dead then return end
	if not IsReady(spell) then return end
	if spells[spell].range ~= nil and GetDistance(from, target) > spells[spell].range then return end
	
	if spells[spell].type ~= nil and spells[spell].width ~= nil and spells[spell].delay ~= nil and spells[spell].range ~= nil and spells[spell].width ~= nil then
		local CastPosition, HitChance, HeroPosition = UPL:Predict(spell, from, target)		
		if HitChance >= chance and GetDistance(CastPosition) < spells[spell].range then
			if spell == _Q then
				local mBool, mTable = GetMinionCollision(myHero, CastPosition, spells[_Q].width)
				if mBool and mTable ~= nil and #mTable > 1 then	return end
			end
		
			CastSpell(spell, CastPosition.x, CastPosition.z)
		end
	else
		CastSpell(spell, target)
	end
end

function OnApplyBuff(unit, target, buff)
	if IsReady(_W) or IsReady(_E) then
		for i,v in ipairs(ccP) do
			if ccP[i] == buff.type then
				if target.team ~= myHero.team and target.type == myHero.type then
					if GetDistance(target) < spells[_E].range + spells[_E].width and not target.dead then
						UseStun(target)
					end
					
					if GetDistance(target) < spells[_W].range and not target.dead then
						CastSpell(_W, target.x, target.z)
					end
				end
			end
		end
	end
end

function Menu()
	settings = scriptConfig("Veigar, The Unknown Hero", "Veigar")

-- Draws --
	settings:addSubMenu("[" .. myHero.charName.. "] - Draw Settings", "draw")
		settings.draw:addParam("Q", "Draw Q", SCRIPT_PARAM_ONOFF, true)
    settings.draw:addParam("W", "Draw W", SCRIPT_PARAM_ONOFF, true)
    settings.draw:addParam("E", "Draw E", SCRIPT_PARAM_ONOFF, true)
    settings.draw:addParam("R", "Draw R", SCRIPT_PARAM_ONOFF, true)
    settings.draw:addParam("DMG", "Draw Damage", SCRIPT_PARAM_ONOFF, true)
		settings.draw:addParam("target", "Draw Target", SCRIPT_PARAM_ONOFF, true)
		settings.draw:addParam("permashow", "Draw PermaShow (Reload)", SCRIPT_PARAM_ONOFF, true)
		
-- Farming --	
	settings:addSubMenu("[" .. myHero.charName.. "] - Farm Settings", "farm")
		settings.farm:addParam("info", "                  -- Lane Clear  --", SCRIPT_PARAM_INFO, "")
			settings.farm:addParam("qlaneclear", "Use Q",SCRIPT_PARAM_ONOFF, false) 
			settings.farm:addParam("qlaneclearmana", "Mana Q % - Lane Clear", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
			
				settings.farm:addParam("info3", "", SCRIPT_PARAM_INFO,"")
				
			settings.farm:addParam("wlaneclear", "Use W", SCRIPT_PARAM_ONOFF, false)
			settings.farm:addParam("wlaneclearmana", "Mana W % - Lane Clear", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)	
			
				settings.farm:addParam("info3", "", SCRIPT_PARAM_INFO,"")
		
		settings.farm:addParam("info", "                  -- Last Hit --", SCRIPT_PARAM_INFO, "")
				settings.farm:addParam("qlasthit", "Use Q", SCRIPT_PARAM_ONOFF, false)
				settings.farm:addParam("qlasthitmana", "Mana Q % - Last Hit", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
				
-- Keys --
	settings:addSubMenu("[" .. myHero.charName.. "] - Keys", "key")
		settings.key:addParam("comboKey", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
		settings.key:addParam("laneClear", "Lane Clear", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("V"))
		settings.key:addParam("lastHit", "Last Hit", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("X"))
		settings.key:addParam("harassKey", "Harass", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("C"))
		
-- Spell Settings --
	settings:addSubMenu("[" .. myHero.charName .. "] - Spell Settings", "spell")
	
	settings.spell:addSubMenu("[" .. myHero.charName.. "] - Baleful Strike (Q)", "Q")
		settings.spell.Q:addParam("ComboQ", "Combo", SCRIPT_PARAM_ONOFF, true)
			settings.spell.Q:addParam("manaQCombo", "Mana Q % - Combo", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		settings.spell.Q:addParam("HarassQ", "Harass", SCRIPT_PARAM_ONOFF, true)
			settings.spell.Q:addParam("manaQHarass", "Mana Q % - Harass", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
			
			settings.spell:addSubMenu("[" .. myHero.charName.. "] - Dark Matter (W)", "W")
		settings.spell.W:addParam("ComboW", "Combo", SCRIPT_PARAM_ONOFF, true)
			settings.spell.W:addParam("manaWCombo", "Mana W % - Combo", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		settings.spell.W:addParam("HarassW", "Harass", SCRIPT_PARAM_ONOFF, true)
			settings.spell.W:addParam("manaWHarass", "Mana W % - Harass", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
			
			settings.spell:addSubMenu("[" .. myHero.charName.. "] - Event Horizion (E)", "E")
		settings.spell.E:addParam("ComboE", "Combo", SCRIPT_PARAM_ONOFF, true)
			settings.spell.E:addParam("manaECombo", "Mana E % - Combo", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		settings.spell.E:addParam("HarassE", "Harass", SCRIPT_PARAM_ONOFF, true)
			settings.spell.E:addParam("manaEHarass", "Mana E % - Harass", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
			
			settings.spell:addSubMenu("[" .. myHero.charName.. "] - Primordial Burst (R)", "R")
		settings.spell.R:addParam("ComboR", "Combo", SCRIPT_PARAM_ONOFF, true)
			settings.spell.R:addParam("manaRCombo", "Mana R % - Combo", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		settings.spell.R:addParam("HarassR", "Harass", SCRIPT_PARAM_ONOFF, true)
			settings.spell.R:addParam("manaRHarass", "Mana R % - Harass", SCRIPT_PARAM_SLICE, 30, 0, 100, 0)
		
	settings:addSubMenu("Orbwalk Settings", "orb")
	
	SetupOrbwalk(settings.orb)
    UPL:AddToMenu(settings) 
		
			settings:addParam("info3", "", SCRIPT_PARAM_INFO,"")
		 settings:addParam("infobox", "         Veigar, The Unknown Hero", SCRIPT_PARAM_INFO, "") 
		 settings:addParam("infobox2", "                      Version:  "..Version.. "         ", SCRIPT_PARAM_INFO,"")
		 
		 	if settings.draw.permashow then
		  settings:permaShow("infobox")
			settings.key:permaShow("comboKey")
			settings.key:permaShow("harassKey")
		end	
end

function OnProcessSpell(object, spell)
	if object.type == myHero.type and object.team ~= myHero.team and GetDistance(object) < 2000 then
		if spell.name == "summonerflash" then
			CastEOnDash(Vector(object) + 500 * (Vector(spell.endPos) - Vector(object)):normalized())
		end
	end
	
	if spell.name == GetSpellData(_W).name then
		lastWPos = {x = spell.endPos.x, y = spell.endPos.y, z = spell.endPos.z}
		lastWTime = os.clock() * 1000
	end
	
	if spell.name == GetSpellData(_E).name then
		lastEPos = {x = spell.endPos.x, y = spell.endPos.y, z = spell.endPos.z}
		lastETime = os.clock() * 1000
	end
	
	if unit.isMe and spell.target and spell.name:find("Attack") then
		lastAttack = spell.target.networkID
		lastAttackTime = os.clock() * 1000
	end
	
	if object.charName == "Zed" and spell.name == object:GetSpellData(_R).name then
		CastEOnDash(myHero)
	end
	
	if object.charName == "Katarina" and spell.name == object:GetSpellData(_R).name then
		CastEOnDash(myHero)
	end
end

function OnNewPath(unit,startPos,endPos,isDash,dashSpeed,dashGravity,dashDistance)
	if unit.type == myHero.type and unit.team ~= myHero.team then
		if isDash then 
			if dashDistance / dashSpeed > 0.5 then
				if GetDistance(endPos) < spells[_E].range + spells[_E].width then
					CastEOnDash(Vector(startPos) + (GetDistance(startPos, endPos) + 50) * (Vector(endPos) - Vector(startPos)):normalized())
				end
			end
		end
	end
end

function OnDraw()
	if myHero.dead then return end
	
	Target = GetTarget()
	
	if ValidTarget(Target) then
		DrawCircle(Target.x, Target.y, Target.z, 150, 0xffffff00)
	end
	
	if IsReady(_Q) and settings.draw.Q == true then DrawCircle(myHero.x, myHero.y, myHero.z, spells[_Q].range, 0xFFFF0000) end
	if IsReady(_W) and settings.draw.W == true then DrawCircle(myHero.x, myHero.y, myHero.z, spells[_W].range, 0xFFFF0000) end
	if IsReady(_E) and settings.draw.E == true then DrawCircle(myHero.x, myHero.y, myHero.z, spells[_E].range + spells[_E].width, 0xFFFF0000) end
	if IsReady(_R) and settings.draw.R == true then DrawCircle(myHero.x, myHero.y, myHero.z, spells[_R].range, 0xFFFF0000) end
end

function SetupOrbwalk(menu)
	if _G.NebelwolfisOrbWalkerInit then
		if _G.NebelwolfisOrbWalkerLoaded then
			CustomPrint("Found Nebelwolfi's Orb Walker")
			menu:addParam("Info", "Nebelwolfi's Orb Walker detected!", SCRIPT_PARAM_INFO, "")
			orbwalker = "nebel"
		else
			DelayAction(function() SetupOrbwalk(settings.orb) end, 1)
		end
	elseif _G.AutoCarry then
		if _G.Reborn_Initialised then
			CustomPrint("Found SAC: Reborn")
			menu:addParam("Info", "SAC: Reborn detected!", SCRIPT_PARAM_INFO, "")
			orbwalker = "sac"
		end
	elseif _G.Reborn_Loaded then
		DelayAction(function() SetupOrbwalk(settings.orb) end, 1)
	elseif FileExist(LIB_PATH .. "SxOrbWalk.lua") then
		require 'SxOrbWalk'
		SxOrb = SxOrbWalk()
		SxOrb:LoadToMenu(menu)
		CustomPrint("Found SxOrb.")
		orbwalker = "vp"
	else
		CustomPrint("No valid Orbwalker found")
	end
end

function hitWInE()
	if lastEPos and lastETime then
		if os.clock() * 1000 - lastETime < 1500 and os.clock() * 1000 - lastETime > 750 then
			if GetDistance(lastEPos) < spells[_W].range then
				for i, enemy in pairs(GetEnemyHeroes()) do
					if enemy.visible and not enemy.dead then
						if GetDistance(enemy, lastEPos) < 350 then 
							CastSpell(_W, enemy.x, enemy.z)
						end
					end
				end
			end
		end
	end
end

function Farm()
	if os.clock() * 1000 - lastFarmCheck < 200 then return end 

	EnemyMinions:update()
	
	for i, minion in pairs(EnemyMinions.objects) do
		if minion.health < getDmg("Q", minion, myHero) then
			if VP:GetPredictedHealth2(minion, spells[_Q].delay / 1000 + (GetDistance(minion) / spells[_Q].speed)) > 0 and (lastAttack ~= minion.networkID or os.clock() * 1000 - lastAttackTime > 750) then
				local mBool, mTable = GetMinionCollision(myHero, minion, spells[_Q].width)
				if mBool and mTable ~= nil and #mTable > 1 then	return end
				CastSpell(_Q, minion.x, minion.z)
			end
		end
	end
	
	lastFarmCheck = os.clock() * 1000
end

function autoFarm()
	if settings.farm.qlaneclear and settings.farm.qlaneclearmana <= 100*myHero.mana/myHero.maxMana and settings.key.laneClear then
		Max = 0
		local MaxPos
		EnemyMinions:update()
		for i, minion in pairs(EnemyMinions.objects) do
					Count = GetNMinionsHit(minion, qwidth)
				if Count > Max then
					Max = Count
					MaxPos = Vector(minion.x, 0, minion.z)
						local qDamage = getDmg("Q",minion,myHero)
							if qDamage == minion.health or qDamage <= minion.health then
						CastSpell(_Q, MaxPos.x, MaxPos.z)
					end
				end
			end
		end
			
			if settings.farm.wlaneclear and settings.farm.wlaneclearmana <= 100*myHero.mana/myHero.maxMana and settings.key.laneClear then
		local MaxPos
		Max = 1
		EnemyMinions:update()
		for i, minion in pairs(EnemyMinions.objects) do
					Count = GetNMinionsHit(minion, wwidth)
				if Count > Max then
					Max = Count
					MaxPos = Vector(minion.x, 3, minion.z)
					local wDamage = getDmg("W",minion,myHero)
						if wDamage == minion.health or wDamage <= minion.health then
						CastSpell(_W, MaxPos.x, MaxPos.z)
					end
				end
			end
		end
			
			if settings.farm.qlasthit and settings.farm.qlasthitmana <= 100*myHero.mana/myHero.maxMana and settings.key.lastHit then
		Max = 0
		local MaxPos
		EnemyMinions:update()
		for i, minion in pairs(EnemyMinions.objects) do
					Count = GetNMinionsHit(minion, qwidth)
				if Count > Max then
					Max = Count
					MaxPos = Vector(minion.x, 0, minion.z)
	          local qDamage = getDmg("Q",minion,myHero)
					  if qDamage >= minion.health then
						CastSpell(_Q, MaxPos.x, MaxPos.z)
					end
				end
			end
		end
	end
	
	function GetNMinionsHit(Pos, width)
	local count = 0
	for i, minion in pairs(EnemyMinions.objects) do
		if GetDistance(minion, Pos) < (spells[_Q].width + 50) then
			count = count + 1
		end
	end
	return count
end

function LoadSpells()
	for spell = _Q, _R  do
		if spells[spell].type ~= nil then
			UPL:AddSpell(spell, { speed = spells[spell].speed, delay = spells[spell].delay, range = spells[spell].range, width = spells[spell].width, collision = spells[spell].collision, aoe = spells[spell].aoe, type = spells[spell].type })
		end
	end
end

function CastEOnDash(predicted)
	local CircX, CircZ
	local dis = math.sqrt((myHero.x - predicted.x) ^ 2 + (myHero.z - predicted.z) ^ 2)
	
	CircX = predicted.x + spells[_E].width * ((myHero.x - predicted.x) / dis)
	CircZ = predicted.z + spells[_E].width * ((myHero.z - predicted.z) / dis)
	
	if dis < spells[_E].range then
		CastSpell(_E, CircX, CircZ)
	end
end

function Variables()
	spells = {}
	spells[_Q] = {range = 950, delay = 0.25, speed = 2000, width = 70, type = "linear", collision = false, aoe = false}
	spells[_W] = {range = 900, delay = 1.5, speed = math.huge, width = 115, type = "circular", collision = false, aoe = true}
	spells[_E] = {range = 700, delay = 0.25, speed = 20, width = 375, type = "circular", collision = false, aoe = true}
	spells[_R] = {range = 650}
	
	ccTable = { 'Stun', 'Taunt', 'Root', 'Flee', 'Supress' }
	ccP = {5, 8, 11, 28, 24}  
	
	lastWPos = nil
	lastWTime = nil
	
	lastEPos = nil
	lastETime = nil
	
	lastAttack = myHero.networkID
	lastAttackTime = os.clock() * 1000
	
	lastFarmCheck = os.clock() * 1000
	
	EnemyMinions = minionManager(MINION_ENEMY,950, myHero, MINION_SORT_HEALTH_ASC)
end

function GetTarget()
	ts:update()
	if _G.AutoCarry and _G.AutoCarry.Crosshair and ValidTarget(_G.AutoCarry.Crosshair:GetTarget()) then _G.AutoCarry.Crosshair:SetSkillCrosshairRange(1500) return _G.AutoCarry.Crosshair:GetTarget() end
	if SelectedTarget ~= nil and not SelectedTarget.dead and SelectedTarget.type == myHero.type and SelectedTarget.team ~= myHero.team then
		if GetDistance(SelectedTarget) > 1500 and ts.target ~= nil then
			return ts.target
		else
			return SelectedTarget
		end
	end
	return ts.target
end

function OnWndMsg(msg,key)
	if msg == WM_LBUTTONDOWN then
		local enemy, distance = ClosestEnemy(mousePos) 
		
		if distance < 150 then SelectedTarget = enemy end
	end
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

function GetDmg(spell, target, source)
	local dmg = 0
	
	if GetSpellData(spell).level > 0 then
		if spell == _Q then
			dmg = 35 + GetSpellData(_Q).level * 45 + 0.6 * source.ap
		elseif spell == _W then
			dmg = 70 + GetSpellData(_W).level * 50 + 1 * source.ap
		elseif spell == _R then
			dmg = 125 + GetSpellData(_R).level * 125 + 1 * source.ap + 0.8 * target.ap
		end
	end

	local MagicPen   = math.floor(source.magicPen)
	local MagicPenPercent  = math.floor(source.magicPenPercent * 100) / 100

	local MagicArmor   = target.magicArmor * MagicPenPercent - MagicPen
	local MagicArmorPercent = MagicArmor > 0 and math.floor(MagicArmor*100/(100+MagicArmor))/100 or math.ceil(MagicArmor*100/(100-MagicArmor))/100
	
	return math.floor(dmg * (1-MagicArmorPercent))
end

function KS()
	for i, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.dead and enemy.visible then
			if IsReady(_R) and enemy.health < GetDmg(_R, enemy, myHero) and GetDistance(enemy) < spells[_R].range then
				CastSpell(_R, enemy)
			elseif IsReady(_Q) and enemy.health < GetDmg(_Q, enemy, myHero) then
				CustomCast(_Q, enemy)
			elseif IsReady(_R) and enemy.health < GetDmg(_R, enemy, myHero) + GetDmg(_W, enemy, myHero) and GetDistance(enemy) < spells[_R].range and lastWTime and lastWPos and os.clock() * 1000 - lastWTime < 1500 and GetDistance(lastWPos, enemy) < 120 then
				CastSpell(_R, enemy)
			end
		end
	end
end

function ValidTargetE(target)
  return target ~= nil and target.team ~= player.team and target.visible and not target.dead and GetDistance(player, target) <= (spells[_E].range + spells[_E].width)
end

function UseStun(object)
	if IsReady(_E) and object and not object.dead then
		CastESpellOnTarget(object)
	end
end

function CastESpellOnTarget(object)
	if IsReady(_E) then
		local target1 = object
		local CircX, CircZ, returnTarget
		local myHeros = heroManager.iCount

		for j = 1, myHeros, 1 do
			local target2 = heroManager:getHero(j)
			if ValidTargetE(target1) and ValidTargetE(target2) and target1.name ~= target2.name then --make sure both targets are valid enemies and in spell range
				if TargetSinRadius(target1, target2) and CircX == nil and CircZ == nil then --true if a double stun is possible

					CircX, CircZ = CalcDoubleStun(target1, target2) --calculates coords for stun

					if CircX and CircZ then
						break
					end
				end
			end
		end

		if CircX == nil or CircZ == nil then --true if double stun coords were not found
			if ValidTargetE(object) then
				CircX, CircZ = CalcSingleStun() --calculate stun coords for a single target
			end
		end
		
		if CircX and CircZ then --true if any coords were found
			CastSpell(_E, CircX, CircZ)
		end
	end
end

function TargetSinRadius(target1, target2)
	local dis, dis1, dis2, predicted1, predicted2, hitchance1, hitchance2

	predicted1, hitchance1 = VP:GetPredictedPos(target1, spells[_E].delay)
	predicted2, hitchance2  = VP:GetPredictedPos(target2, spells[_E].delay)

	if predicted1 and predicted2 then
		dis = math.sqrt((predicted2.x - predicted1.x) ^ 2 + (predicted2.z - predicted1.z) ^ 2) --find the distance between the two targets

		dis1 = math.sqrt((predicted1.x - myHero.x) ^ 2 + (predicted1.z - myHero.z) ^ 2) --distance from myHero to predicted target 1
		dis2 = math.sqrt((predicted2.x - myHero.x) ^ 2 + (predicted2.z - myHero.z) ^ 2) --distance from myHero to predicted target 2
	end

	return dis ~= nil and dis <= (spells[_E].width * 2) and dis1 <= (spells[_E].width + spells[_E].range) and dis2 <= (spells[_E].width + spells[_E].range)
end


function CalcSingleStun()
	if (GetTarget() ~= nil) and IsReady(_E) then
		local predicted, hitchance1
		predicted, hitchance1 = VP:GetPredictedPos(GetTarget(), spells[_E].delay)

		if predicted and (hitchance1 >=3) then
			local CircX, CircZ
			local dis = math.sqrt((myHero.x - predicted.x) ^ 2 + (myHero.z - predicted.z) ^ 2)
			
			CircX = predicted.x + spells[_E].width * ((myHero.x - predicted.x) / dis)
			CircZ = predicted.z + spells[_E].width * ((myHero.z - predicted.z) / dis)

			return CircX, CircZ
		end
	end
end

function CalcDoubleStun(target1, target2)
	local CircX, CircZ, predicted1, predicted2, hitchance1, hitchance2

	predicted1, hitchance1 = VP:GetPredictedPos(target1, spells[_E].delay)
	predicted2, hitchance2  = VP:GetPredictedPos(target2, spells[_E].delay)

	if predicted1 and predicted2 and (hitchance1 >=2) and (hitchance2 >=2) then

		local h1 = predicted1.x
		local k1 = predicted1.z
		local h2 = predicted2.x
		local k2 = predicted2.z

		local u = (h1) ^ 2 + (h2) ^ 2 - 2 * (h1) * (h2) - (k1) ^ 2 + (k2) ^ 2
		local w = k1 - k2
		local v = h2 - h1

		local a = 4 * (w ^ 2 + v ^ 2)
		local b = 4 * (u * w - 2 * ((v) ^ 2) * (k1))
		local c = (u) ^ 2 - 4 * ((v ^ 2)) * (spells[_E].width ^ 2 - k1 ^ 2)

		local Z1 = ((-b) + math.sqrt((b) ^ 2 - 4 * a * c)) / (2 * a) --Z coord for first solution
		local Z2 = ((-b) - math.sqrt((b) ^ 2 - 4 * a * c)) / (2 * a) --Z coord for second solution

		local d = (Z1 - k1) ^ 2 - (spells[_E].width) ^ 2
		local e = (Z1 - k2) ^ 2 - (spells[_E].width) ^ 2

		local X1 = ((h2) ^ 2 - (h1) ^ 2 - d + e) / (2 * v) -- X Coord for first solution

		local p = (Z2 - k1) ^ 2 - (spells[_E].width) ^ 2
		local q = (Z2 - k2) ^ 2 - (spells[_E].width) ^ 2

		local X2 = ((h2) ^ 2 - (h1) ^ 2 - p + q) / (2 * v) --X Coord for second solution


		--determine if these 2 points are within range, and which is closest

		local dis1 = math.sqrt((X1 - myHero.x) ^ 2 + (Z1 - myHero.z) ^ 2)
		local dis2 = math.sqrt((X2 - myHero.x) ^ 2 + (Z2 - myHero.z) ^ 2)

		if dis1 <= (spells[_E].width + spells[_E].range) and dis1 <= dis2 then
			CircX = X1
			CircZ = Z1
		end
		
		if dis2 <= (spells[_E].width + spells[_E].range) and dis2 < dis1 then
			CircX = X2
			CircZ = Z2
		end
	end
	
	return CircX, CircZ
end

function IsReady(spell)
	if not spell then return false end
	if CanUseSpell(spell) == READY then return true end
	return false
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
