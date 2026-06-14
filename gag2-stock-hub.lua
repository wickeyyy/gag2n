-- ╔═══════════════════════════════════════════════════════════════╗
-- ║     Grow A Garden 2 Stock v7                                  ║
-- ║     Auto Stock Reporter + Discord Notifier                    ║
-- ║     Seeds · Gear · Crates · Weather                           ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local lp               = Players.LocalPlayer
local pg               = lp:WaitForChild("PlayerGui")

if pg:FindFirstChild("GAG2StockHub") then pg:FindFirstChild("GAG2StockHub"):Destroy() end

-- ══════════════════════════════════════════════
-- ROLE PINGS (weather only)
-- ══════════════════════════════════════════════
local WEATHER_ROLE_PINGS = {
    ["Bloodmoon"] = "<@&1515606946948972645>",
    ["Rain"]      = "<@&1515607032609247353>",
    ["Rainbow"]   = "<@&1515607274343760004>",
    ["Starfall"]  = "<@&1515607276679987331>",
    ["Lightning"] = "<@&1515607365037064345>",
    ["Snowfall"]  = "<@&1515607406581780580>",
    ["Midas"]     = "<@&1515612301687001088>",
    ["Night"]     = "",
}

local EXCLUDED_ITEMS = {
    ["Carrot Seed"]   = true,
    ["Jump Mushroom"] = true,
}
-- ══════════════════════════════════════════════

local WEBHOOK_FILE      = "gag2_webhook.txt"
local WEBHOOK_URL       = ""
local AUTO_ENABLED      = true
local AUTO_INTERVAL     = 30
local lastStockSnapshot = {}
local lastWeather       = {}
local sentWeatherPings  = {}

pcall(function()
    if isfile and isfile(WEBHOOK_FILE) then
        WEBHOOK_URL = readfile(WEBHOOK_FILE):gsub("%s+","")
    end
end)

-- ── Universal HTTP ─────────────────────────────────────────────────────────────
local function httpRequest(data)
    if syn and syn.request       then return syn.request(data)
    elseif http and http.request then return http.request(data)
    elseif http_request          then return http_request(data)
    elseif request               then return request(data)
    else warn("[GAG2] No HTTP function found!") end
end

