local json = require("dkjson")
require("util")
require("stridx")

local function both_ways(t)
  local ks = {}
  for k,v in pairs(t) do ks[#ks+1] = k end
  for _,k in ipairs(ks) do
    assert(t[t[k]] == nil)
    --assert(false)
    t[t[k]] = k
  end
  return t
end

local all_rulings = json.decode(file_contents("rulings.json"))
local name_to_rulings = {}
for _,rulings_sheet in pairs(all_rulings) do
  for _,ruling in pairs(rulings_sheet) do
    if not ruling.card then print(json.encode(ruling)) end
    if name_to_rulings[ruling.card] == nil then name_to_rulings[ruling.card] = {} end
    local t = name_to_rulings[ruling.card]
    if ruling.ruling then
      assert(type(ruling.date) == "string", ruling.ruling)
      t[#t+1] = ruling
    end
  end
end

local short_colors = {w="White", u="Blue", b="Black", r="Red", g="Green", p="Purple", n="Neutral"}
local short_specs = {dp="Discipline", ni="Ninjutsu", st="Strength",
                     lw="Law",        pc="Peace",    tr="Truth",
                     de="Demonology", di="Disease",  ne="Necromancy",
                     an="Anarchy",    bl="Blood",    fr="Fire",
                     ba="Balance",    fe="Feral",    gr="Growth",
                     pa="Past",       pr="Present",  fu="Future",
                     bs="Bashing",    fn="Finesse",}
short_colors = both_ways(short_colors)
short_specs = both_ways(short_specs)
canonical_url_to_card = {}
local codex_cards = {}
local filenames = {"white", "blue", "black", "red", "green", "purple", "neutral", "heroes"}
local color_to_specs = {White={"Discipline","Ninjutsu","Strength"},
                  Blue={"Law","Peace","Truth"},
                  Black={"Demonology","Disease","Necromancy"},
                  Red={"Anarchy","Blood","Fire"},
                  Green={"Balance","Feral","Growth"},
                  Purple={"Past","Present","Future"},
                  Neutral={"Bashing","Finesse"}}

local used_names = {}
for _,name in pairs(filenames) do
  local cards = json.decode(file_contents(name..".json"))
  for _,card in pairs(cards) do
    if card.sirlins_filename and not used_names[card.name] then
      codex_cards[#codex_cards+1] = card
      used_names[card.name] = true
    end
  end
end

for color, specs in pairs(color_to_specs) do
  codex_cards[#codex_cards+1] = {type="Color", name=color, color=color, fake=true}
  for _, spec in pairs(specs) do
    codex_cards[#codex_cards+1] = {type="Spec", name=spec, color=color, spec=spec, fake=true}
  end
end

for _,card in pairs(codex_cards) do
  card.url = "/" .. card.color:lower()
  if card.spec then
    card.url = card.url .. "/" .. card.spec:lower()
  end
  if not card.fake then
    card.url = card.url .. "/" .. card.name:lower():gsub("[^%a]+", "_")
    card.rulings = name_to_rulings[card.name] or {}
  end
end

circled_digits = {[0]="⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
                           "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳",}

function levenshtein_distance(s, t)
  s,t = procat(s), procat(t)
  local m,n = #s, #t
  local d = {}
  for i=0,m do
    d[i] = {}
    d[i][0] = i
  end
  for j=1,n do
    d[0][j] = j
  end
  for j=1,n do
    for i=1,m do
      if s[i] == t[j] then
        d[i][j] = d[i-1][j-1]
      else
        d[i][j] = math.min(d[i-1][j]+1,
                           d[i][j-1]+1, d[i-1][j-1]+1)
      end
    end
  end
  return d[m][n]
end

function card_to_int_for_sort(card)
  local ret = 0
  if card.type == "Hero" then
    ret = 0
  elseif card.type == "Unit" or card.type == "Legendary Unit" then
    ret = 100
  elseif card.type == "Building" or card.type == "Legendary Building" then
    ret = 200
  elseif card.type == "Upgrade" or card.type == "Legendary Upgrade" then
    ret = 300
  elseif card.type == "Ultimate Spell" or card.type == "Ultimate Ongoing Spell" then
    ret = 500
  else
    ret = 400
  end
  ret = ret + card.cost
  if card.starting_zone == "deck" or card.starting_zone == "command" then
    return ret
  elseif card.starting_zone == "trash" then
    return 9000 + ret
  elseif card.tech_level == nil then
    return 1000 + ret
  else
    return card.tech_level * 1000 + 1000 + ret
  end
end

function card_name_for_list(card)
  return card.name
end

function compare_cards(a,b)
  if (a.spec or b.spec) and a.spec ~= b.spec then
    if b.spec == "Future" then return true end
    if a.spec == "Future" then return false end
    return (a.spec or "Aaaaaaa") < (b.spec or "Aaaaaaa")
  end
  local na, nb = card_to_int_for_sort(a), card_to_int_for_sort(b)
  if na ~= nb then
    return na < nb
  end
  return a.name < b.name
end

function format_color(color)
  local deck = {}
  for _, card in pairs(codex_cards) do
    if card.starting_zone == "deck" and card.color == color then
      deck[#deck + 1] = card
    end
  end
  table.sort(deck, compare_cards)
  local card_names = map(card_name_for_list, deck)
  local ret = color .. ": "
  ret = ret .. table.concat(color_to_specs[color], ", ") .. ". "
  ret = ret .. "Starting deck: "
  ret = ret .. table.concat(card_names, ", ") .. "."
  return ret
end

function format_spec(spec)
  local deck = {}
  for _, card in pairs(codex_cards) do
    if card.spec == spec then
      deck[#deck + 1] = card
    end
  end
  table.sort(deck, compare_cards)
  local card_names = map(card_name_for_list, deck)
  local ret = spec .. ": "
  ret = ret .. table.concat(card_names, ", ") .. "."
  return ret
end

function format_hero(card)
  local str = card.name .. " - "
  str = str .. card.spec .. " Hero - " .. card.subtype .. " "
  str = str .. "(" .. card.cost .. "): "
  str = str .. "1: " .. card.ATK_1 .. "/" .. card.HP_1 .. " "
  if card.base_text_1 then
    str = str .. card.base_text_1 .. " "
  end
  if card.base_text_2 then
    str = str .. card.base_text_2 .. " "
  end
  str = str .. "/ " .. card.mid_level .. ": "
  str = str .. card.ATK_2 .. "/" .. card.HP_2 .. " "
  if card.mid_text_1 then
    str = str .. card.mid_text_1 .. " "
  end
  if card.mid_text_2 then
    str = str .. card.mid_text_2 .. " "
  end
  str = str .. "/ " .. card.max_level .. ": "
  str = str .. card.ATK_3 .. "/" .. card.HP_3 .. " "
  if card.max_text_1 then
    str = str .. card.max_text_1 .. " "
  end
  if card.max_text_2 then
    str = str .. card.max_text_2 .. " "
  end
  return str
end

function format_card(card)
  if card.type == "Hero" then return format_hero(card) end
  if card.type == "Color" then return format_color(card.name) end
  if card.type == "Spec" then return format_spec(card.name) end
  local str = card.name .. " - "
  if card.spec then
    str = str .. card.spec
  else
    str = str .. card.color
  end
  if card.tech_level then
    str = str .. " Tech ".. (({[0]="0", "I", "II", "III"})[card.tech_level])
  end
  str = str .. " " .. card.type
  if card.subtype then
    str = str .. " - " .. card.subtype
  end
  if card.target_icon then
    str = str .. " ◎ "
  end
  if card.cost then
    --str = str .. " " .. circled_digits[card.cost] .. " :"
    str = str .. " (" .. card.cost .. "):"
  end
  if card.ATK then
    str = str .. " " .. card.ATK .. "/" .. card.HP
  elseif card.HP then
    str = str .. " " .. card.HP .. "HP"
  end
  local rules_text = ""
  for i=1,4 do
    if card["rules_text_"..i] then
      rules_text = rules_text .. " " .. card["rules_text_"..i]
    end
  end
  if rules_text ~= "" then
    if card.HP then
      str = str .. " -"
    end
    str = str .. rules_text
  end
  return str
end

function format_didyoumean(cards)
  local str = "Did you mean "
  if #cards == 2 then
    str = str .. cards[1].name .. " or " .. cards[2].name .. "?"
    return str
  end
  for i=1,#cards-1 do
    str = str .. cards[i].name .. ", "
  end
  str = str .. "or " .. cards[#cards].name .. "?"
  return str
end

function format_typeline(card)
  local str = card.color
  if card.spec then
    str = str .. " " ..card.spec
  end
  if card.tech_level then
    str = str .. " Tech ".. (({[0]="0", "I", "II", "III"})[card.tech_level])
  end
  str = str .. " " .. card.type
  if card.subtype then
    str = str .. " — " .. card.subtype
  end
  if card.target_icon then
    str = str .. " ◎ "
  end
  str = str.."<br>"
  str = str..circled_digits[card.cost]
  if card.ATK then
    str = str .. " " .. card.ATK .. "/" .. card.HP
  elseif card.HP then
    str = str .. " " .. card.HP .. "HP"
  end
  return str
end

function format_rules_text(card)
  if card.type == "Hero" then
    local str = "LEVEL 1-" .. (card.mid_level-1) .. "<br>"
    str = str .. card.ATK_1 .. "/" .. card.HP_1 .. "<br>"
    if card.base_text_1 then str = str .. card.base_text_1 .. "<br>" end
    if card.base_text_2 then str = str .. card.base_text_2 .. "<br>" end
    str = str .. "<br>LEVEL " .. (card.mid_level) .. "-" .. (card.max_level-1) .. "<br>"
    str = str .. card.ATK_2 .. "/" .. card.HP_2 .. "<br>"
    if card.mid_text_1 then str = str .. card.mid_text_1 .. "<br>" end
    if card.mid_text_2 then str = str .. card.mid_text_2 .. "<br>" end
    str = str .. "<br>LEVEL " .. (card.max_level) .. "<br>"
    str = str .. card.ATK_3 .. "/" .. card.HP_3 .. "<br>"
    if card.max_text_1 then str = str .. card.max_text_1 .. "<br>" end
    if card.max_text_2 then str = str .. card.max_text_2 .. "<br>" end
    return str
  else
    local str = card.rules_text_1 or ""
    for i=2,4 do
      if card["rules_text_"..i] then
        str = str.."<br><br>"..card["rules_text_"..i]
      end
    end
    return str
  end
end

function format_rulings(card)
  local ret = {"<ul>"}
  for _,ruling in pairs(card.rulings) do
    ret[#ret+1] = "<li><b>"
    ret[#ret+1] = ruling.date:gsub("T.*", "")
    ret[#ret+1] = ": "
    ret[#ret+1] = ruling.ruling
    ret[#ret+1] = "</li>"
  end
  ret[#ret+1] = "</ul>"
  return table.concat(ret)
end

function format_card_list(spec)
  local ok = function(card) return card.color == spec.color end
  if spec.spec then
    ok = function(card) return card.spec == spec.spec end
  end
  local cards = {}
  for _,card in pairs(codex_cards) do
    if ok(card) and not card.fake then
      cards[#cards+1] = card
    end
  end
  table.sort(cards, compare_cards)
  local ret = {}
  for _,card in ipairs(cards) do
    ret[#ret+1] = [[<a href="]]..card.url..[["><img src="/static/]]..card.sirlins_filename..
        [[" alt="]]..card.name..[[" width="330" height="450"></a>]]
  end
  return table.concat(ret)
end

function cardlist(card)
return [[<html lang="en"><head>
  
<meta charset="UTF-8">  
  <title>]]..card.name..[[</title>
  <style type="text/css">
   <!--
    body {background: #fafafa url(http://magiccards.info/images/bg.gif) repeat-x;margin: 1em 1.5em;}
    body,td,th {font: 0.9em/1.2em Verdana;color: #444;}
    th {text-align: left; font-weight: bold;}
    p {margin: 0.5em 0;}
    a {color: #4666BC;}
    a:hover {color: #333;background-color: #ff0;}
    a:active {text-decoration: none;}
    a:visited {color: #283C71;}
    p.ctext {background-color: #fff;padding: 4px;}
    p.otext {background-color: #fff;padding: 4px;}
    div.oo {margin-left: 0em; padding: 0.5em 0 0 0; border: 1px solid #bbb; font-size: 75%;line-height: 100%;}
    div.oo span {padding: 4px;}
    div.oo p {margin: 0.5em 0 0 0;}
    tr.odd {background-color: #e0e0e0;}
    tr.even {background-color: #fafafa;}
    span.missing {color: #aaa;font-weight:bold;font-style:italic;}
    dt {font-weight: bold; font-size: 110%; margin: 1em 0 0.5em 0;}
    table#nav {font-size: 90%;}
    ul {padding-left: 2em;}
    .flag {vertical-align:-10%;}
    .flag2 {vertical-align:-20%;}
    .addition {color: red;}
    a.ruleanchor {text-decoration: none; color: #E8DA58;}
    li:target {background: #FAF7DC;}
    -->
  </style>
  
  
</head>
<body>
      ]]..format_card_list(card)..[[
</body></html>]] 
end

function ass(card)
if card.type == "Spec" or card.type == "Color" then
  return cardlist(card)
end
return [[<html lang="en"><head>
  
<meta charset="UTF-8">  
  <title>]]..card.name..[[</title>
  <style type="text/css">
   <!--
    body {background: #fafafa url(http://magiccards.info/images/bg.gif) repeat-x;margin: 1em 1.5em;}
    body,td,th {font: 0.9em/1.2em Verdana;color: #444;}
    th {text-align: left; font-weight: bold;}
    p {margin: 0.5em 0;}
    a {color: #4666BC;}
    a:hover {color: #333;background-color: #ff0;}
    a:active {text-decoration: none;}
    a:visited {color: #283C71;}
    p.ctext {background-color: #fff;padding: 4px;}
    p.otext {background-color: #fff;padding: 4px;}
    div.oo {margin-left: 0em; padding: 0.5em 0 0 0; border: 1px solid #bbb; font-size: 75%;line-height: 100%;}
    div.oo span {padding: 4px;}
    div.oo p {margin: 0.5em 0 0 0;}
    tr.odd {background-color: #e0e0e0;}
    tr.even {background-color: #fafafa;}
    span.missing {color: #aaa;font-weight:bold;font-style:italic;}
    dt {font-weight: bold; font-size: 110%; margin: 1em 0 0.5em 0;}
    table#nav {font-size: 90%;}
    ul {padding-left: 2em;}
    .flag {vertical-align:-10%;}
    .flag2 {vertical-align:-20%;}
    .addition {color: red;}
    a.ruleanchor {text-decoration: none; color: #E8DA58;}
    li:target {background: #FAF7DC;}
    -->
  </style>
  
  
</head>
<body>


<table border="0" cellpadding="0" cellspacing="0" width="100%">
<tbody><tr>
  <td align="left" width="35%">
    
    
    ← <a href="]]..card.url..[[">]]..card.name..[[</a>
    
  </td>
  <td align="center" width="30%">
    <a href="]]..card.url..[[">]]..card.name..[[</a>
  </td>
  <td align="right" width="35%">
    
    
    <a href="]]..card.url..[[">]]..card.name..[[</a> →
    
  </td>
</tr>
</tbody></table>
<hr>

<table border="0" cellpadding="0" cellspacing="0" width="100%" align="center" style="margin: 0 0 0.5em 0;">
  <tbody><tr>
    <td width="330" valign="top">
      <img src="/static/]]..card.sirlins_filename..[[" alt="]]..card.name..[[" width="330" height="450">
    </td>
    <td valign="top" style="padding: 0.5em;" width="100%">
      <span style="font-size: 1.5em;">
        <a href="]]..card.url..[[">]]..card.name..[[</a>
          
      </span>
      
      
        <p>]]..format_typeline(card)..[[</p>
        <p class="ctext"><b>]]..format_rules_text(card)..[[</b></p>
      

      <p><i></i></p>
      <p><b>Card Rulings</b></p>]]..format_rulings(card)..[[
      <ul>
      </ul>
    </td>
  </tr>
</tbody></table>
</body></html>]] end

function handle_codex(self)
  local name = self.params.cardname
  local color = self.params.color or ""
  local spec = self.params.spec
  local path = self.req.parsed_url.path
  for _,card in pairs(codex_cards) do
    if card.name:gsub('%W',''):lower() == name then
      if card.url == path then
        return ass(card)
      else
        print(json.encode(card))
        print("Redirecting to "..card.name.." "..card.url)
        return { redirect_to = self:build_url(card.url) }
      end
    end
  end
  local bests = {}
  local best_score = 99999999
  for _,card in pairs(codex_cards) do
    local this_score = levenshtein_distance(card.name:gsub('%W',''):lower(), name)
    if this_score < best_score then
      best_score = this_score
      bests = {card}
    elseif this_score == best_score then
      bests[#bests+1] = card
    end
  end
  if #bests == 1 or true then
    local card = bests[1]
    if card.url == path then
      return ass(card)
    else
      print(json.encode(card))
      print("Redirecting to "..card.name.." "..card.url)
      return { redirect_to = self:build_url(card.url) }
    end
  end
  return format_didyoumean(bests)
end

return {
short_colors = short_colors,
short_specs = short_specs,
cards = codex_cards,
color_to_specs = color_to_specs,
format_card = format_card,
levenshtein_distance = levenshtein_distance,
handle_codex = handle_codex,
}