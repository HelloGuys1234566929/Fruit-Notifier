local local_player = game.Players.LocalPlayer
local notifier = local_player.PlayerGui:WaitForChild("Main"):WaitForChild("[OLD]Radar")

-- Displays text on the same label that we use to locate fruits (notifier)

local Translations = {
	["en-us"] = {
		scriptEnabled = "Script enabled successfully",
		notifierOn = "Notifier (ON)",
		notifierOff = "Notifier (OFF)",
		notifierEnabled = "Notifier enabled successfully",
		notifierDisabled = "Notifier disabled successfully",
		switchNotify = "Shows spawned fruits location",
		fruitFound = "%s found: %dm away",
		fruitDespawned = "Fruit despawned/collected",
		defaultFruit = "A fruit",
		fruitPrefix = "%s fruit",
	},
	["pt-br"] = {
		scriptEnabled = "Script ativado com sucesso",
		notifierOn = "Notificador (ATIVADO)",
		notifierOff = "Notificador (DESATIVADO)",
		notifierEnabled = "Notificador ativado com sucesso",
		notifierDisabled = "Notificador desativado com sucesso",
		switchNotify = "Mostra a localizacao das frutas spawnadas",
		fruitFound = "%s encontrada a: %dm",
		fruitDespawned = "Fruta despawnada/coletada",
		defaultFruit = "Uma fruta",
		fruitPrefix = "Fruta %s",
	},
	["tr-tr"] = {
		scriptEnabled = "Betik başarıyla etkinleştirildi",
		notifierOn = "Bildirici (AÇIK)",
		notifierOff = "Bildirici (KAPALI)",
		notifierEnabled = "Bildirici başarıyla etkinleştirildi",
		notifierDisabled = "Bildirici başarıyla devre dışı bırakıldı",
		switchNotify = "Doğan meyvelerin konumunu gösterir",
		fruitFound = "%s bulundu: %dm uzakta",
		fruitDespawned = "Meyve kayboldu/toplandı",
		defaultFruit = "Bir meyve",
		fruitPrefix = "%s meyvesi",
	},
	["es-es"] = {
		scriptEnabled = "Script activado con éxito",
		notifierOn = "Notificador (ACTIVADO)",
		notifierOff = "Notificador (DESACTIVADO)",
		notifierEnabled = "Notificador activado con éxito",
		notifierDisabled = "Notificador desactivado con éxito",
		switchNotify = "Muestra la ubicación de las frutas aparecidas",
		fruitFound = "%s encontrada a: %dm de distancia",
		fruitDespawned = "Fruta desaparecida/recolectada",
		defaultFruit = "Una fruta",
		fruitPrefix = "Fruta %s",
	},
}

-- Fetch the player's locale, format to lowercase, and fallback to "en-us" if missing
local userLocale = string.lower(game:GetService("LocalizationService").RobloxLocaleId)
local t = Translations[userLocale] or Translations["en-us"]

local function showText(text, time)
	notifier.Text = text
	notifier.Visible = true

	task.wait(time)

	notifier.Visible = false
end

-- Plays sound (like when a fruit spawn)
local function playSound(asset_id, pb_speed)
	local sound = Instance.new("Sound", workspace)
	sound.SoundId = asset_id
	sound.Volume = 1
	sound.PlaybackSpeed = pb_speed
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Little colored dot (green = on / red = off)
local function createLed()
	-- The Blox Fruits twitter image button at the right
	local twitter_button = local_player.PlayerGui.Main.Code
	if twitter_button:FindFirstChild("NotifierLed") then
		twitter_button.NotifierLed:Destroy()
	end
	
	local led = Instance.new("Frame")
	led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	led.BackgroundTransparency = 0.3
	led.Position = UDim2.new(1.3, 0, 0.35, 0)
	led.Size = UDim2.new(0, 8, 0, 8)
	led.Name = "NotifierLed"
	led.Parent = twitter_button

	local border = Instance.new("UICorner", led)
	border.CornerRadius = UDim.new(1)
	
	-- Shows/hides the led when twitter image button is clicked
	twitter_button.Activated:Connect(function()
		led.Visible = not led.Visible
	end)

	return led	