local function httpPost(url, body)
    local ok, err = false, "timeout"
    local done = false
    coroutine.wrap(function()
        ok, err = pcall(function()
            httpRequest({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
        end)
        done = true
    end)()
    local t = 0
    while not done and t < 6 do RunService.Heartbeat:Wait() t = t + 0.05 end
    return ok, err
end

-- ── Rarity config ──────────────────────────────────────────────────────────────
local RC = {
    Common=Color3.fromRGB(180,180,180),   Uncommon=Color3.fromRGB(60,200,100),
    Rare=Color3.fromRGB(80,150,255),      Epic=Color3.fromRGB(180,100,255),
    Legendary=Color3.fromRGB(255,200,50), Mythic=Color3.fromRGB(255,80,80),
    Super=Color3.fromRGB(255,140,0),      Event=Color3.fromRGB(255,120,200),
}
local RARITY_BG = {
    Common=Color3.fromRGB(50,50,50),      Uncommon=Color3.fromRGB(20,60,30),
    Rare=Color3.fromRGB(20,40,80),        Epic=Color3.fromRGB(50,20,80),
    Legendary=Color3.fromRGB(70,55,10),   Mythic=Color3.fromRGB(75,15,15),
    Super=Color3.fromRGB(80,45,10),       Event=Color3.fromRGB(75,20,55),
}
local RE = {
    Common="⚪", Uncommon="🟢", Rare="🔵", Epic="🟣",
    Legendary="🟡", Mythic="🔴", Super="🌟", Event="🌸",
}
local RI = {
    Common=9934743, Uncommon=3066993, Rare=3447003,
    Epic=10181046, Legendary=16750592, Mythic=15158332,
    Super=16737280, Event=16711935,
}
local TIER_ORDER = {"Super","Mythic","Legendary","Epic","Event","Rare","Uncommon","Common"}
local RARE_TIERS = {Epic=true,Legendary=true,Mythic=true,Super=true,Event=true}

local function normalizeRarity(r)
    if not r or r=="" then return "Common" end
    r=r:gsub("^%s+",""):gsub("%s+$","")
    return r:sub(1,1):upper()..r:sub(2):lower()
end

-- ── Weather config ─────────────────────────────────────────────────────────────
local WEATHER_EMOJI = {
    Rain="🌧️", Lightning="⚡", Bloodmoon="🩸", Snowfall="❄️",
    Night="🌙", Starfall="⭐", Rainbow="🌈", Midas="🌕",
}
local WEATHER_COLOR = {
    Rain=3447003, Lightning=16776960, Bloodmoon=10027008,
    Snowfall=11393254, Night=4456609, Starfall=16750592,
    Rainbow=11993012, Midas=16766720,
}

-- ══════════════════════════════════════════════════════════════════
-- ITEM DATABASES (updated from wiki + image)
-- ══════════════════════════════════════════════════════════════════

-- Crop/seed emojis for Discord display
local SEED_EMOJI = {
    ["Carrot"]="🥕", ["Strawberry"]="🍓", ["Blueberry"]="🫐",
    ["Tulip"]="🌷", ["Tomato"]="🍅", ["Apple"]="🍎",
    ["Bamboo"]="🎋", ["Corn"]="🌽", ["Cactus"]="🌵",
    ["Pineapple"]="🍍", ["Mushroom"]="🍄", ["Green Bean"]="🫘",
    ["Banana"]="🍌", ["Grape"]="🍇", ["Coconut"]="🥥",
    ["Mango"]="🥭", ["Dragon Fruit"]="🐉", ["Acorn"]="🌰",
    ["Cherry"]="🍒", ["Sunflower"]="🌻", ["Venus Fly Trap"]="🌿",
    ["Pomegranate"]="🔴", ["Poison Apple"]="🍏", ["Moon Bloom"]="🌙",
    ["Dragon's Breath"]="🔥", ["Watermelon"]="🍉", ["Pepper"]="🌶️",
    ["Lemon"]="🍋", ["Pear"]="🍐", ["Peach"]="🍑",
    ["Avocado"]="🥑", ["Eggplant"]="🍆", ["Broccoli"]="🥦",
    ["Onion"]="🧅", ["Garlic"]="🧄", ["Ginger"]="🫚",
}

local GEAR_EMOJI = {
    ["Common Sprinkler"]="💧", ["Uncommon Sprinkler"]="💧",
    ["Rare Sprinkler"]="💧", ["Legendary Sprinkler"]="💧",
    ["Super Sprinkler"]="💧", ["Common Watering Can"]="🪣",
    ["Super Watering Can"]="🪣", ["Trowel"]="🔧",
    ["Rake"]="🪛", ["Crowbar"]="🔩", ["Teleporter"]="🌀",
    ["Power Hose"]="💦", ["Freeze Ray"]="❄️",
    ["Rainbow Carpet"]="🌈", ["Vine Wrapper"]="🌿",
    ["Basic Pot"]="🪴", ["Watering Can"]="🪣",
    ["Sprinkler"]="💧",
}

local SEED_LIST = {
    -- Common
    {name="Carrot",          price="1 Sheckle",    rarity="Common"},
    {name="Strawberry",      price="10 Sheckles",  rarity="Common"},
    {name="Blueberry",       price="25 Sheckles",  rarity="Common"},
    -- Uncommon
    {name="Tulip",           price="40 Sheckles",  rarity="Uncommon"},
    {name="Tomato",          price="200 Sheckles", rarity="Uncommon"},
    {name="Apple",           price="400 Sheckles", rarity="Uncommon"},
    -- Rare
    {name="Bamboo",          price="700 Sheckles", rarity="Rare"},
    {name="Corn",            price="2.5K",         rarity="Rare"},
    {name="Cactus",          price="5K",           rarity="Rare"},
    {name="Pineapple",       price="10K",          rarity="Rare"},
    -- Epic
    {name="Mushroom",        price="15K",          rarity="Epic"},
    {name="Green Bean",      price="20K",          rarity="Epic"},
    {name="Banana",          price="30K",          rarity="Epic"},
    {name="Grape",           price="45K",          rarity="Epic"},
    {name="Coconut",         price="60K",          rarity="Epic"},
    {name="Mango",           price="80K",          rarity="Epic"},
    -- Legendary
    {name="Dragon Fruit",    price="120K",         rarity="Legendary"},
    {name="Acorn",           price="200K",         rarity="Legendary"},
    {name="Cherry",          price="300K",         rarity="Legendary"},
    {name="Sunflower",       price="500K",         rarity="Legendary"},
    -- Mythic
    {name="Venus Fly Trap",  price="1M",           rarity="Mythic"},
    {name="Pomegranate",     price="2M",           rarity="Mythic"},
    {name="Poison Apple",    price="3M",           rarity="Mythic"},
    -- Super
    {name="Moon Bloom",      price="???",          rarity="Super"},
    {name="Dragon's Breath", price="???",          rarity="Super"},
}

local GEAR_LIST = {
    {name="Common Sprinkler",    price="7 R$",   rarity="Common"},
    {name="Uncommon Sprinkler",  price="25 R$",  rarity="Uncommon"},
    {name="Rare Sprinkler",      price="49 R$",  rarity="Rare"},
    {name="Legendary Sprinkler", price="220 R$", rarity="Legendary"},
    {name="Super Sprinkler",     price="399 R$", rarity="Super"},
    {name="Common Watering Can", price="7 R$",   rarity="Common"},
    {name="Super Watering Can",  price="340 R$", rarity="Super"},
    {name="Basic Pot",           price="Free",   rarity="Common"},
    {name="Trowel",              price="30 R$",  rarity="Common"},
    {name="Rake",                price="65 R$",  rarity="Uncommon"},
    {name="Crowbar",             price="85 R$",  rarity="Uncommon"},
    {name="Teleporter",          price="79 R$",  rarity="Rare"},
    {name="Power Hose",          price="299 R$", rarity="Rare"},
    {name="Freeze Ray",          price="799 R$", rarity="Legendary"},
    {name="Rainbow Carpet",      price="599 R$", rarity="Legendary"},
    {name="Vine Wrapper",        price="499 R$", rarity="Rare"},
}

local CRATE_LIST = {
    {name="Ladder Crate",          price="19 R$",  rarity="Common"},
    {name="Bench Crate",           price="23 R$",  rarity="Common"},
    {name="Light Crate",           price="39 R$",  rarity="Uncommon"},
    {name="Roleplay Crate",        price="63 R$",  rarity="Uncommon"},
    {name="Arch Crate",            price="59 R$",  rarity="Uncommon"},
    {name="Conveyor Crate",        price="69 R$",  rarity="Rare"},
    {name="Bridge Crate",          price="79 R$",  rarity="Rare"},
    {name="Spring Crate",          price="99 R$",  rarity="Rare"},
    {name="Bear Trap Crate",       price="169 R$", rarity="Epic"},
    {name="Owner Door Crate",      price="179 R$", rarity="Epic"},
    {name="Fence Crate",           price="199 R$", rarity="Epic"},
    {name="Weather Machine Crate", price="399 R$", rarity="Legendary"},
    {name="Sign Crate",            price="29 R$",  rarity="Common"},
    {name="Teleporter Pad Crate",  price="49 R$",  rarity="Uncommon"},
    {name="Seesaw Crate",          price="89 R$",  rarity="Rare"},
    {name="Lantern Crate",         price="35 R$",  rarity="Common"},
    {name="Wheelbarrow Crate",     price="45 R$",  rarity="Common"},
}

-- ── Theme ──────────────────────────────────────────────────────────────────────
local C = {
    BG=Color3.fromRGB(13,13,18),      Panel=Color3.fromRGB(20,20,28),
    Card=Color3.fromRGB(26,26,38),    Sidebar=Color3.fromRGB(16,16,24),
    Accent=Color3.fromRGB(60,180,80), Green=Color3.fromRGB(50,200,100),
    Red=Color3.fromRGB(210,60,60),    Text=Color3.fromRGB(235,235,255),
    Sub=Color3.fromRGB(120,120,155),  Border=Color3.fromRGB(40,40,60),
    Gold=Color3.fromRGB(255,200,50),  Row=Color3.fromRGB(22,22,34),
    RowIn=Color3.fromRGB(20,32,22),   Purple=Color3.fromRGB(80,40,160),
}

-- ── GUI Root ───────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui", pg)
sg.Name="GAG2StockHub" sg.ResetOnSpawn=false sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local Win = Instance.new("Frame", sg)
Win.Size=UDim2.new(0,520,0,490) Win.Position=UDim2.new(0.5,-260,0.5,-245)
Win.BackgroundColor3=C.BG Win.BorderSizePixel=0 Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,12)
Instance.new("UIStroke",Win).Color=C.Border

-- Topbar
local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,44) TB.BackgroundColor3=C.Panel TB.BorderSizePixel=0 TB.ZIndex=10
local tdot=Instance.new("Frame",TB)
tdot.Size=UDim2.new(0,10,0,10) tdot.Position=UDim2.new(0,12,0.5,-5)
tdot.BackgroundColor3=C.Green tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,340,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("🌱 Grow A Garden 2 Stock",14,C.Text,28,5)
tl("Auto Reporter  v7",10,C.Sub,28,23)

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
    TweenService:Create(Win,TweenInfo.new(0.2),{Size=isMin and UDim2.new(0,520,0,44) or UDim2.new(0,520,0,490)}):Play()
    minBtn.Text=isMin and "+" or "−"
