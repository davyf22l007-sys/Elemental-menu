local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local G = (getgenv and getgenv()) or _G
if G.AUTO_ATTACK_CONTROLLER then
    pcall(function() G.AUTO_ATTACK_CONTROLLER.stop() end)
    G.AUTO_ATTACK_CONTROLLER = nil
end

local criarSecaoLabel, obterAlvoAtaques, getClosestPlayer, updateSelectedLabelText, updateToggleLabels

local MAIN_REMOTE = nil
local function gRE()
    if MAIN_REMOTE and MAIN_REMOTE.Parent then
        return MAIN_REMOTE
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local re = remotes:FindFirstChild("RemoteEvent")
        if re then 
            MAIN_REMOTE = re
            return re 
        end
    end
    local re = ReplicatedStorage:FindFirstChild("RemoteEvent")
    if re then
        MAIN_REMOTE = re
        return re
    end
    return nil
end

local EFEITOS_ATIVOS = {}
local EFEITOS_CONFIG = {
    ["Tesla Turret"] = {
        cor = Color3.fromRGB(0, 150, 255),
        tipo = "raios",
        intensidade = 1.5,
        velocidade = 2
    },
    ["Plasma Orbs"] = {
        cor = Color3.fromRGB(255, 100, 0),
        tipo = "plasma",
        intensidade = 1.2,
        velocidade = 1.8
    },
    ["Dark Flames"] = {
        cor = Color3.fromRGB(100, 0, 100),
        tipo = "chamas",
        intensidade = 1.3,
        velocidade = 1.5
    },
    ["Cruel Sun"] = {
        cor = Color3.fromRGB(255, 200, 0),
        tipo = "sol",
        intensidade = 1.4,
        velocidade = 1
    },
    ["Frost Staff"] = {
        cor = Color3.fromRGB(0, 200, 255),
        tipo = "gelo",
        intensidade = 1.1,
        velocidade = 1.2
    }
}

local function criarRemoteEfeitos()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    if not remotes:FindFirstChild("EfeitosVisuais") then
        local re = Instance.new("RemoteEvent")
        re.Name = "EfeitosVisuais"
        re.Parent = remotes
    end
    
    return remotes:FindFirstChild("EfeitosVisuais")
end

local RemoteEfeitos = criarRemoteEfeitos()

local function criarEfeitoRaios(character, config)
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    
    if not rootPart:FindFirstChild("EfeitoAttachment") then
        local attachment = Instance.new("Attachment")
        attachment.Name = "EfeitoAttachment"
        attachment.Parent = rootPart
        
        local particleEmitter = Instance.new("ParticleEmitter")
        particleEmitter.Parent = attachment
        particleEmitter.Texture = "rbxasset://textures/Particles/sparkles_main.dds"
        particleEmitter.Rate = 50 * config.intensidade
        particleEmitter.Lifetime = NumberRange.new(0.5, 1.5)
        particleEmitter.Speed = NumberRange.new(10 * config.velocidade)
        particleEmitter.Acceleration = Vector3.new(0, -5, 0)
        particleEmitter.Color = ColorSequence.new(config.cor)
        particleEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        particleEmitter.Enabled = true
    end
    
    if not character:FindFirstChild("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Parent = character
        highlight.FillColor = config.cor
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.3
        highlight.OutlineTransparency = 0.1
    else
        local highlight = character.Highlight
        highlight.FillColor = config.cor
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.3
        highlight.OutlineTransparency = 0.1
    end
    
    for _, part in pairs(character:GetDescendants()) do
        if (part.Name == "LeftHand" or part.Name == "RightHand" or 
            part.Name == "LeftFoot" or part.Name == "RightFoot") and part:IsA("BasePart") then
            
            if not part:FindFirstChild("TrailAttachment0") then
                local a0 = Instance.new("Attachment")
                a0.Name = "TrailAttachment0"
                a0.Position = Vector3.new(0, 0.5, 0)
                a0.Parent = part

                local a1 = Instance.new("Attachment")
                a1.Name = "TrailAttachment1"
                a1.Position = Vector3.new(0, -0.5, 0)
                a1.Parent = part

                local trail = Instance.new("Trail")
                trail.Name = "EfeitoTrail"
                trail.Attachment0 = a0
                trail.Attachment1 = a1
                trail.Lifetime = 0.5
                trail.MinLength = 0.1
                trail.Color = ColorSequence.new(config.cor)
                trail.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.3),
                    NumberSequenceKeypoint.new(1, 1)
                })
                trail.Parent = part
            end
        end
    end
end

local function removerEfeito(character)
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local attachment = rootPart:FindFirstChild("EfeitoAttachment")
        if attachment then attachment:Destroy() end
    end

    local highlight = character:FindFirstChild("Highlight")
    if highlight then highlight:Destroy() end

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local a0 = part:FindFirstChild("TrailAttachment0")
            local a1 = part:FindFirstChild("TrailAttachment1")
            local trail = part:FindFirstChild("EfeitoTrail")
            if trail then trail:Destroy() end
            if a0 then a0:Destroy() end
            if a1 then a1:Destroy() end
        end
    end
end

local function ativarEfeitoGlobal(tipoEfeito, ativar)
    if ativar then
        local config = EFEITOS_CONFIG[tipoEfeito]
        if config then
            criarEfeitoRaios(LocalPlayer.Character, config)
        end
    else
        removerEfeito(LocalPlayer.Character)
    end
end

local function teleportarPara(targetPlayer)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local targetPos = targetPlayer.Character.HumanoidRootPart.Position + Vector3.new(0, 3, 0)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    
    return true
end

local function obterListaJogadores()
    local lista = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(lista, p)
        end
    end
    return lista
end

local PODERES_CATEGORIAS = {
    {nome = "🌑 Darkness", cor = Color3.fromRGB(80, 0, 120), poderes = {
        "Shadow Sword", "Unseen Hands", "Unseen Barrage", "Dark Duo", "Abyss", "Dark Hold", "Dark Arc"
    }},
    {nome = "🦴 Bone", cor = Color3.fromRGB(200, 200, 180), poderes = {
        "Bone Scythe", "Blaster", "Bones Barrage", "Flying Bone", "Bone Surge", "Twin Blasters", "Judgement Blast"
    }},
    {nome = "🌌 Space", cor = Color3.fromRGB(20, 20, 80), poderes = {
        "Space Gun", "Blackhole Orb", "Moon Splitter", "Asteroid Belt", "Meteor Jam", "Cosmic Remote", "Space Saucer"
    }},
    {nome = "😈 Devil", cor = Color3.fromRGB(140, 0, 0), poderes = {
        "Devil Sword", "Evil Bullet", "Fangs Barrage", "Evil Flash", "Demon Orb", "Demon Lock", "Dark Tsunami"
    }},
    {nome = "☠️ Venom", cor = Color3.fromRGB(0, 120, 0), poderes = {
        "Venom Blade", "Poison Bullet", "Acid Rain", "Venom Stream", "Hardened Venom", "Poison Demon", "Bubbling Venom"
    }},
    {nome = "💎 Crystal", cor = Color3.fromRGB(0, 180, 180), poderes = {
        "Crystal Cleaver", "Crystal Mine", "Energy Crash", "Energy Crown", "Crystal Eruption", "Energy Crystal", "Crystal Surge"
    }},
    {nome = "⏳ Time", cor = Color3.fromRGB(0, 100, 160), poderes = {
        "Time Scepter", "Temporal Gate", "Warp Barrage", "Tempo Beam", "Time Trap", "Warp Bomb", "Grand Clock"
    }},
    {nome = "🪨 Gravity", cor = Color3.fromRGB(100, 60, 120), poderes = {
        "Gravity Katana", "Heavy Infliction", "Tectonic Barrage", "Gravity Orb", "Tectonic Burst", "Zero Gravity", "Gravity Globe"
    }},
    {nome = "⚙️ Technology", cor = Color3.fromRGB(0, 150, 255), poderes = {
        "Hyper Sword", "Photon Blast", "Twin-Photon Blast", "Tesla Turret", "Orbital", "Tesseract", "Hyper Slash"
    }},
    {nome = "🔥 Fire", cor = Color3.fromRGB(200, 60, 0), poderes = {
        "Fire Sword", "Fire Ball", "Fire Fly", "Fire Bomb", "Comet", "Combust", "Fire Shower"
    }},
    {nome = "🌍 Earth", cor = Color3.fromRGB(120, 80, 40), poderes = {
        "Tectonic Hammer", "Stone Throw", "Rocks Barrage", "Large Boulder", "Burrow", "Stone Henge", "Earth Spikes"
    }},
    {nome = "⚡ Thunder", cor = Color3.fromRGB(200, 200, 0), poderes = {
        "Thunder Staff", "Bolt", "Barrage", "Discharge", "Flying Nimbus", "Lightning Strike", "Storm"
    }},
    {nome = "❄️ Ice", cor = Color3.fromRGB(100, 200, 255), poderes = {
        "Frost Staff", "Frost Fire Ball", "Ice Disk", "Frost Fire Bomb", "Snow Ball", "Ultracold Aura", "Ice Spikes"
    }},
    {nome = "🌿 Nature", cor = Color3.fromRGB(0, 160, 60), poderes = {
        "Christmas Tree Sword", "Plantoid", "Spore Bombs", "Nature's Blessing", "Nuclear Spore", "Pine Burst", "Nature's Wrath"
    }},
    {nome = "✨ Light", cor = Color3.fromRGB(255, 220, 100), poderes = {
        "Light Saber", "Light Ball", "Light Orbs", "Blinding Light", "Shooting Star", "Light Speed", "Light Beam"
    }},
    {nome = "🌋 Lava", cor = Color3.fromRGB(220, 80, 0), poderes = {
        "Lava Katana", "Lava Ball", "Magma Fists", "Lava Dash", "Volcano Sentry", "Magma Spikes", "Nibiru"
    }},
    {nome = "🌊 Water", cor = Color3.fromRGB(0, 120, 220), poderes = {
        "Aqua Trident", "Water Beam", "Big Tsunami", "Bubble Dash", "Atlan's Trident", "Jellyfish", "Bubbles"
    }},
    {nome = "💚 Super Sonic", cor = Color3.fromRGB(0, 200, 50), poderes = {
        "Sonic Barrage", "Rebound Blast", "Sonic Boom", "Super Sonic Wave",
        "Sonic Blaster", "Sonic Twister", "Rebound Teleport"
    }},
    {nome = "⭐ Especiais", cor = Color3.fromRGB(180, 140, 0), poderes = {
        "Dark Flames", "Cruel Sun", "Halloween Sword", "Yoru", "Plasma Orbs",
        "Undead Staff", "Elysian Beam", "Rocket Launcher",
        "Red Saucer", "Bubble Flail", "Poison Serpent", "Sonar"
    }}
}

-- Gerar lista plana automaticamente (sem duplicatas)
local PODERES_LISTA = {}
local _poderesSet = {}
for _, cat in ipairs(PODERES_CATEGORIAS) do
    for _, poder in ipairs(cat.poderes) do
        if not _poderesSet[poder] then
            _poderesSet[poder] = true
            table.insert(PODERES_LISTA, poder)
        end
    end
end

local bannedSpells = {
    ["Space Saucer"] = true, 
    ["Flying Nimbus"] = true, 
    ["Burrow"] = true,
    ["Frost Fire Bomb"] = true,
    ["Frost Fire Ball"] = true,
    ["Snow Ball"] = true,
    ["Flying Bone"] = true,
    ["Orbital"] = true,
    ["Tesseract"] = true
}
local magiasFiltradas = {}
for _, spell in ipairs(PODERES_LISTA) do
    if not bannedSpells[spell] then
        table.insert(magiasFiltradas, spell)
    end
end
local BURST_NO_F_ATIVADO = false

local VELOCIDADE_PADRAO = 100
local ATIVADO_SPEED = false
local SILENT_AIM_ATIVADO = false
local ATAQUES_TELEPORTADOS_ATIVADO = false
local ATAQUES_ALVO_SELECIONADO = nil
local ATAQUES_USA_ALVO_ESPECIFICO = true
local ATAQUES_ALVO_ATIVO = false
local GOD_MODE_ATIVADO = false
local FLY_ATIVADO = false
local INF_JUMP_ATIVADO = false
local ESP_ATIVADO = false
local ESP_LINHAS = false
local ESP_NOMES = false
local ESP_VIDA = false
local AUTO_FARM_ATIVADO = false
local FARM_KEYBIND = Enum.KeyCode.H
local bindingKey = false
local ANTI_AFK_ATIVADO = false
local KILL_AURA_ATIVADO = false
local NO_CLIP_ATIVADO = false
local NO_COOLDOWN_ATIVADO = false
local EFEITOS_VISUAIS_ATIVADO = false
local EFEITO_SELECIONADO = "Tesla Turret"
local LAUNCH_ATIVADO = false

local FLY_SPEED = 50

local TOGGLE_SIZE = UDim2.new(0, 40, 0, 40)
local TOGGLE_POSITION = UDim2.new(0, 10, 0.5, -20)
local TOGGLE_ICON_ASSET = nil
local TOGGLE_ICON_SIZE = UDim2.new(0, 20, 0, 20)
local TOGGLE_DRAGGABLE = true
local TOGGLE_SHOW_TEXT_IN_ICON = true
local TOGGLE_LABEL_TEXT = "ABRIR"

local LAUNCH_CONFIG = {
    TARGET_NAME = "kaiox_994:",
    VELOCITY = 0.1,
    LAUNCH_FORCE = 999999
}

local launchingPlayers = {}

local function getHumanoidRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function setupPhysics(character)
    local rootPart, humanoid = getHumanoidRootPart(character), character:FindFirstChildOfClass("Humanoid")
    if rootPart and humanoid then
        for _, v in pairs(rootPart:GetChildren()) do
            if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then
                v:Destroy()
            end
        end
        local bodyGyro, bodyVelocity = Instance.new("BodyGyro", rootPart), Instance.new("BodyVelocity", rootPart)
        bodyGyro.P, bodyGyro.MaxTorque = 9e4, Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.MaxForce, bodyVelocity.Velocity = Vector3.new(9e9, 9e9, 9e9), Vector3.zero
        humanoid.PlatformStand = true
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        return bodyGyro, bodyVelocity
    end
