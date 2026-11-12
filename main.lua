local KEEP_UPPER = { HP = true, PP = true, TM = true, HM = true, SP = true, XS = true, XL = true }

local EXACT = {
 ["MR. MIME"] = "Mr. Mime",
 ["MR.MIME"] = "Mr. Mime",
 ["HO-OH"] = "Ho-Oh",
 ["FARFETCH'D"] = "Farfetch'd",
 ["POKé BALL"] = "Poké Ball",
 ["POKé DOLL"] = "Poké Doll",
 ["POKé FLUTE"] = "Poké Flute",
 ["POKéMON"] = "Pokémon",
}

local function has_lower_ascii(s) return s:find("%l") ~= nil end

local function titlecase(name)
 if type(name) ~= "string" or name == "" then return nil end
 name = name:gsub("É", "é")
 if has_lower_ascii((name:gsub("é", ""))) then return nil end
 if name:find("[{<%%]") then return nil end
 if EXACT[name] then return EXACT[name] end

 local out = {}
 local pos = 1
 while pos <= #name do
 local s, e = name:find("[%w'é]+", pos)
 if not s then out[#out + 1] = name:sub(pos); break end
 out[#out + 1] = name:sub(pos, s - 1)
 local word = name:sub(s, e)
 local up = word:upper()
 if KEEP_UPPER[up] or up:match("^[TH]M%d+$") then
 out[#out + 1] = up
 else
 out[#out + 1] = word:sub(1, 1):upper() .. word:sub(2):lower()
 end
 pos = e + 1
 end
 local result = table.concat(out)
 if result == name then return nil end
 return result
end

local TEXT_KEEP = {
 PC = true, TM = true, HM = true, HP = true, PP = true, ID = true, TV = true, OK = true,
 GBA = true, GB = true, HQ = true, DJ = true, CD = true, SP = true, XS = true, XL = true,
 DNA = true, UFO = true, VS = true, SOS = true,
}

local MARK_OPEN, MARK_CLOSE = string.char(1), string.char(2)

local function maskName(s, name, store, aliases)
 local out, pos = {}, 1
 while true do
 local a, b = s:find(name, pos, true)
 if not a then break end
 local before, after = s:sub(a - 1, a - 1), s:sub(b + 1, b + 1)
 if before:find("^%w$") or after:find("^%w$") then
 out[#out + 1] = s:sub(pos, b)
 else
 out[#out + 1] = s:sub(pos, a - 1)
 store[#store + 1] = (aliases and aliases[name]) or name
 out[#out + 1] = MARK_OPEN .. #store .. MARK_CLOSE
 end
 pos = b + 1
 end
 out[#out + 1] = s:sub(pos)
 return table.concat(out)
end

local function decapText(s, protected, aliases)
 if type(s) ~= "string" or not s:find("%u") then return nil end
 local source, store = s, {}
 if protected then
 for _, name in ipairs(protected) do source = maskName(source, name, store, aliases) end
 end
 if source:find("É") then source = source:gsub("É", "é") end
 local result = source:gsub("[%w'é]+", function(word)
 if word:find("%d") then return nil end

 local head, tail = word:match("^([%u\195\169]+)('%l+)$")
 if not head then head, tail = word:match("^([%u\195\169][%u\195\169]+)(s)$") end
 if head and select(2, head:gsub("%u", "")) >= 2 then
 if TEXT_KEEP[head] then return nil end
 return head:sub(1, 1):upper() .. head:sub(2):lower() .. tail
 end
 if word:find("%l") then return nil end
 local letters = word:gsub("[^%a]", "")
 if #letters < 1 then return nil end
 local up = word:upper()
 if TEXT_KEEP[up] then return nil end

 if up:match("^'%u+$") then
 return "'" .. up:sub(2):lower()
 end

 local stem = up:match("^(%u%u+)S$")
 if stem and TEXT_KEEP[stem] then return stem .. "s" end

 local base_poss, poss_s = up:match("^(.-)'[sS]$")
 if base_poss and #base_poss >= 2 then
 local b_letters = base_poss:gsub("[^%a]", "")
 if #b_letters >= 2 then
 return base_poss:sub(1, 1):upper() .. base_poss:sub(2):lower() .. "'s"
 end
 end

 if up:match("S$") and #up > 3 then
 local base = up:sub(1, #up - 1)
 return base:sub(1, 1):upper() .. base:sub(2):lower() .. "s"
 end

 return word:sub(1, 1):upper() .. word:sub(2):lower()
 end)
 if #store > 0 then
 result = result:gsub(MARK_OPEN .. "(%d+)" .. MARK_CLOSE, function(i) return store[tonumber(i)] end)
 end
 if result == s then return nil end
 return result
end

return function(mod)
 local SHOW_SUMMARY = false
 local DIALOGUE = true

 local FIELDS = {
 { "pokemon", { "name" } },
 { "moves", { "name" } },
 { "items", { "name" } },
 { "trainers", { "name", "className" } },
 }
 local totals = {}

 for _, entry in ipairs(FIELDS) do
 local registry, fields = entry[1], entry[2]
 local handle = mod.content[registry]
 if handle and mod:supports("content", registry) then
 local seen, changed, refused = 0, 0, 0
 local patches = {}
 local okEach, errEach = pcall(function()
 for id, record in handle:each() do
 seen = seen + 1
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
 end)
 if not okEach then
 mod.log:warn("decap_names: could not iterate %s: %s", registry, tostring(errEach))
 end
 table.sort(patches, function(a, b) return tostring(a.id) < tostring(b.id) end)
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

 local dialogueText = DIALOGUE and "dialogue: not hooked" or "dialogue: off"
 local dialogueSegs = 0

 local function checkNameTagsSupport()
 local okNT, nameTags = pcall(function() return mod.find and mod.find("name_tags") or require("mods.name_tags.main") end)
 if okNT and nameTags then
 mod.log:info("decap_names: Optional name_tags support detected and linked.")
 end
 end

 local labelDecap
 local originMark
 local function textPass()
 if not DIALOGUE then return end
 local okT, T = pcall(require, "src.core.game3.scripting.text_ir")
 if not (okT and type(T) == "table") then
 dialogueText = "dialogue: no engine access"
 return
 end
 if rawget(T, "__decapText") then return end

    local presetNames
    local function isPreset(name)
      if type(name) ~= "string" or name == "" then return false end
      if not presetNames then
        local okR, RomText = pcall(require, "src.core.game3.rom_text")
        if okR and type(RomText) == "table" and type(RomText.list) == "function" then
          local set, count = {}, 0
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
          if count > 0 then presetNames = set end
        end
      end
      return presetNames ~= nil and presetNames[name:upper()] == true
    end

    local function rivalIsFixed(ctx)
      local okD, d = pcall(T.dialect, type(ctx) == "table" and ctx.dialect or nil)
      return okD and type(d) == "table" and d.GENDERED_PH ~= nil and d.GENDERED_PH.RIVAL == true
    end

    local function livePlayerName()
      if type(T._provider) ~= "function" then return nil end
      local okF, name = pcall(function() return T._provider("playerName", T.dialect(nil), nil) end)
      if okF and type(name) == "string" and name ~= "" then return name end
      return nil
    end

    local function protectedNames(ctx)
      local set = {}
      local function add(v)
        if type(v) == "string" and #v >= 2 then set[v] = true end
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
          add(typed:upper())
          aliases[typed:upper()] = typed
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
        if not isPreset(rivalValue) then add(rivalValue) end
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

    local function fixPlural(value)
      if value:find("Ball S$") or value:find("[Bb]allS$") then return (value:gsub("S$", "s")) end
      if value:find("BerrIES$") then return (value:gsub("IES$", "ies")) end
      return nil
    end

    local originalToAscii = T.toAscii
    local function expandSeg(seg, ctx)
      local okE, value = pcall(originalToAscii, { seg, { t = "eos" } }, ctx)
      if okE and type(value) == "string" then return value end
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
          if seg.t == "text" and type(seg.s) == "string" and (seg.s:find("%u%u") or seg.s:find("'%u")) then
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
            dialogueSegs = dialogueSegs + 1
          end
        end
      end
      local result = changed and out or ir
      if not dynamic then cache[ir] = { n = #ir, sig = sig, ir = result } end
      return result
    end

 local wrapped = 0
 for _, fname in ipairs({ "expandPage", "toTextBox", "toAscii" }) do
 local original = T[fname]
 if type(original) == "function" then
 if fname == "expandPage" then
 T[fname] = function(ir, startIdx, ctx) return original(decapIR(ir, ctx), startIdx, ctx) end
 else
 T[fname] = function(ir, ctx) return original(decapIR(ir, ctx), ctx) end
 end
 wrapped = wrapped + 1
 end
 end

 local originalExpandSeg = T.expandSeg
 if type(originalExpandSeg) == "function" then
   T.expandSeg = function(seg, ctx)
     if runtimeSeg[seg] then return originalExpandSeg(seg, ctx) end
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

 labelDecap = function(label)
 local list, _, aliases = protectedNames(nil)
 return decapText(label, list, aliases)
 end
 rawset(T, "__decapText", true)
 dialogueText = ("dialogue: %d functions hooked, origin mode"):format(wrapped)
 end
 pcall(textPass)

 local menuHooked = false
 local function menuPass()
 if not DIALOGUE or menuHooked or not labelDecap then return end
 local SM = package.loaded["src.ui.game3.start_menu"]
 if type(SM) ~= "table" then
 local okS, loaded = pcall(require, "src.ui.game3.start_menu")
 SM = okS and loaded or nil
 end
 if type(SM) ~= "table" or type(SM.draw) ~= "function" then return end
 local original = SM.draw
 local function normalize()
 local entries = SM.ENTRIES
 if type(entries) ~= "table" then return end
 for _, entry in ipairs(entries) do
 if type(entry) == "table" and type(entry.label) == "string"
 and entry.__decapLabel ~= entry.label then
 local new = labelDecap(entry.label)
 if new then entry.label = new end
 entry.__decapLabel = entry.label
 end
 end
 end
 SM.draw = function(...)
 pcall(normalize)
 return original(...)
 end
 menuHooked = true
 mod.log:info("decap_names: pause menu labels hooked")
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

 local function displayPass()
 local okP, P = pcall(require, "src.core.game3.pokemon")
 if not (okP and type(P) == "table") then
 displayText = "display pass: no engine access"
 return nil
 end
 if rawget(P, "_names") == nil then pcall(P.name, 1) end
 local species = rewriteNames(rawget(P, "_names"))
 local moves = rewriteNames(rawget(P, "_moveNames"))
 local abilities = rewriteNames(rawget(P, "_abilityNames"))

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
 local okNT, nameTags = pcall(function() return mod.find and mod.find("name_tags") or require("mods.name_tags.main") end)
 return function(mon, ...)
 local result = original(mon, ...)
 if type(result) ~= "string" then return result end
 if type(mon) == "table" then
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
 end
 end
 end
 if type(I.info) == "function" and not rawget(I, "__decapNames") then
 local original = I.info
 I.info = function(...)
 local result = original(...)
 if type(result) == "table" and type(result.name) == "string" then
 local new = titlecase(result.name)
 if new then result.name = new end
 end
 return result
 end
 rawset(I, "__decapNames", true)
 end
 end

 local berries = 0
 local okB, BT = pcall(require, "src.core.game3.rse.berry_trees")
 if okB and type(BT) == "table" then
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
 pcall(textPass)
 pcall(menuPass)
 if originMark then pcall(originMark) end
 pcall(checkNameTagsSupport)
 local ok, P = pcall(displayPass)
 if not ok then
 displayText = "display pass failed: " .. tostring(P)
 mod.log:warn("decap_names: %s", displayText)
 return
 end
 mod.log:info("decap_names: %s; %s", displayText, dialogueText)
 if P and type(P.onReload) == "function" then
 P.onReload(function() pcall(displayPass) end, "decap_names")
 end
 end)
end
