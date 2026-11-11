-- ============================================================================
-- HARPOON PICKER
-- ============================================================================
-- WebView lifecycle and the Lua side of the picker.html message bridge.
-- ============================================================================

local core = require("harpoon.core")

local M = {}

local pickerConfig = {
	width = 540,
	rowHeight = 60,
	baseHeight = 125,
	maxHeight = 480,
	screenY = 0.20,
}

local picker = nil

local pickerController = hs.webview.usercontent.new("harpoon")

function M.close()
	if picker then
		picker:hide()
	end
end

pickerController:setCallback(function(message)
	local data = message.body

	if type(data) ~= "table" then
		return
	end

	if data.action == "close" then
		M.close()
		return
	end

	if data.action == "select" then
		M.close()

		local slotKey = tostring(data.slot or "")
		local slotNumber = tonumber(slotKey)

		if not slotNumber then
			return
		end
		if slotNumber < 1 then
			return
		end
		if slotNumber > core.maxSlots then
			return
		end
		if slotNumber % 1 ~= 0 then
			return
		end

		core.focusSlot(slotKey)
	end
end)

function M.toggle()
	-- Toggle existing visible picker
	if picker and picker:isVisible() then
		M.close()
		return
	end

	local choices = core.getChoices()

	if #choices == 0 then
		core.showToast("⚠️ Harpoon list is empty")
		return
	end

	-- Ensure HTML exists
	local path = hs.configdir .. "/harpoon/picker.html"

	local file = io.open(path, "r")

	if not file then
		core.showToast("⚠️ Picker HTML file not found:\n" .. path, 3)
		return
	end

	local html = file:read("*a")
	file:close()

	-- Calculate frame
	local screen = hs.screen.mainScreen():frame()

	local width = pickerConfig.width

	local height = math.min(pickerConfig.maxHeight, pickerConfig.baseHeight + #choices * pickerConfig.rowHeight)

	local frame = {
		x = screen.x + (screen.w - width) / 2,
		y = screen.y + screen.h * pickerConfig.screenY,
		w = width,
		h = height,
	}

	-- Recreate so latest HTML/CSS is loaded
	if picker then
		picker:delete()
		picker = nil
	end

	picker = hs.webview.new(frame, {
		javaScriptEnabled = true,
		privateBrowsing = true,
	}, pickerController)

	-- Borderless window, transparent background
	picker:windowStyle({})
	picker:transparent(true)
	picker:allowTextEntry(true)

	-- CSS handles the visual shadow
	picker:shadow(false)

	picker:level(hs.drawing.windowLevels.floating)

	picker:behaviorAsLabels({
		"canJoinAllSpaces",
		"stationary",
	})

	-- Close if user switches away
	picker:windowCallback(function(action, view, state)
		if action == "focusChange" and state == false then
			view:hide()
		end
	end)

	-- Populate after HTML finishes loading
	picker:navigationCallback(function(action, view)
		if action == "didFinishNavigation" then
			local json = hs.json.encode(choices)

			view:evaluateJavaScript("setWindows(" .. json .. ");")
		end
	end)

	picker:html(html)
	picker:show()
	picker:bringToFront()
end

return M
