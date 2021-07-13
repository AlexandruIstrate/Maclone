--Project: Mac OS mockup
--File name: gui
--Description: Main file

--------------------------------------History--------------------------------------------------------
-------Date---------------------------Details--------------------------------------------------------
--	12.11.‎2016			Started
--	13.11.2016			Added desktop background and menu bar
--	15.11.2016			Added dock
--	20.11.2016			Added icons and click handling
--	30.11.2016			Added support for modular GUI by using files to specify elements for the menus, the dock, etc.
--	22.01.2017			Fixed an issue where clicking on the last pixel of a menu item would not register the menu item clicked
--	13.02.2017			Moved some functions to the window API
-----------------------------------------------------------------------------------------------------

os.loadAPI("macos/window")

local scriptsPath = "scripts/"
local itemsPath = "macos/items/"

--Menu bar
local menus = {}
local menuPositions = {}	--Do not initialize here
local menuItems = {}
local menuScripts = {}

local menuOpen = false

--Context menu
local contextMenuItems = {}--{{<display name>, <script name>}, {...}}

local contextMenuOpen = false

--Icons
local icons	= {}--{{<display name>, <icon name>, <script name>, {positionX, positionY}, {{<right click menu item name>, <right click menu script name>}, {...}}}, {...}}
local iconData = {}		--Do not initialize here

--Dock
local dockElements = {}	--{{<display name>, <image name>, <text colour>, <script name>}, {...}}

local dockMinimized = false

local dockTblStart
local dockTblEnd

--Item positions
local menuBarPositionX = 1
local menuBarPositionY = 1

local dockPositionX = 1
local dockPositionY = 19

local dockEndX = 0	--Initialized lower

function getFileData(path)
	if fs.exists(path) then
		file = fs.open(path, "r")
		local line = file.readAll()
		file.close()
		
		return line
	end
	
	return nil
end

function getFormattedFileData(path)
	return textutils.unserialize(getFileData(path))
end

local function launchProgram(path)
	shell.run(path)
	drawWorkspace()
end

