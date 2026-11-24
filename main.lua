local KEEP = {
  HP = true, PP = true, TM = true, HM = true, SP = true, XS = true, XL = true,
  PC = true, ID = true, TV = true, OK = true, GBA = true, GB = true, HQ = true,
  DJ = true, CD = true, DNA = true, UFO = true, VS = true, SOS = true,
  EV = true, IV = true, EXP = true, XP = true, NPC = true, AI = true,
  PKMN = true, PK = true, MN = true, SS = true,
}

local OMNI_KEEP = {
  PSN = true, TOX = true, PAR = true, PRZ = true, BRN = true,
  SLP = true, FRZ = true, FNT = true, PKRS = true,
  OT = true, PWR = true, ACC = true, ATK = true, DEF = true,
  SPA = true, SPD = true, SPE = true, HT = true, WT = true,
  KO = true, OHKO = true, AB = true, GH = true,
  UI = true, API = true, HUD = true, SYS = true,
  SFX = true, BGM = true, FPS = true, RTC = true, GBC = true, SGB = true,
}

local EXACT = {
  ["MR. MIME"] = "Mr. Mime",
  ["MR.MIME"] = "Mr. Mime",
  ["HO-OH"] = "Ho-Oh",
  ["FARFETCH'D"] = "Farfetch'd",
  ["POKé BALL"] = "Poké Ball",
  ["POKé DOLL"] = "Poké Doll",
  ["POKé FLUTE"] = "Poké Flute",
  ["POKéMON"] = "Pokémon",
  ["POKéNAV"] = "PokéNav",
  ["POKéGEAR"] = "PokéGear",
}

local WORD_EXACT = {
  ["POKéNAV"] = "PokéNav",
  ["POKéGEAR"] = "PokéGear",
}

local E_ACUTE = "é"
local E_ACUTE_UPPER = "É"
local MARK_OPEN, MARK_CLOSE = string.char(1), string.char(2)
local MARK_OPEN_BYTE, MARK_CLOSE_BYTE = 1, 2

local function hasLowerAscii(s)
  return s:find("[a-z]") ~= nil
end

local function countUpperAscii(s)
  local _, n = s:gsub("[A-Z]", "")
  return n
end

local function needsDecap(s, hasAliases)
  if type(s) ~= "string" or s == "" then return false end
  if hasAliases then
    return s:find("[A-Z]") ~= nil or s:find(E_ACUTE_UPPER, 1, true) ~= nil
  end
  return s:find("[A-Z][A-Z]") ~= nil
      or s:find("'[A-Z]") ~= nil
      or s:find(E_ACUTE_UPPER, 1, true) ~= nil
      or s:find("[A-Z]\195\169") ~= nil
end

local function capFirst(word)
  if word:sub(1, 2) == E_ACUTE then
    return E_ACUTE .. word:sub(3):lower()
  end
  return word:sub(1, 1):upper() .. word:sub(2):lower()
end

local function isWordByte(b)
  return (b >= 48 and b <= 57)
      or (b >= 65 and b <= 90)
      or (b >= 97 and b <= 122)
      or b == 39
end

