-- ╔═══════════════════════════════════════════════════════════════╗
-- ║     Grow A Garden 2 — Schedule & Prediction                  ║
-- ║     Restock Timers · Weather Queue · Auto-Edit Discord       ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local lp               = Players.LocalPlayer
local pg               = lp:WaitForChild("PlayerGui")

if pg:FindFirstChild("GAG2Schedule") then pg:FindFirstChild("GAG2Schedule"):Destroy() end

-- ══════════════════════════════════════════════
-- CONFIG — fill in your role ID if you want pings
-- Leave as "" for no ping
-- ══════════════════════════════════════════════
local PING_ROLE = ""  -- e.g. "<@&123456789>"

-- ── Permanent storage ─────────────────────────────────────────────────────────
local WEBHOOK_FILE    = "gag2_schedule_webhook.txt"
local MSG_ID_FILE     = "gag2_schedule_msgid.txt"
local CHECKS_FILE     = "gag2_schedule_checks.txt"
local WEBHOOK_URL     = ""
local LAST_MESSAGE_ID = ""
local UPDATE_INTERVAL = 300 -- 5 minutes

pcall(function()
    if isfile and isfile(WEBHOOK_FILE) then WEBHOOK_URL     = readfile(WEBHOOK_FILE):gsub("%s+","") end
    if isfile and isfile(MSG_ID_FILE)  then LAST_MESSAGE_ID = readfile(MSG_ID_FILE):gsub("%s+","")  end
end)

-- ── HTTP ──────────────────────────────────────────────────────────────────────
local function httpRequest(data)
    if syn and syn.request       then return syn.request(data)
    elseif http and http.request then return http.request(data)
    elseif http_request          then return http_request(data)
    elseif request               then return request(data)
    else warn("[GAG2 Schedule] No HTTP function!") end
end