end)

-- Sidebar
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

local seedTab,seedTabL   = sideTab("Seeds","🌱",1)
local gearTab,gearTabL   = sideTab("Gear","⚙️",2)
local crateTab,crateTabL = sideTab("Crates","📦",3)
local wxTab,wxTabL       = sideTab("Weather","🌤️",4)
local hookTab,hookTabL   = sideTab("Webhook","🔗",5)

-- Status card
local statusCard=Instance.new("Frame",SB)
statusCard.Size=UDim2.new(1,-8,0,90) statusCard.BackgroundColor3=C.Card
statusCard.BorderSizePixel=0 statusCard.LayoutOrder=10
Instance.new("UICorner",statusCard).CornerRadius=UDim.new(0,7)

local timerDot=Instance.new("Frame",statusCard)
timerDot.Size=UDim2.new(0,7,0,7) timerDot.Position=UDim2.new(0,8,0,8)
timerDot.BackgroundColor3=C.Green timerDot.BorderSizePixel=0
Instance.new("UICorner",timerDot).CornerRadius=UDim.new(1,0)

local function sideLabel(t,sz,y,col)
    local l=Instance.new("TextLabel",statusCard) l.Size=UDim2.new(1,-8,0,14)
    l.Position=UDim2.new(0,8,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col or C.Sub l.TextSize=sz l.Font=Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left return l
end
local timerLbl    = sideLabel("Next: --",11,18)
local autoLbl     = sideLabel("🟢 Auto: ON",9,34,C.Green)
local lastScanLbl = sideLabel("Starting...",8,50)
local webhookLbl  = sideLabel(
    WEBHOOK_URL~="" and "✅ Webhook set" or "⚠️ No webhook",
    8,64,WEBHOOK_URL~="" and C.Green or C.Red
)

local offBtn=Instance.new("TextButton",SB)
offBtn.Size=UDim2.new(1,-8,0,30) offBtn.BackgroundColor3=C.Red
offBtn.Text="⏹  Turn OFF" offBtn.TextColor3=Color3.new(1,1,1)
offBtn.TextSize=11 offBtn.Font=Enum.Font.GothamBold offBtn.BorderSizePixel=0 offBtn.LayoutOrder=11
Instance.new("UICorner",offBtn).CornerRadius=UDim.new(0,7)

local forceBtn=Instance.new("TextButton",SB)
forceBtn.Size=UDim2.new(1,-8,0,30) forceBtn.BackgroundColor3=C.Purple
forceBtn.Text="🚀 Force Send All" forceBtn.TextColor3=Color3.new(1,1,1)
forceBtn.TextSize=10 forceBtn.Font=Enum.Font.GothamBold forceBtn.BorderSizePixel=0 forceBtn.LayoutOrder=12
Instance.new("UICorner",forceBtn).CornerRadius=UDim.new(0,7)

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
    local b=Instance.new("TextButton",p) b.Size=UDim2.new(1,0,0,h or 32)
    b.Position=UDim2.new(0,0,0,y) b.BackgroundColor3=bg or C.Accent b.Text=t
    b.TextColor3=Color3.new(1,1,1) b.TextSize=12 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7) return b
end

local function makeRarityBadge(parent, rarity, xOffset)
    local r=rarity or "Common"
    local col=RC[r] or C.Sub
    local bg=RARITY_BG[r] or C.Card
    local emoji=RE[r] or "⚪"
    local badge=Instance.new("Frame",parent)
    badge.Size=UDim2.new(0,82,0,19)
    badge.Position=UDim2.new(1,xOffset or -130,0.5,-9)
    badge.BackgroundColor3=bg badge.BorderSizePixel=0
    Instance.new("UICorner",badge).CornerRadius=UDim.new(0,9)
    local stroke=Instance.new("UIStroke",badge) stroke.Color=col stroke.Thickness=1.2
    local lbl=Instance.new("TextLabel",badge)
    lbl.Size=UDim2.new(1,-4,1,0) lbl.Position=UDim2.new(0,2,0,0)
    lbl.BackgroundTransparency=1 lbl.Text=emoji.." "..r
    lbl.TextColor3=col lbl.TextSize=9 lbl.Font=Enum.Font.GothamBold
    lbl.TextXAlignment=Enum.TextXAlignment.Center
    return badge
end