local function mapWords(s, fn)
  local n = #s
  local out = {}
  local pos = 1
  local changed = false
  while pos <= n do
    local gapStart = pos
    while pos <= n do
      local b = s:byte(pos)
      if b == MARK_OPEN_BYTE then
        local closePos = s:find(MARK_CLOSE, pos + 1, true)
        pos = closePos and (closePos + 1) or (n + 1)
      elseif isWordByte(b) then
        break
      elseif b == 195 and s:byte(pos + 1) == 169 then
        break
      else
        pos = pos + 1
      end
    end
    if pos > gapStart then
      out[#out + 1] = s:sub(gapStart, pos - 1)
    end
    if pos > n then break end
    local we = pos
    while we <= n do
      local b = s:byte(we)
      if isWordByte(b) then
        we = we + 1
      elseif b == 195 and s:byte(we + 1) == 169 then
        we = we + 2
      else
        break
      end
    end
    local word = s:sub(pos, we - 1)
    local repl = fn(word)
    if repl and repl ~= word then
      out[#out + 1] = repl
      changed = true
    else
      out[#out + 1] = word
    end
    pos = we
  end
  if not changed then return s end
  return table.concat(out)
end

local function isKeep(token, extraKeep)
  return KEEP[token] == true or (extraKeep ~= nil and extraKeep[token] == true)
end

local function normalizeWord(word, extraKeep)
  if word:find("%d") then
    if word:find("[a-z]") then return nil end
    if word:match("^[TH]M%d+$") then return nil end
    local stem, digits = word:match("^(.-)(%d+)$")
    if stem and #stem >= 2 and not stem:find("%d") and countUpperAscii(stem) >= 2 then
      if isKeep(stem, extraKeep) then return nil end
      local exactStem = WORD_EXACT[stem]
      if exactStem then return exactStem .. digits end
      return capFirst(stem) .. digits
    end
    return nil
  end

  local head, tail = word:match("^([^a-z']+)('[a-z]+)$")
  if not head then
    head, tail = word:match("^([^a-z']+)(s)$")
  end
  if head and countUpperAscii(head) >= 2 then
    local exactHead = WORD_EXACT[head]
    if exactHead then return exactHead .. tail end
    if isKeep(head, extraKeep) then return nil end
    return capFirst(head) .. tail
  end

  if hasLowerAscii(word) then return nil end
  if not word:find("[A-Z]") then return nil end

  if isKeep(word, extraKeep) then return nil end
  local exactWord = WORD_EXACT[word]
  if exactWord then return exactWord end

  if word:match("^'[A-Z]+$") then
    return "'" .. word:sub(2):lower()
  end

  local basePoss = word:match("^(.-)'S$")
  if basePoss and #basePoss >= 2 then
    local exactBase = WORD_EXACT[basePoss]
    if exactBase then return exactBase .. "'s" end
    if isKeep(basePoss, extraKeep) then return basePoss .. "'s" end
    if countUpperAscii(basePoss) >= 2 then
      return capFirst(basePoss) .. "'s"
    end
  end

  local basePlural = word:match("^(.+)S$")
  if basePlural and #basePlural >= 2 then
    local exactBase = WORD_EXACT[basePlural]
    if exactBase then return exactBase .. "s" end
    if isKeep(basePlural, extraKeep) then return basePlural .. "s" end
  end

  return capFirst(word)
end

local function titlecase(name)
  if type(name) ~= "string" or name == "" then return nil end
  local source = name:find(E_ACUTE_UPPER, 1, true) and name:gsub(E_ACUTE_UPPER, E_ACUTE) or name
  if hasLowerAscii(source) then return nil end
  if source:find("[{<%%]") then return nil end
  local exact = EXACT[source]
  if exact then
    return exact ~= name and exact or nil
  end
  local result = mapWords(source, normalizeWord)
  if result == name then return nil end
  return result
end

local function isInsideMark(s, idx)
  local openPos = s:sub(1, idx - 1):match(".*" .. MARK_OPEN .. "()")
  if not openPos then return false end
  return s:sub(openPos, idx - 1):find(MARK_CLOSE, 1, true) == nil
end

local function maskName(s, name, store, aliases)
  if not s:find(name, 1, true) then return s end
  local out, pos = {}, 1
  while true do
    local a, b = s:find(name, pos, true)
    if not a then break end
    if isInsideMark(s, a) then
      local closePos = s:find(MARK_CLOSE, a, true)
      local skipTo = closePos or b
      out[#out + 1] = s:sub(pos, skipTo)
      pos = skipTo + 1
    else
      local before = a > 1 and s:sub(a - 1, a - 1) or ""
      local after = b < #s and s:sub(b + 1, b + 1) or ""
      local prevIsE = a > 2 and s:sub(a - 2, a - 1) == E_ACUTE
      local nextIsE = b + 2 <= #s and s:sub(b + 1, b + 2) == E_ACUTE
      if before:find("^%w$") or after:find("^%w$") or prevIsE or nextIsE then
        out[#out + 1] = s:sub(pos, b)
      else
        out[#out + 1] = s:sub(pos, a - 1)
        store[#store + 1] = (aliases and aliases[name]) or name
        out[#out + 1] = MARK_OPEN .. #store .. MARK_CLOSE
      end
      pos = b + 1
    end
  end
  out[#out + 1] = s:sub(pos)
  return table.concat(out)
end

local function hasAnyKey(t)
  return type(t) == "table" and next(t) ~= nil
end

local function decapText(s, protected, aliases, extraKeep)
  if not needsDecap(s, hasAnyKey(aliases)) then return nil end
  local source, store = s, {}
  if source:find(E_ACUTE_UPPER, 1, true) then
    source = source:gsub(E_ACUTE_UPPER, E_ACUTE)
  end
  if source:find("[{}]") then
    source = source:gsub("{[^{}]*}", function(token)
      store[#store + 1] = token
      return MARK_OPEN .. #store .. MARK_CLOSE
    end)
    if source:find("[{}]") then return nil end
  end
  if protected then
    for _, name in ipairs(protected) do
      source = maskName(source, name, store, aliases)
    end
  end
  local exact = EXACT[source]
  if exact then
    return exact ~= s and exact or nil
  end
  local result = mapWords(source, extraKeep and function(word)
    return normalizeWord(word, extraKeep)
  end or normalizeWord)
  if #store > 0 then
    result = result:gsub(MARK_OPEN .. "(%d+)" .. MARK_CLOSE, function(i)
      return store[tonumber(i)]
    end)
  end
  if result == s then return nil end
  return result
end

local function decapString(value, extraKeep)
  if type(value) ~= "string" then return value end
  return decapText(value, nil, nil, extraKeep) or value
end

local function collapseDuplicatePokemon(s)
  if not s:find("POK", 1, true) then return s end
  local work = s:find(E_ACUTE_UPPER, 1, true) and s:gsub(E_ACUTE_UPPER, E_ACUTE) or s
  work = work:gsub("POK" .. E_ACUTE .. "MON%s+POK" .. E_ACUTE .. "MON", "POK" .. E_ACUTE .. "MON")
  work = work:gsub("POKEMON%s+POK" .. E_ACUTE .. "MON", "POK" .. E_ACUTE .. "MON")
  work = work:gsub("POK" .. E_ACUTE .. "MON%s+PKMN", "PKMN")
  work = work:gsub("POKEMON%s+PKMN", "PKMN")
  return work
end

local function decapDexFields(entry)
  if type(entry) ~= "table" then return end
  for _, key in ipairs({ "category", "categoryName", "description", "description2" }) do
    if type(entry[key]) == "string" then
      entry[key] = decapString(entry[key])
    end
  end
end

return function(mod)
  local SHOW_SUMMARY = true
  local DIALOGUE = true

  local FIELDS = {
    { "pokemon", { "name" } },
    { "moves", { "name" } },
    { "abilities", { "name" } },
    { "items", { "name" } },
    { "trainers", { "name", "className" } },
  }
  local totals = {}

  for _, entry in ipairs(FIELDS) do
    local registry, fields = entry[1], entry[2]
    local handle = mod.content and mod.content[registry]
    if handle and mod:supports("content", registry) then
      local seen, changed, refused = 0, 0, 0
      local patches = {}
      local okEach, errEach = pcall(function()
        for id, record in handle:each() do
          seen = seen + 1
          if type(record) == "table" then
            local patch
            for _, field in ipairs(fields) do
              local new = titlecase(record[field])
              if new then
                patch = patch or {}
                patch[field] = new
              end
            end
            if patch then patches[#patches + 1] = { id = id, patch = patch } end
          end
        end
      end)
      if not okEach then
        mod.log:warn("decap_names: could not iterate %s: %s", registry, tostring(errEach))
      end
      for _, p in ipairs(patches) do
        local okPatch, res, reason = pcall(handle.patch, handle, p.id, p.patch)
        if okPatch and res ~= nil then
          changed = changed + 1
        else
          refused = refused + 1
          if refused <= 3 then
            mod.log:warn("decap_names: %s %s refused: %s", registry, tostring(p.id),
              tostring(okPatch and reason or res))
          end
        end
      end
      totals[registry] = { seen = seen, changed = changed, refused = refused }
    end
  end

  if SHOW_SUMMARY then
    local parts = {}
    for _, entry in ipairs(FIELDS) do
      local t = totals[entry[1]]
      if t and (t.changed > 0 or t.refused > 0) then
        parts[#parts + 1] = ("%s %d/%d"):format(entry[1], t.changed, t.seen)
        if t.refused > 0 then
          parts[#parts] = parts[#parts] .. (" (%d refused)"):format(t.refused)
        end
      end
    end
    if #parts > 0 then
      mod.log:info("decap_names: content names: %s", table.concat(parts, ", "))
    end
  end

  local dialogueText = DIALOGUE and "dialogue: not hooked" or "dialogue: off"

  local function findMod(id)
    if type(mod.find) ~= "function" then return nil end
    local ok, handle = pcall(mod.find, id)
    if ok and handle ~= nil then return handle end
    local okMethod, handleMethod = pcall(mod.find, mod, id)
    if okMethod and handleMethod ~= nil then return handleMethod end
    return nil
  end

  local function checkNameTagsSupport()
    if findMod("name_tags") then
      mod.log:info("decap_names: optional name_tags mod detected")
    end
  end

  local sharedItemNames = {}
  local labelDecap
  local getProtectedNames
  local originMark
  local isPresetName
  local getLivePlayerName
  local getLiveRivalName
  local resetPresetCache

  local function textPass()
    if not DIALOGUE then return end
    local okT, T = pcall(require, "src.core.game3.scripting.text_ir")
    if not (okT and type(T) == "table") then
      dialogueText = "dialogue: no engine access"
      return
    end

    local presetNames
    local presetFailed = false
    local buildingPreset = false

    resetPresetCache = function()
      presetNames = nil
      presetFailed = false
    end

    local function isPreset(name)
      if type(name) ~= "string" or name == "" then return false end
      if buildingPreset then return false end
      if not presetNames and not presetFailed then
        local okR, RomText = pcall(require, "src.core.game3.rom_text")
        if okR and type(RomText) == "table" and type(RomText.list) == "function" then
          local set, count = {}, 0
          buildingPreset = true
          local okBuild = pcall(function()
            for _, key in ipairs({ "sMaleNameChoices", "sFemaleNameChoices", "sRivalNameChoices" }) do
              local okL, list = pcall(RomText.list, key)
              if okL and type(list) == "table" then
                for _, entry in ipairs(list) do
                  local text = entry
                  if type(text) == "table" then
                    local okP, plain = pcall(T.toPlain, text, {})
                    text = okP and plain or nil
                  end
                  if type(text) == "string" and text ~= "" then
                    set[text:upper()] = true
                    count = count + 1
                  end
                end
              end
            end
          end)
          buildingPreset = false
          if not okBuild then
            presetFailed = true
            mod.log:warn("decap_names: could not read preset name lists; preset names will be treated as custom names")
          elseif count > 0 then
            presetNames = set
          else
            presetFailed = true
          end
        end
      end
      return presetNames ~= nil and presetNames[name:upper()] == true
    end
    isPresetName = isPreset

    local function rivalIsFixed(ctx)
      local okD, d = pcall(T.dialect, type(ctx) == "table" and ctx.dialect or nil)
      return okD and type(d) == "table" and d.GENDERED_PH ~= nil and d.GENDERED_PH.RIVAL == true
    end

    local function liveField(fieldName)
      if type(T._provider) ~= "function" then return nil end
      local okF, value = pcall(function() return T._provider(fieldName, T.dialect(nil), nil) end)
      if okF and type(value) == "string" and value ~= "" then return value end
      return nil
    end

    local function livePlayerName()
      return liveField("playerName")
    end

    local function liveRivalName()
      return liveField("rivalName")
    end

    getLivePlayerName = livePlayerName
    getLiveRivalName = liveRivalName

    local function protectedNames(ctx)
      if buildingPreset then return {}, "#preset", {} end
      local set = {}
      local function add(v)
        if type(v) == "string" and #v >= 2 and (v:find("[A-Z]") or v:find(E_ACUTE_UPPER, 1, true)) then
          set[v] = true
        end
      end
      local function field(name)
        local v = type(ctx) == "table" and ctx[name] or nil
        if v == nil and type(T._provider) == "function" then
          local okF, r = pcall(function()
            return T._provider(name, T.dialect(type(ctx) == "table" and ctx.dialect or nil), ctx)
          end)
          if okF then v = r end
        end
        return v
      end

      local aliases = {}
      local typed = livePlayerName()
      local carried = field("playerName")
      local reference = typed or carried
      if reference and not isPreset(reference) then
        add(reference)
        if typed and typed ~= typed:upper() then
          local upperTyped = typed:upper()
          add(upperTyped)
          aliases[upperTyped] = typed
        end
        if carried and carried ~= reference then
          if typed and carried:upper() == typed:upper() then
            add(carried)
            aliases[carried] = typed
          else
            add(carried)
          end
        end
      end
      if not rivalIsFixed(ctx) then
        local rivalValue = field("rivalName")
        if rivalValue and not isPreset(rivalValue) then
          add(rivalValue)
          if rivalValue ~= rivalValue:upper() then
            local upperRival = rivalValue:upper()
            add(upperRival)
            aliases[upperRival] = rivalValue
          end
        end
      end
      local list = {}
      for name in pairs(set) do list[#list + 1] = name end
      table.sort(list, function(x, y)
        if #x ~= #y then return #x > #y end
        return x < y
      end)
      local aliasKeys = {}
      for from, to in pairs(aliases) do aliasKeys[#aliasKeys + 1] = from .. ">" .. to end
      table.sort(aliasKeys)
      return list, table.concat(list, "|") .. "#" .. table.concat(aliasKeys, "|"), aliases
    end

    getProtectedNames = protectedNames
    labelDecap = function(label)
      if type(label) ~= "string" then return nil end
      local list, _, aliases = protectedNames(nil)
      return decapText(label, list, aliases)
    end

    rawset(T, "__decapLabel", labelDecap)
    rawset(T, "__decapProtected", protectedNames)
    rawset(T, "__decapIsPreset", isPreset)
    rawset(T, "__decapResetPreset", resetPresetCache)

    if rawget(T, "__decapText") then
      dialogueText = "dialogue: already hooked"
      return
    end

    local function fixPlural(value)
      if type(value) ~= "string" or value == "" then return nil end
      if value:match("[Bb]all%s*S$") then
        return (value:gsub("%s*S$", "s"))
      end
      if value:match("[Bb]err[iI][eE][sS]$") then
        local fixed = value:gsub("[iI][eE][sS]$", "ies")
        if fixed ~= value then return fixed end
        return nil
      end
      local itemMap = sharedItemNames
      if type(itemMap) == "table" then
        if #value >= 4 then
          local suffix = value:sub(-3)
          if suffix:upper() == "IES" and suffix ~= "ies" then
            local stem = value:sub(1, -4) .. "y"
            local canonical = itemMap[stem:upper()]
            if canonical and canonical:sub(-1):lower() == "y" then
              return canonical:sub(1, -2) .. "ies"
            end
          end
        end
        if value:sub(-1) == "S" and #value >= 2 then
          local stem = value:sub(1, -2)
          local canonical = itemMap[stem:upper()]
          if canonical then return canonical .. "s" end
        end
      end
      return nil
    end

    local originalToAscii = T.toAscii
    local originalExpandSeg = T.expandSeg

    local function expandSeg(seg, ctx)
      if type(originalExpandSeg) == "function" then
        local okE, value = pcall(originalExpandSeg, seg, ctx)
        if okE and type(value) == "string" then return value end
        return nil
      end
      if type(originalToAscii) == "function" then
        local okE, value = pcall(originalToAscii, { seg, { t = "eos" } }, ctx)
        if okE and type(value) == "string" then return value end
      end
      return nil
    end

    local runtimeIR = setmetatable({}, { __mode = "k" })
    local runtimeSeg = setmetatable({}, { __mode = "k" })
    local cache = setmetatable({}, { __mode = "k" })

    local function decapIR(ir, ctx)
      if type(ir) ~= "table" then return ir end
      if runtimeIR[ir] then return ir end
      local hit = cache[ir]
      if hit and hit.n == #ir and hit.plain then return ir end

      local candidate, dynamic = false, false
      for i = 1, #ir do
        local seg = ir[i]
        if type(seg) == "table" then
          if seg.t == "text" and type(seg.s) == "string"
              and (needsDecap(seg.s, false) or seg.s:find("[A-Z]")) then
            candidate = true
          elseif seg.t == "strvar" or seg.t == "rival" or seg.t == "player" then
            dynamic = true
          end
        end
      end
      if not candidate and not dynamic then
        cache[ir] = { n = #ir, plain = true }
        return ir
      end

      local list, sig, aliases = protectedNames(ctx)
      if not dynamic and hit and hit.n == #ir and hit.sig == sig then return hit.ir end
      local fixedRival = dynamic and rivalIsFixed(ctx)
      local out, changed = {}, false
      for i = 1, #ir do
        local seg = ir[i]
        out[i] = seg
        if type(seg) == "table" then
          local replacement
          if seg.t == "text" then
            local new = decapText(seg.s, list, aliases)
            if new then replacement = new end
          elseif seg.t == "strvar" then
            local value = expandSeg(seg, ctx)
            if value then replacement = fixPlural(value) end
          elseif seg.t == "player" then
            local value = expandSeg(seg, ctx)
            if value then
              local typed = livePlayerName()
              if isPreset(typed or value) then
                replacement = decapText(value, nil)
              elseif typed and value ~= typed and value:upper() == typed:upper() then
                replacement = typed
              end
            end
          elseif seg.t == "rival" then
            local value = expandSeg(seg, ctx)
            if value and (fixedRival or isPreset(value)) then
              replacement = decapText(value, nil)
            end
          end
          if replacement then
            local copy = {}
            for k, v in pairs(seg) do copy[k] = v end
            copy.t, copy.s = "text", replacement
            out[i] = copy
            changed = true
          end
        end
      end
      local result = changed and out or ir
      if not dynamic then cache[ir] = { n = #ir, sig = sig, ir = result } end
      return result
    end

    local inTopWrapper = 0
    local function callUnwrapped(fn, ...)
      inTopWrapper = inTopWrapper + 1
      local ok, a, b, c, d = pcall(fn, ...)
      inTopWrapper = inTopWrapper - 1
      if not ok then error(a, 0) end
      return a, b, c, d
    end

    local wrapped = 0
    for _, fname in ipairs({ "expandPage", "toTextBox", "toAscii" }) do
      local original = T[fname]
      if type(original) == "function" then
        if fname == "expandPage" then
          T[fname] = function(ir, startIdx, ctx)
            return callUnwrapped(original, decapIR(ir, ctx), startIdx, ctx)
          end
        else
          T[fname] = function(ir, ctx)
            return callUnwrapped(original, decapIR(ir, ctx), ctx)
          end
        end
        wrapped = wrapped + 1
      end
    end

    if type(originalExpandSeg) == "function" then
      T.expandSeg = function(seg, ctx)
        if inTopWrapper > 0 or runtimeSeg[seg] then
          return originalExpandSeg(seg, ctx)
        end
        local ir = decapIR({ seg }, ctx)
        return originalExpandSeg(ir[1], ctx)
      end
      wrapped = wrapped + 1
    end

    local originalFromAscii = T.fromAscii
    originMark = function()
      if rawget(T, "__decapOrigin") or type(originalFromAscii) ~= "function" then return end
      T.fromAscii = function(...)
        local ir = originalFromAscii(...)
        if type(ir) == "table" then
          runtimeIR[ir] = true
          for i = 1, #ir do
            local seg = ir[i]
            if type(seg) == "table" then runtimeSeg[seg] = true end
          end
        end
        return ir
      end
      rawset(T, "__decapOrigin", true)
    end

    local okPlain, RomText = pcall(require, "src.core.game3.rom_text")
    if okPlain and type(RomText) == "table" and type(RomText.plain) == "function"
        and not rawget(RomText, "__decapPlain") then
      local originalPlain = RomText.plain
      RomText.plain = function(key, ctx)
        local out = originalPlain(key, ctx)
        if type(out) ~= "string" then return out end
        if not needsDecap(out, false) and not out:find("[A-Z]") then return out end
        local list, _, aliases = protectedNames(ctx)
        local new = decapText(out, list, aliases)
        return new or out
      end
      rawset(RomText, "__decapPlain", true)
    end

    rawset(T, "__decapText", true)
    dialogueText = ("dialogue: %d functions hooked, origin mode"):format(wrapped)
  end

  local okText, errText = pcall(textPass)
  if not okText then
    dialogueText = "dialogue: hook error"
    mod.log:warn("decap_names: dialogue hooks failed: %s", tostring(errText))
  end

  local function loadModule(path)
    local ok, module = pcall(require, path)
    return ok and type(module) == "table" and module or nil
  end

  local namingMod, namingTried = nil, false
  local runtimeMod, runtimeTried = nil, false
  local partyMod, partyTried = nil, false
  local battleMod, battleTried = nil, false
  local pokemonMod, pokemonTried = nil, false

  local function isNamingOpen()
    if not namingTried then
      namingTried = true
      namingMod = loadModule("src.ui.game3.naming")
    end
    if not namingMod then return false end
    if namingMod.openFlag == true then return true end
    if type(namingMod.isOpen) == "function" then
      local okOpen, open = pcall(namingMod.isOpen)
      if okOpen and open == true then return true end
    end
    return false
  end

  local function collectCustomNicknames()
    if not pokemonTried then
      pokemonTried = true
      pokemonMod = loadModule("src.core.game3.pokemon")
    end
    if not runtimeTried then
      runtimeTried = true
      runtimeMod = loadModule("src.core.game3.runtime")
    end
    if not partyTried then
      partyTried = true
      partyMod = loadModule("src.ui.game3.party_menu")
    end
    if not battleTried then
      battleTried = true
      battleMod = loadModule("src.core.game3.battle")
    end

    local namesTable = pokemonMod and rawget(pokemonMod, "_names")
    local nicks, seen = nil, nil
    local function considerMon(mon)
      if type(mon) ~= "table" then return end
      if mon.isEgg == true or (pokemonMod and type(pokemonMod.isEgg) == "function" and pokemonMod.isEgg(mon)) then
        return
      end
      local nick = mon.nickname
      if type(nick) ~= "string" or #nick < 2 then return end
      local sp = mon.species or mon.speciesId
      if not sp and pokemonMod and type(pokemonMod.speciesOf) == "function" then
        local okS, res = pcall(pokemonMod.speciesOf, mon)
        if okS then sp = res end
      end
      local speciesName = sp and type(namesTable) == "table" and namesTable[sp]
      if type(speciesName) == "string" and speciesName:upper() == nick:upper() then
        return
      end
      if nick:upper() == "EGG" then return end
      if not seen then
        nicks, seen = {}, {}
      end
      if not seen[nick] then
        seen[nick] = true
        nicks[#nicks + 1] = nick
      end
    end

    local function considerParty(party)
      if type(party) ~= "table" then return end
      for i = 1, #party do
        considerMon(party[i])
      end
    end

    if runtimeMod then
      local session = runtimeMod.session
      if not session and type(runtimeMod.getSession) == "function" then
        local okS, s = pcall(runtimeMod.getSession)
        if okS and type(s) == "table" then session = s end
      end
      if type(session) == "table" then considerParty(session.party) end
    end
    if partyMod then
      considerParty(partyMod._party)
      if type(partyMod._session) == "table" then considerParty(partyMod._session.party) end
    end
    if battleMod and type(battleMod.getState) == "function" then
      local okB, st = pcall(battleMod.getState)
      if okB and type(st) == "table" then
        considerParty(st.playerParty)
        if type(st.player) == "table" then considerMon(st.player.mon or st.player.pokemon) end
        if type(st.enemy) == "table" then considerMon(st.enemy.mon or st.enemy.pokemon) end
        if type(st.battlers) == "table" then
          for _, b in pairs(st.battlers) do
            if type(b) == "table" then considerMon(b.mon or b.pokemon) end
          end
        end
      end
    end
    return nicks
  end

  local NAME_FIELDS = { "name", "className", "displayName", "title" }

  local function upperKey(s)
    local key = s:upper()
    if key:find(E_ACUTE_UPPER, 1, true) then key = key:gsub(E_ACUTE_UPPER, E_ACUTE) end
    return key
  end

  local function learnName(dict, value)
    if type(value) ~= "string" or #value < 3 or not value:find("[A-Za-z]") then return end
    if value:find("[{}<>%%\n]") then return end
    local key = upperKey(value)
    if dict[key] then return end
    local proper = hasLowerAscii(value) and value or titlecase(value)
    if proper and proper ~= key then dict[key] = proper end
  end

  local function learnRegistries(dict)
    local content = mod.content
    if type(content) ~= "table" then return end
    local okP, iter, state, init = pcall(pairs, content)
    if not okP then return end
    for _, handle in iter, state, init do
      if type(handle) == "table" and type(handle.each) == "function" then
        pcall(function()
          for _, record in handle:each() do
            if type(record) == "table" then
              for _, field in ipairs(NAME_FIELDS) do learnName(dict, record[field]) end
            end
          end
        end)
      end
    end
  end

  local function learnPlaces(dict)
    local MS = loadModule("src.import.gba.map_sections_extract")
    if MS then
      pcall(MS.ensureGenerated)
      if type(MS.SECTIONS) == "table" then
        for _, sec in pairs(MS.SECTIONS) do
          if type(sec) == "table" then learnName(dict, sec.name) end
        end
      end
    end
    local Mapsec = loadModule("src.ui.game3.rse.mapsec")
    if Mapsec and type(Mapsec.count) == "function" and type(Mapsec.name) == "function" then
      pcall(function()
        for sec = 0, (Mapsec.count() or 0) - 1 do
          local okN, name = pcall(Mapsec.name, sec)
          if okN then learnName(dict, name) end
        end
      end)
    end
  end

  local function isCapsWord(w)
    return not w:find("[a-z]") and (w:find("[A-Z]") ~= nil or w:find(E_ACUTE_UPPER, 1, true) ~= nil)
  end

  local function isNameByte(s, i)
    local b = s:byte(i)
    if not b then return 0 end
    if isWordByte(b) then return 1 end
    if b == 195 then
      local c = s:byte(i + 1)
      if c == 169 or c == 137 then return 2 end
    end
    return 0
  end

  local function scanWords(s)
    local words, n, pos = {}, #s, 1
    while pos <= n do
      local b = s:byte(pos)
      if b == MARK_OPEN_BYTE then
        local c = s:find(MARK_CLOSE, pos + 1, true)
        pos = c and (c + 1) or (n + 1)
      elseif isNameByte(s, pos) > 0 then
        local we = pos
        while we <= n do
          local step = isNameByte(s, we)
          if step == 0 then break end
          we = we + step
        end
        words[#words + 1] = { a = pos, b = we - 1, caps = isCapsWord(s:sub(pos, we - 1)) }
        pos = we
      else
        pos = pos + 1
      end
    end
    return words
  end

  local JOINS = { [" "] = true, ["."] = true, [". "] = true, ["-"] = true }

  local function dictReplace(s, dict, protect)
    local store = {}
    local work = s
    if work:find("[{}]") then
      work = work:gsub("{[^{}]*}", function(token)
        store[#store + 1] = token
        return MARK_OPEN .. #store .. MARK_CLOSE
      end)
    end
    local function lookup(text)
      local key = upperKey(text)
      if protect[key] then return nil end
      return dict[key]
    end
    local words = scanWords(work)
    local out, last, changed, i = {}, 1, false, 1
    while i <= #words do
      if not words[i].caps then
        i = i + 1
      else
        local runEnd = i
        while runEnd < #words and words[runEnd + 1].caps
            and JOINS[work:sub(words[runEnd].b + 1, words[runEnd + 1].a - 1)] do
          runEnd = runEnd + 1
        end
        local tiles, p = {}, i
        while p <= runEnd do
          local hit
          for j = math.min(runEnd, p + 4), p, -1 do
            local text = work:sub(words[p].a, words[j].b)
            local rep = lookup(text)
            if not rep and text:sub(-2) == "'S" and #text > 3 then
              rep = lookup(text:sub(1, -3))
              if rep then rep = rep .. "'s" end
            end
            if rep then
              hit = { p = p, j = j, text = rep }
              break
            end
          end
          if not hit then
            local word = work:sub(words[p].a, words[p].b)
            if isKeep(word) then
              hit = { p = p, j = p, text = word }
            else
              tiles = nil
              break
            end
          end
          tiles[#tiles + 1] = hit
          p = hit.j + 1
        end
        if tiles then
          for _, t in ipairs(tiles) do
            out[#out + 1] = work:sub(last, words[t.p].a - 1)
            out[#out + 1] = t.text
            last = words[t.j].b + 1
          end
          changed = true
        end
        i = runEnd + 1
      end
    end
    if not changed then return s end
    out[#out + 1] = work:sub(last)
    local result = table.concat(out)
    if #store > 0 then
      result = result:gsub(MARK_OPEN .. "(%d+)" .. MARK_CLOSE, function(k) return store[tonumber(k)] end)
    end
    return result
  end

  local fontDict = {}
  local fontCache, fontCacheSize, fontProtect, fontProtectSig, fontProtectAt = {}, 0, {}, nil, -1

  local function clock()
    local okC, t = pcall(os.clock)
    return okC and t or 0
  end

  local function refreshFontProtect()
    local now = clock()
    if fontProtectSig and now - fontProtectAt < 0.25 then return end
    fontProtectAt = now
    local set, keys = {}, {}
    local function add(name)
      if type(name) == "string" and name ~= "" then
        local key = upperKey(name)
        if not set[key] then
          set[key] = true
          keys[#keys + 1] = key
        end
      end
    end
    for _, getter in ipairs({ getLivePlayerName, getLiveRivalName }) do
      if type(getter) == "function" then
        local okG, name = pcall(getter)
        if okG and not (type(isPresetName) == "function" and isPresetName(name)) then add(name) end
      end
    end
    local okN, nicks = pcall(collectCustomNicknames)
    if okN and nicks then
      for _, nick in ipairs(nicks) do add(nick) end
    end
    table.sort(keys)
    local sig = table.concat(keys, "\31")
    if sig ~= fontProtectSig then
      fontProtectSig, fontProtect = sig, set
      fontCache, fontCacheSize = {}, 0
    end
  end

  local engineText, engineTextSize = {}, 0

  local function rememberEngineText(out, alt)
    if out == alt then return end
    if engineTextSize >= 2048 then engineText, engineTextSize = {}, 0 end
    if engineText[out] == nil then engineTextSize = engineTextSize + 1 end
    engineText[out] = alt
  end

  local function engineStringsPass()
    local S = loadModule("src.core.Strings")
    if not S or type(S.get) ~= "function" or type(S.lookup) ~= "function" or rawget(S, "__decapStrings") then return end
    local originalGet = S.get
    S.get = function(source, ...)
      local out = originalGet(source, ...)
      if type(out) == "string" and type(source) == "string" and needsDecap(source, false) then
        local args = { n = select("#", ...), ... }
        local unpackArgs = table.unpack or unpack
        pcall(function()
          local argc = args.n
          local english, template = source, decapText(source)
          if not template then return end
          local alt = template
          if argc > 0 and source:find("%%[^%%]") then
            local okE, e = pcall(string.format, source, unpackArgs(args, 1, argc))
            local okF, f = pcall(string.format, template, unpackArgs(args, 1, argc))
            if not (okE and okF) then return end
            english, alt = e, f
          end
          if out ~= english then return end
          rememberEngineText(out, alt)
        end)
      end
      return out
    end
    rawset(S, "__decapStrings", true)
  end

  local function fontText(text)
    if type(text) ~= "string" or text == "" then return text end
    if not (text:find("[A-Z][A-Z]") or text:find(E_ACUTE_UPPER, 1, true) or text:find("[A-Z]\195\169")) then
      return text
    end
    if isNamingOpen() then return text end
    local engine = engineText[text]
    if engine then return engine end
    refreshFontProtect()
    local hit = fontCache[text]
    if hit then return hit end
    local okR, out = pcall(dictReplace, text, fontDict, fontProtect)
    if not okR then out = text end
    if fontCacheSize >= 1024 then fontCache, fontCacheSize = {}, 0 end
    fontCache[text] = out
    fontCacheSize = fontCacheSize + 1
    return out
  end

  local function rebuildFontDict(defaultNames)
    local dict = {}
    for key, value in pairs(defaultNames) do dict[upperKey(key)] = value end
    pcall(learnRegistries, dict)
    pcall(learnPlaces, dict)
    for key, value in pairs(dict) do
      if defaultNames[key] == nil then defaultNames[key] = value end
    end
    fontDict = dict
    fontCache, fontCacheSize, fontProtectSig = {}, 0, nil
  end

  local function decapRows(rows)
    if type(rows) ~= "table" then return rows end
    local list, _, aliases
    for _, entry in ipairs(rows) do
      if type(entry) == "table" and type(entry.label) == "string" and needsDecap(entry.label, false) then
        if not list and getProtectedNames then
          list, _, aliases = getProtectedNames(nil)
        end
        local new = decapText(entry.label, list, aliases)
        if new then entry.label = new end
      end
    end
    return rows
  end

  local function canHook(name)
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then return false end
    local ok, supported = pcall(mod.supports, mod, "hooks", name)
    return ok and supported == true
  end

  local function installHook(name, callback, priority)
    local ok = pcall(mod.hooks.wrap, mod.hooks, name, callback, priority)
    return ok
  end

  local menuHooked = false
  local function menuPass()
    if not DIALOGUE or menuHooked or not labelDecap then return end
    local hooked = false
    if canHook("ui.start_menu.items") then
      local ok = installHook("ui.start_menu.items", function(nextFn, game, items)
        local rows = nextFn(game, items)
        return decapRows(rows)
      end, 1000000)
      if ok then hooked = true end
    end
    local SM = loadModule("src.ui.game3.start_menu")
    if SM and type(SM.draw) == "function" then
      if not rawget(SM, "__decapDraw") then
        local original = SM.draw
        local function normalize()
          local entries = SM.ENTRIES
          if type(entries) ~= "table" then return end
          local list, _, aliases
          for _, entry in ipairs(entries) do
            if type(entry) == "table" and type(entry.label) == "string"
                and (needsDecap(entry.label, false) or (entry.label:find("[A-Z]") and not hasLowerAscii(entry.label))) then
              if not list then
                local okT, T = pcall(require, "src.core.game3.scripting.text_ir")
                local protFn = (okT and type(T) == "table" and rawget(T, "__decapProtected")) or getProtectedNames
                if type(protFn) == "function" then
                  list, _, aliases = protFn(nil)
                else
                  list, aliases = {}, {}
                end
              end
              local new = decapText(entry.label, list, aliases)
              if new then entry.label = new end
            end
          end
        end
        SM.draw = function(...)
          pcall(normalize)
          local result = original(...)
          pcall(normalize)
          return result
        end
        rawset(SM, "__decapDraw", true)
      end
      hooked = true
    end
    if not hooked then return end
    menuHooked = true
    mod.log:info("decap_names: pause menu labels hooked")
  end

  local partyHooked = false
  local function partyMenuPass()
    if not DIALOGUE or partyHooked or not labelDecap then return end
    local hooked = false
    if canHook("ui.party.submenu") then
      local ok = installHook("ui.party.submenu", function(nextFn, ...)
        local rows = nextFn(...)
        return decapRows(rows)
      end, 1000000)
      if ok then hooked = true end
    end
    local PM = loadModule("src.ui.game3.party_menu")
    if PM and type(PM.draw) == "function" and type(PM._actionTextsFor) == "function" then
      if not rawget(PM, "__decapDraw") then
        local original = PM.draw
        local function normalize(listItems)
          if type(listItems) ~= "table" then return end
          local texts = PM._actionTextsFor(listItems)
          if type(texts) ~= "table" then return end
          local list, _, aliases
          for i, text in ipairs(texts) do
            if type(text) == "string" and needsDecap(text, false) then
              if not list then
                local okT, T = pcall(require, "src.core.game3.scripting.text_ir")
                local protFn = (okT and type(T) == "table" and rawget(T, "__decapProtected")) or getProtectedNames
                if type(protFn) == "function" then
                  list, _, aliases = protFn(nil)
                else
                  list, aliases = {}, {}
                end
              end
              local new = decapText(text, list, aliases)
              if new then texts[i] = new end
            end
          end
        end
        local function normalizeCurrent()
          local mode = PM.mode
          if mode == "item_action" then
            normalize(PM.ITEM_ACTIONS)
          elseif mode == "action" or mode == "choose_multi" then
            normalize(PM.ACTIONS)
          end
        end
        PM.draw = function(...)
          pcall(normalizeCurrent)
          local result = original(...)
          pcall(normalizeCurrent)
          return result
        end
        rawset(PM, "__decapDraw", true)
      end
      hooked = true
    end
    if not hooked then return end
    partyHooked = true
    mod.log:info("decap_names: party menu labels hooked")
  end

  local displayText = "display pass: not run"

  local function rewriteNames(t)
    if type(t) ~= "table" then return 0 end
    local count = 0
    for key, value in pairs(t) do
      local new = titlecase(value)
      if new then
        t[key] = new
        count = count + 1
      end
    end
    return count
  end

  local function sharedTable(P, key)
    local map = rawget(P, key)
    if type(map) ~= "table" then
      map = {}
      rawset(P, key, map)
    end
    return map
  end

  local function clearTable(t)
    for key in pairs(t) do t[key] = nil end
  end

  local function displayPass()
    local okP, P = pcall(require, "src.core.game3.pokemon")
    if not (okP and type(P) == "table") then
      displayText = "display pass: no engine access"
      return nil
    end

    if type(resetPresetCache) == "function" then resetPresetCache() end
    local okT, T = pcall(require, "src.core.game3.scripting.text_ir")
    if okT and type(T) == "table" then
      local sharedReset = rawget(T, "__decapResetPreset")
      if type(sharedReset) == "function" and sharedReset ~= resetPresetCache then
        sharedReset()
      end
    end

    local defaultNames = sharedTable(P, "__decapDefaultNames")
    clearTable(defaultNames)
    local itemNames = sharedTable(P, "__decapItemNames")
    clearTable(itemNames)
    sharedItemNames = itemNames

    if type(isPresetName) == "function" then rawset(P, "__decapIsPreset", isPresetName) end
    if type(getLivePlayerName) == "function" then rawset(P, "__decapLivePlayer", getLivePlayerName) end
    if type(getLiveRivalName) == "function" then rawset(P, "__decapLiveRival", getLiveRivalName) end

    if rawget(P, "_names") == nil then pcall(P.name, 1) end
    local species = rewriteNames(rawget(P, "_names"))
    local moves = rewriteNames(rawget(P, "_moveNames"))
    local abilities = rewriteNames(rawget(P, "_abilityNames"))

    local rawDex = rawget(P, "_dex")
    if type(rawDex) == "table" then
      for _, entry in pairs(rawDex) do
        decapDexFields(entry)
      end
    end

    if type(P.dexEntry) == "function" and not rawget(P, "__decapDexEntry") then
      local original = P.dexEntry
      P.dexEntry = function(...)
        local entry = original(...)
        decapDexFields(entry)
        return entry
      end
      rawset(P, "__decapDexEntry", true)
    end

    if type(P.moveName) == "function" and not rawget(P, "__decapMoveName") then
      local original = P.moveName
      P.moveName = function(...)
        local result = original(...)
        if type(result) == "string" then
          local new = titlecase(result)
          if new then return new end
        end
        return result
      end
      rawset(P, "__decapMoveName", true)
    end

    if not rawget(P, "__decapMonNames") then
      local function monWrap(original)
        return function(mon, ...)
          local result = original(mon, ...)
          if type(result) ~= "string" then return result end
          if type(mon) == "table" then
            if type(P.isEgg) == "function" and P.isEgg(mon) then
              return titlecase(result) or result
            end
            local nick = mon.nickname
            if type(nick) == "string" and nick ~= "" then
              local okS, sp = pcall(P.speciesOf, mon)
              local names = rawget(P, "_names")
              local speciesName = okS and sp and type(names) == "table" and names[sp]
              if type(speciesName) == "string" and speciesName:upper() == nick:upper() then
                return speciesName
              end
              return result
            end
          end
          return titlecase(result) or result
        end
      end
      for _, fname in ipairs({ "displayName", "displayMonName" }) do
        if type(P[fname]) == "function" then P[fname] = monWrap(P[fname]) end
      end
      rawset(P, "__decapMonNames", true)
    end

    local speciesNames = rawget(P, "_names")
    if type(speciesNames) == "table" then
      for _, value in pairs(speciesNames) do
        if type(value) == "string" and hasLowerAscii(value) then
          defaultNames[value:upper()] = value
        end
      end
    end
    for _, names in ipairs({ rawget(P, "_moveNames") or {}, rawget(P, "_abilityNames") or {} }) do
      for _, value in pairs(names) do
        if type(value) == "string" and hasLowerAscii(value) then
          defaultNames[value:upper()] = value
        end
      end
    end

    local okF, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
    if okF and type(FrlgFont) == "table" and type(FrlgFont.draw) == "function"
        and not rawget(FrlgFont, "__decapFont") then
      local originalDraw = FrlgFont.draw
      FrlgFont.draw = function(text, ...)
        return originalDraw(fontText(text), ...)
      end
      if type(FrlgFont.measure) == "function" then
        local originalMeasure = FrlgFont.measure
        FrlgFont.measure = function(text, ...)
          return originalMeasure(fontText(text), ...)
        end
      end
      rawset(FrlgFont, "__decapFont", true)
    end

    local battleState = sharedTable(P, "__decapBattleState")
    battleState.isRse = false
    battleState.trainerCodes = { [0x1C] = true, [0x1D] = true }
    battleState.playerCodes = { [0x23] = true }
    local okProf, Profile = pcall(require, "src.core.game3.battle.profile")
    if okProf and type(Profile) == "table" and type(Profile.get) == "function" then
      local okC, cfg = pcall(Profile.get)
      if okC and type(cfg) == "table" and cfg.family == "rse" then
        battleState.isRse = true
        battleState.trainerCodes[0x2E] = true
        battleState.trainerCodes[0x2F] = true
        battleState.trainerCodes[0x32] = true
        battleState.trainerCodes[0x33] = true
      end
    end

    local okBattle, BattleText = pcall(require, "src.core.game3.battle.battle_text")
    if okBattle and type(BattleText) == "table" and type(BattleText.context) == "function"
        and not rawget(BattleText, "__decapBattle") then
      local originalContext = BattleText.context
      local function decapBattleName(value)
        local direct = defaultNames[value]
        if direct then return direct end
        local from = 1
        while true do
          local space = value:find(" ", from, true)
          if not space then return nil end
          local replacement = defaultNames[value:sub(space + 1)]
          if replacement then
            local prefix = value:sub(1, space)
            local decappedPrefix = titlecase(prefix) or prefix
            return decappedPrefix .. replacement
          end
          from = space + 1
        end
      end
      BattleText.context = function(...)
        local ctx = originalContext(...)
        local values = type(ctx) == "table" and ctx.battle or nil
        local meta = type(values) == "table" and getmetatable(values) or nil
        if meta and type(meta.__index) == "function" and not meta.__decapWrapped then
          local inner = meta.__index
          meta.__index = function(t, code)
            local value = inner(t, code)
            if type(value) == "string" then
              local new
              if battleState.playerCodes[code] then
                local presetCheck = rawget(P, "__decapIsPreset") or isPresetName
                local livePlayer = rawget(P, "__decapLivePlayer") or getLivePlayerName
                local typed = type(livePlayer) == "function" and livePlayer() or nil
                if type(presetCheck) == "function" and presetCheck(typed or value) then
                  new = titlecase(value)
                elseif typed and value ~= typed and value:upper() == typed:upper() then
                  new = typed
                end
              else
                new = decapBattleName(value)
                if not new and battleState.trainerCodes[code] then
                  local keepCustomRival = false
                  if not battleState.isRse and code == 0x1D then
                    local liveRival = rawget(P, "__decapLiveRival") or getLiveRivalName
                    local presetCheck = rawget(P, "__decapIsPreset") or isPresetName
                    local rival = type(liveRival) == "function" and liveRival() or nil
                    if type(rival) == "string" and rival ~= ""
                        and rival:upper() == value:upper()
                        and not (type(presetCheck) == "function" and presetCheck(rival)) then
                      keepCustomRival = true
                      if value ~= rival then new = rival end
                    end
                  end
                  if not keepCustomRival then
                    new = titlecase(value)
                  end
                end
              end
              if new then
                rawset(t, code, new)
                return new
              end
            end
            return value
          end
          meta.__decapWrapped = true
        end
        return ctx
      end
      rawset(BattleText, "__decapBattle", true)
    end

    local okSum, SummaryData = pcall(require, "src.core.game3.summary_data")
    if okSum and type(SummaryData) == "table" and not rawget(SummaryData, "__decapDescriptions") then
      for _, fname in ipairs({ "moveDescription", "abilityDescription", "contestEffectDescription", "contestCategoryName" }) do
        local fn = SummaryData[fname]
        if type(fn) == "function" then
          SummaryData[fname] = function(...) return decapString(fn(...)) end
        end
      end
      rawset(SummaryData, "__decapDescriptions", true)
    end

    local okPD, PokedexData = pcall(require, "src.core.game3.pokedex_data")
    if okPD and type(PokedexData) == "table" and type(PokedexData.getEntry) == "function"
        and not rawget(PokedexData, "__decapPokedex") then
      local original = PokedexData.getEntry
      PokedexData.getEntry = function(...)
        local entry = original(...)
        decapDexFields(entry)
        return entry
      end
      rawset(PokedexData, "__decapPokedex", true)
    end

    local okMap, Mapsec = pcall(require, "src.ui.game3.rse.mapsec")
    if okMap and type(Mapsec) == "table" and type(Mapsec.readLua) == "function"
        and not rawget(Mapsec, "__decapPokedex") then
      local original = Mapsec.readLua
      Mapsec.readLua = function(rel, ...)
        local pack = original(rel, ...)
        if rel == "pokemon/pokedex/entries.lua" and type(pack) == "table" then
          for _, entry in pairs(pack) do
            decapDexFields(entry)
          end
        end
        return pack
      end
      rawset(Mapsec, "__decapPokedex", true)
    end

    local items = 0
    local okI, I = pcall(require, "src.core.game3.items_data")
    if okI and type(I) == "table" then
      local rows = rawget(I, "_byId")
      if type(rows) ~= "table" then
        pcall(I.ensureLoaded or I.info, 1)
        rows = rawget(I, "_byId")
      end
      if type(rows) == "table" then
        for _, row in pairs(rows) do
          if type(row) == "table" then
            local new = titlecase(row.name)
            if new then
              row.name = new
              items = items + 1
            end
            local desc = decapText(row.description)
            if desc then row.description = desc end
            if type(row.name) == "string" and hasLowerAscii(row.name) then
              local upperName = row.name:upper()
              defaultNames[upperName] = row.name
              itemNames[upperName] = row.name
            end
          end
        end
      end
      if type(I.info) == "function" and not rawget(I, "__decapNames") then
        local original = I.info
        I.info = function(...)
          local result = original(...)
          if type(result) == "table" then
            if type(result.name) == "string" then
              local new = titlecase(result.name)
              if new then result.name = new end
            end
            if type(result.description) == "string" then
              result.description = decapString(result.description)
            end
          end
          return result
        end
        rawset(I, "__decapNames", true)
      end
      if type(I.description) == "function" and not rawget(I, "__decapItemDesc") then
        local original = I.description
        I.description = function(...)
          return decapString(original(...))
        end
        rawset(I, "__decapItemDesc", true)
      end
      if type(I.displayName) == "function" and not rawget(I, "__decapDisplayName") then
        local original = I.displayName
        I.displayName = function(...)
          local result = original(...)
          if type(result) == "string" then
            local new = titlecase(result)
            if new then return new end
          end
          return result
        end
        rawset(I, "__decapDisplayName", true)
      end
    end

    local berries = 0
    local okBerries, BT = pcall(require, "src.core.game3.rse.berry_trees")
    if okBerries and type(BT) == "table" then
      if type(BT.name) == "function" and not rawget(BT, "__decapBerry") then
        local original = BT.name
        BT.name = function(...)
          local result = original(...)
          if type(result) == "string" then
            local new = titlecase(result)
            if new then return new end
          end
          return result
        end
        rawset(BT, "__decapBerry", true)
      end
      if type(BT.berries) == "function" then
        local okL, list = pcall(BT.berries)
        if okL and type(list) == "table" then
          for _, row in pairs(list) do
            if type(row) == "table" then
              local new = titlecase(row.name)
              if new then
                row.name = new
                berries = berries + 1
              end
              if type(row.name) == "string" and hasLowerAscii(row.name) then
                local upperName = row.name:upper()
                defaultNames[upperName] = row.name
                itemNames[upperName] = row.name
              end
            end
          end
        end
      end
    end

    rebuildFontDict(defaultNames)
    local known = 0
    for _ in pairs(fontDict) do known = known + 1 end

    displayText = ("display pass: %d species, %d moves, %d abilities, %d items, %d berries renamed, %d known names"):format(
      species, moves, abilities, items, berries, known)
    return P
  end

  local resetOmniCache
  local function omniPass()
    if not DIALOGUE then return end
    local handle = findMod("omni_ui")
    if not (type(handle) == "table" and type(handle.exports) == "table") then return end
    local exports = handle.exports
    local Layout = exports.Layout
    if type(Layout) ~= "table" or type(Layout.cleanText) ~= "function" then return end

    local state = rawget(Layout, "__decapOmniState")
    if type(state) ~= "table" then
      state = { bypassDepth = 0, bypassText = nil }
      rawset(Layout, "__decapOmniState", state)
    end

    local cachedPlayer, cachedRival, cachedNickSig = false, false, false
    local cachedList, cachedAliases, cachedHasAliases = {}, {}, false
    local textCache, textCacheSize = {}, 0

    local function clearTextCache()
      textCache = {}
      textCacheSize = 0
    end

    resetOmniCache = function()
      cachedPlayer, cachedRival, cachedNickSig = false, false, false
      clearTextCache()
    end

    local function getOmniProtection()
      local p = type(getLivePlayerName) == "function" and getLivePlayerName() or nil
      local r = type(getLiveRivalName) == "function" and getLiveRivalName() or nil
      local nicks = collectCustomNicknames()
      local nickSig = ""
      if nicks then
        table.sort(nicks)
        nickSig = table.concat(nicks, "\31")
      end
      if p == cachedPlayer and r == cachedRival and nickSig == cachedNickSig then
        return cachedList, cachedAliases, cachedHasAliases
      end

      cachedPlayer, cachedRival, cachedNickSig = p, r, nickSig
      clearTextCache()

      local set, aliases = {}, {}
      if type(getProtectedNames) == "function" then
        local baseList, _, baseAliases = getProtectedNames(nil)
        for _, name in ipairs(baseList) do set[name] = true end
        for from, to in pairs(baseAliases) do aliases[from] = to end
      end
      if nicks then
        for _, nick in ipairs(nicks) do
          if nick:find("[A-Z]") or nick:find(E_ACUTE_UPPER, 1, true) then
            set[nick] = true
          end
          local upperNick = nick:upper()
          if nick ~= upperNick and (upperNick:find("[A-Z]") or upperNick:find(E_ACUTE_UPPER, 1, true)) then
            set[upperNick] = true
            aliases[upperNick] = nick
          end
        end
      end

      local list = {}
      for name in pairs(set) do list[#list + 1] = name end
      table.sort(list, function(x, y)
        if #x ~= #y then return #x > #y end
        return x < y
      end)
      cachedList = list
      cachedAliases = aliases
      cachedHasAliases = next(aliases) ~= nil
      return cachedList, cachedAliases, cachedHasAliases
    end

    local function omniTransform(cleaned)
      if type(cleaned) ~= "string" or cleaned == "" then return cleaned end
      if state.bypassDepth > 0 then return cleaned end
      if state.bypassText ~= nil and cleaned == state.bypassText then return cleaned end
      if isNamingOpen() then return cleaned end

      local list, aliases, hasAliases = getOmniProtection()
      local hit = textCache[cleaned]
      if hit ~= nil then return hit end

      local work = collapseDuplicatePokemon(cleaned)
      local out = work
      if needsDecap(work, hasAliases) then
        out = decapText(work, list, aliases, OMNI_KEEP) or work
      end

      if textCacheSize >= 512 then clearTextCache() end
      textCache[cleaned] = out
      textCacheSize = textCacheSize + 1
      return out
    end

    rawset(Layout, "__decapOmniFn", omniTransform)
    rawset(Layout, "__decapOmniReset", resetOmniCache)

    local hooked = false
    if not rawget(Layout, "__decapOmni") then
      local origCleanText = Layout.cleanText
      Layout.cleanText = function(text, ...)
        local cleaned = origCleanText(text, ...)
        local fn = rawget(Layout, "__decapOmniFn")
        if type(fn) == "function" then
          return fn(cleaned)
        end
        return cleaned
      end
      rawset(Layout, "__decapOmni", true)
      hooked = true
    end

    if type(Layout.drawButtonHint) == "function" and not rawget(Layout, "__decapOmniHint") then
      local origDrawButtonHint = Layout.drawButtonHint
      Layout.drawButtonHint = function(x, y, keyText, labelText, opts)
        local prev = state.bypassText
        state.bypassText = keyText ~= nil and tostring(keyText) or nil
        local okH, a, b, c, d = pcall(origDrawButtonHint, x, y, keyText, labelText, opts)
        state.bypassText = prev
        if not okH then error(a, 0) end
        return a, b, c, d
      end
      rawset(Layout, "__decapOmniHint", true)
      hooked = true
    end

    local Widgets = exports.Widgets
    if type(Widgets) == "table" and type(Widgets.drawStatusBadge) == "function"
        and not rawget(Widgets, "__decapOmni") then
      local origDrawStatusBadge = Widgets.drawStatusBadge
      Widgets.drawStatusBadge = function(...)
        state.bypassDepth = state.bypassDepth + 1
        local okW, a, b, c, d = pcall(origDrawStatusBadge, ...)
        state.bypassDepth = state.bypassDepth - 1
        if not okW then error(a, 0) end
        return a, b, c, d
      end
      rawset(Widgets, "__decapOmni", true)
      hooked = true
    end

    local MoveDatabase = exports.MoveDatabase
    if type(MoveDatabase) == "table" and type(MoveDatabase.getDescription) == "function"
        and not rawget(MoveDatabase, "__decapOmni") then
      local origMoveDesc = MoveDatabase.getDescription
      MoveDatabase.getDescription = function(...)
        return decapString(origMoveDesc(...), OMNI_KEEP)
      end
      rawset(MoveDatabase, "__decapOmni", true)
      hooked = true
    end

    local ItemDatabase = exports.ItemDatabase
    if type(ItemDatabase) == "table" and type(ItemDatabase.getDescription) == "function"
        and not rawget(ItemDatabase, "__decapOmni") then
      local origItemDesc = ItemDatabase.getDescription
      ItemDatabase.getDescription = function(...)
        return decapString(origItemDesc(...), OMNI_KEEP)
      end
      rawset(ItemDatabase, "__decapOmni", true)
      hooked = true
    end

    if hooked then
      mod.log:info("decap_names: optional omni_ui support hooked")
    end
  end

  local questHooked = false
  local function questLogPass()
    if not DIALOGUE or questHooked then return end
    local UI = loadModule("src.ui.game3.quest_log")
    if not (UI and type(UI.text) == "function") then return end
    questHooked = true
    if rawget(UI, "__decapQuest") then return end

    local function defaults()
      local P = loadModule("src.core.game3.pokemon")
      return P and rawget(P, "__decapDefaultNames") or {}
    end

    local function presetCheck(name)
      return type(isPresetName) == "function" and isPresetName(name)
    end

    local function fixedName(name)
      if type(name) ~= "string" or name == "" then return name end
      if presetCheck(name) then return titlecase(name) or name end
      return name
    end

    local function questArg(v, session)
      if type(v) ~= "string" or v == "" or hasLowerAscii(v) then return v end
      local upper = v:upper()
      for _, field in ipairs({ "name", "rivalName" }) do
        local own = session[field]
        if type(own) == "string" and own ~= "" and own:upper() == upper then
          return fixedName(own)
        end
      end
      local d = defaults()[v] or defaults()[upperKey(v)]
      if d then return d end
      if upper == "TRAINER" or v:match("^BOX ?%d+$") then
        return titlecase(v) or v
      end
      return v
    end

    local decappedPack
    local function decapPack()
      local pack = rawget(UI, "pack")
      if pack == decappedPack or type(pack) ~= "table" or type(pack.text) ~= "table" then return end
      for key, text in pairs(pack.text) do
        if type(text) == "string" then
          local new = decapText(text)
          if new then pack.text[key] = new end
        end
      end
      decappedPack = pack
    end

    local original = UI.text
    UI.text = function(key, args, session)
      pcall(decapPack)
      local real = type(session) == "table" and session or {}
      local fixedArgs = args
      if type(args) == "table" then
        fixedArgs = {}
        for k, v in pairs(args) do
          local okA, new = pcall(questArg, v, real)
          fixedArgs[k] = okA and new or v
        end
      end
      local view = setmetatable({
        name = fixedName(real.name or "RED"),
        rivalName = fixedName(real.rivalName or "BLUE"),
      }, { __index = real })
      return original(key, fixedArgs, view)
    end
    rawset(UI, "__decapQuest", true)
    mod.log:info("decap_names: quest log hooked")
  end

  mod.events:on("game.ready", function()
    local okTextReady, errTextReady = pcall(textPass)
    if not okTextReady then
      dialogueText = "dialogue: hook error"
      mod.log:warn("decap_names: dialogue hooks failed: %s", tostring(errTextReady))
    end
    local okMenu, errMenu = pcall(menuPass)
    if not okMenu then mod.log:warn("decap_names: pause menu hook failed: %s", tostring(errMenu)) end
    local okParty, errParty = pcall(partyMenuPass)
    if not okParty then mod.log:warn("decap_names: party menu hook failed: %s", tostring(errParty)) end
    if originMark then
      local okOrigin, errOrigin = pcall(originMark)
      if not okOrigin then mod.log:warn("decap_names: origin hook failed: %s", tostring(errOrigin)) end
    end
    pcall(checkNameTagsSupport)
    local ok, P = pcall(displayPass)
    if not ok then
      displayText = "display pass failed: " .. tostring(P)
      mod.log:warn("decap_names: %s", displayText)
      P = nil
    end
    local okStrings, errStrings = pcall(engineStringsPass)
    if not okStrings then mod.log:warn("decap_names: engine text hook failed: %s", tostring(errStrings)) end
    local okQuest, errQuest = pcall(questLogPass)
    if not okQuest then mod.log:warn("decap_names: quest log hook failed: %s", tostring(errQuest)) end
    local okOmni, errOmni = pcall(omniPass)
    if not okOmni then mod.log:warn("decap_names: omni_ui hook failed: %s", tostring(errOmni)) end
    mod.log:info("decap_names: %s; %s", displayText, dialogueText)
    if P and type(P.onReload) == "function" then
      P.onReload(function()
        if type(resetOmniCache) == "function" then pcall(resetOmniCache) end
        local okReload, errReload = pcall(displayPass)
        if not okReload then mod.log:warn("decap_names: display reload failed: %s", tostring(errReload)) end
      end, "decap_names")
    end
  end)
end