local function httpPost(url, body)
    local ok, res, done = false, nil, false
    coroutine.wrap(function()
        ok, res = pcall(function()
            return httpRequest({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
        end)
        done = true
    end)()
    local t = 0
    while not done and t < 8 do RunService.Heartbeat:Wait() t=t+0.05 end
    return ok, res
end

local function httpPatch(url, body)
    local ok, res, done = false, nil, false
    coroutine.wrap(function()
        ok, res = pcall(function()
            return httpRequest({Url=url, Method="PATCH", Headers={["Content-Type"]="application/json"}, Body=body})
        end)
        done = true
    end)()
    local t = 0
    while not done and t < 8 do RunService.Heartbeat:Wait() t=t+0.05 end
    return ok, res
end

-- ── Time formatter → "Xd Xh Xm Xs" ──────────────────────────────────────────
local function parseTimeToSeconds(txt)
    if not txt or txt == "" or txt == "0s" or txt == "0m 0s" then return 0 end
    local total = 0
    -- formats seen: "2m 41s", "5m 30s", "1h 16m", "1d 0h", "5h 43m"
    local d = txt:match("(%d+)d") total = total + (d and tonumber(d)*86400 or 0)
    local h = txt:match("(%d+)h") total = total + (h and tonumber(h)*3600  or 0)
    local m = txt:match("(%d+)m") total = total + (m and tonumber(m)*60    or 0)
    local s = txt:match("(%d+)s") total = total + (s and tonumber(s)       or 0)
    return total
end

local function formatExpanded(txt)
    local secs = parseTimeToSeconds(txt)
    if secs <= 0 then return "Available now" end
    local d = math.floor(secs/86400)
    local h = math.floor((secs%86400)/3600)
    local m = math.floor((secs%3600)/60)
    local s = secs%60
    local parts = {}
    if d>0 then table.insert(parts, d.."d") end
    if h>0 then table.insert(parts, h.."h") end
    if m>0 then table.insert(parts, m.."m") end
    if s>0 or #parts==0 then table.insert(parts, s.."s") end
    return table.concat(parts, " ")
end

-- ── Item / Weather lists ──────────────────────────────────────────────────────
local SEED_ITEMS = {
    "Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Pumpkin",
    "Bamboo","Corn","Cactus","Pineapple","Horned Melon",
    "Mushroom","Banana","Grape","Coconut","Mango","Beanstalk","Lotus","Glow Mushroom","Jump Mushroom","Invisibility Mushroom",
    "Dragon Fruit","Acorn","Cherry","Sunflower","Thorn Rose","Poison Ivy",
    "Venus Fly Trap","Pomegranate","Poison Apple","Ghost Pepper",
    "Moon Bloom","Dragon's Breath",
}

local GEAR_ITEMS = {
    "Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler","Legendary Sprinkler","Super Sprinkler",
    "Common Watering Can","Super Watering Can",
    "Trowel","Rake","Crowbar","Teleporter","Power Hose","Freeze Ray","Rainbow Carpet","Vine Wrapper",
}

local WEATHER_ITEMS = {
    "Rain","Lightning","Bloodmoon","Snowfall","Night","Starfall","Rainbow",
}

local WEATHER_EMOJI = {
    Rain="🌧️", Lightning="⚡", Bloodmoon="🩸", Snowfall="❄️",
    Night="🌙", Starfall="⭐", Rainbow="🌈",
}

local RARITY_EMOJI = {
    Common="⚪", Uncommon="🟢", Rare="🔵", Epic="🟣",
    Legendary="🟡", Mythic="🔴", Super="🌟",
}

local SEED_RARITY = {
    Carrot="Common", Strawberry="Common", Blueberry="Common",
    Tulip="Uncommon", Tomato="Uncommon", Apple="Uncommon", Pumpkin="Uncommon",
    Bamboo="Rare", Corn="Rare", Cactus="Rare", Pineapple="Rare", ["Horned Melon"]="Rare",
    Mushroom="Epic", Banana="Epic", Grape="Epic", Coconut="Epic", Mango="Epic",
    Beanstalk="Epic", Lotus="Epic", ["Glow Mushroom"]="Epic",
    ["Jump Mushroom"]="Epic", ["Invisibility Mushroom"]="Epic",
    ["Dragon Fruit"]="Legendary", Acorn="Legendary", Cherry="Legendary",
    Sunflower="Legendary", ["Thorn Rose"]="Legendary", ["Poison Ivy"]="Legendary",
    ["Venus Fly Trap"]="Mythic", Pomegranate="Mythic", ["Poison Apple"]="Mythic", ["Ghost Pepper"]="Mythic",
    ["Moon Bloom"]="Super", ["Dragon's Breath"]="Super",
}

local GEAR_RARITY = {
    ["Common Sprinkler"]="Common", ["Common Watering Can"]="Common", Trowel="Common",
    ["Uncommon Sprinkler"]="Uncommon", Rake="Uncommon", Crowbar="Uncommon",
    ["Rare Sprinkler"]="Rare", Teleporter="Rare", ["Power Hose"]="Rare", ["Vine Wrapper"]="Rare",
    ["Legendary Sprinkler"]="Legendary", ["Freeze Ray"]="Legendary", ["Rainbow Carpet"]="Legendary",
    ["Super Sprinkler"]="Super", ["Super Watering Can"]="Super",
}

-- ── Checked state ─────────────────────────────────────────────────────────────
local checked = {}

local function saveChecks()
    local parts = {}
    for k, v in pairs(checked) do
        if v then table.insert(parts, k) end
    end
    pcall(function() writefile(CHECKS_FILE, table.concat(parts, "\n")) end)
end

local function loadChecks()
    pcall(function()
        if isfile and isfile(CHECKS_FILE) then
            for line in readfile(CHECKS_FILE):gmatch("[^\n]+") do
                checked[line] = true
            end
        end
    end)
end
loadChecks()

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {
    BG=Color3.fromRGB(13,13,18),      Panel=Color3.fromRGB(20,20,28),
    Card=Color3.fromRGB(26,26,38),    Sidebar=Color3.fromRGB(16,16,24),
    Accent=Color3.fromRGB(60,180,80), Green=Color3.fromRGB(50,200,100),
    Red=Color3.fromRGB(210,60,60),    Text=Color3.fromRGB(235,235,255),
    Sub=Color3.fromRGB(120,120,155),  Border=Color3.fromRGB(40,40,60),
    Gold=Color3.fromRGB(255,200,50),  Purple=Color3.fromRGB(100,50,180),
    Row=Color3.fromRGB(22,22,34),     CheckOn=Color3.fromRGB(20,32,22),
}

local RC = {
    Common=Color3.fromRGB(180,180,180), Uncommon=Color3.fromRGB(60,200,100),
    Rare=Color3.fromRGB(80,150,255),    Epic=Color3.fromRGB(180,100,255),
    Legendary=Color3.fromRGB(255,200,50), Mythic=Color3.fromRGB(255,80,80),
    Super=Color3.fromRGB(255,140,0),
}

-- ── GUI Root ──────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui", pg)
sg.Name="GAG2Schedule" sg.ResetOnSpawn=false sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local Win = Instance.new("Frame", sg)
Win.Size=UDim2.new(0,540,0,500) Win.Position=UDim2.new(0.5,-270,0.5,-250)
Win.BackgroundColor3=C.BG Win.BorderSizePixel=0 Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,12)
Instance.new("UIStroke",Win).Color=C.Border

-- Topbar
local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,44) TB.BackgroundColor3=C.Panel TB.BorderSizePixel=0 TB.ZIndex=10

local tdot=Instance.new("Frame",TB)
tdot.Size=UDim2.new(0,10,0,10) tdot.Position=UDim2.new(0,12,0.5,-5)
tdot.BackgroundColor3=C.Accent tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,360,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("📅 Grow A Garden 2 — Schedule",14,C.Text,28,5)
tl("Restock Timers · Weather Queue · Auto-Edit Discord",10,C.Sub,28,23)