end

local function launchPlayer(targetPlayer)
    if targetPlayer == LocalPlayer or not targetPlayer.Character then return end
    
    launchingPlayers[targetPlayer.UserId] = true
    
    task.spawn(function()
        while launchingPlayers[targetPlayer.UserId] and targetPlayer.Character do
            pcall(function()
                local character = LocalPlayer.Character
                local bodyGyro, bodyVelocity = setupPhysics(character)
                if character and getHumanoidRootPart(character) and bodyVelocity then
                    if targetPlayer.Character and getHumanoidRootPart(targetPlayer.Character) then
                        local targetRoot = getHumanoidRootPart(targetPlayer.Character)
                        local targetHumanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                            for i = 1, 8 do
                                if not launchingPlayers[targetPlayer.UserId] or not getHumanoidRootPart(character) or not bodyVelocity then break end
                                getHumanoidRootPart(character).CFrame = targetRoot.CFrame * CFrame.Angles(
                                    math.rad(math.random(0, 360)),
                                    math.rad(math.random(0, 360)),
                                    math.rad(math.random(0, 360))
                                )
                                bodyVelocity.Velocity = Vector3.new(LAUNCH_CONFIG.LAUNCH_FORCE, LAUNCH_CONFIG.LAUNCH_FORCE, LAUNCH_CONFIG.LAUNCH_FORCE)
                                RunService.Heartbeat:Wait()
                            end
                            bodyVelocity.Velocity = Vector3.zero
                        end
                    end
                end
            end)
            task.wait(LAUNCH_CONFIG.VELOCITY)
        end
    end)
end

local function stopLaunchingPlayer(targetPlayer)
    launchingPlayers[targetPlayer.UserId] = false
end

local function stopAllLaunches()
    for userId, _ in pairs(launchingPlayers) do
        launchingPlayers[userId] = false
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SuperMenuManusV43"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false


local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Visible = false
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 1

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 10)
mfCorner.Parent = MainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Thickness = 1
mfStroke.Color = Color3.fromRGB(40,40,40)
mfStroke.Parent = MainFrame

local mfGrad = Instance.new("UIGradient")
mfGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(28,28,28)), ColorSequenceKeypoint.new(1, Color3.fromRGB(18,18,18))}
mfGrad.Rotation = 90
mfGrad.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "ELEMENTAL MENU V5.0"
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.TextYAlignment = Enum.TextYAlignment.Center

local titleBg = Instance.new("Frame")
titleBg.Parent = MainFrame
titleBg.Size = UDim2.new(1, 0, 0, 40)
titleBg.Position = UDim2.new(0,0,0,0)
titleBg.BackgroundColor3 = Color3.fromRGB(35,35,35)
titleBg.ZIndex = 2

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBg

local titleGrad = Instance.new("UIGradient")
titleGrad.Parent = titleBg
titleGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(50,50,50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(30,30,30))}
titleGrad.Rotation = 90

Title.Parent = titleBg
Title.ZIndex = 3

local ToggleButton = Instance.new("TextButton")
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ToggleButton.Position = TOGGLE_POSITION
ToggleButton.Size = TOGGLE_SIZE
ToggleButton.Text = "MENU"
ToggleButton.TextColor3 = Color3.fromRGB(245, 245, 245)
ToggleButton.Font = Enum.Font.GothamSemibold
ToggleButton.TextSize = 13
ToggleButton.TextXAlignment = Enum.TextXAlignment.Center
ToggleButton.TextYAlignment = Enum.TextYAlignment.Center
ToggleButton.AutoButtonColor = false
ToggleButton.TextScaled = true
ToggleButton.TextWrapped = true

local centerLabel = Instance.new("TextLabel")
centerLabel.Name = "_CenterLabel"
centerLabel.Parent = ToggleButton
centerLabel.Size = UDim2.new(1,0,1,0)
centerLabel.BackgroundTransparency = 1
centerLabel.Text = TOGGLE_LABEL_TEXT or ToggleButton.Text
centerLabel.TextColor3 = Color3.fromRGB(245,245,245)
centerLabel.Font = Enum.Font.GothamSemibold
centerLabel.TextScaled = true
centerLabel.TextWrapped = true
centerLabel.TextXAlignment = Enum.TextXAlignment.Center
centerLabel.TextYAlignment = Enum.TextYAlignment.Center
centerLabel.ZIndex = ToggleButton.ZIndex + 5
ToggleButton.Text = ""

local toggleCorner = Instance.new("UICorner")
toggleCorner.Parent = ToggleButton
local function updateToggleCorner()
    local sizeX = ToggleButton.AbsoluteSize.X
    local sizeY = ToggleButton.AbsoluteSize.Y
    local radius = math.floor(math.min(sizeX, sizeY) / 2)
    toggleCorner.CornerRadius = UDim.new(0, radius)
end
ToggleButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateToggleCorner)
task.defer(updateToggleCorner)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Thickness = 1
toggleStroke.Color = Color3.fromRGB(60,60,60)
toggleStroke.Parent = ToggleButton
toggleStroke.Transparency = 1

local toggleGrad = Instance.new("UIGradient")
toggleGrad.Parent = ToggleButton
toggleGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(30,30,30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(20,20,20))}
toggleGrad.Rotation = 90

local Glow = Instance.new("Frame")
Glow.Name = "InnerGlow"
Glow.Parent = ToggleButton
Glow.AnchorPoint = Vector2.new(0.5, 0.5)
Glow.Position = UDim2.new(0.5, 0, 0.5, 0)
Glow.Size = UDim2.new(0.9, 0, 0.9, 0)
Glow.BackgroundTransparency = 1
Glow.ZIndex = ToggleButton.ZIndex
local glowCorner = Instance.new("UICorner")
glowCorner.Parent = Glow
local function updateGlowCorner()
    local sizeX = ToggleButton.AbsoluteSize.X * 0.9
    local sizeY = ToggleButton.AbsoluteSize.Y * 0.9
    local radius = math.floor(math.min(sizeX, sizeY) / 2)
    glowCorner.CornerRadius = UDim.new(0, radius)
end
ToggleButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGlowCorner)
task.defer(updateGlowCorner)
local glowStroke = Instance.new("UIStroke")
glowStroke.Parent = Glow
glowStroke.Thickness = 1
glowStroke.Color = Color3.fromRGB(75,75,75)
glowStroke.Transparency = 1
Glow.ZIndex = ToggleButton.ZIndex - 1

local arc = Instance.new("UIAspectRatioConstraint") arc.Parent = ToggleButton arc.AspectRatio = 1

local pulseTween = nil
local pulseInfo = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function startPulse()
    if pulseTween then pcall(function() pulseTween:Play() end) return end
    pulseTween = TweenService:Create(glowStroke, pulseInfo, {Transparency = 0.6, Thickness = 1})
    pcall(function() pulseTween:Play() end)
end
local function stopPulse()
    if pulseTween then pcall(function() pulseTween:Cancel() pulseTween = nil glowStroke.Transparency = 1 glowStroke.Thickness = 1 end) end
end

do
    local hoverTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local uiScale = Instance.new("UIScale") uiScale.Parent = ToggleButton uiScale.Scale = 1
    local normalStroke = toggleStroke.Color
    local hoverColor = ToggleButton.BackgroundColor3:lerp(Color3.fromRGB(70,70,70), 0.2)
    ToggleButton.MouseEnter:Connect(function()
        pcall(function()
            TweenService:Create(uiScale, hoverTweenInfo, {Scale = 1.12}):Play()
            TweenService:Create(toggleStroke, hoverTweenInfo, {Color = hoverColor}):Play()
        end)
    end)
    ToggleButton.MouseLeave:Connect(function()
        pcall(function()
            TweenService:Create(uiScale, hoverTweenInfo, {Scale = 1}):Play()
            TweenService:Create(toggleStroke, hoverTweenInfo, {Color = normalStroke}):Play()
        end)
    end)
end

if TOGGLE_ICON_ASSET then
    local icon = Instance.new("ImageLabel")
    icon.Name = "ToggleIcon"
    icon.Parent = ToggleButton
    icon.Size = TOGGLE_ICON_SIZE
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Image = TOGGLE_ICON_ASSET
    local icorner = Instance.new("UICorner")
    icorner.Parent = icon
    local function updateIconCorner()
        local sizeX = icon.AbsoluteSize.X
        local sizeY = icon.AbsoluteSize.Y
        local radius = math.floor(math.min(sizeX, sizeY) / 2)
        icorner.CornerRadius = UDim.new(0, radius)
    end
    icon:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateIconCorner)
    task.defer(updateIconCorner)
    ToggleButton.Text = ""
    if TOGGLE_SHOW_TEXT_IN_ICON then
        local label = Instance.new("TextLabel")
        label.Name = "ToggleIconLabel"
        label.Parent = ToggleButton
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.Text = TOGGLE_LABEL_TEXT
        label.TextColor3 = Color3.fromRGB(245,245,245)
        label.Font = Enum.Font.GothamSemibold
        label.TextScaled = true
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = icon.ZIndex + 1
    end
else
    ToggleButton.TextXAlignment = Enum.TextXAlignment.Center
end

do
    local dragging = false
    local dragStart, startPos
    local function update(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and TOGGLE_DRAGGABLE then
            dragging = true
            dragStart = input.Position
            startPos = ToggleButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            pcall(update, input)
        end
    end)
end

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if not TOGGLE_ICON_ASSET then
        ToggleButton.Text = ""
        if centerLabel then
            centerLabel.Text = MainFrame.Visible and "FECHAR" or (TOGGLE_LABEL_TEXT or "ABRIR")
        end
    end
end)

local TabButtons = Instance.new("ScrollingFrame")
TabButtons.Parent = MainFrame
TabButtons.Position = UDim2.new(0, 0, 0, 40)
TabButtons.Size = UDim2.new(1, 0, 0, 40)
TabButtons.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TabButtons.ScrollBarThickness = 6
TabButtons.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
TabButtons.CanvasSize = UDim2.new(0, 0, 0, 0)
TabButtons.BorderSizePixel = 0

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0,6)
tabCorner.Parent = TabButtons

local tabLayout = Instance.new("UIListLayout")
tabLayout.Parent = TabButtons
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6)

tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabButtons.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X + 12, 0, 0)
end)

local function stylizeBtn(btn, baseColor)
    if not btn then return end
    if baseColor then
        btn.BackgroundColor3 = baseColor
    elseif btn.BackgroundColor3 == Color3.fromRGB(255, 255, 255) then
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
    btn.TextColor3 = Color3.fromRGB(245, 245, 245)
    btn.AutoButtonColor = false
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,6) corner.Parent = btn
    local stroke = Instance.new("UIStroke") stroke.Thickness = 1 stroke.Color = Color3.fromRGB(30,30,30) stroke.Parent = btn
    local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    btn.MouseEnter:Connect(function()
        local c = btn.BackgroundColor3
        btn:SetAttribute("PrevColor", c)
        local highlight = Color3.new(math.min(c.R + 0.12,1), math.min(c.G + 0.12,1), math.min(c.B + 0.12,1))
        TweenService:Create(btn, tweenInfo, {BackgroundColor3 = highlight}):Play()
    end)
    btn.MouseLeave:Connect(function()
        local prevColor = btn:GetAttribute("PrevColor") or btn.BackgroundColor3
        TweenService:Create(btn, tweenInfo, {BackgroundColor3 = prevColor}):Play()
    end)
end

local function criarAbaBtn(nome, pos, total)
    local btn = Instance.new("TextButton")
    btn.Parent = TabButtons
    btn.Size = UDim2.new(0, 120, 1, 0)
    btn.Text = nome
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.TextScaled = false
    btn.TextWrapped = false
    btn.TextXAlignment = Enum.TextXAlignment.Center
    stylizeBtn(btn, Color3.fromRGB(30,30,30))
    return btn
end

