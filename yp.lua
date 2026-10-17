--// AAYAN V4 - FULL SCRIPT
--// Premium GUI + aura + sound system + customizer + INFO tab
--// ROBLOX LOCAL SCRIPT

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

--==================================================
-- SETTINGS YOU MAY WANT TO CHANGE
--==================================================

local SONG_ID = 86804131922977
-- Gap between every element. Roblox offsets are whole pixels,
-- so the requested 0.9 gap is rounded to 1 pixel.
local GAP = 1

--==================================================
-- CHARACTER HELPERS
--==================================================

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getRoot()
	local character = getCharacter()
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHum()
	local character = getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

--==================================================
-- CONFIG
--==================================================

local Config = {
	AntiVoid = false,
	AntiFling = false,
	AntiSit = false,
	Spd = false,
	Spin = false,
	InfJump = false,
	CurrentTroll = nil
}

--==================================================
-- THEME + REGISTRY (everything the customizer can change)
--==================================================

local Defaults = {
	A1 = Color3.fromRGB(0, 200, 255),
	A2 = Color3.fromRGB(160, 60, 255),
	Scale = 1,
	Opacity = 0.1,
	AuraPower = 0.75,
	Aura = true,
	Particles = true,
	Rainbow = false,
	Spin = true,
	Round = 1,
	FontIndex = 1,
	Volume = 0.6
}

local Theme = {}
for k, v in pairs(Defaults) do
	Theme[k] = v
end
Theme.Text = Color3.fromRGB(245, 247, 255)
Theme.Muted = Color3.fromRGB(160, 165, 205)

local Fonts = {
	Enum.Font.GothamBold,
	Enum.Font.FredokaOne,
	Enum.Font.SciFi,
	Enum.Font.Arcade,
	Enum.Font.Code
}
local FontNames = { "GOTHAM", "FREDOKA", "SCI-FI", "ARCADE", "CODE" }

local Reg = {
	grads = {},
	buttons = {},
	tabs = {},
	corners = {},
	texts = {},
	fields = {},
	cards = {},
	accentFns = {},
	lookFns = {}
}

local Hooks = {} -- per-frame effects run by one single driver loop
local activeTab = nil
local mainOpen = false
local mainTweens = {}

local function mixColor()
	return Theme.A1:Lerp(Theme.A2, 0.5)
end

local function shade(f)
	return mixColor():Lerp(Color3.new(0, 0, 0), 1 - f)
end

local function refreshShadeCache()
	Theme._n = shade(0.22)
	Theme._h = shade(0.36)
	Theme._a = shade(0.55)
	Theme._field = shade(0.14)
	Theme._card = shade(0.10)
end
refreshShadeCache()

local function addGradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Scale that keeps the GUI usable on small phone screens
local function viewScale()
	local cam = workspace.CurrentCamera
	if not cam then return 1 end
	local v = cam.ViewportSize
	return math.clamp(math.min(v.Y / 420, v.X / 440), 0.55, 1)
end

local function baseScale()
	return viewScale() * Theme.Scale
end

-- Border stroke with an accent gradient (stroke gradients never tint text)
local function borderStroke(parent, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.Color = Color3.new(1, 1, 1)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	local g = addGradient(s, Theme.A1, Theme.A2, 0)
	table.insert(Reg.grads, g)
	return s, g
end

local function regCorner(inst, base)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, math.floor(base * Theme.Round + 0.5))
	c.Parent = inst
	table.insert(Reg.corners, { c = c, base = base })
	return c
end

--==================================================
-- CLEAN OLD COPIES (no duplicates on re-execute)
--==================================================

local old = PlayerGui:FindFirstChild("AAYAN_PAPA_SPECIAL")
if old then
	old:Destroy()
end

local oldMusic = SoundService:FindFirstChild("AAYAN_V4_MUSIC")
if oldMusic then
	oldMusic:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "AAYAN_PAPA_SPECIAL"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = PlayerGui

-- connections / objects that must be cleaned when the GUI is destroyed
local Cleanup = {}
sg.Destroying:Connect(function()
	for _, c in ipairs(Cleanup) do
		pcall(function() c:Disconnect() end)
	end
	local leftoverBlur = Lighting:FindFirstChild("KINGS_V3_BLUR")
	if leftoverBlur then leftoverBlur:Destroy() end
end)

--==================================================
-- DRAG FUNCTION (handle = optional part of the frame used to grab it)
--==================================================

local function makeDraggable(frame, handle)
	local dragging = false
	local dragStart
	local startPos

	;(handle or frame).InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	table.insert(Cleanup, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then

			local delta = input.Position - dragStart

			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end))
end

--==================================================
-- AVATAR THUMBNAIL (real avatar of the local player)
--==================================================

local avatarImage = ""
do
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)
	if ok and img and img ~= "" then
		avatarImage = img
	else
		avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	end
end

--==================================================
-- INTRO: NAME -> GANG -> TARGET (3 compact GUIs)
--==================================================

local playerName, gangName, targetName

