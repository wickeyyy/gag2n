-- ╔═══════════════════════════════════════════════════════════════╗
-- ║     Grow A Garden 2 Stock                                    ║
-- ║     Auto Notifier · Seeds · Gear · Props · Weather Alerts    ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local lp               = Players.LocalPlayer
local pg               = lp:WaitForChild("PlayerGui")

if pg:FindFirstChild("GAG2StockHub") then pg:FindFirstChild("GAG2StockHub"):Destroy() end

-- ── Permanent Webhook save/load ───────────────────────────────────────────────
local WEBHOOK_FILE = "gag2_webhook.txt"
local WEBHOOK_URL  = ""

local function saveWebhook(url)
    WEBHOOK_URL = url
    pcall(function() writefile(WEBHOOK_FILE, url) end)
end

local function loadWebhook()
    local ok, data = pcall(function() return readfile(WEBHOOK_FILE) end)
    if ok and data and data ~= "" then WEBHOOK_URL = data return data end
    return ""
end

local savedUrl = loadWebhook() -- load before GUI builds

-- ── State ─────────────────────────────────────────────────────────────────────
local AUTO_ENABLED   = true   -- starts ON
local AUTO_INTERVAL  = 30
local lastWeather    = {}
local sentWeatherPings = {}

-- ══════════════════════════════════════════════
--   ROLE IDs — Replace YOUR_ROLE_ID with actual Discord role ID
-- ══════════════════════════════════════════════
local WEATHER_ROLE_PINGS = {
    ["Bloodmoon"] = "<@&YOUR_ROLE_ID>",
    ["Rainbow"]   = "<@&YOUR_ROLE_ID>",
    ["Starfall"]  = "<@&YOUR_ROLE_ID>",
    ["Lightning"] = "<@&YOUR_ROLE_ID>",
    ["Rain"]      = "<@&YOUR_ROLE_ID>",
    ["Snowfall"]  = "<@&YOUR_ROLE_ID>",
    ["Night"]     = "<@&YOUR_ROLE_ID>",
}
-- ══════════════════════════════════════════════

-- ── Universal HTTP ────────────────────────────────────────────────────────────
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

-- ── Item Databases ────────────────────────────────────────────────────────────
local SEED_LIST = {
    {name="Carrot",          price="1 Sheckle",    rarity="Common"},
    {name="Strawberry",      price="10 Sheckles",  rarity="Common"},
    {name="Blueberry",       price="25 Sheckles",  rarity="Common"},
    {name="Tulip",           price="40 Sheckles",  rarity="Uncommon"},
    {name="Tomato",          price="200 Sheckles", rarity="Uncommon"},
    {name="Apple",           price="400 Sheckles", rarity="Uncommon"},
    {name="Bamboo",          price="700 Sheckles", rarity="Rare"},
    {name="Corn",            price="2.5K",         rarity="Rare"},
    {name="Cactus",          price="5K",           rarity="Rare"},
    {name="Pineapple",       price="10K",          rarity="Rare"},
    {name="Mushroom",        price="15K",          rarity="Epic"},
    {name="Green Bean",      price="???",          rarity="Epic"},
    {name="Banana",          price="30K",          rarity="Epic"},
    {name="Grape",           price="???",          rarity="Epic"},
    {name="Coconut",         price="???",          rarity="Epic"},
    {name="Mango",           price="???",          rarity="Epic"},
    {name="Dragon Fruit",    price="120K",         rarity="Legendary"},
    {name="Acorn",           price="200K",         rarity="Legendary"},
    {name="Cherry",          price="???",          rarity="Legendary"},
    {name="Sunflower",       price="???",          rarity="Legendary"},
    {name="Venus Fly Trap",  price="???",          rarity="Mythic"},
    {name="Pomegranate",     price="2M",           rarity="Mythic"},
    {name="Poison Apple",    price="???",          rarity="Mythic"},
    {name="Moon Bloom",      price="???",          rarity="Super"},
    {name="Dragon's Breath", price="???",          rarity="Super"},
    {name="Baby Cactus",     price="Pack",         rarity="Rare"},
    {name="Horned Melon",    price="Pack",         rarity="Rare"},
    {name="Glow Mushroom",   price="Pack",         rarity="Epic"},
    {name="Poison Ivy",      price="Pack",         rarity="Legendary"},
    {name="Ghost Pepper",    price="Pack",         rarity="Mythic"},
}

local GEAR_LIST = {
    {name="Rainbow Carpet",        price="???", rarity="Legendary"},
    {name="Vine Wrapper",          price="???", rarity="Rare"},
    {name="Freeze Ray",            price="???", rarity="Rare"},
    {name="Power Hose",            price="???", rarity="Uncommon"},
    {name="Jump Mushroom",         price="???", rarity="Common"},
    {name="Shrink Mushroom",       price="???", rarity="Common"},
    {name="Invisibility Mushroom", price="???", rarity="Uncommon"},
    {name="Speed Mushroom",        price="???", rarity="Uncommon"},
    {name="Supersized Mushroom",   price="???", rarity="Rare"},
}

local PROPS_LIST = {
    {name="Garden Fence",  price="???", rarity="Common"},
    {name="Scarecrow",     price="???", rarity="Common"},
    {name="Garden Gate",   price="???", rarity="Uncommon"},
    {name="Stone Wall",    price="???", rarity="Uncommon"},
    {name="Watchtower",    price="???", rarity="Rare"},
    {name="Spike Trap",    price="???", rarity="Rare"},
    {name="Guard Gnome",   price="???", rarity="Epic"},
    {name="Alarm Bell",    price="???", rarity="Epic"},
    {name="Dragon Statue", price="???", rarity="Legendary"},
}

