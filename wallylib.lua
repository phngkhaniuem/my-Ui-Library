-- ============================================================
--  UI Library (cleaned)
-- ============================================================

local Library = {
	count       = 0,
	queue       = {},
	callbacks   = {},
	rainbowtable= {},
	toggled     = true,
	binds       = {},
}

local WindowMeta = {}
WindowMeta.__index = WindowMeta

local Mouse    = game:GetService("Players").LocalPlayer:GetMouse()
local UIS      = game:GetService("UserInputService")
local RS       = game:GetService("RunService")
local Heartbeat= RS.Heartbeat

-- ============================================================
--  Default theme
-- ============================================================
local default = {
	topcolor         = Color3.fromRGB(30, 30, 30),
	titlecolor       = Color3.fromRGB(255, 255, 255),
	underlinecolor   = Color3.fromRGB(0, 0, 255),
	bgcolor          = Color3.fromRGB(35, 35, 35),
	boxcolor         = Color3.fromRGB(35, 35, 35),
	btncolor         = Color3.fromRGB(25, 25, 25),
	dropcolor        = Color3.fromRGB(25, 25, 25),
	sectncolor       = Color3.fromRGB(25, 25, 25),
	bordercolor      = Color3.fromRGB(60, 60, 60),
	font             = Enum.Font.SourceSans,
	titlefont        = Enum.Font.Code,
	fontsize         = 17,
	titlesize        = 18,
	textstroke       = 1,
	titlestroke      = 1,
	strokecolor      = Color3.fromRGB(0, 0, 0),
	textcolor        = Color3.fromRGB(255, 255, 255),
	titletextcolor   = Color3.fromRGB(255, 255, 255),
	placeholdercolor = Color3.fromRGB(255, 255, 255),
	titlestrokecolor = Color3.fromRGB(0, 0, 0),
}

Library.options = setmetatable({}, { __index = default })

-- ============================================================
--  Helper: Create instance
-- ============================================================
function Library.Create(_, className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			if typeof(v) == "Instance" then
				v.Parent = inst
			else
				inst[k] = v
			end
		end
	end
	inst.Parent = props.Parent
	return inst
end

-- ============================================================
--  Dragging
-- ============================================================
local Drag = {}

function Drag.new(titleBar)
	local window = titleBar.Parent
	titleBar.Active = true

	titleBar.InputBegan:connect(function(input)
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not isMouse and not isTouch then return end

		-- lấy vị trí ban đầu (mouse hoặc touch)
		local function getPos()
			if isTouch then
				return Vector2.new(input.Position.X, input.Position.Y)
			else
				return Vector2.new(Mouse.X, Mouse.Y)
			end
		end

		local startPos = getPos()
		local offset = Vector2.new(
			startPos.X - window.AbsolutePosition.X,
			startPos.Y - window.AbsolutePosition.Y
		)

		local moveConn, endConn

		local function stop()
			if moveConn then moveConn:Disconnect() end
			if endConn  then endConn:Disconnect()  end
		end

		if isTouch then
			-- touch: dùng InputChanged để theo ngón tay
			moveConn = UIS.InputChanged:connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.Touch then
					window.Position = UDim2.new(
						0, changed.Position.X - offset.X,
						0, changed.Position.Y - offset.Y
					)
				end
			end)
			endConn = UIS.InputEnded:connect(function(ended)
				if ended.UserInputType == Enum.UserInputType.Touch then
					stop()
				end
			end)
		else
			-- mouse: dùng Heartbeat
			moveConn = Heartbeat:Connect(function()
				if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					stop()
					return
				end
				window.Position = UDim2.new(
					0, Mouse.X - offset.X,
					0, Mouse.Y - offset.Y
				)
			end)
		end
	end)
end

-- ============================================================
--  Global toggle (RightControl)
-- ============================================================
UIS.InputBegan:connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
		Library.toggled = not Library.toggled
		for _, entry in pairs(Library.queue) do
			local pos = Library.toggled and entry.p or UDim2.new(-1, 0, -0.5, 0)
			entry.w:TweenPosition(pos, Library.toggled and "Out" or "In", "Quad", 0.15, true)
			wait()
		end
	end
end)