do
	local oldSetup = PlayerGui:FindFirstChild("KINGS_V3_SETUP")
	if oldSetup then oldSetup:Destroy() end
	local oldBlur = Lighting:FindFirstChild("KINGS_V3_BLUR")
	if oldBlur then oldBlur:Destroy() end

	local setupGui = Instance.new("ScreenGui")
	setupGui.Name = "KINGS_V3_SETUP"
	setupGui.ResetOnSpawn = false
	setupGui.IgnoreGuiInset = true
	setupGui.DisplayOrder = 500
	setupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	setupGui.Parent = PlayerGui

	local blur = Instance.new("BlurEffect")
	blur.Name = "KINGS_V3_BLUR"
	blur.Size = 0
	blur.Parent = Lighting

	setupGui.Destroying:Connect(function()
		if blur and blur.Parent then blur:Destroy() end
	end)

	local FIELD = Color3.fromRGB(22, 24, 54)
	local BORDER_IDLE = Color3.fromRGB(110, 80, 230)

	local function runStep(heading, subtitle, placeholder, iconText, buttonText)
		local result = nil
		local submitted = false
		local finished = Instance.new("BindableEvent")

		-- CanvasGroup is only used for fading. NO gradient on the group itself
		-- (a UIGradient on a CanvasGroup tints everything inside = black GUI).
		local card = Instance.new("CanvasGroup")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.new(0.5, 0, 0.5, 0)
		card.Size = UDim2.new(0, 290, 0, 244)
		card.BackgroundTransparency = 1
		card.BorderSizePixel = 0
		card.GroupTransparency = 1
		card.Parent = setupGui

		local scale = Instance.new("UIScale")
		scale.Scale = viewScale() * 0.85
		scale.Parent = card

		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

		local _, cardStrokeGrad = borderStroke(card, 2.5, 0)

		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.BackgroundTransparency = 0.06
		bg.BorderSizePixel = 0
		bg.ZIndex = 1
		bg.Parent = card
		addGradient(bg, Color3.fromRGB(20, 22, 56), Color3.fromRGB(10, 10, 28), 90)

		-- vertical column, every element 1px apart
		local col = Instance.new("Frame")
		col.Size = UDim2.new(1, 0, 1, 0)
		col.BackgroundTransparency = 1
		col.ZIndex = 2
		col.Parent = card

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, GAP)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = col

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.Parent = col

		-- avatar
		local ringHolder = Instance.new("Frame")
		ringHolder.LayoutOrder = 1
		ringHolder.Size = UDim2.new(1, 0, 0, 72)
		ringHolder.BackgroundTransparency = 1
		ringHolder.ZIndex = 3
		ringHolder.Parent = col

		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0.5, 0, 0.5, 0)
		ring.Size = UDim2.new(0, 66, 0, 66)
		ring.BackgroundColor3 = Color3.fromRGB(16, 30, 80)
		ring.BorderSizePixel = 0
		ring.ZIndex = 3
		ring.Parent = ringHolder
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local _, ringGrad = borderStroke(ring, 3, 0)

		local avatar = Instance.new("ImageLabel")
		avatar.AnchorPoint = Vector2.new(0.5, 0.5)
		avatar.Position = UDim2.new(0.5, 0, 0.5, 0)
		avatar.Size = UDim2.new(1, -10, 1, -10)
		avatar.BackgroundTransparency = 1
		avatar.Image = avatarImage
		avatar.ScaleType = Enum.ScaleType.Crop
		avatar.ZIndex = 4
		avatar.Parent = ring
		Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

		-- heading
		local head = Instance.new("TextLabel")
		head.LayoutOrder = 2
		head.Size = UDim2.new(1, -30, 0, 28)
		head.BackgroundTransparency = 1
		head.Text = heading
		head.TextColor3 = Color3.new(1, 1, 1)
		head.Font = Enum.Font.GothamBlack
		head.TextScaled = true
		head.ZIndex = 3
		head.Parent = col
		local headLimit = Instance.new("UITextSizeConstraint")
		headLimit.MaxTextSize = 22
		headLimit.MinTextSize = 11
		headLimit.Parent = head
		addGradient(head, Color3.fromRGB(80, 220, 255), Color3.fromRGB(240, 130, 255), 0)

		local sub = Instance.new("TextLabel")
		sub.LayoutOrder = 3
		sub.Size = UDim2.new(1, -30, 0, 18)
		sub.BackgroundTransparency = 1
		sub.Text = subtitle
		sub.TextColor3 = Theme.Muted
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 12
		sub.ZIndex = 3
		sub.Parent = col

		-- small name box
		local field = Instance.new("Frame")
		field.LayoutOrder = 4
		field.Size = UDim2.new(1, -44, 0, 34)
		field.BackgroundColor3 = FIELD
		field.BorderSizePixel = 0
		field.ZIndex = 3
		field.Parent = col
		Instance.new("UICorner", field).CornerRadius = UDim.new(0, 10)
		local fieldStroke = Instance.new("UIStroke")
		fieldStroke.Thickness = 1.5
		fieldStroke.Color = BORDER_IDLE
		fieldStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		fieldStroke.Parent = field

		local icon = Instance.new("TextLabel")
		icon.Position = UDim2.new(0, 8, 0, 0)
		icon.Size = UDim2.new(0, 24, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = iconText
		icon.TextSize = 16
		icon.TextColor3 = Theme.Muted
		icon.Font = Enum.Font.GothamBold
		icon.ZIndex = 4
		icon.Parent = field

		local box = Instance.new("TextBox")
		box.Position = UDim2.new(0, 36, 0, 0)
		box.Size = UDim2.new(1, -44, 1, 0)
		box.BackgroundTransparency = 1
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(150, 155, 195)
		box.Text = ""
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 14
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.ClearTextOnFocus = false
		box.ClipsDescendants = true
		box.ZIndex = 4
		box.Parent = field

		-- solid colour button (a gradient would tint its text); gradient is on the border
		local button = Instance.new("TextButton")
		button.LayoutOrder = 5
		button.Size = UDim2.new(1, -44, 0, 36)
		button.BackgroundColor3 = Color3.fromRGB(40, 100, 235)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = buttonText .. "  →"
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBlack
		button.TextSize = 16
		button.ZIndex = 3
		button.Parent = col
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
		borderStroke(button, 1.8, 0)

		local hint = Instance.new("TextLabel")
		hint.LayoutOrder = 6
		hint.Size = UDim2.new(1, -30, 0, 18)
		hint.BackgroundTransparency = 1
		hint.Text = "Press Enter to continue"
		hint.TextColor3 = Theme.Muted
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 11
		hint.ZIndex = 3
		hint.Parent = col

		local close = Instance.new("TextButton")
		close.Position = UDim2.new(1, -34, 0, 8)
		close.Size = UDim2.new(0, 26, 0, 26)
		close.BackgroundColor3 = FIELD
		close.Text = "✕"
		close.TextColor3 = Color3.new(1, 1, 1)
		close.Font = Enum.Font.GothamBold
		close.TextSize = 13
		close.AutoButtonColor = false
		close.ZIndex = 6
		close.Parent = card
		Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
		local closeStroke = Instance.new("UIStroke")
		closeStroke.Thickness = 1
		closeStroke.Color = Color3.fromRGB(100, 100, 170)
		closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		closeStroke.Parent = close

		local alive = true
		task.spawn(function()
			local rot = 0
			while alive and card.Parent do
				rot = (rot + 2) % 360
				cardStrokeGrad.Rotation = rot
				ringGrad.Rotation = -rot
				task.wait(0.03)
			end
		end)

		button.MouseEnter:Connect(function()
			tween(button, 0.15, { BackgroundColor3 = Color3.fromRGB(70, 130, 255) })
		end)
		button.MouseLeave:Connect(function()
			tween(button, 0.15, { BackgroundColor3 = Color3.fromRGB(40, 100, 235) })
		end)
		button.MouseButton1Down:Connect(function()
			tween(button, 0.08, { BackgroundColor3 = Color3.fromRGB(110, 60, 220) })
		end)
		box.Focused:Connect(function()
			tween(fieldStroke, 0.2, { Color = Color3.fromRGB(0, 210, 255) })
		end)
		box.FocusLost:Connect(function()
			tween(fieldStroke, 0.2, { Color = BORDER_IDLE })
		end)

		tween(blur, 0.5, { Size = 14 })
		tween(card, 0.45, { GroupTransparency = 0 })
		tween(scale, 0.5, { Scale = viewScale() }, Enum.EasingStyle.Back)

		local function closeCard(value)
			if submitted then return end
			submitted = true
			result = value
			alive = false
			tween(card, 0.3, { GroupTransparency = 1 })
			local out = tween(scale, 0.3, { Scale = viewScale() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			out.Completed:Wait()
			card:Destroy()
			finished:Fire()
		end

		local function shake()
			local origin = box.Position
			for _, dx in ipairs({ 8, -8, 5, -5, 0 }) do
				box.Position = origin + UDim2.new(0, dx, 0, 0)
				task.wait(0.03)
			end
			box.Position = origin
		end

		local function trySubmit()
			if submitted then return end
			local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
			if text == "" then
				tween(fieldStroke, 0.1, { Color = Color3.fromRGB(255, 80, 100) })
				task.spawn(shake)
				box.PlaceholderText = "This field can't be empty"
				task.delay(0.8, function()
					if not submitted then
						tween(fieldStroke, 0.2, { Color = BORDER_IDLE })
						box.PlaceholderText = placeholder
					end
				end)
				return
			end
			task.spawn(closeCard, text)
		end

		button.Activated:Connect(trySubmit)
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then trySubmit() end
		end)
		close.Activated:Connect(function()
			task.spawn(closeCard, nil)
		end)

		finished.Event:Wait()
		finished:Destroy()
		return result
	end

	local function showStatus(text, good)
		local toast = Instance.new("CanvasGroup")
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, -60)
		toast.Size = UDim2.new(0, 300, 0, 44)
		toast.BackgroundColor3 = Color3.fromRGB(14, 16, 38)
		toast.BorderSizePixel = 0
		toast.GroupTransparency = 1
		toast.Parent = setupGui
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 14)
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = good and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(255, 170, 60)
		s.Parent = toast
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -16, 1, 0)
		l.Position = UDim2.new(0, 8, 0, 0)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 13
		l.TextWrapped = true
		l.Parent = toast

		-- sits just under the sound bar
		tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, 64), GroupTransparency = 0 }, Enum.EasingStyle.Back)
		task.delay(4, function()
			local out = tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, -60), GroupTransparency = 1 })
			out.Completed:Wait()
			toast:Destroy()
			if setupGui and setupGui.Parent then
				setupGui:Destroy()
			end
		end)
	end

	local function getChannel()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			return nil
		end
		local channels = TextChatService:FindFirstChild("TextChannels")
		if not channels then
			channels = TextChatService:WaitForChild("TextChannels", 5)
		end
		if not channels then return nil end
		return channels:FindFirstChild("RBXGeneral") or channels:WaitForChild("RBXGeneral", 5)
	end

	local function sendChat(channel, message)
		if not channel then return false end
		local ok, err = pcall(function()
			channel:SendAsync(message)
		end)
		if not ok then
			warn("[V4] Chat message failed: " .. tostring(err))
		end
		return ok
	end

	playerName = runStep("ENTER YOUR NAME", "Your name will be used in the script", "Enter your name...", "👤", "ENTER")
	if playerName then
		gangName = runStep("ENTER YOUR GANG NAME", "Your gang name will be used in the script", "Enter your gang name...", "👥", "ENTER")
	end
	if gangName then
		targetName = runStep("ENTER YOUR TARGET NAME", "Type the name you want to mention", "Enter target name...", "🎯", "ENTER")
	end

	local blurOut = tween(blur, 0.5, { Size = 0 })
	blurOut.Completed:Connect(function()
		if blur and blur.Parent then blur:Destroy() end
	end)

	if not (playerName and gangName and targetName) then
		-- setup was closed: stop the script cleanly
		task.delay(0.6, function()
			setupGui:Destroy()
			sg:Destroy()
		end)
		return
	end

	local channel = getChannel()

	local sent1 = sendChat(
		channel,
		"SCRIPT BY " .. playerName .. " _________________________THE KING'S V3 IS HERE_________________________MADE BY " .. playerName .. "___V3 LOADED"
	)

	task.wait(2)

	local sent2 = sendChat(
		channel,
		"THE FATHER OF " .. targetName .. " TERA BAP AGYA 🥰😭 ___" .. gangName .. " ON TOP"
	)

	if sent1 and sent2 then
		showStatus("V3 LOADED  •  by " .. playerName, true)
	else
		showStatus("V3 LOADED  •  by " .. playerName .. "  (chat message not sent)", false)
	end
end

--==================================================
-- SHARED UI WIDGETS (buttons, ripple, sliders)
--==================================================

-- click ripple that expands from the centre of a button
local function ripple(b)
	local r = Instance.new("Frame")
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.new(0.5, 0, 0.5, 0)
	r.Size = UDim2.new(0, 0, 0, 0)
	r.BackgroundColor3 = Color3.new(1, 1, 1)
	r.BackgroundTransparency = 0.7
	r.BorderSizePixel = 0
	r.ZIndex = b.ZIndex + 1
	r.Parent = b
	Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
	local tw = tween(r, 0.45, { Size = UDim2.new(1.2, 0, 2.6, 0), BackgroundTransparency = 1 })
	tw.Completed:Connect(function()
		r:Destroy()
	end)
end

local function makeButton(parent, text, size, textSize, callback)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = size
	b.BackgroundColor3 = Theme._n
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0
	b.ClipsDescendants = true

	b.Text = text
	b.TextColor3 = Theme.Text
	b.Font = Fonts[Theme.FontIndex]
	b.TextSize = textSize
	b.TextWrapped = true
	b.AutoButtonColor = false
	b.ZIndex = 15

	regCorner(b, 8)
	local stroke = borderStroke(b, 1.3, 0.15)

	table.insert(Reg.buttons, b)
	table.insert(Reg.texts, b)

	b.MouseEnter:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = Theme._h })
		tween(stroke, 0.15, { Thickness = 2 })
	end)

	b.MouseLeave:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = Theme._n })
		tween(stroke, 0.15, { Thickness = 1.3 })
	end)

	b.MouseButton1Down:Connect(function()
		tween(b, 0.07, { BackgroundColor3 = Theme._a })
		ripple(b)
	end)

	b.MouseButton1Up:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = Theme._h })
	end)

	if typeof(callback) == "function" then
		b.MouseButton1Click:Connect(function()
			callback(b)
		end)
	end

	return b
end

-- slider: returns { set = function(value, silent), get = function() }
local function makeSlider(parent, label, min, max, default, fmt, onChange)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, 31)
	item.BackgroundTransparency = 1
	item.ZIndex = 130
	item.Parent = parent

	local nameL = Instance.new("TextLabel")
	nameL.Position = UDim2.new(0, 2, 0, 0)
	nameL.Size = UDim2.new(0.62, 0, 0, 14)
	nameL.BackgroundTransparency = 1
	nameL.Text = label
	nameL.TextColor3 = Theme.Muted
	nameL.Font = Enum.Font.GothamBold
	nameL.TextSize = 10
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.ZIndex = 131
	nameL.Parent = item

	local valL = Instance.new("TextLabel")
	valL.Position = UDim2.new(0.62, 0, 0, 0)
	valL.Size = UDim2.new(0.38, -2, 0, 14)
	valL.BackgroundTransparency = 1
	valL.Text = ""
	valL.TextColor3 = Theme.Text
	valL.Font = Enum.Font.GothamBold
	valL.TextSize = 10
	valL.TextXAlignment = Enum.TextXAlignment.Right
	valL.ZIndex = 131
	valL.Parent = item

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 6, 0, 19)
	track.Size = UDim2.new(1, -12, 0, 7)
	track.BackgroundColor3 = Color3.fromRGB(34, 36, 70)
	track.BorderSizePixel = 0
	track.ZIndex = 131
	track.Parent = item
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 132
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	table.insert(Reg.grads, addGradient(fill, Theme.A1, Theme.A2, 0))

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.Size = UDim2.new(0, 15, 0, 15)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 133
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	borderStroke(knob, 1.5, 0)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 134
	hit.Parent = item

	local value = default

	local function setValue(v, silent)
		v = math.clamp(v, min, max)
		value = v
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valL.Text = fmt(v)
		if not silent then
			onChange(v)
		end
	end

	local dragging = false

	local function setFromX(x)
		local w = track.AbsoluteSize.X
		if w <= 0 then return end
		local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
		setValue(min + (max - min) * rel)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	table.insert(Cleanup, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))

	table.insert(Cleanup, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	setValue(default, true)

	return {
		set = setValue,
		get = function() return value end
	}
end

--==================================================
-- MAIN GUI
-- CanvasGroup (for fade) + background frame child.
-- The gradient is on the background frame, never on the group.
--==================================================

local Main = Instance.new("CanvasGroup", sg)

Main.Name = "MainWindow"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0,420,0,340)
Main.Position = UDim2.new(.5,0,.5,0)