local abas = {"Poderes", "Combate", "Caos", "Movimento", "Farm", "Visual", "mapa", "Efeitos", "Teleporte", "Void Launch", "Atualizações", "Site", "Informações do Dono"}
local botoesAbas = {}
for i, nome in ipairs(abas) do
    botoesAbas[nome] = criarAbaBtn(nome, i-1, #abas)
end

local RGB_ENABLED = true
local RGB_SPEED = 0.25
local rgbHue = 0
local rgbConnection = nil

local function enableRGB(enable)
    RGB_ENABLED = enable
    if enable and not rgbConnection then
        rgbConnection = RunService.RenderStepped:Connect(function(dt)
            rgbHue = (rgbHue + dt * RGB_SPEED) % 1
            local c = Color3.fromHSV(rgbHue, 1, 1)
            if mfStroke then pcall(function() mfStroke.Color = c end) end
            if titleBg then pcall(function() titleBg.BackgroundColor3 = c:lerp(Color3.fromRGB(35,35,35), 0.7) end) end
            if TabButtons then
                for _, child in pairs(TabButtons:GetChildren()) do
                    if child:IsA("TextButton") then
                        local stroke = child:FindFirstChildOfClass("UIStroke")
                        if stroke then pcall(function() stroke.Color = c end) end
                    end
                end
            end
            local tstroke = ToggleButton and ToggleButton:FindFirstChildOfClass("UIStroke")
            if tstroke then pcall(function() tstroke.Color = c end) end
            if glowStroke then pcall(function() glowStroke.Color = c end) end
            if centerLabel then pcall(function()
                local lum = 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
                centerLabel.TextColor3 = lum > 0.6 and Color3.fromRGB(10,10,10) or Color3.fromRGB(245,245,245)
            end) end
        end)
    elseif not enable and rgbConnection then
        rgbConnection:Disconnect()
        rgbConnection = nil
        if mfStroke then mfStroke.Color = Color3.fromRGB(40,40,40) end
        if titleBg then titleBg.BackgroundColor3 = Color3.fromRGB(35,35,35) end
        if TabButtons then
            for _, child in pairs(TabButtons:GetChildren()) do
                if child:IsA("TextButton") then
                    local stroke = child:FindFirstChildOfClass("UIStroke")
                    if stroke then stroke.Color = Color3.fromRGB(30,30,30) end
                end
            end
        end
        local tstroke = ToggleButton and ToggleButton:FindFirstChildOfClass("UIStroke")
        if tstroke then tstroke.Color = Color3.fromRGB(50,50,50) end
    end
end

enableRGB(RGB_ENABLED)

task.spawn(function()
    while true do
        task.wait(2)
        if RGB_ENABLED and not rgbConnection then
            pcall(function() enableRGB(true) end)
        end
    end
end)

local ContentFrame = Instance.new("Frame")
ContentFrame.Parent = MainFrame
ContentFrame.Position = UDim2.new(0, 10, 0, 85)
ContentFrame.Size = UDim2.new(1, -20, 1, -95)
ContentFrame.BackgroundTransparency = 1

local function limparConteudo()
    updateSelectedLabelText = nil
    for _, child in pairs(ContentFrame:GetChildren()) do
        child:Destroy()
    end
end

local function criarToggle(parent, texto, estado, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = parent
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    
    stylizeBtn(btn)
    
    local function atualizar()
        btn.Text = texto .. ": " .. (estado and "ATIVADO" or "DESATIVADO")
        local color = estado and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
        btn.BackgroundColor3 = color
        btn:SetAttribute("PrevColor", color)
    end
    
    btn.MouseButton1Click:Connect(function()
        estado = not estado
        atualizar()
        callback(estado)
    end)
    
    atualizar()
    return btn
end

local HALLOWEEN_SWORD_PASSWORD = "5820"

local function askPassword(correctPassword, callback)
    if not ScreenGui then return end
    local existing = ScreenGui:FindFirstChild("PasswordModal")
    if existing then existing:Destroy() end

    local overlay = Instance.new("Frame")
    overlay.Name = "PasswordModal"
    overlay.Parent = ScreenGui
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.6
    overlay.ZIndex = 1000

    local panel = Instance.new("Frame")
    panel.Parent = overlay
    panel.Size = UDim2.new(0, 320, 0, 140)
    panel.Position = UDim2.new(0.5, -160, 0.5, -70)
    panel.BackgroundColor3 = Color3.fromRGB(36,36,36)
    panel.BorderSizePixel = 0
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,8) pc.Parent = panel

    local label = Instance.new("TextLabel")
    label.Parent = panel
    label.Size = UDim2.new(1, -20, 0, 24)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = "Insira a senha para desbloquear:"
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextColor3 = Color3.new(1,1,1)

    local textbox = Instance.new("TextBox")
    textbox.Parent = panel
    textbox.Size = UDim2.new(1, -20, 0, 32)
    textbox.Position = UDim2.new(0, 10, 0, 40)
    textbox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    textbox.TextColor3 = Color3.new(1,1,1)
    textbox.Font = Enum.Font.SourceSans
    textbox.TextSize = 14
    textbox.ClearTextOnFocus = true
    textbox.Text = ""
    textbox.PlaceholderText = "Senha..."

    local errorLabel = Instance.new("TextLabel")
    errorLabel.Parent = panel
    errorLabel.Size = UDim2.new(1, -20, 0, 20)
    errorLabel.Position = UDim2.new(0, 10, 0, 76)
    errorLabel.BackgroundTransparency = 1
    errorLabel.Text = ""
    errorLabel.Font = Enum.Font.SourceSans
    errorLabel.TextSize = 14
    errorLabel.TextColor3 = Color3.fromRGB(255,120,120)

    local btnConfirm = Instance.new("TextButton")
    btnConfirm.Parent = panel
    btnConfirm.Size = UDim2.new(0.5, -15, 0, 34)
    btnConfirm.Position = UDim2.new(0, 10, 1, -44)
    btnConfirm.Text = "Confirmar"
    btnConfirm.BackgroundColor3 = Color3.fromRGB(0,150,0)
    btnConfirm.TextColor3 = Color3.new(1,1,1)
    stylizeBtn(btnConfirm, Color3.fromRGB(0,150,0))

    local btnCancel = Instance.new("TextButton")
    btnCancel.Parent = panel
    btnCancel.Size = UDim2.new(0.5, -15, 0, 34)
    btnCancel.Position = UDim2.new(0.5, 5, 1, -44)
    btnCancel.Text = "Cancelar"
    btnCancel.BackgroundColor3 = Color3.fromRGB(150,0,0)
    btnCancel.TextColor3 = Color3.new(1,1,1)
    stylizeBtn(btnCancel, Color3.fromRGB(150,0,0))

    btnConfirm.MouseButton1Click:Connect(function()
        if textbox.Text == correctPassword then
            overlay:Destroy()
            pcall(callback, true)
        else
            errorLabel.Text = "Senha incorreta"
            textbox.Text = ""
        end
    end)

    btnCancel.MouseButton1Click:Connect(function()
        overlay:Destroy()
        pcall(callback, false)
    end)
end

local function showPoderes()
    limparConteudo()

    -- remover TextBoxes legados (caso uma versão anterior tenha deixado o código na GUI)
    pcall(function()
        if ScreenGui then
            for _, desc in pairs(ScreenGui:GetDescendants()) do
                if desc:IsA("TextBox") and desc.MultiLine then
                    if #tostring(desc.Text) > 50 then
                        desc:Destroy()
                    end
                end
            end
        end
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 5
    scroll.BackgroundTransparency = 1

    local list = Instance.new("UIListLayout")
    list.Parent = scroll
    list.Padding = UDim.new(0, 5)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)

    local layoutOrder = 0
    local function nextOrder()
        layoutOrder = layoutOrder + 1
        return layoutOrder
    end

    -- Botao equipar todos
    local btnEquiparTodos = Instance.new("TextButton")
    btnEquiparTodos.Parent = scroll
    btnEquiparTodos.LayoutOrder = nextOrder()
    btnEquiparTodos.Size = UDim2.new(1, -10, 0, 36)
    btnEquiparTodos.Text = "⚡ EQUIPAR TODOS OS PODERES ⚡"
    btnEquiparTodos.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    btnEquiparTodos.TextColor3 = Color3.new(1, 1, 1)
    btnEquiparTodos.Font = Enum.Font.SourceSansBold
    btnEquiparTodos.TextSize = 16
    stylizeBtn(btnEquiparTodos, Color3.fromRGB(0, 120, 200))

    btnEquiparTodos.MouseButton1Click:Connect(function()
        local RE = gRE()
        if RE then
            btnEquiparTodos.BackgroundColor3 = Color3.fromRGB(0, 80, 140)
            task.spawn(function()
                local function temPoder(nome)
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild(nome) then return true end
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    if bp and bp:FindFirstChild(nome) then return true end
                    return false
                end

                local total = #PODERES_LISTA
                for i, nome in ipairs(PODERES_LISTA) do
                    if not temPoder(nome) then
                        btnEquiparTodos.Text = "Equipando: " .. i .. "/" .. total
                        pcall(function()
                            RE:FireServer("equip_mystery_spell", nome)
                        end)
                        task.wait(0.25)
                    end
                end
                btnEquiparTodos.Text = "⚡ TODOS EQUIPADOS! ⚡"
                btnEquiparTodos.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
                task.wait(2)
                if btnEquiparTodos.Parent then
                    btnEquiparTodos.Text = "⚡ EQUIPAR TODOS OS PODERES ⚡"
                    btnEquiparTodos.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
                end
            end)
        end
    end)

    -- Criar poderes organizados por categoria elemental
    for _, categoria in ipairs(PODERES_CATEGORIAS) do
        -- Header da categoria
        local header = Instance.new("TextLabel")
        header.Parent = scroll
        header.LayoutOrder = nextOrder()
        header.Size = UDim2.new(1, -10, 0, 28)
        header.BackgroundColor3 = categoria.cor
        header.BackgroundTransparency = 0.3
        header.Text = "  " .. categoria.nome .. "  "
        header.Font = Enum.Font.GothamBold
        header.TextSize = 14
        header.TextColor3 = Color3.fromRGB(255, 255, 255)
        header.TextXAlignment = Enum.TextXAlignment.Center
        local hCorner = Instance.new("UICorner")
        hCorner.CornerRadius = UDim.new(0, 6)
        hCorner.Parent = header
        local hStroke = Instance.new("UIStroke")
        hStroke.Thickness = 1
        hStroke.Color = categoria.cor
        hStroke.Transparency = 0.2
        hStroke.Parent = header

        -- Botoes dos poderes desta categoria
        for _, nome in ipairs(categoria.poderes) do
            local btn = Instance.new("TextButton")
            btn.Parent = scroll
            btn.LayoutOrder = nextOrder()
            btn.Size = UDim2.new(1, -10, 0, 30)
            btn.Text = nome
            local btnColor = categoria.cor:lerp(Color3.fromRGB(30, 30, 30), 0.7)
            btn.BackgroundColor3 = btnColor
            btn.TextColor3 = Color3.new(1, 1, 1)
            stylizeBtn(btn, btnColor)
            btn.MouseButton1Click:Connect(function()
                local RE = gRE()
                if RE then RE:FireServer("equip_mystery_spell", nome) end
            end)
        end
    end
end

local function showCombate()
    limparConteudo()
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 6
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0

    local list = Instance.new("UIListLayout")
    list.Parent = scroll
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)
    
    ----------aba combate---------------------------
    local betaTagCombate = Instance.new("TextLabel")
    betaTagCombate.Parent = scroll
    betaTagCombate.Size = UDim2.new(1, -10, 0, 24)
    betaTagCombate.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    betaTagCombate.TextColor3 = Color3.fromRGB(255,255,255)
    betaTagCombate.Font = Enum.Font.SourceSansBold
    betaTagCombate.TextSize = 14
    betaTagCombate.Text = "COMBATE BETA"
    betaTagCombate.TextXAlignment = Enum.TextXAlignment.Center
    betaTagCombate.TextYAlignment = Enum.TextYAlignment.Center
    local betaCornerCombate = Instance.new("UICorner") betaCornerCombate.CornerRadius = UDim.new(0,6) betaCornerCombate.Parent = betaTagCombate
    ------------------------------------------------------
    
    criarToggle(scroll, "BURST NO F (Todas as Magias)", BURST_NO_F_ATIVADO, function(v) BURST_NO_F_ATIVADO = v end)
end

local function teleportToSpawn()
    local spawnLocation = nil
    if LocalPlayer.RespawnLocation then
        spawnLocation = LocalPlayer.RespawnLocation
    end

    if not spawnLocation then
        local spawns = {}
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("SpawnLocation") then
                table.insert(spawns, desc)
            end
        end

        if LocalPlayer.Team then
            for _, spawnLoc in ipairs(spawns) do
                if spawnLoc.TeamColor == LocalPlayer.TeamColor then
                    spawnLocation = spawnLoc
                    break
                end
            end
        end

        if not spawnLocation and #spawns > 0 then
            for _, spawnLoc in ipairs(spawns) do
                if spawnLoc.Neutral then
                    spawnLocation = spawnLoc
                    break
                end
            end
            if not spawnLocation then
                spawnLocation = spawns[1]
            end
        end
    end

    if spawnLocation and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:PivotTo(spawnLocation.CFrame + Vector3.new(0, 5, 0))
        return true
    end
    return false
end

local function showMovimento()
    limparConteudo()
    local list = Instance.new("UIListLayout")
    list.Parent = ContentFrame
    list.Padding = UDim.new(0, 8)
    
    criarToggle(ContentFrame, "SPEED HACK", ATIVADO_SPEED, function(v) ATIVADO_SPEED = v end)
    criarToggle(ContentFrame, "FLY (Voar)", FLY_ATIVADO, function(v) FLY_ATIVADO = v end)
    criarToggle(ContentFrame, "NO CLIP", NO_CLIP_ATIVADO, function(v) NO_CLIP_ATIVADO = v end)
    criarToggle(ContentFrame, "PULO INFINITO", INF_JUMP_ATIVADO, function(v) INF_JUMP_ATIVADO = v end)
    
    local speedBox = Instance.new("TextBox")
    speedBox.Parent = ContentFrame
    speedBox.Size = UDim2.new(1, 0, 0, 35)
    speedBox.Text = "Velocidade: " .. VELOCIDADE_PADRAO
    speedBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    speedBox.TextColor3 = Color3.new(1, 1, 1)
    speedBox.FocusLost:Connect(function()
        local val = tonumber(speedBox.Text:match("%d+"))
        if val then VELOCIDADE_PADRAO = val speedBox.Text = "Velocidade: " .. val end
    end)

    local tpSpawnBtn = Instance.new("TextButton")
    tpSpawnBtn.Parent = ContentFrame
    tpSpawnBtn.Size = UDim2.new(1, 0, 0, 35)
    tpSpawnBtn.Text = "TP PARA RESPAWN"
    tpSpawnBtn.Font = Enum.Font.SourceSansBold
    tpSpawnBtn.TextSize = 14
    tpSpawnBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
    tpSpawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stylizeBtn(tpSpawnBtn, Color3.fromRGB(0, 100, 180))

    tpSpawnBtn.MouseButton1Click:Connect(function()
        local success = teleportToSpawn()
        if success then
            tpSpawnBtn.Text = "Teleportado!"
            task.wait(1)
            if tpSpawnBtn.Parent then tpSpawnBtn.Text = "TP PARA RESPAWN" end
        else
            tpSpawnBtn.Text = "Spawn não encontrado!"
            task.wait(1)
            if tpSpawnBtn.Parent then tpSpawnBtn.Text = "TP PARA RESPAWN" end
        end
    end)
end

local AUTO_BUY_ENABLED = false
local AUTO_COLLECT_RUNNING = false
local AUTO_BUY_RUNNING = false
local AUTO_CAST_FARM_ATIVADO = false
local AUTO_CAST_FARM_RUNNING = false
local AUTO_REBIRTH_ATIVADO = false
local AUTO_REBIRTH_RUNNING = false
local AUTO_EQUIP_ATIVADO = false
local AUTO_EQUIP_RUNNING = false
local FARM_COLLECT_SPEED = 0.5
local FARM_BUY_SPEED = 0.1
local FARM_STATUS_TEXT = "Parado"
local farmStatusLabel = nil