-- ============================================================
--  Keybind match helper
-- ============================================================
local function matchBind(bind, input)
	if typeof(bind) == "Instance" then
		if bind.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.KeyCode then
			return true
		end
		if tostring(bind.UserInputType):find("MouseButton") and input.UserInputType == bind.UserInputType then
			return true
		end
	end
	if tostring(bind):find("MouseButton1") then
		return bind == input.UserInputType
	else
		return bind == input.KeyCode
	end
end

UIS.InputBegan:connect(function(input)
	if not Library.binding then
		for flag, data in pairs(Library.binds) do
			local val = data.location[flag]
			if val and matchBind(val, input) then
				data.callback()
			end
		end
	end
end)

-- ============================================================
--  Rainbow loop
-- ============================================================
spawn(function()
	local hue = 0
	while true do
		hue = (hue + 0.00333) % 1
		for _, obj in pairs(Library.rainbowtable) do
			obj.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		end
		wait()
	end
end)

-- ============================================================
--  WindowMeta helpers
-- ============================================================
function WindowMeta:Resize()
	local height = 0
	for _, child in pairs(self.container:GetChildren()) do
		if not child:IsA("UIListLayout") then
			height = height + child.AbsoluteSize.Y
		end
	end
	self.container.Size = UDim2.new(1, 0, 0, height + 5)
end

function WindowMeta:GetOrder()
	local count = 0
	for _, child in pairs(self.container:GetChildren()) do
		if not child:IsA("UIListLayout") then
			count = count + 1
		end
	end
	return count
end