Main.BackgroundTransparency = 1
Main.BorderSizePixel = 0
Main.Active = true
Main.ZIndex = 10
Main.Visible = false
Main.GroupTransparency = 1

regCorner(Main, 16)

local MainScale = Instance.new("UIScale", Main)
MainScale.Scale = baseScale() * 0.9

makeDraggable(Main)

local MainBg = Instance.new("Frame", Main)
MainBg.Name = "Bg"
MainBg.Size = UDim2.new(1,0,1,0)
MainBg.BackgroundColor3 = Color3.new(1,1,1)
MainBg.BackgroundTransparency = Theme.Opacity
MainBg.BorderSizePixel = 0
MainBg.ZIndex = 1
local MainBgGrad = addGradient(MainBg, shade(0.14), shade(0.24), 60)

local MainStroke, MainStrokeGrad = borderStroke(Main, 2.5, 0)

--==================================================
-- AURA (glow + pulse rings + particles coming out of the GUI)
--==================================================

local AuraRoot = Instance.new("Frame", sg)
AuraRoot.Name = "Aura"
AuraRoot.AnchorPoint = Vector2.new(0.5, 0.5)
AuraRoot.Size = UDim2.new(0, 420, 0, 340)
AuraRoot.Position = Main.Position
AuraRoot.BackgroundTransparency = 1
AuraRoot.ZIndex = 5
AuraRoot.Visible = false

local AuraScale = Instance.new("UIScale", AuraRoot)
AuraScale.Scale = MainScale.Scale

do
	local layers = {}
	local baseTrans = { 0.72, 0.82, 0.90, 0.95 }

	for i = 1, 4 do
		local layer = Instance.new("Frame")
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.new(0.5, 0, 0.5, 0)
		layer.Size = UDim2.new(1, i * 8, 1, i * 8)
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.ZIndex = 1
		layer.Parent = AuraRoot
		Instance.new("UICorner", layer).CornerRadius = UDim.new(0, 16 + i * 6)
		local stroke = borderStroke(layer, 4 + i * 7, baseTrans[i])
		table.insert(layers, { stroke = stroke, base = baseTrans[i] })
	end

	-- energy rings that spread out of the window
	local rings = {}
	for i = 1, 3 do
		local ringF = Instance.new("Frame")
		ringF.AnchorPoint = Vector2.new(0.5, 0.5)
		ringF.Position = UDim2.new(0.5, 0, 0.5, 0)
		ringF.Size = UDim2.new(1, 0, 1, 0)
		ringF.BackgroundTransparency = 1
		ringF.BorderSizePixel = 0
		ringF.ZIndex = 2
		ringF.Parent = AuraRoot
		Instance.new("UICorner", ringF).CornerRadius = UDim.new(0, 18)
		local stroke = borderStroke(ringF, 2, 0.3)
		table.insert(rings, ringF)

		local info = TweenInfo.new(2.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, (i - 1) * 0.9)
		TweenService:Create(ringF, info, { Size = UDim2.new(1, 120, 1, 120) }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end

	-- rising particles
	local PCOUNT = 18
	local particles = {}

	for i = 1, PCOUNT do
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Size = UDim2.new(0, 5, 0, 5)
		p.BackgroundColor3 = (i % 2 == 0) and Theme.A1 or Theme.A2
		p.BackgroundTransparency = 1
		p.BorderSizePixel = 0
		p.ZIndex = 3
		p.Parent = AuraRoot
		Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
		particles[i] = p

		task.spawn(function()
			task.wait(math.random() * 2)
			while sg.Parent do
				local allowed = math.ceil(PCOUNT * math.max(Theme.AuraPower, 0.15))
				if Theme.Aura and Theme.Particles and AuraRoot.Visible and i <= allowed then
					local side = math.random(1, 4)
					local px, py, dx, dy
					if side == 1 then
						px, py, dx, dy = math.random(), 0, 0, -1
					elseif side == 2 then
						px, py, dx, dy = math.random(), 1, 0, 1
					elseif side == 3 then
						px, py, dx, dy = 0, math.random(), -1, 0
					else
						px, py, dx, dy = 1, math.random(), 1, 0
					end
					local dist = math.random(50, 115)
					local sizePx = math.random(3, 7)
					p.Size = UDim2.new(0, sizePx, 0, sizePx)
					p.Position = UDim2.new(px, 0, py, 0)
					p.BackgroundTransparency = 0.15
					local dur = 1.4 + math.random() * 1.4
					tween(p, dur, {
						Position = UDim2.new(px, dx * dist + math.random(-14, 14), py, dy * dist + math.random(-14, 14)),
						BackgroundTransparency = 1,
						Size = UDim2.new(0, 1, 0, 1)
					}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					task.wait(dur * (0.5 + math.random() * 0.4))
				else
					task.wait(0.4)
				end
			end
		end)
	end

	table.insert(Reg.accentFns, function()
		for i, p in ipairs(particles) do
			p.BackgroundColor3 = (i % 2 == 0) and Theme.A1 or Theme.A2
		end
	end)

	table.insert(Reg.lookFns, function()
		local power = math.clamp(Theme.AuraPower, 0, 1)
		for _, l in ipairs(layers) do
			l.stroke.Transparency = 1 - (1 - l.base) * power * 1.35
		end
		for _, r in ipairs(rings) do
			r.Visible = Theme.Aura and power > 0.05
		end
		AuraRoot.Visible = Main.Visible and Theme.Aura
	end)
end

local function syncAura()
	AuraRoot.Position = Main.Position
	AuraScale.Scale = MainScale.Scale
	AuraRoot.Visible = Main.Visible and Theme.Aura
end

Main:GetPropertyChangedSignal("Position"):Connect(syncAura)
Main:GetPropertyChangedSignal("Visible"):Connect(syncAura)
MainScale:GetPropertyChangedSignal("Scale"):Connect(syncAura)

--==================================================
-- TITLE
--==================================================

local Title = Instance.new("TextLabel",Main)

Title.Size = UDim2.new(1,-20,0,30)
Title.Position = UDim2.new(0,10,0,4)

Title.BackgroundTransparency = 1
Title.Text = string.upper(tostring(gangName or "AAYAN")) .. " ON TOP"
Title.TextColor3 = Color3.new(1, 1, 1)

Title.Font = Enum.Font.GothamBlack
Title.TextSize = 21
Title.TextXAlignment = Enum.TextXAlignment.Center

Title.ZIndex = 12

local TitleGrad = Instance.new("UIGradient", Title)
Reg.titleGrad = TitleGrad

--==================================================
-- SUB TITLE
--==================================================

local SubTitle = Instance.new("TextLabel",Main)

SubTitle.Size = UDim2.new(1,-20,0,18)
SubTitle.Position = UDim2.new(0,10,0,34)

SubTitle.BackgroundTransparency = 1
SubTitle.RichText = true

SubTitle.Text =
'<font color="#FFD700">' .. string.upper(tostring(gangName or "AAYAN")) .. '</font> <font color="#FF2D55">ON TOP</font> 💀😼'

SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 11

SubTitle.ZIndex = 12

-- glowing divider under the title
local Divider = Instance.new("Frame", Main)
Divider.Position = UDim2.new(0, 10, 0, 55)
Divider.Size = UDim2.new(1, -20, 0, 2)
Divider.BackgroundColor3 = Color3.new(1, 1, 1)
Divider.BorderSizePixel = 0
Divider.ZIndex = 12
Instance.new("UICorner", Divider).CornerRadius = UDim.new(1, 0)
table.insert(Reg.grads, addGradient(Divider, Theme.A1, Theme.A2, 0))

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = Instance.new("ScrollingFrame",Main)

Sidebar.Size = UDim2.new(0,125,1,-70)
Sidebar.Position = UDim2.new(0,10,0,60)

Sidebar.BackgroundColor3 = Color3.fromRGB(8,10,28)
Sidebar.BackgroundTransparency = .25
Sidebar.BorderSizePixel = 0

Sidebar.ScrollBarThickness = 2
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new(0,0,0,0)

Sidebar.ZIndex = 11

regCorner(Sidebar, 12)
borderStroke(Sidebar, 1, 0.5)

local SideList = Instance.new("UIListLayout",Sidebar)

SideList.Padding = UDim.new(0,GAP)
SideList.HorizontalAlignment =
Enum.HorizontalAlignment.Center

local SidePadding = Instance.new("UIPadding",Sidebar)

SidePadding.PaddingTop = UDim.new(0,GAP)
SidePadding.PaddingBottom = UDim.new(0,GAP)

--==================================================
-- PAGES
--==================================================

local Pages = Instance.new("Frame",Main)
Pages.Size = UDim2.new(1,-160,1,-70)
Pages.Position = UDim2.new(0,148,0,60)
Pages.BackgroundTransparency = 1
Pages.ZIndex = 11

local function createPage()
	local p = Instance.new("ScrollingFrame",Pages)

	p.Size = UDim2.new(1,0,1,0)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.Visible = false
	p.ScrollBarThickness = 3
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.CanvasSize = UDim2.new(0,0,0,0)
	p.ZIndex = 11

	local layout = Instance.new("UIListLayout",p)
	layout.Padding = UDim.new(0,GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return p
end

local P1 = createPage()
local P2 = createPage()
local P3 = createPage()
local P4 = createPage()
local P5 = createPage()
local P6 = createPage()
local P7 = createPage()
local P8 = createPage()
local P9 = createPage()
local P10 = createPage()
local P11 = createPage()
local P12 = createPage()
local P13 = createPage() -- INFO

--==================================================
-- THEME APPLY FUNCTIONS
--==================================================

local function applyAccent()
	local seq = ColorSequence.new(Theme.A1, Theme.A2)
	for i = #Reg.grads, 1, -1 do
		local g = Reg.grads[i]
		if g.Parent then
			g.Color = seq
		else
			table.remove(Reg.grads, i)
		end
	end

	if Reg.titleGrad then
		Reg.titleGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.A1),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Theme.A2)
		})
	end

	for _, fn in ipairs(Reg.accentFns) do
		fn()
	end
end