local function atualizarFarmStatus(texto)
    FARM_STATUS_TEXT = texto
    if farmStatusLabel and farmStatusLabel.Parent then
        pcall(function() farmStatusLabel.Text = texto end)
    end
end

local function autoCollectLoop()
    while AUTO_FARM_ATIVADO do
        task.wait(math.max(0.01, FARM_COLLECT_SPEED))
        pcall(function()
            local tycoon = Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild(LocalPlayer.Name)
            if tycoon then
                local collectPart = nil
                if tycoon:FindFirstChild("Auxiliary") and tycoon.Auxiliary:FindFirstChild("Collector") and tycoon.Auxiliary.Collector:FindFirstChild("Collect") then
                    collectPart = tycoon.Auxiliary.Collector.Collect
                end
                if not collectPart then
                    for _, desc in pairs(tycoon:GetDescendants()) do
                        if desc.Name == "Collect" and desc:IsA("BasePart") then
                            collectPart = desc
                            break
                        end
                    end
                end
                if collectPart then
                    local character = LocalPlayer.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        character:PivotTo(collectPart.CFrame)
                        atualizarFarmStatus("Coletando moedas...")
                    end
                end
            end
        end)
    end
    AUTO_COLLECT_RUNNING = false
    atualizarFarmStatus("Parado")
end

local function autoBuyLoop()
    local function isGreenButton(color)
        return color.G > 0.3 and color.R < 0.2 and color.B < 0.2
    end
    while AUTO_BUY_ENABLED do
        task.wait(math.max(0.01, FARM_BUY_SPEED))
        pcall(function()
            local tycoon = Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild(LocalPlayer.Name)
            if tycoon and tycoon:FindFirstChild("Buttons") then
                for _, button in pairs(tycoon.Buttons:GetChildren()) do
                    if not AUTO_BUY_ENABLED then break end
                    local buttonBase = button:FindFirstChild("Button")
                    if buttonBase and isGreenButton(buttonBase.Color) then
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            atualizarFarmStatus("Comprando: " .. button.Name)
                            character:PivotTo(buttonBase.CFrame)
                            if FARM_BUY_SPEED > 0 then
                                task.wait(math.min(0.15, FARM_BUY_SPEED))
                            else
                                task.wait(0.01)
                            end
                        end
                    end
                end
            end
        end)
    end
    AUTO_BUY_RUNNING = false
    atualizarFarmStatus("Parado")
end

local function autoCastFarmLoop()
    local farmSpells = {
        "Dark Flames", "Fire Shower", "Combust", "Fire Bomb", "Plasma Orbs",
        "Tesla Turret", "Nuclear Spore", "Comet", "Elysian Beam", "Shadow Sword",
        "Dark Hold", "Frost Staff", "Lava Ball", "Light Beam", "Storm",
        "Fire Sword", "Fire Ball", "Magma Spikes", "Earth Spikes", "Crystal Surge"
    }
    while AUTO_CAST_FARM_ATIVADO do
        pcall(function()
            local RE = gRE()
            if RE then
                local spell = farmSpells[math.random(1, #farmSpells)]
                RE:FireServer("equip_mystery_spell", spell)
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local mousePos = character.HumanoidRootPart.Position + character.HumanoidRootPart.CFrame.LookVector * 20
                    RE:FireServer("cast_spell", spell, mousePos)
                    atualizarFarmStatus("Castando: " .. spell)
                end
            end
        end)
        task.wait(0.8)
    end
    AUTO_CAST_FARM_RUNNING = false
    atualizarFarmStatus("Parado")
end

local function autoRebirthLoop()
    while AUTO_REBIRTH_ATIVADO do
        pcall(function()
            local RE = gRE()
            if RE then
                RE:FireServer("rebirth")
                RE:FireServer("Rebirth")
                RE:FireServer("buy_rebirth")
            end
            local tycoon = Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild(LocalPlayer.Name)
            if tycoon then
                for _, desc in pairs(tycoon:GetDescendants()) do
                    if (desc.Name:lower():find("rebirth") or desc.Name:lower():find("prestige")) and desc:IsA("BasePart") then
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            atualizarFarmStatus("Tentando rebirth...")
                            character:PivotTo(desc.CFrame)
                        end
                        break
                    end
                end
            end
        end)
        task.wait(5)
    end
    AUTO_REBIRTH_RUNNING = false
    atualizarFarmStatus("Parado")
end

local function autoEquipLoop()
    while AUTO_EQUIP_ATIVADO do
        pcall(function()
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local bestTool = nil
                for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        if not bestTool then
                            bestTool = tool
                        end
                    end
                end
                if bestTool and humanoid then
                    local currentTool = character:FindFirstChildOfClass("Tool")
                    if not currentTool then
                        humanoid:EquipTool(bestTool)
                        atualizarFarmStatus("Equipou: " .. bestTool.Name)
                    end
                end
            end
        end)
        task.wait(1)
    end
    AUTO_EQUIP_RUNNING = false
    atualizarFarmStatus("Parado")
end

local ANTI_AFK_IDLED_CONN = nil
local ANTI_AFK_JUMP_CONN = nil
local ANTI_AFK_JUMP_INTERVAL = 20
local _antiAfkJumpTimer = 0
local function enableAntiAfkIdled()
    if ANTI_AFK_IDLED_CONN then return end
    ANTI_AFK_IDLED_CONN = LocalPlayer.Idled:Connect(function()
        if ANTI_AFK_ATIVADO then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

local function disableAntiAfkIdled()
    if ANTI_AFK_IDLED_CONN then
        ANTI_AFK_IDLED_CONN:Disconnect()
        ANTI_AFK_IDLED_CONN = nil
    end
end

local function enableAntiAfkJump()
    if ANTI_AFK_JUMP_CONN then return end
    _antiAfkJumpTimer = 0
    ANTI_AFK_JUMP_CONN = RunService.Heartbeat:Connect(function(dt)
        if not ANTI_AFK_ATIVADO then return end
        _antiAfkJumpTimer = _antiAfkJumpTimer + dt
        if _antiAfkJumpTimer >= ANTI_AFK_JUMP_INTERVAL then
            _antiAfkJumpTimer = 0
            local character = LocalPlayer.Character
            if character and character:FindFirstChildOfClass("Humanoid") then
                pcall(function()
                    character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end
    end)
end

local function disableAntiAfkJump()
    if ANTI_AFK_JUMP_CONN then
        ANTI_AFK_JUMP_CONN:Disconnect()
        ANTI_AFK_JUMP_CONN = nil
    end
    _antiAfkJumpTimer = 0
end

function criarSecaoLabel(parent, texto)
    local sec = Instance.new("TextLabel")
    sec.Parent = parent
    sec.Size = UDim2.new(1, -10, 0, 22)
    sec.BackgroundTransparency = 1
    sec.Text = "-- " .. texto .. " --"
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 12
    sec.TextColor3 = Color3.fromRGB(150, 150, 150)
    sec.TextXAlignment = Enum.TextXAlignment.Center
    return sec
end

local function criarVelocidadeInput(parent, labelText, valorInicial, onChanged)
    local frame = Instance.new("Frame")
    frame.Parent = parent
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    frame.BorderSizePixel = 0
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 6) fc.Parent = frame

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox")
    box.Parent = frame
    box.Size = UDim2.new(0.3, -8, 0, 22)
    box.Position = UDim2.new(0.65, 0, 0.5, -11)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSansBold
    box.TextSize = 14
    box.Text = tostring(valorInicial)
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = box

    local currentVal = valorInicial
    box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val and val >= 0 and val <= 10 then
            currentVal = val
            onChanged(val)
        end
        box.Text = tostring(currentVal)
    end)

    return frame, box
end

local function showFarm()
    limparConteudo()

    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 6
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0

    local list = Instance.new("UIListLayout")
    list.Parent = scroll
    list.Padding = UDim.new(0, 5)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)

    -- ========== STATUS ==========
    farmStatusLabel = Instance.new("TextLabel")
    farmStatusLabel.Parent = scroll
    farmStatusLabel.Size = UDim2.new(1, -10, 0, 34)
    farmStatusLabel.BackgroundColor3 = Color3.fromRGB(25, 40, 25)
    farmStatusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    farmStatusLabel.Font = Enum.Font.GothamBold
    farmStatusLabel.TextSize = 14
    farmStatusLabel.Text = FARM_STATUS_TEXT
    farmStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    local stCorner = Instance.new("UICorner") stCorner.CornerRadius = UDim.new(0, 6) stCorner.Parent = farmStatusLabel
    local stStroke = Instance.new("UIStroke") stStroke.Thickness = 1 stStroke.Color = Color3.fromRGB(0, 120, 0) stStroke.Parent = farmStatusLabel

    task.spawn(function()
        while farmStatusLabel and farmStatusLabel.Parent do
            pcall(function() farmStatusLabel.Text = FARM_STATUS_TEXT end)
            task.wait(0.5)
        end
    end)

    -- ========== COLETA ==========
    criarSecaoLabel(scroll, "COLETA")

    criarToggle(scroll, "AUTO-COLLECT MOEDAS", AUTO_FARM_ATIVADO, function(v)
        AUTO_FARM_ATIVADO = v
        if v and not AUTO_COLLECT_RUNNING then
            AUTO_COLLECT_RUNNING = true
            task.spawn(autoCollectLoop)
        end
        if not v then atualizarFarmStatus("Parado") end
    end)

    criarVelocidadeInput(scroll, "Velocidade Coleta (seg):", FARM_COLLECT_SPEED, function(val)
        FARM_COLLECT_SPEED = val
    end)

    criarToggle(scroll, "AUTO-BUY (AUTO COMPRAR)", AUTO_BUY_ENABLED, function(v)
        AUTO_BUY_ENABLED = v
        if v and not AUTO_BUY_RUNNING then
            AUTO_BUY_RUNNING = true
            task.spawn(autoBuyLoop)
        end
        if not v then atualizarFarmStatus("Parado") end
    end)

    local keybindFrame = Instance.new("Frame")
    keybindFrame.Parent = scroll
    keybindFrame.Size = UDim2.new(1, -10, 0, 30)
    keybindFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    keybindFrame.BorderSizePixel = 0
    local kfc = Instance.new("UICorner") kfc.CornerRadius = UDim.new(0, 6) kfc.Parent = keybindFrame

    local kLabel = Instance.new("TextLabel")
    kLabel.Parent = keybindFrame
    kLabel.Size = UDim2.new(0.6, 0, 1, 0)
    kLabel.Position = UDim2.new(0, 10, 0, 0)
    kLabel.BackgroundTransparency = 1
    kLabel.Text = "Atalho Auto-Buy (Toggle):"
    kLabel.Font = Enum.Font.SourceSans
    kLabel.TextSize = 13
    kLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    kLabel.TextXAlignment = Enum.TextXAlignment.Left

    local kButton = Instance.new("TextButton")
    kButton.Parent = keybindFrame
    kButton.Size = UDim2.new(0.3, -8, 0, 22)
    kButton.Position = UDim2.new(0.65, 0, 0.5, -11)
    kButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    kButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    kButton.Font = Enum.Font.SourceSansBold
    kButton.TextSize = 14
    kButton.Text = bindingKey and "..." or (FARM_KEYBIND and FARM_KEYBIND.Name or "Nenhum")
    local kbc = Instance.new("UICorner") kbc.CornerRadius = UDim.new(0, 4) kbc.Parent = kButton

    kButton.MouseButton1Click:Connect(function()
        if bindingKey then return end
        bindingKey = true
        kButton.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local code = input.KeyCode
                if code == Enum.KeyCode.Escape then
                    FARM_KEYBIND = Enum.KeyCode.None
                else
                    FARM_KEYBIND = code
                end
                bindingKey = false
                kButton.Text = FARM_KEYBIND == Enum.KeyCode.None and "Nenhum" or FARM_KEYBIND.Name
                conn:Disconnect()
            end
        end)
    end)

    criarVelocidadeInput(scroll, "Velocidade Compra (seg):", FARM_BUY_SPEED, function(val)
        FARM_BUY_SPEED = val
    end)

    -- ========== COMBATE FARM ==========
    criarSecaoLabel(scroll, "COMBATE FARM")

    criarToggle(scroll, "AUTO-CAST MAGIAS (PvE)", AUTO_CAST_FARM_ATIVADO, function(v)
        AUTO_CAST_FARM_ATIVADO = v
        if v and not AUTO_CAST_FARM_RUNNING then
            AUTO_CAST_FARM_RUNNING = true
            task.spawn(autoCastFarmLoop)
        end
        if not v then atualizarFarmStatus("Parado") end
    end)

    criarToggle(scroll, "AUTO-EQUIP TOOL", AUTO_EQUIP_ATIVADO, function(v)
        AUTO_EQUIP_ATIVADO = v
        if v and not AUTO_EQUIP_RUNNING then
            AUTO_EQUIP_RUNNING = true
            task.spawn(autoEquipLoop)
        end
        if not v then atualizarFarmStatus("Parado") end
    end)

    -- ========== PROGRESSAO ==========
    criarSecaoLabel(scroll, "PROGRESSAO")

    criarToggle(scroll, "AUTO-REBIRTH", AUTO_REBIRTH_ATIVADO, function(v)
        AUTO_REBIRTH_ATIVADO = v
        if v and not AUTO_REBIRTH_RUNNING then
            AUTO_REBIRTH_RUNNING = true
            task.spawn(autoRebirthLoop)
        end
        if not v then atualizarFarmStatus("Parado") end
    end)

    -- ========== UTILIDADES ==========
    criarSecaoLabel(scroll, "UTILIDADES")

    criarToggle(scroll, "ANTI-AFK", ANTI_AFK_ATIVADO, function(v)
        ANTI_AFK_ATIVADO = v
        if v then
            enableAntiAfkIdled()
            enableAntiAfkJump()
        else
            disableAntiAfkIdled()
            disableAntiAfkJump()
            local character = LocalPlayer.Character
            if character and character:FindFirstChildOfClass("Humanoid") then
                pcall(function()
                    character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Landed)
                    character:FindFirstChildOfClass("Humanoid").PlatformStand = false
                end)
            end
        end
    end)

    -- ========== TELEPORTE RAPIDO ==========
    criarSecaoLabel(scroll, "TELEPORTE RAPIDO")

    local tpCollectorBtn = Instance.new("TextButton")
    tpCollectorBtn.Parent = scroll
    tpCollectorBtn.Size = UDim2.new(1, -10, 0, 32)
    tpCollectorBtn.Text = "TP PARA COLETOR"
    tpCollectorBtn.Font = Enum.Font.SourceSansBold
    tpCollectorBtn.TextSize = 14
    tpCollectorBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 160)
    tpCollectorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stylizeBtn(tpCollectorBtn, Color3.fromRGB(0, 80, 160))

    tpCollectorBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local tycoon = Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild(LocalPlayer.Name)
            if tycoon then
                local collectPart = nil
                if tycoon:FindFirstChild("Auxiliary") and tycoon.Auxiliary:FindFirstChild("Collector") and tycoon.Auxiliary.Collector:FindFirstChild("Collect") then
                    collectPart = tycoon.Auxiliary.Collector.Collect
                end
                if not collectPart then
                    for _, desc in pairs(tycoon:GetDescendants()) do
                        if desc.Name == "Collect" and desc:IsA("BasePart") then
                            collectPart = desc
                            break
                        end
                    end
                end
                if collectPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character:PivotTo(collectPart.CFrame)
                    tpCollectorBtn.Text = "Teleportado!"
                    task.wait(1)
                    if tpCollectorBtn.Parent then tpCollectorBtn.Text = "TP PARA COLETOR" end
                else
                    tpCollectorBtn.Text = "Coletor nao encontrado"
                    task.wait(1)
                    if tpCollectorBtn.Parent then tpCollectorBtn.Text = "TP PARA COLETOR" end
                end
            end
        end)
    end)

    local tpBaseBtn = Instance.new("TextButton")
    tpBaseBtn.Parent = scroll
    tpBaseBtn.Size = UDim2.new(1, -10, 0, 32)
    tpBaseBtn.Text = "TP PARA BASE / TYCOON"
    tpBaseBtn.Font = Enum.Font.SourceSansBold
    tpBaseBtn.TextSize = 14
    tpBaseBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 80)
    tpBaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stylizeBtn(tpBaseBtn, Color3.fromRGB(0, 120, 80))

    tpBaseBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local tycoon = Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild(LocalPlayer.Name)
            if tycoon then
                local basePart = nil
                for _, desc in pairs(tycoon:GetDescendants()) do
                    if desc:IsA("BasePart") and (desc.Name:lower():find("spawn") or desc.Name:lower():find("base") or desc.Name:lower():find("platform")) then
                        basePart = desc
                        break
                    end
                end
                if not basePart then
                    basePart = tycoon:FindFirstChildWhichIsA("BasePart", true)
                end
                if basePart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character:PivotTo(basePart.CFrame + Vector3.new(0, 5, 0))
                    tpBaseBtn.Text = "Teleportado!"
                    task.wait(1)
                    if tpBaseBtn.Parent then tpBaseBtn.Text = "TP PARA BASE / TYCOON" end
                end
            end
        end)
    end)

    -- Botao para desligar tudo
    criarSecaoLabel(scroll, "CONTROLES")

    local desligarTudoBtn = Instance.new("TextButton")
    desligarTudoBtn.Parent = scroll
    desligarTudoBtn.Size = UDim2.new(1, -10, 0, 35)
    desligarTudoBtn.Text = "DESLIGAR TUDO"
    desligarTudoBtn.Font = Enum.Font.GothamBold
    desligarTudoBtn.TextSize = 14
    desligarTudoBtn.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
    desligarTudoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stylizeBtn(desligarTudoBtn, Color3.fromRGB(160, 0, 0))

    desligarTudoBtn.MouseButton1Click:Connect(function()
        AUTO_FARM_ATIVADO = false
        AUTO_BUY_ENABLED = false
        AUTO_CAST_FARM_ATIVADO = false
        AUTO_REBIRTH_ATIVADO = false
        AUTO_EQUIP_ATIVADO = false
        ANTI_AFK_ATIVADO = false
        disableAntiAfkIdled()
        disableAntiAfkJump()
        atualizarFarmStatus("Tudo desligado!")
        task.wait(1)
        atualizarFarmStatus("Parado")
        showFarm()
    end)
