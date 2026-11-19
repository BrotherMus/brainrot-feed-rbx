-- The Index: every brainrot in the catalog, a 3D portrait once found and a black silhouette until then.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.BrainrotCatalog)

local models = ReplicatedStorage.Brainrots
local cells = {} -- [brainrot id] = its cell in the grid

local IndexPanel = {}

local function buildPortrait(view: ViewportFrame, id: string)
	local model = models[id]:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = view
	local size = model:GetExtentsSize()
	local focus = Vector3.new(0, size.Y * 0.5, 0)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0.45, 0.25, -1.1) * size.Magnitude, focus)
	camera.Parent = view
	view.CurrentCamera = camera
end

-- Fills the grid with one cell for each of the catalog's brainrots, in ladder order.
function IndexPanel.buildGrid(panel: Frame)
	for _, entry in Catalog.list do
		local cell = panel.CellTemplate:Clone()
		cell.Name = entry.id
		cell.LayoutOrder = entry.order
		cell.RarityText.Text = entry.rarity.name:upper()
		cell.RarityText.TextColor3 = entry.rarity.color
		cell.UIStroke.Color = entry.rarity.color
		cell.Visible = true
		buildPortrait(cell.View, entry.id)
		cell.Parent = panel.Grid
		cells[entry.id] = cell
	end
end

-- Reveals the cells of the brainrots found so far (foundList is the player's Index attribute).
function IndexPanel.showFound(panel: Frame, foundList: string)
	local found = {}
	local count = 0
	for id in string.gmatch(foundList, "[^,]+") do
		found[id] = true
		count += 1
	end
	for id, cell in cells do
		cell.NameText.Text = found[id] and Catalog.byId[id].name or "???"
		cell.View.ImageColor3 = found[id] and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	end
	panel.Title.Text = `📖 INDEX {count}/{#Catalog.list}  (+{count}% money)`
end

return IndexPanel