local function applyShades()
	refreshShadeCache()

	MainBgGrad.Color = ColorSequence.new(shade(0.14), shade(0.24))

	for i = #Reg.buttons, 1, -1 do
		local b = Reg.buttons[i]
		if b.Parent then
			b.BackgroundColor3 = Theme._n
		else
			table.remove(Reg.buttons, i)
		end
	end

	for _, b in ipairs(Reg.tabs) do
		b.BackgroundColor3 = (b == activeTab) and Theme._a or Theme._n
	end

	for _, f in ipairs(Reg.fields) do
		f.BackgroundColor3 = Theme._field
	end

	for _, c in ipairs(Reg.cards) do
		c.BackgroundColor3 = Theme._card
	end
end

local function applyLook()
	local font = Fonts[Theme.FontIndex]
	for i = #Reg.texts, 1, -1 do
		local t = Reg.texts[i]
		if t.Parent then
			t.Font = font
		else
			table.remove(Reg.texts, i)
		end
	end

	for i = #Reg.corners, 1, -1 do
		local c = Reg.corners[i]
		if c.c.Parent then
			c.c.CornerRadius = UDim.new(0, math.floor(c.base * Theme.Round + 0.5))
		else
			table.remove(Reg.corners, i)
		end
	end

	MainBg.BackgroundTransparency = Theme.Opacity

	if mainOpen then
		for _, t in ipairs(mainTweens) do
			t:Cancel()
		end
		table.clear(mainTweens)
		Main.GroupTransparency = 0
		MainScale.Scale = baseScale()
	end

	for _, fn in ipairs(Reg.lookFns) do
		fn()
	end
end

local function applyAll()
	applyShades()
	applyAccent()
	applyLook()
end

--==================================================
-- TAB FUNCTION
--==================================================

local function setTabLook(b, mode)
	local c = Theme._n
	if mode == "active" then
		c = Theme._a
	elseif mode == "hover" then
		c = Theme._h
	end
	tween(b, 0.15, { BackgroundColor3 = c })

	local bar = b:FindFirstChild("AccentBar")
	if bar then
		bar.Visible = (mode == "active")
	end
end

local function tab(name, page)
	local b = Instance.new("TextButton", Sidebar)

	b.Size = UDim2.new(1, -8, 0, 36)
	b.BackgroundColor3 = Theme._n
	b.BorderSizePixel = 0
	b.Text = name
	b.TextColor3 = Theme.Text
	b.Font = Fonts[Theme.FontIndex]
	b.TextSize = 13
	b.TextWrapped = true
	b.ZIndex = 15
	b.AutoButtonColor = false
	b.ClipsDescendants = true

	regCorner(b, 8)
	borderStroke(b, 1.3, 0.2)

	table.insert(Reg.tabs, b)
	table.insert(Reg.texts, b)

	-- accent bar shown on the active tab
	local bar = Instance.new("Frame", b)
	bar.Name = "AccentBar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 3, 0.5, 0)
	bar.Size = UDim2.new(0, 3, 0.6, 0)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.ZIndex = 16
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	table.insert(Reg.grads, addGradient(bar, Theme.A1, Theme.A2, 90))

	b.MouseEnter:Connect(function()
		if activeTab ~= b then setTabLook(b, "hover") end
	end)

	b.MouseLeave:Connect(function()
		if activeTab ~= b then setTabLook(b, "normal") end
	end)

	b.MouseButton1Down:Connect(function()
		ripple(b)
	end)

	b.MouseButton1Click:Connect(function()
		for _, v in ipairs(Pages:GetChildren()) do
			if v:IsA("ScrollingFrame") then
				v.Visible = false
			end
		end

		if activeTab and activeTab ~= b then
			setTabLook(activeTab, "normal")
		end
		activeTab = b
		setTabLook(b, "active")

		page.Visible = true
	end)

	return b
end

--==================================================
-- BUTTON FUNCTION
--==================================================

local function btn(text, parent, callback)
	return makeButton(parent, text, UDim2.new(1, -10, 0, 36), 13, callback)
end

--==================================================
-- TABS
--==================================================

tab("PANEL 💀",P1)
tab("SPAMMER 🌀",P2)
tab("OTHER ☣",P3)
tab("SHIELD 🤖",P4)
tab("VOIDOUT 🗿",P5)
tab("DJ SYSTEM 🎶",P6)
tab("fun💥",P7)
tab("ALPHA EMPIRE ⛩️",P8)
tab("MINI GAMES 🎮",P9)
tab("OWNER 🚩",P10)
tab("NOTE 🔷",P11)
tab("SPECIAL 💖",P12)
tab("INFO 📊",P13)

--==================================================
-- ADD HERE P1
--==================================================
P1.Visible = true
do
	-- highlight the first tab (PANEL) as active
	local first
	for _, v in ipairs(Sidebar:GetChildren()) do
		if v:IsA("TextButton") then first = v break end
	end
	if first then
		activeTab = first
		first.BackgroundColor3 = Theme._a
		local bar = first:FindFirstChild("AccentBar")
		if bar then bar.Visible = true end
	end
end

-- smaller target name box
local targetBox = Instance.new("TextBox", P1)
targetBox.Size = UDim2.new(1, -10, 0, 30)
targetBox.PlaceholderText = "⚡ Enter Target Name..."
targetBox.PlaceholderColor3 = Color3.fromRGB(150, 155, 195)
targetBox.Text = ""
targetBox.BackgroundColor3 = Theme._field
targetBox.TextColor3 = Theme.Text
targetBox.Font = Enum.Font.GothamMedium
targetBox.TextSize = 13
targetBox.ClearTextOnFocus = false
targetBox.ZIndex = 15
regCorner(targetBox, 8)
borderStroke(targetBox, 1.3, 0.1)
table.insert(Reg.fields, targetBox)

local function getT()
	local n = targetBox.Text:lower()
	if n == "" then return nil end
	for _, v in pairs(Players:GetPlayers()) do
		if v ~= player and (v.Name:lower():find(n) or v.DisplayName:lower():find(n)) then return v end
	end
end

--==================================================
-- YOU WILL ADD HERE
-- (the troll-mode function startTroll(mode) goes here)
--==================================================

btn("GO TO 👤", P1, function()
	local t = getT()
	local root = getRoot()
	if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") and root then
		root.CFrame = t.Character.HumanoidRootPart.CFrame
	end
end)

btn("🚀 GOTO", P1, function()
	local t = getT()
	if t and t.Character and t.Character.HumanoidRootPart then
		pcall(function()
			player.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame
		end)
	end
end)

-- YOU WILL ADD HERE  (FACE button)

btn("SPECTATE 👁️", P1, function()
	local t = getT()
	if t and t.Character and t.Character:FindFirstChildOfClass("Humanoid") then
		workspace.CurrentCamera.CameraSubject = t.Character:FindFirstChildOfClass("Humanoid")
	end
end)

-- YOU WILL ADD HERE  (fun⚠️ button)
-- YOU WILL ADD HERE  (HEADSIT button)
-- YOU WILL ADD HERE  (FRONT SIT button)
-- YOU WILL ADD HERE  (FRONT HEADSIT button)
-- YOU WILL ADD HERE  (ANNOY button)

btn("STOP TROLL 💢", P1, function()
	Config.CurrentTroll = nil
	_G.Loop = false
	local hum = getHum()
	if hum then
		hum.Sit = false
		workspace.CurrentCamera.CameraSubject = hum
	end
end)

--==================================================
-- P2
--==================================================

btn("CUSTOM SPAM 😎👺",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/FVLWdWWy"
	))()
end)

btn("ROAST SPAM 💢🤬",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/crWrmZMT"
	))()
end)
btn("ULTIMATE SPAM 💥⚠️",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/BKt9y40g"
	))()
end)
btn("ALPHA EMPIRE ⛩️😼",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/Bm3p4tnh"
	))()
end)
btn("FORBID 🚫☣️",P2,function()
	loadstring(game:HttpGet(
		"https://gist.githubusercontent.com/forbidtherobloxscripter/3e1a67cdf3f22192307218825c8469ea/raw/d16fabac096433b08eb63170274af33c8345603e/fm%25201.5.txt"
	))()
end)



--==================================================
-- P3
--==================================================


btn("😋 AAYAN EMOTE", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024"))()
end)

btn("🚀 INF JUMP: OFF", P3, function(self)
	Config.InfJump = not Config.InfJump
	self.Text = "🚀 INF JUMP: " .. (Config.InfJump and "ON" or "OFF")
end)

btn("🏃 SPEED 300", P3, function(self)
	Config.Spd = not Config.Spd

	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")

	if hum then
		hum.WalkSpeed = Config.Spd and 300 or 16
	end

	self.Text = "🏃 SPEED 300: " .. (Config.Spd and "ON" or "OFF")
end)

btn("𫯯 SPIN 300", P3, function() Config.Spin = not Config.Spin end)

btn("💃 COPY EMOTE AND MORE", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Ro-vibes-ROVibes-95220"))()
end)

btn("🪓 SKY DESTROYER", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-sky-destroyer-V2-AXEZZ-110640"))()
end)

btn("🧍‍♂️ STAND BY", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/10c0XURE"))()
end)

btn("🎈 HEADSTAND", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/1zxuPzS4"))()
end)

btn("🍁 GAZE EMOTES", P3, function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Gazer-Ha/Gaze-stuff/refs/heads/main/Gaze%20emote"))()
end)

btn("🕊️ FLY CONTROLLER", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/6btVgzWN"))()
end)

btn("👻 NO CLIP", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/YW3XzdGD"))()
end)
--==================================================
-- P4
--==================================================
btn("👑 ANTI-VOID", P4, function(self)
	Config.AntiVoid = not Config.AntiVoid
	self.Text = "👑 ANTI-VOID: " .. (Config.AntiVoid and "ON" or "OFF")
end)

btn("🚫 ANTI-SIT", P4, function(self)
	Config.AntiSit = not Config.AntiSit
	self.Text = "🚫 ANTI-SIT: " .. (Config.AntiSit and "ON" or "OFF")
end)

