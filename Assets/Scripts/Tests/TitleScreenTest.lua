-- Standalone LuaJIT test. Does not launch or build the engine.
-- From repository root: luajit Assets/Scripts/Tests/TitleScreenTest.lua
local scriptPath = arg[1] or "Assets/Scripts/GameLogic/TitleScreen.lua"
local function Check(ok, name) assert(ok, name); print("PASS: " .. name) end
local function V(x, y) return { X = x, Y = y } end
local function FaceRect(image)
    local hover = image.Path == "Assets/UI/Title/CellarButtonHover.png"
    local left, top, width, height = hover and 18 or 20, hover and 152 or 156, 2134, hover and 408 or 404
    return {
        Offset = V(image.Offset.X + image.Size.X * left / 2172, image.Offset.Y + image.Size.Y * top / 724),
        Size = V(image.Size.X * width / 2172, image.Size.Y * height / 724),
    }
end
local function NewMenu(width, height)
    local state = { Width = width, Height = height, Mouse = V(-1, -1), Pressed = false, Accepts = true, Loads = {}, Quits = 0, Images = {}, Texts = {} }
    local env = setmetatable({
        FVector2 = { new = V },
        MouseButton = { Left = 1 },
        GetViewportSize = function() return V(state.Width, state.Height) end,
        GetMousePosition = function() return state.Mouse end,
        IsMouseOverGameViewport = function() return state.Accepts end,
        IsMousePressed = function(button) assert(button == 1); return state.Pressed end,
        AddUIImage = function(path, size, anchor, alignment, offset)
            state.Images[#state.Images + 1] = { Path = path, Size = size, Anchor = anchor, Alignment = alignment, Offset = offset }
        end,
        AddUIText = function(text, size, anchor, alignment, offset)
            state.Texts[#state.Texts + 1] = { Text = text, Size = size, Anchor = anchor, Alignment = alignment, Offset = offset }
        end,
        LoadScene = function(path) state.Loads[#state.Loads + 1] = path end,
        QuitGame = function() state.Quits = state.Quits + 1 end,
    }, { __index = _G })
    local chunk = assert(loadfile(scriptPath)); setfenv(chunk, env); chunk()
    env.BeginPlay()
    function state:Frame()
        self.Images, self.Texts = {}, {}
        env.Tick(0.016)
    end
    function state:PointAt(index)
        local image = FaceRect(self.Images[index])
        self.Mouse = V(image.Offset.X + image.Size.X * .5, image.Offset.Y + image.Size.Y * .5)
    end
    return state, env
end

for _, size in ipairs({ V(1920,1080), V(1280,720), V(640,480), V(320,180) }) do
    local state = NewMenu(size.X, size.Y); state:Frame()
    assert(#state.Images == 4 and #state.Texts == 2)
    assert(state.Images[1].Path == "Assets/UI/Title/Background.png")
    assert(state.Images[1].Size.X >= size.X and state.Images[1].Size.Y >= size.Y)
    assert(math.abs(state.Images[1].Size.X / state.Images[1].Size.Y - 1620 / 864) < .0001)
    assert(state.Texts[1].Text == "게임 시작" and state.Texts[2].Text == "종료")
    local logo = state.Images[2]
    assert(logo.Path == "Assets/UI/Title/TitleWordmark-v2.png")
    assert(math.abs(logo.Size.X / logo.Size.Y - 2172 / 724) < .0001, "Logo aspect ratio changed")
    local logoLeft = logo.Offset.X + logo.Size.X * 28 / 2172
    local logoTop = logo.Offset.Y + logo.Size.Y * 98 / 724
    local logoWidth = logo.Size.X * 2120 / 2172
    local logoHeight = logo.Size.Y * 528 / 724
    local firstButton = FaceRect(state.Images[3])
    assert(math.abs(logoLeft - firstButton.Offset.X) < .001, "Logo is not aligned with buttons")
    assert(logoLeft >= 0 and logoLeft + logoWidth <= size.X and logoTop >= 0, "Logo outside screen")
    assert(logoTop + logoHeight < firstButton.Offset.Y, "Logo overlaps buttons")
    for i = 3, 4 do
        local image, text = FaceRect(state.Images[i]), state.Texts[i-2]
        assert(image.Offset.X >= -0.0001 and image.Offset.Y >= -0.0001)
        assert(image.Offset.X + image.Size.X <= size.X + 0.0001 and image.Offset.Y + image.Size.Y <= size.Y + 0.0001)
        assert(math.abs(size.X * text.Anchor.X + text.Offset.X - (image.Offset.X + image.Size.X * .5)) < .0001)
        assert(math.abs(size.Y * text.Anchor.Y + text.Offset.Y - (image.Offset.Y + image.Size.Y * .5)) < .0001)
    end
    state:PointAt(3); state.Pressed = true; state:Frame()
    assert(#state.Loads == 1 and state.Loads[1] == "Assets/Scenes/MapTest.scene" and state.Quits == 0)
end
Check(true, "Background covers viewport and title, textured button faces, labels and hit areas match at four sizes")

local state, env = NewMenu(1280,720)
state:Frame();state:PointAt(3);state.Pressed = false;state:Frame()
Check(#state.Loads == 0 and state.Images[3].Path == "Assets/UI/Title/CellarButtonHover.png", "Hover changes appearance without starting game")
state.Pressed = true;state:Frame();state:Frame()
Check(#state.Loads == 1, "Start requests existing scene transition only once")
env.OnReload();state:PointAt(4);state:Frame();state:Frame()
Check(state.Quits == 1 and #state.Loads == 1, "Quit action is one-shot and hot reload restores input")

state = NewMenu(1280,720);state:Frame();state:PointAt(3);state.Accepts = false;state.Pressed = true;state:Frame()
Check(#state.Loads == 0 and state.Quits == 0 and state.Images[3].Path == "Assets/UI/Title/CellarButton.png", "Editor controls or an unfocused game cannot activate menu")
state.Accepts = true;state.Mouse = V(0,0);state:Frame()
Check(#state.Loads == 0 and state.Quits == 0, "Background click does nothing")

local start = FaceRect(state.Images[3])
state.Mouse = V(start.Offset.X + start.Size.X + .01, start.Offset.Y + start.Size.Y * .5);state:Frame()
Check(#state.Loads == 0, "Click outside right edge does not hit button")
state.Mouse = V(start.Offset.X + start.Size.X * .5, start.Offset.Y + start.Size.Y + .01);state:Frame()
Check(#state.Loads == 0, "Click outside bottom edge does not hit button")
state.Mouse = V(start.Offset.X, start.Offset.Y);state:Frame()
Check(#state.Loads == 1, "Left and top edges are part of the button")

state = NewMenu(0,0);state.Pressed = true;state:Frame()
Check(#state.Images == 0 and #state.Texts == 0 and #state.Loads == 0 and state.Quits == 0, "Zero-sized game viewport is ignored")
print("Title screen Lua tests passed")
