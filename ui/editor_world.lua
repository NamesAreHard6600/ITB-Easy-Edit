
-- header
local path = GetParentPath(...)
local helpers = require(path.."helpers")
local decorate = require(path.."helper_decorate")
local dragEntry = require(path.."helper_dragEntry")
local tooltip = require(path.."helper_tooltip")
local tooltip_islandComposite = require(path.."helper_tooltip_islandComposite")
local DecoIcon = require(path.."deco/DecoIcon")
local UiDragSource = require(path.."widget/UiDragSource")
local UiDragObject_Island = require(path.."widget/UiDragObject_Island")
local UiDropTarget = require(path.."widget/UiDropTarget")
local UiScrollAreaExt = require(path.."widget/UiScrollAreaExt")
local UiScrollArea = UiScrollAreaExt.vertical
local UiScrollAreaH = UiScrollAreaExt.horizontal

local createUiTitle = helpers.createUiTitle

-- defs
local EDITOR_TITLE = "World Editor"
local PADDING = 8
local SCROLLBAR_WIDTH = 16
local ORIENTATION_VERTICAL = helpers.ORIENTATION_VERTICAL
local ORIENTATION_HORIZONTAL = helpers.ORIENTATION_HORIZONTAL
local DRAG_TARGET_TYPE = modApi.islandComposite:getDragType()
local TOOLTIP_ISLAND_COMPOSITE = tooltip_islandComposite
local DEFAULT_ISLAND_SLOTS = { "archive", "rst", "pinnacle", "detritus" }
local ISLAND_ICON_DEF_OUTLINED = copy_table(modApi.island:getIconDef())
ISLAND_ICON_DEF_OUTLINED.outlinesize = 2

-- ui
local islandSlots
local worldEditor = {}
local dragObject = UiDragObject_Island(DRAG_TARGET_TYPE)

local function resetAll()
	for i = 1, 4 do
		local islandComposite = modApi.islandComposite:get(DEFAULT_ISLAND_SLOTS[i])
		local island = modApi.island:get(islandComposite.island)
		local islandInSlot = islandSlots[i]

		islandInSlot
			:setVar("data", islandComposite)
			:decorate{
				DecoIcon(island, ISLAND_ICON_DEF_OUTLINED)
			}
	end
end

local function buildFrameContent(parentUi)
	local root = sdlext:getUiRoot()
	local islandComposites = UiBoxLayout()

	islandSlots = {
		UiDropTarget(DRAG_TARGET_TYPE),
		UiDropTarget(DRAG_TARGET_TYPE),
		UiDropTarget(DRAG_TARGET_TYPE),
		UiDropTarget(DRAG_TARGET_TYPE),
	}

	local content = UiWeightLayout()
		:hgap(0)
		:beginUi()
			:padding(PADDING)
			:beginUi(UiWeightLayout)
				:width(1)
				:vgap(8)
				:orientation(ORIENTATION_VERTICAL)
				:add(createUiTitle("World"))
				:beginUi()
					:decorate{
						DecoFrame(),
						DecoIcon("img/strategy/waterbg.png", { clip = true }),
					}
					:beginUi(islandSlots[1])
						:size(.5, .5)
						:anchor("left", "top")
					:endUi()
					:beginUi(islandSlots[2])
						:size(.5, .5)
						:anchor("left", "bottom")
					:endUi()
					:beginUi(islandSlots[3])
						:size(.5, .5)
						:anchor("right", "top")
					:endUi()
					:beginUi(islandSlots[4])
						:size(.5, .5)
						:anchor("right", "bottom")
					:endUi()
				:endUi()
			:endUi()
		:endUi()
		:beginUi()
			:widthpx(0
				+ ISLAND_ICON_DEF_OUTLINED.width * ISLAND_ICON_DEF_OUTLINED.scale
				+ 4 * PADDING + SCROLLBAR_WIDTH
			)
			:padding(PADDING)
			:beginUi(UiWeightLayout)
				:width(1)
				:vgap(8)
				:orientation(ORIENTATION_VERTICAL)
				:add(createUiTitle("Islands"))
				:beginUi(UiScrollArea)
					:decorate{ DecoFrame() }
					:beginUi(islandComposites)
						:padding(PADDING)
						:vgap(7)
					:endUi()
				:endUi()
			:endUi()
		:endUi()

	local cache_world = easyEdit.savedata.cache.world or DEFAULT_ISLAND_SLOTS

	for islandSlot, cache_data in ipairs(cache_world) do
		local islandComposite = modApi.islandComposite:get(cache_data)
		local island = modApi.island:get(islandComposite.island)
		local islandInSlot = islandSlots[islandSlot]

		islandInSlot
			:setVar("data", islandComposite)
			:setCustomTooltip(TOOLTIP_ISLAND_COMPOSITE)
			:decorate{
				DecoIcon(island, ISLAND_ICON_DEF_OUTLINED)
			}
	end

	for _, islandComposite in pairs(modApi.islandComposite._children) do
		local entry = UiDragSource(dragObject)

		entry
			:widthpx(ISLAND_ICON_DEF_OUTLINED.width * ISLAND_ICON_DEF_OUTLINED.scale)
			:heightpx(ISLAND_ICON_DEF_OUTLINED.height * ISLAND_ICON_DEF_OUTLINED.scale)
			:setVar("data", islandComposite)
			:setCustomTooltip(TOOLTIP_ISLAND_COMPOSITE)
			:addTo(islandComposites)

		decorate.button.islandComposite(entry, islandComposite)
	end

	return content
end

local function buildFrameButtons(buttonLayout)
	sdlext.buildButton(
		"Default",
		"Reset everything to default.",
		resetAll
 	):addTo(buttonLayout)
end

local function onExit()
	easyEdit.savedata.cache.world = {
		islandSlots[1].data._id,
		islandSlots[2].data._id,
		islandSlots[3].data._id,
		islandSlots[4].data._id,
	}

	easyEdit.savedata:save()

	-- This does more than necessary
	modApi.islandComposite:update()
end

function worldEditor.mainButton()
	sdlext.showDialog(function(ui, quit)
		ui.onDialogExit = onExit

		local frame = sdlext.buildButtonDialog(
			EDITOR_TITLE,
			buildFrameContent,
			buildFrameButtons
		)

		function frame:onGameWindowResized(screen, oldSize)
			local minW = 800
			local minH = 600
			local maxW = 1000
			local maxH = 800
			local width = math.min(maxW, math.max(minW, ScreenSizeX() - 200))
			local height = math.min(maxH, math.max(minH, ScreenSizeY() - 100))

			self
				:widthpx(width)
				:heightpx(height)
		end

		frame
			:addTo(ui)
			:anchor("center", "center")
			:onGameWindowResized()
	end)
end

return worldEditor