-- more extensions for AutoTouch's extensions file

--[[ TODO::
* add funcs for table dupe, sort nested tables, splitby(...) - for multi splits
* fix len()
* implement ipad functions
* getting the source of a file is returning the rootdir+full path to extensions (implement traceback func)
  > replace all debug.getinfo with the most recent item in traceback
* rename all funcs to capd version and have current case be pcall to handle error catching
  > pcall(funcName, param1, param2, etc.)
* have all file funcs default to searching rootdir
* implement help function
--]]



-- BACKEND FUNCTIONS --

function traceback()
  local level = 1
  log(">>>> TRACEBACK >>>>")
  while true do
    local info = debug.getinfo(level, "Sl")
    if not info then break end
    log(string.format("[%s]:%d",info.short_src, info.currentline))
    level = level + 1
  end
  log("<<<< END TRACEBACK <<<<")
end
 
--- Turn a table to a formatted string for easier viewing
-- @param tabl The target table
-- @param indent How many spaces each indent should be
-- @param done A table of the lines to output
-- @return A multi-line string
function formatted_table(tabl, indent, done)
-- func for multi-line table print ; ie logtable()
  local tabStr = "  .  "
  done = done or {}
  indent = indent or 0
  if type(tabl) == "table" then
    local data = {}
    for key, value in pairs(tabl) do
      table.insert(data, string.rep(tabStr, indent)) -- indent it
      if type(value) == "table" and not done[value] then
  done [value] = true
  table.insert(data, "\"" .. tostring(key) .. "\" = \n" .. string.rep(tabStr,indent) .. "{\n");
  table.insert(data, formatted_table(value, indent + 1, done))
  table.insert(data, string.rep (tabStr, indent)) -- indent it
  table.insert(data, "}\n");
      elseif type(key) == "number" then
  table.insert(data, string.format("%s,\n", tostring(value)))
      else
  table.insert(data, string.format(
      "\"%s\" = \"%s\",\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(data)
  else
    return tabl .. "\n"
  end
end

--- Turn the given variable into a string
--- Function 1 of 3 in formatting a table for one-line printing
function val2str ( v )
  if type( v ) == "string" then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return type( v ) == "table" and table2string( v ) or
      tostring( v )
  end
end

--- Turns the given key into a string
--- Function 2 of 3 in formatting a table for one-line printing
function key2str ( k )
  if type( k ) == "string" and string.match( k, "^[_%a][_%a%d]*$" ) then
    return "\"" .. k .. "\""
  else
    return "[" .. val2str( k ) .. "]"
  end
end

--- The start point to turn a table into a string
--- Function 3 of 3 in formatting a table for one-line printing
function table2string( tbl )
-- func 3 of 3 in one-line table print ; ie str()
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, val2str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
  key2str( k ) .. " = " .. val2str( v ) )
    end
  end
  return "{" .. table.concat( result, ", " ) .. "}"
end

--- Get data from the plist of installed applications
function parseServicesPlist()
  local apps = {}
  local fReader = io.lines("/var/mobile/Library/MobileInstallation/LastLaunchServicesMap.plist")
  for lyn in fReader do
    if (lyn ~= nil or lyn ~= "nil") and isin("<key>", lyn) and isin(".", lyn) then
      lyn = lyn:gsub("<key>", "")
      lyn = lyn:gsub("</key>", "")
      lyn = lyn:gsub("\t", "")
      --log(lyn .. " (" .. count(" ",lyn) ..")")
      table.insert(apps, 1, lyn)
    end
  end
  return apps
end

--- Turns a color in red, green, blue format to X, Y, Z format
function rgb2xyz(r,g,b)
  r = r / 255
  g = g / 255
  b = b / 255
  
  if r > 0.04045 then
    r = ((r + 0.055) / 1.055)^2.4
  else
    r = r / 12.92
  end
  r = r * 100
  
  if g > 0.04045 then
    g = ((g + 0.055) / 1.055)^2.4
  else
    g = g / 12.92
  end
  g = g * 100
  
  if b > 0.04045 then
    b = ((b + 0.055) / 1.055)^2.4
  else
    b = b / 12.92
  end
  b = b * 100
  
  -- for observer = 2* and illuminant=d65 (whatever that really means) ....
  local x = (r * 0.4124) + (g * 0.3576) + (b * 0.1805)
  local y = (r * 0.2126) + (g * 0.7152) + (b * 0.0722)
  local z = (r * 0.0193) + (g * 0.1192) + (b * 0.9505)
  
  return round(x,3), round(y,3), round(z,3)
end
  
--- Turns a color in X, Y, Z format to LAB format
function xyz2lab(x,y,z)
  x = x / 95.047
  y = y / 100.0
  z = z / 108.883
  
  if x > 0.008856 then
    x = x^(1/3)
  else
    x = (7.787*x) + (16/116)
  end
  
  if y > 0.008856 then
    y = y^(1/3)
  else
    y = (7.787*y) + (16/116)
  end
  
  if z > 0.008856 then
    z = z^(1/3)
  else
    z = (7.787*z) + (16/116)
  end
  
  local l = (116*y)-16
  local a = 500*(x-y)
  local b = 200*(y-z)
  
  return round(l,3), round(a,3), round(b,3)
end

--- A shortcut function to turn a color in red, green, blue format to LAB format
function rgb2lab(r, g, b)
  local x, y, z = rgb2xyz(r, g, b)
  return xyz2lab(x, y, z)
end

--- Finds the closest color name of the given color (in red, green, blue format) given the ID of which map to use
--- Higher IDs = More color names (0 -> 3)
function closestName(red, grn, blu, mapID)
  local l, a, b = rgb2lab(red, grn, blu)
  local ColorMap = {}
  if mapID <= 0 then
    ColorMap = {["10% Gray"]="#E6E6E6", ["15% Gray"]="#D9D9D9", ["20% Gray"]="#CCCCCC", ["25% Gray"]="#BFBFBF", ["30% Gray"]="#B3B3B3", ["35% Gray"]="#A6A6A6", ["40% Gray"]="#999999", ["45% Gray"]="#8C8C8C", ["5% Gray"]="#F2F2F2", ["50% Gray"]="#808080", ["55% Gray"]="#737373", ["60% Gray"]="#666666", ["65% Gray"]="#595959", ["70% Gray"]="#4D4D4D", ["75% Gray"]="#404040", ["80% Gray"]="#333333", ["85% Gray"]="#262626", ["90% Gray"]="#191919", ["95% Gray"]="#0D0D0D", ["Black"]="#000000", ["White"]="#FFFFFF"}
  else
    ColorMap = {["Cyan"]="#00FFFF", ["Olive"]="#808000", ["Green"]="#008000", ["Light Blue"]="#ADD8E6", ["Magenta"]="#FF00FF", ["Teal"]="#008080", ["Purple"]="#800080", ["Dark Blue"]="#0000A0", ["Orange"]="#FFA500", ["Red"]="#FF0000", ["Navy"]="#000080", ["Gray"]="#808080", ["Yellow"]="#FFFF00", ["Maroon"]="#800000", ["Lime"]="#00FF00", ["White"]="#FFFFFF", ["Blue"]="#0000FF", ["Brown"]="#A52A2A", ["Black"]="#000000", ["Silver"]="#C0C0C0"}
    if mapID >= 2 then
      ColorMap = merge(ColorMap, {["10% Gray"]="#E6E6E6", ["20% Gray"]="#CCCCCC", ["30% Gray"]="#B3B3B3", ["40% Gray"]="#999999", ["50% Gray"]="#808080", ["60% Gray"]="#666666", ["70% Gray"]="#4D4D4D", ["80% Gray"]="#333333", ["90% Gray"]="#191919", ["Aquamarine"]="#7FFFD4", ["Beige"]="#F5F5DC", ["Blue Violet"]="#8A2BE2", ["Dark Goldenrod"]="#B8860B", ["Dark Green"]="#006400", ["Dark Orange"]="#FF8C00", ["Dark Red"]="#8B0000", ["Dark Turquoise"]="#00CED1", ["Deep Pink"]="#FF1493", ["Gold"]="#FFD700", ["Goldenrod"]="#DAA520", ["Gray-Blue"]="#5F9EA0", ["Green-Yellow"]="#ADFF2F", ["Honeydew"]="#F0FFF0", ["Hot Pink"]="#FF69B4", ["Indigo"]="#4B0082", ["Khaki"]="#F0E68C", ["Lavender"]="#E6E6FA", ["Light Green"]="#90EE90", ["Light Yellow"]="#FFFFE0", ["Orange-Red"]="#FF4500", ["Pale Green"]="#98FB98", ["Pink"]="#FFC0CB", ["Plum"]="#DDA0DD", ["Salmon"]="#FA8072", ["Sandy Brown"]="#F4A460", ["Tan"]="#D2B48C", ["Turquoise"]="#40E0D0", ["Violet"]="#EE82EE", ["Yellow-Green"]="#9ACD32"})
      if mapID >= 3 then
        ColorMap = merge(ColorMap, {["15% Gray"]="#D9D9D9", ["25% Gray"]="#BFBFBF", ["35% Gray"]="#A6A6A6", ["45% Gray"]="#8C8C8C", ["55% Gray"]="#737373", ["65% Gray"]="#595959", ["75% Gray"]="#404040", ["85% Gray"]="#262626", ["95% Gray"]="#0D0D0D", ["Antique White"]="#FAEBD7", ["Chartreuse"]="#7FFF00", ["Coral"]="#FF7F50", ["Crimson"]="#DC143C", ["Dark Gray-Green"]="#8FBC8F", ["Dark Khaki"]="#BDB76B", ["Dark Olive"]="#556B2F", ["Dark Salmon"]="#E9967A", ["Ivory"]="#FFFFF0", ["Light Goldenrod-Yellow"]="#FAFAD2", ["Light Pink-Red"]="#F08080", ["Light Salmon"]="#FFA07A", ["Medium Blue"]="#0000CD", ["Medium Violet-Red"]="#C71585", ["Misty Rose"]="#FFE4E1", ["Moccasin"]="#FFE4B5", ["Navajo White"]="#FFDEAD", ["Pale Goldenrod"]="#EEE8AA", ["Pale Purple"]="#9370DB", ["Pale Violet-Red"]="#DB7093", ["Peach Puff"]="#FFDAB9", ["Powder Blue"]="#B0E0E6", ["Purple-Blue"]="#6A5ACD", ["Rosy Brown"]="#BC8F8F", ["Royal Blue"]="#4169E1", ["Saddle Brown"]="#8B4513", ["Sky Blue"]="#87CEEB", ["Spring Green"]="#00FF7F", ["Steel Blue"]="#4682B4", ["Wheat"]="#F5DEB3"})
      end
    end    
  end
  local mindiff = nil
  mincolorname = ''
  for n,h in pairs(ColorMap) do
    local RED, GRN, BLU = tonumber(h:sub(2,3),16), tonumber(h:sub(4,5), 16), tonumber(h:sub(6,7), 16)  
    local L, A, B = rgb2lab(RED, GRN, BLU)
    local diff = math.sqrt((L-l)^2 + (A-a)^2 + (B-b)^2)
    if mindiff == nil or diff < mindiff then  
      mindiff = diff  
      mincolorname = n 
    end
  end
  return mincolorname 
end

-- /BACKEND FUNCTIONS --



-- Check/logic related functions --

--- Gets the app that is currently open
function getActiveApp()
  local apps = parseServicesPlist()
  
  for _,appID in pairs(apps) do
    local status = appState(appID)
    if status == nil then status = "nil" end
    --log("\n"..appID.." (" .. status .. ")")
    if status == "ACTIVATED" then return appID end
  end
  return "nil"
end

--- Checks whether an item in a table
function isItemInTable(i, t)
  for i,v in pairs(t) do
    if str(v) == str(i) then
      return true
    end
  end
  return false
end

--- Checks whether a substring (needle) is contained within a larger string (haystack)
function isNeedleInHaystack(n, h)
  if string.find(h,n) ~= nil then
    return true
  else
    return false
  end
end

--- A more intuative function name to check for a substring
function isStrInStr(n, h)
  return isNeedleInHaystack(n,h)
end

--- Deep copies the table
function table.copy(tbl)
  local orig_type = type(tbl)
  local copied
  if orig_type == 'table' then
      copied = {}
      for orig_key, orig_value in next, tbl, nil do
          copied[table.copy(orig_key)] = table.copy(orig_value)
      end
      setmetatable(copied, table.copy(getmetatable(tbl)))
  else -- number, string, boolean, etc
      copied = tbl
  end
  return copied
end

--- Checks if two tables equal each other
function tblsEqual(t1, t2)
  table.sort(t1)
  table.sort(t2)
  for i,v in pairs(t1) do
    if t1[i] ~= t2[i] then
      return false
    end
  end
  return true
end

--- Checks whether a sub-table (x) is contained within a larger table (y)
function isTableInTable(x, y)
  -- assumes x is table and y is 1-layered nested table
  for i,v in pairs(y) do
    if tblsEqual(x, v) then
      return true
    end
  end
  return false
end

--- A shortcut function for checking if one variable is contained within another
function isin(x,y)
  if isStr(x) and isStr(y) then
    return isNeedleInHaystack(x,y)
  elseif isBool(x) and isStr(y) then
    return isNeedleInHaystack(str(x),y)
  elseif (isStr(x) or isBool(x) or isNum(x)) and isTable(y) then
    return isItemInTable(x,y)
  elseif isTable(x) and isTable(y) then
    return isTableInTable(x,y)
  else
    alert("I dont understand (or could not parse) your inputs of: " .. x .. " and " .. y .. " for function isin(). Returning nil.")
    return nil
 end
end

--- A reverse function of isin
function isnotin(x,y)
  return not isin(x,y)
end

--- Counts how many times value appears in the input
function count(input, value)
  local c = 0
  if type(input) == "table" then
    for _,v in pairs(input) do
      if v == value then c = c + 1 end
    end
  else
    if head == nil or tail == nil then
      head,  tail = string.find(input, value)
    end
    while head ~= nil or tail ~= nil do 
      if (head ~= nil and tail ~= nil) then
  c = c + 1
  head, tail = string.find(input, value, tail + 1)
      end 
    end
  end
  return c
end

--- Provides a more intuitive way to format a string for people who don't know about regular expressions
function toPattern(input)
  -- replaces all instances of <TYPE> with its respective pattern (useful for replace/gsub functions)
  --[[ 
%a: represents all letters. 
%c: represents all control characters. 
%d: represents all digits. 
%l: represents all lowercase letters. 
%p: represents all punctuation characters. 
%s: represents all space characters. 
%u: represents all uppercase letters. 
%w: represents all alphanumeric characters.
%x: represents all hexadecimal digits. 
%z: represents the character with representation 0
?: previous character may appear 0 to 1 times.
+: previous character may appear 1 to infinite times.
*: previous character may appear 0 to infinite times.
^: marks beginning of string 
$: marks end of string
  --]]
  letters  = "<LETTER>"
  control  = "<CTRL>"
  digits   = "<NUM>"
  lower    = "<LOWER>"
  upper    = "<UPPER>"
  punct    = "<PUNCT>"
  space    = "<SPACE>"
  alphanum = "<ALPHANUM>"
  hexa     = "<HEX>"
  null     = "<NULL>"
  head     = "<START>"
  tail     = "<END>"
  
  error("Not implemented.")
end
  
  
-- Useful conversion and string functions --

--- Turns a color in hex format to red, green, blue format
function hexToRgb(hex)
  if type(hex) == "number" then
    hex = str(hex)
  end
  hex = hex:gsub("#","")
  hex = hex:gsub("0x","")
  return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

--- Turns a color in hex format to integer format
function hexToInt(hex)
  local r,g,b = hexToRgb(hex)
  return rgbToInt(r,g,b)
end

--- Turns a color in red, green, blue format to hex format
function rgbToHex(r,g,b)
  local rgb = {r,g,b}
  local hexResult = "0x"
  for key, value in pairs(rgb) do
    local hex = ''
    while(value > 0)do
    local index = math.fmod(value, 16) + 1
    value = math.floor(value / 16)
    hex = string.sub('0123456789ABCDEF', index, index) .. hex     
  end

  if(string.len(hex) == 0)then
    hex = '00'
  elseif(string.len(hex) == 1)then
    hex = '0' .. hex
  end
  hexResult = hexResult .. hex
  end
  return hexResult
end

--- Turns a color in integer format to hex format
function intToHex(int)
  r,g,b = intToRgb(int)
  return rgbToHex(r,g,b)
end

--- Finds the closest color name to the given color in red, green, blue format
function rgbToName(r, g, b, colorScheme)
  if colorScheme == nil then
    colorScheme = 1
  end
  if isnotin(colorScheme, {"gray", "grey", "basic", "indepth", "complete", "small", "medium", "large", 0, 1, 2, 3}) then
    error("Your colorScheme of " .. colorScheme .. " is invalid. colorScheme needs to be one of the following: gray/grey, basic, indepth, complete, small, medium, large, or a value from 0-3. Check the help doc (generated using the main functions+ script) for more info.")
  end

  local name = "?"
  if isin(colorScheme, {"gray", "grey", 0}) then
    name = closestName(r, g, b, 0)
  elseif isin(colorScheme, {"basic", "small", 1}) then
    name = closestName(r, g, b, 1)
  elseif isin(colorScheme, {"indepth", "medium", 2}) then
    name = closestName(r, g, b, 2)
  elseif isin(colorScheme, {"complete", "large", 3}) then
    name = closestName(r, g, b, 3)
  end
  return name
end 

--- Finds the closest color name to the given color in integer format
function intToName(i, colorScheme)
  local r, g, b = intToRgb(i)
  return rgbToName(r, g, b, colorScheme)
end

--- Finds the closest color name to the given color in hex format
function hexToName(hex, colorScheme)
  local r, g, b = hexToRgb(hex)
  return rgbToName(r, g, b, colorScheme)
end

--- Integer division
function div(d1, d2)
  return math.floor(d1/d2)
end

--- A convenient function to turn any given input into a string
function str(input)
 if input == nil then return "nil" end
 if type(input)=="number" or type(input)=="boolean" then
  return tostring(input)
 elseif type(input)=="table" then
  return table2string(input)
 else 
  return input
 end
end

--- A convenient function to turn a given input into a number
function num(input)
  if input~=nil and tonumber(input)== nil then
    error("Your input of '" .. input .. "' cannot be converted to a number; Aborting.")
  end
  return tonumber(input)
end

--- Splits a string based on a delimiter, with the option to automatically convert strings which are numbers
function string.split(input, delim, autoNum)
  if delim == nil then delim = "" end
  if autoNum == nil then autoNum = true end
  output = {}
  currEntry = ""
  idx = 1
  if type(input) == "number" then
    input = str(input)
  end
  for i = 1, #input do
    local char = input:sub(i,i)
    if delim == "" then
      status,op = pcall(num,char)
      if status and autoNum then
        char = op
      end
      output[idx] = char
      idx = idx + 1
    elseif char ~= delim then
      currEntry = currEntry .. char
    else
      status,op = pcall(num,currEntry)
      if status and autoNum then
        currEntry = op
      end
      output[idx] = currEntry
      currEntry = ""
      idx = idx + 1
    end
  end
  if currEntry ~= "" then
    status,op = pcall(num,currEntry)
    if status and autoNum then
      currEntry = op
    end
    output[idx] = currEntry
    currEntry = ""
  end
  return output
end

--- Checks if the input string starts with a given substring
function string.startswith(input, starts)
  return string.sub(input, 1, string.len(starts)) == starts
end

--- Checks if the input string ends with a given substring
function string.endswith(input, ends)
  if isNil(ends) then 
    traceback()
    ends = ''
  end
  return ends == '' or string.sub(input, -string.len(ends)) == ends
end

--- Removes leading/trailing whitespace from the input
function string.trim(input)
  return (input:gsub("^%s*(.-)%s*$", "%1"))
end

--- Replaces parts of a string with something else, with the option to limit it a certain number of times
function string.replace(input, before, after, limit)
  if input == nil or input == "" then error("Input must not be nil or an empty string; Aborting.") end
  if before == nil or before == "" then error("Before parameter must not be nil or an empty string; Aborting.") end
  if after == nil then after = "" end
  if limit == nil then limit = 0 end
  
  input = input:gsub(before, after, limit)
  
  return input
end

--- Similar to Python's format; allows a string filled with curly brackets to be replaced with the corresponding value in the extra arguments
function format(input, ...)
  local arg = {...}
  local aIdx = 1
  
  -- if user inputs a string without any "{}" or without any parameters
  if #arg == 0 or isnotin("{}",input) then
    return input
  end
  
  while isin("{}", input) do
    if aIdx > #arg then
      local numCurly = count(input, "{}")
      error("Not enough parameters provided - your input contains " .. numCurly .. " {}'s, but only " .. str(#arg) .. " parameters.")
    end
    input = input:gsub("{}", arg[aIdx], 1)
    aIdx = aIdx + 1
  end
  
  return input
end

--- Combines two tables
function merge(...)
  local arg = {...}
  local result = {}
  for i,v in pairs(arg) do
    if not isTable(v) then
      v = str(v)
      table.insert(result, v)
    else
      for i2,v2 in pairs(v) do
        table.insert(result, v2)
      end
    end
  end
  return result
end

--- Compares two non-nested tables for similarity
function compareTables(t1, t2)
  error("Not implemented. Complain to the dev to finish this.")
  return 0
end

--- Join together the given file paths in the order given
function join(...)
  local arg = {...}
  if #arg == 0 then
    error("Function join must have at least 1 parameter; Aborting.")
  end
  local output = ""
  if isNil(arg[1]) then
    error("Arg 1 appears to be nil; Aborting.")
  end
  output = output .. arg[1]
  --[[
  possibilities:
    no slashes ("Applications/AutoTouch.app")
    front slash ("/Applications/AutoTouch.app")
    back slash ("Applications/AutoTouch.app")
    all slashes ("/Applications/AutoTouch.app/")
  
  --]]
  local slash = ""
  if isin("/", arg[1]) and isin("\\", arg[1]) then 
    slash = "/"
    output = output:gsub("\\", "/")
  elseif isin("/", arg[1]) then 
    slash = "/"
  elseif isin("\\", arg[1]) then 
    slash = "\\"
  else
    slash = "/"
  end
  
  if not output:startswith(slash) or not output:startswith("." .. slash) then
    output = slash .. output
  end
  if not output:endswith(slash) then
    output = output .. slash
  end
  
  for i,v in pairs(arg) do
    if i == 1 then 
      -- do nothing, as its already added
    else
      if v:startswith(slash) then
        v = v:gsub(slash, "")
      end
      if not v:endswith(slash) then
        v = v .. slash
      end
      output = output .. v
    end
  end
  return output
end

--- Checks if the given input is a string
function isStr(input)
  return type(input) == "string"
end

--- Checks if the given input is a number
function isNum(number)
  return type(number) == "number"
end

--- Checks if the given input is a table
function isTable(table)
  return type(table) == "table"
end

--- Checks if the given input is a boolean
function isBool(bool)
  return type(bool) == "boolean"
end

--- Checks if the given input is nil
function isNil(x)
  return x == nil
end

--- Checks if the given input is NOT nil
function isNotNil(x)
  return x ~= nil
end

--- A better way to print to the AutoTouch log than using "log" (which doesn't allow more than one parameter)
function print(...)
  local arg = {...}
  result = ""
  for i,v in pairs(arg) do
    result = result .. str(v) .. " "
  end
  log(result)
end

--- Prints formatted table rather than one-lined table
function pprint(tabl)
  if not isTable(tabl) then
    error("[PPrintT] Input must be a single table")
  end
  tabl="\n{\n"..formatted_table(tabl, 1).."}"
  log(tabl)
end

--- Finds the length of the input (for tables, better than Lua's "#", which doesn't take tables with keys into account)
function len(input)
  local counter = 0
  local tInput = {}
  if input == nil then alert("[len] input is nil, returning 0..."); return 0 end
  if type(input) == "number" then 
    input = str(input)
  elseif type(input) == "boolean" then 
    if input then return 1 else return 0 end
  elseif type(input) == "string" then
    tInput = input:split("")
  elseif type(input) == "table" then
    tInput = input
  end
  
  for i,v in pairs(tInput) do
    counter = counter + 1
  end
  return counter
end


-- Time related functions --

--- A more intuative way to sleep than AutoTouch's "usleep"
function pause(time, unit)
  if type(time) ~= "number" then
    alert("The first parameter (time) should be a number")
    return
  elseif (type(unit) ~= "string" and type(unit) ~= nil) then
    alert("The second parameter (unit) should be a string or nil.")
    return
  end
    
  if time == nil and unit == nil then
    usleep(16000)
    return
  end
  
  if time ~= nil and unit == nil then
    ; -- keep input as is
  elseif unit:lower() == "ms" then
    time = time * 1000
  elseif unit:sub(1,1):lower() == "s" then
    time = time * 1000000
  elseif unit:sub(1,1):lower() == "m" then
    time = time * 6000000
  end
    
  usleep(time)
  return
end
  
-- File related functions --

--- Provides a quicker way to get information than going to the F+ help page
function help(func)
  doc = ""
  if func == nil then
    doc = [[ Functions+ by ShirtAndTieler
Contact on reddit: /u/shirtandtieler

If you would like a listing of the functions, run the code: help("functions")
For help with a specific function, run the code: help(<function name>).
Alternatively you can generate the help doc (.txt) by running Functions+.lua and selecting "Generate Help Doc", "Goto help doc site (HTML)", or manually going to the site by visiting the url "tinyurl.com/FunctionsPlusHelp"!]]
  elseif func == "functions" then
    --log all function names
  end
  log(doc)
end

--- Replaces text in a given file, with the option to back the file up
function replaceInFile(file, before, after, limit, backup)
 if file == nil then
  local info = debug.getinfo(1, "S")
  fname = string.sub(info.source, 2)
  file = "/var/mobile/Library/AutoTouch/Scripts/" .. fname
  --log("LOOKING FOR FILE: " .. fname)
 end
  
 if limit == nil then
   limit = 0
 end

 if fileExists(file) == false then
   if isnotin("/AutoTouch/", file) then
     newfile = rootDir() .. file
     return replace(newfile, before, after, backup)
   end
   
   alert("File: " .. file .. "\ndoes not exist (or can't be found)! Can't continue; aborting.")
   return
 end

 if after == nil then
   after = ""
 end

 if backup == nil then 
  backup = true
 end
 if backup == true then
  buLyns = getLines(file)
  f = io.open(file..".bak","w")
  for i,v in pairs(buLyns) do
   f:write(v.."\n")
  end
  f:close()
 end
 
 inFile = io.open(file)
 cont = inFile:read()
 inFile:close()
 cont,n = string.gsub(cont, before, limit, after)
 outFile = io.open(file,"w")
 outFile:write(cont)
 outFile:close()
 return
end

--- Search for a text in the given file
function search(file, query, startSearch, endSearch)
 if file == nil then
  local info = debug.getinfo(1, "S")
  fname = string.sub(info.source, 2)
  file = rootDir() .. fname
 end

 if fileExists(file) == false then
   if isnotin("/AutoTouch/", file) then
     newfile = rootDir() .. file
     return search(newfile, query, startSearch)
   end
   
   alert("File: " .. file .. "\ndoes not exist (or can't be found)! Can't continue; aborting.")
   return
 end

 if query == nil then
   alert("I can't search for nothing! Returning nil.")
   return nil
 end

 if startSearch == nil then 
   startSearch = 1 
 end
 
 inFile = io.open(file)
 cont = inFile:read()
 inFile:close()
 
 results = {}

 locStart = 0
 locEnd = 0
 while locStart ~= nil or startSearch < endSearch do
   locStart,locEnd = string.find(cont, query, startSearch)
   if locStart ~= nil then
     startSearch = locEnd
     results[#results+1]={locStart, locEnd}
   end
 end
 return results
end

--- List the folders and files in the given directory
function getDir(dir)
  lyns = {}
  lyns_idx = 1
  if dir == nil then
    dir = rootDir()
  end
  f = io.popen('ls ' .. dir)
  for name in f:lines() do 
    lyns[lyns_idx] = name
    lyns_idx = lyns_idx + 1
  end
  return lyns
end
 
--- Clears the AutoTouch log (as the only other alternative is doing is manually)
function clear()
 fyl=io.open("/var/mobile/Library/AutoTouch/Library/log.log","w")
 fyl:close()
end

--- Edit the AutoTouch log, formatting it so it's easier to read
function editLog(option, value)
  option = string.lower(option)
  if value == nil then value = "~" end
  if option == 'p' or option == 'prefix' then
    local pattern = "%d+-%d+ %d+:%d+:%d+"
    local fn = '/var/mobile/Library/AutoTouch/Library/log.log'
    fp = io.open( fn, "r" )
    cont = fp:read( "*all" )
    cont = string.gsub( cont, pattern, value )
    fp:close()

    fp = io.open( fn, "w+" )
    fp:write( cont )
    fp:close()
  elseif option:sub(1,1) == 's' or option:sub(1,3) == 'sep' or option == 'seperator' then
  local sepLine = ''
  for i=1,20 do
  sepLine = sepLine .. value .. " "
    end
  log(sepLine)
  end
end
    
--- Get a list of lines in the given file
function getLines(file)
  if file == nil then 
    local info = debug.getinfo(1, "S")
    fname = string.sub(info.source, 2)
    file = rootDir() .. fname
  end
  if not fileExists(file) then 
    error("[getLines] file not found: '" .. file .. "'")
  end
  local file = io.open(file)
  local fLines = {}
  local i = 0
  if file then
    for line in file:lines() do
     i = i + 1
     fLines[i] = line
    end
    file:close()
  else
    error("[getLines] Problem with opening file: '" .. file .. "'")
  end
  return fLines
end

--- Gets a specific line in the given file
function getLine(file, lineNum)
  local fLines = getLines(file)
  return fLines[lineNum]
end

--- Checks whether the given file exists 
function fileExists(file)
  local f = io.open(file, "rb")
  if f then f:close(); end
  return f ~= nil
end

--- Copies a file to a specific path, with the option to overwrite any files that exist with the same name
function copyFile(srcFilePath, dstFilePath, overwrite)
  
  --check if first two params are nil
  if srcFilePath == nil then
    alert("Problem with parameter #1: Must not be nil")
    assert(srcFilePath ~= nil)
  elseif dstFilePath == nil then
    alert("Problem with parameter #2: Must not be nil")
    assert(dstFilePath ~= nil)
  end
  
  --default overwrite to false
  if overwrite == nil then overwrite = false end
  
  --check if src file exists
  if not fileExists(srcFilePath) then
    alert("Could not find a file @ " .. srcFilePath)
    assert(fileExists(srcFilePath))
  end
  
  --if theres a file with the same name as the dst and overwrite is false then fail
  if fileExists(dstFilePath) and overwrite == false then
    alert("File already exists and param #3 (overwrite) is either not set or set to false")
    assert(overwrite == true)
  end
  
  local rfh = io.open(srcFilePath, "rb" )
  local wfh = io.open(dstFilePath, "wb" )
  
  if not (wfh) then
  error("writeFileName open error!")
  return
  else
  local data = rfh:read( "*a" )
  if not (data) then
    error("Could not read file!")
        return
  elseif not (wfh:write(data)) then
    error("Could not write to file!")
        return
  end
  end

  --clean up file handles
  rfh:close()
  wfh:close()
  return
end


function isFullPath(fileName)
  -- check if full path
end

--- Gets the size of the given file in bits
function getFileSize(fileName)
  -- default to autotouch directory if not full path
  local file = io.open(fileName)
  local size = -1
  if file ~= nil then
    size = file:seek("end")
    file:close()
  end
  return size
end
      
-- Action functions --

--- Runs a terminal command and returns the results
function exe(cmd)
  local c = io.popen(cmd)
  local res = c:read("*a")
  c:close()
  return res
end

--[[
-- REMVD ss func (below) b/c I dont think the need is really there 
--		(but if it is, I'll fix it - as it's currently reporting the "problem with ss function" error)

function ss(path, name, region)
  if path == nil then path = rootDir() end
  if fileExists(path) == false then
    alert("[Error] The folder: \n" .. path .. "\n could not be found or doesn't exist. Aborting :(")
    return
  end

  local srcpath=rootDir()..name
  local dstpath=''
  if string.sub(path,-1) == "/" then
    dstpath=path..name
  else
    dstpath=path.."/"..name
  end

  if string.sub(name,-4) ~= ".bmp" then
    name = name .. ".bmp"
  end

  screenshot(name,region)
  local result = copyFile(srcpath,dstpath,true)
  if result then
  os.remove(srcpath)
    return
  else
     alert("Problem with ss function :/")
     return
  end
end
--]]

-- Helper funcs for drawing circle

function getCircleXY(origin, r, angle)
 if #origin < 2 then 
  error("param 1 needs to be a table of x, y coords") 
 end
 local originX = origin[1]
 local originY = origin[2]
 angle = deg2rad(angle)
 local x = originX + (r * math.cos(angle))
 x = round(x, 2)
 local y = originY + (r * math.sin(angle))
 y = round(y, 2)
 return x, y
end

function round(num, places)
 local mult = 10^(places or 0)
 return math.floor(num * mult + 0.5) / mult
end

function deg2rad(deg)
 return deg*math.pi/180
end

--- Uses AutoTouch's touchDown/touchMove/touchUp functions to draw a shape on the screen
function draw(shape, size, centerPos)
  shape = shape:lower()
  shapes = {"circle","triangle","square"}
  canDraw = 0
  for i,v in pairs(shapes) do
   if shape == v then
     canDraw = 1
   end
  end
  if canDraw == 0 then
    error("I can not draw a " .. shape)
  end
  points = getPoints(shape, size, centerPos)
  print(points)
  touchDown(0, points[1][1], points[1][2])
  usleep(60000)
  for _,pt in pairs(points) do
    touchMove(0, pt[1], pt[2])
    usleep(32500)
  end
  touchUp(0, points[#points][1], points[#points][2])
end

--- Gets a table of points in the given shape at the given center coordiate and of the given size
function getPoints(shape, size, center)
  points = {}
  tl = {center[1]-(size/2), center[2]-(size/2)}
  tm = {center[1]		  , center[2]-(size/2)}
  tr = {center[1]+(size/2), center[2]-(size/2)}
  
  ml = {center[1]-(size/2), center[2]}
  mr = {center[1]+(size/2), center[2]}
  
  bl = {center[1]-(size/2), center[2]+(size/2)}
  bm = {center[1]		  , center[2]+(size/2)}
  br = {center[1]+(size/2), center[2]+(size/2)}
  
  if shape == "square" then
    table.insert(points, bl)
    points = merge(points, getInbetweenPoints(bl, tl, 10))
    table.insert(points, tl)
    points = merge(points, getInbetweenPoints(tl, tr, 10))
    table.insert(points, tr)
    points = merge(points, getInbetweenPoints(tr, br, 10))
    table.insert(points, br)
    points = merge(points, getInbetweenPoints(br, bl, 10))
    table.insert(points, bl)
    points = merge(points, getInbetweenPoints(bl, tl, 10))
  elseif shape == "triangle" then
    table.insert(points, bl)
    points = merge(points, getInbetweenPoints(bl, tm, 10))
    table.insert(points, tm)
    points = merge(points, getInbetweenPoints(tm, br, 10))
    table.insert(points, br)
    points = merge(points, getInbetweenPoints(br, bl, 10))
    table.insert(points, bl)
    points = merge(points, getInbetweenPoints(bl, tm, 10))
  elseif shape == "circle" then
    for a=0,360,360/20 do
      local scaleX = math.cos(math.rad(a))
      local scaleY = math.sin(math.rad(a))
      local x = round(center[1]+((size/2)*scaleX), 0)
      local y = round(center[2]+((size/2)*scaleY), 0)
      table.insert(points, {x,y})
    end
    table.insert(points, points[1])
    table.insert(points, points[2])
    table.insert(points, points[3])
  end
  return points
end

--- Return a table of coordinates between two points, split up a given number of times
function getInbetweenPoints(point1, point2, inbetween)
  local pts = {}
  if inbetween>100 then
    inbetween = 100
  end
  local xDiff = point2[1]-point1[1]
  local yDiff = point2[2]-point1[2]
  for i=0,100,inbetween do
    local percent = i/100
    local newX = point1[1] + (xDiff*percent)
    local newY = point1[2] + (yDiff*percent)
    table.insert(pts, {newX, newY})
  end
  return pts
end
    
--- Scrolls the screen in a certain direction at some speed, with the option to repeat the scrolling 
function scroll(dir, speed, repeats)
 if repeats <= 0 then
   return
 end

 wid,hyt = getScreenSize()
  
 if speed == nil then speed = 3
 elseif speed > 5 then speed = 5
 elseif speed < 1 then speed = 1
 end
  
 if dir:sub(1,1):lower() == "d" then
  dir = "d"
 elseif dir:sub(1,1):lower() == "u" then
  dir = "u"
 elseif dir:sub(1,1):lower() == "l" then
  dir = "l"
 elseif dir:sub(1,1):lower() == "r" then
  dir = "r"
 else 
  alert("Cant parse your inputted direction of: " .. dir .. ". Aborting.")
  return
 end
  

  startX = wid/2; startY = hyt/2;
  finX = wid/2; finY = hyt/2;
  step = 0;

  if dir == "d" then
    startY = hyt * 0.9
    finY = hyt * 0.1
    step = -1
  elseif dir == "u" then
    startY = hyt * 0.1
    finY = hyt * 0.9
    step = 1
  elseif dir == "l" then
    startX = wid * 0.1
    finX = wid * 0.9
    step = 1
  else
    startX = wid * 0.9
    finX = wid * 0.1
    step = -1
  end
 
  local modSpeed = speed^2
  step = step * modSpeed
 
  touchDown(0, startX, startY)
  usleep(60000)
  if dir == "u" or dir == "d" then
    for p=startY, finY, step do
      touchMove(0, startX, p)
      usleep(16000)
    end
  else
    for p=startX, finX, step do
      touchMove(0, p, startY)
      usleep(16000)
    end
  end
  touchUp(0, finX, finY)
  if repeats > 1 then
    usleep(250000)
    scroll(dir, speed, repeats-1)
  end
end

function getRampedPoints(speed, vertex)
  -- get points starting from near 0 speed, continuing/ramping up to the vertex, then going back down to 0
  local pts = {}
  -- equation = y=-0.1x^2+v
  -- x intercepts aka bounds at +- sqrt(v*10)
  leftBound = -math.sqrt(v*10)
  riteBound = leftBound * -1
  
end


-- Uploading functions!! --
--- Create a dialog with a list of options the user can perform, which shows up after running the script
function askAction()
  local label = {type=CONTROLLER_TYPE.LABEL, text="Welcome to Functions+! Please choose what youd like to do from the selection below!"}
  local picker = {type=CONTROLLER_TYPE.PICKER, title="", key="action", value="Install", options={"Install", "Uninstall","Reinstall","Check if installed", "Generate Help Doc (Sort: A-Z)", "Generate Help Doc (Sort: Type)", "Goto help doc site (HTML)"}}
  local vSwitch = {type=CONTROLLER_TYPE.SWITCH, title="Verbose mode:", key="VSwitch", value=0}
  control={label, picker, vSwitch}
  dialog(control, false)
  
  local vMode = false
  if vSwitch.value == 1 then
    vMode = true
  end

  if picker.value == "Install" then
    return 1, vMode
  elseif picker.value == "Reinstall" then
    return 1.1, vMode
  --[[
  elseif picker.value == "Custom Install" then 
    alert("Custom Install not yet implemented :(")
    return 1.5, vMode
  --]]
  elseif picker.value == "Uninstall" then 
    return -1, vMode
  elseif picker.value == "Check if installed" then
    return 2, vMode
  elseif picker.value == "Generate Help File (Sort: A-Z)" then
    return 3.1, vMode
  elseif picker.value == "Generate Help File (Sort: Type)" then
    return 3.2, vMode
  elseif picker.value == "Goto help doc site (HTML)" then
    return 3.0, vMode
  else
    alert("Unknown input...")
    return 0, vMode
  end
end


function checkPermissions(fylLoc)
  local fCheck = io.open(fylLoc,"a")
  if fCheck == nil then
    return "Denied"
  else
    fCheck:close()
    return "Granted"
  end
end


function permissionsRewrite(eFyl)
  if checkPermissions(eFyl) == "Denied" then
    local eLyns = getLines(eFyl)
    os.remove(eFyl)
    local eFylNew = io.open(eFyl,"w")
  for i,v in ipairs(eLyns) do
      eFylNew:write(v)
      eFylNew:write("\n");
    end
    eFylNew:close()
  end
end


function isFuncsPlusAdded()
  local eFyl = "/Applications/AutoTouch.app/Extensions.lua"
  local extnFile = assert(io.open(eFyl))
  local extnCont = extnFile:read("*all")
  extnFile:close()
  
  if isin("Functions+", extnCont) and isin("scroll", extnCont) and (getFileSize(eFyl) > getFileSize(eFyl..".bak")) then
      -- scroll is just a random function that I used to test it
    return true
  else
    return false
  end
end
  

function install(v)
  local eFyl = "/Applications/AutoTouch.app/Extensions.lua"
  if v then log("\nInstall starting....") end
  
  if isFuncsPlusAdded() then
    local label = {type=CONTROLLER_TYPE.LABEL, text="Functions+ has already been added!"}
    local reins = {type=CONTROLLER_TYPE.SWITCH, title="Would you like to reinstall it?", key="", value=0}
    control={label, reins}
    dialog(control, false)
    if reins.value == 0 then
      if v then log("F+ already installed and user selected to NOT reinstall. Ending.") end
      return 1
    else
      if v then log("F+ already installed and user selected to reinstall") end
      uninstall(v)
    end
  end
  
  copyFile(eFyl, eFyl..".bak", true)
  if fileExists(eFyl..".bak") and v then
    log("Made a backup (.bak) of the Extensions file.")
  elseif not fileExists(eFyl..".bak") then
    error("Issue with making a backup copy during installation.")
  end

  local metaFile = assert(io.open(rootDir() .. "Functions+.lua"))
  local metaLyns = getLines(rootDir() .. "Functions+.lua")
  metaFile:close()
  
  if v then 
    log("Read Functions+ file successfully.")
    log("Number of characters in portioned Functions+ script: " .. len(metaLyns))
    log("#### PREVIEW ####")
    for indx,val in pairs(preview()) do 
      log(val)
    end
    log("#################")
  end
  
  
  local header = "----------Functions+----------"
  local footer = "------------------------------"
  
  eFyl = "/Applications/AutoTouch.app/Extensions.lua"
  permissionsRewrite(eFyl)
  local extnFile = assert(io.open(eFyl, "a"))
  extnFile:write("\n" .. header .. "\n")
  pass=false
  lynsWritten = 0
  charWritten = 0
  for indx,val in pairs(metaLyns) do
    if isin("-- Uploading functions!! --", val) then
      pass=true
    end
    if not pass then 
      extnFile:write(val)
      extnFile:write("\n")
      lynsWritten = lynsWritten + 1
      charWritten = charWritten + #val
    end
  end
  extnFile:write("\n" .. footer .. "\n")
  extnFile:close()
  
  if v then 
    log("Finished installation successfully!\nWrote " .. lynsWritten .. " lines and " .. charWritten .. " characters.\n") 
  end
  return 1
end


function customInstall()
  local label = {type=CONTROLLER_TYPE.LABEL, text="Toggle the functions that you'd like to install!"}
  alert("Not implemented.")
end


function uninstall(v)
  local eFyl = "/Applications/AutoTouch.app/Extensions.lua"
  if v then log("\nUninstall starting....") end
  if not fileExists(eFyl .. ".bak") then
    alert("Cannot find backup file with saved backup of original file.\nEither you deleted it or Functions+ is not installed. Aborting uninstall.\n\n(If you deleted it or it's not there, contact /u/shirtandtieler for a copy)")
    return
  end
  
  local oldExtSize = getFileSize("/Applications/AutoTouch.app/Extensions.lua")
  copyFile(eFyl..".bak", eFyl, true)
  if v then log("Replaced Extensions.lua with the backup copy.") end
  usleep(16000)
  
  local extExists = fileExists("/Applications/AutoTouch.app/Extensions.lua")
  local newExtSize = -1
  if extExists then
    newExtSize = getFileSize("/Applications/AutoTouch.app/Extensions.lua")
  end
  
  -- check to make sure it worked
  if fileExists("/Applications/AutoTouch.app/Extensions.lua") and v then
    log("Uninstall complete!\n") 
  elseif not (fileExists("/Applications/AutoTouch.app/Extensions.lua")) or (getFileSize(eFyl) < getFileSize(eFyl..".bak")) then
    log("Uninstall failed :(")
    alert("Uninstall failed :( \nOld extensions file size = " .. str(oldExtSize) .. " and new ext file size = " .. str(newExtSize) .. "\nDoes extensions.lua exist? " .. str(extExists))
  end
  
  if v then log("Uninstall info: old extensions file size = " .. str(oldExtSize) .. " and new ext file size = " .. str(newExtSize)) end
end

function test(v)
  if not v then
    return isFuncsPlusAdded()
  end
  clear()
  -- test color conversions
  local hVal = rgbToHex(150, 25, 220)
  log("hex = " .. hVal)
  local iVal = rgbToInt(150, 25, 220)
  log("int = " .. str(iVal))
  local r,g,b = hexToRgb(hVal)
  log("rgb = " .. str(type(r)) .. ", " .. r .. "," .. g .. "," .. b)
  local name = intToName(iVal)
  log("name = " .. name)
  
  -- test string manipulation
  local testInput = " hello from the  other side  ! "
  local testSplit = testInput:split(" ")
  local testWith1 = testInput:startswith(" h")
  local testWith2 = testInput:endswith("! ")
  local testReslt = testInput:replace("  ", " poop ", 1)
  local testStrip = testInput:trim()
  local test4mat  = format("My name is {}, I am {} years old, and I have a dog named {}", "Tyler", "23", "Daisy") -- not formatting...
  print(testInput)
  print(testSplit)
  print(str(testWith1) .. " , " .. str(testWith2))
  print(testReslt)
  print(testStrip)
  print(test4mat)
  
  local testTabl1 = {"alpha", "bet", "card", "dog"}
  local testTabl2 = {"dog", "ear"}
  local testTabl3 = {["a"]=1, ["b"]=3, ["c"]=3}
  local testTabl4 = {["b"]=2, "frog"}
  local testTablM1 = merge(testTabl1, testTabl2)
  local testTablM2 = merge(testTabl1, testTabl3)
  local testTablM3 = merge(testTabl1, testTabl4)
  local testTablM4 = merge(testTabl2, testTabl3)
  local testTablM5 = merge(testTabl2, testTabl4)
  local testTablM6 = merge(testTabl3, testTabl4)
  log("1 + 2 = ")
  print(testTablM1)
  log("1 + 3 = ")
  print(testTablM2)
  log("1 + 4 = ")
  print(testTablM3)
  log("2 + 3 = ")
  print(testTablM4)
  log("2 + 4 = ")
  print(testTablM5)
  log("3 + 4 = ")
  print(testTablM6)
  
  
  -- action functions
  -- REMVD b/c <see init of function>
  --[[
  ss("/var/mobile/Media/Downloads", "testImage.bmp", nil)
  --]]
  
  
  -- test table manipulation
  -- REMVD b/c table.concat exists...
  --[[
  local testTable = {"a",1,"b",2,"d",4}
  local conjoined = join(testTable, " <> ")
  print(conjoined)
  --]]
  
  -- test path-join
  local path2fyl  = join("var/mobile/DCIM", "Photos", "Day0.jpg")
  print("path2fyl = " .. str(path2fyl))
  draw("circle", 200, {360, 530})
  
  return true
end

function genHelp(sort, v)
  if v then log("Generating help file sorted by " .. sort) end
end

function gotoHelp(v)
  if v then log("Opening safari...") end
  local start = os.clock()
  local timeout = os.time()-start
  appRun("com.apple.mobilesafari");
  usleep(2000000)
  while (appState("com.apple.mobilesafari") ~= "ACTIVATED") do
    usleep(250000)
    timeout = os.clock()-start
    if timeout >= 10000000 then
      error("Timeout error - Could not open safari; aborting.")
    end
  end 
  log(os.clock()-start)
  if v then log("Safari opened successfully") end
  local cb = clipText()
  copyText("http://tinyurl.com/FunctionsPlusHelp")
  if v then log("Setting clipboard to: " .. clipText()) end
  alert("Please paste the url currently in your clipboard. Clipboard state will be reverted to previous item in 10 seconds.")
  if v then log("Giving the user 10 seconds to paste the link") end
  usleep(10000000)
  copyText(cb)
  if v then log("Clipboard reverted to: " .. cb) end
end



function preview()
  local p = {}
  local i = 1
  lyns = getLines("/var/mobile/Library/AutoTouch/Scripts/Functions+.lua")
  for v = 1,5 do
    p[i] = lyns[v]
    i = i + 1
  end
  p[i]="........"
  i = i + 1
  for vv = #lyns-5, #lyns-1 do
    p[i] = lyns[vv]
    i = i + 1
  end
  return p
end

function reinstall(v)
  uninstall(v)
  usleep(500000)
  install(v)
end

-- See what the user wants to do, and then do it!
a,v = askAction()


if a == 1 then
  install(v)
elseif a == 1.1 then
  reinstall(v)
--[[
elseif a == 1.5 then
  ;
--]]
elseif a == 2 then
  testResult = test(v)
  if testResult then alert("Installed and working!") else alert("Issues with installation…") end
elseif a == -1 then
  uninstall(v)
elseif a == 3.1 then
  genHelp("alpha", v)
elseif a == 3.2 then
  genHelp("type", v)
elseif a == 3.0 then
  gotoHelp(v)
else
  alert("Unknown answer...(How did you do this??)")
end