-- ── Weather config ────────────────────────────────────────────────────────────
local WEATHER_EMOJI = {
    Rain="🌧️", Lightning="⚡", Bloodmoon="🩸", Snowfall="❄️",
    Night="🌙", Starfall="⭐", Rainbow="🌈",
}
local WEATHER_COLOR = {
    Rain=3447003, Lightning=16776960, Bloodmoon=10027008,
    Snowfall=11393254, Night=4456609, Starfall=16750592, Rainbow=11993012,
}

-- ── Rarity Styling ────────────────────────────────────────────────────────────
local RC = {
    Common=Color3.fromRGB(180,180,180),   Uncommon=Color3.fromRGB(60,200,100),
    Rare=Color3.fromRGB(80,150,255),      Epic=Color3.fromRGB(180,100,255),
    Legendary=Color3.fromRGB(255,200,50), Mythic=Color3.fromRGB(255,80,80),
    Super=Color3.fromRGB(255,140,0),      Event=Color3.fromRGB(255,120,200),
    Limited=Color3.fromRGB(255,215,0),
}
local RE = {
    Common="⚪", Uncommon="🟢", Rare="🔵", Epic="🟣",
    Legendary="🟡", Mythic="🔴", Super="🌟", Event="🌸", Limited="🏆",
}
local RI = {
    Common=9934743,    Uncommon=3066993,  Rare=3447003,
    Epic=10181046,     Legendary=16750592, Mythic=15158332,
    Super=16737280,    Event=16711935,     Limited=16766720,
}
local RARITY_BG = {
    Common=Color3.fromRGB(60,60,60),       Uncommon=Color3.fromRGB(20,70,35),
    Rare=Color3.fromRGB(20,45,90),         Epic=Color3.fromRGB(55,25,85),
    Legendary=Color3.fromRGB(80,60,10),    Mythic=Color3.fromRGB(80,20,20),
    Super=Color3.fromRGB(90,50,10),        Event=Color3.fromRGB(80,25,60),
    Limited=Color3.fromRGB(80,65,10),
}
local TIER_ORDER = {"Super","Mythic","Legendary","Epic","Event","Limited","Rare","Uncommon","Common"}
local RARE_TIERS = {Epic=true,Legendary=true,Mythic=true,Super=true,Event=true,Limited=true}

local function getRarity(list, name)
    for _,v in ipairs(list) do
        if v.name==name then return v.rarity, v.price end
    end
    return "Common","???"
end

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {
    BG=Color3.fromRGB(15,15,20),      Panel=Color3.fromRGB(22,22,30),
    Card=Color3.fromRGB(28,28,40),    Sidebar=Color3.fromRGB(18,18,26),
    Accent=Color3.fromRGB(60,180,80), Green=Color3.fromRGB(50,200,100),
    Red=Color3.fromRGB(210,60,60),    Text=Color3.fromRGB(235,235,255),
    Sub=Color3.fromRGB(130,130,165),  Border=Color3.fromRGB(45,45,65),
    Gold=Color3.fromRGB(255,200,50),  Purple=Color3.fromRGB(120,50,200),
}

-- ── GUI Root ──────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui", pg)
sg.Name="GAG2StockHub" sg.ResetOnSpawn=false sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local Win = Instance.new("Frame", sg)
Win.Size=UDim2.new(0,510,0,470) Win.Position=UDim2.new(0.5,-255,0.5,-235)
Win.BackgroundColor3=C.BG Win.BorderSizePixel=0 Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,12)
local ws=Instance.new("UIStroke",Win) ws.Color=C.Border ws.Thickness=1.5

-- Topbar
local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,42) TB.BackgroundColor3=C.Panel TB.BorderSizePixel=0 TB.ZIndex=10

local tdot=Instance.new("Frame",TB)
tdot.Size=UDim2.new(0,10,0,10) tdot.Position=UDim2.new(0,12,0.5,-5)
tdot.BackgroundColor3=C.Green tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,320,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("🌱 Grow A Garden 2 Stock",14,C.Text,28,5)
tl("Auto Notifier · Seeds · Gear · Props · Weather",10,C.Sub,28,23)

local function topBtn(xo,bg,t)
    local b=Instance.new("TextButton",TB)
    b.Size=UDim2.new(0,26,0,26) b.Position=UDim2.new(1,xo,0.5,-13)
    b.BackgroundColor3=bg b.Text=t b.TextColor3=Color3.new(1,1,1)
    b.TextSize=13 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.ZIndex=11
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5) return b
end
topBtn(-10,C.Red,"✕").MouseButton1Click:Connect(function()
    AUTO_ENABLED=false sg:Destroy()
end)
local minBtn=topBtn(-42,Color3.fromRGB(40,40,60),"−")

local Body=Instance.new("Frame",Win)
Body.Size=UDim2.new(1,0,1,-42) Body.Position=UDim2.new(0,0,0,42) Body.BackgroundTransparency=1

local isMin=false
minBtn.MouseButton1Click:Connect(function()
    isMin=not isMin Body.Visible=not isMin
    TweenService:Create(Win,TweenInfo.new(0.2),{
        Size=isMin and UDim2.new(0,510,0,42) or UDim2.new(0,510,0,470)
    }):Play()
    minBtn.Text=isMin and "+" or "−"
end)

-- Sidebar
local SB=Instance.new("Frame",Body)
SB.Size=UDim2.new(0,114,1,0) SB.BackgroundColor3=C.Sidebar SB.BorderSizePixel=0
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