local function topBtn(xo,bg,t)
    local b=Instance.new("TextButton",TB)
    b.Size=UDim2.new(0,26,0,26) b.Position=UDim2.new(1,xo,0.5,-13)
    b.BackgroundColor3=bg b.Text=t b.TextColor3=Color3.new(1,1,1)
    b.TextSize=13 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.ZIndex=11
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5) return b
end
topBtn(-10,C.Red,"✕").MouseButton1Click:Connect(function() sg:Destroy() end)
local minBtn=topBtn(-42,Color3.fromRGB(40,40,60),"−")

local Body=Instance.new("Frame",Win)
Body.Size=UDim2.new(1,0,1,-44) Body.Position=UDim2.new(0,0,0,44) Body.BackgroundTransparency=1
local isMin=false
minBtn.MouseButton1Click:Connect(function()
    isMin=not isMin Body.Visible=not isMin
    TweenService:Create(Win,TweenInfo.new(0.2),{Size=isMin and UDim2.new(0,540,0,44) or UDim2.new(0,540,0,500)}):Play()
    minBtn.Text=isMin and "+" or "−"
end)

-- ── Sidebar ───────────────────────────────────────────────────────────────────
local SB=Instance.new("Frame",Body)
SB.Size=UDim2.new(0,116,1,0) SB.BackgroundColor3=C.Sidebar SB.BorderSizePixel=0
local sbl=Instance.new("UIListLayout",SB)
sbl.Padding=UDim.new(0,4) sbl.SortOrder=Enum.SortOrder.LayoutOrder
Instance.new("UIPadding",SB).PaddingTop=UDim.new(0,8)

local function sideTab(lbl,icon,order)
    local b=Instance.new("TextButton",SB)
    b.Size=UDim2.new(1,-8,0,38) b.BackgroundColor3=C.Card b.Text="" b.BorderSizePixel=0 b.LayoutOrder=order
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    local i=Instance.new("TextLabel",b) i.Size=UDim2.new(0,26,1,0) i.Position=UDim2.new(0,6,0,0)
    i.BackgroundTransparency=1 i.Text=icon i.TextSize=16 i.Font=Enum.Font.Gotham i.TextColor3=C.Text
    local t=Instance.new("TextLabel",b) t.Size=UDim2.new(1,-36,1,0) t.Position=UDim2.new(0,36,0,0)
    t.BackgroundTransparency=1 t.Text=lbl t.TextSize=11 t.Font=Enum.Font.GothamBold t.TextColor3=C.Sub
    t.TextXAlignment=Enum.TextXAlignment.Left return b,t
end

local seedTab,seedTabL    = sideTab("Seeds","🌱",1)
local gearTab,gearTabL    = sideTab("Gear","⚙️",2)
local weatherTab,wxTabL   = sideTab("Weather","🌤️",3)
local previewTab,prevTabL = sideTab("Preview","👁",4)
local hookTab,hookTabL    = sideTab("Webhook","🔗",5)

-- Status card
local statusCard=Instance.new("Frame",SB)
statusCard.Size=UDim2.new(1,-8,0,80) statusCard.BackgroundColor3=C.Card
statusCard.BorderSizePixel=0 statusCard.LayoutOrder=10
Instance.new("UICorner",statusCard).CornerRadius=UDim.new(0,7)