end

local function showVisual()
    limparConteudo()
    local list = Instance.new("UIListLayout")
    list.Parent = ContentFrame
    list.Padding = UDim.new(0, 8)

    criarToggle(ContentFrame, "MENU RGB (Cores)", RGB_ENABLED, function(v)
        RGB_ENABLED = v
        enableRGB(v)
    end)

    criarToggle(ContentFrame, "ESP HIGHLIGHT (Brilho)", ESP_ATIVADO, function(v) 
        ESP_ATIVADO = v 
        if not v then
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("Highlight") then p.Character.Highlight:Destroy() end
            end
        end
    end)

    criarToggle(ContentFrame, "ESP TRACERS (Linhas)", ESP_LINHAS, function(v) ESP_LINHAS = v end)
    criarToggle(ContentFrame, "ESP NAMES (Nomes)", ESP_NOMES, function(v) ESP_NOMES = v end)
    criarToggle(ContentFrame, "ESP HEALTH (Vida)", ESP_VIDA, function(v) ESP_VIDA = v end)
end

local CEU_ESCURO_ATIVADO = false
local CEU_GALAXIA_ATIVADO = false

local CEU_GALAXIA_CONN = nil

local function ceuGalaxia(ativar)
    local Lighting = game:GetService("Lighting")
    
    if CEU_GALAXIA_CONN then
        CEU_GALAXIA_CONN:Disconnect()
        CEU_GALAXIA_CONN = nil
    end
    _G.PararLoopGalaxia = true
    
    if ativar then
        _G.PararLoopGalaxia = false
        
        local function limparBloqueios()
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                    pcall(function() obj:Destroy() end)
                end
            end
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
        
        local function forcarIluminacao()
            Lighting.ClockTime = 0
            Lighting.Ambient = Color3.fromRGB(80, 70, 110)
            Lighting.OutdoorAmbient = Color3.fromRGB(40, 30, 60)
            Lighting.FogColor = Color3.fromRGB(15, 10, 25)
            Lighting.FogEnd = 999999
        end
        
        local function aplicarSky()
            limparBloqueios()
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("Sky") and obj.Name ~= "GalaxySkybox" then
                    pcall(function() obj:Destroy() end)
                end
            end
            
            local NewSky = Lighting:FindFirstChild("GalaxySkybox")
            if not NewSky then
                NewSky = Instance.new("Sky")
                NewSky.Name = "GalaxySkybox"
                NewSky.Parent = Lighting
            end
            NewSky.SkyboxBk = "rbxassetid://8351654823"
            NewSky.SkyboxDn = "rbxassetid://8351654271"
            NewSky.SkyboxFt = "rbxassetid://8351654668"
            NewSky.SkyboxLf = "rbxassetid://8351654388"
            NewSky.SkyboxRt = "rbxassetid://8351654536"
            NewSky.SkyboxUp = "rbxassetid://8351654160"
            NewSky.SunTextureId = "rbxassetid://0"
            NewSky.MoonTextureId = "rbxassetid://0"
            forcarIluminacao()
        end
        
        aplicarSky()
        
        CEU_GALAXIA_CONN = Lighting.Changed:Connect(function(prop)
            if prop == "ClockTime" or prop == "Ambient" or prop == "OutdoorAmbient" or prop == "FogColor" or prop == "FogEnd" then
                pcall(forcarIluminacao)
            end
        end)
        
        task.spawn(function()
            while not _G.PararLoopGalaxia do
                pcall(aplicarSky)
                task.wait(2)
            end
        end)
        
        print("[Manus AI] Céu de galáxia roxa ativado com sucesso!")
    else
        Lighting.ClockTime = 14 
        Lighting.Ambient = Color3.fromRGB(200, 200, 200) 
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200) 
        Lighting.FogColor = Color3.fromRGB(192, 192, 192)
        Lighting.FogEnd = 100000
        
        local Sky = Lighting:FindFirstChild("GalaxySkybox")
        if Sky then
            Sky:Destroy()
        end
        
        print("Céu restaurado para o padrão!")
    end
end


local function escurecerCeu(ativar)
    local Lighting = game:GetService("Lighting")
    
    if ativar then
        Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(50, 50, 50)
        Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 50)
        
        local Sky = Lighting:FindFirstChildOfClass("Sky")
        if Sky then
            Sky:Destroy()
        end
        
        local NewSky = Instance.new("Sky")
        NewSky.Parent = Lighting
        NewSky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.png"
        NewSky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.png"
        NewSky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.png"
        NewSky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.png"
        NewSky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.png"
        NewSky.SkyboxUp = "rbxasset://textures/sky/sky512_up.png"
        
        Lighting.FogColor = Color3.fromRGB(0, 0, 0)
        Lighting.FogEnd = 100000 
        
        print("[Manus AI] Céu escurecido com sucesso!")
    else
        Lighting.ClockTime = 14 
        Lighting.Ambient = Color3.fromRGB(200, 200, 200) 
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200) 
        Lighting.FogColor = Color3.fromRGB(192, 192, 192)
        Lighting.FogEnd = 100000
        
        local Sky = Lighting:FindFirstChildOfClass("Sky")
        if Sky then
            Sky:Destroy()
        end
        
        print("Céu restaurado para o padrão!")
    end
end

local function showEfeitos()
    limparConteudo()
    local list = Instance.new("UIListLayout")
    list.Parent = ContentFrame
    list.Padding = UDim.new(0, 8)
    
    criarToggle(ContentFrame, "ATIVAR EFEITOS VISUAIS", EFEITOS_VISUAIS_ATIVADO, function(v) 
        EFEITOS_VISUAIS_ATIVADO = v
        if v and EFEITO_SELECIONADO then
            ativarEfeitoGlobal(EFEITO_SELECIONADO, true)
        else
            removerEfeito(LocalPlayer.Character)
        end
    end)
    
    local label = Instance.new("TextLabel")
    label.Parent = ContentFrame
    label.Size = UDim2.new(1, 0, 0, 30)
    label.Text = "Efeito Selecionado: " .. EFEITO_SELECIONADO
    label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    
    for nomeEfeito, _ in pairs(EFEITOS_CONFIG) do
        local btn = Instance.new("TextButton")
        btn.Parent = ContentFrame
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.Text = "Usar: " .. nomeEfeito
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        stylizeBtn(btn, Color3.fromRGB(50,50,100))
        
        btn.MouseButton1Click:Connect(function()
            EFEITO_SELECIONADO = nomeEfeito
            label.Text = "Efeito Selecionado: " .. EFEITO_SELECIONADO
            if EFEITOS_VISUAIS_ATIVADO then
                ativarEfeitoGlobal(EFEITO_SELECIONADO, true)
            end
        end)
    end
end

local function showVisuaisAvancados()
    limparConteudo()
    local list = Instance.new("UIListLayout")
    list.Parent = ContentFrame
    list.Padding = UDim.new(0, 8)
    
    criarToggle(ContentFrame, "CÉU ESCURO", CEU_ESCURO_ATIVADO, function(v)
        CEU_ESCURO_ATIVADO = v
        if v then
            CEU_GALAXIA_ATIVADO = false
            escurecerCeu(true)
        else
            escurecerCeu(false)
        end
        showVisuaisAvancados()
    end)
    
    criarToggle(ContentFrame, "CÉU DE GALÁXIA", CEU_GALAXIA_ATIVADO, function(v)
        CEU_GALAXIA_ATIVADO = v
        if v then
            CEU_ESCURO_ATIVADO = false
            ceuGalaxia(true)
        else
            ceuGalaxia(false)
        end
        showVisuaisAvancados()
    end)
end

