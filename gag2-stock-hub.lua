-- ╔═══════════════════════════════════════════════════════════════╗
-- ║         GAG2 Stock Hub v2                                    ║
-- ║         Auto + Manual Stock Reporter + Discord Notifier      ║
-- ║         Shops: Seeds · Gear · Props · Weather Alerts         ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local lp               = Players.LocalPlayer
local pg               = lp:WaitForChild("PlayerGui")

if pg:FindFirstChild("GAG2StockHub") then pg:FindFirstChild("GAG2StockHub"):Destroy() end

local WEBHOOK_URL  = ""
local AUTO_ENABLED = false
local AUTO_INTERVAL = 30
local lastSeedStock  = {}
local lastGearStock  = {}
local lastPropsStock = {}
local lastWeather    = {}
local sentWeatherPings = {}

-- ══════════════════════════════════════════════
--   ROLE IDs — Replace YOUR_ROLE_ID with actual Discord role ID
--   To get: Discord Developer Mode ON → right-click role → Copy Role ID
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
    Common=Color3.fromRGB(60,60,60),
    Uncommon=Color3.fromRGB(20,70,35),
    Rare=Color3.fromRGB(20,45,90),
    Epic=Color3.fromRGB(55,25,85),
    Legendary=Color3.fromRGB(80,60,10),
    Mythic=Color3.fromRGB(80,20,20),
    Super=Color3.fromRGB(90,50,10),
    Event=Color3.fromRGB(80,25,60),
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
    Gold=Color3.fromRGB(255,200,50),
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
tdot.BackgroundColor3=C.Accent tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,300,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("🌱 GAG2 Stock Hub",14,C.Text,28,5)
tl("Auto + Manual Reporter  v2",10,C.Sub,28,23)

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
Body.Size=UDim2.new(1,0,1,-42) Body.Position=UDim2.new(0,0,0,42) Body.BackgroundTransparency=1

