-- ╔═══════════════════════════════════════════════════════════════╗
-- ║         GAG2 Stock Hub v1                                    ║
-- ║         Auto + Manual Stock Reporter + Discord Notifier      ║
-- ║         Shops: Seeds · Gear · Props · Events                 ║
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
local AUTO_INTERVAL = 30  -- seconds between auto scans
local lastSeedStock  = {}
local lastGearStock  = {}
local lastPropsStock = {}
local lastEventStock = {}

-- ── Universal HTTP ────────────────────────────────────────────────────────────
local function httpRequest(data)
    if syn and syn.request       then return syn.request(data)
    elseif http and http.request then return http.request(data)
    elseif http_request          then return http_request(data)
    elseif request               then return request(data)
    else warn("[GAG2] No HTTP function found!") end
end

-- ── Item Databases ────────────────────────────────────────────────────────────

-- Seeds (Seed Shop — restocks every 5 min, globally shared)
local SEED_LIST = {
    -- Common
    {name="Carrot",        price="1 Sheckle",    rarity="Common"},
    {name="Strawberry",    price="10 Sheckles",  rarity="Common"},
    {name="Blueberry",     price="25 Sheckles",  rarity="Common"},
    -- Uncommon
    {name="Tulip",         price="40 Sheckles",  rarity="Uncommon"},
    {name="Tomato",        price="200 Sheckles", rarity="Uncommon"},
    {name="Apple",         price="400 Sheckles", rarity="Uncommon"},
    -- Rare
    {name="Bamboo",        price="700 Sheckles", rarity="Rare"},
    {name="Corn",          price="2.5K",         rarity="Rare"},
    {name="Cactus",        price="5K",           rarity="Rare"},
    {name="Pineapple",     price="10K",          rarity="Rare"},
    -- Epic
    {name="Mushroom",      price="15K",          rarity="Epic"},
    {name="Green Bean",    price="???",          rarity="Epic"},
    {name="Banana",        price="30K",          rarity="Epic"},
    {name="Grape",         price="???",          rarity="Epic"},
    {name="Coconut",       price="???",          rarity="Epic"},
    {name="Mango",         price="???",          rarity="Epic"},
    -- Legendary
    {name="Dragon Fruit",  price="120K",         rarity="Legendary"},
    {name="Acorn",         price="200K",         rarity="Legendary"},
    {name="Cherry",        price="???",          rarity="Legendary"},
    {name="Sunflower",     price="???",          rarity="Legendary"},
    -- Mythic
    {name="Venus Fly Trap",price="???",          rarity="Mythic"},
    {name="Pomegranate",   price="2M",           rarity="Mythic"},
    {name="Poison Apple",  price="???",          rarity="Mythic"},
    -- Super
    {name="Moon Bloom",    price="???",          rarity="Super"},
    {name="Dragon's Breath",price="???",         rarity="Super"},
    -- Ghost Pepper Pack exclusives
    {name="Baby Cactus",   price="Pack",         rarity="Rare"},
    {name="Horned Melon",  price="Pack",         rarity="Rare"},
    {name="Glow Mushroom", price="Pack",         rarity="Epic"},
    {name="Poison Ivy",    price="Pack",         rarity="Legendary"},
    {name="Ghost Pepper",  price="Pack",         rarity="Mythic"},
}

-- Gear (Gear Shop NPC George — restocks every 5 min)
local GEAR_LIST = {
    {name="Rainbow Carpet", price="???",  rarity="Legendary"},
    {name="Vine Wrapper",   price="???",  rarity="Rare"},
    {name="Freeze Ray",     price="???",  rarity="Rare"},
    {name="Power Hose",     price="???",  rarity="Uncommon"},
    -- Mushroom consumables (confirmed in gear shop)
    {name="Jump Mushroom",      price="???", rarity="Common"},
    {name="Shrink Mushroom",    price="???", rarity="Common"},
    {name="Invisibility Mushroom", price="???", rarity="Uncommon"},
    {name="Speed Mushroom",     price="???", rarity="Uncommon"},
    {name="Supersized Mushroom",price="???", rarity="Rare"},
}