-- ============================================================
--  window()
-- ============================================================
function WindowMeta.window(name, opts)
	Library.count = Library.count + 1
	local opt = opts

	local titleLabel = Library:Create("TextLabel", {
		Text                  = name,
		Size                  = UDim2.new(1, -10, 1, 0),
		Position              = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency= 1,
		Font                  = opt.titlefont,
		TextSize              = opt.titlesize,
		TextColor3            = opt.titletextcolor,
		TextStrokeTransparency= opt.titlestroke,
		TextStrokeColor3      = opt.titlestrokecolor,
		ZIndex                = 3,
	})

	local toggleBtn = Library:Create("TextButton", {
		Size                  = UDim2.new(0, 30, 0, 30),
		Position              = UDim2.new(1, -35, 0, 0),
		BackgroundTransparency= 1,
		Text                  = "-",
		TextSize              = opt.titlesize,
		Font                  = opt.titlefont,
		Name                  = "window_toggle",
		TextColor3            = opt.titletextcolor,
		TextStrokeTransparency= opt.titlestroke,
		TextStrokeColor3      = opt.titlestrokecolor,
		ZIndex                = 3,
	})

	local underline = Library:Create("Frame", {
		Name            = "Underline",
		Size            = UDim2.new(1, 0, 0, 2),
		Position        = UDim2.new(0, 0, 1, -2),
		BackgroundColor3= opt.underlinecolor ~= "rainbow" and opt.underlinecolor or Color3.new(),
		BorderSizePixel = 0,
		ZIndex          = 3,
	})

	local container = Library:Create("Frame", {
		Name              = "container",
		Position          = UDim2.new(0, 0, 1, 0),
		Size              = UDim2.new(1, 0, 0, 0),
		BorderSizePixel   = 0,
		BackgroundColor3  = opt.bgcolor,
		ClipsDescendants  = false,
		Library:Create("UIListLayout", { Name = "List", SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local frame = Library:Create("Frame", {
		Name            = name,
		Size            = UDim2.new(0, 190, 0, 30),
		BackgroundColor3= opt.topcolor,
		BorderSizePixel = 0,
		Parent          = Library.container,
		Position        = UDim2.new(0, 15 + 200 * Library.count - 200, 0, 0),
		ZIndex          = 3,
		titleLabel,
		toggleBtn,
		underline,
		container,
	})

	if opt.underlinecolor == "rainbow" then
		table.insert(Library.rainbowtable, frame:FindFirstChild("Underline"))
	end

	local win = setmetatable({
		count    = 0,
		object   = frame,
		container= frame.container,
		toggled  = true,
		flags    = {},
	}, WindowMeta)

	table.insert(Library.queue, { w = win.object, p = win.object.Position })

	frame:FindFirstChild("window_toggle").MouseButton1Click:connect(function()
		win.toggled = not win.toggled
		frame:FindFirstChild("window_toggle").Text = win.toggled and "+" or "-"

		if not win.toggled then
			win.container.ClipsDescendants = true
		end
		wait()

		local height = 0
		for _, child in pairs(win.container:GetChildren()) do
			if not child:IsA("UIListLayout") then
				height = height + child.AbsoluteSize.Y
			end
		end

		local targetSize = win.toggled and UDim2.new(1, 0, 0, height + 5) or UDim2.new(1, 0, 0, 0)
		win.container:TweenSize(targetSize, win.toggled and "In" or "Out", "Quint", 0.3, true)
		wait(0.3)

		if win.toggled then
			win.container.ClipsDescendants = false
		end
	end)

	return win
end

-- ============================================================
--  Toggle
-- ============================================================
function WindowMeta:Toggle(label, cfg, callback)
	local val      = cfg.default or false
	local loc      = cfg.location or self.flags
	local flag     = cfg.flag or ""
	local cb       = callback or function() end
	loc[flag]      = val

	local checkmark = Library:Create("TextButton", {
		Text                  = loc[flag] and utf8.char(10003) or "",
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		Name                  = "Checkmark",
		Size                  = UDim2.new(0, 20, 0, 20),
		Position              = UDim2.new(1, -25, 0, 4),
		TextColor3            = Library.options.textcolor,
		BackgroundColor3      = Library.options.bgcolor,
		BorderColor3          = Library.options.bordercolor,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	local textLabel = Library:Create("TextLabel", {
		Name                  = label,
		Text                  = "\r" .. label,
		BackgroundTransparency= 1,
		TextColor3            = Library.options.textcolor,
		Position              = UDim2.new(0, 5, 0, 0),
		Size                  = UDim2.new(1, -5, 1, 0),
		TextXAlignment        = Enum.TextXAlignment.Left,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		checkmark,
	})

	local row = Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		textLabel,
	})

	local function toggle(_)
		loc[flag] = not loc[flag]
		cb(loc[flag])
		row:FindFirstChild(label).Checkmark.Text = loc[flag] and utf8.char(10003) or ""
	end

	row:FindFirstChild(label).Checkmark.MouseButton1Click:connect(toggle)
	Library.callbacks[flag] = toggle

	if loc[flag] == true then cb(loc[flag]) end

	self:Resize()

	return {
		Set = function(_, newVal)
			loc[flag] = newVal
			cb(loc[flag])
			row:FindFirstChild(label).Checkmark.Text = loc[flag] and utf8.char(10003) or ""
		end
	}
end

-- ============================================================
--  Button
-- ============================================================
function WindowMeta:Button(label, callback)
	local cb = callback or function() end

	local btn = Library:Create("TextButton", {
		Name                  = label,
		Text                  = label,
		BackgroundColor3      = Library.options.btncolor,
		BorderColor3          = Library.options.bordercolor,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		TextColor3            = Library.options.textcolor,
		Position              = UDim2.new(0, 5, 0, 5),
		Size                  = UDim2.new(1, -10, 0, 20),
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
	})

	Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		btn,
	}):FindFirstChild(label).MouseButton1Click:connect(cb)

	self:Resize()

	return {
		Fire = function() cb() end
	}
end

-- ============================================================
--  Box (TextBox)
-- ============================================================
function WindowMeta:Box(label, cfg, callback)
	local inputType = cfg.type or ""
	local default_  = cfg.default or ""
	local loc       = cfg.location or self.flags
	local flag      = cfg.flag or ""
	local cb        = callback or function() end
	local minVal    = cfg.min or 0
	local maxVal    = cfg.max or 9000000000

	if inputType == "number" and tonumber(default_) then
		loc[flag] = default_
	else
		loc[flag] = ""
		default_  = ""
	end

	local box = Library:Create("TextBox", {
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		Text                  = tostring(default_),
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		Name                  = "Box",
		Size                  = UDim2.new(0, 60, 0, 20),
		Position              = UDim2.new(1, -65, 0, 3),
		TextColor3            = Library.options.textcolor,
		BackgroundColor3      = Library.options.boxcolor,
		BorderColor3          = Library.options.bordercolor,
		PlaceholderColor3     = Library.options.placeholdercolor,
	})

	local textLabel = Library:Create("TextLabel", {
		Name                  = label,
		Text                  = "\r" .. label,
		BackgroundTransparency= 1,
		TextColor3            = Library.options.textcolor,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		Position              = UDim2.new(0, 5, 0, 0),
		Size                  = UDim2.new(1, -5, 1, 0),
		TextXAlignment        = Enum.TextXAlignment.Left,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		box,
	})

	Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		textLabel,
	})

	box.FocusLost:connect(function(enterPressed)
		local prev = loc[flag]
		if inputType ~= "number" then
			loc[flag] = tostring(box.Text)
		else
			local n = tonumber(box.Text)
			if n then
				loc[flag] = math.clamp(n, minVal, maxVal)
				box.Text   = tostring(loc[flag])
			else
				box.Text   = tostring(loc[flag])
			end
		end
		cb(loc[flag], prev, enterPressed)
	end)

	if inputType == "number" then
		box:GetPropertyChangedSignal("Text"):connect(function()
			box.Text = string.gsub(box.Text, "[%a+]", "")
		end)
	end

	self:Resize()
	return box