function getRunningPath()
  local runningProgram = shell.getRunningProgram()
  local programName = fs.getName(runningProgram)
  return runningProgram:sub(1, #runningProgram - #programName)
end

local function getClick()
	return os.pullEvent("mouse_click")
end

local function resetScreen()
	term.clear()
	term.setCursorPos(1, 1)
	term.setTextColour(colours.white)
end

local function drawBackground()
	local image = paintutils.loadImage("macos/images/bkg")
	paintutils.drawImage(image, 1, 2)
	
	if dockMinimized then
		drawMinimizedDockSegment()
	end
end

local function addDockItem(image, text, textColour, positionX, positionY)
	paintutils.drawPixel(positionX, positionY, colours.lightGrey)
	
	if not image == "" then
		local image = paintutils.loadImage(image)
		paintutils.drawImage(image, positionX, positionY)
	end
	
	term.setCursorPos(positionX, positionY)
	term.setTextColour(textColour)
	term.write(text)
end

local function drawDockElements(elements, tblStart, tblEnd, startX)
	local elementNumber = #elements
	if tblStart > elementNumber or tblEnd > elementNumber or (tblEnd - tblStart) < 0 then
		dockTblStart = 1
		tblStart = dockTblStart
		
		dockTblEnd = elementNumber
		tblEnd = dockTblEnd
	end
	
	if tblEnd > elementNumber then
		dockTblEnd = elementNumber
		tblEnd = dockTblEnd
	end

	local position = 1
	for i = tblStart, tblEnd do
		addDockItem(elements[i][2], elements[i][1], elements[i][3], startX + position, dockPositionY)
		position = position + 1
	end
end

local function drawDock(positionY, forcedRedraw)
	if not dockMinimized or forcedRedraw then
		term.setTextColour(colours.white)
		term.setCursorPos(1, positionY)
	
		--Menu begining segment
		local beginingSegmentPosition = 1
		addDockItem("", "=", colours.grey, beginingSegmentPosition, positionY)
	
		--Left arrow button
		local leftArrowPosition = beginingSegmentPosition + 1
		addDockItem("", "<", colours.white, leftArrowPosition, positionY)
	
		--Dock elements
		drawDockElements(dockElements, dockTblStart, dockTblEnd, leftArrowPosition)
	
		--Right arrow button
		local rightArrowPosition = leftArrowPosition + dockTblEnd - dockTblStart + 2
		addDockItem("", ">", colours.white, rightArrowPosition, positionY)
	
		--Menu ending segment
		local endingSegmentPosition = rightArrowPosition + 1
		addDockItem("", "D", colours.white, endingSegmentPosition, positionY)
	
		dockEndX = endingSegmentPosition
	elseif dockMinimized then
		drawMinimizedDockSegment()
	end
end

local function getLongestItem(tbl)
	local longest = 0
	for i = 1, #tbl do
		local currentElementSize = string.len(tbl[i])
		if currentElementSize > longest then
			longest = currentElementSize
		end
	end
	
	return longest
end

local function getLongestItemInMap(map, position)
	local longest = 0

	for i = 1, #map do
		local current = string.len(map[i][position])
		
		if current > longest then
			longest = current
		end
	end
	
	return longest
end

local function drawContextMenu(positionX, positionY, elements)
	if positionY > 1 then
		local sizeX = getLongestItemInMap(elements, 1) + 1
		local spaceX = 51 - positionX
		if spaceX < sizeX then
			positionX = 51 - sizeX
		end
	
		local sizeY = #elements
		local spaceY = 19 - positionY
		if spaceY < sizeY then
			positionY = 20 - sizeY
		end
	
		paintutils.drawFilledBox(positionX, positionY, positionX + sizeX, positionY + sizeY - 1, colours.lightGrey)
	
		term.setTextColour(colours.white)
		for i = 1, #elements do
			term.setCursorPos(positionX + 1, positionY + i - 1)
			term.write(elements[i][1])
		end
	
		contextMenuOpen = true
	
		local newPos = {}
		newPos["x"] = positionX
		newPos["y"] = positionY
	
		return newPos
	end
	
	return nil
end

local function closeContextMenu()
	if contextMenuOpen then
		drawBackground()
		drawMenuBar()
		drawDock(dockPositionY, false)
		drawIcons()
		
		contextMenuOpen = false
	end
end

local function handleContextMenuClick(positionX, positionY, elements, defaultContextMenuItems, iconMenu)
	local eventType, button, x, y = getClick()
	
	if button == 1 then
		local longest = getLongestItemInMap(elements, 1)
		
		if x <= positionX + longest and x >= positionX and y <= positionY + #elements and y >= positionY then
			local itemIndex = y - positionY
			colouredWriteSpecific(positionX, positionY + itemIndex, positionX + longest + 1, colours.blue, colours.white, " " .. elements[itemIndex + 1][1])
			os.sleep(0.2)
			
			--Run context menu item
			launchProgram(scriptsPath .. "contextmenu/" .. elements[itemIndex + 1][2])	--Discrepancy between the number of items in contextMenuScripts and actual number of items causes an error
		end
		
		closeContextMenu()
	elseif button == 2 then
		closeContextMenu()
		
		if y > 1 and not handleIconClick(button, x, y) then
			if not iconMenu then
				pos = drawContextMenu(x, y, elements)
				handleContextMenuClick(pos["x"], pos["y"], elements)
			else
				pos = drawContextMenu(x, y, defaultContextMenuItems)
				handleContextMenuClick(pos["x"], pos["y"], defaultContextMenuItems)
			end
		end
	end
end

local function openContextMenu(positionX, positionY, elements, defaultContextMenuItems, iconMenu)
	pos = drawContextMenu(positionX, positionY, elements)
	handleContextMenuClick(pos["x"], pos["y"], elements, defaultContextMenuItems, iconMenu)
end

local function drawDropDownMenu(elements, positionX)
	window.drawDropDownMenu(elements, positionX)
	menuOpen = true
end

local function drawTime()
	paintutils.drawLine(43, menuBarPositionY, 50, menuBarPositionY, colours.lightGrey)

	term.setCursorPos(43, menuBarPositionY)
	term.setBackgroundColour(colours.lightGrey)
	term.setTextColour(colours.white)
	local time = os.time()
	term.write(textutils.formatTime(time, false))
end

function drawMenuBar()
	paintutils.drawLine(menuBarPositionX, menuBarPositionY, 51, 1, colours.lightGrey)
	
	--Menus
	menuPositions = window.addMenus(menus, 2)
	
	--Time
	drawTime()
end

local function colouredWriteAuto(positionX, positionY, backgroundColour, textColour, text)
	previous = term.getBackgroundColour()

	term.setBackgroundColour(backgroundColour)
	term.setCursorPos(positionX, positionY)
	term.setTextColour(textColour)
	term.write(text)
	
	term.setBackgroundColour(previous)
end

function colouredWriteSpecific(positionX, positionY, endX, backgroundColour, textColour, text)	--Lets you specify the length of x
	previous = term.getBackgroundColour()
	
	paintutils.drawLine(positionX, positionY, endX, positionY, backgroundColour)
	term.setCursorPos(positionX, positionY)
	term.setTextColour(textColour)
	term.write(text)
	
	term.setBackgroundColour(previous)
end

local function getImageMaxWidth(image)
	local biggestSize = 0
	for i = 1, #image do
		for m = 1, #image[i] do
			local stringSize = string.len(image[i][m])
			if stringSize > biggestSize then
				biggestSize = stringSize
			end
		end
	end
	
	return biggestSize
end

local function getImageMaxHeight(image)
	return #image
end

local function drawIcon(image, text, positionX, positionY)
	image = paintutils.loadImage(image)
	paintutils.drawImage(image, positionX, positionY)
	
	local textStartX = math.ceil((positionX - getImageMaxWidth(image) / 2) - string.len(text) / 2) + 3
	local textStartY = positionY + getImageMaxHeight(image)
	local textEndX = positionX + string.len(text) - 4
	paintutils.drawLine(textStartX, textStartY, textEndX, textStartY, colours.white)
	
	term.setCursorPos(textStartX, textStartY)
	term.setTextColour(colours.black)
	term.write(text)
	
	local ext = {{textStartX, positionY}, {textEndX, textStartY}}
	return ext
end

function drawIcons()
	for i = 1, #icons do
		iconData[i] = drawIcon("macos/icons/" .. icons[i][2], icons[i][1], icons[i][4][1], icons[i][4][2])
	end
end

local function openMenu(x)
	for i = 1, #menus do
		local menuPos = menuPositions[i]
		local element = menus[i]
		
		if x >= menuPos and x <= menuPos + string.len(element) - 1 then
			colouredWriteAuto(menuPos, menuBarPositionY, colours.blue, colours.white, element)
					
			local elements = menuItems[i]
			drawDropDownMenu(elements, menuPos)
			handleMenuItemClick(i, elements)
			
			break
		end
	end
end

local function closeMenu()
	if menuOpen then
		drawBackground()
		drawMenuBar()
		drawDock(dockPositionY, false)
		drawIcons()
		
		menuOpen = false
	end
end

function handleMenuItemClick(menuIndex, elements)
	local menuPositionX = menuPositions[menuIndex]
	local eventType, button, x, y = getClick()
	
	if button == 1 then
		if y <= menuBarPositionY + #elements and y > menuBarPositionY and x >= menuPositionX and x <= menuPositionX + getLongestItem(elements) + 1 then
			local itemIndex = y - 1
			colouredWriteSpecific(menuPositionX, y, menuPositionX + getLongestItem(elements) + 1, colours.blue, colours.white, " " .. elements[itemIndex])
			os.sleep(0.2)
			closeMenu()
			
			--Run menu item script
			launchProgram(scriptsPath .. "menus/" .. menuScripts[menuIndex][itemIndex])
		elseif y == 1 then
			closeMenu()
			openMenu(x)		
		else	
			closeMenu()
		end
	end
end

function handleIconClick(clickType, positionX, positionY)
	for i = 1, #iconData do
		if positionX >= iconData[i][1][1] and positionX <= iconData[i][2][1] and positionY >= iconData[i][1][2] and positionY <= iconData[i][2][2] then	
			if clickType == 1 then	--Clicked on the icon
				-- print(icons[i][3])
				-- print(scriptsPath .. icons[i][3])
				launchProgram(scriptsPath .. icons[i][3])
			elseif clickType == 2 then --Right clicked on the icon
				openContextMenu(positionX, positionY, icons[i][5], contextMenuItems, true)
			end
			
			return true
		end
	end
	
	return false
end

local function exitEditMode()
	drawBackground()
	drawDock(dockPositionY, false)
	drawIcons()
end

local function drawDeleteButtons(positionX, elementNumber)
	term.setTextColour(colours.black)
	for i = 1, elementNumber do
		local positionX = 2 + i
		paintutils.drawPixel(positionX, dockPositionY, colours.red)
		term.setCursorPos(positionX, dockPositionY)
		term.write("x")
	end
end

local function handleDeleteClick()
	local eventType, button, x, y = getClick()

	if y == dockPositionY and x > 2 and x < dockEndX - 1 then
		table.remove(dockElements, x - 2)
	else
		exitEditMode()
	end
end

local function handleDockClick(positionX, positionY)
	if positionX > 2 and positionX < dockEndX - 1 then	--Clicked on a dock element
		launchProgram(scriptsPath .. "dock/" .. dockElements[positionX - 2][4])
	elseif positionX == 1 then	--Clicked on the begining segment
		local elementNumber = dockTblEnd - dockTblStart + 1
		if elementNumber > 0 then
			drawDeleteButtons(x, elementNumber)

			handleDeleteClick()
			exitEditMode()
			term.setCursorPos(1, 1)
		end
	elseif positionX == 2 then	--Clicked on the left arrow
		if dockTblStart > 1 then
			dockTblStart = dockTblStart - 1
			dockTblEnd = dockTblEnd - 1
			
			drawDock(dockPositionY, false)
		end
	elseif positionX == dockEndX - 1 then	--Clicked on the right arrow
		if dockTblEnd < #dockElements then
			dockTblStart = dockTblStart + 1
			dockTblEnd = dockTblEnd + 1
			
			drawDock(dockPositionY, false)
		end
	elseif positionX == dockEndX then	--Clicked on the ending segment
		minimizeDock()
	end
end

function drawMinimizedDockSegment()
	addDockItem("", "D", colours.white, dockPositionX, dockPositionY)
	dockMinimized = true
end

function minimizeDock()
	drawBackground()
	drawMenuBar()
	drawIcons()
	
	drawMinimizedDockSegment()
	
	dockMinimized = true
end

function maximizeDock()
	drawDock(dockPositionY, true)
	dockMinimized = false
end

local function handleClick()
	local eventType, button, x, y = getClick()
	
	if button == 1 then
		if y == menuBarPositionY then	--Clicked on the menu bar
			openMenu(x)
		elseif y == dockPositionY and x <= dockEndX then	--Clicked on the dock
			if not dockMinimized then
				handleDockClick(x, y)
			elseif dockMinimized and x == 1 then
				maximizeDock()
			end
		else	--Clicked on the desktop
			handleIconClick(1, x, y)
		end
	elseif button == 2 then
		if y > 1 then	--Right clicked on the desktop
			if not handleIconClick(2, x, y) then
				openContextMenu(x, y, contextMenuItems, contextMenuItems, false)
			end
		end
	end
	
	closeMenu()
	drawTime()
	handleClick()
end

function drawWorkspace()
	resetScreen()
	drawBackground()
	drawMenuBar()
	drawDock(19)
	drawIcons()
end

function main()
	--Get data for GUI items from files

	--Menus
	menus = getFormattedFileData(itemsPath .. "menus")
	menuItems = getFormattedFileData(itemsPath .. "menu_items")
	menuScripts = getFormattedFileData(itemsPath .. "menu_scripts")

	--Context menu
	contextMenuItems = getFormattedFileData(itemsPath .. "context_menu")

	--Icons
	icons = getFormattedFileData(itemsPath .. "icons")

	--Dock
	dockElements = {{"a", "", colours.red, "dock1"}, {"b", "", colours.yellow, "dock2"}, {"c", "", colours.purple, "dock3"}, {"d", "", colours.grey, "dock4"}, {"e", "", colours.blue, "dock5"}, {"f", "", colours.black, "dock6"}, {"g", "", colours.brown, "dock7"}, {"h", "", colours.white, "dock8"}, {"i", "", colours.orange, "dock9"}, {"j", "", colours.magenta, "dock10"}}
	--dockElements = getFormattedFileData(itemsPath .. "dock")
	
	dockTblStart = 1
	dockTblEnd = dockTblStart + 12

	drawWorkspace()
	handleClick()
end

main()