-- Props (Props Stand in central hub)
local PROPS_LIST = {
    {name="Garden Fence",    price="???", rarity="Common"},
    {name="Scarecrow",       price="???", rarity="Common"},
    {name="Garden Gate",     price="???", rarity="Uncommon"},
    {name="Stone Wall",      price="???", rarity="Uncommon"},
    {name="Watchtower",      price="???", rarity="Rare"},
    {name="Spike Trap",      price="???", rarity="Rare"},
    {name="Guard Gnome",     price="???", rarity="Epic"},
    {name="Alarm Bell",      price="???", rarity="Epic"},
    {name="Dragon Statue",   price="???", rarity="Legendary"},
}

-- Events (rotating event shop)
local EVENT_LIST = {
    {name="Event Seed Pack",   price="???", rarity="Event"},
    {name="Event Pet Egg",     price="???", rarity="Event"},
    {name="Event Decoration",  price="???", rarity="Event"},
    {name="Event Gear",        price="???", rarity="Event"},
    {name="Event Cosmetic",    price="???", rarity="Event"},
    {name="Limited Seed",      price="???", rarity="Limited"},
    {name="Limited Pet",       price="???", rarity="Limited"},
}

-- ── Rarity Styling ────────────────────────────────────────────────────────────
local RC = {
    Common=Color3.fromRGB(180,180,180),   Uncommon=Color3.fromRGB(60,200,100),
    Rare=Color3.fromRGB(80,150,255),      Epic=Color3.fromRGB(180,100,255),
    Legendary=Color3.fromRGB(255,200,50), Mythic=Color3.fromRGB(255,80,80),
    Super=Color3.fromRGB(255,120,50),     Event=Color3.fromRGB(255,120,200),
    Limited=Color3.fromRGB(255,215,0),
}
local RE = {
    Common="⚪",  Uncommon="🟢",   Rare="🔵",    Epic="🟣",
    Legendary="🟡", Mythic="🔴",  Super="🌟",    Event="🌸",   Limited="🏆",
}
local RI = {
    Common=9934743,    Uncommon=3066993,  Rare=3447003,
    Epic=10181046,     Legendary=16750592, Mythic=15158332,
    Super=16737280,    Event=16711935,     Limited=16766720,
}
local RARE_TIERS = {Epic=true,Legendary=true,Mythic=true,Super=true,Event=true,Limited=true}
local TIER_ORDER = {"Super","Mythic","Legendary","Epic","Event","Limited","Rare","Uncommon","Common"}

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
Win.Size=UDim2.new(0,490,0,460) Win.Position=UDim2.new(0.5,-245,0.5,-230)
Win.BackgroundColor3=C.BG Win.BorderSizePixel=0 Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,10)
local ws=Instance.new("UIStroke",Win) ws.Color=C.Border ws.Thickness=1.5

-- Topbar
local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,40) TB.BackgroundColor3=C.Panel TB.BorderSizePixel=0 TB.ZIndex=10

local tdot=Instance.new("Frame",TB)
tdot.Size=UDim2.new(0,10,0,10) tdot.Position=UDim2.new(0,12,0.5,-5)
tdot.BackgroundColor3=C.Accent tdot.BorderSizePixel=0
Instance.new("UICorner",tdot).CornerRadius=UDim.new(1,0)

local function tl(t,sz,col,x,y)
    local l=Instance.new("TextLabel",TB) l.Size=UDim2.new(0,280,0,sz+4)
    l.Position=UDim2.new(0,x,0,y) l.BackgroundTransparency=1 l.Text=t
    l.TextColor3=col l.TextSize=sz l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Left
end
tl("🌱 GAG2 Stock Hub",14,C.Text,28,5)
tl("Auto + Manual Reporter  v1",10,C.Sub,28,22)

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
Body.Size=UDim2.new(1,0,1,-40) Body.Position=UDim2.new(0,0,0,40) Body.BackgroundTransparency=1

local isMin=false
minBtn.MouseButton1Click:Connect(function()
    isMin=not isMin Body.Visible=not isMin
    TweenService:Create(Win,TweenInfo.new(0.2),{
        Size=isMin and UDim2.new(0,490,0,40) or UDim2.new(0,490,0,460)
    }):Play()
end)

