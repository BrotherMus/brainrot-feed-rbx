-- BrainrotBuilder: turns one BrainrotCatalog entry into a Model made only of Roblox parts:
-- a body plan, googly eyes, the species traits, the phone-world prop it carries, the look
-- of its mutation, and the floating name tag (name, rarity, price, money per second).
local BrainrotCatalog = require(script.Parent.BrainrotCatalog)
local GameConfig = require(script.Parent.GameConfig)

local BrainrotBuilder = {}

local V, CF = Vector3.new, CFrame.new
local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder (whose axis is X) upright
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.fromRGB(17, 24, 39)
local ORANGE, GOLD = Color3.fromRGB(245, 158, 11), Color3.fromRGB(250, 204, 21)

type Ctx = { model: Model, root: BasePart, s: number, main: Color3, accent: Color3, seed: number }
type Anchors = { body: CFrame, bodySize: Vector3, head: CFrame, headSize: Vector3, back: CFrame, rear: CFrame }

-- One welded, massless, non-colliding part. `offset` is in model space before scaling.
local function addPart(ctx: Ctx, name: string, shape: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part: BasePart = if shape == "wedge" then Instance.new("WedgePart") else Instance.new("Part")
	if shape == "cyl" then
		(part :: Part).Shape = Enum.PartType.Cylinder
	elseif shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Name = name
	part.Size = size * ctx.s
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = ctx.root.CFrame * CF(offset.Position * ctx.s) * offset.Rotation
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = ctx.model
	return part
end

-- A board with big text on its front face: hashtags, LIVE, pop-up ads, error codes.
local function addSign(ctx: Ctx, offset: CFrame, size: Vector3, text: string, color: Color3): BasePart
	local board = addPart(ctx, "Sign", "block", size, offset, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.86)
	label.Position = UDim2.fromScale(0.05, 0.07)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = WHITE
	label.Parent = gui
	return board
end

-- The five body plans. Each returns where the head, back and rear are so traits can attach.
local function buildBody(ctx: Ctx, kind: string, t: { [string]: string }): Anchors
	local m, a = ctx.main, ctx.accent
	local neck = tonumber(t.neck) or 0
	local lift = if t.legs == "long" then 1.8 else 0
	local an = {} :: Anchors
	local separateHead = true
	if kind == "quad" then
		an.body, an.bodySize = CF(0, 2.5, 0.3), V(3, 2.6, 4.4)
		for _, x in { -0.95, 0.95 } do
			for _, z in { -1.1, 1.7 } do
				addPart(ctx, "Leg", "cyl", V(1.7, 0.85, 0.85), CF(x, 0.85, z) * UP, a)
			end
		end
		an.head, an.headSize = CF(0, 3.5 + neck, -2.2), V(2.4, 2.2, 2.4)
		an.back, an.rear = CF(0, 3.8, 0.9), CF(0, 2.8, 2.4)
	elseif kind == "biped" then
		an.body, an.bodySize = CF(0, 2.9, 0), V(2.8, 3.2, 2.4)
		for _, x in { -0.7, 0.7 } do
			addPart(ctx, "Leg", "cyl", V(1.5, 0.85, 0.85), CF(x, 0.75, 0) * UP, a)
			addPart(ctx, "Arm", "ball", V(0.8, 1.9, 0.8), CF(x * 2.4, 3.1, -0.2) * CFrame.Angles(0, 0, math.rad(x * 30)), m)
		end
		an.head, an.headSize = CF(0, 5.3 + neck, -0.2), V(2.6, 2.3, 2.4)
		an.back, an.rear = CF(0, 5.2, 1.6), CF(0, 1.9, 1.2)
	elseif kind == "blob" then
		separateHead = false
		an.body, an.bodySize = CF(0, 2.2, 0), V(4, 3.6, 3.8)
		for _, x in { -1, 1 } do
			addPart(ctx, "Foot", "ball", V(1.3, 0.8, 1.7), CF(x, 0.4, -0.5), a)
		end
		an.head, an.headSize = CF(0, 2.5, -0.2), V(3.6, 3.2, 3.6)
		an.back, an.rear = CF(0, 3.7, 0.9), CF(0, 1.8, 1.9)
	elseif kind == "fish" then
		separateHead = false
		an.body, an.bodySize = CF(0, 2, 0), V(2.4, 2.8, 5.2)
		addPart(ctx, "Dorsal", "wedge", V(0.3, 1.3, 1.7), CF(0, 3.8, 0.5), a)
		addPart(ctx, "TailFin", "ball", V(0.35, 2.8, 1.5), CF(0, 2.1, 3.1), a)
		for _, x in { -1, 1 } do
			addPart(ctx, "Fin", "ball", V(1.5, 0.3, 1), CF(x * 1.5, 1.3, -0.3) * CFrame.Angles(0, 0, math.rad(x * -25)), a)
		end
		an.head, an.headSize = CF(0, 2.2, -1.5), V(2.2, 2.4, 2.4)
		an.back, an.rear = CF(0, 3.5, 0.6), CF(0, 2, 2.6)
	elseif kind == "bird" then
		an.body, an.bodySize = CF(0, 3.2 + lift, 0.2), V(2.8, 3, 3.2)
		for _, x in { -0.6, 0.6 } do
			addPart(ctx, "Leg", "cyl", V(1.9 + lift, 0.3, 0.3), CF(x, (1.9 + lift) / 2, 0.2) * UP, ORANGE)
			addPart(ctx, "Foot", "block", V(0.9, 0.2, 1.3), CF(x, 0.1, -0.2), ORANGE)
			addPart(ctx, "Wing", "ball", V(0.5, 1.9, 2.5), CF(x * 2.5, 3.3 + lift, 0.3), a)
		end
		an.head, an.headSize = CF(0, 5 + lift + neck, -0.8), V(2, 2, 2)
		an.back, an.rear = CF(0, 4.8 + lift, 1.1), CF(0, 3 + lift, 1.8)
	else -- slug
		an.body, an.bodySize = CF(0, 0.9, 0.5), V(2.2, 1.8, 5.4)
		addPart(ctx, "Neck", "ball", V(1.6, 2.4, 1.6), CF(0, 1.5, -1.7), m)
		an.head, an.headSize = CF(0, 2.6, -1.9), V(2, 1.9, 2)
		an.back, an.rear = CF(0, 1.8, 1.1), CF(0, 0.8, 3.1)
	end
	addPart(ctx, "Body", "ball", an.bodySize, an.body, m)
	if neck > 0 then
		addPart(ctx, "Neck", "cyl", V(neck + 1.6, 1, 1), an.head * CF(0, -(neck + 1.6) / 2, 0.3) * UP, m)
	end
	if separateHead then
		addPart(ctx, "Head", "ball", an.headSize, an.head, m)
	end
	return an
end

-- Two big googly eyes whose pupils wander: every brainrot stares in its own two directions.
local function addGooglyEyes(ctx: Ctx, an: Anchors, t: { [string]: string })
	local hs = an.headSize
	for index, side in { -1, 1 } do
		local d = if t.stalks then 0.95 else hs.X * 0.38
		local eye = an.head * CF(side * hs.X * 0.25, hs.Y * 0.14, -hs.Z * 0.42)
		if t.stalks then
			eye = an.head * CF(side * 0.6, hs.Y / 2 + 1.1, -0.2)
			addPart(ctx, "EyeStalk", "cyl", V(1.4, 0.24, 0.24), an.head * CF(side * 0.6, hs.Y / 2 + 0.4, -0.2) * UP, ctx.main)
		end
		addPart(ctx, "Eye", "ball", V(d, d, d), eye, WHITE)
		local wanderX = ((ctx.seed + index * 3) % 5 - 2) * 0.07 * d
		local wanderY = ((ctx.seed + index) % 3 - 1) * 0.08 * d
		addPart(ctx, "Pupil", "ball", V(d * 0.48, d * 0.48, d * 0.3), eye * CF(wanderX, wanderY, -d * 0.4), BLACK)
	end
end

-- Ears, snouts, tails, horns and the rest: what makes a capybara differ from a narwhal.
local function addSpeciesTraits(ctx: Ctx, an: Anchors, t: { [string]: string })
	local m, a = ctx.main, ctx.accent
	local head, hs, rear = an.head, an.headSize, an.rear
	local pale = m:Lerp(WHITE, 0.55)
	for _, side in { -1, 1 } do
		if t.ears == "round" then
			addPart(ctx, "Ear", "ball", V(1, 1, 0.5), head * CF(side * hs.X * 0.42, hs.Y * 0.45, 0.1), a)
		elseif t.ears == "pointy" then
			addPart(ctx, "Ear", "ball", V(0.7, 1.5, 0.5), head * CF(side * hs.X * 0.36, hs.Y * 0.55, 0.1) * CFrame.Angles(0, 0, math.rad(side * -18)), m)
		elseif t.ears == "droopy" then
			addPart(ctx, "Ear", "ball", V(0.6, 1.8, 1), head * CF(side * hs.X * 0.55, -0.2, 0.1), a)
		elseif t.ears == "long" then
			addPart(ctx, "Ear", "ball", V(0.65, 2.6, 0.5), head * CF(side * hs.X * 0.25, hs.Y * 0.5 + 1, 0.1), m)
		end
		if t.horn == "two" then
			addPart(ctx, "Horn", "ball", V(0.4, 1.2, 0.4), head * CF(side * 0.45, hs.Y * 0.5 + 0.4, -0.1), a)
		elseif t.horn == "antlers" then
			local tilt = CFrame.Angles(0, 0, math.rad(side * -28))
			addPart(ctx, "Antler", "ball", V(0.35, 2.2, 0.35), head * CF(side * 0.7, hs.Y * 0.5 + 0.8, 0) * tilt, pale)
			addPart(ctx, "Antler", "ball", V(1.1, 0.3, 0.3), head * CF(side * 1.3, hs.Y * 0.5 + 1.2, 0), pale)
		elseif t.horn == "tusks" then
			addPart(ctx, "Tusk", "ball", V(0.35, 1.5, 0.35), head * CF(side * 0.55, -hs.Y * 0.45, -hs.Z * 0.42) * CFrame.Angles(math.rad(-20), 0, 0), WHITE)
		end
		if t.whiskers then
			addPart(ctx, "Whisker", "cyl", V(1.6, 0.08, 0.08), head * CF(side * 1.2, -0.35, -hs.Z * 0.45) * CFrame.Angles(0, 0, math.rad(side * 12)), BLACK)
		end
		if t.claws then
			addPart(ctx, "Claw", "ball", V(1.5, 1.1, 1.9), an.body * CF(side * 2.6, -0.3, -1.3), m)
			addPart(ctx, "ClawTip", "wedge", V(0.4, 0.7, 1), an.body * CF(side * 2.6, 0.3, -2.3), a)
		end
		if t.wings then
			addPart(ctx, "BigWing", "ball", V(3.2, 0.3, 2.4), an.body * CF(side * 2.3, 0.5, 0.2) * CFrame.Angles(0, 0, math.rad(side * 22)), a)
		end
		if t.gills then
			for row = 0, 2 do
				addPart(ctx, "Gill", "ball", V(1.5, 0.35, 0.35), head * CF(side * (hs.X * 0.5 + 0.5), 0.6 - row * 0.5, 0.2) * CFrame.Angles(0, 0, math.rad(side * (30 - row * 30))), a)
			end
		end
	end
	if t.snout == "short" then
		addPart(ctx, "Snout", "ball", V(1.3, 0.9, 1), head * CF(0, -hs.Y * 0.18, -hs.Z * 0.45), pale)
		addPart(ctx, "Nose", "ball", V(0.45, 0.35, 0.3), head * CF(0, -hs.Y * 0.08, -hs.Z * 0.45 - 0.45), BLACK)
	elseif t.snout == "long" then
		addPart(ctx, "Snout", "ball", V(1.2, 1, 2.2), head * CF(0, -hs.Y * 0.18, -hs.Z * 0.5 - 0.4), pale)
		addPart(ctx, "Nose", "ball", V(0.5, 0.4, 0.35), head * CF(0, -hs.Y * 0.1, -hs.Z * 0.5 - 1.45), BLACK)
	elseif t.snout == "beak" then
		addPart(ctx, "Beak", "ball", V(0.8, 0.6, 1.8), head * CF(0, -hs.Y * 0.15, -hs.Z * 0.5 - 0.5), ORANGE)
	elseif t.snout == "trunk" then
		addPart(ctx, "Trunk", "ball", V(0.9, 0.9, 1.6), head * CF(0, -hs.Y * 0.2, -hs.Z * 0.5 - 0.4), m)
		addPart(ctx, "Trunk", "ball", V(0.75, 2, 0.75), head * CF(0, -hs.Y * 0.2 - 0.9, -hs.Z * 0.5 - 1), m)
	end
	if t.horn == "one" then
		addPart(ctx, "Horn", "ball", V(0.5, 2.2, 0.5), head * CF(0, hs.Y * 0.5 + 0.7, -0.5) * CFrame.Angles(math.rad(-25), 0, 0), a, Enum.Material.Neon)
	end
	if t.tail == "stub" then
		addPart(ctx, "Tail", "ball", V(0.9, 0.9, 0.9), rear, pale)
	elseif t.tail == "long" then
		addPart(ctx, "Tail", "ball", V(0.7, 0.7, 3.4), rear * CF(0, 0.5, 1.4) * CFrame.Angles(math.rad(25), 0, 0), m)
		addPart(ctx, "TailTip", "ball", V(0.9, 0.9, 0.9), rear * CF(0, 1.3, 2.9), a)
	elseif t.tail == "fan" then
		for blade = -2, 2 do
			addPart(ctx, "TailFan", "ball", V(1, 3.4, 0.3), rear * CFrame.Angles(math.rad(20), 0, math.rad(blade * 24)) * CF(0, 1.9, 0.3), if blade % 2 == 0 then a else m)
		end
	end
	if t.spikes then
		for row = 0, 4 do
			addPart(ctx, "Spike", "ball", V(0.45, 1.2, 0.7), an.body * CF(0, an.bodySize.Y * 0.5 - math.abs(row - 2) * 0.12, (row - 2) * an.bodySize.Z * 0.2), a)
		end
	end
	if t.stripes or t.spots then
		for row = -1, 1 do
			local scale = if t.stripes then V(1.03, 1.03, 0.09) else V(0.3, 0.3, 0.2)
			local fit = math.sqrt(1 - (row * 0.3 * 2) ^ 2) -- keeps a band on the ellipsoid's surface
			local size = if t.stripes then V(an.bodySize.X * fit, an.bodySize.Y * fit, an.bodySize.Z) * scale else an.bodySize * scale
			local at = if t.stripes then CF(0, 0, row * an.bodySize.Z * 0.3) else CF(row * 0.7, an.bodySize.Y * 0.46, row * 0.9 + 0.3)
			addPart(ctx, "Marking", "ball", size, an.body * at, BLACK)
		end
	end
	if t.fluff or t.mane then
		local color = if t.mane then a else WHITE
		for puff = 0, 3 do
			addPart(ctx, "Fluff", "ball", V(1.1, 1.1, 1.1), head * CF((puff % 2 - 0.5) * 0.7, hs.Y * 0.45 - puff * 0.5, 0.5 + puff * 0.25), color)
		end
	end
	if t.tentacles then
		for arm = 0, 7 do
			local around = CFrame.Angles(0, math.rad(arm * 45 + 22), 0)
			addPart(ctx, "Tentacle", "ball", V(0.8, 0.8, 2.6), around * CF(0, 0.5, -2.2), m)
			addPart(ctx, "Sucker", "ball", V(0.6, 0.6, 0.6), around * CF(0, 0.7, -3.4), a)
		end
	end
	if t.mask then
		addPart(ctx, "Mask", "ball", V(hs.X * 1.03, hs.Y * 0.42, hs.Z * 1.03), head * CF(0, hs.Y * 0.14, -0.04), BLACK)
	end
	if t.belly then
		local bs = an.bodySize
		addPart(ctx, "Belly", "ball", V(bs.X * 0.8, bs.Y * 0.78, bs.Z * 0.8), an.body * CF(0, -bs.Y * 0.1, -bs.Z * 0.12), pale)
	end
end

-- The object half of "absurd animal + object": every prop comes from a phone or a feed.
local function addPhoneWorldProp(ctx: Ctx, an: Anchors, prop: string)
	local a = ctx.accent
	local head, hs, back = an.head, an.headSize, an.back
	local top = head * CF(0, hs.Y * 0.5, 0)
	local kind, text = string.match(prop, "^(%a+):?(.*)$")
	if kind == "sign" then
		addPart(ctx, "Pole", "cyl", V(1.6, 0.25, 0.25), back * CF(0, 0.6, 0) * UP, BLACK)
		addSign(ctx, back * CF(0, 2.3, 0), V(4.2, 2.1, 0.3), text, a)
	elseif kind == "bubble" then
		addSign(ctx, top * CF(0.9, 1.3, 0), V(2.1, 1.5, 0.3), text, a)
		addPart(ctx, "BubbleTail", "ball", V(0.5, 0.5, 0.3), top * CF(0.2, 0.4, 0), a)
	elseif kind == "phone" then
		addPart(ctx, "Phone", "block", V(2.1, 3.6, 0.35), back * CF(0, 1.6, 0), BLACK)
		addPart(ctx, "PhoneScreen", "block", V(1.8, 3.1, 0.1), back * CF(0, 1.6, -0.18), a, Enum.Material.Neon)
	elseif kind == "heart" then
		for _, side in { -1, 1 } do
			addPart(ctx, "Heart", "ball", V(1.1, 1.1, 0.7), top * CF(side * 0.42, 1.5, 0), a, Enum.Material.Neon)
		end
		addPart(ctx, "Heart", "block", V(1, 1, 0.6), top * CF(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(45)), a, Enum.Material.Neon)
	elseif kind == "ring" then
		for dot = 0, 7 do -- the loading spinner: eight dots fading round a circle
			local spot = addPart(ctx, "SpinnerDot", "ball", V(0.55, 0.55, 0.3), top * CF(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(dot * 45)) * CF(0, 1.2, 0), a, Enum.Material.Neon)
			spot.Transparency = dot * 0.1
		end
	elseif kind == "bell" then
		addPart(ctx, "Bell", "ball", V(1.6, 1.5, 1.6), top * CF(0, 1.1, 0), GOLD)
		addPart(ctx, "BellRim", "cyl", V(0.25, 2, 2), top * CF(0, 0.5, 0) * UP, GOLD)
		addPart(ctx, "Badge", "ball", V(0.8, 0.8, 0.8), top * CF(0.75, 1.75, -0.2), Color3.fromRGB(239, 68, 68), Enum.Material.Neon)
	elseif kind == "wifi" then
		addPart(ctx, "WifiDot", "ball", V(0.5, 0.5, 0.4), top * CF(0, 0.5, 0), a, Enum.Material.Neon)
		for bar = 1, 3 do
			addPart(ctx, "WifiBar", "block", V(bar * 0.95, 0.32, 0.32), top * CF(0, 0.5 + bar * 0.6, 0), a, Enum.Material.Neon)
		end
	elseif kind == "bars" then
		for bar = 1, 4 do
			addPart(ctx, "SignalBar", "block", V(0.5, bar * 0.7, 0.4), back * CF((bar - 2.5) * 0.7, bar * 0.35 + 0.2, 0), a, Enum.Material.Neon)
		end
	elseif kind == "cable" then
		for link = 0, 5 do
			addPart(ctx, "Cable", "ball", V(0.5, 0.5, 0.9), an.rear * CF(0, math.sin(link * 0.9) * 0.9 + 0.3, 0.4 + link * 0.7), a, Enum.Material.Neon)
		end
		addPart(ctx, "Plug", "block", V(0.9, 0.7, 1.1), an.rear * CF(0, -0.3, 4.6), WHITE)
	elseif kind == "mic" then
		addPart(ctx, "MicHandle", "cyl", V(1.7, 0.4, 0.4), an.body * CF(1.9, 0.6, -1) * UP, BLACK)
		addPart(ctx, "MicHead", "ball", V(1, 1, 1), an.body * CF(1.9, 1.7, -1), Color3.fromRGB(148, 163, 184), Enum.Material.DiamondPlate)
	elseif kind == "shades" then
		for _, side in { -1, 1 } do
			addPart(ctx, "Lens", "block", V(hs.X * 0.44, hs.Y * 0.3, 0.2), head * CF(side * hs.X * 0.25, hs.Y * 0.14, -hs.Z * 0.42 - hs.X * 0.2), BLACK, Enum.Material.Glass)
		end
		addPart(ctx, "Bridge", "block", V(hs.X * 1.04, 0.14, 0.14), head * CF(0, hs.Y * 0.22, -hs.Z * 0.42 - hs.X * 0.2), BLACK)
	elseif kind == "envelope" then
		addPart(ctx, "Envelope", "block", V(2.8, 1.8, 0.3), back * CF(0, 1.1, 0), WHITE)
		for _, side in { -1, 1 } do
			addPart(ctx, "Flap", "block", V(1.6, 0.12, 0.1), back * CF(side * 0.68, 1.5, -0.17) * CFrame.Angles(0, 0, math.rad(side * -30)), Color3.fromRGB(239, 68, 68))
		end
	elseif kind == "cookie" then
		addPart(ctx, "Cookie", "cyl", V(0.4, 2.6, 2.6), back * CF(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0), a)
		for chip = 0, 4 do
			addPart(ctx, "Chip", "ball", V(0.4, 0.4, 0.3), back * CF(math.cos(chip * 1.3) * 0.7, 1.5 + math.sin(chip * 1.3) * 0.7, -0.22), Color3.fromRGB(69, 39, 20))
		end
	elseif kind == "headset" then
		addPart(ctx, "Headband", "block", V(hs.X * 1.1, 0.3, 0.6), top * CF(0, 0.1, 0), BLACK)
		for _, side in { -1, 1 } do
			addPart(ctx, "EarCup", "cyl", V(0.5, 1.3, 1.3), head * CF(side * hs.X * 0.55, 0, 0), a, Enum.Material.Neon)
		end
		addPart(ctx, "MicBoom", "cyl", V(1.4, 0.14, 0.14), head * CF(hs.X * 0.55, -0.5, -0.7) * CFrame.Angles(0, math.rad(90), 0), BLACK)
	elseif kind == "camera" then
		addPart(ctx, "Camera", "block", V(2, 1.4, 1.1), top * CF(0, 0.75, 0), BLACK)
		addPart(ctx, "Lens", "cyl", V(0.5, 1, 1), top * CF(0, 0.75, -0.7) * CFrame.Angles(0, math.rad(90), 0), a)
		addPart(ctx, "RecLight", "ball", V(0.35, 0.35, 0.35), top * CF(0.7, 1.25, -0.5), Color3.fromRGB(239, 68, 68), Enum.Material.Neon)
	elseif kind == "crown" then
		addPart(ctx, "Crown", "cyl", V(0.7, 2, 2), top * CF(0, 0.3, 0) * UP, GOLD, Enum.Material.Metal)
		for point = 0, 4 do
			addPart(ctx, "CrownPoint", "ball", V(0.5, 1.1, 0.5), top * CFrame.Angles(0, math.rad(point * 72), 0) * CF(0, 0.9, -0.8), if point == 0 then a else GOLD, Enum.Material.Neon)
		end
	elseif kind == "cloud" then
		for puff = -1, 1 do
			addPart(ctx, "Cloud", "ball", V(1.9 - math.abs(puff) * 0.4, 1.5 - math.abs(puff) * 0.3, 1.5), top * CF(puff * 1.1, 1.6, 0), WHITE)
		end
		addPart(ctx, "UploadArrow", "block", V(0.4, 1, 0.3), top * CF(0, 1.5, -0.7), a, Enum.Material.Neon)
	elseif kind == "speaker" then
		addPart(ctx, "Speaker", "block", V(2.2, 3, 1.5), back * CF(0, 1.5, 0), BLACK)
		addPart(ctx, "Woofer", "cyl", V(0.3, 1.6, 1.6), back * CF(0, 1, -0.75) * CFrame.Angles(0, math.rad(90), 0), a, Enum.Material.Neon)
		addPart(ctx, "Tweeter", "cyl", V(0.3, 0.8, 0.8), back * CF(0, 2.4, -0.75) * CFrame.Angles(0, math.rad(90), 0), a, Enum.Material.Neon)
	end
end

-- Trending glows cyan and sparkles, Viral burns hot pink, a Legendary Meme is solid gold.
local function applyMutationLook(model: Model, mutation: string)
	local def = BrainrotCatalog.Mutations[mutation]
	local body = model:FindFirstChild("Body") :: BasePart
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Eye" and part.Name ~= "Pupil" and part.Name ~= "Sign" and part.Transparency < 1 then
			if mutation == "Trending" then
				part.Color = part.Color:Lerp(def.color, 0.45)
			elseif mutation == "Viral" then
				part.Color = part.Color:Lerp(def.color, 0.7)
				part.Material = Enum.Material.Neon
			else
				part.Color = def.color:Lerp(part.Color, 0.15)
				part.Material = Enum.Material.Foil
				part.Reflectance = 0.25
			end
		end
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = def.color
	sparkles.Parent = body
	if mutation ~= "Trending" then
		local fire = Instance.new("Fire")
		fire.Color = def.color
		fire.SecondaryColor = WHITE
		fire.Size = 7
		fire.Heat = 12
		fire.Parent = body
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 16
		light.Brightness = 2
		light.Parent = body
	end
end

local function addTagLine(parent: Instance, name: string, y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, height)
	label.Position = UDim2.fromScale(0, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

-- The big label over every brainrot: mutation, name, rarity, then price and money per second.
local function addNameTag(model: Model, entry: BrainrotCatalog.Entry, mutation: string?, height: number)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Adornee = model.PrimaryPart
	tag.Size = UDim2.fromScale(15, 6.4)
	tag.StudsOffsetWorldSpace = Vector3.new(0, height + 3.9, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 230
	tag.Parent = model.PrimaryPart
	local mutationLine = addTagLine(tag, "Mutation", 0, 0.2, WHITE)
	if mutation then
		mutationLine.Text = BrainrotCatalog.Mutations[mutation].label
		mutationLine.TextColor3 = BrainrotCatalog.Mutations[mutation].color
	end
	addTagLine(tag, "BrainrotName", 0.2, 0.3, WHITE).Text = entry.name
	addTagLine(tag, "Rarity", 0.5, 0.2, entry.color).Text = string.upper(entry.rarityName)
	addTagLine(tag, "Price", 0.7, 0.3, Color3.fromRGB(74, 222, 128))
end

-- Rewrites the last line of the tag: "$250  +$4/s" on the Feed, "+$8/s" on a stand.
function BrainrotBuilder.setTagMoney(model: Model, price: number?, incomePerSecond: number)
	local line = model.PrimaryPart:FindFirstChild("NameTag"):FindFirstChild("Price") :: TextLabel
	local income = "+" .. GameConfig.formatCash(incomePerSecond) .. "/s"
	line.Text = if price then GameConfig.formatCash(price) .. "   " .. income else income
	line.TextColor3 = if price then Color3.fromRGB(74, 222, 128) else GOLD
end

-- Builds brainrot `id` standing on the origin, facing -Z. The caller parents and places it.
function BrainrotBuilder.buildFromParts(id: string, mutation: string?): Model
	local entry = BrainrotCatalog.get(id) :: BrainrotCatalog.Entry
	local model = Instance.new("Model")
	model.Name = entry.name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(2, 0.2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	local scale = tonumber(entry.traits.size) or 1
	local ctx: Ctx = { model = model, root = root, s = scale, main = entry.main, accent = entry.accent, seed = entry.order * 7 }
	local anchors = buildBody(ctx, entry.body, entry.traits)
	addSpeciesTraits(ctx, anchors, entry.traits)
	addGooglyEyes(ctx, anchors, entry.traits)
	addPhoneWorldProp(ctx, anchors, entry.prop)
	if mutation then
		applyMutationLook(model, mutation)
	end
	addNameTag(model, entry, mutation, model:GetExtentsSize().Y)
	BrainrotBuilder.setTagMoney(model, BrainrotCatalog.priceOf(id, mutation), BrainrotCatalog.incomeOf(id, mutation))
	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("Mutation", mutation)
	return model
end

return BrainrotBuilder