local function showTeleporte()
    limparConteudo()
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 10
    scroll.TopImage = ""
    scroll.BottomImage = ""
    scroll.MidImage = ""
    
    local jogadores = obterListaJogadores()
    local alturaTotal = 35 + (#jogadores * 50)
    scroll.CanvasSize = UDim2.new(0, 0, 0, alturaTotal)
    
    local list = Instance.new("UIListLayout")
    list.Parent = scroll
    list.Padding = UDim.new(0, 5)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local titulo = Instance.new("TextLabel")
    titulo.Parent = scroll
    titulo.Size = UDim2.new(0.95, 0, 0, 35)
    titulo.Text = "CLIQUE PARA TELEPORTAR"
    titulo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    titulo.TextColor3 = Color3.fromRGB(255, 255, 100)
    titulo.Font = Enum.Font.SourceSansBold
    titulo.TextSize = 14
    
    if #jogadores == 0 then
        local label = Instance.new("TextLabel")
        label.Parent = scroll
        label.Size = UDim2.new(0.95, 0, 0, 50)
        label.Text = "Nenhum jogador encontrado"
        label.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.SourceSansBold
    else
        for _, jogador in ipairs(jogadores) do
            if jogador and jogador.Character then
                local btn = Instance.new("TextButton")
                btn.Parent = scroll
                btn.Size = UDim2.new(0.95, 0, 0, 45)
                btn.Text = jogador.Name
                btn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
                btn.TextColor3 = Color3.new(1, 1, 1)
                btn.Font = Enum.Font.SourceSansBold
                btn.TextSize = 14
                btn.BorderSizePixel = 0
                stylizeBtn(btn, Color3.fromRGB(0,100,150))
                
                btn.MouseButton1Click:Connect(function()
                    local sucesso = teleportarPara(jogador)
                    if sucesso then
                        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
                        btn.Text = "✓ " .. jogador.Name
                        task.wait(1)
                        if btn.Parent then
                            btn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
                            btn.Text = jogador.Name
                        end
                    else
                        btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
                        btn.Text = "✗ Erro"
                        task.wait(1)
                        if btn.Parent then
                            btn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
                            btn.Text = jogador.Name
                        end
                    end
                end)
            end
        end
    end
end

local function showVoidLaunch()
    limparConteudo()
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 10
    scroll.TopImage = ""
    scroll.BottomImage = ""
    scroll.MidImage = ""
    
    local jogadores = obterListaJogadores()
    local alturaTotal = 35 + (#jogadores * 50)
    scroll.CanvasSize = UDim2.new(0, 0, 0, alturaTotal)
    
    local list = Instance.new("UIListLayout")
    list.Parent = scroll
    list.Padding = UDim.new(0, 5)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local titulo = Instance.new("TextLabel")
    titulo.Parent = scroll
    titulo.Size = UDim2.new(0.95, 0, 0, 35)
    titulo.Text = "CLIQUE PARA LANCAR AO VOID"
    titulo.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
    titulo.Font = Enum.Font.SourceSansBold
    titulo.TextSize = 14
    
    if #jogadores == 0 then
        local label = Instance.new("TextLabel")
        label.Parent = scroll
        label.Size = UDim2.new(0.95, 0, 0, 50)
        label.Text = "Nenhum jogador encontrado"
        label.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.SourceSansBold
    else
        for _, jogador in ipairs(jogadores) do
            if jogador and jogador.Character then
                local btn = Instance.new("TextButton")
                btn.Parent = scroll
                btn.Size = UDim2.new(0.95, 0, 0, 45)
                btn.Text = jogador.Name
                btn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                btn.TextColor3 = Color3.new(1, 1, 1)
                btn.Font = Enum.Font.SourceSansBold
                btn.TextSize = 14
                btn.BorderSizePixel = 0
                stylizeBtn(btn, Color3.fromRGB(200,100,0))
                
                btn.MouseButton1Click:Connect(function()
                    launchPlayer(jogador)
                    btn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
                    btn.Text = "LANCANDO..."
                    task.wait(10)
                    stopLaunchingPlayer(jogador)
                    btn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                    btn.Text = jogador.Name
                end)
            end
        end
    end
end

local function showAtualizacoes()
    limparConteudo()

    local container = Instance.new("Frame")
    container.Parent = ContentFrame
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1

    local panel = Instance.new("ScrollingFrame")
    panel.Parent = container
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    panel.BorderSizePixel = 0
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.ScrollBarThickness = 5
    panel.BackgroundTransparency = 0

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 8)
    panelCorner.Parent = panel

    local panelPadding = Instance.new("UIPadding")
    panelPadding.PaddingTop = UDim.new(0, 10)
    panelPadding.PaddingLeft = UDim.new(0, 10)
    panelPadding.PaddingRight = UDim.new(0, 10)
    panelPadding.PaddingBottom = UDim.new(0, 10)
    panelPadding.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Parent = panel
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        panel.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    local title = Instance.new("TextLabel")
    title.Parent = panel
    title.Size = UDim2.new(1, 0, 0, 36)
    title.BackgroundTransparency = 1
    title.Text = "ATUALIZAÇÕES"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextXAlignment = Enum.TextXAlignment.Center

    local function makeSection(heading, text)
        local sec = Instance.new("Frame")
        sec.Parent = panel
        
        -- Estimate height based on character count and newlines
        local _, lineCount = text:gsub("\n", "\n")
        lineCount = lineCount + 1
        local estimatedHeight = 44 + (lineCount * 18)
        if estimatedHeight < 120 then estimatedHeight = 120 end
        sec.Size = UDim2.new(1, -10, 0, estimatedHeight)
        sec.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
        sec.BorderSizePixel = 0

        local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 6) rc.Parent = sec

        local h = Instance.new("TextLabel")
        h.Parent = sec
        h.Size = UDim2.new(1, -16, 0, 28)
        h.Position = UDim2.new(0, 8, 0, 8)
        h.BackgroundTransparency = 1
        h.Text = heading
        h.Font = Enum.Font.SourceSansSemibold
        h.TextSize = 16
        h.TextColor3 = Color3.fromRGB(220,220,220)
        h.TextXAlignment = Enum.TextXAlignment.Left

        local body = Instance.new("TextLabel")
        body.Parent = sec
        body.Size = UDim2.new(1, -16, 1, -44)
        body.Position = UDim2.new(0, 8, 0, 40)
        body.BackgroundTransparency = 1
        body.Text = text
        body.Font = Enum.Font.SourceSans
        body.TextSize = 14
        body.TextColor3 = Color3.fromRGB(235,235,235)
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left

        return sec
    end

    local adicionados = "- Novo Elemento: 🌊 Water (7 poderes)\n- Super Sonic adicionado nos Elementais"
    local corrigidos = "- Reorganização e ajuste das categorias de Elementais\n- Remoção do poder Draedron's Tech (não funcional)\n- Remoção de senha para a Halloween Sword (equipa direto)"

    makeSection("O que foi adicionado:", adicionados)
    makeSection("O que foi corrigido:", corrigidos)
end

local function showSite()
    limparConteudo()

    local container = Instance.new("Frame")
    container.Parent = ContentFrame
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1

    local btn = Instance.new("TextButton")
    btn.Parent = container
    btn.Size = UDim2.new(0, 300, 0, 40)
    btn.Position = UDim2.new(0.5, -150, 0.5, -20)
    btn.Text = "Abrir site"
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.fromRGB(245,245,245)
    btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    stylizeBtn(btn, Color3.fromRGB(0,120,255))

    local url = "https://elemental-menu.netlify.app/"

    btn.MouseButton1Click:Connect(function()
        local opened = false
        pcall(function()
            local GuiService = game:GetService("GuiService")
            if GuiService and GuiService.OpenBrowserWindow then
                GuiService:OpenBrowserWindow(url)
                opened = true
            end
        end)

        if not opened then
            pcall(function()
                if setclipboard then setclipboard(url) opened = true end
            end)
        end

        local info = Instance.new("TextLabel")
        info.Parent = container
        info.Size = UDim2.new(0, 360, 0, 28)
        info.Position = UDim2.new(0.5, -180, 0.5, 30)
        info.BackgroundTransparency = 1
        info.Font = Enum.Font.SourceSans
        info.TextSize = 14
        info.TextColor3 = Color3.fromRGB(220,220,220)
        if opened then
            info.Text = "Link copiado para a área de transferência."
        else
            info.Text = "Link copiado"
        end
        task.delay(2, function() if info and info.Parent then info:Destroy() end end)
    end)
end

local function showCaos()
    limparConteudo()

    pcall(function()
        if ScreenGui then
            for _, d in pairs(ScreenGui:GetDescendants()) do
                if d:IsA("TextBox") and d.MultiLine and #tostring(d.Text) > 50 then
                    d:Destroy()
                end
            end
        end
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = ContentFrame
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 390)
    scroll.ScrollBarThickness = 6
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0

    local info = Instance.new("TextLabel")
    info.Parent = scroll
    info.Size = UDim2.new(1, -20, 0, 60)
    info.Position = UDim2.new(0, 10, 0, 10)
    info.BackgroundTransparency = 1
    info.Text = "AUTO-ATTACK: teleporta para jogadores e ataca automaticamente. Escolha modo e alvo abaixo."
    info.Font = Enum.Font.SourceSans
    info.TextSize = 14
    info.TextColor3 = Color3.fromRGB(235,235,235)
    info.TextWrapped = true
    
--------aba beta auto-attack--------
    local betaTag = Instance.new("TextLabel")
    betaTag.Parent = scroll
    betaTag.Size = UDim2.new(0, 120, 0, 24)
    betaTag.Position = UDim2.new(1, -130, 0, 12)
    betaTag.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    betaTag.TextColor3 = Color3.fromRGB(255,255,255)
    betaTag.Font = Enum.Font.SourceSansBold
    betaTag.TextSize = 14
    betaTag.Text = "BETA"
    betaTag.TextXAlignment = Enum.TextXAlignment.Center
    betaTag.TextYAlignment = Enum.TextYAlignment.Center
    local betaCorner = Instance.new("UICorner") betaCorner.CornerRadius = UDim.new(0,6) betaCorner.Parent = betaTag