local seedTab,seedTabL = sideTab("Seeds","🌱",1)
local gearTab,gearTabL = sideTab("Gear","⚙️",2)
local propTab,propTabL = sideTab("Props","🪨",3)
local wxTab,wxTabL     = sideTab("Weather","🌤️",4)
local hookTab,hookTabL = sideTab("Webhook","🔗",5)

-- Timer card in sidebar
local timerCard=Instance.new("Frame",SB)
timerCard.Size=UDim2.new(1,-8,0,70) timerCard.BackgroundColor3=C.Card
timerCard.BorderSizePixel=0 timerCard.LayoutOrder=10
Instance.new("UICorner",timerCard).CornerRadius=UDim.new(0,7)
local timerDot=Instance.new("Frame",timerCard)
timerDot.Size=UDim2.new(0,7,0,7) timerDot.Position=UDim2.new(0,8,0,8)
timerDot.BackgroundColor3=C.Green timerDot.BorderSizePixel=0
Instance.new("UICorner",timerDot).CornerRadius=UDim.new(1,0)
local function sideLabel(t,sz,y)
    local l=Instance.new("TextLabel",timerCard) l.Size=UDim2.new(1,-8,0,14)
    l.Position=UDim2.new(0,8,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=C.Sub l.TextSize=sz l.Font=Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left return l
end
local timerLbl  = sideLabel("Next: --",11,18)
local timerSub  = sideLabel("🟢 Auto: ON",9,32)
local timerLast = sideLabel("Scan: waiting",8,46)

-- Stop/Start Auto button in sidebar
local offBtn=Instance.new("TextButton",SB)
offBtn.Size=UDim2.new(1,-8,0,30) offBtn.BackgroundColor3=C.Red
offBtn.Text="⏹ Stop Auto" offBtn.TextColor3=Color3.new(1,1,1)
offBtn.TextSize=11 offBtn.Font=Enum.Font.GothamBold offBtn.BorderSizePixel=0 offBtn.LayoutOrder=11
Instance.new("UICorner",offBtn).CornerRadius=UDim.new(0,7)

offBtn.MouseButton1Click:Connect(function()
    if AUTO_ENABLED then
        AUTO_ENABLED=false
        offBtn.Text="▶ Start Auto" offBtn.BackgroundColor3=C.Green
        timerSub.Text="🔴 Auto: OFF" tdot.BackgroundColor3=C.Red
    else
        AUTO_ENABLED=true
        offBtn.Text="⏹ Stop Auto" offBtn.BackgroundColor3=C.Red
        timerSub.Text="🟢 Auto: ON" tdot.BackgroundColor3=C.Green
    end
end)

-- Content area
local CT=Instance.new("Frame",Body)
CT.Size=UDim2.new(1,-122,1,-8) CT.Position=UDim2.new(0,118,0,4) CT.BackgroundTransparency=1

local function makePage()
    local f=Instance.new("Frame",CT) f.Size=UDim2.new(1,0,1,0) f.BackgroundTransparency=1 f.Visible=false return f
end

-- ── UI Helpers ────────────────────────────────────────────────────────────────
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

-- ── Rarity Filter Bar ─────────────────────────────────────────────────────────
local function makeRarityBar(parent, y, onFilter)
    local bar=Instance.new("Frame",parent)
    bar.Size=UDim2.new(1,0,0,22) bar.Position=UDim2.new(0,0,0,y)
    bar.BackgroundTransparency=1 bar.BorderSizePixel=0
    local layout=Instance.new("UIListLayout",bar)
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.Padding=UDim.new(0,3) layout.SortOrder=Enum.SortOrder.LayoutOrder
    local rarities={"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Super"}
    local btns={}
    for i,r in ipairs(rarities) do
        local btn=Instance.new("TextButton",bar)
        btn.Size=UDim2.new(0,r=="All" and 28 or 58,0,20)
        btn.BackgroundColor3=r=="All" and C.Accent or (RARITY_BG[r] or C.Card)
        btn.Text=r=="All" and "All" or (RE[r] or "").." "..r
        btn.TextColor3=r=="All" and Color3.new(1,1,1) or (RC[r] or C.Text)
        btn.TextSize=9 btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.LayoutOrder=i
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
        btns[r]=btn
        btn.MouseButton1Click:Connect(function()
            for k,b2 in pairs(btns) do
                if k==r then
                    b2.BackgroundColor3=k=="All" and C.Accent or (RC[k] or C.Accent)
                    b2.TextColor3=Color3.new(1,1,1)
                else
                    b2.BackgroundColor3=k=="All" and C.Card or (RARITY_BG[k] or C.Card)
                    b2.TextColor3=k=="All" and C.Sub or (RC[k] or C.Text)
                end
            end
            if onFilter then onFilter(r) end
        end)
    end
    return bar
end

-- ── Scrollable list ───────────────────────────────────────────────────────────
local function mklist(p,y,h)
    local bg=Instance.new("Frame",p) bg.Size=UDim2.new(1,0,0,h)
    bg.Position=UDim2.new(0,0,0,y) bg.BackgroundColor3=C.Card bg.BorderSizePixel=0 bg.ClipsDescendants=true
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",bg).Color=C.Border
    local sc=Instance.new("ScrollingFrame",bg)
    sc.Size=UDim2.new(1,-4,1,-4) sc.Position=UDim2.new(0,2,0,2)
    sc.BackgroundTransparency=1 sc.BorderSizePixel=0
    sc.ScrollBarThickness=2 sc.ScrollBarImageColor3=C.Accent
    local lay=Instance.new("UIListLayout",sc) lay.Padding=UDim.new(0,2) lay.SortOrder=Enum.SortOrder.LayoutOrder
    return sc, lay
end

-- ── HTTP Post ─────────────────────────────────────────────────────────────────
-- ── Build Discord Embed ───────────────────────────────────────────────────────
local function buildEmbed(shopName,icon,items,itemList,source)
    local lines={} local hasRare=false local topColor=RI.Common
    local pingParts, pingsSeen = {}, {}
    for _,item in ipairs(items) do
        local r,price=getRarity(itemList,item.name or item)
        local emoji=RE[r] or "⚪"
        if RARE_TIERS[r] then hasRare=true end
        for _,tier in ipairs(TIER_ORDER) do
            if r==tier then topColor=RI[tier] or topColor break end
        end
        local priceTxt=item.price and item.price~="" and item.price or price
        table.insert(lines,emoji.." **"..(item.name or item).."** `"..r.."` · "..priceTxt)
    end
    if #lines==0 then return nil,"nothing to send" end
    local payload=HttpService:JSONEncode({
        embeds={{
            title=icon.." Grow A Garden 2 — "..shopName.." Stock",
            description="Stock updated · "..os.date("%H:%M").." · "..(source or "Manual"),
            color=topColor,
            fields={{name="Available Items ("..#lines..")",value=table.concat(lines,"\n"),inline=false}},
            footer={text="Grow A Garden 2 Stock"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    return payload,nil
end

-- ── Scan a shop's PlayerGui ───────────────────────────────────────────────────
local function scanShopGui(guiName, shopChildName)
    local results = {}
    pcall(function()
        local gui   = pg:FindFirstChild(guiName)
        if not gui then return end
        local frame = gui:FindFirstChild("Frame")
        if not frame then return end
        local shop  = frame:FindFirstChild(shopChildName) or frame:FindFirstChild("ScrollingFrame")
        if not shop then return end
        local timerLabel = frame:FindFirstChild("Header")
            and frame.Header:FindFirstChild("RefreshIn")
            and frame.Header.RefreshIn:FindFirstChild("Timer")
        local restockTime = timerLabel and timerLabel.Text or "?"
        for _, item in pairs(shop:GetChildren()) do
            if item.Name=="ItemTemplate" or item.Name=="Sheckles_Shelf" or item.Name=="Robux_Shelf" then continue end
            local mf = item:FindFirstChild("Main_Frame")
            if not mf then continue end
            local name   = mf:FindFirstChild("Seed_Text")  and mf.Seed_Text.Text  or item.Name
            local cost   = mf:FindFirstChild("Cost_Text")  and mf.Cost_Text.Text  or "?"
            local rarity = mf:FindFirstChild("Rarity")
                and mf.Rarity:FindFirstChild("Rarity_Text")
                and mf.Rarity.Rarity_Text.Text or "Common"
            local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
            local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"
            if inStock then
                table.insert(results, {name=name, cost=cost, rarity=rarity, stock=stock, price=cost, restockTime=restockTime})
            end
        end
    end)
    return results
end

-- ── Display row (no checkbox, read-only) ─────────────────────────────────────
local function makeDisplayRow(parent, item, index)
    local rarity = item.rarity or "Common"
    local col    = RC[rarity] or C.Sub
    local bgCol  = RARITY_BG[rarity] or C.Card

    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,30) row.BackgroundColor3=Color3.fromRGB(22,22,32)
    row.LayoutOrder=index row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)

    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-145,1,0) nameLbl.Position=UDim2.new(0,8,0,0)
    nameLbl.BackgroundTransparency=1
    nameLbl.Text=(RE[rarity] or "⚪").." "..item.name
    nameLbl.TextColor3=C.Text nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left

    local tag=Instance.new("TextLabel",row)
    tag.Size=UDim2.new(0,72,0,18) tag.Position=UDim2.new(1,-115,0.5,-9)
    tag.BackgroundColor3=bgCol tag.BorderSizePixel=0
    tag.Text=rarity tag.TextColor3=col tag.TextSize=9 tag.Font=Enum.Font.GothamBold
    Instance.new("UICorner",tag).CornerRadius=UDim.new(0,4)
    local ts=Instance.new("UIStroke",tag) ts.Color=col ts.Thickness=1

    if item.stock then
        local stockLbl=Instance.new("TextLabel",row)
        stockLbl.Size=UDim2.new(0,32,1,0) stockLbl.Position=UDim2.new(1,-100,0,0)
        stockLbl.BackgroundTransparency=1 stockLbl.Text="📦"..item.stock
        stockLbl.TextColor3=C.Sub stockLbl.TextSize=9 stockLbl.Font=Enum.Font.Gotham
        stockLbl.TextXAlignment=Enum.TextXAlignment.Left
    end

    local priceLbl=Instance.new("TextLabel",row)
    priceLbl.Size=UDim2.new(0,56,1,0) priceLbl.Position=UDim2.new(1,-60,0,0)
    priceLbl.BackgroundTransparency=1 priceLbl.Text=item.price or item.cost or "???"
    priceLbl.TextColor3=Color3.fromRGB(100,220,100) priceLbl.TextSize=9
    priceLbl.Font=Enum.Font.Gotham priceLbl.TextXAlignment=Enum.TextXAlignment.Right

    return row
end

-- ── Build Shop Page (live scan, no checkboxes) ────────────────────────────────
local function buildShopPage(itemList, shopName, icon, guiName, shopChild)
    local page=makePage()
    hdr(page,"  "..icon.." "..shopName:upper().." — in stock right now",0)

    local rowRefs   = {}
    local rarityFilter = "All"

    local filterBar = makeRarityBar(page, 16, function(r)
        rarityFilter = r
        for _, ref in ipairs(rowRefs) do
            ref.row.Visible = (r=="All" or ref.rarity==r)
        end
    end)

    local sc, _ = mklist(page, 42, 238)

    local emptyLbl=Instance.new("TextLabel",sc)
    emptyLbl.Size=UDim2.new(1,0,0,24) emptyLbl.BackgroundTransparency=1
    emptyLbl.Text="Press 🔍 Refresh to scan the shop" emptyLbl.TextColor3=C.Sub
    emptyLbl.TextSize=11 emptyLbl.Font=Enum.Font.Gotham
    emptyLbl.TextXAlignment=Enum.TextXAlignment.Left emptyLbl.LayoutOrder=0

    local lastScanLbl=Instance.new("TextLabel",page)
    lastScanLbl.Size=UDim2.new(1,0,0,16) lastScanLbl.Position=UDim2.new(0,0,0,284)
    lastScanLbl.BackgroundTransparency=1 lastScanLbl.Text="Last scan: never"
    lastScanLbl.TextColor3=C.Sub lastScanLbl.TextSize=10 lastScanLbl.Font=Enum.Font.Gotham
    lastScanLbl.TextXAlignment=Enum.TextXAlignment.Left

    local sendBtn    = abtn(page,"📤  Send "..shopName.." to Discord",304,C.Accent)
    local refreshBtn = abtn(page,"🔍  Refresh Scan",340,Color3.fromRGB(25,90,60),26)
    local statusLbl  = Instance.new("TextLabel",page)
    statusLbl.Size=UDim2.new(1,0,0,14) statusLbl.Position=UDim2.new(0,0,0,372)
    statusLbl.BackgroundTransparency=1 statusLbl.Text=""
    statusLbl.TextColor3=C.Green statusLbl.TextSize=10 statusLbl.Font=Enum.Font.Gotham
    statusLbl.TextXAlignment=Enum.TextXAlignment.Left

    local currentItems = {}

    local function refreshDisplay()
        -- clear old rows
        for _, ref in ipairs(rowRefs) do ref.row:Destroy() end
        rowRefs = {}
        emptyLbl.Parent = nil

        local items = guiName and scanShopGui(guiName, shopChild) or {}
        currentItems = items
        lastScanLbl.Text = "Last scan: "..os.date("%H:%M:%S").." · "..#items.." in stock"

        if #items == 0 then
            emptyLbl.Text = "⚠️ Shop not open / nothing in stock right now"
            emptyLbl.Parent = sc
            sc.CanvasSize = UDim2.new(0,0,0,28)
            return
        end

        for i, item in ipairs(items) do
            local row = makeDisplayRow(sc, item, i)
            table.insert(rowRefs, {row=row, rarity=item.rarity or "Common"})
        end
        sc.CanvasSize = UDim2.new(0,0,0,#items*32+4)

        -- reapply filter
        if rarityFilter ~= "All" then
            for _, ref in ipairs(rowRefs) do
                ref.row.Visible = (ref.rarity == rarityFilter)
            end
        end
    end

    refreshBtn.MouseButton1Click:Connect(function()
        refreshBtn.Text = "⏳ Scanning..."
        task.spawn(function()
            refreshDisplay()
            refreshBtn.Text = "🔍  Refresh Scan"
        end)
    end)

    sendBtn.MouseButton1Click:Connect(function()
        if WEBHOOK_URL=="" then
            statusLbl.Text="⚠️ Set webhook first!" statusLbl.TextColor3=C.Red
            task.delay(2,function() statusLbl.Text="" end) return
        end
        local items = #currentItems>0 and currentItems or (guiName and scanShopGui(guiName,shopChild) or {})
        if #items==0 then
            statusLbl.Text="⚠️ Nothing found in shop!" statusLbl.TextColor3=C.Red
            task.delay(2,function() statusLbl.Text="" end) return
        end
        sendBtn.Text="⏳ Sending..."
        task.spawn(function()
            local payload,err=buildEmbed(shopName,icon,items,itemList,"Manual")
            local ok=payload and httpPost(WEBHOOK_URL,payload)
            sendBtn.Text=ok and "✅ Sent!" or "❌ Failed"
            statusLbl.Text=ok and ("✅ Sent "..#items.." items!") or "❌ Send failed"
            statusLbl.TextColor3=ok and C.Green or C.Red
            task.delay(2,function()
                sendBtn.Text="📤  Send "..shopName.." to Discord"
                statusLbl.Text=""
            end)
        end)
    end)

    return page, refreshDisplay, function() return currentItems end
end

-- ── Create shop pages ─────────────────────────────────────────────────────────
local SP,refreshSeeds,getSeeds = buildShopPage(SEED_LIST,"Seeds","🌱","SeedShop","NormalShop")
local GP,refreshGear,getGear   = buildShopPage(GEAR_LIST,"Gear","⚙️","GearShop","ScrollingFrame")
local PP,refreshProps,getProps  = buildShopPage(PROPS_LIST,"Props","🪨","CrateShop","ScrollingFrame")

-- ── WEATHER PAGE ──────────────────────────────────────────────────────────────
local WXP=makePage()
hdr(WXP,"  🌤️ WEATHER — current active events",0)

local wxStatusCard=Instance.new("Frame",WXP)
wxStatusCard.Size=UDim2.new(1,0,0,200) wxStatusCard.Position=UDim2.new(0,0,0,16)
wxStatusCard.BackgroundColor3=C.Card wxStatusCard.BorderSizePixel=0
Instance.new("UICorner",wxStatusCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wxStatusCard).Color=C.Border

local wxTitle=Instance.new("TextLabel",wxStatusCard)
wxTitle.Size=UDim2.new(1,-16,0,20) wxTitle.Position=UDim2.new(0,8,0,8)
wxTitle.BackgroundTransparency=1 wxTitle.Text="Live Weather Status"
wxTitle.TextColor3=C.Text wxTitle.TextSize=12 wxTitle.Font=Enum.Font.GothamBold
wxTitle.TextXAlignment=Enum.TextXAlignment.Left

local wxDisplay=Instance.new("TextLabel",wxStatusCard)
wxDisplay.Size=UDim2.new(1,-16,1,-36) wxDisplay.Position=UDim2.new(0,8,0,30)
wxDisplay.BackgroundTransparency=1 wxDisplay.Text="Scanning..."
wxDisplay.TextColor3=C.Sub wxDisplay.TextSize=11 wxDisplay.Font=Enum.Font.Gotham
wxDisplay.TextXAlignment=Enum.TextXAlignment.Left
wxDisplay.TextYAlignment=Enum.TextYAlignment.Top wxDisplay.TextWrapped=true

local wxSendBtn  = abtn(WXP,"📤  Send Current Weather to Discord",222,C.Accent)
local wxScanBtn  = abtn(WXP,"🔍  Refresh Weather Scan",260,Color3.fromRGB(25,110,70),26)
local wxLastLbl  = Instance.new("TextLabel",WXP)
wxLastLbl.Size=UDim2.new(1,0,0,18) wxLastLbl.Position=UDim2.new(0,0,0,292)
wxLastLbl.BackgroundTransparency=1 wxLastLbl.Text="Last scan: never"
wxLastLbl.TextColor3=C.Sub wxLastLbl.TextSize=10 wxLastLbl.Font=Enum.Font.Gotham
wxLastLbl.TextXAlignment=Enum.TextXAlignment.Left

-- ── Weather scanner ───────────────────────────────────────────────────────────
local currentWeatherData = {}

local function scanWeather()
    local active = {}
    pcall(function()
        local weatherUI = pg:FindFirstChild("WeatherUI")
        if not weatherUI then return end
        local frame = weatherUI:FindFirstChildOfClass("Frame")
        if not frame then return end
        for _, child in pairs(frame:GetChildren()) do
            if not child:IsA("ImageLabel") then continue end
            if not child.Visible then continue end
            local weatherLbl = child:FindFirstChild("Weather")
            local timeLbl    = child:FindFirstChild("Time")
            local name     = weatherLbl and weatherLbl.Text or ""
            local timeLeft = timeLbl and timeLbl.Text or "?"
            local hasTime  = timeLeft ~= "" and timeLeft ~= "0s" and timeLeft ~= "0m 0s" and timeLeft ~= "0m" and timeLeft ~= "00:00"
            if name ~= "" and hasTime then
                table.insert(active, {name=name, time=timeLeft})
            end
        end
    end)
    return active
end

local function updateWeatherDisplay()
    local active = scanWeather()
    currentWeatherData = active
    wxLastLbl.Text = "Last scan: "..os.date("%H:%M:%S")
    if #active == 0 then
        wxDisplay.Text = "☀️ No active weather events"
        return
    end
    local lines = {}
    for _, w in ipairs(active) do
        local emoji = WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines, emoji.." **"..w.name.."** — "..w.time.." remaining")
    end
    wxDisplay.Text = table.concat(lines,"\n")
end

local function sendWeatherToDiscord(weatherList, source)
    if WEBHOOK_URL=="" or #weatherList==0 then return false end
    local lines={} local topColor=11393254
    for _, w in ipairs(weatherList) do
        local emoji=WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines,emoji.." **"..w.name.."** — "..w.time.." remaining")
        if WEATHER_COLOR[w.name] then topColor=WEATHER_COLOR[w.name] end
    end
    local payload=HttpService:JSONEncode({
        embeds={{
            title="🌤️ Grow A Garden 2 — Weather Update",
            description="Active weather · "..os.date("%H:%M").." · "..(source or "Manual"),
            color=topColor,
            fields={{name="Active Events ("..#weatherList..")",value=table.concat(lines,"\n"),inline=false}},
            footer={text="Grow A Garden 2 Stock"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    return httpPost(WEBHOOK_URL,payload)
end

local function sendWeatherPing(weather)
    if sentWeatherPings[weather.name] then return end
    sentWeatherPings[weather.name]=true
    local ping=WEATHER_ROLE_PINGS[weather.name]
    if not ping or ping:find("YOUR_ROLE_ID") then return end
    local emoji=WEATHER_EMOJI[weather.name] or "🌤️"
    local color=WEATHER_COLOR[weather.name] or 11393254
    local payload=HttpService:JSONEncode({
        content=ping.." "..emoji.." **"..weather.name.."** weather has started!",
        embeds={{
            title=emoji.." "..weather.name.." Weather Alert!",
            description="**"..weather.name.."** is now active!\n⏱️ Duration: "..weather.time,
            color=color,
            footer={text="Grow A Garden 2 Stock · Weather Alert"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    httpPost(WEBHOOK_URL,payload)
end

wxScanBtn.MouseButton1Click:Connect(function()
    wxScanBtn.Text="🔍 Scanning..."
    task.spawn(function()
        updateWeatherDisplay()
        wxScanBtn.Text="✅ Done!"
        task.delay(2,function() wxScanBtn.Text="🔍  Refresh Weather Scan" end)
    end)
end)

wxSendBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then
        wxSendBtn.Text="⚠️ Set webhook first!"
        task.delay(2,function() wxSendBtn.Text="📤  Send Current Weather to Discord" end) return
    end
    wxSendBtn.Text="⏳ Sending..."
    task.spawn(function()
        local active=scanWeather()
        local ok=sendWeatherToDiscord(active,"Manual")
        wxSendBtn.Text=ok and "✅ Sent!" or "❌ Failed / No weather"
        task.delay(2,function() wxSendBtn.Text="📤  Send Current Weather to Discord" end)
    end)
end)

-- ── WEBHOOK PAGE ──────────────────────────────────────────────────────────────
local HKP=makePage()
hdr(HKP,"  🔗 DISCORD WEBHOOK",0)

local wCard=Instance.new("Frame",HKP)
wCard.Size=UDim2.new(1,0,0,100) wCard.Position=UDim2.new(0,0,0,16)
wCard.BackgroundColor3=C.Card wCard.BorderSizePixel=0
Instance.new("UICorner",wCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wCard).Color=C.Border

local wHint=Instance.new("TextLabel",wCard)
wHint.Size=UDim2.new(1,-16,0,18) wHint.Position=UDim2.new(0,8,0,6)
wHint.BackgroundTransparency=1 wHint.Text="Webhook URL (saved permanently — no need to re-enter):"
wHint.TextColor3=C.Sub wHint.TextSize=11 wHint.Font=Enum.Font.GothamBold
wHint.TextXAlignment=Enum.TextXAlignment.Left

local wBox=Instance.new("TextBox",wCard)
wBox.Size=UDim2.new(1,-16,0,32) wBox.Position=UDim2.new(0,8,0,28)
wBox.BackgroundColor3=C.BG wBox.Text=savedUrl
wBox.PlaceholderText="https://discord.com/api/webhooks/..."
wBox.TextColor3=C.Text wBox.PlaceholderColor3=C.Sub wBox.TextSize=9 wBox.Font=Enum.Font.Gotham
wBox.TextXAlignment=Enum.TextXAlignment.Left wBox.ClearTextOnFocus=false wBox.BorderSizePixel=0
Instance.new("UICorner",wBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",wBox).PaddingLeft=UDim.new(0,6)

local wSave=Instance.new("TextButton",wCard)
wSave.Size=UDim2.new(1,-16,0,26) wSave.Position=UDim2.new(0,8,0,66)
wSave.BackgroundColor3=C.Green wSave.Text="💾  Save Webhook"
wSave.TextColor3=Color3.new(1,1,1) wSave.TextSize=11 wSave.Font=Enum.Font.GothamBold wSave.BorderSizePixel=0
Instance.new("UICorner",wSave).CornerRadius=UDim.new(0,7)

local wStatus=Instance.new("TextLabel",HKP)
wStatus.Size=UDim2.new(1,0,0,18) wStatus.Position=UDim2.new(0,0,0,122)
wStatus.BackgroundTransparency=1
wStatus.Text=savedUrl~="" and "✅ Webhook loaded from file — ready!" or "⚪ No webhook saved yet"
wStatus.TextColor3=savedUrl~="" and C.Green or C.Sub
wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold wStatus.TextXAlignment=Enum.TextXAlignment.Left

local wTest=abtn(HKP,"🧪  Test Webhook",146,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent

-- Force Notify All button
local forceBtn=abtn(HKP,"🔔  Force Notify All — Seeds · Gear · Props · Weather",184,C.Purple)
local forceLbl=Instance.new("TextLabel",HKP)
forceLbl.Size=UDim2.new(1,0,0,16) forceLbl.Position=UDim2.new(0,0,0,222)
forceLbl.BackgroundTransparency=1 forceLbl.Text=""
forceLbl.TextColor3=C.Green forceLbl.TextSize=10 forceLbl.Font=Enum.Font.Gotham
forceLbl.TextXAlignment=Enum.TextXAlignment.Left

local wInfo=Instance.new("TextLabel",HKP)
wInfo.Size=UDim2.new(1,0,0,100) wInfo.Position=UDim2.new(0,0,0,244)
wInfo.BackgroundTransparency=1
wInfo.Text="How to get a webhook URL:\n1. Discord → your channel → ⚙️ Edit Channel → Integrations\n2. Webhooks → New Webhook → Copy Webhook URL\n3. Paste above and Save — saved permanently, no need to re-enter\n\nFor weather role pings: edit WEATHER_ROLE_PINGS at top of script"
wInfo.TextColor3=C.Sub wInfo.TextSize=10 wInfo.Font=Enum.Font.Gotham
wInfo.TextXAlignment=Enum.TextXAlignment.Left wInfo.TextWrapped=true

wSave.MouseButton1Click:Connect(function()
    local url=wBox.Text:gsub("%s+","")
    if url:find("discord.com/api/webhooks/") then
        saveWebhook(url)
        wStatus.Text="✅ Saved permanently!" wStatus.TextColor3=C.Green
    else
        wStatus.Text="❌ Invalid — must be a Discord webhook URL" wStatus.TextColor3=C.Red
    end
end)

wTest.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then wStatus.Text="⚠️ Save a webhook first!" wStatus.TextColor3=C.Red return end
    wTest.Text="⏳ Testing..."
    task.spawn(function()
        local ok,err=httpPost(WEBHOOK_URL,HttpService:JSONEncode({
            embeds={{
                title="✅ Grow A Garden 2 Stock — Test",
                description="Webhook connected!\n🌱 Seeds · ⚙️ Gear · 🪨 Props · 🌤️ Weather Alerts ready!",
                color=3066993,
                footer={text="Grow A Garden 2 Stock"}
            }}
        }))
        wTest.Text=ok and "✅ Works!" or "❌ Failed"
        wStatus.Text=ok and "✅ Connected!" or "❌ "..tostring(err)
        wStatus.TextColor3=ok and C.Green or C.Red
        task.delay(3,function() wTest.Text="🧪  Test Webhook" end)
    end)
end)

-- Force Notify All
forceBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then
        forceLbl.Text="⚠️ Save a webhook first!" forceLbl.TextColor3=C.Red
        task.delay(2,function() forceLbl.Text="" end) return
    end
    forceBtn.Text="⏳ Sending all..."
    task.spawn(function()
        local sent=0
        local seeds=scanShopGui("SeedShop","NormalShop")
        if #seeds>0 then
            local p=buildEmbed("Seeds","🌱",seeds,SEED_LIST,"Force Notify")
            if p then httpPost(WEBHOOK_URL,p) sent=sent+1 task.wait(0.6) end
        end
        local gear=scanShopGui("GearShop","ScrollingFrame")
        if #gear>0 then
            local p=buildEmbed("Gear","⚙️",gear,GEAR_LIST,"Force Notify")
            if p then httpPost(WEBHOOK_URL,p) sent=sent+1 task.wait(0.6) end
        end
        local props=scanShopGui("CrateShop","ScrollingFrame")
        if #props>0 then
            local p=buildEmbed("Props","🪨",props,PROPS_LIST,"Force Notify")
            if p then httpPost(WEBHOOK_URL,p) sent=sent+1 task.wait(0.6) end
        end
        local weather=scanWeather()
        if #weather>0 then
            sendWeatherToDiscord(weather,"Force Notify")
            sent=sent+1
        end
        forceBtn.Text="🔔  Force Notify All — Seeds · Gear · Props · Weather"
        forceLbl.Text=sent>0 and ("✅ Sent "..sent.." embeds to Discord!") or "⚠️ Nothing found in any shop"
        forceLbl.TextColor3=sent>0 and C.Green or C.Red
        timerLast.Text="Force sent: "..os.date("%H:%M:%S")
        task.delay(4,function() forceLbl.Text="" end)
    end)
end)

-- ── Auto weather scan ─────────────────────────────────────────────────────────
local function runWeatherScan()
    local active=scanWeather()
    updateWeatherDisplay()
    local snapshot={}
    for _, w in ipairs(active) do
        snapshot[w.name]=w.time
        if not lastWeather[w.name] then
            if WEBHOOK_URL~="" then
                sendWeatherPing(w)
                task.wait(0.5)
            end
        end
    end
    if #active>0 then
        local changed=false
        for k in pairs(snapshot) do if not lastWeather[k] then changed=true break end end
        for k in pairs(lastWeather) do if not snapshot[k] then changed=true break end end
        if changed and WEBHOOK_URL~="" then
            sendWeatherToDiscord(active,"Auto Scan")
        end
    end
    -- reset ended weather so it re-alerts next time
    for k in pairs(lastWeather) do
        if not snapshot[k] then lastWeather[k]=nil sentWeatherPings[k]=nil end
    end
    lastWeather=snapshot
    timerLast.Text="Scan: "..os.date("%H:%M:%S")
end

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabs={
    Seeds={SP,seedTab,seedTabL},   Gear={GP,gearTab,gearTabL},
    Props={PP,propTab,propTabL},   Weather={WXP,wxTab,wxTabL},
    Webhook={HKP,hookTab,hookTabL},
}
local function switchTab(n)
    for k,v in pairs(tabs) do
        v[1].Visible=(k==n)
        TweenService:Create(v[2],TweenInfo.new(0.15),{
            BackgroundColor3=(k==n) and C.Accent or C.Card
        }):Play()
        v[3].TextColor3=(k==n) and C.Text or C.Sub
    end
    if n=="Weather" then updateWeatherDisplay() end
end
seedTab.MouseButton1Click:Connect(function() switchTab("Seeds")   end)
gearTab.MouseButton1Click:Connect(function() switchTab("Gear")    end)
propTab.MouseButton1Click:Connect(function() switchTab("Props")   end)
wxTab.MouseButton1Click:Connect(function()   switchTab("Weather") end)
hookTab.MouseButton1Click:Connect(function() switchTab("Webhook") end)
switchTab("Seeds")

-- ── 5-minute restock countdown ────────────────────────────────────────────────
task.spawn(function()
    while sg.Parent do
        local remaining=300-(os.time()%300)
        for i=remaining,1,-1 do
            if not sg.Parent then break end
            timerLbl.Text=string.format("Next: %d:%02d",math.floor(i/60),i%60)
            task.wait(1)
        end
        timerLbl.Text="🔄 Restocking!"
        timerDot.BackgroundColor3=C.Gold
        sentWeatherPings={}
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            task.wait(3)
            runWeatherScan()
            timerLast.Text="Restock scan: "..os.date("%H:%M:%S")
        end
        task.wait(8)
        timerDot.BackgroundColor3=AUTO_ENABLED and C.Green or C.Red
    end
end)

-- ── Auto scan loop — starts immediately ───────────────────────────────────────
task.spawn(function()
    task.wait(2)
    while sg.Parent do
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            pcall(runWeatherScan)
        end
        task.wait(AUTO_INTERVAL)
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

task.delay(2, updateWeatherDisplay)
print("[Grow A Garden 2 Stock] Loaded! Auto-scan ON · Weather alerts active")