btn("😴 ANTI-AFK", P4, function(self)
	Config.AntiAFK = not Config.AntiAFK
	self.Text = "😴 ANTI-AFK: " .. (Config.AntiAFK and "ON" or "OFF")
end)
btn("🔄 REVERSE FLING", P4, function() local hrp = player.Character.HumanoidRootPart; local s = Instance.new("BodyAngularVelocity", hrp); s.MaxTorque = Vector3.new(math.huge,math.huge,math.huge); s.AngularVelocity = Vector3.new(0,999999,0) end)
btn("🔥  ANTI-FLING", P4, function() for _,v in pairs(player.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end)

--==================================================
-- P5
--==================================================

btn("VOIDSTRIKER 🗿", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/c3R861CE"))() end)
btn("🪐 LOW GRAVITY", P5, function() workspace.Gravity = 15 end)
btn("🌌 ZERO GRAVITY", P5, function() workspace.Gravity = 0 end)
btn("🌍 NORMAL GRAVITY", P5, function() workspace.Gravity = 196.2 end)
btn("AURA GLOW 🌟", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/SEEgQyMg"))() end)
btn("PATROL👽", P5, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/XhKJMEqj"))() end)
btn("FAKEOUT 🌚", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/67KEqzjv"))() end)
btn("TELEPORTER V1 👾", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/EUSknnAF"))() end)
btn("TELEPORTER V2 👾", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/216FSAFS"))() end)

-- YOU WILL ADD HERE  (UNIVERSAL BANG 3F button)

btn("TROLL ADMIN 🔥", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/ZnAdZPW1"))() end)
btn("INFINITE YEILD 🔲", P5, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
btn("ULTIMATE ADMIN 🔥", P5, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Veaquach/kruel/refs/heads/main/kruel%20obf.txt"))() end)

--==================================================
-- P6
--==================================================

btn("🎵 DJ PLAYER",P6,function()
	loadstring(game:HttpGet(
		"https://pastefy.app/EZbyn0pl/raw"
	))()
end)

btn("funV1 💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/Gk24KYmb"))() end)
btn("fun V2💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/X73d41m6"))() end)
btn("fun 3 💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/TsLFDeKw"))() end)
btn("MULTI TARGET 💥🕷️", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/6f0Kfemd"))() end)
btn("HUB 🔥💢", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/EgVAYt7U"))() end)
btn("VOID WALKER ✨", P7, function() loadstring(game:HttpGet("https://pastefy.app/RdQmPLSO/raw"))() end)




--==================================================
-- P8
--==================================================

btn("ALPHA HISTORY 📜", P8, function() loadstring(game:HttpGet("https://pastefy.app/VlheRB4L/raw"))() end)
btn("JOIN EMPIRE ⛩️", P8, function() loadstring(game:HttpGet("https://pastefy.app/62LGo4kD/raw"))() end)
btn("VISIT ONCE 👀", P8, function() loadstring(game:HttpGet("https://pastebin.com/raw/2u9zqrk2"))() end)

--==================================================
-- P9
--==================================================

btn("TIC TAC TOE 🎮", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/ZYPzKzBF"))() end)
btn("JET DEFENDER ✈️", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/KEjtCtpP"))() end)
btn("CANDY BOM 💥", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/tTCmn7FS"))() end)
btn("FLAPPY BIRD 🐦", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/BNqYv7N6"))() end)
btn("CANDY CRUSH 🍭", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/gSW5NzsZ"))() end)


--==================================================
-- P10
--==================================================

local info = Instance.new("TextLabel", P10)

info.Size = UDim2.new(1,-5,1,0)
info.BackgroundTransparency = 1
info.TextSize = 16
info.Font = Enum.Font.GothamBold
info.TextWrapped = true
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextXAlignment = Enum.TextXAlignment.Center
info.RichText = false

info.Text = [[
👑 ꜱᴄʀɪᴘᴛ ᴏᴡɴᴇʀ - 🗿ᴀᴀʏᴀɴ⛩️


📩 ʀᴏʙʟᴏx ɪᴅ -> AAYAN_ZZZZ

📩 ꜱɴᴀᴘᴄʜᴀᴛ ɪᴅ -> aayanzz123

ʀᴏʙʟᴏx ɪᴅ -> mr_king784(AE_MAX)


ʙɪʜᴀʀ ᴏɴ ᴛᴏᴘ 🚩

ᴜʟᴛɪᴍᴀᴛᴇ ʙᴀɴɢ ꜱᴄʀɪᴘᴛ💀😈

♣ ᴛʜᴀɴᴋ ʏᴏᴜ ꜰᴏʀ ᴜꜱᴇ ᴀᴀʏᴀɴ ᴠ2 ♠
]]

-- RGB TEXT
task.spawn(function()
	local h = 0

	while info.Parent do
		h = (h + 0.008) % 1
		info.TextColor3 = Color3.fromHSV(h, 0.8, 1)
		task.wait(0.02)
	end
end)

--==================================================
-- P11
--==================================================

local InfoFrame = Instance.new("Frame", P11)
InfoFrame.Size = UDim2.new(1,0,1,0)
InfoFrame.BackgroundTransparency = 1

local function AddInfoText(Text, Color, Size, Bold)
	local Label = Instance.new("TextLabel")
	Label.Parent = InfoFrame
	Label.Size = UDim2.new(1,-10,0,Size)
	Label.BackgroundTransparency = 1
	Label.Text = Text
	Label.TextColor3 = Color
	Label.TextSize = 15
	Label.Font = Bold and Enum.Font.GothamBold or Enum.Font.Gotham
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	return Label
end

local Cyan = Color3.fromRGB(0,255,255)
local Purple = Color3.fromRGB(190,70,255)
local Red = Color3.fromRGB(255,70,90)
local White = Color3.fromRGB(240,240,245)

-- TITLE
local InfoTitle = AddInfoText(
	"⛩️ ᴡᴇʟᴄᴏᴍᴇ ᴛᴏ ᴀᴀʏᴀɴ ᴠ2 👑",
	Cyan,
	32,
	true
)
InfoTitle.Position = UDim2.new(0,5,0,5)

-- SUBTITLE
local InfoSub = AddInfoText(
	"ᴛʜᴇ ᴋᴇʏʟᴇꜱꜱ ꜱᴄʀɪᴘᴛ ʙʏ ᴀᴀʏᴀɴ 💀",
	Purple,
	28,
	true
)
InfoSub.Position = UDim2.new(0,5,0,38)

-- FEATURE TITLE
local FeatureTitle = AddInfoText(
	"✨ FEATURES ✨",
	Red,
	25,
	true
)
FeatureTitle.Position = UDim2.new(0,5,0,70)

-- FEATURES
local Features = AddInfoText(
	[[
🔷 ʙᴀɴɢ - ᴜʟᴛɪᴍᴀᴛᴇ ɢᴀᴍᴇᴘʟᴀʏ ꜰᴇᴀᴛᴜʀᴇ 👽

🛡️ ꜱʜɪᴇʟᴅ - ᴘʀᴏᴛᴇᴄᴛɪᴏɴ ꜰᴇᴀᴛᴜʀᴇꜱ ᴀɢᴀɪɴꜱᴛ ᴀᴛᴛᴀᴄᴋꜱ

🟣 ꜱᴘᴀᴍᴍᴇʀ - ꜰᴜɴ ᴄʜᴀᴛ & ᴍᴇꜱꜱᴀɢᴇ ꜰᴇᴀᴛᴜʀᴇꜱ 😂

🔴 ᴠᴏɪᴅᴏᴜᴛ - ʙᴀɴɢɢᴇʀ + ᴇxᴛʀᴀ ɢᴀᴍᴇ ꜰᴇᴀᴛᴜʀᴇꜱ

🎵 ᴅᴊ ꜱʏꜱᴛᴇᴍ - ᴇɴᴊᴏʏ ᴛʜᴇ ɢᴀᴍᴇ ᴡɪᴛʜ ᴍᴜꜱɪᴄ & ꜰᴜɴᴋ 💀

⛩️ ᴀʟᴘʜᴀ ᴇᴍᴘɪʀᴇ - ꜰᴇᴀᴛᴜʀᴇꜱ & ᴄᴏɴᴛᴇɴᴛ ᴀʙᴏᴜᴛ ᴀʟᴘʜᴀ ᴇᴍᴘɪʀᴇ

🎮 ᴍɪɴɪ ɢᴀᴍᴇ - ᴘʟᴀʏ ᴍɪɴɪ ɢᴀᴍᴇꜱ ᴡʜᴇɴ ʏᴏᴜ ɢᴇᴛ ʙᴏʀᴇᴅ 😋

🌚 ꜱᴘᴇᴄɪᴀʟ - ᴜʟᴛɪᴍᴀᴛᴇ ꜱᴘᴇᴄɪᴀʟ ꜰᴇᴀᴛᴜʀᴇꜱ

✨ ɪ ʜᴏᴘᴇ ʏᴏᴜ ʟɪᴋᴇ ᴀᴀʏᴀɴ ʜᴜʙ ᴠ2
]],
	White,
	205,
	false
)

Features.Position = UDim2.new(0,5,0,98)
Features.TextYAlignment = Enum.TextYAlignment.Top
Features.TextSize = 13

--// RGB FEATURE TEXT EFFECT
local Hue = 0

table.insert(Cleanup, RunService.RenderStepped:Connect(function()
	Hue = (Hue + 0.003) % 1

	local RGB = Color3.fromHSV(Hue,0.8,1)

	FeatureTitle.TextColor3 = RGB
end))
--==================================================
-- P12
--==================================================

btn("SPECIAL MODES 😋 ", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/yiz4bZgG"))() end)
btn("FOV VIEW 👁️ ", P12, function() loadstring(game:HttpGet("https://pastefy.app/wBDTCnNa/raw"))() end)
btn("DRONE CONTROLLER 🚁", P12, function() loadstring(game:HttpGet("https://pastefy.app/9QN9NTjk/raw"))() end)
btn("AURA GLITCH 🎭", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/Uq7htgyG"))() end)
btn("OUTFIT BREAKER 😈", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/d4u4u9tn"))() end)
btn("🦖 Giant Mode", P12, function() if player.Character and player.Character:FindFirstChild("Humanoid") then for _, scale in pairs({"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}) do local obj = player.Character.Humanoid:FindFirstChild(scale); if obj then obj.Value = 2.5 end end end end, false)
btn("FAKE CHAT ☠️", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/96AH9Dcr"))() end)
btn("TRAIL 🏳️‍🌈", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/xhXTB61N"))() end)
btn("AUTO CLICKER ↗️", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/4b3HeU6Q"))() end)

--==================================================
-- P13 : INFO TAB
--==================================================

do
	-- avatar + welcome section
	local header = Instance.new("Frame", P13)
	header.Size = UDim2.new(1, -10, 0, 150)
	header.BackgroundTransparency = 1
	header.ZIndex = 12

	local ring = Instance.new("Frame", header)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 4)
	ring.Size = UDim2.new(0, 84, 0, 84)
	ring.BackgroundColor3 = Color3.fromRGB(16, 30, 80)
	ring.BorderSizePixel = 0
	ring.ZIndex = 13
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local _, ringGrad = borderStroke(ring, 3, 0)

	local av = Instance.new("ImageLabel", ring)
	av.AnchorPoint = Vector2.new(0.5, 0.5)
	av.Position = UDim2.new(0.5, 0, 0.5, 0)
	av.Size = UDim2.new(1, -10, 1, -10)
	av.BackgroundTransparency = 1
	av.Image = avatarImage
	av.ScaleType = Enum.ScaleType.Crop
	av.ZIndex = 14
	Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

	local welcome = Instance.new("TextLabel", header)
	welcome.Position = UDim2.new(0, 0, 0, 94)
	welcome.Size = UDim2.new(1, 0, 0, 28)
	welcome.BackgroundTransparency = 1
	welcome.Text = "WELCOME, " .. player.Name
	welcome.TextColor3 = Theme.Text
	welcome.Font = Enum.Font.GothamBlack
	welcome.TextScaled = true
	welcome.ZIndex = 13
	local wLimit = Instance.new("UITextSizeConstraint", welcome)
	wLimit.MaxTextSize = 18
	wLimit.MinTextSize = 10

	local display = Instance.new("TextLabel", header)
	display.Position = UDim2.new(0, 0, 0, 124)
	display.Size = UDim2.new(1, 0, 0, 18)
	display.BackgroundTransparency = 1
	display.Text = "Display name: " .. player.DisplayName
	display.TextColor3 = Theme.Muted
	display.Font = Enum.Font.Gotham
	display.TextSize = 12
	display.ZIndex = 13

	table.insert(Hooks, function(t, dt)
		-- only animate while the INFO page is actually visible
		if P13.Visible and Main.Visible then
			ringGrad.Rotation = (ringGrad.Rotation + 120 * dt) % 360
		end
	end)

	-- info cards
	local function makeCard(iconText, labelText)
		local card = Instance.new("Frame", P13)
		card.Size = UDim2.new(1, -10, 0, 46)
		card.BackgroundColor3 = Theme._card
		card.BackgroundTransparency = 0.05
		card.BorderSizePixel = 0
		card.ZIndex = 12
		regCorner(card, 10)
		borderStroke(card, 1.2, 0.25)
		table.insert(Reg.cards, card)

		local icon = Instance.new("TextLabel", card)
		icon.Position = UDim2.new(0, 8, 0, 0)
		icon.Size = UDim2.new(0, 30, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = iconText
		icon.TextSize = 20
		icon.TextColor3 = Theme.Text
		icon.Font = Enum.Font.GothamBold
		icon.ZIndex = 13

		local label = Instance.new("TextLabel", card)
		label.Position = UDim2.new(0, 44, 0, 5)
		label.Size = UDim2.new(1, -52, 0, 14)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = Theme.Muted
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 13

		local value = Instance.new("TextLabel", card)
		value.Position = UDim2.new(0, 44, 0, 21)
		value.Size = UDim2.new(1, -52, 0, 20)
		value.BackgroundTransparency = 1
		value.Text = "..."
		value.TextColor3 = Theme.Text
		value.Font = Enum.Font.GothamBold
		value.TextSize = 15
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.ZIndex = 13

		return value
	end

	local fpsValue = makeCard("⚡", "FPS")
	local pingValue = makeCard("📶", "PING (LATENCY)")
	local speedValue = makeCard("🌐", "NETWORK SPEED")
	local timeValue = makeCard("🕒", "LOCAL TIME")
	local dayValue = makeCard("📅", "DAY")
	local dateValue = makeCard("🗓️", "DATE")

	-- Roblox LocalScripts cannot measure real download/upload throughput
	speedValue.Text = "N/A (not measurable in Roblox)"
	speedValue.TextSize = 12
	speedValue.TextColor3 = Theme.Muted

	-- FPS counter: one lightweight Heartbeat connection, labels refreshed once per second
	local frames = 0
	table.insert(Cleanup, RunService.Heartbeat:Connect(function()
		frames += 1
	end))

	local function readPing()
		local ok, val = pcall(function()
			return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and typeof(val) == "number" then
			return math.floor(val + 0.5)
		end
		return nil
	end

	local function refresh(fps)
		if fps then
			fpsValue.Text = tostring(fps) .. " FPS"
			if fps >= 50 then
				fpsValue.TextColor3 = Color3.fromRGB(80, 255, 150)
			elseif fps >= 30 then
				fpsValue.TextColor3 = Color3.fromRGB(255, 200, 70)
			else
				fpsValue.TextColor3 = Color3.fromRGB(255, 90, 90)
			end
		end

		local ping = readPing()
		pingValue.Text = ping and (tostring(ping) .. " ms") or "N/A"

		timeValue.Text = os.date("%I:%M:%S %p")
		dayValue.Text = os.date("%A")
		dateValue.Text = os.date("%d %B %Y")
	end

	refresh(nil)

	-- refresh immediately when the INFO page becomes visible
	P13:GetPropertyChangedSignal("Visible"):Connect(function()
		if P13.Visible then refresh(nil) end
	end)

	task.spawn(function()
		local last = os.clock()
		while sg.Parent do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			local fps = math.floor(frames / math.max(dt, 0.001) + 0.5)
			frames = 0

			if Main.Visible and P13.Visible then
				refresh(fps)
			end
		end
	end)
end

--==================================================
-- DANGER TOGGLE BUTTON
--==================================================

local ToggleBtn = Instance.new("ImageButton",sg)

ToggleBtn.Name = "ToggleButton"
ToggleBtn.Size = UDim2.new(0,70,0,70)
ToggleBtn.Position = UDim2.new(0,20,0.5,-35)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(26,0,0)
ToggleBtn.BackgroundTransparency = 0.05
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Image = "rbxassetid://83877589941594"
ToggleBtn.ScaleType = Enum.ScaleType.Fit
ToggleBtn.Visible = true
ToggleBtn.ZIndex = 200
ToggleBtn.Active = true
ToggleBtn.AutoButtonColor = false

Instance.new("UICorner",ToggleBtn).CornerRadius = UDim.new(0,18)

local ToggleStroke = Instance.new("UIStroke",ToggleBtn)
ToggleStroke.Thickness = 3
ToggleStroke.Color = Color3.fromRGB(255, 30, 30)
ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local ToggleScale = Instance.new("UIScale", ToggleBtn)

-- danger ripple rings
for i = 1, 2 do
	local dr = Instance.new("Frame", ToggleBtn)
	dr.AnchorPoint = Vector2.new(0.5, 0.5)
	dr.Position = UDim2.new(0.5, 0, 0.5, 0)
	dr.Size = UDim2.new(1, 0, 1, 0)
	dr.BackgroundTransparency = 1
	dr.BorderSizePixel = 0
	dr.ZIndex = 199
	Instance.new("UICorner", dr).CornerRadius = UDim.new(0, 18)
	local drs = Instance.new("UIStroke", dr)
	drs.Thickness = 2
	drs.Color = Color3.fromRGB(255, 40, 40)
	drs.Transparency = 0.2
	drs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local dinfo = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, (i - 1) * 0.9)
	TweenService:Create(dr, dinfo, { Size = UDim2.new(1, 44, 1, 44) }):Play()
	TweenService:Create(drs, dinfo, { Transparency = 1 }):Play()
end

-- skull badge
local Badge = Instance.new("TextLabel", ToggleBtn)
Badge.AnchorPoint = Vector2.new(0.5, 0.5)
Badge.Position = UDim2.new(1, -4, 0, 4)
Badge.Size = UDim2.new(0, 24, 0, 24)
Badge.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
Badge.Text = "☠"
Badge.TextColor3 = Color3.fromRGB(255, 60, 60)
Badge.TextSize = 15
Badge.Font = Enum.Font.GothamBlack
Badge.ZIndex = 202
Instance.new("UICorner", Badge).CornerRadius = UDim.new(1, 0)
local BadgeStroke = Instance.new("UIStroke", Badge)
BadgeStroke.Color = Color3.fromRGB(255, 40, 40)
BadgeStroke.Thickness = 1.5
BadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- danger caption
local Caption = Instance.new("TextLabel", ToggleBtn)
Caption.AnchorPoint = Vector2.new(0.5, 0)
Caption.Position = UDim2.new(0.5, 0, 1, 4)
Caption.Size = UDim2.new(1, 20, 0, 14)
Caption.BackgroundTransparency = 1
Caption.Text = "⚠ DANGER ⚠"
Caption.TextColor3 = Color3.fromRGB(255, 50, 50)
Caption.Font = Enum.Font.GothamBlack
Caption.TextSize = 10
Caption.TextStrokeTransparency = 0.3
Caption.TextStrokeColor3 = Color3.new(0, 0, 0)
Caption.ZIndex = 202

ToggleBtn.MouseEnter:Connect(function()
	tween(ToggleScale, 0.15, { Scale = 1.1 })
end)
ToggleBtn.MouseLeave:Connect(function()
	tween(ToggleScale, 0.15, { Scale = 1 })
end)
ToggleBtn.MouseButton1Down:Connect(function()
	tween(ToggleScale, 0.08, { Scale = 0.92 })
end)
ToggleBtn.MouseButton1Up:Connect(function()
	tween(ToggleScale, 0.12, { Scale = 1.1 })
end)

makeDraggable(ToggleBtn)

--==================================================
-- OPEN / CLOSE ANIMATION
--==================================================

local function setMain(open)
	mainOpen = open

	for _, t in ipairs(mainTweens) do
		t:Cancel()
	end
	table.clear(mainTweens)

	local base = baseScale()

	if open then
		if not Main.Visible then
			Main.GroupTransparency = 1
			MainScale.Scale = base * 0.9
			Main.Visible = true
		end

		table.insert(mainTweens, tween(Main, 0.3, { GroupTransparency = 0 }))
		table.insert(mainTweens, tween(MainScale, 0.35, { Scale = base }, Enum.EasingStyle.Back))
	else
		table.insert(mainTweens, tween(Main, 0.22, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		local closing = tween(MainScale, 0.22, { Scale = base * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		table.insert(mainTweens, closing)

		closing.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not mainOpen then
				Main.Visible = false
			end
		end)
	end
end

-- keep the GUI sized correctly if the screen size changes
do
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(Cleanup, cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if mainOpen and #mainTweens > 0 then
				MainScale.Scale = baseScale()
			end
		end))
	end
end

-- ignore toggle clicks that were really drags
local toggleDownPos = nil

ToggleBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		toggleDownPos = ToggleBtn.AbsolutePosition
	end
end)

ToggleBtn.Activated:Connect(function()
	if toggleDownPos and (ToggleBtn.AbsolutePosition - toggleDownPos).Magnitude > 6 then
		return
	end
	setMain(not mainOpen)
end)

--==================================================
-- SOUND SYSTEM + CUSTOMIZER ATTACHED TO MAIN GUI (⚙️)
--==================================================

do
	local music = Instance.new("Sound")
	music.Name = "AAYAN_V4_MUSIC"
	music.SoundId = "rbxassetid://" .. tostring(SONG_ID)
	music.Volume = Theme.Volume
	music.Looped = true
	music.Parent = SoundService

	table.insert(Cleanup, {
		Disconnect = function()
			music:Destroy()
		end
	})

	-- top bar
	local bar = Instance.new("Frame", sg)
	bar.Name = "SoundBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromOffset(0, 0) -- synced to MainWindow below
	bar.Size = UDim2.new(0, 296, 0, 46)
	bar.BackgroundColor3 = Theme._card
	bar.BackgroundTransparency = 0.05
	bar.BorderSizePixel = 0
	bar.ZIndex = 120
	regCorner(bar, 14)
	borderStroke(bar, 1.8, 0)
	table.insert(Reg.cards, bar)

	local barScale = Instance.new("UIScale", bar)
	local function updateBarScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		barScale.Scale = math.clamp(math.min(v.X / 450, v.Y / 340), 0.5, 1)
	end
	updateBarScale()
	if workspace.CurrentCamera then
		table.insert(Cleanup, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateBarScale))
	end

	local row = Instance.new("UIListLayout", bar)
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, GAP)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder

	-- spinning disc (also the handle used to drag the bar)
	local grab = Instance.new("Frame", bar)
	grab.LayoutOrder = 1
	grab.Size = UDim2.new(0, 42, 0, 38)
	grab.BackgroundTransparency = 1
	grab.ZIndex = 121

	local disc = Instance.new("TextLabel", grab)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.new(0.5, 0, 0.5, 0)
	disc.Size = UDim2.new(0, 30, 0, 30)
	disc.BackgroundTransparency = 1
	disc.Text = "💿"
	disc.TextSize = 24
	disc.TextColor3 = Theme.Text
	disc.ZIndex = 122


	-- song info
	local infoF = Instance.new("Frame", bar)
	infoF.LayoutOrder = 2
	infoF.Size = UDim2.new(0, 116, 0, 38)
	infoF.BackgroundTransparency = 1
	infoF.ZIndex = 121

	local nameL = Instance.new("TextLabel", infoF)
	nameL.Position = UDim2.new(0, 0, 0, 1)
	nameL.Size = UDim2.new(1, 0, 0, 16)
	nameL.BackgroundTransparency = 1
	nameL.Text = "♪ Loading song..."
	nameL.TextColor3 = Theme.Text
	nameL.Font = Enum.Font.GothamBold
	nameL.TextSize = 11
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	nameL.ZIndex = 122

	local prog = Instance.new("Frame", infoF)
	prog.Position = UDim2.new(0, 0, 0, 19)
	prog.Size = UDim2.new(1, 0, 0, 4)
	prog.BackgroundColor3 = Color3.fromRGB(34, 36, 70)
	prog.BorderSizePixel = 0
	prog.ZIndex = 122
	Instance.new("UICorner", prog).CornerRadius = UDim.new(1, 0)

	local progFill = Instance.new("Frame", prog)
	progFill.Size = UDim2.new(0, 0, 1, 0)
	progFill.BackgroundColor3 = Color3.new(1, 1, 1)
	progFill.BorderSizePixel = 0
	progFill.ZIndex = 123
	Instance.new("UICorner", progFill).CornerRadius = UDim.new(1, 0)
	table.insert(Reg.grads, addGradient(progFill, Theme.A1, Theme.A2, 0))

	local timeL = Instance.new("TextLabel", infoF)
	timeL.Position = UDim2.new(0, 0, 0, 24)
	timeL.Size = UDim2.new(1, 0, 0, 13)
	timeL.BackgroundTransparency = 1
	timeL.Text = "0:00 / 0:00"
	timeL.TextColor3 = Theme.Muted
	timeL.Font = Enum.Font.Gotham
	timeL.TextSize = 10
	timeL.TextXAlignment = Enum.TextXAlignment.Left
	timeL.ZIndex = 122

	-- equalizer (driven by the real loudness of the song)
	local eqF = Instance.new("Frame", bar)
	eqF.LayoutOrder = 3
	eqF.Size = UDim2.new(0, 40, 0, 30)
	eqF.BackgroundTransparency = 1
	eqF.ZIndex = 121

	local eqList = Instance.new("UIListLayout", eqF)
	eqList.FillDirection = Enum.FillDirection.Horizontal
	eqList.Padding = UDim.new(0, GAP + 2)
	eqList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	eqList.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local eqBars = {}
	local eqHeights = {}
	for i = 1, 5 do
		local eb = Instance.new("Frame", eqF)
		eb.Size = UDim2.new(0, 5, 0, 3)
		eb.BackgroundColor3 = Color3.new(1, 1, 1)
		eb.BorderSizePixel = 0
		eb.ZIndex = 122
		Instance.new("UICorner", eb).CornerRadius = UDim.new(1, 0)
		table.insert(Reg.grads, addGradient(eb, Theme.A1, Theme.A2, 90))
		eqBars[i] = eb
		eqHeights[i] = 3
	end

	-- play / pause + customizer buttons
	local musicOn = false

	local playBtn = makeButton(bar, "▶", UDim2.new(0, 34, 0, 34), 15, nil)
	playBtn.LayoutOrder = 4
	playBtn.ZIndex = 125

	local gearBtn = makeButton(bar, "⚙️", UDim2.new(0, 34, 0, 34), 16, nil)
	gearBtn.LayoutOrder = 5
	gearBtn.ZIndex = 125

	local function setMusic(on)
		musicOn = on
		if on then
			music:Play()
		else
			music:Pause()
		end
		playBtn.Text = on and "⏸" or "▶"
	end

	playBtn.MouseButton1Click:Connect(function()
		setMusic(not musicOn)
	end)

	-- real song title + load check
	task.spawn(function()
		local ok, pinfo = pcall(function()
			return MarketplaceService:GetProductInfo(SONG_ID)
		end)
		if ok and pinfo and pinfo.Name then
			nameL.Text = "♪ " .. pinfo.Name
		else
			nameL.Text = "♪ Aayan Theme"
		end

		local t0 = os.clock()
		while not music.IsLoaded and os.clock() - t0 < 12 do
			task.wait(0.25)
		end
		if not music.IsLoaded then
			nameL.Text = "⚠ Audio unavailable"
		end
	end)

	local function fmtTime(s)
		s = math.max(0, math.floor(s))
		return string.format("%d:%02d", math.floor(s / 60), s % 60)
	end

	table.insert(Hooks, function(t, dt)
		local playing = musicOn and music.IsPlaying

		if playing then
			disc.Rotation = (disc.Rotation + 180 * dt) % 360
		end

		local len = music.TimeLength
		if len and len > 0 then
			progFill.Size = UDim2.new(math.clamp(music.TimePosition / len, 0, 1), 0, 1, 0)
			timeL.Text = fmtTime(music.TimePosition) .. " / " .. fmtTime(len)
		end

		local loud = math.clamp(music.PlaybackLoudness / 500, 0, 1)
		for i, eb in ipairs(eqBars) do
			local target = 3
			if playing then
				target = 3 + loud * 24 * (0.55 + 0.45 * math.abs(math.sin(t * 5 + i * 1.7)))
			end
			eqHeights[i] = eqHeights[i] + (target - eqHeights[i]) * 0.5
			eb.Size = UDim2.new(0, 5, 0, math.floor(eqHeights[i] + 0.5))
		end
	end)

	--==================================================
	-- CUSTOMIZER PANEL
	--==================================================

	local panel = Instance.new("CanvasGroup", sg)
	panel.Name = "Customizer"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromOffset(0, 0) -- synced beside MainWindow
	panel.Size = UDim2.new(0, 420, 0, 282)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 1
	panel.Visible = false
	panel.ZIndex = 125
	regCorner(panel, 14)
	borderStroke(panel, 2, 0)

	local panelScale = Instance.new("UIScale", panel)
	panelScale.Scale = 0.92

	local panelBg = Instance.new("Frame", panel)
	panelBg.Size = UDim2.new(1, 0, 1, 0)
	panelBg.BackgroundColor3 = Color3.new(1, 1, 1)
	panelBg.BackgroundTransparency = 0.04
	panelBg.BorderSizePixel = 0
	panelBg.ZIndex = 126
	local panelBgGrad = addGradient(panelBg, shade(0.12), shade(0.2), 70)
	table.insert(Reg.accentFns, function()
		panelBgGrad.Color = ColorSequence.new(shade(0.12), shade(0.2))
	end)

	local pTitle = Instance.new("TextLabel", panel)
	pTitle.Position = UDim2.new(0, 10, 0, 4)
	pTitle.Size = UDim2.new(1, -60, 0, 26)
	pTitle.BackgroundTransparency = 1
	pTitle.Text = "⚙️  " .. string.upper(tostring(gangName or "AAYAN")) .. " ON TOP"
	pTitle.TextColor3 = Theme.Text
	pTitle.Font = Enum.Font.GothamBlack
	pTitle.TextSize = 14
	pTitle.TextXAlignment = Enum.TextXAlignment.Left
	pTitle.ZIndex = 130

	local pClose = makeButton(panel, "✕", UDim2.new(0, 26, 0, 24), 13, nil)
	pClose.Position = UDim2.new(1, -34, 0, 5)
	pClose.ZIndex = 132

	local pDiv = Instance.new("Frame", panel)
	pDiv.Position = UDim2.new(0, 10, 0, 31)
	pDiv.Size = UDim2.new(1, -20, 0, 2)
	pDiv.BackgroundColor3 = Color3.new(1, 1, 1)
	pDiv.BorderSizePixel = 0
	pDiv.ZIndex = 130
	table.insert(Reg.grads, addGradient(pDiv, Theme.A1, Theme.A2, 0))

	-- left column: sliders
	local left = Instance.new("Frame", panel)
	left.Position = UDim2.new(0, 8, 0, 36)
	left.Size = UDim2.new(0, 205, 1, -42)
	left.BackgroundTransparency = 1
	left.ZIndex = 130
	local leftList = Instance.new("UIListLayout", left)
	leftList.Padding = UDim.new(0, GAP)
	leftList.SortOrder = Enum.SortOrder.LayoutOrder

	-- right column: presets + toggles
	local right = Instance.new("Frame", panel)
	right.Position = UDim2.new(0, 220, 0, 36)
	right.Size = UDim2.new(1, -228, 1, -42)
	right.BackgroundTransparency = 1
	right.ZIndex = 130
	local rightList = Instance.new("UIListLayout", right)
	rightList.Padding = UDim.new(0, GAP)
	rightList.SortOrder = Enum.SortOrder.LayoutOrder

	local sliders = {}

	local function hueOf(c)
		local h = c:ToHSV()
		return h
	end

	local function pct(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end

	sliders.h1 = makeSlider(left, "ACCENT COLOR 1", 0, 1, hueOf(Theme.A1), function(v)
		return string.format("%d°", math.floor(v * 360))
	end, function(v)
		Theme.A1 = Color3.fromHSV(v, 0.85, 1)
		Theme.Rainbow = false
		applyAll()
	end)

	sliders.h2 = makeSlider(left, "ACCENT COLOR 2", 0, 1, hueOf(Theme.A2), function(v)
		return string.format("%d°", math.floor(v * 360))
	end, function(v)
		Theme.A2 = Color3.fromHSV(v, 0.85, 1)
		Theme.Rainbow = false
		applyAll()
	end)

	sliders.size = makeSlider(left, "GUI SIZE", 0.6, 1.3, Theme.Scale, pct, function(v)
		Theme.Scale = v
		applyLook()
	end)

	sliders.opacity = makeSlider(left, "GUI OPACITY", 0, 1, 1 - Theme.Opacity, pct, function(v)
		Theme.Opacity = 1 - v
		applyLook()
	end)

	sliders.aura = makeSlider(left, "AURA POWER", 0, 1, Theme.AuraPower, pct, function(v)
		Theme.AuraPower = v
		applyLook()
	end)

	sliders.round = makeSlider(left, "ROUNDNESS", 0, 2, Theme.Round, pct, function(v)
		Theme.Round = v
		applyLook()
	end)

	sliders.volume = makeSlider(left, "MUSIC VOLUME", 0, 1, Theme.Volume, pct, function(v)
		Theme.Volume = v
		music.Volume = v
	end)

	for i, s in ipairs({ sliders.h1, sliders.h2, sliders.size, sliders.opacity, sliders.aura, sliders.round, sliders.volume }) do
		-- keep the slider order stable inside the list
		s = s
	end

	-- right column labels
	local function sectionLabel(text, order)
		local l = Instance.new("TextLabel", right)
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, 0, 14)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = Theme.Muted
		l.Font = Enum.Font.GothamBold
		l.TextSize = 10
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 131
		return l
	end

	sectionLabel("THEME PRESETS", 1)

	local presetRow = Instance.new("Frame", right)
	presetRow.LayoutOrder = 2
	presetRow.Size = UDim2.new(1, 0, 0, 28)
	presetRow.BackgroundTransparency = 1
	presetRow.ZIndex = 131
	local presetList = Instance.new("UIListLayout", presetRow)
	presetList.FillDirection = Enum.FillDirection.Horizontal
	presetList.Padding = UDim.new(0, GAP + 1)

	local chips = {}

	local function refreshSliders()
		sliders.h1.set(hueOf(Theme.A1), true)
		sliders.h2.set(hueOf(Theme.A2), true)
		sliders.size.set(Theme.Scale, true)
		sliders.opacity.set(1 - Theme.Opacity, true)
		sliders.aura.set(Theme.AuraPower, true)
		sliders.round.set(Theme.Round, true)
		sliders.volume.set(Theme.Volume, true)
	end

	local function refreshChips()
		chips.aura.Text = "AURA: " .. (Theme.Aura and "ON" or "OFF")
		chips.particles.Text = "SPARKS: " .. (Theme.Particles and "ON" or "OFF")
		chips.rainbow.Text = "RAINBOW: " .. (Theme.Rainbow and "ON" or "OFF")
		chips.spin.Text = "SPIN: " .. (Theme.Spin and "ON" or "OFF")
		chips.font.Text = "FONT: " .. FontNames[Theme.FontIndex]
	end

	local presets = {
		{ Color3.fromRGB(0, 200, 255), Color3.fromRGB(160, 60, 255) },
		{ Color3.fromRGB(255, 40, 60), Color3.fromRGB(120, 0, 40) },
		{ Color3.fromRGB(60, 255, 120), Color3.fromRGB(0, 150, 100) },
		{ Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 100, 0) },
		{ Color3.fromRGB(255, 120, 200), Color3.fromRGB(190, 90, 255) },
		{ Color3.fromRGB(130, 235, 255), Color3.fromRGB(60, 110, 255) }
	}

	for _, p in ipairs(presets) do
		local sw = Instance.new("TextButton", presetRow)
		sw.Size = UDim2.new(0, 27, 0, 26)
		sw.BackgroundColor3 = Color3.new(1, 1, 1)
		sw.Text = ""
		sw.AutoButtonColor = false
		sw.ZIndex = 133
		Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 7)
		addGradient(sw, p[1], p[2], 45)
		local sws = Instance.new("UIStroke", sw)
		sws.Color = Color3.new(1, 1, 1)
		sws.Transparency = 0.5
		sws.Thickness = 1
		sws.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		sw.MouseButton1Click:Connect(function()
			Theme.A1 = p[1]
			Theme.A2 = p[2]
			Theme.Rainbow = false
			applyAll()
			refreshSliders()
			refreshChips()
		end)
	end

	sectionLabel("EFFECTS", 3)

	local function twoRow(order)
		local r = Instance.new("Frame", right)
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 28)
		r.BackgroundTransparency = 1
		r.ZIndex = 131
		local rl = Instance.new("UIListLayout", r)
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.Padding = UDim.new(0, GAP)
		return r
	end

	local half = UDim2.new(0.5, -1, 1, 0)

	local row1 = twoRow(4)
	chips.aura = makeButton(row1, "", half, 11, function()
		Theme.Aura = not Theme.Aura
		applyLook()
		refreshChips()
	end)
	chips.particles = makeButton(row1, "", half, 11, function()
		Theme.Particles = not Theme.Particles
		refreshChips()
	end)

	local row2 = twoRow(5)
	chips.rainbow = makeButton(row2, "", half, 11, function()
		Theme.Rainbow = not Theme.Rainbow
		if not Theme.Rainbow then
			Theme.A1 = Defaults.A1
			Theme.A2 = Defaults.A2
			applyAll()
			refreshSliders()
		end
		refreshChips()
	end)
	chips.spin = makeButton(row2, "", half, 11, function()
		Theme.Spin = not Theme.Spin
		refreshChips()
	end)

	local row3 = twoRow(6)
	chips.font = makeButton(row3, "", UDim2.new(1, 0, 1, 0), 11, function()
		Theme.FontIndex = (Theme.FontIndex % #Fonts) + 1
		applyLook()
		refreshChips()
	end)

	local row4 = twoRow(7)
	makeButton(row4, "🎲 RANDOM", half, 11, function()
		local h = math.random()
		Theme.A1 = Color3.fromHSV(h, 0.8, 1)
		Theme.A2 = Color3.fromHSV((h + 0.25 + math.random() * 0.3) % 1, 0.85, 1)
		Theme.Rainbow = false
		applyAll()
		refreshSliders()
		refreshChips()
	end)
	makeButton(row4, "↺ RESET", half, 11, function()
		for k, v in pairs(Defaults) do
			Theme[k] = v
		end
		music.Volume = Theme.Volume
		applyAll()
		refreshSliders()
		refreshChips()
	end)

	refreshChips()

	-- open / close the panel with a short animation
	local panelOpen = false
	local panelTweens = {}

	local function setPanel(open)
		panelOpen = open
		for _, t in ipairs(panelTweens) do
			t:Cancel()
		end
		table.clear(panelTweens)

		if open then
			if not panel.Visible then
				panel.GroupTransparency = 1
				panelScale.Scale = 0.92
				panel.Visible = true
			end
			table.insert(panelTweens, tween(panel, 0.25, { GroupTransparency = 0 }))
			table.insert(panelTweens, tween(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back))
		else
			table.insert(panelTweens, tween(panel, 0.18, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
			local cl = tween(panelScale, 0.18, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			table.insert(panelTweens, cl)
			cl.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not panelOpen then
					panel.Visible = false
				end
			end)
		end
	end

	gearBtn.MouseButton1Click:Connect(function()
		setPanel(not panelOpen)
	end)
	pClose.MouseButton1Click:Connect(function()
		setPanel(false)
	end)

	-- Keep the sound bar below the main GUI and the customizer beside it.
	-- They are siblings of MainWindow so CanvasGroup bounds do not clip them;
	-- their screen positions are synchronized whenever MainWindow moves/resizes.
	local function syncAttachedPanels()
		if not Main or not Main.Parent then return end
		local mainPos = Main.AbsolutePosition
		local mainSize = Main.AbsoluteSize
		bar.Position = UDim2.fromOffset(
			mainPos.X + mainSize.X / 2,
			mainPos.Y + mainSize.Y + 8
		)
		local panelX = mainPos.X + mainSize.X + 10
		local cam = workspace.CurrentCamera
		if cam and panelX + panel.AbsoluteSize.X > cam.ViewportSize.X then
			panelX = math.max(8, mainPos.X - panel.AbsoluteSize.X - 10)
		end
		panel.Position = UDim2.fromOffset(
			panelX,
			mainPos.Y + (mainSize.Y - panel.AbsoluteSize.Y) / 2
		)
	end

	Main:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncAttachedPanels)
	Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncAttachedPanels)
	MainScale:GetPropertyChangedSignal("Scale"):Connect(syncAttachedPanels)
	if workspace.CurrentCamera then
		table.insert(Cleanup, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(syncAttachedPanels))
	end
	task.defer(syncAttachedPanels)
	-- Start just below the main GUI; the main window's drag keeps this bar attached.
	setMusic(true)
end

--==================================================
-- ONE DRIVER LOOP FOR ALL ANIMATIONS
--==================================================

do
	local accTick = 0
	local shadeTick = 0
	local spinRot = 0

	table.insert(Hooks, function(t, dt)
		-- title shimmer
		TitleGrad.Offset = Vector2.new(math.sin(t * 1.6) * 0.45, 0)

		-- rotating main border
		if Theme.Spin and Main.Visible then
			spinRot = (spinRot + 90 * dt) % 360
			MainStrokeGrad.Rotation = spinRot
		end

		-- danger pulse on the toggle
		local pulse = (math.sin(t * 5) + 1) / 2
		ToggleStroke.Color = Color3.fromRGB(255, 30, 30):Lerp(Color3.fromRGB(255, 150, 0), pulse)
		ToggleStroke.Thickness = 3 + pulse
		BadgeStroke.Color = ToggleStroke.Color

		-- rainbow theme
		if Theme.Rainbow then
			local h = (t * 0.08) % 1
			Theme.A1 = Color3.fromHSV(h, 0.8, 1)
			Theme.A2 = Color3.fromHSV((h + 0.4) % 1, 0.85, 1)

			accTick = accTick + dt
			shadeTick = shadeTick + dt

			if accTick > 0.06 then
				accTick = 0
				applyAccent()
			end
			if shadeTick > 0.35 then
				shadeTick = 0
				applyShades()
			end
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while sg.Parent do
			local now = os.clock()
			local dt = now - last
			last = now
			for _, fn in ipairs(Hooks) do
				pcall(fn, now, dt)
			end
			task.wait(0.033)
		end
	end)
end

-- apply the theme to everything once, then open the main window
applyAll()
setMain(true)