end

-- ============================================================
--  Bind
-- ============================================================
function WindowMeta:Bind(label, cfg, callback)
	local loc    = cfg.location or self.flags
	local kbOnly = cfg.kbonly or false
	local flag   = cfg.flag or ""
	local cb     = callback or function() end
	local def    = cfg.default

	if kbOnly and not tostring(def):find("MouseButton") then
		loc[flag] = def
	end

	local blacklist = { Return=true, Space=true, Tab=true, Unknown=true }
	local aliases   = {
		RightControl="RightCtrl", LeftControl="LeftCtrl",
		LeftShift="LShift",       RightShift="RShift",
		MouseButton1="Mouse1",    MouseButton2="Mouse2",
	}
	local mouseButtons = { MouseButton1=true, MouseButton2=true }

	local displayName = not def or aliases[def.Name] or (def.Name or "None")

	local keybindBtn = Library:Create("TextButton", {
		Name                  = "Keybind",
		Text                  = displayName,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		Size                  = UDim2.new(0, 60, 0, 20),
		Position              = UDim2.new(1, -65, 0, 5),
		TextColor3            = Library.options.textcolor,
		BackgroundColor3      = Library.options.bgcolor,
		BorderColor3          = Library.options.bordercolor,
		BorderSizePixel       = 1,
	})

	local textLabel = Library:Create("TextLabel", {
		Name                  = label,
		Text                  = "\r" .. label,
		BackgroundTransparency= 1,
		TextColor3            = Library.options.textcolor,
		Position              = UDim2.new(0, 5, 0, 0),
		Size                  = UDim2.new(1, -5, 1, 0),
		TextXAlignment        = Enum.TextXAlignment.Left,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		BorderColor3          = Library.options.bordercolor,
		BorderSizePixel       = 1,
		keybindBtn,
	})

	Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 30),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		textLabel,
	})

	keybindBtn.MouseButton1Click:connect(function()
		Library.binding = true
		keybindBtn.Text  = "..."

		local input = UIS.InputBegan:wait()

		local isInvalid = (input.UserInputType == Enum.UserInputType.Keyboard or
		                   (not mouseButtons[input.UserInputType.Name] or kbOnly))
		               and (not input.KeyCode or blacklist[input.KeyCode.Name])

		if isInvalid then
			-- restore previous bind display
			if loc[flag] then
				local ok = pcall(function() return loc[flag].UserInputType end)
				if ok then
					local name = loc[flag].UserInputType ~= Enum.UserInputType.Keyboard
					             and loc[flag].UserInputType.Name
					             or loc[flag].KeyCode.Name
					keybindBtn.Text = aliases[name] or name
				else
					local s = tostring(loc[flag])
					keybindBtn.Text = aliases[s] or s
				end
			end
		else
			local name = input.UserInputType ~= Enum.UserInputType.Keyboard
			             and input.UserInputType.Name
			             or input.KeyCode.Name
			loc[flag]       = input
			keybindBtn.Text = aliases[name] or name
		end

		wait(0.1)
		Library.binding = false
	end)

	if loc[flag] then
		keybindBtn.Text = aliases[tostring(loc[flag].Name)] or tostring(loc[flag].Name)
	end

	Library.binds[flag] = { location = loc, callback = cb }

	self:Resize()