local function makeItemRow(parent, item, index)
    local r=item.rarity or "Common"
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,30)
    row.BackgroundColor3=item.inStock and C.RowIn or C.Row
    row.LayoutOrder=index row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
    local dot=Instance.new("Frame",row)
    dot.Size=UDim2.new(0,7,0,7) dot.Position=UDim2.new(0,6,0.5,-3)
    dot.BackgroundColor3=item.inStock and C.Green or C.Red
    dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-160,1,0) nameLbl.Position=UDim2.new(0,18,0,0)
    nameLbl.BackgroundTransparency=1 nameLbl.Text=item.name
    nameLbl.TextColor3=item.inStock and C.Text or C.Sub
    nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    makeRarityBadge(row,r,-130)
    local priceLbl=Instance.new("TextLabel",row)
    priceLbl.Size=UDim2.new(0,42,1,0) priceLbl.Position=UDim2.new(1,-44,0,0)
    priceLbl.BackgroundTransparency=1
    local displayPrice=item.price or "???"
    if displayPrice=="OWNED" or displayPrice=="EQUIPPED"
    or displayPrice=="NOT OWNED" or displayPrice=="UNEQUIPPED" then
        displayPrice=item.dbPrice or "R$?"
    end
    priceLbl.Text=displayPrice
    priceLbl.TextColor3=item.inStock and Color3.fromRGB(100,220,100) or C.Sub
    priceLbl.TextSize=9 priceLbl.Font=Enum.Font.Gotham
    priceLbl.TextXAlignment=Enum.TextXAlignment.Right
    return row
end

local function buildShopPage(shopName, icon)
    local page=makePage()
    hdr(page,"  "..icon.." "..shopName:upper().." — live stock",0)
    local statsLbl=Instance.new("TextLabel",page)
    statsLbl.Size=UDim2.new(1,0,0,16) statsLbl.Position=UDim2.new(0,0,0,16)
    statsLbl.BackgroundTransparency=1 statsLbl.Text="Waiting for scan..."
    statsLbl.TextColor3=C.Sub statsLbl.TextSize=10 statsLbl.Font=Enum.Font.Gotham
    statsLbl.TextXAlignment=Enum.TextXAlignment.Left
    local bg=Instance.new("Frame",page) bg.Size=UDim2.new(1,0,0,302)
    bg.Position=UDim2.new(0,0,0,36) bg.BackgroundColor3=C.Card
    bg.BorderSizePixel=0 bg.ClipsDescendants=true
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",bg).Color=C.Border
    local sc=Instance.new("ScrollingFrame",bg)
    sc.Size=UDim2.new(1,-4,1,-4) sc.Position=UDim2.new(0,2,0,2)
    sc.BackgroundTransparency=1 sc.BorderSizePixel=0
    sc.ScrollBarThickness=2 sc.ScrollBarImageColor3=C.Accent
    local lay=Instance.new("UIListLayout",sc)
    lay.Padding=UDim.new(0,2) lay.SortOrder=Enum.SortOrder.LayoutOrder
    local sendBtn=abtn(page,"📤  Force Send "..shopName.." to Discord",346,C.Accent)
    local scanBtn=abtn(page,"🔍  Refresh Now",382,Color3.fromRGB(25,100,65),26)
    return page,sc,statsLbl,sendBtn,scanBtn
end

local seedPage,  seedSc,  seedStats,  seedSend,  seedScan  = buildShopPage("Seeds","🌱")
local gearPage,  gearSc,  gearStats,  gearSend,  gearScan  = buildShopPage("Gear","⚙️")
local cratePage, crateSc, crateStats, crateSend, crateScan  = buildShopPage("Crates","📦")

local function dbLookup(list, name)
    for _,v in ipairs(list) do
        if v.name:lower()==name:lower() then return v end
    end
    return nil
end

-- ── Shop scanner ───────────────────────────────────────────────────────────────
local function scanShop(guiName, dbList)
    local items={} local seen={}
    pcall(function()
        local shopGui=pg:FindFirstChild(guiName)
        if not shopGui then return end
        for _,v in pairs(shopGui:GetDescendants()) do
            if v:IsA("TextLabel") and v.Name=="Seed_Text" then
                local grandParent=v.Parent and v.Parent.Parent
                if grandParent and grandParent.Name=="ItemTemplate" then continue end
                local name=v.Text:gsub("^%s+",""):gsub("%s+$","")
                if EXCLUDED_ITEMS[name] then continue end
                if name=="" or seen[name] then continue end
                seen[name]=true
                local parent=v.Parent
                local costLbl=parent and parent:FindFirstChild("Cost_Text")
                local rarityLbl=parent and parent:FindFirstChild("Rarity_Text")
                local stockLbl=parent and parent:FindFirstChild("Stock_Text")
                local rawPrice=costLbl and costLbl.Text or ""
                local rarity=rarityLbl and rarityLbl.Text or "Common"
                local stock=stockLbl and stockLbl.Text or "NO STOCK"
                local statusWords={"NO STOCK","x0 in Stock","SOLD OUT","OWNED","EQUIPPED","NOT OWNED","UNEQUIPPED"}
                local inStock=true
                for _,sw in ipairs(statusWords) do
                    if rawPrice:upper():find(sw:upper()) or stock:upper():find(sw:upper()) then
                        inStock=false break
                    end
                end
                if stock=="" then inStock=false end
                local dbEntry=dbLookup(dbList,name)
                local dbPrice=dbEntry and dbEntry.price or "???"
                local dbRarity=dbEntry and dbEntry.rarity or normalizeRarity(rarity)
                local displayPrice=rawPrice
                if rawPrice=="" or rawPrice:upper():find("OWNED") or rawPrice:upper():find("EQUIPPED")
                or rawPrice:upper():find("NO STOCK") or rawPrice:upper():find("SOLD") then
                    displayPrice=dbPrice
                end
                table.insert(items,{
                    name=name, price=displayPrice, dbPrice=dbPrice,
                    rarity=dbRarity, stock=stock, inStock=inStock,
                })
            end
        end
    end)
    return items
