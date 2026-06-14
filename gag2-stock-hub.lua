-- ╔═══════════════════════════════════════════════════════════════╗
-- ║         Grow A Garden 2 Stock                                ║
-- ║         Auto Stock Reporter + Discord Notifier               ║
-- ║         Shops: Seeds · Gear · Props · Weather                ║
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
--   ROLE IDs — Replace YOUR_ROLE_ID with actual Discord role ID
--   To get: Developer Mode ON → right-click role → Copy Role ID
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

local WEBHOOK_FILE = "gag2_webhook.txt"
local WEBHOOK_URL  = ""
local AUTO_ENABLED = true -- starts ON automatically
local AUTO_INTERVAL = 30
local lastSeedStock  = {}
local lastGearStock  = {}
local lastPropsStock = {}
local lastWeather    = {}
local sentWeatherPings = {}

-- ── Load saved webhook ────────────────────────────────────────────────────────
pcall(function()
    if isfile and isfile(WEBHOOK_FILE) then
        WEBHOOK_URL = readfile(WEBHOOK_FILE):gsub("%s+","")
    end
end)

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

-- ── Rarity Styling ────────────────────────────────────────────────────────────
local RC = {
    Common=Color3.fromRGB(180,180,180),   Uncommon=Color3.fromRGB(60,200,100),
    Rare=Color3.fromRGB(80,150,255),      Epic=Color3.fromRGB(180,100,255),
    Legendary=Color3.fromRGB(255,200,50), Mythic=Color3.fromRGB(255,80,80),
    Super=Color3.fromRGB(255,140,0),      Event=Color3.fromRGB(255,120,200),
}
local RARITY_BG = {
    Common=Color3.fromRGB(50,50,50),
    Uncommon=Color3.fromRGB(20,60,30),
    Rare=Color3.fromRGB(20,40,80),
    Epic=Color3.fromRGB(50,20,80),
    Legendary=Color3.fromRGB(70,55,10),
    Mythic=Color3.fromRGB(75,15,15),
    Super=Color3.fromRGB(80,45,10),
    Event=Color3.fromRGB(75,20,55),
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
    if not r then return "Common" end
    r = r:sub(1,1):upper() .. r:sub(2):lower()
    return r
end

-- ── Weather config ────────────────────────────────────────────────────────────
local WEATHER_EMOJI = {
    Rain="🌧️", Lightning="⚡", Bloodmoon="🩸", Snowfall="❄️",
    Night="🌙", Starfall="⭐", Rainbow="🌈",
}
local WEATHER_COLOR = {
    Rain=3447003, Lightning=16776960, Bloodmoon=10027008,
    Snowfall=11393254, Night=4456609, Starfall=16750592, Rainbow=11993012,
}

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {
    BG=Color3.fromRGB(13,13,18),      Panel=Color3.fromRGB(20,20,28),
    Card=Color3.fromRGB(26,26,38),    Sidebar=Color3.fromRGB(16,16,24),
    Accent=Color3.fromRGB(60,180,80), Green=Color3.fromRGB(50,200,100),
    Red=Color3.fromRGB(210,60,60),    Text=Color3.fromRGB(235,235,255),
    Sub=Color3.fromRGB(120,120,155),  Border=Color3.fromRGB(40,40,60),
    Gold=Color3.fromRGB(255,200,50),  Row=Color3.fromRGB(22,22,34),
}

-- ── GUI Root ──────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui", pg)
sg.Name="GAG2StockHub" sg.ResetOnSpawn=false sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local Win = Instance.new("Frame", sg)
Win.Size=UDim2.new(0,520,0,480) Win.Position=UDim2.new(0.5,-260,0.5,-240)
Win.BackgroundColor3=C.BG Win.BorderSizePixel=0 Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,12)
local ws=Instance.new("UIStroke",Win) ws.Color=C.Border ws.Thickness=1.5

-- Topbar
local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,44) TB.BackgroundColor3=C.Panel TB.BorderSizePixel=0 TB.ZIndex=10