-- Sidebar
local SB=Instance.new("Frame",Body)
SB.Size=UDim2.new(0,112,1,0) SB.BackgroundColor3=C.Sidebar SB.BorderSizePixel=0
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
local evtTab,evtTabL    = sideTab("Events","🌸",4)
local autoTab,autoTabL  = sideTab("Auto","🤖",5)
local hookTab,hookTabL  = sideTab("Webhook","🔗",6)

-- Timer in sidebar
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
local timerLbl  = sideLabel("Next: --",11,18)
local timerSub  = sideLabel("Auto: OFF",9,34)

-- Content area
local CT=Instance.new("Frame",Body)
CT.Size=UDim2.new(1,-120,1,-8) CT.Position=UDim2.new(0,116,0,4) CT.BackgroundTransparency=1

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

local function makeCheckRow(parent,item,index,checkedTable)
    local rarity=item.rarity or "Common"
    local col=RC[rarity] or C.Sub
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-4,0,28) row.BackgroundTransparency=1 row.LayoutOrder=index row.BorderSizePixel=0
    local check=Instance.new("TextButton",row)
    check.Size=UDim2.new(0,20,0,20) check.Position=UDim2.new(0,2,0.5,-10)
    check.BackgroundColor3=C.Border check.Text="" check.BorderSizePixel=0
    Instance.new("UICorner",check).CornerRadius=UDim.new(0,4)
    local checkMark=Instance.new("TextLabel",check)
    checkMark.Size=UDim2.new(1,0,1,0) checkMark.BackgroundTransparency=1
    checkMark.Text="" checkMark.TextColor3=Color3.new(1,1,1) checkMark.TextSize=14 checkMark.Font=Enum.Font.GothamBold
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(1,-100,1,0) nameLbl.Position=UDim2.new(0,28,0,0)
    nameLbl.BackgroundTransparency=1 nameLbl.Text=(RE[rarity] or "⚪").." "..item.name
    nameLbl.TextColor3=col nameLbl.TextSize=11 nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    local rarityLbl=Instance.new("TextLabel",row)
    rarityLbl.Size=UDim2.new(0,58,1,0) rarityLbl.Position=UDim2.new(1,-60,0,0)
    rarityLbl.BackgroundTransparency=1 rarityLbl.Text=rarity
    rarityLbl.TextColor3=col rarityLbl.TextSize=9 rarityLbl.Font=Enum.Font.Gotham
    rarityLbl.TextXAlignment=Enum.TextXAlignment.Right
    local checked=false
    local function setCheck(v)
        checked=v checkedTable[item.name]=v
        check.BackgroundColor3=v and C.Green or C.Border
        checkMark.Text=v and "✓" or ""
    end
    check.MouseButton1Click:Connect(function() setCheck(not checked) end)
    return row, setCheck
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
        local priceTxt = item.price and item.price~="" and item.price or price
        table.insert(lines, emoji.." **"..(item.name or item).."** `"..r.."` · "..priceTxt)
    end
    if #lines==0 then return nil,"nothing selected" end
    local payload=HttpService:JSONEncode({
        content=hasRare and "🚨 **Rare item spotted in GaG2!**" or nil,
        embeds={{
            title=icon.." GAG2 — "..shopName.." Stock",
            description="Stock updated · "..os.date("%H:%M").." · "..(source or "Manual"),
            color=topColor,
            fields={{name="Available Items ("..#lines..")",value=table.concat(lines,"\n"),inline=false}},
            footer={text="GAG2 Stock Hub v1"},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    return payload,nil
end

-- ── Auto Scanners ─────────────────────────────────────────────────────────────
-- NOTE: GaG2 is brand new (June 12 2026). These scan the central hub shops.
-- Paths below are best-guess based on GaG1 structure; update if the game changes.

local function scanShopFrame(guiPath, stockChildName)
    local results={}
    pcall(function()
        local frame=pg
        for _,key in ipairs(guiPath) do frame=frame:WaitForChild(key,3) if not frame then return end end
        for _,child in pairs(frame:GetChildren()) do
            local stockLbl=child:FindFirstChild(stockChildName)
            local stock = stockLbl and tonumber(tostring(stockLbl.Text):match("%d+")) or 0
            if stock and stock > 0 then
                table.insert(results,{name=child.Name, stock=stock})
            end
        end
    end)
    return results
end

local function autoScanAndSend(shopKey,icon,shopName,itemList,lastStock)
    if WEBHOOK_URL=="" then return end
    local items={}
    pcall(function()
        -- Generic scan: walk the hub's shop GUIs
        -- Paths will need confirming once GaG2's UI tree is mapped by community
        local root = workspace:FindFirstChild("HubShops") or workspace:FindFirstChild("Shops")
        if not root then return end
        local shopFolder = root:FindFirstChild(shopKey)
        if not shopFolder then return end
        for _,child in pairs(shopFolder:GetChildren()) do
            local stock=0
            local stockPart = child:FindFirstChildWhichIsA("IntValue")
                           or child:FindFirstChild("Stock")
            if stockPart then stock = stockPart.Value or 0 end
            if stock > 0 then
                table.insert(items,{name=child.Name, stock=stock})
            end
        end
    end)
    if #items==0 then return end

    -- Diff check
    local changed=false
    local snapshot={}
    for _,it in ipairs(items) do
        snapshot[it.name]=(it.stock or 1)
        if lastStock[it.name]~=snapshot[it.name] then changed=true end
    end
    if not changed then return end
    for k,v in pairs(snapshot) do lastStock[k]=v end

    local payload,err=buildEmbed(shopName,icon,items,itemList,"Auto Scan")
    if payload then httpPost(WEBHOOK_URL,payload) end
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
local function buildShopPage(itemList,shopName,icon,shopKey,lastStock)
    local pg2=makePage()
    hdr(pg2,"  "..icon.." "..shopName:upper().." — tick what's currently in stock",0)
    local sc,_=mklist(pg2,16,268)
    local checked={}
    local sendBtn=abtn(pg2,"📤  Send "..shopName.." to Discord",290,C.Accent)
    local clearBtn=abtn(pg2,"🗑  Clear All",328,C.Panel,26)
    Instance.new("UIStroke",clearBtn).Color=C.Red
    local scanBtn=abtn(pg2,"🔍  Auto Scan "..shopName.." Now",358,Color3.fromRGB(25,110,70),26)

    for i,item in ipairs(itemList) do makeCheckRow(sc,item,i,checked) end
    sc.CanvasSize=UDim2.new(0,0,0,#itemList*30+4)

    sendBtn.MouseButton1Click:Connect(function()
        manualSend(checked,shopName,icon,itemList,sendBtn)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        for _,row in ipairs(sc:GetChildren()) do
            if row:IsA("Frame") then
                local cb=row:FindFirstChildOfClass("TextButton")
                if cb then
                    cb.BackgroundColor3=C.Border
                    local cm=cb:FindFirstChildOfClass("TextLabel") if cm then cm.Text="" end
                end
            end
        end
        for k in pairs(checked) do checked[k]=false end
    end)

    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text="🔍 Scanning..."
        task.spawn(function()
            -- Try to auto-detect from workspace
            local found=0
            pcall(function()
                local root=workspace:FindFirstChild("HubShops") or workspace:FindFirstChild("Shops")
                if root then
                    local folder=root:FindFirstChild(shopKey)
                    if folder then
                        for _,child in pairs(folder:GetChildren()) do
                            local sv=child:FindFirstChild("Stock")
                            local stock=sv and sv.Value or 0
                            if stock>0 then
                                checked[child.Name]=true found=found+1
                            end
                        end
                    end
                end
            end)
            -- Refresh checkboxes visually
            for _,row in ipairs(sc:GetChildren()) do
                if row:IsA("Frame") then
                    local nameLbl=row:FindFirstChildOfClass("TextLabel")
                    local cb=row:FindFirstChildOfClass("TextButton")
                    if nameLbl and cb then
                        local raw=nameLbl.Text:gsub("^[^%a]+",""):gsub("^%s+","")
                        if checked[raw] then
                            cb.BackgroundColor3=C.Green
                            local cm=cb:FindFirstChildOfClass("TextLabel") if cm then cm.Text="✓" end
                        end
                    end
                end
            end
            scanBtn.Text=found>0 and "✅ Found "..found.." items!" or "⚠️ Shop not found / empty"
            task.delay(3,function() scanBtn.Text="🔍  Auto Scan "..shopName.." Now" end)
        end)
    end)

    return pg2, checked
end

-- ── Create all shop pages ─────────────────────────────────────────────────────
local SP, seedChecked  = buildShopPage(SEED_LIST,  "Seeds", "🌱","SeedShop",  lastSeedStock)
local GP, gearChecked  = buildShopPage(GEAR_LIST,  "Gear",  "⚙️","GearShop",  lastGearStock)
local PP, propChecked  = buildShopPage(PROPS_LIST, "Props", "🪨","PropsShop", lastPropsStock)
local EP, evtChecked   = buildShopPage(EVENT_LIST, "Events","🌸","EventShop", lastEventStock)

-- ── AUTO PAGE ─────────────────────────────────────────────────────────────────
local AP=makePage()
hdr(AP,"  AUTO NOTIFIER — scans every 5 minutes on restock",0)

local autoCard=Instance.new("Frame",AP) autoCard.Size=UDim2.new(1,0,0,116)
autoCard.Position=UDim2.new(0,0,0,16) autoCard.BackgroundColor3=C.Card autoCard.BorderSizePixel=0
Instance.new("UICorner",autoCard).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",autoCard).Color=C.Border

local autoStatusLbl=Instance.new("TextLabel",autoCard)
autoStatusLbl.Size=UDim2.new(1,-16,0,20) autoStatusLbl.Position=UDim2.new(0,8,0,8)
autoStatusLbl.BackgroundTransparency=1 autoStatusLbl.Text="🔴 Auto Notifier: OFF"
autoStatusLbl.TextColor3=C.Red autoStatusLbl.TextSize=12 autoStatusLbl.Font=Enum.Font.GothamBold
autoStatusLbl.TextXAlignment=Enum.TextXAlignment.Left

local autoInfo=Instance.new("TextLabel",autoCard)
autoInfo.Size=UDim2.new(1,-16,0,60) autoInfo.Position=UDim2.new(0,8,0,30)
autoInfo.BackgroundTransparency=1
autoInfo.Text="Scans Seeds, Gear, Props & Events every 5 min.\nOnly sends to Discord when stock changes.\nWorks best while standing at the central hub.\nRequires webhook URL to be saved first."
autoInfo.TextColor3=C.Sub autoInfo.TextSize=10 autoInfo.Font=Enum.Font.Gotham
autoInfo.TextXAlignment=Enum.TextXAlignment.Left autoInfo.TextWrapped=true

local autoToggle=abtn(AP,"▶  Start Auto Notifier",138,C.Green)
local autoScanNow=abtn(AP,"🔍  Force Scan & Send Now",176,C.Accent)
local autoLastLbl=Instance.new("TextLabel",AP)
autoLastLbl.Size=UDim2.new(1,0,0,18) autoLastLbl.Position=UDim2.new(0,0,0,215)
autoLastLbl.BackgroundTransparency=1 autoLastLbl.Text="Last scan: never"
autoLastLbl.TextColor3=C.Sub autoLastLbl.TextSize=10 autoLastLbl.Font=Enum.Font.Gotham
autoLastLbl.TextXAlignment=Enum.TextXAlignment.Left

local autoThread=nil
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
                autoScanAndSend("SeedShop", "🌱","Seeds",  SEED_LIST,  lastSeedStock)
                autoScanAndSend("GearShop", "⚙️","Gear",   GEAR_LIST,  lastGearStock)
                autoScanAndSend("PropsShop","🪨","Props",  PROPS_LIST, lastPropsStock)
                autoScanAndSend("EventShop","🌸","Events", EVENT_LIST, lastEventStock)
                autoLastLbl.Text="Last scan: "..os.date("%H:%M:%S")
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

autoScanNow.MouseButton1Click:Connect(function()
    if WEBHOOK_URL=="" then
        autoScanNow.Text="⚠️ Set webhook first!"
        task.delay(2,function() autoScanNow.Text="🔍  Force Scan & Send Now" end) return
    end
    autoScanNow.Text="⏳ Scanning..."
    task.spawn(function()
        lastSeedStock={} lastGearStock={} lastPropsStock={} lastEventStock={}
        autoScanAndSend("SeedShop", "🌱","Seeds",  SEED_LIST,  lastSeedStock)
        autoScanAndSend("GearShop", "⚙️","Gear",   GEAR_LIST,  lastGearStock)
        autoScanAndSend("PropsShop","🪨","Props",  PROPS_LIST, lastPropsStock)
        autoScanAndSend("EventShop","🌸","Events", EVENT_LIST, lastEventStock)
        autoLastLbl.Text="Last scan: "..os.date("%H:%M:%S")
        autoScanNow.Text="✅ Done!"
        task.delay(2,function() autoScanNow.Text="🔍  Force Scan & Send Now" end)
    end)
end)

-- ── WEBHOOK PAGE ──────────────────────────────────────────────────────────────
local WP=makePage()
hdr(WP,"  DISCORD WEBHOOK",0)

local wCard=Instance.new("Frame",WP) wCard.Size=UDim2.new(1,0,0,96)
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

local wStatus=Instance.new("TextLabel",WP)
wStatus.Size=UDim2.new(1,0,0,18) wStatus.Position=UDim2.new(0,0,0,118) wStatus.BackgroundTransparency=1
wStatus.Text="No webhook saved." wStatus.TextColor3=C.Sub wStatus.TextSize=11 wStatus.Font=Enum.Font.GothamBold
wStatus.TextXAlignment=Enum.TextXAlignment.Left

local wTest=abtn(WP,"🧪  Test Webhook",142,C.Panel)
Instance.new("UIStroke",wTest).Color=C.Accent

local wInfo=Instance.new("TextLabel",WP)
wInfo.Size=UDim2.new(1,0,0,88) wInfo.Position=UDim2.new(0,0,0,184) wInfo.BackgroundTransparency=1
wInfo.Text="How to get a webhook URL:\n1. Open Discord → go to your stock channel\n2. Click ⚙️ Edit Channel → Integrations\n3. Webhooks → New Webhook → Copy Webhook URL\n4. Paste it above and click Save\n\nTip: Make a dedicated #gag2-stock channel for clean alerts!"
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
                title="✅ GAG2 Stock Hub v1 — Test",
                description="Webhook is connected! Seeds · Gear · Props · Events reporter ready. 🌱",
                color=3066993,
                footer={text="GAG2 Stock Hub v1"}
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
    Seeds={SP,seedTab,seedTabL},  Gear={GP,gearTab,gearTabL},
    Props={PP,propTab,propTabL},  Events={EP,evtTab,evtTabL},
    Auto={AP,autoTab,autoTabL},   Webhook={WP,hookTab,hookTabL},
}
local function switchTab(n)
    for k,v in pairs(tabs) do
        v[1].Visible=(k==n)
        TweenService:Create(v[2],TweenInfo.new(0.15),{
            BackgroundColor3=(k==n) and C.Accent or C.Card
        }):Play()
        v[3].TextColor3=(k==n) and C.Text or C.Sub
    end
end
seedTab.MouseButton1Click:Connect(function() switchTab("Seeds")   end)
gearTab.MouseButton1Click:Connect(function() switchTab("Gear")    end)
propTab.MouseButton1Click:Connect(function() switchTab("Props")   end)
evtTab.MouseButton1Click:Connect(function()  switchTab("Events")  end)
autoTab.MouseButton1Click:Connect(function() switchTab("Auto")    end)
hookTab.MouseButton1Click:Connect(function() switchTab("Webhook") end)
switchTab("Seeds")

-- ── 5-minute restock countdown (GaG2 restocks every 5 min like GaG1) ─────────
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
        if AUTO_ENABLED and WEBHOOK_URL~="" then
            task.wait(4) -- wait for shop to actually refresh
            lastSeedStock={} lastGearStock={} lastPropsStock={} lastEventStock={}
            autoScanAndSend("SeedShop", "🌱","Seeds",  SEED_LIST,  lastSeedStock)
            autoScanAndSend("GearShop", "⚙️","Gear",   GEAR_LIST,  lastGearStock)
            autoScanAndSend("PropsShop","🪨","Props",  PROPS_LIST, lastPropsStock)
            autoScanAndSend("EventShop","🌸","Events", EVENT_LIST, lastEventStock)
            if AP:FindFirstChild("Frame") then
                autoLastLbl.Text="Last scan: "..os.date("%H:%M:%S").." (restock)"
            end
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

print("[GAG2 Stock Hub v1] Loaded! Tracking Seeds · Gear · Props · Events")