local isMin=false
minBtn.MouseButton1Click:Connect(function()
    isMin=not isMin Body.Visible=not isMin
    TweenService:Create(Win,TweenInfo.new(0.2),{
        Size=isMin and UDim2.new(0,510,0,42) or UDim2.new(0,510,0,470)
    }):Play()
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

local seedTab,seedTabL  = sideTab("Seeds","🌱",1)
local gearTab,gearTabL  = sideTab("Gear","⚙️",2)
local propTab,propTabL  = sideTab("Props","🪨",3)
local wxTab,wxTabL      = sideTab("Weather","🌤️",4)
local autoTab,autoTabL  = sideTab("Auto","🤖",5)
local hookTab,hookTabL  = sideTab("Webhook","🔗",6)

-- Timer card
local timerCard=Instance.new("Frame",SB)
timerCard.Size=UDim2.new(1,-8,0,52) timerCard.BackgroundColor3=C.Card
timerCard.BorderSizePixel=0 timerCard.LayoutOrder=10
Instance.new("UICorner",timerCard).CornerRadius=UDim.new(0,7)
local timerDot=Instance.new("Frame",timerCard)
timerDot.Size=UDim2.new(0,7,0,7) timerDot.Position=UDim2.new(0,8,0,8)
timerDot.BackgroundColor3=C.Accent timerDot.BorderSizePixel=0
Instance.new("UICorner",timerDot).CornerRadius=UDim.new(1,0)
local function sideLabel(t,sz,y)
    local l=Instance.new("TextLabel",timerCard) l.Size=UDim2.new(1,-8,0,14)
    l.Position=UDim2.new(0,8,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=C.Sub l.TextSize=sz l.Font=Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left return l
end
local timerLbl = sideLabel("Next: --",11,18)
local timerSub = sideLabel("Auto: OFF",9,34)

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
    layout.Padding=UDim.new(0,3)
    layout.SortOrder=Enum.SortOrder.LayoutOrder

    local rarities={"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Super"}
    local active="All"
    local btns={}

    for i,r in ipairs(rarities) do
        local btn=Instance.new("TextButton",bar)
        btn.Size=UDim2.new(0,r=="All" and 28 or 58,0,20)
        btn.BackgroundColor3=r=="All" and C.Accent or (RARITY_BG[r] or C.Card)
        btn.Text=r=="All" and "All" or (RE[r] or "").. " "..r
        btn.TextColor3=r=="All" and Color3.new(1,1,1) or (RC[r] or C.Text)
        btn.TextSize=9 btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0
        btn.LayoutOrder=i
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
        btns[r]=btn

        btn.MouseButton1Click:Connect(function()
            active=r
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

-- ── Scrollable item list with rarity filter ───────────────────────────────────
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
    return sc,lay
end

-- ── Improved Check Row with color-coded rarity tag ────────────────────────────
local function makeCheckRow(parent,item,index,checkedTable)
    local rarity=item.rarity or "Common"
    local col=RC[rarity] or C.Sub
    local bgCol=RARITY_BG[rarity] or C.Card

    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,30) row.BackgroundColor3=Color3.fromRGB(22,22,32)
    row.LayoutOrder=index row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)

    -- Checkbox
    local check=Instance.new("TextButton",row)
    check.Size=UDim2.new(0,20,0,20) check.Position=UDim2.new(0,5,0.5,-10)
    check.BackgroundColor3=C.Border check.Text="" check.BorderSizePixel=0
    Instance.new("UICorner",check).CornerRadius=UDim.new(0,4)
    local checkMark=Instance.new("TextLabel",check)
    checkMark.Size=UDim2.new(1,0,1,0) checkMark.BackgroundTransparency=1
    checkMark.Text="" checkMark.TextColor3=Color3.new(1,1,1)
    checkMark.TextSize=14 checkMark.Font=Enum.Font.GothamBold

    -- Item name
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-145,1,0) nameLbl.Position=UDim2.new(0,30,0,0)
    nameLbl.BackgroundTransparency=1
    nameLbl.Text=(RE[rarity] or "⚪").." "..item.name
    nameLbl.TextColor3=C.Text nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Rarity tag (color coded)
    local tag=Instance.new("TextLabel",row)
    tag.Size=UDim2.new(0,72,0,18) tag.Position=UDim2.new(1,-115,0.5,-9)
    tag.BackgroundColor3=bgCol tag.BorderSizePixel=0
    tag.Text=rarity tag.TextColor3=col
    tag.TextSize=9 tag.Font=Enum.Font.GothamBold
    Instance.new("UICorner",tag).CornerRadius=UDim.new(0,4)
    local tagStroke=Instance.new("UIStroke",tag) tagStroke.Color=col tagStroke.Thickness=1

    -- Price
    local priceLbl=Instance.new("TextLabel",row)
    priceLbl.Size=UDim2.new(0,36,1,0) priceLbl.Position=UDim2.new(1,-38,0,0)
    priceLbl.BackgroundTransparency=1 priceLbl.Text=item.price or "???"
    priceLbl.TextColor3=Color3.fromRGB(100,220,100) priceLbl.TextSize=9
    priceLbl.Font=Enum.Font.Gotham priceLbl.TextXAlignment=Enum.TextXAlignment.Right

    local checked=false
    local function setCheck(v)
        checked=v checkedTable[item.name]=v
        check.BackgroundColor3=v and C.Green or C.Border
        checkMark.Text=v and "✓" or ""
        row.BackgroundColor3=v and Color3.fromRGB(25,45,30) or Color3.fromRGB(22,22,32)
    end
    check.MouseButton1Click:Connect(function() setCheck(not checked) end)
    row.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then setCheck(not checked) end
    end)
    return row, setCheck, rarity
end