local tdot=Instance.new("Frame",TB)
tdot.Size=UDim2.new(0,10,0,10) tdot.Position=UDim2.new(0,12,0.5,-5)
tdot.BackgroundColor3=C.Accent tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,320,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("🌱 Grow A Garden 2 Stock",14,C.Text,28,5)
tl("Auto Reporter  v3",10,C.Sub,28,23)

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
    TweenService:Create(Win,TweenInfo.new(0.2),{
        Size=isMin and UDim2.new(0,520,0,44) or UDim2.new(0,520,0,480)
    }):Play()
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

local seedTab,seedTabL = sideTab("Seeds","🌱",1)
local gearTab,gearTabL = sideTab("Gear","⚙️",2)
local propTab,propTabL = sideTab("Props","🪨",3)
local wxTab,wxTabL     = sideTab("Weather","🌤️",4)
local hookTab,hookTabL = sideTab("Webhook","🔗",5)

-- Status card in sidebar
local statusCard=Instance.new("Frame",SB)
statusCard.Size=UDim2.new(1,-8,0,80) statusCard.BackgroundColor3=C.Card
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
local timerLbl   = sideLabel("Next: --",11,18)
local autoLbl    = sideLabel("🟢 Auto: ON",9,34,C.Green)
local lastScanLbl= sideLabel("Scanning...",8,50)

-- OFF button in sidebar
local offBtn=Instance.new("TextButton",SB)
offBtn.Size=UDim2.new(1,-8,0,30) offBtn.BackgroundColor3=C.Red
offBtn.Text="⏹  Turn OFF" offBtn.TextColor3=Color3.new(1,1,1)
offBtn.TextSize=11 offBtn.Font=Enum.Font.GothamBold offBtn.BorderSizePixel=0
offBtn.LayoutOrder=11
Instance.new("UICorner",offBtn).CornerRadius=UDim.new(0,7)

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

-- ── Shop Item Row (display only, no checkbox) ─────────────────────────────────
local function makeItemRow(parent, name, price, rarity, stock, index)
    local r = normalizeRarity(rarity)
    local col = RC[r] or C.Sub
    local bgCol = RARITY_BG[r] or C.Card
    local inStock = stock and not stock:find("NO STOCK") and stock ~= ""

    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,30)
    row.BackgroundColor3=inStock and Color3.fromRGB(22,32,24) or C.Row
    row.LayoutOrder=index row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)

    -- Stock indicator dot
    local dot=Instance.new("Frame",row)
    dot.Size=UDim2.new(0,8,0,8) dot.Position=UDim2.new(0,6,0.5,-4)
    dot.BackgroundColor3=inStock and C.Green or C.Red dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

    -- Item name
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-160,1,0) nameLbl.Position=UDim2.new(0,20,0,0)
    nameLbl.BackgroundTransparency=1
    nameLbl.Text=(RE[r] or "⚪").." "..name
    nameLbl.TextColor3=inStock and C.Text or C.Sub
    nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Rarity tag
    local tag=Instance.new("TextLabel",row)
    tag.Size=UDim2.new(0,68,0,17) tag.Position=UDim2.new(1,-138,0.5,-8)
    tag.BackgroundColor3=bgCol tag.BorderSizePixel=0
    tag.Text=r tag.TextColor3=col
    tag.TextSize=9 tag.Font=Enum.Font.GothamBold
    Instance.new("UICorner",tag).CornerRadius=UDim.new(0,4)
    Instance.new("UIStroke",tag).Color=col

    -- Stock count
    local stockLbl=Instance.new("TextLabel",row)
    stockLbl.Size=UDim2.new(0,62,1,0) stockLbl.Position=UDim2.new(1,-65,0,0)
    stockLbl.BackgroundTransparency=1
    stockLbl.Text=inStock and stock or "No Stock"
    stockLbl.TextColor3=inStock and C.Green or C.Red
    stockLbl.TextSize=9 stockLbl.Font=Enum.Font.Gotham
    stockLbl.TextXAlignment=Enum.TextXAlignment.Right

    return row
