local KEEP = {
  HP = true, PP = true, TM = true, HM = true, SP = true, XS = true, XL = true,
  PC = true, ID = true, TV = true, OK = true, GBA = true, GB = true, HQ = true,
  DJ = true, CD = true, DNA = true, UFO = true, VS = true, SOS = true,
  EV = true, IV = true, EXP = true, XP = true, NPC = true, AI = true,
  PKMN = true, PK = true, MN = true, SS = true,
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
  return (b >= 48 and b <= 57)  -- 0-9
      or (b >= 65 and b <= 90)  -- A-Z
      or (b >= 97 and b <= 122) -- a-z
      or b == 39                -- '
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

local function normalizeWord(word)
  if word:find("%d") then
    if word:find("[a-z]") then return nil end
    if word:match("^[TH]M%d+$") then return nil end
    local stem, digits = word:match("^(.-)(%d+)$")
    if stem and #stem >= 2 and not stem:find("%d") and countUpperAscii(stem) >= 2 then
      if KEEP[stem] then return nil end
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
    if KEEP[head] then return nil end
    return capFirst(head) .. tail
  end

  if hasLowerAscii(word) then return nil end
  if not word:find("[A-Z]") then return nil end

  if KEEP[word] then return nil end
  local exactWord = WORD_EXACT[word]
  if exactWord then return exactWord end

  if word:match("^'[A-Z]+$") then
    return "'" .. word:sub(2):lower()
  end

  local basePoss = word:match("^(.-)'S$")
  if basePoss and #basePoss >= 2 then
    local exactBase = WORD_EXACT[basePoss]
    if exactBase then return exactBase .. "'s" end
    if KEEP[basePoss] then return basePoss .. "'s" end
    if countUpperAscii(basePoss) >= 2 then
      return capFirst(basePoss) .. "'s"
    end
  end

  local basePlural = word:match("^(.+)S$")
  if basePlural and #basePlural >= 2 then
    local exactBase = WORD_EXACT[basePlural]
    if exactBase then return exactBase .. "s" end
    if KEEP[basePlural] then return basePlural .. "s" end
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

local function decapText(s, protected, aliases)
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
  local result = mapWords(source, normalizeWord)
  if #store > 0 then
    result = result:gsub(MARK_OPEN .. "(%d+)" .. MARK_CLOSE, function(i)
      return store[tonumber(i)]
    end)
  end
  if result == s then return nil end
  return result
end

local function decapString(value)
  if type(value) ~= "string" then return value end
  return decapText(value) or value
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

  local function checkNameTagsSupport()
    if type(mod.find) ~= "function" then return end
    local ok, handle = pcall(mod.find, mod, "name_tags")
    if ok and handle then
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
      local ok = installHook("ui.party.submenu", function(nextFn, game, items, mon, ctx)
        local rows = nextFn(game, items, mon, ctx)
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
        and not rawget(FrlgFont, "__decapDefaults") then
      local originalDraw = FrlgFont.draw
      FrlgFont.draw = function(text, ...)
        if type(text) == "string" then
          local replacement = defaultNames[text]
          if replacement then text = replacement end
        end
        return originalDraw(text, ...)
      end
      rawset(FrlgFont, "__decapDefaults", true)
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

    displayText = ("display pass: %d species, %d moves, %d abilities, %d items, %d berries renamed"):format(
      species, moves, abilities, items, berries)
    return P
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
      return
    end
    mod.log:info("decap_names: %s; %s", displayText, dialogueText)
    if P and type(P.onReload) == "function" then
      P.onReload(function()
        local okReload, errReload = pcall(displayPass)
        if not okReload then mod.log:warn("decap_names: display reload failed: %s", tostring(errReload)) end
      end, "decap_names")
    end
  end)
end