end

-- ============================================================
--  Section
-- ============================================================
function WindowMeta:Section(text)
	local order = self:GetOrder()
	local size  = order == 0 and UDim2.new(1, 0, 0, 21) or UDim2.new(1, 0, 0, 25)
	local pos   = order == 0 and UDim2.new(0, 0, 0, -1) or UDim2.new(0, 0, 0, 4)
	local lblSz = order == 0 and UDim2.new(1, 0, 1, 0)  or UDim2.new(1, 0, 0, 20)

	local lbl = Library:Create("TextLabel", {
		Name                  = "section_lbl",
		Text                  = text,
		BackgroundTransparency= 0,
		BorderSizePixel       = 0,
		BackgroundColor3      = Library.options.sectncolor,
		TextColor3            = Library.options.textcolor,
		Position              = pos,
		Size                  = lblSz,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	Library:Create("Frame", {
		Name                  = "Section",
		BackgroundTransparency= 1,
		Size                  = size,
		BackgroundColor3      = Library.options.sectncolor,
		BorderSizePixel       = 0,
		LayoutOrder           = order,
		Parent                = self.container,
		lbl,
	})

	self:Resize()
end

-- ============================================================
--  Slider
-- ============================================================
function WindowMeta:Slider(label, cfg, callback)
	local val    = cfg.default or cfg.min
	local minVal = cfg.min or 0
	local maxVal = cfg.max or 1
	local loc    = cfg.location or self.flags
	local precise= cfg.precise or false
	local flag   = cfg.flag or ""
	local cb     = callback or function() end
	loc[flag]    = val

	local valLabel = Library:Create("TextLabel", {
		Name                  = "ValueLabel",
		Text                  = val,
		BackgroundTransparency= 1,
		TextColor3            = Library.options.textcolor,
		Position              = UDim2.new(0, -10, 0, 0),
		Size                  = UDim2.new(0, 1, 1, 0),
		TextXAlignment        = Enum.TextXAlignment.Right,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	local button = Library:Create("TextButton", {
		Name            = "Button",
		Size            = UDim2.new(0, 5, 1, -2),
		Position        = UDim2.new(0, 0, 0, 1),
		AutoButtonColor = false,
		Text            = "",
		BackgroundColor3= Color3.fromRGB(20, 20, 20),
		BorderSizePixel = 0,
		ZIndex          = 2,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	local line = Library:Create("Frame", {
		Name                  = "Line",
		BackgroundTransparency= 0,
		Position              = UDim2.new(0, 0, 0.5, 0),
		Size                  = UDim2.new(1, 0, 0, 1),
		BackgroundColor3      = Library.options.textcolor,
		BorderSizePixel       = 0,
	})

	local sliderContainer = Library:Create("Frame", {
		Name              = "Container",
		Size              = UDim2.new(0, 60, 0, 20),
		Position          = UDim2.new(1, -65, 0, 3),
		BackgroundTransparency= 1,
		BorderSizePixel   = 0,
		valLabel, button, line,
	})

	local textLabel = Library:Create("TextLabel", {
		Name                  = label,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		Text                  = "\r" .. label,
		BackgroundTransparency= 1,
		TextColor3            = Library.options.textcolor,
		Position              = UDim2.new(0, 5, 0, 2),
		Size                  = UDim2.new(1, -5, 1, 0),
		TextXAlignment        = Enum.TextXAlignment.Left,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		sliderContainer,
	})

	local row = Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		textLabel,
	})

	local sliderEl    = row:FindFirstChild(label)
	local renderConn  = nil
	local enterConn, leaveConn, inputBegin, inputEnd, btnDown, globalUp

	local function startDrag()
		if renderConn then renderConn:disconnect() end
		renderConn = RS.RenderStepped:connect(function()
			local mouseX    = UIS:GetMouseLocation().X
			local pct       = (mouseX - sliderEl.Container.AbsolutePosition.X) / sliderEl.Container.AbsoluteSize.X
			local clamped   = math.clamp(pct, 0, 1)
			local fmtPct    = tonumber(string.format("%.2f", clamped))
			sliderEl.Container.Button.Position = UDim2.new(math.clamp(fmtPct, 0, 0.99), 0, 0, 1)
			local raw       = minVal + (maxVal - minVal) * clamped
			local result    = precise and raw or math.floor(raw)
			sliderEl.Container.ValueLabel.Text = result
			cb(tonumber(result))
			loc[flag] = tonumber(result)
		end)
	end

	local function stopDrag()
		if renderConn  then renderConn:disconnect()  end
		if enterConn   then enterConn:disconnect()   end
		if inputEnd    then inputEnd:disconnect()     end
		if inputBegin  then inputBegin:disconnect()   end
		if globalUp    then globalUp:disconnect()     end
	end

	sliderEl.Container.MouseEnter:connect(function()
		enterConn = nil

		inputBegin = sliderEl.Container.InputBegan:connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then startDrag() end
		end)
		inputEnd = sliderEl.Container.InputEnded:connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then stopDrag() end
		end)
		btnDown = sliderEl.Container.Button.MouseButton1Down:connect(startDrag)
		globalUp = UIS.InputEnded:connect(function(inp, _)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 and btnDown and btnDown.Connected then
				stopDrag()
			end
		end)

		enterConn = sliderEl.Container.MouseLeave:connect(function()
			-- connections cleaned up by stopDrag / globalUp
		end)
	end)

	-- Set initial position
	if val ~= minVal then
		local frac = 1 - (maxVal - val) / (maxVal - minVal)
		local display = not precise and math.floor(tonumber(string.format("%.2f", val))) or tonumber(string.format("%.2f", val))
		sliderEl.Container.Button.Position    = UDim2.new(math.clamp(frac, 0, 0.99), 0, 0, 1)
		sliderEl.Container.ValueLabel.Text    = display
	end

	self:Resize()

	return {
		Set = function(_, newVal)
			local frac    = 1 - (maxVal - newVal) / (maxVal - minVal)
			local display = not precise and math.floor(tonumber(string.format("%.2f", newVal))) or tonumber(string.format("%.2f", newVal))
			sliderEl.Container.Button.Position   = UDim2.new(math.clamp(frac, 0, 0.99), 0, 0, 1)
			sliderEl.Container.ValueLabel.Text   = display
			loc[flag] = display
			cb(display)
		end
	}
end

-- ============================================================
--  SearchBox
-- ============================================================
function WindowMeta:SearchBox(placeholder, cfg, callback)
	local list     = cfg.list or {}
	local flag     = cfg.flag or ""
	local loc      = cfg.location or self.flags
	local cb       = callback or function() end
	local selecting= false

	local listLayout = Library:Create("UIListLayout", {
		Name      = "ListLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local dropContainer = Library:Create("ScrollingFrame", {
		Position          = UDim2.new(0, 0, 1, 1),
		Name              = "Container",
		BackgroundColor3  = Library.options.btncolor,
		ScrollBarThickness= 0,
		BorderSizePixel   = 0,
		BorderColor3      = Library.options.bordercolor,
		Size              = UDim2.new(1, 0, 0, 0),
		ZIndex            = 2,
		listLayout,
	})

	local box = Library:Create("TextBox", {
		Text                  = "",
		PlaceholderText       = placeholder,
		PlaceholderColor3     = Color3.fromRGB(60, 60, 60),
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		Name                  = "Box",
		Size                  = UDim2.new(1, -10, 0, 20),
		Position              = UDim2.new(0, 5, 0, 4),
		TextColor3            = Library.options.textcolor,
		BackgroundColor3      = Library.options.dropcolor,
		BorderColor3          = Library.options.bordercolor,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
		dropContainer,
	})

	local row = Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		box,
	})

	local function updateSearch(query)
		row:FindFirstChild("Box").Container.ScrollBarThickness = 0
		for _, child in pairs(row:FindFirstChild("Box").Container:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end

		if #query > 0 then
			for _, item in pairs(list) do
				if string.sub(string.lower(item), 1, #query) == string.lower(query) then
					local itemBtn = Library:Create("TextButton", {
						Text                  = item,
						Font                  = Library.options.font,
						TextSize              = Library.options.fontsize,
						TextColor3            = Library.options.textcolor,
						BorderColor3          = Library.options.bordercolor,
						TextStrokeTransparency= Library.options.textstroke,
						TextStrokeColor3      = Library.options.strokecolor,
						Parent                = row:FindFirstChild("Box").Container,
						Size                  = UDim2.new(1, 0, 0, 20),
						BackgroundColor3      = Library.options.btncolor,
						ZIndex                = 2,
					})
					itemBtn.MouseButton1Click:connect(function()
						selecting = true
						row:FindFirstChild("Box").Text = itemBtn.Text
						wait()
						selecting = false
						loc[flag] = itemBtn.Text
						cb(loc[flag])
						local cont = row:FindFirstChild("Box").Container
						cont.ScrollBarThickness = 0
						for _, c in pairs(cont:GetChildren()) do
							if not c:IsA("UIListLayout") then c:Destroy() end
						end
						cont:TweenSize(UDim2.new(1, 0, 0, 0), "Out", "Quint", 0.3, true)
					end)
				end
			end
		end

		local children = row:FindFirstChild("Box").Container:GetChildren()
		local total    = 20 * #children - 20
		local clamped  = math.clamp(total, 0, 100)
		if total > 100 then
			row:FindFirstChild("Box").Container.ScrollBarThickness = 5
		end
		row:FindFirstChild("Box").Container:TweenSize(UDim2.new(1, 0, 0, clamped), "Out", "Quint", 0.3, true)
		row:FindFirstChild("Box").Container.CanvasSize = UDim2.new(1, 0, 0, total)
	end

	row:FindFirstChild("Box"):GetPropertyChangedSignal("Text"):connect(function()
		if not selecting then
			updateSearch(row:FindFirstChild("Box").Text)
		end
	end)

	self:Resize()

	local function refresh(newList)
		list = newList
		updateSearch("")
	end

	return refresh, row:FindFirstChild("Box")
end

-- ============================================================
--  Dropdown
-- ============================================================
function WindowMeta:Dropdown(label, items, cfg, callback)
	local loc    = cfg.location or self.flags
	local flag   = cfg.flag or ""
	local cb     = callback or function() end
	local list   = cfg.list or items or {}
	loc[flag]    = list[1]

	local selLabel = Library:Create("TextLabel", {
		Name                  = "Selection",
		Size                  = UDim2.new(1, 0, 1, 0),
		Text                  = list[1],
		TextColor3            = Library.options.textcolor,
		BackgroundTransparency= 1,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	local dropArrow = Library:Create("TextButton", {
		Name                  = "drop",
		BackgroundTransparency= 1,
		Size                  = UDim2.new(0, 20, 1, 0),
		Position              = UDim2.new(1, -25, 0, 0),
		Text                  = "v",
		TextColor3            = Library.options.textcolor,
		Font                  = Library.options.font,
		TextSize              = Library.options.fontsize,
		TextStrokeTransparency= Library.options.textstroke,
		TextStrokeColor3      = Library.options.strokecolor,
	})

	local dropLabel = Library:Create("Frame", {
		Name            = "dropdown_lbl",
		BackgroundTransparency= 0,
		BackgroundColor3= Library.options.dropcolor,
		Position        = UDim2.new(0, 5, 0, 4),
		BorderColor3    = Library.options.bordercolor,
		Size            = UDim2.new(1, -10, 0, 20),
		selLabel, dropArrow,
	})

	local row = Library:Create("Frame", {
		BackgroundTransparency= 1,
		Size                  = UDim2.new(1, 0, 0, 25),
		BackgroundColor3      = Color3.fromRGB(25, 25, 25),
		BorderSizePixel       = 0,
		LayoutOrder           = self:GetOrder(),
		Parent                = self.container,
		dropLabel,
	})

	local outsideConn = nil

	local function isMouseOver(frame)
		local mouse   = UIS:GetMouseLocation()
		local mPos    = Vector2.new(mouse.X, mouse.Y - 36)
		local absPos  = frame.AbsolutePosition
		local absSize = frame.AbsoluteSize
		return mPos.X >= absPos.X and mPos.X <= absPos.X + absSize.X
		   and mPos.Y >= absPos.Y and mPos.Y <= absPos.Y + absSize.Y
	end

	dropArrow.MouseButton1Click:connect(function()
		if outsideConn and outsideConn.Connected then return end

		row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").TextColor3 = Color3.fromRGB(60, 60, 60)
		row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").Text       = label

		-- Calculate height
		local itemCount  = 0
		for _ in pairs(list) do itemCount = itemCount + 1 end
		local totalH = itemCount * 20
		local scrollH, scrollBar
		if totalH <= 100 then
			scrollH   = totalH
			scrollBar = 0
		else
			scrollH   = 100
			scrollBar = 5
		end

		local scroll = Library:Create("ScrollingFrame", {
			TopImage          = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			BottomImage       = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			Name              = "DropContainer",
			Parent            = row:FindFirstChild("dropdown_lbl"),
			Size              = UDim2.new(1, 0, 0, 0),
			BackgroundColor3  = Library.options.bgcolor,
			BorderColor3      = Library.options.bordercolor,
			Position          = UDim2.new(0, 0, 1, 0),
			ScrollBarThickness= scrollBar,
			CanvasSize        = UDim2.new(0, 0, 0, totalH),
			ZIndex            = 5,
			ClipsDescendants  = true,
			Library:Create("UIListLayout", { Name = "List", SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		for idx, item in pairs(list) do
			local itemBtn = Library:Create("TextButton", {
				Size                  = UDim2.new(1, 0, 0, 20),
				BackgroundColor3      = Library.options.btncolor,
				BorderColor3          = Library.options.bordercolor,
				Text                  = item,
				Font                  = Library.options.font,
				TextSize              = Library.options.fontsize,
				LayoutOrder           = idx,
				Parent                = scroll,
				ZIndex                = 5,
				TextColor3            = Library.options.textcolor,
				TextStrokeTransparency= Library.options.textstroke,
				TextStrokeColor3      = Library.options.strokecolor,
			})
			itemBtn.MouseButton1Click:connect(function()
				row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").TextColor3 = Library.options.textcolor
				row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").Text       = itemBtn.Text
				loc[flag] = tostring(itemBtn.Text)
				cb(loc[flag])
				game:GetService("Debris"):AddItem(scroll, 0)
				if outsideConn then outsideConn:disconnect() end
			end)
		end

		scroll:TweenSize(UDim2.new(1, 0, 0, scrollH), "Out", "Quint", 0.3, true)

		outsideConn = UIS.InputBegan:connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 and not isMouseOver(scroll) then
				row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").TextColor3 = Library.options.textcolor
				row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").Text       = loc[flag]
				scroll:TweenSize(UDim2.new(1, 0, 0, 0), "In", "Quint", 0.3, true)
				wait(0.15)
				game:GetService("Debris"):AddItem(scroll, 0)
				outsideConn:disconnect()
			end
		end)
	end)

	self:Resize()

	return {
		Refresh = function(_, newItems)
			list     = newItems
			loc[flag] = newItems[1]
			pcall(function() if outsideConn then outsideConn:disconnect() end end)
			row:WaitForChild("dropdown_lbl").Selection.Text = loc[flag]
			row:FindFirstChild("dropdown_lbl"):WaitForChild("Selection").TextColor3 = Library.options.textcolor
		end
	}
end

-- ============================================================
--  CreateWindow (entry point)
-- ============================================================
function Library.CreateWindow(_, name, opts)
	if not Library.container then
		local gui = Library:Create("ScreenGui", {
			Name  = "LibraryGui",
			Parent= game:GetService("CoreGui"),
			Library:Create("Frame", {
				Name                  = "Container",
				Size                  = UDim2.new(1, -30, 1, 0),
				Position              = UDim2.new(0, 20, 0, 20),
				BackgroundTransparency= 1,
				Active                = false,
			}),
		})
		Library.container = gui:FindFirstChild("Container")
	end

	if opts then
		Library.options = setmetatable(opts, { __index = default })
	end

	local win = WindowMeta.window(name, Library.options)
	Drag.new(win.object)
	return win
end

return Library
