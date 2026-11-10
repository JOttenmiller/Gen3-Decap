local KEEP_UPPER = { HP = true, PP = true, TM = true, HM = true, SP = true, XS = true, XL = true }

local EXACT = {
  ["MR. MIME"]   = "Mr. Mime",
  ["MR.MIME"]    = "Mr. Mime",
  ["HO-OH"]      = "Ho-Oh",
  ["FARFETCH'D"] = "Farfetch'd",
  ["POKé BALL"]  = "Poké Ball",
  ["POKé DOLL"]  = "Poké Doll",
  ["POKé FLUTE"] = "Poké Flute",
  ["POKéMON"]    = "Pokémon",
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


return function(mod)
  local SHOW_SUMMARY = false

  local FIELDS = {
    { "pokemon",  { "name" } },
    { "moves",    { "name" } },
    { "items",    { "name" } },
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
        -- a raised error would roll back the whole mod, so guard every write
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

    displayText = ("display pass: %d species, %d moves, %d abilities, %d items renamed"):format(
      species, moves, abilities, items)
    return P
  end

  mod.events:on("game.ready", function()
    local ok, P = pcall(displayPass)
    if not ok then
      displayText = "display pass failed: " .. tostring(P)
      mod.log:warn("decap_names: %s", displayText)
      return
    end
    mod.log:info("decap_names: %s", displayText)
    -- the engine rebuilds its name tables on every species reload; run again after each
    if P and type(P.onReload) == "function" then
      P.onReload(function() pcall(displayPass) end, "decap_names")
    end
  end)

  if SHOW_SUMMARY then
    mod.events:once("world.stepped", function()
      local parts = {}
      for _, entry in ipairs(FIELDS) do
        local t = totals[entry[1]]
        if t then
          parts[#parts + 1] = ("%s %d/%d/%d"):format(entry[1], t.seen, t.changed, t.refused)
        end
      end
      local text = "decap_names (seen/renamed/refused)\n" .. table.concat(parts, "\n")
        .. "\n" .. displayText
      mod.world:queueScript({ { "show_text", text } })
    end)
  end
end