end

-- Switch to turn the notifier on/off
local function createSwitch()
	-- The Blox Fruits settings image button at the right
	local settings_button = local_player.PlayerGui.Main.Settings
	if settings_button:FindFirstChild("NotifierSwitch") then
		settings_button.NotifierSwitch:Destroy()
	end
	
	-- Creates the notifier switch by making a copy of an existent Blox Fruits switch
	local switch = settings_button.DmgCounterButton:Clone()
	
	-- Applied translations for Switch label and text
	switch.Notify.Text = t.switchNotify
	switch.TextLabel.Text = t.notifierOff

	switch.Position = UDim2.new(-1.2, 0, -4.03, 0) -- Above counter switch
	switch.Size = UDim2.new(5, 0, 0.8, 0) -- Similar size to other switches
	switch.Name = "NotifierSwitch"
	
	switch.Parent = settings_button
	
	-- Shows/hides the switch when settings image button is clicked
	settings_button.Activated:Connect(function()
		switch.Visible = not switch.Visible
	end)

	return switch
end

-- To store the connection, so after we can disconnect on switch click (also used to check switch state)
local workspace_connection

-- To be called when a fruit spawns
local function enableNotifier(fruit)
	local fruit_name = t.defaultFruit

	-- Fruit hasn't a position but its children do
	local fruit_child = fruit:WaitForChild("Handle")

	-- The MeshPart is a child of the fruit and the name is like Meshes/fruitsname_34
	for _, descendant in ipairs(fruit:GetChildren()) do
		if descendant:IsA("MeshPart") and string.sub(descendant.Name, 1, 7) == "Meshes/" then
			local i = string.find(descendant.Name, '_')

			fruit_name = string.sub(descendant.Name, 8, i - 1)

			-- Fixing some names
			if string.lower(fruit_name) == "magu" then
				fruit_name = "Magma"
			elseif string.lower(fruit_name) == "smouke" then
				fruit_name = "Smoke"
			elseif string.lower(fruit_name) == "quaketest" then
				fruit_name = "Quake"
			end

			fruit_name = fruit_name:gsub("%d+", '') -- Removes numbers from string
			
			-- Applied string formatting with fruitPrefix translation key
			fruit_name = string.format(t.fruitPrefix, fruit_name:gsub("^%l", string.upper))
			break
		end
	end

	playSound("rbxassetid://3997124966", 4)
	notifier.Visible = true
	local fruit_alive = true

	-- Keeps updating the distance if fruit is alive and switch is on
	while fruit_alive and workspace_connection do
		local distance = math.floor((local_player.Character:WaitForChild("UpperTorso").Position - fruit_child.Position).Magnitude * 0.15)
		
		-- Applied string formatting with fruitFound translation key
		notifier.Text = string.format(t.fruitFound, fruit_name, distance)

		task.wait(0.2)
		fruit_alive = workspace:FindFirstChild(fruit.Name)
	end

	if not fruit_alive then
		playSound("rbxassetid://4612375233", 1)
		showText(t.fruitDespawned, 3)
	end
end

local led = createLed()
local switch = createSwitch()

local function onSwitchClick()
	-- Enables/disables the workspace connection listening for children added 
	if workspace_connection then -- check if we are connected
		workspace_connection:Disconnect()
		workspace_connection = nil
		
		led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)

		switch.TextLabel.Text = t.notifierOff
		showText(t.notifierDisabled, 2)
	else -- if the connection does not exist
		led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		
		switch.TextLabel.Text = t.notifierOn
		showText(t.notifierEnabled, 2)

		-- Connect the event and start listening
		workspace_connection = workspace.ChildAdded:Connect(function(child)
			if child.Name == "Fruit " then
				task.spawn(enableNotifier, child)
			end
		end)

		-- Look for an already spawned fruit
		local fruit = workspace:FindFirstChild("Fruit ")

		if fruit then
			task.spawn(enableNotifier, fruit)
		end
	end
end

showText(t.scriptEnabled, 3)

-- Enables the notifier on startup by simulating a switch click
onSwitchClick()

-- Enables/disables the notifier when notifier switch is clicked
switch.Activated:Connect(onSwitchClick)