------------------------------------
    local G = (getgenv and getgenv()) or _G
    if not G.AUTO_ATTACK_CONTROLLER then
        G.AUTO_ATTACK_CONTROLLER = {
            running = false,
            threads = {},
            velocidade = 0.1,
            targetMode = "specific", -- "closest", "specific", or "none"
            selectedTarget = nil,
            currentTargetPos = nil
        }
    end
    local controller = G.AUTO_ATTACK_CONTROLLER

    local function ensureRemoteEvent()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            return remotes:FindFirstChild("RemoteEvent") or ReplicatedStorage:FindFirstChild("RemoteEvent")
        end
        return ReplicatedStorage:FindFirstChild("RemoteEvent")
    end

    local function getClosestPlayerFromChar(char)
        local PlayersS = game:GetService("Players")
        local lp = PlayersS.LocalPlayer
        local target = nil
        local dist = math.huge
        if not (char and char:FindFirstChild("HumanoidRootPart")) then return nil end
        for _, p in pairs(PlayersS:GetPlayers()) do
            if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local d = (char.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
                if d < dist then dist = d target = p end
            end
        end
        return target
    end

    local function attackLoop()
        while controller.running do
            local PlayersS = game:GetService("Players")
            local lp = PlayersS.LocalPlayer
            local char = lp and lp.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local targets = {}
                if controller.targetMode == "closest" then
                    for _, p in pairs(PlayersS:GetPlayers()) do
                        if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                            table.insert(targets, p)
                        end
                    end
                elseif controller.targetMode == "specific" then
                    if controller.selectedTarget then
                        local p = controller.selectedTarget
                        if p and p.Parent == PlayersS then
                            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                                table.insert(targets, p)
                            end
                        else
                            controller.selectedTarget = nil
                            selectedLabel.Text = "Alvo: Nenhum"
                            updateToggleLabels()
                        end
                    end
                elseif controller.targetMode == "none" then
                    table.insert(targets, "none")
                end

                for _, target in ipairs(targets) do
                    if not controller.running then break end

                    if typeof(target) == "Instance" and target:IsA("Player") and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        controller.currentTargetPos = target.Character.HumanoidRootPart.Position
                        pcall(function()
                            char.HumanoidRootPart.CFrame = CFrame.new(target.Character.HumanoidRootPart.Position + Vector3.new(0,3,0))
                        end)
                        task.wait(0.02)
                    end

                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        for _, tool in pairs(lp.Backpack:GetChildren()) do
                            if tool:IsA("Tool") and humanoid.Parent and humanoid.Health > 0 then
                                pcall(function()
                                    humanoid:EquipTool(tool)
                                end)
                                pcall(function() tool:Activate() end)
                            end
                        end
                        local equippedTool = char:FindFirstChildOfClass("Tool")
                        if equippedTool then
                            pcall(function() equippedTool:Activate() end)
                        end
                    end
                end
            end
            task.wait(controller.velocidade)
        end
    end



    local function spellsLoop()
        local lastEquipTime = 0
        local currentSpell = nil
        while controller.running do
            local re = ensureRemoteEvent()
            if re then
                local PlayersS = game:GetService("Players")
                local lp = PlayersS.LocalPlayer
                local char = lp and lp.Character
                
                local now = os.time()
                -- Switch spell only every 5 seconds to prevent freezing/rate limiting
                if not currentSpell or (now - lastEquipTime) >= 5 then
                    currentSpell = magiasFiltradas[math.random(1, #magiasFiltradas)]
                    pcall(function()
                        re:FireServer("equip_mystery_spell", currentSpell)
                    end)
                    lastEquipTime = now
                    task.wait(0.15) -- brief delay to let the server process the equip
                end

                pcall(function()
                    if controller.targetMode == "closest" then
                        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                            if p ~= game:GetService("Players").LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                                pcall(function()
                                    re:FireServer("cast_spell", currentSpell, p.Character.HumanoidRootPart.Position)
                                end)
                            end
                        end
                    else
                        local castPos = controller.currentTargetPos
                        if not castPos then
                            local closest = getClosestPlayer()
                            if closest then
                                castPos = closest.Position
                            else
                                castPos = game:GetService("Players").LocalPlayer:GetMouse().Hit.p
                            end
                        end
                        re:FireServer("cast_spell", currentSpell, castPos)
                    end
                end)
            end
            task.wait(1)
        end
    end

    local toggleClosestBtn = Instance.new("TextButton")
    toggleClosestBtn.Parent = scroll
    toggleClosestBtn.Size = UDim2.new(1, -20, 0, 26)
    toggleClosestBtn.Position = UDim2.new(0, 10, 0, 80)
    toggleClosestBtn.Font = Enum.Font.SourceSansBold
    toggleClosestBtn.TextSize = 14
    stylizeBtn(toggleClosestBtn)

    local toggleSpecificBtn = Instance.new("TextButton")
    toggleSpecificBtn.Parent = scroll
    toggleSpecificBtn.Size = UDim2.new(1, -20, 0, 26)
    toggleSpecificBtn.Position = UDim2.new(0, 10, 0, 110)
    toggleSpecificBtn.Font = Enum.Font.SourceSansBold
    toggleSpecificBtn.TextSize = 14
    stylizeBtn(toggleSpecificBtn)

    local toggleNoneBtn = Instance.new("TextButton")
    toggleNoneBtn.Parent = scroll
    toggleNoneBtn.Size = UDim2.new(1, -20, 0, 26)
    toggleNoneBtn.Position = UDim2.new(0, 10, 0, 140)
    toggleNoneBtn.Font = Enum.Font.SourceSansBold
    toggleNoneBtn.TextSize = 14
    stylizeBtn(toggleNoneBtn)

    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Parent = scroll
    selectedLabel.Size = UDim2.new(0.6, -15, 0, 24)
    selectedLabel.Position = UDim2.new(0, 10, 0, 170)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Font = Enum.Font.SourceSans
    selectedLabel.TextSize = 14
    selectedLabel.TextColor3 = Color3.fromRGB(235,235,235)
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.Text = "Alvo: Nenhum"

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Parent = scroll
    refreshBtn.Size = UDim2.new(0.4, -15, 0, 24)
    refreshBtn.Position = UDim2.new(0.6, 10, 0, 170)
    refreshBtn.Font = Enum.Font.SourceSansBold
    refreshBtn.TextSize = 13
    refreshBtn.Text = "Atualizar Lista"
    stylizeBtn(refreshBtn, Color3.fromRGB(0, 100, 180))

    local playersList = Instance.new("ScrollingFrame")
    playersList.Parent = scroll
    playersList.Size = UDim2.new(1, -20, 0, 150)
    playersList.Position = UDim2.new(0, 10, 0, 198)
    playersList.CanvasSize = UDim2.new(0, 0, 0, 0)
    playersList.ScrollBarThickness = 6
    playersList.BackgroundTransparency = 1
    playersList.BorderSizePixel = 0

    local function clearPlayerList()
        for _, c in pairs(playersList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    local function updatePlayerList()
        clearPlayerList()
        local y = 0
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local btn = Instance.new("TextButton")
                btn.Parent = playersList
                btn.Size = UDim2.new(1, -8, 0, 28)
                btn.Position = UDim2.new(0, 4, 0, y)
                btn.Font = Enum.Font.SourceSans
                btn.TextSize = 14
                btn.Text = p.Name
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(235,235,235)
                btn.MouseButton1Click:Connect(function()
                    controller.selectedTarget = p
                    selectedLabel.Text = "Alvo: " .. p.Name
                    controller.stop()
                end)
                y = y + 32
            end
        end
        playersList.CanvasSize = UDim2.new(0, 0, 0, y)
    end

    refreshBtn.MouseButton1Click:Connect(updatePlayerList)

    updateToggleLabels = function()
        if not (toggleClosestBtn and toggleClosestBtn.Parent and toggleSpecificBtn and toggleSpecificBtn.Parent and toggleNoneBtn and toggleNoneBtn.Parent) then
            return
        end
        
        -- Resetar padrões
        toggleClosestBtn.Text = "Ativar AUTO-ATTACK: Próximo"
        toggleClosestBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        
        toggleSpecificBtn.Text = "Ativar AUTO-ATTACK: Alvo Específico"
        toggleSpecificBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        
        toggleNoneBtn.Text = "Ativar AUTO-ATTACK: Sem Teleporte"
        toggleNoneBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        
        if controller.running then
            if controller.targetMode == "closest" then
                toggleClosestBtn.Text = "Desativar AUTO-ATTACK: Próximo"
                toggleClosestBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
            elseif controller.targetMode == "specific" then
                toggleSpecificBtn.Text = "Desativar AUTO-ATTACK: Alvo Específico"
                toggleSpecificBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
            elseif controller.targetMode == "none" then
                toggleNoneBtn.Text = "Desativar AUTO-ATTACK: Sem Teleporte"
                toggleNoneBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
            end
        else
            -- Destacar o modo selecionado aguardando ativação por 'K'
            if controller.targetMode == "closest" then
                toggleClosestBtn.Text = "AUTO-ATTACK: Próximo [Selecionado - Aperte K]"
                toggleClosestBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
            elseif controller.targetMode == "specific" then
                toggleSpecificBtn.Text = "AUTO-ATTACK: Alvo Específico [Selecionado - Aperte K]"
                toggleSpecificBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
            elseif controller.targetMode == "none" then
                toggleNoneBtn.Text = "AUTO-ATTACK: Sem Teleporte [Selecionado - Aperte K]"
                toggleNoneBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
            end
        end
    end

    function controller.start()
        if controller.running then return end
        controller.running = true
        if updateToggleLabels then
            pcall(updateToggleLabels)
        end
        controller.threads.attack = task.spawn(attackLoop)
        controller.threads.spells = task.spawn(spellsLoop)
    end

    function controller.stop()
        controller.running = false
        if updateToggleLabels then
            pcall(updateToggleLabels)
        end
    end

    toggleClosestBtn.MouseButton1Click:Connect(function()
        controller.targetMode = "closest"
        controller.stop()
    end)

    toggleSpecificBtn.MouseButton1Click:Connect(function()
        controller.targetMode = "specific"
        controller.stop()
    end)

    toggleNoneBtn.MouseButton1Click:Connect(function()
        controller.targetMode = "none"
        controller.stop()
    end)

    local desligarCaosBtn = Instance.new("TextButton")
    desligarCaosBtn.Parent = scroll
    desligarCaosBtn.Size = UDim2.new(1, -20, 0, 30)
    desligarCaosBtn.Position = UDim2.new(0, 10, 0, 355)
    desligarCaosBtn.Font = Enum.Font.SourceSansBold
    desligarCaosBtn.TextSize = 14
    desligarCaosBtn.Text = "DESLIGAR CAOS (Desativar Tudo)"
    desligarCaosBtn.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
    desligarCaosBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stylizeBtn(desligarCaosBtn, Color3.fromRGB(160, 0, 0))

    desligarCaosBtn.MouseButton1Click:Connect(function()
        controller.stop()
        controller.selectedTarget = nil
        controller.targetMode = "specific"
        controller.currentTargetPos = nil
        selectedLabel.Text = "Alvo: Nenhum"
    end)

    updatePlayerList()
    updateToggleLabels()

    Players.PlayerAdded:Connect(function() task.wait(0.5) updatePlayerList() end)
    Players.PlayerRemoving:Connect(function(p)
        if controller.selectedTarget and controller.selectedTarget == p then
            controller.selectedTarget = nil
            selectedLabel.Text = "Alvo: Nenhum"
        end
        task.wait(0.5)
        updatePlayerList()
    end)
end

botoesAbas["Poderes"].MouseButton1Click:Connect(showPoderes)
botoesAbas["Combate"].MouseButton1Click:Connect(showCombate)
botoesAbas["Caos"].MouseButton1Click:Connect(showCaos)
botoesAbas["Movimento"].MouseButton1Click:Connect(showMovimento)
botoesAbas["Farm"].MouseButton1Click:Connect(showFarm)
botoesAbas["Visual"].MouseButton1Click:Connect(showVisual)
botoesAbas["mapa"].MouseButton1Click:Connect(showVisuaisAvancados)
botoesAbas["Efeitos"].MouseButton1Click:Connect(showEfeitos)
botoesAbas["Teleporte"].MouseButton1Click:Connect(showTeleporte)
botoesAbas["Void Launch"].MouseButton1Click:Connect(showVoidLaunch)
botoesAbas["Atualizações"].MouseButton1Click:Connect(showAtualizacoes)
botoesAbas["Site"].MouseButton1Click:Connect(showSite)

local function showDono()
    limparConteudo()

    local container = Instance.new("Frame")
    container.Parent = ContentFrame
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1

    local panel = Instance.new("Frame")
    panel.Parent = container
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    panel.BorderSizePixel = 0

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 8)
    panelCorner.Parent = panel

    local panelPadding = Instance.new("UIPadding")
    panelPadding.PaddingTop = UDim.new(0, 10)
    panelPadding.PaddingLeft = UDim.new(0, 10)
    panelPadding.PaddingRight = UDim.new(0, 10)
    panelPadding.PaddingBottom = UDim.new(0, 10)
    panelPadding.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Parent = panel
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Parent = panel
    title.Size = UDim2.new(1, 0, 0, 36)
    title.BackgroundTransparency = 1
    title.Text = "INFORMAÇÕES DO DONO"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextXAlignment = Enum.TextXAlignment.Center

    local function makeRow(heading, value)
        local row = Instance.new("Frame")
        row.Parent = panel
        row.Size = UDim2.new(1, 0, 0, 48)
        row.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
        row.BorderSizePixel = 0

        local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 6) rc.Parent = row

        local left = Instance.new("TextLabel")
        left.Parent = row
        left.Size = UDim2.new(0.38, -8, 1, 0)
        left.Position = UDim2.new(0, 8, 0, 0)
        left.BackgroundTransparency = 1
        left.Text = heading
        left.Font = Enum.Font.SourceSansSemibold
        left.TextSize = 14
        left.TextColor3 = Color3.fromRGB(200, 200, 200)
        left.TextXAlignment = Enum.TextXAlignment.Left

        local right = Instance.new("TextLabel")
        right.Parent = row
        right.Size = UDim2.new(0.62, -12, 1, 0)
        right.Position = UDim2.new(0.38, 0, 0, 0)
        right.BackgroundTransparency = 1
        right.Text = value
        right.Font = Enum.Font.Gotham
        right.TextSize = 14
        right.TextColor3 = Color3.fromRGB(245, 245, 245)
        right.TextXAlignment = Enum.TextXAlignment.Left
        right.TextWrapped = true

        return row
    end

    makeRow("Criado por", "davymods")
    makeRow("Contato", "discord.gg/davy102  •  +55 94 9185-5060")
    makeRow("Redes", "Instagram: davyf22l1  •  TikTok: drak_ylon")

    local descRow = Instance.new("Frame")
    descRow.Parent = panel
    descRow.Size = UDim2.new(1, 0, 0, 80)
    descRow.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    descRow.BorderSizePixel = 0
    local descCorner = Instance.new("UICorner") descCorner.CornerRadius = UDim.new(0,6) descCorner.Parent = descRow

    local descLabel = Instance.new("TextLabel")
    descLabel.Parent = descRow
    descLabel.Size = UDim2.new(1, -16, 1, -12)
    descLabel.Position = UDim2.new(0, 8, 0, 6)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = "Sejam bem-vindos ao melhor modo menu do Elemental Powers Tycoon — aproveitem as funcionalidades e divirtam-se!"
    descLabel.TextWrapped = true
    descLabel.Font = Enum.Font.SourceSans
    descLabel.TextSize = 14
    descLabel.TextColor3 = Color3.fromRGB(220, 220, 220)

end

botoesAbas["Informações do Dono"].MouseButton1Click:Connect(showDono)


function getClosestPlayer()
    local target = nil
    local dist = math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local d = (LocalPlayer.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if d < dist then
                dist = d
                target = p.Character.HumanoidRootPart
            end
        end
    end
    return target
end

function obterAlvoAtaques()
    if ATAQUES_USA_ALVO_ESPECIFICO then
        if ATAQUES_ALVO_SELECIONADO then
            local p = ATAQUES_ALVO_SELECIONADO
            if p and p.Parent == Players then
                if ATAQUES_ALVO_ATIVO and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    return p.Character.HumanoidRootPart
                end
            else
                ATAQUES_ALVO_SELECIONADO = nil
            end
        end
        return nil
    end
    return getClosestPlayer()
end

local oldFireServer
task.spawn(function()
    local remote = gRE()
    if not remote then
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if remotes then
            remote = remotes:WaitForChild("RemoteEvent", 10)
        end
        if not remote then
            remote = ReplicatedStorage:WaitForChild("RemoteEvent", 10)
        end
    end
    
    if remote then
        MAIN_REMOTE = remote
        pcall(function()
            oldFireServer = hookfunction(remote.FireServer, function(re, ...)
                local args = {...}
                local isSpellCall = false
                
                if args[1] == "fire_spell" or args[1] == "cast_spell" then
                    isSpellCall = true
                end
                
                if ATAQUES_TELEPORTADOS_ATIVADO then
                    local targetRoot = obterAlvoAtaques()
                    if targetRoot then
                        local targetChar = targetRoot.Parent
                        local targetPlr = Players:GetPlayerFromCharacter(targetChar)
                        
                        local myChar = LocalPlayer.Character
                        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                        
                        if myRoot then
                            local dist = (myRoot.Position - targetRoot.Position).Magnitude
                            if dist > 20 then
                                task.spawn(function()
                                    local oldCFrame = myRoot.CFrame
                                    
                                    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 4, 0)
                                    task.wait(0.04)
                                    
                                    for i = 1, #args do
                                        if typeof(args[i]) == "Vector3" then
                                            args[i] = targetRoot.Position
                                        elseif typeof(args[i]) == "CFrame" then
                                            args[i] = CFrame.new(targetRoot.Position)
                                        elseif typeof(args[i]) == "Instance" then
                                            if args[i]:IsA("Player") and args[i] ~= LocalPlayer then
                                                if targetPlr then args[i] = targetPlr end
                                            elseif args[i]:IsA("Model") and args[i]:FindFirstChildOfClass("Humanoid") and args[i] ~= LocalPlayer.Character then
                                                if targetChar then args[i] = targetChar end
                                            elseif args[i]:IsA("BasePart") then
                                                local parentModel = args[i]:FindFirstAncestorOfClass("Model")
                                                if parentModel and parentModel:FindFirstChildOfClass("Humanoid") and parentModel ~= LocalPlayer.Character then
                                                    if targetChar then
                                                        args[i] = targetChar:FindFirstChild(args[i].Name) or targetRoot
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    oldFireServer(re, unpack(args))
                                    if NO_COOLDOWN_ATIVADO then
                                        oldFireServer(re, unpack(args))
                                        oldFireServer(re, unpack(args))
                                    end
                                    
                                    myRoot.CFrame = oldCFrame
                                end)
                                return
                            end
                        end
                        
                        for i = 1, #args do
                            if typeof(args[i]) == "Vector3" then
                                args[i] = targetRoot.Position
                                isSpellCall = true
                            elseif typeof(args[i]) == "CFrame" then
                                args[i] = CFrame.new(targetRoot.Position)
                                isSpellCall = true
                            elseif typeof(args[i]) == "Instance" then
                                if args[i]:IsA("Player") and args[i] ~= LocalPlayer then
                                    if targetPlr then args[i] = targetPlr end
                                    isSpellCall = true
                                elseif args[i]:IsA("Model") and args[i]:FindFirstChildOfClass("Humanoid") and args[i] ~= LocalPlayer.Character then
                                    if targetChar then args[i] = targetChar end
                                    isSpellCall = true
                                elseif args[i]:IsA("BasePart") then
                                    local parentModel = args[i]:FindFirstAncestorOfClass("Model")
                                    if parentModel and parentModel:FindFirstChildOfClass("Humanoid") and parentModel ~= LocalPlayer.Character then
                                        if targetChar then
                                            args[i] = targetChar:FindFirstChild(args[i].Name) or targetRoot
                                            isSpellCall = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif SILENT_AIM_ATIVADO and args[1] == "fire_spell" then
                    local target = getClosestPlayer()
                    if target then args[3] = target.Position end
                end
                
                if NO_COOLDOWN_ATIVADO and isSpellCall then
                    oldFireServer(re, unpack(args))
                    oldFireServer(re, unpack(args))
                end
                
                return oldFireServer(re, unpack(args))
            end)
        end)
    end
end)

local function monitorarETeleportarProjeteis(child)
    if not ATAQUES_TELEPORTADOS_ATIVADO then return end
    
    task.wait()
    if not child or not child.Parent then return end
    
    local targetPart = obterAlvoAtaques()
    if not targetPart then return end
    
    local targetChar = targetPart.Parent
    if not targetChar then return end
    
    if child:IsA("BasePart") or child:IsA("Model") then
        if child.Name == "Card" or child.Name == "Cash" or child.Name:lower():find("ore") or child.Name:lower():find("drop") then
            return
        end
        if Players:GetPlayerFromCharacter(child) then return end
        
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local primaryPart = child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or child
            if primaryPart and primaryPart:IsA("BasePart") then
                local dist = (primaryPart.Position - root.Position).Magnitude
                if dist < 15 then
                    task.spawn(function()
                        for i = 1, 40 do
                            if not ATAQUES_TELEPORTADOS_ATIVADO or not child.Parent or not targetPart.Parent then break end
                            local targetPos = targetPart.Position
                            
                            if child:IsA("Model") then
                                child:PivotTo(CFrame.new(targetPos))
                            else
                                child.CFrame = CFrame.new(targetPos)
                            end
                            
                            if firetouchinterest then
                                local targetParts = {}
                                for _, part in pairs(targetChar:GetChildren()) do
                                    if part:IsA("BasePart") then
                                        table.insert(targetParts, part)
                                    end
                                end
                                
                                local partsToTouch = {}
                                if child:IsA("Model") then
                                    for _, p in pairs(child:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                            table.insert(partsToTouch, p)
                                        end
                                    end
                                else
                                    table.insert(partsToTouch, child)
                                end
                                
                                local activeTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                                if activeTool then
                                    for _, p in pairs(activeTool:GetDescendants()) do
                                        if p:IsA("BasePart") then
                                            table.insert(partsToTouch, p)
                                        end
                                    end
                                end
                                
                                for _, tPart in ipairs(targetParts) do
                                    for _, part in ipairs(partsToTouch) do
                                        pcall(firetouchinterest, part, tPart, 0)
                                        pcall(firetouchinterest, part, tPart, 1)
                                    end
                                end
                            end
                            
                            task.wait(0.05)
                        end
                    end)
                end
            end
        end
    end
end

local function setupProjectileListener(folder)
    if not folder:IsA("Folder") and not folder:IsA("Model") then return end
    folder.ChildAdded:Connect(monitorarETeleportarProjeteis)
end

task.spawn(function()
    for _, child in pairs(Workspace:GetChildren()) do
        if child:IsA("Folder") or (child:IsA("Model") and child.Name ~= LocalPlayer.Name) then
            pcall(setupProjectileListener, child)
        end
    end
    
    Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Folder") or (child:IsA("Model") and child.Name ~= LocalPlayer.Name) then
            pcall(setupProjectileListener, child)
        end
        pcall(monitorarETeleportarProjeteis, child)
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if ATAQUES_TELEPORTADOS_ATIVADO then
            pcall(function()
                local targetRoot = obterAlvoAtaques()
                if targetRoot and targetRoot.Parent then
                    local targetChar = targetRoot.Parent
                    local char = LocalPlayer.Character
                    local tool = char and char:FindFirstChildOfClass("Tool")
                    if tool then
                        local targetParts = {}
                        for _, part in pairs(targetChar:GetChildren()) do
                            if part:IsA("BasePart") then
                                table.insert(targetParts, part)
                            end
                        end
                        
                        for _, part in pairs(tool:GetDescendants()) do
                            if part:IsA("BasePart") then
                                if firetouchinterest then
                                    for _, tPart in ipairs(targetParts) do
                                        pcall(firetouchinterest, part, tPart, 0)
                                        pcall(firetouchinterest, part, tPart, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if ATAQUES_ALVO_SELECIONADO == p then
        ATAQUES_ALVO_SELECIONADO = nil
    end
end)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        if ATIVADO_SPEED then hum.WalkSpeed = VELOCIDADE_PADRAO end
        if GOD_MODE_ATIVADO then hum.Health = hum.MaxHealth end
        
        if NO_COOLDOWN_ATIVADO then
            for _, v in pairs(LocalPlayer.Backpack:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    if v.Name:lower():find("cooldown") or v.Name:lower():find("wait") or v.Name:lower():find("reload") then
                        v.Value = 0
                    end
                end
            end
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    if v.Name:lower():find("cooldown") or v.Name:lower():find("wait") or v.Name:lower():find("reload") then
                        v.Value = 0
                    end
                end
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if NO_CLIP_ATIVADO and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

task.spawn(function()
    while true do
        if KILL_AURA_ATIVADO and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local target = getClosestPlayer()
            if target and (LocalPlayer.Character.HumanoidRootPart.Position - target.Position).Magnitude <= 25 then
                local RE = gRE()
                if RE then RE:FireServer("fire_spell", "Dark Flames", target.Position) end
            end
        end
        task.wait(NO_COOLDOWN_ATIVADO and 0.01 or 0.3)
    end
end)

local bv, bg
RunService.RenderStepped:Connect(function()
    if FLY_ATIVADO and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if not bv then
            bv = Instance.new("BodyVelocity", root)
            bg = Instance.new("BodyGyro", root)
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        end
        bg.CFrame = Camera.CFrame
        local dir = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        bv.Velocity = dir * FLY_SPEED
    else
        if bv then bv:Destroy() bv = nil end
        if bg then bg:Destroy() bg = nil end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if INF_JUMP_ATIVADO and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local burstRunning = false
local lastBurstTrigger = 0
local function executarBurst()
    if not BURST_NO_F_ATIVADO then return end
    
    local now = os.clock()
    if now - lastBurstTrigger < 0.2 then
        return
    end
    lastBurstTrigger = now
    
    if burstRunning then
        burstRunning = false
        warn("[Elemental Menu] Cancelando burst atual...")
        return
    end
    
    local re = ReplicatedStorage:FindFirstChild("Remotes") and (ReplicatedStorage.Remotes:FindFirstChild("RemoteEvent") or ReplicatedStorage:FindFirstChild("RemoteEvent")) or ReplicatedStorage:FindFirstChild("RemoteEvent")
    if not re then return end

    local castPos = nil
    local targetRoot = obterAlvoAtaques()
    if targetRoot then
        castPos = targetRoot.Position
    else
        castPos = LocalPlayer:GetMouse().Hit.p
    end
    
    burstRunning = true
    task.spawn(function()
        local success, err = pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local bp = LocalPlayer:FindFirstChild("Backpack")
            
            -- Coleta todas as tools/magias que o jogador possui no momento
            local ownedTools = {}
            if char then
                for _, tool in pairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        table.insert(ownedTools, tool.Name)
                    end
                end
            end
            if bp then
                for _, tool in pairs(bp:GetChildren()) do
                    if tool:IsA("Tool") then
                        table.insert(ownedTools, tool.Name)
                    end
                end
            end

            -- Conjura as magias que o jogador possui (tools)
            for _, toolName in ipairs(ownedTools) do
                if not burstRunning then break end
                pcall(function()
                    re:FireServer("fire_spell", toolName, castPos)
                end)
                if NO_COOLDOWN_ATIVADO then
                    pcall(function()
                        re:FireServer("fire_spell", toolName, castPos)
                    end)
                end
            end

            -- Conjura o restante das magias filtradas do jogo, equipando-as fisicamente (como o modo Caos faz no loop de ataque)
            for _, spell in ipairs(magiasFiltradas) do
                if not burstRunning then break end
                
                pcall(function()
                    re:FireServer("equip_mystery_spell", spell)
                end)
                
                -- Aguarda a tool correspondente aparecer na mochila
                local tool = nil
                for i = 1, 8 do
                    if not burstRunning then break end
                    if not bp then break end
                    tool = bp:FindFirstChild(spell) or (char and char:FindFirstChild(spell))
                    if tool then break end
                    task.wait(0.015)
                end
                
                -- Se após o loop ainda não achou a tool específica, tenta pegar qualquer tool genérica recém-criada
                if not tool and bp and burstRunning then
                    for _, t in pairs(bp:GetChildren()) do
                        if t:IsA("Tool") then
                            tool = t
                            break
                        end
                    end
                end
                
                if not burstRunning then break end
                
                -- Se encontrou a tool, equipa e ativa fisicamente
                if tool and humanoid and humanoid.Health > 0 then
                    pcall(function()
                        humanoid:EquipTool(tool)
                    end)
                    task.wait(0.03) -- tempo para empunhar a tool
                    
                    if not burstRunning then break end
                    
                    pcall(function()
                        tool:Activate()
                    end)
                end
                
                if not burstRunning then break end
                
                -- Dispara os remotes de ataque adicionais
                pcall(function()
                    re:FireServer("fire_spell", spell, castPos)
                    re:FireServer("cast_spell", spell, castPos)
                end)
                
                if NO_COOLDOWN_ATIVADO then
                    pcall(function()
                        re:FireServer("fire_spell", spell, castPos)
                        re:FireServer("cast_spell", spell, castPos)
                    end)
                    if tool then
                        pcall(function() tool:Activate() end)
                    end
                end
                task.wait(0.02)
            end
        end)
        
        if not success then
            warn("[Elemental Menu] Erro na execução do burst:", err)
        end
        burstRunning = false
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if UserInputService:GetFocusedTextBox() then return end
    if bindingKey then return end

    if input.KeyCode == FARM_KEYBIND and FARM_KEYBIND ~= Enum.KeyCode.Unknown and FARM_KEYBIND ~= Enum.KeyCode.None then
        AUTO_BUY_ENABLED = not AUTO_BUY_ENABLED
        if AUTO_BUY_ENABLED then
            if not AUTO_BUY_RUNNING then
                AUTO_BUY_RUNNING = true
                task.spawn(autoBuyLoop)
            end
            atualizarFarmStatus("Comprando botões...")
        else
            atualizarFarmStatus("Parado")
        end
        if farmStatusLabel and farmStatusLabel.Parent then
            showFarm()
        end
    elseif input.KeyCode == Enum.KeyCode.G then
        teleportToSpawn()
    elseif input.KeyCode == Enum.KeyCode.F then
        executarBurst()
    elseif input.KeyCode == Enum.KeyCode.K then
        -- 1. Controle do Ataque Teleportado (Aba Combate)
        if ATAQUES_USA_ALVO_ESPECIFICO and ATAQUES_ALVO_SELECIONADO then
            ATAQUES_ALVO_ATIVO = not ATAQUES_ALVO_ATIVO
            if ATAQUES_ALVO_ATIVO then
                ATAQUES_TELEPORTADOS_ATIVADO = true
            end
            if updateSelectedLabelText then
                pcall(updateSelectedLabelText)
            end
        end

        -- 2. Controle do Auto-Attack (Aba Caos)
        local G = (getgenv and getgenv()) or _G
        local controller = G.AUTO_ATTACK_CONTROLLER
        if controller then
            if controller.running then
                controller.stop()
            else
                if controller.targetMode == "specific" then
                    if controller.selectedTarget then
                        controller.start()
                    end
                else
                    controller.start()
                end
            end
        end
    end
end)

pcall(function()
    LocalPlayer:GetMouse().KeyDown:Connect(function(key)
        if key:lower() == "f" then
            executarBurst()
        end
    end)
end)

local ESP_Objects = {}

local function createESP(player)
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Color3.new(1, 1, 1)
    tracer.Thickness = 1.5
    tracer.Transparency = 0.8

    local text = Drawing.new("Text")
    text.Visible = false
    text.Color = Color3.new(1, 1, 1)
    text.Size = 24
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.new(0, 0, 0)
    text.Font = 2 

    ESP_Objects[player] = {Tracer = tracer, Text = text}
end

local function removeESP(player)
    if ESP_Objects[player] then
        ESP_Objects[player].Tracer:Remove()
        ESP_Objects[player].Text:Remove()
        ESP_Objects[player] = nil
    end
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESP(p) end
end

RunService.RenderStepped:Connect(function()
    if ESP_ATIVADO then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if not p.Character:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", p.Character)
                    h.FillColor = Color3.fromRGB(255, 255, 255)
                    h.OutlineColor = Color3.fromRGB(0, 0, 0)
                end
            end
        end
    end

    local inset = game:GetService("GuiService"):GetGuiInset()
    for player, objects in pairs(ESP_Objects) do
        local char = player.Character
        local tracer = objects.Tracer
        local text = objects.Text

        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local head = char.Head
            local hum = char.Humanoid
            local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))

            if onScreen and (ESP_LINHAS or ESP_NOMES or ESP_VIDA) then
                local distance = (Camera.CFrame.Position - head.Position).Magnitude
                local healthPercent = hum.Health / hum.MaxHealth
                local healthColor = Color3.fromHSV(healthPercent * 0.3, 1, 1)
                local screenPos = Vector2.new(headPos.X, headPos.Y + inset.Y)

                if ESP_LINHAS then
                    tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y + inset.Y)
                    tracer.To = screenPos
                    tracer.Color = healthColor
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end

                if ESP_NOMES or ESP_VIDA then
                    local content = ""
                    if ESP_NOMES then content = content .. player.Name end
                    if ESP_VIDA then 
                        content = content .. (ESP_NOMES and " | " or "") .. math.floor(hum.Health) .. " HP"
                    end
                    
                    text.Text = content
                    text.Position = screenPos
                    text.Color = healthColor
                    text.Visible = true
                    text.Size = math.clamp(32 - (distance / 12), 16, 32)
                else
                    text.Visible = false
                end
            else
                tracer.Visible = false
                text.Visible = false
            end
        else
            tracer.Visible = false
            text.Visible = false
        end
    end
end)


LocalPlayer.CharacterAdded:Connect(function(newChar)
    if EFEITOS_VISUAIS_ATIVADO and EFEITO_SELECIONADO then
        task.wait(0.5)
        criarEfeitoRaios(newChar, EFEITOS_CONFIG[EFEITO_SELECIONADO])
    end
end)

showPoderes()
print("Menu Carregado")