end

-- ── Update display ─────────────────────────────────────────────────────────────
local function updateDisplay(sc,statsLbl,items)
    for _,child in pairs(sc:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local inCount=0
    local sorted={}
    for _,item in ipairs(items) do table.insert(sorted,item) end
    table.sort(sorted,function(a,b)
        if a.inStock~=b.inStock then return a.inStock end
        local ai,bi=99,99
        for i,tier in ipairs(TIER_ORDER) do
            if a.rarity==tier then ai=i end
            if b.rarity==tier then bi=i end
        end
        return ai<bi
    end)
    for i,item in ipairs(sorted) do
        makeItemRow(sc,item,i)
        if item.inStock then inCount=inCount+1 end
    end
    sc.CanvasSize=UDim2.new(0,0,0,#items*34+4)
    statsLbl.Text="✅ "..inCount.." in stock  ·  "..#items.." total  ·  "..os.date("%H:%M:%S")
    statsLbl.TextColor3=inCount>0 and C.Green or C.Sub
end

-- ── Extract stock count from stock text ───────────────────────────────────────
local function getStockCount(stockText)
    if not stockText then return "" end
    local num=stockText:match("x(%d+)")
    return num and num.."x" or ""
end

-- ── Build combined Discord payload (new format) ────────────────────────────────
local function buildCombinedPayload(seedItems, gearItems, crateItems, weatherList)
    -- Build Seeds section
    local seedLines={}
    local seedMentions={}
    for _,item in ipairs(seedItems) do
        if item.inStock then
            local emoji=SEED_EMOJI[item.name] or "🌱"
            local count=getStockCount(item.stock)
            table.insert(seedLines, emoji.." "..count.." - "..item.name)
            table.insert(seedMentions, "@"..item.name)
        end
    end

    -- Build Gear section
    local gearLines={}
    local gearMentions={}
    for _,item in ipairs(gearItems) do
        if item.inStock then
            local emoji=GEAR_EMOJI[item.name] or "⚙️"
            local count=getStockCount(item.stock)
            table.insert(gearLines, emoji.." "..count.." - "..item.name)
            table.insert(gearMentions, "@"..item.name)
        end
    end

    -- Build Crates section
    local crateLines={}
    for _,item in ipairs(crateItems) do
        if item.inStock then
            local count=getStockCount(item.stock)
            table.insert(crateLines, "📦 "..count.." - "..item.name)
        end
    end

    -- Build description
    local desc=""
    if #seedLines>0 then
        desc=desc.."**SEEDS STOCK**\n"..table.concat(seedLines,"\n")
    end
    if #gearLines>0 then
        if desc~="" then desc=desc.."\n\n" end
        desc=desc.."**GEARS STOCK**\n"..table.concat(gearLines,"\n")
    end
    if #crateLines>0 then
        if desc~="" then desc=desc.."\n\n" end
        desc=desc.."**CRATES STOCK**\n"..table.concat(crateLines,"\n")
    end
    if #weatherList>0 then
        local wxLines={}
        for _,w in ipairs(weatherList) do
            local emoji=WEATHER_EMOJI[w.name] or "🌤️"
            table.insert(wxLines, emoji.." "..w.name.." — "..w.time)
        end
        if desc~="" then desc=desc.."\n\n" end
        desc=desc.."**WEATHER**\n"..table.concat(wxLines,"\n")
    end

    if desc=="" then desc="No items currently in stock" end

    -- Top color based on rarest item
    local topColor=RI.Common
    local allItems={}
    for _,i in ipairs(seedItems) do if i.inStock then table.insert(allItems,i) end end
    for _,i in ipairs(gearItems) do if i.inStock then table.insert(allItems,i) end end
    for _,i in ipairs(crateItems) do if i.inStock then table.insert(allItems,i) end end
    for _,item in ipairs(allItems) do
        for _,tier in ipairs(TIER_ORDER) do
            if item.rarity==tier then topColor=RI[tier] or topColor break end
        end
    end

    -- Mentions line (like the screenshot)
    local allMentions={}
    for _,m in ipairs(seedMentions) do table.insert(allMentions,m) end
    for _,m in ipairs(gearMentions) do table.insert(allMentions,m) end
    local mentionContent=#allMentions>0 and table.concat(allMentions," ") or nil

    return HttpService:JSONEncode({
        content=mentionContent,
        embeds={{
            title="🌱 Grow A Garden 2 Stocks",
            description=desc,
            color=topColor,
            footer={text="Grow A Garden 2 Stock · "..os.date("%H:%M")},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
end

-- ── Weather scanner ────────────────────────────────────────────────────────────
local function scanWeather()
    local active={}
    pcall(function()
        local weatherUI=pg:FindFirstChild("WeatherUI")
        if not weatherUI then return end
        local frame=weatherUI:FindFirstChildOfClass("Frame")
        if not frame then return end
        for _,child in pairs(frame:GetChildren()) do
            if child:IsA("ImageLabel") and child.Visible then
                local weatherLbl=child:FindFirstChild("Weather")
                local timeLbl=child:FindFirstChild("Time")
                local name=weatherLbl and weatherLbl.Text or child.Name
                local timeLeft=timeLbl and timeLbl.Text or "?"
                local hasTime=timeLeft~="" and timeLeft~="0s" and timeLeft~="0m 0s"
                if name~="" and hasTime then
                    table.insert(active,{name=name,time=timeLeft})
                end
            end
        end
    end)
    return active
end

local function sendWeatherPing(weather)
    if sentWeatherPings[weather.name] then return end
    sentWeatherPings[weather.name]=true
    local ping=WEATHER_ROLE_PINGS[weather.name]
    if not ping or ping=="" or ping:find("YOUR_ROLE_ID") then return end
    local emoji=WEATHER_EMOJI[weather.name] or "🌤️"
    local color=WEATHER_COLOR[weather.name] or 11393254
    httpPost(WEBHOOK_URL,HttpService:JSONEncode({
        content=ping,
        embeds={{
            title=emoji.." "..weather.name.." Weather Alert!",
            description="**"..weather.name.."** is now active!\n⏱️ Duration: **"..weather.time.."**",
            color=color,
            footer={text="Grow A Garden 2 Stock · Weather Alert"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    }))
end

-- ── Stored items ───────────────────────────────────────────────────────────────
local seedItems,gearItems,crateItems={},{},{}

-- ── Main scan ──────────────────────────────────────────────────────────────────
local function runFullScan(force)
    local newSeeds  = scanShop("SeedShop",  SEED_LIST)
    local newGear   = scanShop("GearShop",  GEAR_LIST)
    local newCrates = scanShop("CrateShop", CRATE_LIST)
    local weather   = scanWeather()

    if #newSeeds  >0 then seedItems  =newSeeds  updateDisplay(seedSc, seedStats, seedItems)  end
    if #newGear   >0 then gearItems  =newGear   updateDisplay(gearSc, gearStats, gearItems)  end
    if #newCrates >0 then crateItems =newCrates  updateDisplay(crateSc,crateStats,crateItems) end

    if WEBHOOK_URL=="" then lastScanLbl.Text="⚠️ No webhook set" return end

    local snapshot={} local changed=force
    for _,item in ipairs(seedItems)  do snapshot["s:"..item.name]=item.stock if lastStockSnapshot["s:"..item.name]~=item.stock then changed=true end end
    for _,item in ipairs(gearItems)  do snapshot["g:"..item.name]=item.stock if lastStockSnapshot["g:"..item.name]~=item.stock then changed=true end end
    for _,item in ipairs(crateItems) do snapshot["c:"..item.name]=item.stock if lastStockSnapshot["c:"..item.name]~=item.stock then changed=true end end

    local wxSnapshot={}
    for _,w in ipairs(weather) do
        wxSnapshot[w.name]=w.time
        if not lastWeather[w.name] and not sentWeatherPings[w.name] then
            sendWeatherPing(w) task.wait(0.5) changed=true
        end
    end
    for k in pairs(sentWeatherPings) do
        if not wxSnapshot[k] then sentWeatherPings[k]=nil end
    end
    for k in pairs(lastWeather) do
        if not wxSnapshot[k] then changed=true end
    end
    lastWeather=wxSnapshot

    if changed then
        local payload=buildCombinedPayload(seedItems,gearItems,crateItems,weather)
        if payload then httpPost(WEBHOOK_URL,payload) end
        lastStockSnapshot=snapshot
    end

    lastScanLbl.Text="Scanned: "..os.date("%H:%M:%S")
end

-- ── Force send per-shop ────────────────────────────────────────────────────────
local function forceSendShop(items,shopName,icon,btn,label)
    if WEBHOOK_URL=="" then btn.Text="⚠️ No webhook!" task.delay(2,function() btn.Text=label end) return end
    btn.Text="⏳ Sending..."
    task.spawn(function()
        local inStock={} local topColor=RI.Common
        for _,item in ipairs(items) do if item.inStock then table.insert(inStock,item) end end
        if #inStock==0 then btn.Text="⚠️ Nothing in stock!" task.delay(2,function() btn.Text=label end) return end
        local lines={}
        for _,item in ipairs(inStock) do
            local emoji=(shopName=="Seeds" and SEED_EMOJI[item.name]) or (shopName=="Gear" and GEAR_EMOJI[item.name]) or "📦"
            local count=getStockCount(item.stock)
            table.insert(lines, emoji.." "..count.." - "..item.name)
            for _,tier in ipairs(TIER_ORDER) do if item.rarity==tier then topColor=RI[tier] or topColor break end end
        end
        local ok=httpPost(WEBHOOK_URL,HttpService:JSONEncode({
            embeds={{
                title=icon.." "..shopName.." Stock ("..#inStock.." in stock)",
                description=table.concat(lines,"\n"),
                color=topColor,
                footer={text="Grow A Garden 2 Stock"},
                timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }))
        btn.Text=ok and "✅ Sent!" or "❌ Failed"
        task.delay(2,function() btn.Text=label end)
    end)
end

seedSend.MouseButton1Click:Connect(function()  forceSendShop(seedItems,"Seeds","🌱",seedSend,"📤  Force Send Seeds to Discord")    end)
gearSend.MouseButton1Click:Connect(function()  forceSendShop(gearItems,"Gear","⚙️",gearSend,"📤  Force Send Gear to Discord")      end)
crateSend.MouseButton1Click:Connect(function() forceSendShop(crateItems,"Crates","📦",crateSend,"📤  Force Send Crates to Discord") end)

seedScan.MouseButton1Click:Connect(function()
    seedScan.Text="🔍 Scanning..."
    task.spawn(function() local i=scanShop("SeedShop",SEED_LIST) if #i>0 then seedItems=i updateDisplay(seedSc,seedStats,i) end seedScan.Text="✅ Done!" task.delay(2,function() seedScan.Text="🔍  Refresh Now" end) end)
end)
gearScan.MouseButton1Click:Connect(function()
    gearScan.Text="🔍 Scanning..."
    task.spawn(function() local i=scanShop("GearShop",GEAR_LIST) if #i>0 then gearItems=i updateDisplay(gearSc,gearStats,i) end gearScan.Text="✅ Done!" task.delay(2,function() gearScan.Text="🔍  Refresh Now" end) end)
end)
crateScan.MouseButton1Click:Connect(function()
    crateScan.Text="🔍 Scanning..."
    task.spawn(function() local i=scanShop("CrateShop",CRATE_LIST) if #i>0 then crateItems=i updateDisplay(crateSc,crateStats,i) end crateScan.Text="✅ Done!" task.delay(2,function() crateScan.Text="🔍  Refresh Now" end) end)
end)

-- ── WEATHER PAGE ───────────────────────────────────────────────────────────────
local WXP=makePage()
hdr(WXP,"  🌤️ WEATHER — active events",0)
local wxCard=Instance.new("Frame",WXP)
wxCard.Size=UDim2.new(1,0,0,210) wxCard.Position=UDim2.new(0,0,0,18)
wxCard.BackgroundColor3=C.Card wxCard.BorderSizePixel=0
Instance.new("UICorner",wxCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wxCard).Color=C.Border
local wxDisplay=Instance.new("TextLabel",wxCard)
wxDisplay.Size=UDim2.new(1,-16,1,-16) wxDisplay.Position=UDim2.new(0,8,0,8)
wxDisplay.BackgroundTransparency=1 wxDisplay.Text="Scanning..."
wxDisplay.TextColor3=C.Sub wxDisplay.TextSize=12 wxDisplay.Font=Enum.Font.Gotham
wxDisplay.TextXAlignment=Enum.TextXAlignment.Left
wxDisplay.TextYAlignment=Enum.TextYAlignment.Top wxDisplay.TextWrapped=true

local wxIconRow=Instance.new("Frame",WXP)
wxIconRow.Size=UDim2.new(1,0,0,40) wxIconRow.Position=UDim2.new(0,0,0,234)
wxIconRow.BackgroundTransparency=1 wxIconRow.BorderSizePixel=0
local wxIconLayout=Instance.new("UIListLayout",wxIconRow)
wxIconLayout.FillDirection=Enum.FillDirection.Horizontal wxIconLayout.Padding=UDim.new(0,4)
local wxIconRefs={}
for _,wx in ipairs({"Rain","Lightning","Bloodmoon","Snowfall","Night","Starfall","Rainbow","Midas"}) do
    local btn=Instance.new("TextButton",wxIconRow)
    btn.Size=UDim2.new(0,46,0,36) btn.BackgroundColor3=C.Card btn.BorderSizePixel=0
    btn.Text=(WEATHER_EMOJI[wx] or "🌤️").."\n"..wx:sub(1,5)
    btn.TextColor3=C.Sub btn.TextSize=9 btn.Font=Enum.Font.Gotham
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",btn).Color=C.Border
    wxIconRefs[wx]=btn
end

local wxSendBtn=abtn(WXP,"📤  Send Weather to Discord",280,C.Accent)
local wxScanBtn=abtn(WXP,"🔍  Refresh Weather",316,Color3.fromRGB(25,100,65),26)

local function refreshWeatherDisplay()
    local active=scanWeather()
    if #active==0 then
        wxDisplay.Text="☀️ No active weather events right now"
        for _,btn in pairs(wxIconRefs) do
            btn.BackgroundColor3=C.Card btn.TextColor3=C.Sub
            local st=btn:FindFirstChildOfClass("UIStroke") if st then st.Color=C.Border st.Thickness=1 end
        end
        return
    end
    local lines={} local activeNames={}
    for _,w in ipairs(active) do
        local emoji=WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines,emoji.." **"..w.name.."**\n⏱️ "..w.time.." remaining")
        activeNames[w.name]=true
    end
    wxDisplay.Text=table.concat(lines,"\n\n")
    for name,btn in pairs(wxIconRefs) do
        if activeNames[name] then
            btn.BackgroundColor3=RARITY_BG.Legendary btn.TextColor3=C.Gold
            local st=btn:FindFirstChildOfClass("UIStroke") if st then st.Color=C.Gold st.Thickness=1.5 end
        else
            btn.BackgroundColor3=C.Card btn.TextColor3=C.Sub
            local st=btn:FindFirstChildOfClass("UIStroke") if st then st.Color=C.Border st.Thickness=1 end
        end
    end
end

wxScanBtn.MouseButton1Click:Connect(function()
    wxScanBtn.Text="🔍 Scanning..."
    task.spawn(function() refreshWeatherDisplay() wxScanBtn.Text="✅ Done!" task.delay(2,function() wxScanBtn.Text="🔍  Refresh Weather" end) end)
end)
wxSendBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then wxSendBtn.Text="⚠️ No webhook!" task.delay(2,function() wxSendBtn.Text="📤  Send Weather to Discord" end) return end
    wxSendBtn.Text="⏳ Sending..."
    task.spawn(function()
        local active=scanWeather()
        if #active==0 then wxSendBtn.Text="⚠️ No active weather!" task.delay(2,function() wxSendBtn.Text="📤  Send Weather to Discord" end) return end
        local lines={} local topColor=11393254
        for _,w in ipairs(active) do
            local emoji=WEATHER_EMOJI[w.name] or "🌤️"
            table.insert(lines,emoji.." **"..w.name.."** — "..w.time.." remaining")
            if WEATHER_COLOR[w.name] then topColor=WEATHER_COLOR[w.name] end
        end
        local ok=httpPost(WEBHOOK_URL,HttpService:JSONEncode({
            embeds={{title="🌤️ Active Weather",description=table.concat(lines,"\n"),color=topColor,footer={text="Grow A Garden 2 Stock"},timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}
        }))
        wxSendBtn.Text=ok and "✅ Sent!" or "❌ Failed"
        task.delay(2,function() wxSendBtn.Text="📤  Send Weather to Discord" end)
    end)
end)

-- ── WEBHOOK PAGE ───────────────────────────────────────────────────────────────
local HKP=makePage()
hdr(HKP,"  DISCORD WEBHOOK",0)
local wCard=Instance.new("Frame",HKP) wCard.Size=UDim2.new(1,0,0,110)
wCard.Position=UDim2.new(0,0,0,16) wCard.BackgroundColor3=C.Card wCard.BorderSizePixel=0
Instance.new("UICorner",wCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wCard).Color=C.Border
local wHint=Instance.new("TextLabel",wCard)
wHint.Size=UDim2.new(1,-16,0,18) wHint.Position=UDim2.new(0,8,0,6) wHint.BackgroundTransparency=1
wHint.Text="Discord Webhook URL (saved permanently):"
wHint.TextColor3=C.Sub wHint.TextSize=11 wHint.Font=Enum.Font.GothamBold
wHint.TextXAlignment=Enum.TextXAlignment.Left
local wBox=Instance.new("TextBox",wCard)
wBox.Size=UDim2.new(1,-16,0,32) wBox.Position=UDim2.new(0,8,0,28) wBox.BackgroundColor3=C.BG
wBox.Text=WEBHOOK_URL wBox.PlaceholderText="https://discord.com/api/webhooks/..."
wBox.TextColor3=C.Text wBox.PlaceholderColor3=C.Sub wBox.TextSize=9 wBox.Font=Enum.Font.Gotham
wBox.TextXAlignment=Enum.TextXAlignment.Left wBox.ClearTextOnFocus=false wBox.BorderSizePixel=0
Instance.new("UICorner",wBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",wBox).PaddingLeft=UDim.new(0,6)
local wSave=abtn(wCard,"💾  Save Webhook Permanently",70,C.Green,28)
wSave.Size=UDim2.new(1,-16,0,28) wSave.Position=UDim2.new(0,8,0,70) wSave.TextSize=11
local wStatus=Instance.new("TextLabel",HKP)
wStatus.Size=UDim2.new(1,0,0,20) wStatus.Position=UDim2.new(0,0,0,134) wStatus.BackgroundTransparency=1
wStatus.Text=WEBHOOK_URL~="" and "✅ Webhook loaded from save!" or "No webhook saved."
wStatus.TextColor3=WEBHOOK_URL~="" and C.Green or C.Sub
wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold wStatus.TextXAlignment=Enum.TextXAlignment.Left
local wTest=abtn(HKP,"🧪  Test Webhook",160,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent
local wClear=abtn(HKP,"🗑  Clear Saved Webhook",198,C.Panel,26)
Instance.new("UIStroke",wClear).Color=C.Red
local wInfo=Instance.new("TextLabel",HKP)
wInfo.Size=UDim2.new(1,0,0,140) wInfo.Position=UDim2.new(0,0,0,232) wInfo.BackgroundTransparency=1
wInfo.Text="Webhook saved locally — auto-loaded every run!\n\nHow to get a webhook:\n1. Discord → channel → ⚙️ Edit → Integrations\n2. Webhooks → New Webhook → Copy URL\n3. Paste above → Save\n\nWeather pings: each weather has its own role ID\n(edit WEATHER_ROLE_PINGS at top of script)\n\nStock format: @item mentions + SEEDS/GEARS/CRATES sections in one embed"
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
            embeds={{title="✅ Grow A Garden 2 Stock — Test",description="Connected!\n🌱 Seeds · ⚙️ Gear · 📦 Crates · 🌤️ Weather",color=3066993,footer={text="Grow A Garden 2 Stock"}}}
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

-- ── Tab switching ──────────────────────────────────────────────────────────────
local tabs={
    Seeds={seedPage,seedTab,seedTabL},     Gear={gearPage,gearTab,gearTabL},
    Crates={cratePage,crateTab,crateTabL}, Weather={WXP,wxTab,wxTabL},
    Webhook={HKP,hookTab,hookTabL},
}
local function switchTab(n)
    for k,v in pairs(tabs) do
        v[1].Visible=(k==n)
        TweenService:Create(v[2],TweenInfo.new(0.15),{BackgroundColor3=(k==n) and C.Accent or C.Card}):Play()
        v[3].TextColor3=(k==n) and C.Text or C.Sub
    end
    if n=="Weather" then refreshWeatherDisplay() end
end
seedTab.MouseButton1Click:Connect(function()  switchTab("Seeds")   end)
gearTab.MouseButton1Click:Connect(function()  switchTab("Gear")    end)
crateTab.MouseButton1Click:Connect(function() switchTab("Crates")  end)
wxTab.MouseButton1Click:Connect(function()    switchTab("Weather") end)
hookTab.MouseButton1Click:Connect(function()  switchTab("Webhook") end)
switchTab("Seeds")

-- ── OFF / ON ───────────────────────────────────────────────────────────────────
offBtn.MouseButton1Click:Connect(function()
    AUTO_ENABLED=not AUTO_ENABLED
    if AUTO_ENABLED then
        offBtn.Text="⏹  Turn OFF" offBtn.BackgroundColor3=C.Red
        autoLbl.Text="🟢 Auto: ON" autoLbl.TextColor3=C.Green
        timerDot.BackgroundColor3=C.Green
    else
        offBtn.Text="▶  Turn ON" offBtn.BackgroundColor3=C.Green
        autoLbl.Text="🔴 Auto: OFF" autoLbl.TextColor3=C.Red
        timerDot.BackgroundColor3=C.Red
    end
end)

forceBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then forceBtn.Text="⚠️ No webhook!" task.delay(2,function() forceBtn.Text="🚀 Force Send All" end) return end
    forceBtn.Text="⏳ Sending..."
    task.spawn(function()
        lastStockSnapshot={} lastWeather={}
        runFullScan(true)
        forceBtn.Text="✅ Done!"
        task.delay(2,function() forceBtn.Text="🚀 Force Send All" end)
    end)
end)

-- ── Auto scan loop ─────────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        if AUTO_ENABLED then pcall(runFullScan,false) end
        task.wait(AUTO_INTERVAL)
    end
end)

-- ── 5-minute restock countdown ─────────────────────────────────────────────────
task.spawn(function()
    while true do
        local remaining=300-(os.time()%300)
        for i=remaining,1,-1 do
            timerLbl.Text=string.format("Next: %d:%02d",math.floor(i/60),i%60)
            task.wait(1)
        end
        timerLbl.Text="🔄 Restocking!"
        timerDot.BackgroundColor3=C.Gold
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            task.wait(3)
            lastStockSnapshot={} lastWeather={}
            pcall(runFullScan,true)
        end
        task.wait(8)
        timerDot.BackgroundColor3=AUTO_ENABLED and C.Green or C.Red
    end
end)

-- ── Drag ───────────────────────────────────────────────────────────────────────
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

task.delay(1.5,function() pcall(runFullScan,true) refreshWeatherDisplay() end)

print("[Grow A Garden 2 Stock v7] Loaded!")