-- ── HTTP Post ─────────────────────────────────────────────────────────────────
local function httpPost(url,body)
    local ok,err=false,"timeout" local done=false
    coroutine.wrap(function()
        ok,err=pcall(function()
            httpRequest({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
        end)
        done=true
    end)()
    local t=0 while not done and t<6 do RunService.Heartbeat:Wait() t=t+0.05 end
    return ok,err
end

-- ── Build Discord Embed ───────────────────────────────────────────────────────
local function buildEmbed(shopName,icon,items,itemList,source)
    local lines={} local hasRare=false local topColor=RI.Common
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
    if #lines==0 then return nil,"nothing selected" end
    local payload=HttpService:JSONEncode({
        content=hasRare and "🚨 **Rare item spotted in GaG2!**" or nil,
        embeds={{
            title=icon.." GAG2 — "..shopName.." Stock",
            description="Stock updated · "..os.date("%H:%M").." · "..(source or "Manual"),
            color=topColor,
            fields={{name="Available Items ("..#lines..")",value=table.concat(lines,"\n"),inline=false}},
            footer={text="GAG2 Stock Hub v2"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    return payload,nil
end

-- ── Manual send helper ────────────────────────────────────────────────────────
local function manualSend(checkedMap,shopName,icon,itemList,btn)
    if WEBHOOK_URL=="" then
        btn.Text="⚠️ Set webhook first!"
        task.delay(2,function() btn.Text="📤  Send "..shopName.." to Discord" end) return
    end
    local items={}
    for _,item in ipairs(itemList) do
        if checkedMap[item.name] then table.insert(items,item) end
    end
    if #items==0 then
        btn.Text="⚠️ Nothing checked!"
        task.delay(2,function() btn.Text="📤  Send "..shopName.." to Discord" end) return
    end
    btn.Text="⏳ Sending..."
    task.spawn(function()
        local payload,err=buildEmbed(shopName,icon,items,itemList,"Manual")
        local ok=payload and httpPost(WEBHOOK_URL,payload)
        btn.Text=ok and "✅ Sent!" or "❌ Failed"
        task.delay(2,function() btn.Text="📤  Send "..shopName.." to Discord" end)
    end)
end

-- ── BUILD SHOP PAGE ───────────────────────────────────────────────────────────
local function buildShopPage(itemList,shopName,icon)
    local page=makePage()
    hdr(page,"  "..icon.." "..shopName:upper(),0)

    -- Rarity filter bar
    local rowRefs={}
    local rarityFilter="All"

    local filterBar=makeRarityBar(page,16,function(r)
        rarityFilter=r
        for _,ref in ipairs(rowRefs) do
            ref.row.Visible=(r=="All" or ref.rarity==r)
        end
    end)

    local sc,_=mklist(page,42,240)
    local checked={}

    -- Stats bar
    local statsBar=Instance.new("Frame",page)
    statsBar.Size=UDim2.new(1,0,0,18) statsBar.Position=UDim2.new(0,0,0,286)
    statsBar.BackgroundTransparency=1 statsBar.BorderSizePixel=0
    local statsLbl=Instance.new("TextLabel",statsBar)
    statsLbl.Size=UDim2.new(1,0,1,0) statsLbl.BackgroundTransparency=1
    statsLbl.Text="0 selected" statsLbl.TextColor3=C.Sub
    statsLbl.TextSize=10 statsLbl.Font=Enum.Font.Gotham
    statsLbl.TextXAlignment=Enum.TextXAlignment.Left

    local sendBtn=abtn(page,"📤  Send "..shopName.." to Discord",308,C.Accent)
    local clearBtn=abtn(page,"🗑  Clear All",344,C.Panel,26)
    Instance.new("UIStroke",clearBtn).Color=C.Red

    for i,item in ipairs(itemList) do
        local row,setCheck,rar=makeCheckRow(sc,item,i,checked)
        table.insert(rowRefs,{row=row,rarity=rar})

        -- Update stats on check
        local origCheck=checked
        local origSet=setCheck
        local wrappedSet=function(v)
            origSet(v)
            local count=0
            for _,v2 in pairs(checked) do if v2 then count=count+1 end end
            statsLbl.Text=count.." selected · "..#itemList.." total"
        end
        row:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
            local count=0
            for _,v2 in pairs(checked) do if v2 then count=count+1 end end
            statsLbl.Text=count.." selected · "..#itemList.." total"
        end)
    end
    sc.CanvasSize=UDim2.new(0,0,0,#itemList*34+4)

    sendBtn.MouseButton1Click:Connect(function()
        manualSend(checked,shopName,icon,itemList,sendBtn)
    end)
    clearBtn.MouseButton1Click:Connect(function()
        for _,ref in ipairs(rowRefs) do
            local cb=ref.row:FindFirstChildOfClass("TextButton")
            if cb then
                cb.BackgroundColor3=C.Border
                local cm=cb:FindFirstChildOfClass("TextLabel") if cm then cm.Text="" end
                ref.row.BackgroundColor3=Color3.fromRGB(22,22,32)
            end
        end
        for k in pairs(checked) do checked[k]=false end
        statsLbl.Text="0 selected · "..#itemList.." total"
    end)

    return page, checked
end

-- ── Create shop pages ─────────────────────────────────────────────────────────
local SP, seedChecked = buildShopPage(SEED_LIST, "Seeds", "🌱")
local GP, gearChecked = buildShopPage(GEAR_LIST, "Gear",  "⚙️")
local PP, propChecked = buildShopPage(PROPS_LIST,"Props", "🪨")

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
wxDisplay.TextYAlignment=Enum.TextYAlignment.Top
wxDisplay.TextWrapped=true

local wxSendBtn=abtn(WXP,"📤  Send Current Weather to Discord",222,C.Accent)
local wxScanBtn=abtn(WXP,"🔍  Refresh Weather Scan",260,Color3.fromRGB(25,110,70),26)
local wxLastLbl=Instance.new("TextLabel",WXP)
wxLastLbl.Size=UDim2.new(1,0,0,18) wxLastLbl.Position=UDim2.new(0,0,0,292)
wxLastLbl.BackgroundTransparency=1 wxLastLbl.Text="Last scan: never"
wxLastLbl.TextColor3=C.Sub wxLastLbl.TextSize=10 wxLastLbl.Font=Enum.Font.Gotham
wxLastLbl.TextXAlignment=Enum.TextXAlignment.Left

-- ── Weather Scanner ───────────────────────────────────────────────────────────
local currentWeatherData = {}

local function scanWeather()
    local active = {}
    pcall(function()
        local weatherUI = pg:FindFirstChild("WeatherUI")
        if not weatherUI then return end
        local frame = weatherUI:FindFirstChildOfClass("Frame")
        if not frame then return end
        for _, child in pairs(frame:GetChildren()) do
            if child:IsA("ImageLabel") and child.Visible then
                local weatherLbl = child:FindFirstChild("Weather")
                local timeLbl = child:FindFirstChild("Time")
                local name = weatherLbl and weatherLbl.Text or child.Name
                local timeLeft = timeLbl and timeLbl.Text or "?"
                if name and name ~= "" then
                    table.insert(active, {name=name, time=timeLeft})
                end
            end
        end
    end)
    return active
end

local function updateWeatherDisplay()
    local active = scanWeather()
    currentWeatherData = active
    wxLastLbl.Text = "Last scan: " .. os.date("%H:%M:%S")
    if #active == 0 then
        wxDisplay.Text = "☀️ No active weather events"
        return
    end
    local lines = {}
    for _, w in ipairs(active) do
        local emoji = WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines, emoji .. " **" .. w.name .. "** — " .. w.time .. " remaining")
    end
    wxDisplay.Text = table.concat(lines, "\n")
end

local function sendWeatherToDiscord(weatherList, source)
    if WEBHOOK_URL == "" then return false end
    if #weatherList == 0 then return false end
    local lines = {}
    local topColor = 11393254
    for _, w in ipairs(weatherList) do
        local emoji = WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines, emoji .. " **" .. w.name .. "** — " .. w.time .. " remaining")
        if WEATHER_COLOR[w.name] then topColor = WEATHER_COLOR[w.name] end
    end
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "🌤️ GAG2 — Weather Update",
            description = "Active weather · " .. os.date("%H:%M") .. " · " .. (source or "Manual"),
            color = topColor,
            fields = {{name = "Active Events (" .. #weatherList .. ")", value = table.concat(lines, "\n"), inline = false}},
            footer = {text = "GAG2 Stock Hub v2"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    return httpPost(WEBHOOK_URL, payload)
end

-- Weather role ping
local function sendWeatherPing(weather)
    if sentWeatherPings[weather.name] then return end
    sentWeatherPings[weather.name] = true
    local ping = WEATHER_ROLE_PINGS[weather.name] or "@here"
    local emoji = WEATHER_EMOJI[weather.name] or "🌤️"
    local color = WEATHER_COLOR[weather.name] or 11393254
    local payload = HttpService:JSONEncode({
        content = ping .. " " .. emoji .. " **" .. weather.name .. "** weather has started!",
        embeds = {{
            title = emoji .. " " .. weather.name .. " Weather Alert!",
            description = "**" .. weather.name .. "** is now active!\n⏱️ Duration: " .. weather.time,
            color = color,
            footer = {text = "GAG2 Stock Hub v2 · Weather Alert"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    httpPost(WEBHOOK_URL, payload)
end

wxScanBtn.MouseButton1Click:Connect(function()
    wxScanBtn.Text = "🔍 Scanning..."
    task.spawn(function()
        updateWeatherDisplay()
        wxScanBtn.Text = "✅ Done!"
        task.delay(2, function() wxScanBtn.Text = "🔍  Refresh Weather Scan" end)
    end)
end)

wxSendBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL == "" then
        wxSendBtn.Text = "⚠️ Set webhook first!"
        task.delay(2, function() wxSendBtn.Text = "📤  Send Current Weather to Discord" end) return
    end
    wxSendBtn.Text = "⏳ Sending..."
    task.spawn(function()
        local active = scanWeather()
        local ok = sendWeatherToDiscord(active, "Manual")
        wxSendBtn.Text = ok and "✅ Sent!" or "❌ Failed / No weather"
        task.delay(2, function() wxSendBtn.Text = "📤  Send Current Weather to Discord" end)
    end)
end)

-- ── AUTO PAGE ─────────────────────────────────────────────────────────────────
local AP=makePage()
hdr(AP,"  AUTO NOTIFIER",0)

local autoCard=Instance.new("Frame",AP) autoCard.Size=UDim2.new(1,0,0,120)
autoCard.Position=UDim2.new(0,0,0,16) autoCard.BackgroundColor3=C.Card autoCard.BorderSizePixel=0
Instance.new("UICorner",autoCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",autoCard).Color=C.Border

local autoStatusLbl=Instance.new("TextLabel",autoCard)
autoStatusLbl.Size=UDim2.new(1,-16,0,20) autoStatusLbl.Position=UDim2.new(0,8,0,8)
autoStatusLbl.BackgroundTransparency=1 autoStatusLbl.Text="🔴 Auto Notifier: OFF"
autoStatusLbl.TextColor3=C.Red autoStatusLbl.TextSize=12 autoStatusLbl.Font=Enum.Font.GothamBold
autoStatusLbl.TextXAlignment=Enum.TextXAlignment.Left

local autoInfo=Instance.new("TextLabel",autoCard)
autoInfo.Size=UDim2.new(1,-16,0,80) autoInfo.Position=UDim2.new(0,8,0,30)
autoInfo.BackgroundTransparency=1
autoInfo.Text="Scans weather every 30 seconds · Sends when weather changes\nWeather pings use role IDs from WEATHER_ROLE_PINGS\nPings reset every restock cycle (no duplicates)\n\nNote: Shop auto-scan requires manual tick for now\n(GAG2 uses encrypted networking — shop GUI paths TBD)"
autoInfo.TextColor3=C.Sub autoInfo.TextSize=9 autoInfo.Font=Enum.Font.Gotham
autoInfo.TextXAlignment=Enum.TextXAlignment.Left autoInfo.TextWrapped=true

local autoToggle=abtn(AP,"▶  Start Auto Notifier",142,C.Green)
local wxAutoScan=abtn(AP,"🌤️  Scan Weather & Send Now",180,Color3.fromRGB(30,80,150))
local autoLastLbl=Instance.new("TextLabel",AP)
autoLastLbl.Size=UDim2.new(1,0,0,18) autoLastLbl.Position=UDim2.new(0,0,0,218)
autoLastLbl.BackgroundTransparency=1 autoLastLbl.Text="Last scan: never"
autoLastLbl.TextColor3=C.Sub autoLastLbl.TextSize=10 autoLastLbl.Font=Enum.Font.Gotham
autoLastLbl.TextXAlignment=Enum.TextXAlignment.Left

local autoThread=nil

local function runWeatherScan()
    local active = scanWeather()
    updateWeatherDisplay()

    -- Check for new weather and send pings
    local snapshot = {}
    for _, w in ipairs(active) do
        snapshot[w.name] = w.time
        if not lastWeather[w.name] then
            -- New weather appeared!
            if WEBHOOK_URL ~= "" then
                sendWeatherPing(w)
                task.wait(0.5)
            end
        end
    end

    -- Send full weather update if anything changed
    if #active > 0 then
        local changed = false
        for k in pairs(snapshot) do if not lastWeather[k] then changed=true break end end
        for k in pairs(lastWeather) do if not snapshot[k] then changed=true break end end
        if changed and WEBHOOK_URL ~= "" then
            sendWeatherToDiscord(active, "Auto Scan")
        end
    end

    lastWeather = snapshot
    autoLastLbl.Text = "Last scan: " .. os.date("%H:%M:%S")
end

autoToggle.MouseButton1Click:Connect(function()
    if not AUTO_ENABLED then
        if WEBHOOK_URL=="" then
            autoToggle.Text="⚠️ Set webhook first!"
            task.delay(2,function() autoToggle.Text="▶  Start Auto Notifier" end) return
        end
        AUTO_ENABLED=true
        autoToggle.Text="⏹  Stop Auto Notifier" autoToggle.BackgroundColor3=C.Red
        autoStatusLbl.Text="🟢 Auto Notifier: ON" autoStatusLbl.TextColor3=C.Green
        timerSub.Text="Auto: ON"
        autoThread=task.spawn(function()
            while AUTO_ENABLED do
                runWeatherScan()
                task.wait(AUTO_INTERVAL)
            end
        end)
    else
        AUTO_ENABLED=false
        if autoThread then task.cancel(autoThread) end
        autoToggle.Text="▶  Start Auto Notifier" autoToggle.BackgroundColor3=C.Green
        autoStatusLbl.Text="🔴 Auto Notifier: OFF" autoStatusLbl.TextColor3=C.Red
        timerSub.Text="Auto: OFF"
    end
end)

wxAutoScan.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then
        wxAutoScan.Text="⚠️ Set webhook first!"
        task.delay(2,function() wxAutoScan.Text="🌤️  Scan Weather & Send Now" end) return
    end
    wxAutoScan.Text="⏳ Scanning..."
    task.spawn(function()
        lastWeather={} sentWeatherPings={}
        runWeatherScan()
        wxAutoScan.Text="✅ Done!"
        task.delay(2,function() wxAutoScan.Text="🌤️  Scan Weather & Send Now" end)
    end)
end)

-- ── WEBHOOK PAGE ──────────────────────────────────────────────────────────────
local HKP=makePage()
hdr(HKP,"  DISCORD WEBHOOK",0)
local wCard=Instance.new("Frame",HKP) wCard.Size=UDim2.new(1,0,0,96)
wCard.Position=UDim2.new(0,0,0,16) wCard.BackgroundColor3=C.Card wCard.BorderSizePixel=0
Instance.new("UICorner",wCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wCard).Color=C.Border
local wHint=Instance.new("TextLabel",wCard)
wHint.Size=UDim2.new(1,-16,0,18) wHint.Position=UDim2.new(0,8,0,6) wHint.BackgroundTransparency=1
wHint.Text="Paste your Discord Webhook URL below:"
wHint.TextColor3=C.Sub wHint.TextSize=11 wHint.Font=Enum.Font.GothamBold
wHint.TextXAlignment=Enum.TextXAlignment.Left
local wBox=Instance.new("TextBox",wCard)
wBox.Size=UDim2.new(1,-16,0,32) wBox.Position=UDim2.new(0,8,0,26) wBox.BackgroundColor3=C.BG
wBox.Text="" wBox.PlaceholderText="https://discord.com/api/webhooks/..."
wBox.TextColor3=C.Text wBox.PlaceholderColor3=C.Sub wBox.TextSize=9 wBox.Font=Enum.Font.Gotham
wBox.TextXAlignment=Enum.TextXAlignment.Left wBox.ClearTextOnFocus=false wBox.BorderSizePixel=0
Instance.new("UICorner",wBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",wBox).PaddingLeft=UDim.new(0,6)
local wSave=abtn(wCard,"💾  Save Webhook",64,C.Green,26)
wSave.Size=UDim2.new(1,-16,0,26) wSave.Position=UDim2.new(0,8,0,64) wSave.TextSize=11
local wStatus=Instance.new("TextLabel",HKP)
wStatus.Size=UDim2.new(1,0,0,18) wStatus.Position=UDim2.new(0,0,0,118) wStatus.BackgroundTransparency=1
wStatus.Text="No webhook saved." wStatus.TextColor3=C.Sub wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold
wStatus.TextXAlignment=Enum.TextXAlignment.Left
local wTest=abtn(HKP,"🧪  Test Webhook",142,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent
local wInfo=Instance.new("TextLabel",HKP)
wInfo.Size=UDim2.new(1,0,0,100) wInfo.Position=UDim2.new(0,0,0,184) wInfo.BackgroundTransparency=1
wInfo.Text="How to get a webhook URL:\n1. Open Discord → go to your stock channel\n2. Click ⚙️ Edit Channel → Integrations\n3. Webhooks → New Webhook → Copy Webhook URL\n4. Paste it above and click Save\n\nFor role pings: edit WEATHER_ROLE_PINGS at the top of the script\nReplace YOUR_ROLE_ID with your actual Discord role ID"
wInfo.TextColor3=C.Sub wInfo.TextSize=10 wInfo.Font=Enum.Font.Gotham
wInfo.TextXAlignment=Enum.TextXAlignment.Left wInfo.TextWrapped=true

wSave.MouseButton1Click:Connect(function()
    local url=wBox.Text:gsub("%s+","")
    if url:find("discord.com/api/webhooks/") then
        WEBHOOK_URL=url wStatus.Text="✅ Webhook saved!" wStatus.TextColor3=C.Green
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
                title="✅ GAG2 Stock Hub v2 — Test",
                description="Webhook connected!\n🌱 Seeds · ⚙️ Gear · 🪨 Props · 🌤️ Weather Alerts ready!",
                color=3066993,
                footer={text="GAG2 Stock Hub v2"}
            }}
        }))
        wTest.Text=ok and "✅ Works!" or "❌ Failed"
        wStatus.Text=ok and "✅ Connected!" or "❌ "..tostring(err)
        wStatus.TextColor3=ok and C.Green or C.Red
        task.delay(3,function() wTest.Text="🧪  Test Webhook" end)
    end)
end)

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabs={
    Seeds={SP,seedTab,seedTabL},   Gear={GP,gearTab,gearTabL},
    Props={PP,propTab,propTabL},   Weather={WXP,wxTab,wxTabL},
    Auto={AP,autoTab,autoTabL},    Webhook={HKP,hookTab,hookTabL},
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
autoTab.MouseButton1Click:Connect(function() switchTab("Auto")    end)
hookTab.MouseButton1Click:Connect(function() switchTab("Webhook") end)
switchTab("Seeds")

-- ── 5-minute restock countdown ────────────────────────────────────────────────
task.spawn(function()
    while true do
        local now=os.time()
        local sec=now%300
        local remaining=300-sec
        for i=remaining,1,-1 do
            local m=math.floor(i/60) local s=i%60
            timerLbl.Text=string.format("Next: %d:%02d",m,s)
            task.wait(1)
        end
        timerLbl.Text="🔄 Restocking!"
        timerDot.BackgroundColor3=C.Gold
        -- Reset weather ping tracker on restock
        sentWeatherPings={}
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            task.wait(3)
            runWeatherScan()
            autoLastLbl.Text="Last scan: "..os.date("%H:%M:%S").." (restock)"
        end
        task.wait(8)
        timerDot.BackgroundColor3=C.Accent
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

-- Initial weather scan
task.delay(2, updateWeatherDisplay)

print("[GAG2 Stock Hub v2] Loaded! Seeds · Gear · Props · Weather Alerts")