end

-- ── Shop page builder ─────────────────────────────────────────────────────────
local function buildDisplayPage(shopName, icon)
    local page=makePage()
    hdr(page,"  "..icon.." "..shopName:upper().." — live stock view",0)

    -- Stats bar
    local statsBar=Instance.new("Frame",page)
    statsBar.Size=UDim2.new(1,0,0,20) statsBar.Position=UDim2.new(0,0,0,16)
    statsBar.BackgroundTransparency=1 statsBar.BorderSizePixel=0
    local statsLbl=Instance.new("TextLabel",statsBar)
    statsLbl.Size=UDim2.new(1,0,1,0) statsLbl.BackgroundTransparency=1
    statsLbl.Text="Waiting for scan..." statsLbl.TextColor3=C.Sub
    statsLbl.TextSize=10 statsLbl.Font=Enum.Font.Gotham
    statsLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- List
    local bg=Instance.new("Frame",page) bg.Size=UDim2.new(1,0,0,300)
    bg.Position=UDim2.new(0,0,0,40) bg.BackgroundColor3=C.Card
    bg.BorderSizePixel=0 bg.ClipsDescendants=true
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",bg).Color=C.Border
    local sc=Instance.new("ScrollingFrame",bg)
    sc.Size=UDim2.new(1,-4,1,-4) sc.Position=UDim2.new(0,2,0,2)
    sc.BackgroundTransparency=1 sc.BorderSizePixel=0
    sc.ScrollBarThickness=2 sc.ScrollBarImageColor3=C.Accent
    local lay=Instance.new("UIListLayout",sc)
    lay.Padding=UDim.new(0,2) lay.SortOrder=Enum.SortOrder.LayoutOrder

    local sendBtn=abtn(page,"📤  Force Send "..shopName.." Stock",348,C.Accent)
    local scanBtn=abtn(page,"🔍  Refresh Scan Now",384,Color3.fromRGB(25,100,65),26)

    return page, sc, lay, statsLbl, sendBtn, scanBtn
end

local seedPage, seedSc, seedLay, seedStats, seedSend, seedScan = buildDisplayPage("Seeds","🌱")
local gearPage, gearSc, gearLay, gearStats, gearSend, gearScan = buildDisplayPage("Gear","⚙️")
local propPage,  propSc,  propLay,  propStats,  propSend,  propScan  = buildDisplayPage("Props","🪨")

-- ── Shop Scanner ──────────────────────────────────────────────────────────────
local function scanShop(guiName)
    local items = {}
    pcall(function()
        local shopGui = pg:FindFirstChild(guiName)
        if not shopGui then return end
        local found = {}
        -- Find all Seed_Text labels (item names)
        for _, v in pairs(shopGui:GetDescendants()) do
            if v:IsA("TextLabel") and v.Name == "Seed_Text" then
                local parent = v.Parent
                if parent then
                    local name = v.Text
                    local costLbl = parent:FindFirstChild("Cost_Text")
                    local rarityLbl = parent:FindFirstChild("Rarity_Text")
                    local stockLbl = parent:FindFirstChild("Stock_Text")
                    local price = costLbl and costLbl.Text or "???"
                    local rarity = rarityLbl and rarityLbl.Text or "Common"
                    local stock = stockLbl and stockLbl.Text or "NO STOCK"
                    if name and name ~= "" and not found[name] then
                        found[name] = true
                        table.insert(items, {
                            name=name, price=price,
                            rarity=normalizeRarity(rarity), stock=stock,
                            inStock=not stock:find("NO STOCK") and stock ~= ""
                        })
                    end
                end
            end
        end
    end)
    return items
end

