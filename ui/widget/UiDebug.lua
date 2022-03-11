
-- header
local path = GetParentPath(...)
local parentPath = GetParentPath(path)
local DecoOutline = require(parentPath.."deco/DecoOutline")


local UiDebug = Class.inherit(Ui)
function UiDebug:new(watchedElement, color)
	Ui.new(self)

	self._debugName = "UiDebug"
	self.translucent = true
	self.watchedElement = watchedElement
	self.decoText = DecoAlignedText(nil, deco.fonts.tooltipTitleLarge, deco.textset(color))

	self:decorate{
		DecoOutline(color, 4),
		DecoAlign(0, -30),
		self.decoText,
	}
end

function UiDebug:relayout()
	local root = self.root
	local watchedElement = root[self.watchedElement]

	self.visible = watchedElement ~= nil

	if not self.visible then
		return
	end

	local debugName = watchedElement._debugName or "Missing debugName"

	if type(debugName) ~= 'string' then
		debugName = "Malformed debugName"
	end

	self.decoText:setsurface(debugName)

	self.screenx = watchedElement.screenx
	self.screeny = watchedElement.screeny
	self.w = watchedElement.w
	self.h = watchedElement.h

	Ui.relayout(self)
end

modApi.events.onUiRootCreated:subscribe(function(screen, uiRoot)
	uiRoot.priorityUi:add(UiDebug("hoveredchild", sdl.rgb(255, 100, 100)))
end)

modApi.events.onUiRootCreated:subscribe(function(screen, uiRoot)
	uiRoot.priorityUi:add(UiDebug("draghoveredchild", sdl.rgb(100, 255, 100)))
end)


-- Add debug names for all derivatives of class Ui
for name, class in pairs(_G) do
	if type(class) == 'table' then
		if Class.isSubclassOf(class, Ui) then
			class.__index._debugName = name
		end
	end
end