local function sideLabel(t,sz,y,col)
    local l=Instance.new("TextLabel",statusCard) l.Size=UDim2.new(1,-8,0,14)
    l.Position=UDim2.new(0,8,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col or C.Sub l.TextSize=sz l.Font=Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left return l
end
local nextUpdateLbl = sideLabel("Next update: --",9,8)
local statusLbl     = sideLabel("Ready",9,24,C.Green)
local webhookLbl    = sideLabel(WEBHOOK_URL~="" and "✅ Webhook set" or "⚠️ No webhook",8,40,WEBHOOK_URL~="" and C.Green or C.Red)
local msgLbl        = sideLabel(LAST_MESSAGE_ID~="" and "✅ Msg linked" or "⚪ No message",8,56,LAST_MESSAGE_ID~="" and C.Green or C.Sub)

-- Send now button
local sendNowBtn=Instance.new("TextButton",SB)
sendNowBtn.Size=UDim2.new(1,-8,0,30) sendNowBtn.BackgroundColor3=C.Accent
sendNowBtn.Text="📤 Send / Update Now" sendNowBtn.TextColor3=Color3.new(1,1,1)
sendNowBtn.TextSize=10 sendNowBtn.Font=Enum.Font.GothamBold sendNowBtn.BorderSizePixel=0
sendNowBtn.LayoutOrder=11
Instance.new("UICorner",sendNowBtn).CornerRadius=UDim.new(0,7)

-- Content area
local CT=Instance.new("Frame",Body)
CT.Size=UDim2.new(1,-124,1,-8) CT.Position=UDim2.new(0,120,0,4) CT.BackgroundTransparency=1

local function makePage()
    local f=Instance.new("Frame",CT) f.Size=UDim2.new(1,0,1,0) f.BackgroundTransparency=1 f.Visible=false return f
end
local function hdr(p,t,y)
    local l=Instance.new("TextLabel",p) l.Size=UDim2.new(1,0,0,14)
    l.Position=UDim2.new(0,0,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=C.Sub l.TextSize=10 l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
local function abtn(p,t,y,bg,h)
    local b=Instance.new("TextButton",p) b.Size=UDim2.new(1,0,0,h or 30)
    b.Position=UDim2.new(0,0,0,y) b.BackgroundColor3=bg or C.Accent b.Text=t
    b.TextColor3=Color3.new(1,1,1) b.TextSize=11 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7) return b
end

-- ── Checkbox row builder ──────────────────────────────────────────────────────
local checkRefs = {} -- stores {row, setFn} per name for refresh

local function makeCheckRow(parent, name, rarityMap, index)
    local rarity  = rarityMap and rarityMap[name] or nil
    local col     = rarity and (RC[rarity] or C.Sub) or C.Sub

    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,26) row.LayoutOrder=index row.BorderSizePixel=0
    row.BackgroundColor3=checked[name] and C.CheckOn or C.Row
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)

    local cb=Instance.new("TextButton",row)
    cb.Size=UDim2.new(0,18,0,18) cb.Position=UDim2.new(0,5,0.5,-9)
    cb.BackgroundColor3=checked[name] and C.Green or C.Border
    cb.Text=checked[name] and "✓" or "" cb.TextColor3=Color3.new(1,1,1)
    cb.TextSize=12 cb.Font=Enum.Font.GothamBold cb.BorderSizePixel=0
    Instance.new("UICorner",cb).CornerRadius=UDim.new(0,4)

    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-100,1,0) nameLbl.Position=UDim2.new(0,28,0,0)
    nameLbl.BackgroundTransparency=1 nameLbl.Text=name
    nameLbl.TextColor3=C.Text nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left

    if rarity then
        local rarLbl=Instance.new("TextLabel",row)
        rarLbl.Size=UDim2.new(0,78,0,16) rarLbl.Position=UDim2.new(1,-82,0.5,-8)
        rarLbl.BackgroundTransparency=1 rarLbl.Text=(RARITY_EMOJI[rarity] or "").. " "..rarity
        rarLbl.TextColor3=col rarLbl.TextSize=9 rarLbl.Font=Enum.Font.GothamBold
        rarLbl.TextXAlignment=Enum.TextXAlignment.Right
    end

    local function setCheck(v)
        checked[name]=v
        cb.BackgroundColor3=v and C.Green or C.Border
        cb.Text=v and "✓" or ""
        row.BackgroundColor3=v and C.CheckOn or C.Row
        saveChecks()
    end

    cb.MouseButton1Click:Connect(function() setCheck(not checked[name]) end)
    row.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then setCheck(not checked[name]) end
    end)

    checkRefs[name]={row=row, set=setCheck}
    return row, setCheck
end

