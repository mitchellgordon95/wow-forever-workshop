-- Forever Workshop: snapshot this character's professions, bags, bank and
-- Auctionator prices into SavedVariables, and show one copyable export string.
--   /fw export   open the export box (paste into the planner's Import box)
--   /fw scan     re-scan bags and skills now
--   /fw prices   refresh Auctionator prices for every item seen
-- SavedVariables layout (ForeverWorkshopDB):
--   chars["Name-Realm"] = {class, level, skills={[name]=skill}, bags={[itemName]=count}, bank={[itemName]=count}, ts}
--   prices[itemName] = copper per unit (Auctionator min buyout)
--   items[itemName] = itemID

local ADDON = ...
local f = CreateFrame("Frame")
ForeverWorkshopDB = ForeverWorkshopDB or {}
local DB

local function charKey()
  local name, realm = UnitName("player"), GetRealmName()
  return name .. "-" .. (realm or "?")
end

local function initDB()
  DB = ForeverWorkshopDB
  DB.chars = DB.chars or {}
  DB.prices = DB.prices or {}
  DB.items = DB.items or {}
  local key = charKey()
  DB.chars[key] = DB.chars[key] or {}
  local c = DB.chars[key]
  c.skills = c.skills or {}
  c.bags = c.bags or {}
  c.bank = c.bank or {}
  return c
end

-- ---------- scanning ----------
local function scanSkills(c)
  wipe(c.skills)
  local _, class = UnitClass("player")
  c.class = class
  c.level = UnitLevel("player")
  -- Classic-era API: the skill window lists professions as skill lines.
  if GetNumSkillLines then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      if name and not isHeader and rank and rank > 0 then
        c.skills[name] = rank
      end
    end
  elseif GetProfessions then
    -- Retail-style fallback, in case Forever exposes this instead.
    local p1, p2, _, fishing, cooking, firstAid = GetProfessions()
    for _, idx in ipairs({ p1, p2, fishing, cooking, firstAid }) do
      if idx then
        local name, _, rank = GetProfessionInfo(idx)
        if name then c.skills[name] = rank end
      end
    end
  end
end

local function containerNumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
  return GetContainerNumSlots(bag)
end

local function containerItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount end
    return nil
  end
  local _, count, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
  return itemID, count
end

local function addItem(tbl, itemID, count)
  if not itemID or not count then return end
  local name = GetItemInfo(itemID)
  if not name then
    -- Not cached yet; ask the client and pick it up on the next scan.
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return
  end
  tbl[name] = (tbl[name] or 0) + count
  DB.items[name] = itemID
end

local function scanBags(c)
  wipe(c.bags)
  for bag = 0, 4 do
    local n = containerNumSlots(bag) or 0
    for slot = 1, n do
      local id, count = containerItem(bag, slot)
      addItem(c.bags, id, count)
    end
  end
  c.ts = time()
end

local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10 }
local function scanBank(c)
  wipe(c.bank)
  for _, bag in ipairs(BANK_BAGS) do
    local n = containerNumSlots(bag) or 0
    for slot = 1, n do
      local id, count = containerItem(bag, slot)
      addItem(c.bank, id, count)
    end
  end
end

local function scanPrices()
  if not (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID) then
    return false
  end
  local n = 0
  for name, itemID in pairs(DB.items) do
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, itemID)
    if ok and price and price > 0 then
      DB.prices[name] = price
      n = n + 1
    end
  end
  return true, n
end

-- ---------- JSON (minimal, strings/numbers/tables only) ----------
local function jsonStr(s)
  s = tostring(s):gsub('[%c"\\]', function(ch)
    if ch == '"' then return '\\"' elseif ch == '\\' then return '\\\\' end
    return string.format('\\u%04x', ch:byte())
  end)
  return '"' .. s .. '"'
end

local function toJSON(v)
  local t = type(v)
  if t == "number" then return tostring(v)
  elseif t == "string" then return jsonStr(v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif t == "table" then
    local parts = {}
    local isArray = #v > 0
    if isArray then
      for _, x in ipairs(v) do parts[#parts + 1] = toJSON(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = jsonStr(k) .. ":" .. toJSON(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local function exportString()
  return toJSON({ v = 1, ts = time(), chars = DB.chars, prices = DB.prices })
end

-- ---------- export UI ----------
local box
local function showExport()
  if not box then
    box = CreateFrame("Frame", "ForeverWorkshopExport", UIParent, "BackdropTemplate")
    box:SetSize(520, 320)
    box:SetPoint("CENTER")
    box:SetFrameStrata("DIALOG")
    box:SetMovable(true); box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)
    if box.SetBackdrop then
      box:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
      box:SetBackdropColor(0, 0, 0, 0.9)
    end
    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Forever Workshop export — Ctrl+A, Ctrl+C, then paste into the planner")
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(460)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(edit)
    box.edit = edit
    local close = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    close:SetSize(80, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 10)
    close:SetText("Close")
    close:SetScript("OnClick", function() box:Hide() end)
    box.status = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.status:SetPoint("BOTTOMLEFT", 12, 14)
  end
  local s = exportString()
  box.edit:SetText(s)
  box.edit:HighlightText()
  box.edit:SetFocus()
  local nChars = 0
  for _ in pairs(DB.chars) do nChars = nChars + 1 end
  local nPrices = 0
  for _ in pairs(DB.prices) do nPrices = nPrices + 1 end
  box.status:SetText(string.format("%d characters, %d prices, %d bytes", nChars, nPrices, #s))
  box:Show()
end

-- ---------- events & slash ----------
local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cffd9a648Forever Workshop:|r " .. s) end

local pending = false
local function rescan()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = false
    local c = initDB()
    scanSkills(c)
    scanBags(c)
  end)
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    local c = initDB()
    scanSkills(c)
    scanBags(c)
    msg("loaded. /fw export to copy a snapshot for the planner.")
  elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
    local c = initDB()
    scanBank(c)
  else
    rescan()
  end
end)

SLASH_FOREVERWORKSHOP1 = "/fw"
SlashCmdList.FOREVERWORKSHOP = function(arg)
  arg = (arg or ""):lower():match("^%s*(%S*)")
  local c = initDB()
  if arg == "export" or arg == "" then
    scanSkills(c); scanBags(c); scanPrices()
    showExport()
  elseif arg == "scan" then
    scanSkills(c); scanBags(c)
    local n = 0; for _ in pairs(c.bags) do n = n + 1 end
    msg(string.format("scanned %d item types in bags, %d skills.", n, (function() local k = 0; for _ in pairs(c.skills) do k = k + 1 end; return k end)()))
  elseif arg == "prices" then
    local ok, n = scanPrices()
    if ok then msg(string.format("refreshed %d prices from Auctionator.", n or 0))
    else msg("Auctionator API not found. Is Auctionator loaded?") end
  else
    msg("commands: /fw export · /fw scan · /fw prices")
  end
end