-- ── Update shop display page ──────────────────────────────────────────────────
local function updateShopDisplay(sc, lay, statsLbl, items)
    for _, child in pairs(sc:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local inStockCount = 0
    for i, item in ipairs(items) do
        makeItemRow(sc, item.name, item.price, item.rarity, item.stock, i)
        if item.inStock then inStockCount = inStockCount + 1 end
    end
    sc.CanvasSize = UDim2.new(0,0,0,#items*34+4)
    statsLbl.Text = inStockCount.." in stock · "..#items.." total items"
end

-- ── Build Discord payload for shop ───────────────────────────────────────────
local function buildShopPayload(shopName, icon, items)
    local inStockItems = {}
    local topColor = RI.Common
    local hasRare = false
    for _, item in ipairs(items) do
        if item.inStock then
            table.insert(inStockItems, item)
            if RARE_TIERS[item.rarity] then hasRare = true end
            for _, tier in ipairs(TIER_ORDER) do
                if item.rarity == tier then
                    topColor = RI[tier] or topColor break
                end
            end
        end
    end
    if #inStockItems == 0 then return nil end
    local lines = {}
    for _, item in ipairs(inStockItems) do
        local emoji = RE[item.rarity] or "⚪"
        table.insert(lines, emoji.." **"..item.name.."** `"..item.rarity.."` · "..item.price.." · "..item.stock)
    end
    return HttpService:JSONEncode({
        content = hasRare and "🚨 **Rare item in Grow A Garden 2!**" or nil,
        embeds = {{
            title = icon.." GAG2 — "..shopName.." Stock",
            description = "Live stock · "..os.date("%H:%M"),
            color = topColor,
            fields = {{name="In Stock ("..#inStockItems..")", value=table.concat(lines,"\n"), inline=false}},
            footer = {text="Grow A Garden 2 Stock"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
end

-- ── Weather Scanner ───────────────────────────────────────────────────────────
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

local function sendWeatherPing(weather)
    if sentWeatherPings[weather.name] then return end
    sentWeatherPings[weather.name] = true
    local ping = WEATHER_ROLE_PINGS[weather.name] or "@here"
    local emoji = WEATHER_EMOJI[weather.name] or "🌤️"
    local color = WEATHER_COLOR[weather.name] or 11393254
    local payload = HttpService:JSONEncode({
        content = ping.." "..emoji.." **"..weather.name.."** weather has started!",
        embeds = {{
            title = emoji.." "..weather.name.." Weather Alert!",
            description = "**"..weather.name.."** is now active!\n⏱️ Duration: "..weather.time,
            color = color,
            footer = {text="Grow A Garden 2 Stock · Weather Alert"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    httpPost(WEBHOOK_URL, payload)
end

local function buildWeatherPayload(weatherList)
    if #weatherList == 0 then return nil end
    local lines = {}
    local topColor = 11393254
    for _, w in ipairs(weatherList) do
        local emoji = WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines, emoji.." **"..w.name.."** — "..w.time.." remaining")
        if WEATHER_COLOR[w.name] then topColor = WEATHER_COLOR[w.name] end
    end
    return HttpService:JSONEncode({
        embeds = {{
            title = "🌤️ GAG2 — Weather Update",
            description = "Active weather · "..os.date("%H:%M"),
            color = topColor,
            fields = {{name="Active Events ("..#weatherList..")", value=table.concat(lines,"\n"), inline=false}},
            footer = {text="Grow A Garden 2 Stock"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
end

-- ── Main scan function ────────────────────────────────────────────────────────
local seedItems, gearItems, propItems = {}, {}, {}

local function runFullScan(force)
    if WEBHOOK_URL == "" then return end

    -- Seeds
    local newSeeds = scanShop("SeedShop")
    if #newSeeds > 0 then
        seedItems = newSeeds
        updateShopDisplay(seedSc, seedLay, seedStats, seedItems)
        local changed = force
        if not force then
            for _, item in ipairs(newSeeds) do
                if lastSeedStock[item.name] ~= item.stock then changed=true break end
            end
        end
        if changed then
            local payload = buildShopPayload("Seeds","🌱",newSeeds)
            if payload then httpPost(WEBHOOK_URL, payload) task.wait(0.5) end
            for _, item in ipairs(newSeeds) do lastSeedStock[item.name]=item.stock end
        end
    end

    -- Gear
    local newGear = scanShop("GearShop")
    if #newGear > 0 then
        gearItems = newGear
        updateShopDisplay(gearSc, gearLay, gearStats, gearItems)
        local changed = force
        if not force then
            for _, item in ipairs(newGear) do
                if lastGearStock[item.name] ~= item.stock then changed=true break end
            end
        end
        if changed then
            local payload = buildShopPayload("Gear","⚙️",newGear)
            if payload then httpPost(WEBHOOK_URL, payload) task.wait(0.5) end
            for _, item in ipairs(newGear) do lastGearStock[item.name]=item.stock end
        end
    end

    -- Props
    local newProps = scanShop("CrateShop")
    if #newProps > 0 then
        propItems = newProps
        updateShopDisplay(propSc, propLay, propStats, propItems)
        local changed = force
        if not force then
            for _, item in ipairs(newProps) do
                if lastPropsStock[item.name] ~= item.stock then changed=true break end
            end
        end
        if changed then
            local payload = buildShopPayload("Props","🪨",newProps)
            if payload then httpPost(WEBHOOK_URL, payload) task.wait(0.5) end
            for _, item in ipairs(newProps) do lastPropsStock[item.name]=item.stock end
        end
    end

    -- Weather
    local active = scanWeather()
    local wxChanged = force
    local snapshot = {}
    for _, w in ipairs(active) do
        snapshot[w.name] = w.time
        if not lastWeather[w.name] then
            wxChanged = true
            sendWeatherPing(w)
            task.wait(0.5)
        end
    end
    for k in pairs(lastWeather) do if not snapshot[k] then wxChanged=true break end end
    if wxChanged and #active > 0 then
        local payload = buildWeatherPayload(active)
        if payload then httpPost(WEBHOOK_URL, payload) end
    end
    lastWeather = snapshot
    lastScanLbl.Text = "Scanned: "..os.date("%H:%M:%S")
end

-- ── Force send buttons ────────────────────────────────────────────────────────
seedSend.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then seedSend.Text="⚠️ Set webhook first!" task.delay(2,function() seedSend.Text="📤  Force Send Seeds Stock" end) return end
    seedSend.Text="⏳ Sending..."
    task.spawn(function()
        local payload=buildShopPayload("Seeds","🌱",seedItems)
        local ok=payload and httpPost(WEBHOOK_URL,payload)
        seedSend.Text=ok and "✅ Sent!" or "❌ No stock data"
        task.delay(2,function() seedSend.Text="📤  Force Send Seeds Stock" end)
    end)
end)
gearSend.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then gearSend.Text="⚠️ Set webhook first!" task.delay(2,function() gearSend.Text="📤  Force Send Gear Stock" end) return end
    gearSend.Text="⏳ Sending..."
    task.spawn(function()
        local payload=buildShopPayload("Gear","⚙️",gearItems)
        local ok=payload and httpPost(WEBHOOK_URL,payload)
        gearSend.Text=ok and "✅ Sent!" or "❌ No stock data"
        task.delay(2,function() gearSend.Text="📤  Force Send Gear Stock" end)
    end)
end)
propSend.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then propSend.Text="⚠️ Set webhook first!" task.delay(2,function() propSend.Text="📤  Force Send Props Stock" end) return end
    propSend.Text="⏳ Sending..."
    task.spawn(function()
        local payload=buildShopPayload("Props","🪨",propItems)
        local ok=payload and httpPost(WEBHOOK_URL,payload)
        propSend.Text=ok and "✅ Sent!" or "❌ No stock data"
        task.delay(2,function() propSend.Text="📤  Force Send Props Stock" end)
    end)
end)
seedScan.MouseButton1Click:Connect(function()
    seedScan.Text="🔍 Scanning..." task.spawn(function() local i=scanShop("SeedShop") if #i>0 then seedItems=i updateShopDisplay(seedSc,seedLay,seedStats,i) end seedScan.Text="✅ Done!" task.delay(2,function() seedScan.Text="🔍  Refresh Scan Now" end) end)
end)
gearScan.MouseButton1Click:Connect(function()
    gearScan.Text="🔍 Scanning..." task.spawn(function() local i=scanShop("GearShop") if #i>0 then gearItems=i updateShopDisplay(gearSc,gearLay,gearStats,i) end gearScan.Text="✅ Done!" task.delay(2,function() gearScan.Text="🔍  Refresh Scan Now" end) end)
end)
propScan.MouseButton1Click:Connect(function()
    propScan.Text="🔍 Scanning..." task.spawn(function() local i=scanShop("CrateShop") if #i>0 then propItems=i updateShopDisplay(propSc,propLay,propStats,i) end propScan.Text="✅ Done!" task.delay(2,function() propScan.Text="🔍  Refresh Scan Now" end) end)
end)

-- ── WEATHER PAGE ──────────────────────────────────────────────────────────────
local WXP=makePage()
hdr(WXP,"  🌤️ WEATHER — active events",0)

local wxCard=Instance.new("Frame",WXP)
wxCard.Size=UDim2.new(1,0,0,200) wxCard.Position=UDim2.new(0,0,0,18)
wxCard.BackgroundColor3=C.Card wxCard.BorderSizePixel=0
Instance.new("UICorner",wxCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",wxCard).Color=C.Border

local wxDisplay=Instance.new("TextLabel",wxCard)
wxDisplay.Size=UDim2.new(1,-16,1,-16) wxDisplay.Position=UDim2.new(0,8,0,8)
wxDisplay.BackgroundTransparency=1 wxDisplay.Text="Scanning..."
wxDisplay.TextColor3=C.Sub wxDisplay.TextSize=12 wxDisplay.Font=Enum.Font.Gotham
wxDisplay.TextXAlignment=Enum.TextXAlignment.Left
wxDisplay.TextYAlignment=Enum.TextYAlignment.Top
wxDisplay.TextWrapped=true

-- Weather icons row
local wxIconRow=Instance.new("Frame",WXP)
wxIconRow.Size=UDim2.new(1,0,0,40) wxIconRow.Position=UDim2.new(0,0,0,226)
wxIconRow.BackgroundTransparency=1 wxIconRow.BorderSizePixel=0
local wxIconLayout=Instance.new("UIListLayout",wxIconRow)
wxIconLayout.FillDirection=Enum.FillDirection.Horizontal
wxIconLayout.Padding=UDim.new(0,4)

local wxIconRefs = {}
for _, wx in ipairs({"Rain","Lightning","Bloodmoon","Snowfall","Night","Starfall","Rainbow"}) do
    local btn=Instance.new("TextButton",wxIconRow)
    btn.Size=UDim2.new(0,50,0,36)
    btn.BackgroundColor3=C.Card btn.BorderSizePixel=0
    btn.Text=(WEATHER_EMOJI[wx] or "🌤️").."\n"..wx:sub(1,4)
    btn.TextColor3=C.Sub btn.TextSize=9 btn.Font=Enum.Font.Gotham
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",btn).Color=C.Border
    wxIconRefs[wx]=btn
end

local wxSendBtn=abtn(WXP,"📤  Force Send Weather to Discord",270,C.Accent)
local wxScanBtn=abtn(WXP,"🔍  Refresh Weather",308,Color3.fromRGB(25,100,65),26)
local wxForceSendAll=abtn(WXP,"🚀  Force Send ALL (Shops + Weather)",338,Color3.fromRGB(80,40,160),26)

local function refreshWeatherDisplay()
    local active=scanWeather()
    if #active==0 then
        wxDisplay.Text="☀️ No active weather events right now"
        for _,btn in pairs(wxIconRefs) do
            btn.BackgroundColor3=C.Card
            btn.TextColor3=C.Sub
        end
        return
    end
    local lines={}
    local activeNames={}
    for _,w in ipairs(active) do
        local emoji=WEATHER_EMOJI[w.name] or "🌤️"
        table.insert(lines,emoji.." **"..w.name.."**  —  ⏱️ "..w.time.." remaining")
        activeNames[w.name]=true
    end
    wxDisplay.Text=table.concat(lines,"\n\n")
    for name,btn in pairs(wxIconRefs) do
        if activeNames[name] then
            btn.BackgroundColor3=RARITY_BG.Epic or C.Accent
            btn.TextColor3=C.Gold
            local st=Instance.new("UIStroke",btn) st.Color=C.Gold st.Thickness=1.5
        else
            btn.BackgroundColor3=C.Card btn.TextColor3=C.Sub
            local st=btn:FindFirstChildOfClass("UIStroke") if st then st:Destroy() end
        end
    end
end

wxScanBtn.MouseButton1Click:Connect(function()
    wxScanBtn.Text="🔍 Scanning..."
    task.spawn(function() refreshWeatherDisplay() wxScanBtn.Text="✅ Done!" task.delay(2,function() wxScanBtn.Text="🔍  Refresh Weather" end) end)
end)
wxSendBtn.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then wxSendBtn.Text="⚠️ Set webhook first!" task.delay(2,function() wxSendBtn.Text="📤  Force Send Weather to Discord" end) return end
    wxSendBtn.Text="⏳ Sending..."
    task.spawn(function()
        local active=scanWeather()
        local payload=buildWeatherPayload(active)
        local ok=payload and httpPost(WEBHOOK_URL,payload)
        wxSendBtn.Text=ok and "✅ Sent!" or "❌ No active weather"
        task.delay(2,function() wxSendBtn.Text="📤  Force Send Weather to Discord" end)
    end)
end)
wxForceSendAll.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then wxForceSendAll.Text="⚠️ Set webhook first!" task.delay(2,function() wxForceSendAll.Text="🚀  Force Send ALL (Shops + Weather)" end) return end
    wxForceSendAll.Text="⏳ Sending all..."
    task.spawn(function()
        lastSeedStock={} lastGearStock={} lastPropsStock={} lastWeather={} sentWeatherPings={}
        runFullScan(true)
        wxForceSendAll.Text="✅ All sent!"
        task.delay(2,function() wxForceSendAll.Text="🚀  Force Send ALL (Shops + Weather)" end)
    end)
end)

-- ── WEBHOOK PAGE ──────────────────────────────────────────────────────────────
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
wBox.Size=UDim2.new(1,-16,0,32) wBox.Position=UDim2.new(0,8,0,26) wBox.BackgroundColor3=C.BG
wBox.Text=WEBHOOK_URL wBox.PlaceholderText="https://discord.com/api/webhooks/..."
wBox.TextColor3=C.Text wBox.PlaceholderColor3=C.Sub wBox.TextSize=9 wBox.Font=Enum.Font.Gotham
wBox.TextXAlignment=Enum.TextXAlignment.Left wBox.ClearTextOnFocus=false wBox.BorderSizePixel=0
Instance.new("UICorner",wBox).CornerRadius=UDim.new(0,5)
Instance.new("UIPadding",wBox).PaddingLeft=UDim.new(0,6)

local wSave=abtn(wCard,"💾  Save Webhook Permanently",66,C.Green,28)
wSave.Size=UDim2.new(1,-16,0,28) wSave.Position=UDim2.new(0,8,0,68) wSave.TextSize=11

local wStatus=Instance.new("TextLabel",HKP)
wStatus.Size=UDim2.new(1,0,0,20) wStatus.Position=UDim2.new(0,0,0,132) wStatus.BackgroundTransparency=1
wStatus.Text=WEBHOOK_URL~="" and "✅ Webhook loaded from save!" or "No webhook saved."
wStatus.TextColor3=WEBHOOK_URL~="" and C.Green or C.Sub
wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold
wStatus.TextXAlignment=Enum.TextXAlignment.Left

local wTest=abtn(HKP,"🧪  Test Webhook",158,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent

local wClear=abtn(HKP,"🗑  Clear Saved Webhook",196,C.Panel,26)
Instance.new("UIStroke",wClear).Color=C.Red

local wInfo=Instance.new("TextLabel",HKP)
wInfo.Size=UDim2.new(1,0,0,120) wInfo.Position=UDim2.new(0,0,0,230) wInfo.BackgroundTransparency=1
wInfo.Text="Your webhook is saved to a local file and loaded automatically every time you execute the script.\n\nHow to get a webhook URL:\n1. Discord → stock channel → ⚙️ Edit Channel\n2. Integrations → Webhooks → New Webhook\n3. Copy Webhook URL → paste above → Save\n\nFor role pings: edit WEATHER_ROLE_PINGS at the top of the script"
wInfo.TextColor3=C.Sub wInfo.TextSize=10 wInfo.Font=Enum.Font.Gotham
wInfo.TextXAlignment=Enum.TextXAlignment.Left wInfo.TextWrapped=true

wSave.MouseButton1Click:Connect(function()
    local url=wBox.Text:gsub("%s+","")
    if url:find("discord.com/api/webhooks/") then
        WEBHOOK_URL=url
        pcall(function() writefile(WEBHOOK_FILE, url) end)
        wStatus.Text="✅ Webhook saved permanently!" wStatus.TextColor3=C.Green
        autoLbl.Text="🟢 Auto: ON"
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
                description="Webhook connected! Auto notifier is running.\n🌱 Seeds · ⚙️ Gear · 🪨 Props · 🌤️ Weather",
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
wClear.MouseButton1Click:Connect(function()
    WEBHOOK_URL=""
    wBox.Text=""
    pcall(function() writefile(WEBHOOK_FILE,"") end)
    wStatus.Text="Webhook cleared." wStatus.TextColor3=C.Sub
end)

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabs={
    Seeds={seedPage,seedTab,seedTabL},
    Gear={gearPage,gearTab,gearTabL},
    Props={propPage,propTab,propTabL},
    Weather={WXP,wxTab,wxTabL},
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
    if n=="Weather" then refreshWeatherDisplay() end
end
seedTab.MouseButton1Click:Connect(function() switchTab("Seeds")   end)
gearTab.MouseButton1Click:Connect(function() switchTab("Gear")    end)
propTab.MouseButton1Click:Connect(function() switchTab("Props")   end)
wxTab.MouseButton1Click:Connect(function()   switchTab("Weather") end)
hookTab.MouseButton1Click:Connect(function() switchTab("Webhook") end)
switchTab("Seeds")

-- ── OFF button ────────────────────────────────────────────────────────────────
offBtn.MouseButton1Click:Connect(function()
    if AUTO_ENABLED then
        AUTO_ENABLED=false
        offBtn.Text="▶  Turn ON"
        offBtn.BackgroundColor3=C.Green
        autoLbl.Text="🔴 Auto: OFF"
        autoLbl.TextColor3=C.Red
        timerDot.BackgroundColor3=C.Red
    else
        AUTO_ENABLED=true
        offBtn.Text="⏹  Turn OFF"
        offBtn.BackgroundColor3=C.Red
        autoLbl.Text="🟢 Auto: ON"
        autoLbl.TextColor3=C.Green
        timerDot.BackgroundColor3=C.Green
    end
end)

-- ── Auto scan loop ────────────────────────────────────────────────────────────
local autoThread = task.spawn(function()
    while true do
        if AUTO_ENABLED then
            runFullScan(false)
        end
        task.wait(AUTO_INTERVAL)
    end
end)

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
        sentWeatherPings={}
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            task.wait(3)
            lastSeedStock={} lastGearStock={} lastPropsStock={} lastWeather={}
            runFullScan(true)
        end
        task.wait(8)
        timerDot.BackgroundColor3=AUTO_ENABLED and C.Green or C.Red
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

-- Initial scan on load
task.delay(1, function()
    runFullScan(true)
    refreshWeatherDisplay()
end)

print("[Grow A Garden 2 Stock v3] Loaded! Auto notifier started.")