-- ── Build checklist page ──────────────────────────────────────────────────────
local function buildCheckPage(title, icon, itemList, rarityMap)
    local page=makePage()
    hdr(page,"  "..icon.." "..title:upper().." — check items to include",0)

    -- Select all / Clear all
    local allBtn=abtn(page,"✅ Select All",18,Color3.fromRGB(25,90,45),24)
    allBtn.Size=UDim2.new(0.48,0,0,24)
    local clrBtn=abtn(page,"🗑 Clear All",18,C.Panel,24)
    clrBtn.Size=UDim2.new(0.48,0,0,24) clrBtn.Position=UDim2.new(0.52,0,0,18)
    Instance.new("UIStroke",clrBtn).Color=C.Red

    local bg=Instance.new("Frame",page) bg.Size=UDim2.new(1,0,0,368)
    bg.Position=UDim2.new(0,0,0,50) bg.BackgroundColor3=C.Card
    bg.BorderSizePixel=0 bg.ClipsDescendants=true
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",bg).Color=C.Border

    local sc=Instance.new("ScrollingFrame",bg)
    sc.Size=UDim2.new(1,-4,1,-4) sc.Position=UDim2.new(0,2,0,2)
    sc.BackgroundTransparency=1 sc.BorderSizePixel=0
    sc.ScrollBarThickness=2 sc.ScrollBarImageColor3=C.Accent
    local lay=Instance.new("UIListLayout",sc)
    lay.Padding=UDim.new(0,2) lay.SortOrder=Enum.SortOrder.LayoutOrder

    local rowList={}
    for i, name in ipairs(itemList) do
        local row, setFn = makeCheckRow(sc, name, rarityMap, i)
        table.insert(rowList, {name=name, set=setFn})
    end
    sc.CanvasSize=UDim2.new(0,0,0,#itemList*28+4)

    allBtn.MouseButton1Click:Connect(function()
        for _, ref in ipairs(rowList) do ref.set(true) end
    end)
    clrBtn.MouseButton1Click:Connect(function()
        for _, ref in ipairs(rowList) do ref.set(false) end
    end)

    return page
end

local seedPage    = buildCheckPage("Seeds",   "🌱", SEED_ITEMS,    SEED_RARITY)
local gearPage    = buildCheckPage("Gear",    "⚙️", GEAR_ITEMS,    GEAR_RARITY)
local weatherPage = buildCheckPage("Weather", "🌤️", WEATHER_ITEMS, nil)

-- ── PREVIEW PAGE ──────────────────────────────────────────────────────────────
local prevPage=makePage()
hdr(prevPage,"  👁 PREVIEW — what will be sent to Discord",0)

local prevCard=Instance.new("Frame",prevPage)
prevCard.Size=UDim2.new(1,0,0,390) prevCard.Position=UDim2.new(0,0,0,18)
prevCard.BackgroundColor3=C.Card prevCard.BorderSizePixel=0 prevCard.ClipsDescendants=true
Instance.new("UICorner",prevCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",prevCard).Color=C.Border

local prevSc=Instance.new("ScrollingFrame",prevCard)
prevSc.Size=UDim2.new(1,-4,1,-4) prevSc.Position=UDim2.new(0,2,0,2)
prevSc.BackgroundTransparency=1 prevSc.BorderSizePixel=0
prevSc.ScrollBarThickness=2 prevSc.ScrollBarImageColor3=C.Accent

local prevLbl=Instance.new("TextLabel",prevSc)
prevLbl.Size=UDim2.new(1,-8,0,380) prevLbl.Position=UDim2.new(0,4,0,4)
prevLbl.BackgroundTransparency=1 prevLbl.Text="Press 'Send / Update Now' to preview"
prevLbl.TextColor3=C.Sub prevLbl.TextSize=10 prevLbl.Font=Enum.Font.Gotham
prevLbl.TextXAlignment=Enum.TextXAlignment.Left
prevLbl.TextYAlignment=Enum.TextYAlignment.Top prevLbl.TextWrapped=true

-- ── WEBHOOK PAGE ──────────────────────────────────────────────────────────────
local HKP=makePage()
hdr(HKP,"  🔗 DISCORD WEBHOOK",0)

local wCard=Instance.new("Frame",HKP) wCard.Size=UDim2.new(1,0,0,114)
wCard.Position=UDim2.new(0,0,0,18) wCard.BackgroundColor3=C.Card wCard.BorderSizePixel=0
Instance.new("UICorner",wCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wCard).Color=C.Border

local wHint=Instance.new("TextLabel",wCard)
wHint.Size=UDim2.new(1,-16,0,16) wHint.Position=UDim2.new(0,8,0,6)
wHint.BackgroundTransparency=1 wHint.Text="Webhook URL (saved permanently):"
wHint.TextColor3=C.Sub wHint.TextSize=11 wHint.Font=Enum.Font.GothamBold
wHint.TextXAlignment=Enum.TextXAlignment.Left

local wBox=Instance.new("TextBox",wCard)
wBox.Size=UDim2.new(1,-16,0,30) wBox.Position=UDim2.new(0,8,0,26)
wBox.BackgroundColor3=C.BG wBox.Text=WEBHOOK_URL
wBox.PlaceholderText="https://discord.com/api/webhooks/..."
wBox.TextColor3=C.Text wBox.PlaceholderColor3=C.Sub wBox.TextSize=9 wBox.Font=Enum.Font.Gotham
wBox.TextXAlignment=Enum.TextXAlignment.Left wBox.ClearTextOnFocus=false wBox.BorderSizePixel=0
Instance.new("UICorner",wBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",wBox).PaddingLeft=UDim.new(0,6)

local wSave=abtn(wCard,"💾  Save Webhook Permanently",62,C.Green,26)
wSave.Size=UDim2.new(1,-16,0,26) wSave.Position=UDim2.new(0,8,0,62) wSave.TextSize=11

local wStatus=Instance.new("TextLabel",HKP)
wStatus.Size=UDim2.new(1,0,0,18) wStatus.Position=UDim2.new(0,0,0,138) wStatus.BackgroundTransparency=1
wStatus.Text=WEBHOOK_URL~="" and "✅ Webhook loaded from save!" or "No webhook saved."
wStatus.TextColor3=WEBHOOK_URL~="" and C.Green or C.Sub
wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold wStatus.TextXAlignment=Enum.TextXAlignment.Left

local wTest  = abtn(HKP,"🧪  Test Webhook",162,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent

local wClear = abtn(HKP,"🗑  Clear Saved Webhook",198,C.Panel,26)
Instance.new("UIStroke",wClear).Color=C.Red

-- Clear message ID button
local wClearMsg = abtn(HKP,"🗑  Clear Linked Message (force new post)",230,C.Panel,26)
Instance.new("UIStroke",wClearMsg).Color=C.Red

-- Ping role input
local pingCard=Instance.new("Frame",HKP) pingCard.Size=UDim2.new(1,0,0,72)
pingCard.Position=UDim2.new(0,0,0,264) pingCard.BackgroundColor3=C.Card pingCard.BorderSizePixel=0
Instance.new("UICorner",pingCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",pingCard).Color=C.Border

local pingHint=Instance.new("TextLabel",pingCard)
pingHint.Size=UDim2.new(1,-16,0,16) pingHint.Position=UDim2.new(0,8,0,6)
pingHint.BackgroundTransparency=1 pingHint.Text="Ping role (optional) — paste role ID:"
pingHint.TextColor3=C.Sub pingHint.TextSize=11 pingHint.Font=Enum.Font.GothamBold
pingHint.TextXAlignment=Enum.TextXAlignment.Left

local pingBox=Instance.new("TextBox",pingCard)
pingBox.Size=UDim2.new(1,-16,0,26) pingBox.Position=UDim2.new(0,8,0,26)
pingBox.BackgroundColor3=C.BG pingBox.Text=PING_ROLE:match("%d+") or ""
pingBox.PlaceholderText="Role ID e.g. 1515378504525549659  (leave blank for no ping)"
pingBox.TextColor3=C.Text pingBox.PlaceholderColor3=C.Sub pingBox.TextSize=9 pingBox.Font=Enum.Font.Gotham
pingBox.TextXAlignment=Enum.TextXAlignment.Left pingBox.ClearTextOnFocus=false pingBox.BorderSizePixel=0
Instance.new("UICorner",pingBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",pingBox).PaddingLeft=UDim.new(0,6)

local wInfo=Instance.new("TextLabel",HKP)
wInfo.Size=UDim2.new(1,0,0,60) wInfo.Position=UDim2.new(0,0,0,344) wInfo.BackgroundTransparency=1
wInfo.Text="The script edits the same Discord message every 5 minutes.\nFirst send creates the message, every update after edits it.\nClear Linked Message to force a fresh post next time."
wInfo.TextColor3=C.Sub wInfo.TextSize=10 wInfo.Font=Enum.Font.Gotham
wInfo.TextXAlignment=Enum.TextXAlignment.Left wInfo.TextWrapped=true

wSave.MouseButton1Click:Connect(function()
    local url=wBox.Text:gsub("%s+","")
    if url:find("discord.com/api/webhooks/") then
        WEBHOOK_URL=url
        pcall(function() writefile(WEBHOOK_FILE,url) end)
        wStatus.Text="✅ Saved permanently!" wStatus.TextColor3=C.Green
        webhookLbl.Text="✅ Webhook set" webhookLbl.TextColor3=C.Green
    else
        wStatus.Text="❌ Invalid webhook URL" wStatus.TextColor3=C.Red
    end
end)

wTest.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then wStatus.Text="⚠️ Save a webhook first!" wStatus.TextColor3=C.Red return end
    wTest.Text="⏳ Testing..."
    task.spawn(function()
        local ok,err=httpPost(WEBHOOK_URL,HttpService:JSONEncode({
            embeds={{
                title="✅ GAG2 Schedule — Test",
                description="Webhook connected! Schedule updates every 5 minutes.",
                color=3066993,
                footer={text="Grow A Garden 2 Schedule"}
            }}
        }))
        wTest.Text=ok and "✅ Works!" or "❌ Failed"
        wStatus.Text=ok and "✅ Connected!" or "❌ "..tostring(err)
        wStatus.TextColor3=ok and C.Green or C.Red
        task.delay(3,function() wTest.Text="🧪  Test Webhook" end)
    end)
end)

wClear.MouseButton1Click:Connect(function()
    WEBHOOK_URL="" wBox.Text=""
    pcall(function() writefile(WEBHOOK_FILE,"") end)
    wStatus.Text="Webhook cleared." wStatus.TextColor3=C.Sub
    webhookLbl.Text="⚠️ No webhook" webhookLbl.TextColor3=C.Red
end)

wClearMsg.MouseButton1Click:Connect(function()
    LAST_MESSAGE_ID=""
    pcall(function() writefile(MSG_ID_FILE,"") end)
    msgLbl.Text="⚪ No message" msgLbl.TextColor3=C.Sub
    wClearMsg.Text="✅ Cleared — next send creates new post"
    task.delay(3,function() wClearMsg.Text="🗑  Clear Linked Message (force new post)" end)
end)

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabs={
    Seeds={seedPage,seedTab,seedTabL},       Gear={gearPage,gearTab,gearTabL},
    Weather={weatherPage,weatherTab,wxTabL}, Preview={prevPage,previewTab,prevTabL},
    Webhook={HKP,hookTab,hookTabL},
}
local function switchTab(n)
    for k,v in pairs(tabs) do
        v[1].Visible=(k==n)
        TweenService:Create(v[2],TweenInfo.new(0.15),{BackgroundColor3=(k==n) and C.Accent or C.Card}):Play()
        v[3].TextColor3=(k==n) and C.Text or C.Sub
    end
end
seedTab.MouseButton1Click:Connect(function()    switchTab("Seeds")   end)
gearTab.MouseButton1Click:Connect(function()    switchTab("Gear")    end)
weatherTab.MouseButton1Click:Connect(function() switchTab("Weather") end)
previewTab.MouseButton1Click:Connect(function() switchTab("Preview") end)
hookTab.MouseButton1Click:Connect(function()    switchTab("Webhook") end)
switchTab("Seeds")

-- ── Scanner ───────────────────────────────────────────────────────────────────
local function getShopRestockTime(guiName)
    local t = nil
    pcall(function()
        local gui   = pg:FindFirstChild(guiName)
        if not gui then return end
        for _, v in pairs(gui:GetDescendants()) do
            if v.ClassName=="TextLabel" and v.Name=="Timer" then
                t = v.Text return
            end
        end
    end)
    return t
end

local function getItemRestockTime(guiName, itemName)
    local result = nil
    pcall(function()
        local gui = pg:FindFirstChild(guiName)
        if not gui then return end
        for _, v in pairs(gui:GetDescendants()) do
            if v:IsA("TextLabel") and v.Name=="Seed_Text" and v.Text==itemName then
                local mf = v.Parent
                -- look for TextDisplay labels (x1, x3, x10 restock quantities)
                -- and Timer-like labels inside the same Main_Frame
                for _, child in pairs(mf:GetChildren()) do
                    if child:IsA("TextLabel") and (child.Name=="Stock_Text" or child.Name=="Timer" or child.Name=="Restock_Text") then
                        local txt = child.Text or ""
                        if txt:find("IN ") or txt:find("%dd") or txt:find("%dh") or txt:find("%dm") then
                            result = txt return
                        end
                    end
                end
                -- also check TextDisplay parent frames
                for _, child in pairs(mf:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextLabel") then
                        for _, sub in pairs(child:GetChildren()) do
                            if sub:IsA("TextLabel") then
                                local txt = sub.Text or ""
                                if txt:find("IN ") or txt:find("%dd") or txt:find("%dh") then
                                    result = txt return
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return result
end

local function getWeatherQueue()
    local queue = {}
    pcall(function()
        local weatherUI = pg:FindFirstChild("WeatherUI")
        if not weatherUI then return end
        local frame = weatherUI:FindFirstChildOfClass("Frame")
        if not frame then return end
        for _, child in pairs(frame:GetChildren()) do
            local wLbl = child:FindFirstChild("Weather")
            local tLbl = child:FindFirstChild("Time")
            if wLbl and tLbl then
                local name = wLbl.Text
                local time = tLbl.Text
                -- include all weathers that have a time (even 0s = current/just ended)
                if name and name ~= "" then
                    local secs = parseTimeToSeconds(time)
                    table.insert(queue, {name=name, time=time, secs=secs})
                end
            end
        end
        -- sort by secs ascending so closest is first
        table.sort(queue, function(a,b) return a.secs < b.secs end)
    end)
    return queue
end

-- ── Build Discord embeds ──────────────────────────────────────────────────────
local function buildPayload()
    local embeds   = {}
    local pingRole = pingBox.Text:gsub("%s+","")
    local content  = pingRole~="" and "<@&"..pingRole..">" or nil

    -- ── Seeds restock embed
    local seedLines   = {}
    local seedRestock = getShopRestockTime("SeedShop")
    local seedGlobal  = seedRestock and ("**Shop restocks in:** `"..formatExpanded(seedRestock:gsub("Restock in ","")).."` ⏱️\n\n") or ""

    for _, name in ipairs(SEED_ITEMS) do
        if checked[name] then
            local rarity  = SEED_RARITY[name] or "Common"
            local emoji   = RARITY_EMOJI[rarity] or "⚪"
            local itemEta = getItemRestockTime("SeedShop", name)
            local etaTxt  = itemEta and ("`"..formatExpanded(itemEta).."` ") or ""
            table.insert(seedLines, emoji.." **"..name.."** `"..rarity.."` "..etaTxt)
        end
    end

    if #seedLines > 0 then
        table.insert(embeds, {
            title       = "🌱 Seeds — Restock Schedule",
            description = seedGlobal..table.concat(seedLines,"\n"),
            color       = 3066993,
            footer      = {text="Grow A Garden 2 Schedule · "..os.date("%H:%M:%S")},
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end

    -- ── Gear restock embed
    local gearLines   = {}
    local gearRestock = getShopRestockTime("GearShop")
    local gearGlobal  = gearRestock and ("**Shop restocks in:** `"..formatExpanded(gearRestock:gsub("Restock in ","")).."` ⏱️\n\n") or ""

    for _, name in ipairs(GEAR_ITEMS) do
        if checked[name] then
            local rarity  = GEAR_RARITY[name] or "Common"
            local emoji   = RARITY_EMOJI[rarity] or "⚪"
            local itemEta = getItemRestockTime("GearShop", name)
            local etaTxt  = itemEta and ("`"..formatExpanded(itemEta).."` ") or ""
            table.insert(gearLines, emoji.." **"..name.."** `"..rarity.."` "..etaTxt)
        end
    end

    if #gearLines > 0 then
        table.insert(embeds, {
            title       = "⚙️ Gear — Restock Schedule",
            description = gearGlobal..table.concat(gearLines,"\n"),
            color       = 3447003,
            footer      = {text="Grow A Garden 2 Schedule · "..os.date("%H:%M:%S")},
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end

    -- ── Weather queue embed
    local wxLines = {}
    local queue   = getWeatherQueue()
    for _, w in ipairs(queue) do
        if checked[w.name] then
            local emoji   = WEATHER_EMOJI[w.name] or "🌤️"
            local timeTxt = w.secs <= 0 and "🟢 **Active now**" or ("`"..formatExpanded(w.time).."` away")
            table.insert(wxLines, emoji.." **"..w.name.."** — "..timeTxt)
        end
    end

    if #wxLines > 0 then
        table.insert(embeds, {
            title       = "🌤️ Weather Queue",
            description = table.concat(wxLines,"\n"),
            color       = 11393254,
            footer      = {text="Grow A Garden 2 Schedule · "..os.date("%H:%M:%S")},
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end

    if #embeds == 0 then return nil, "Nothing checked — select items in Seeds/Gear/Weather tabs" end

    return HttpService:JSONEncode({content=content, embeds=embeds}), nil
end

-- ── Send or edit Discord message ──────────────────────────────────────────────
local function sendOrEdit()
    if WEBHOOK_URL=="" then
        statusLbl.Text="⚠️ No webhook set!" statusLbl.TextColor3=C.Red
        return
    end

    local payload, err = buildPayload()
    if not payload then
        statusLbl.Text="⚠️ "..err statusLbl.TextColor3=C.Red
        return
    end

    -- update preview
    local previewText = ""
    local decoded = HttpService:JSONDecode(payload)
    for _, embed in ipairs(decoded.embeds or {}) do
        previewText = previewText .. "▌ **" .. (embed.title or "") .. "**\n"
        previewText = previewText .. (embed.description or "") .. "\n\n"
    end
    prevLbl.Text = previewText ~= "" and previewText or "Nothing to preview"
    prevSc.CanvasSize = UDim2.new(0,0,0,#previewText*0.6+20)

    statusLbl.Text="⏳ Sending..." statusLbl.TextColor3=C.Gold

    task.spawn(function()
        local ok, res

        if LAST_MESSAGE_ID ~= "" then
            -- extract webhook id and token from URL
            local webhookId, webhookToken = WEBHOOK_URL:match("webhooks/(%d+)/([%w_%-]+)")
            if webhookId and webhookToken then
                local editUrl = "https://discord.com/api/webhooks/"..webhookId.."/"..webhookToken.."/messages/"..LAST_MESSAGE_ID
                ok, res = httpPatch(editUrl, payload)
                if not ok then
                    -- message might be deleted, fall back to new post
                    LAST_MESSAGE_ID = ""
                end
            end
        end

        if LAST_MESSAGE_ID == "" then
            -- new post — need message ID back, use ?wait=true
            local postUrl = WEBHOOK_URL .. "?wait=true"
            ok, res = httpPost(postUrl, payload)
            if ok and res then
                pcall(function()
                    local body = type(res)=="table" and res.Body or tostring(res)
                    local data = HttpService:JSONDecode(body)
                    if data and data.id then
                        LAST_MESSAGE_ID = data.id
                        pcall(function() writefile(MSG_ID_FILE, LAST_MESSAGE_ID) end)
                        msgLbl.Text="✅ Msg linked" msgLbl.TextColor3=C.Green
                    end
                end)
            end
        end

        if ok then
            statusLbl.Text="✅ Updated: "..os.date("%H:%M:%S") statusLbl.TextColor3=C.Green
        else
            statusLbl.Text="❌ Failed to send" statusLbl.TextColor3=C.Red
        end
    end)
end

-- ── Send Now button ───────────────────────────────────────────────────────────
sendNowBtn.MouseButton1Click:Connect(function()
    sendNowBtn.Text="⏳ Sending..."
    task.spawn(function()
        sendOrEdit()
        sendNowBtn.Text="📤 Send / Update Now"
    end)
end)

-- ── Auto update every 5 minutes ───────────────────────────────────────────────
local countdown = UPDATE_INTERVAL
task.spawn(function()
    while sg.Parent do
        countdown = countdown - 1
        local m = math.floor(countdown/60)
        local s = countdown%60
        nextUpdateLbl.Text = string.format("Next: %dm %02ds", m, s)
        if countdown <= 0 then
            countdown = UPDATE_INTERVAL
            if WEBHOOK_URL ~= "" then
                sendOrEdit()
            end
        end
        task.wait(1)
    end
end)

-- ── Drag ──────────────────────────────────────────────────────────────────────
do
    local drag,ds,wp
    TB.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true ds=i.Position wp=Win.Position end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            Win.Position=UDim2.new(wp.X.Scale,wp.X.Offset+d.X,wp.Y.Scale,wp.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
end

print("[Grow A Garden 2 Schedule] Loaded! Auto-updates every 5 minutes.")
