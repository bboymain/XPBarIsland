local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Small themed controls used by the settings window: checkbox, segmented
-- buttons, slider and button.  Each builder returns a full row frame with a
-- :Refresh() method.
-- ---------------------------------------------------------------------------
local W = {}
ns.Widgets = W

local ROW_H = 46
local function fs(parent, size, hex, justify)
    local t = parent:CreateFontString(nil, "OVERLAY")
    ns.StyleText(t, size, "bold", "")
    t:SetTextColor(ns.Hex(hex))
    if justify then t:SetJustifyH(justify) end
    return t
end

local function base(parent, label, desc)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row.label = fs(row, 14, "#ECE6D8", "LEFT")
    ns.StyleText(row.label, 14, "bold")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.desc = fs(row, 11, (ns.Theme().grey or "#8F8777"), "LEFT")
    ns.StyleText(row.desc, 11, "medium")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.div = row:CreateTexture(nil, "ARTWORK", nil, 0)
    row.div:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.div:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.div:SetHeight(1)
    ns.Paint(row.div, 0.13, 0.12, 0.09, 1)
    row.label:SetText(label or "")
    row.desc:SetText(desc or "")
    row.hl = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.hl:SetAllPoints(row)
    ns.Paint(row.hl, 1, 0.82, 0, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function() row.hl:SetAlpha(0.06) end)
    row:SetScript("OnLeave", function() row.hl:SetAlpha(0) end)
    return row
end

function W.Checkbox(parent, label, desc, get, set)
    local row = base(parent, label, desc)
    local chk = CreateFrame("Frame", nil, row)
    chk:SetSize(20, 20)
    chk:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    chk.bg = chk:CreateTexture(nil, "BACKGROUND", nil, 0)
    chk.bg:SetAllPoints(chk)
    ns.Paint(chk.bg, 0.047, 0.039, 0.031, 1)
    chk.bd = chk:CreateTexture(nil, "BORDER", nil, 1)
    chk.bd:SetPoint("TOPLEFT", chk, "TOPLEFT", -1, 1)
    chk.bd:SetPoint("BOTTOMRIGHT", chk, "BOTTOMRIGHT", 1, -1)
    chk.mark = fs(chk, 15, (ns.Theme().pillText or "#FFD100"), "CENTER")
    chk.mark:SetPoint("CENTER", chk, "CENTER", 0, 1)
    chk.mark:SetText("\226\156\147")
    chk:EnableMouse(true)
    chk:SetScript("OnMouseUp", function()
        set(not get())
        ns.Notify()
    end)
    row.Refresh = function()
        local on = get()
        if on then chk.mark:Show() else chk.mark:Hide() end
        local th = ns.Theme()
        ns.Paint(chk.bd, ns.Hex(th.trim))
        chk.mark:SetTextColor(ns.Hex(th.btnText or th.pillText or th.gold))
        row.desc:SetTextColor(ns.Hex(th.grey or "#8F8777"))
    end
    return row
end

function W.Segmented(parent, label, desc, options, get, set)
    local row = base(parent, label, desc)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    holder:SetHeight(26)
    local buttons = {}
    local function refresh()
        local cur = get()
        local totalW = 0
        for i, opt in ipairs(options) do
            local b = buttons[i]
            local active = (opt.value == cur)
            local th = ns.Theme()
            b.label:SetTextColor(ns.Hex(active and (th.btnText or th.pillText or th.gold) or (th.pillOff or "#9D9D9D")))
            ns.WhiteTexture(b.bg)
            if active then
                ns.Gradient(b.bg, ns.HexA(th.btnPrimary1 or "#3A2C12"), ns.HexA(th.btnPrimary2 or "#1A1409"), false)
                ns.Paint(b.bd, ns.Hex(th.btnRing or th.ring))
            else
                ns.Gradient(b.bg, ns.HexA(th.bg1), ns.HexA(th.bg2), false)
                ns.Paint(b.bd, 0.29, 0.23, 0.11, 1)
            end
            totalW = totalW + b:GetWidth()
        end
        holder:SetWidth(totalW)
        row.desc:SetTextColor(ns.Hex(ns.Theme().grey or "#8F8777"))
    end
    for i, opt in ipairs(options) do
        local b = CreateFrame("Frame", nil, holder)
        b:SetHeight(26)
        b.label = fs(b, 12, "#9D9D9D", "CENTER")
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label:SetText(opt.label)
        local lw = b.label:GetStringWidth() or 40
        b:SetWidth(lw + 22)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
        b.bg:SetAllPoints(b)
        b.bd = b:CreateTexture(nil, "BORDER", nil, 1)
        b.bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        b.bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        b:EnableMouse(true)
        b:SetScript("OnMouseUp", function()
            set(opt.value)
            refresh()
            ns.Notify()
        end)
        if i == 1 then
            b:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else
            b:SetPoint("LEFT", buttons[i - 1], "RIGHT", -1, 0)
        end
        buttons[i] = b
    end
    row.Refresh = refresh
    return row
end

function W.Slider(parent, label, desc, min, max, step, get, set, fmt)
    local row = base(parent, label, desc)
    row:SetHeight(math.max(ROW_H, 40))
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    holder:SetSize(230, 40)

    local value = fs(holder, 12, "#FFD100", "RIGHT")
    value:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    value:SetWidth(46)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(150, 16)
    slider:SetPoint("RIGHT", value, "LEFT", -10, 6)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    if slider.SetHitRectInsets then slider:SetHitRectInsets(0, 0, -6, -6) end

    local track = slider:CreateTexture(nil, "BACKGROUND", nil, 0)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    ns.Paint(track, 0.047, 0.039, 0.031, 1)

    local tb = {}
    for i = 1, 4 do
        local t = slider:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.Media.white)
        tb[i] = t
    end
    local fill = slider:CreateTexture(nil, "ARTWORK", nil, 0)
    fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetWidth(0)

    local thumbEdge = slider:CreateTexture(nil, "OVERLAY", nil, 1)
    thumbEdge:SetSize(12, 18); thumbEdge:SetTexture(ns.Media.white); thumbEdge:SetVertexColor(0, 0, 0, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY", nil, 2)
    thumb:SetSize(10, 16); thumb:SetTexture(ns.Media.white)
    slider:SetThumbTexture(thumb)

    local minT = fs(holder, 10, "#8F8777", "LEFT")
    minT:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4); minT:SetText(tostring(min))
    local maxT = fs(holder, 10, "#8F8777", "RIGHT")
    maxT:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -4); maxT:SetText(tostring(max))

    local function borderEdges()
        local e = tb
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0); e[1]:SetHeight(1)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(1)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
        local trim = ns.HexA(ns.Theme().trim)
        if slider._hover then trim = { math.min(1, trim[1] + 0.3), math.min(1, trim[2] + 0.3), math.min(1, trim[3] + 0.3), 1 } end
        for i = 1, 4 do ns.Paint(e[i], trim[1], trim[2], trim[3], trim[4] or 1) end
    end

    local function apply(v)
        slider:SetValue(v)
        value:SetText(fmt and fmt(v) or tostring(v))
        local frac = (max > min) and (v - min) / (max - min) or 0
        fill:SetWidth(math.max(0, frac * 140 + 5))
        fill:SetVertexColor(ns.Hex(ns.Theme().gold))
        thumb:SetVertexColor(ns.Hex(ns.Theme().gold))
        borderEdges()
    end
    slider:SetScript("OnValueChanged", function(_, v)
        v = ns.round(v / step) * step
        value:SetText(fmt and fmt(v) or tostring(v))
        local frac = (max > min) and (v - min) / (max - min) or 0
        fill:SetWidth(math.max(0, frac * 140 + 5))
        set(v)
        ns.Notify()
    end)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(_, d)
        slider:SetValue(ns.clamp(slider:GetValue() + d * step, min, max))
    end)
    slider:SetScript("OnEnter", function() slider._hover = true; thumb:SetVertexColor(1, 0.9, 0.4, 1); borderEdges() end)
    slider:SetScript("OnLeave", function() slider._hover = false; thumb:SetVertexColor(ns.Hex(ns.Theme().gold)); borderEdges() end)

    row.Refresh = function() apply(get()) end
    apply(get())
    return row
end

-- On/off switch: 40x22 track (dark fill + 1px trim border), 16px square knob.
function W.Switch(parent, label, desc, get, set)
    local row = base(parent, label, desc)
    row.control = "switch"
    row:SetHeight(math.max(ROW_H, 34))

    local sw = CreateFrame("Frame", nil, row)
    sw:SetSize(40, 22)
    sw:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local stateText = fs(row, 10, "#6B6454", "RIGHT")
    stateText:SetPoint("RIGHT", sw, "LEFT", -6, 0)

    sw.track = sw:CreateTexture(nil, "BACKGROUND", nil, 0)
    sw.track:SetAllPoints(sw)
    sw.tb = {}
    for i = 1, 4 do
        local t = sw:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.Media.white)
        sw.tb[i] = t
    end
    sw.knobEdge = sw:CreateTexture(nil, "OVERLAY", nil, 1)
    sw.knobEdge:SetTexture(ns.Media.white)
    sw.knobEdge:SetSize(18, 18)
    sw.knobEdge:SetVertexColor(0, 0, 0, 1)
    sw.knob = sw:CreateTexture(nil, "OVERLAY", nil, 2)
    sw.knob:SetTexture(ns.Media.white)
    sw.knob:SetSize(16, 16)
    sw:EnableMouse(true)

    local function placeKnob(x)
        sw._kx = x
        sw.knob:ClearAllPoints(); sw.knob:SetPoint("LEFT", sw, "LEFT", x, 0)
        sw.knobEdge:ClearAllPoints(); sw.knobEdge:SetPoint("LEFT", sw, "LEFT", x - 1, 0)
    end
    local function borderEdges(col)
        local e = sw.tb
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 0, 0); e[1]:SetHeight(1)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(1)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", sw, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", sw, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
        for i = 1, 4 do ns.Paint(e[i], col[1], col[2], col[3], col[4] or 1) end
    end

    local function apply(on, animate)
        local th = ns.Theme()
        local gold = ns.HexA(th.gold)
        local trim = ns.HexA(th.trim)
        ns.WhiteTexture(sw.track)
        if on then ns.Gradient(sw.track, ns.HexA(th.switchTrack1 or "#5A431A"), ns.HexA(th.switchTrack2 or "#2A1D09"), false)
        else ns.Paint(sw.track, 0.047, 0.039, 0.031, 1) end
        local bc = trim
        if sw._hover then bc = { math.min(1, trim[1] + 0.3), math.min(1, trim[2] + 0.3), math.min(1, trim[3] + 0.3), 1 } end
        borderEdges(bc)
        local kc = on and ns.HexA(th.switchOn or "#FFD100") or ns.HexA(th.switchOff or "#6B6454")
        sw.knob:SetVertexColor(kc[1], kc[2], kc[3], 1)
        stateText:SetText(on and "On" or "Off")
        stateText:SetTextColor(kc[1], kc[2], kc[3], 1)
        row.desc:SetTextColor(ns.Hex(th.grey or "#8F8777"))
        local target = on and 22 or 2
        if sw._ktween then ns.KillTween(sw._ktween) end
        if animate == false then
            placeKnob(target)
        else
            local from = sw._kx or target
            sw._ktween = ns.Tween({
                dur = 0.2, from = from, to = target, ease = ns.easeOutCubic,
                set = function(v) placeKnob(v) end,
                done = function() sw._ktween = nil end,
            })
        end
    end

    local function toggle()
        local on = not get()
        set(on)
        ns.Notify()
        apply(on, true)
    end
    sw:SetScript("OnMouseUp", toggle)
    row.label:EnableMouse(true)
    row.label:SetScript("OnMouseUp", toggle)
    sw:SetScript("OnEnter", function() sw._hover = true; apply(get(), false) end)
    sw:SetScript("OnLeave", function() sw._hover = false; apply(get(), false) end)

    row.Refresh = function() apply(get(), false) end
    ns.OnUpdateLayout(function() pcall(apply, get(), false) end)
    apply(get(), false)
    return row
end

-- Colour row: Auto + preset swatches + hex edit box + ColorPicker ("...").
function W.ColorRow(parent, label, desc, presets, get, set)
    local row = base(parent, label, desc)
    row:SetHeight(math.max(ROW_H, 34))
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    holder:SetHeight(24)
    local swatches = {}

    local function place(b)
        if #swatches == 1 then b:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else b:SetPoint("LEFT", swatches[#swatches], "RIGHT", 3, 0) end
        swatches[#swatches + 1] = b
    end

    -- 1px outline drawn as four edges.  A single texture stretched between two
    -- diagonal points would fill the frame and hide the colour underneath.
    local function makeEdges(frame)
        local bd = {}
        for i = 1, 4 do
            local t = frame:CreateTexture(nil, "BORDER", nil, 1)
            t:SetTexture(ns.Media.white)
            bd[i] = t
        end
        bd[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); bd[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); bd[1]:SetHeight(1)
        bd[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); bd[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0); bd[2]:SetHeight(1)
        bd[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); bd[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); bd[3]:SetWidth(1)
        bd[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); bd[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0); bd[4]:SetWidth(1)
        return bd
    end
    local function paintEdges(bd, r, g, b, a)
        for i = 1, 4 do ns.Paint(bd[i], r, g, b, a or 1) end
    end

    local function makeSwatch(color, isAuto)
        local b = CreateFrame("Frame", nil, holder)
        b:SetSize(22, 22)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
        b.bg:SetAllPoints(b)
        if isAuto then
            local th = ns.Theme()
            ns.Paint(b.bg, ns.Hex(th.trim))
        else
            ns.Paint(b.bg, ns.Hex(color))
        end
        b.bd = makeEdges(b)
        paintEdges(b.bd, 0, 0, 0, 1)
        b:EnableMouse(true)
        b.value = color or false
        b:SetScript("OnMouseUp", function() set(b.value); ns.Notify() end)
        place(b)
        return b
    end

    makeSwatch(nil, true)
    for _, c in ipairs(presets) do makeSwatch(c, false) end

    local eb = CreateFrame("EditBox", nil, holder)
    eb:SetSize(74, 22)
    eb:SetAutoFocus(false)
    ns.StyleText(eb, 11, "bold", "")
    eb:SetJustifyH("LEFT")
    eb:SetPoint("LEFT", swatches[#swatches], "RIGHT", 6, 0)
    local ebg = eb:CreateTexture(nil, "BACKGROUND", nil, 0)
    ebg:SetAllPoints(eb)
    ns.Paint(ebg, 0.05, 0.043, 0.031, 1)
    local ebd = makeEdges(eb)
    paintEdges(ebd, 0.29, 0.23, 0.11, 1)
    local function commit()
        local v = eb:GetText() or ""
        v = v:gsub("%s", "")
        if v:match("^#?%x%x%x%x%x%x$") then
            if v:sub(1, 1) ~= "#" then v = "#" .. v end
            set(v)
            ns.Notify()
        else
            eb:SetText("")
        end
    end
    eb:SetScript("OnEnterPressed", function(self) commit(); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", commit)

    local dots
    if _G.ColorPickerFrame then
        dots = CreateFrame("Frame", nil, holder)
        dots:SetSize(22, 22)
        dots:SetPoint("LEFT", eb, "RIGHT", 6, 0)
        dots.bd = makeEdges(dots)
        paintEdges(dots.bd, 0.29, 0.23, 0.11, 1)
        dots.t = dots:CreateFontString(nil, "OVERLAY")
        ns.StyleText(dots.t, 12, "bold", "")
        dots.t:SetPoint("CENTER", dots, "CENTER", 0, 0)
        dots.t:SetText("...")
        dots:EnableMouse(true)
        dots:SetScript("OnMouseUp", function()
            local r, g, b = ns.Hex(get() or "#ffffff")
            local function swatch(rr, gg, bb)
                if set then set(string.format("#%02X%02X%02X", rr * 255, gg * 255, bb * 255)); ns.Notify() end
            end
            if ColorPickerFrame.SetupColorPickerAndShow then
                pcall(ColorPickerFrame.SetupColorPickerAndShow, { swatchFunc = swatch, r = r, g = g, b = b })
            elseif ColorPickerFrame.SetColorRGB then
                ColorPickerFrame.func = swatch
                ColorPickerFrame:SetColorRGB(r, g, b)
                ColorPickerFrame:Show()
            end
        end)
    end

    -- Size the holder to its contents.  It is anchored by its RIGHT edge, so
    -- without an explicit width its left is the row's right edge and the whole
    -- swatch/hex/picker group would be laid out past the row and off-screen.
    local total = 0
    for i = 1, #swatches do
        if i > 1 then total = total + 3 end
        total = total + 22
    end
    total = total + 6 + 74
    if dots then total = total + 6 + 22 end
    holder:SetWidth(total)

    row.Refresh = function()
        local cur = get()
        for _, b in ipairs(swatches) do
            local on = (b.value or false) == (cur or false)
            paintEdges(b.bd, on and 1 or 0, on and 1 or 0, on and 1 or 0, 1)
        end
        if cur then eb:SetText(cur) else eb:SetText("") end
    end
    row.Refresh()
    return row
end

function W.Button(parent, label, onClick)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(26)
    b.control = "button"
    b.label = fs(b, 12, (ns.Theme().btnText or "#ECE6D8"), "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    local lw = b.label:GetStringWidth() or 40
    b:SetWidth(lw + 28)
    b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.bg:SetAllPoints(b)
    b.bd = {}
    for i = 1, 4 do
        local t = b:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.Media.white)
        b.bd[i] = t
    end
    b:EnableMouse(true)
    b:SetScript("OnMouseUp", function() onClick() end)
    local function edges()
        local e = b.bd
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0); e[1]:SetHeight(1)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(1)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
        local th = ns.Theme()
        local trim = ns.HexA(th.btnRing or th.trim)
        if b._hover then trim = { math.min(1, trim[1] + 0.3), math.min(1, trim[2] + 0.3), math.min(1, trim[3] + 0.3), 1 } end
        for i = 1, 4 do ns.Paint(e[i], trim[1], trim[2], trim[3], trim[4] or 1) end
    end
    b.Refresh = function()
        local th = ns.Theme()
        ns.WhiteTexture(b.bg)
        ns.Gradient(b.bg, ns.HexA(th.btn1 or "#1A150E"), ns.HexA(th.btn2 or "#0C0A08"), false)
        b.label:SetTextColor(ns.Hex(th.btnText or "#ECE6D8"))
        edges()
    end
    b:SetScript("OnEnter", function() b._hover = true; edges() end)
    b:SetScript("OnLeave", function() b._hover = false; edges() end)
    b.Refresh()
    return b
end

-- A subtle inline text link: grey like secondary text, turns gold on hover and
-- is clickable.  No button chrome, so it blends into the window.
function W.Link(parent, text, onClick, tooltipTitle, tooltipLine)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(16)
    b.label = fs(b, 11, (ns.Theme().grey or "#8F8777"), "LEFT")
    ns.StyleText(b.label, 11, "medium")
    b.label:SetText(text)
    b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
    b:SetWidth((b.label:GetStringWidth() or 60) + 6)
    b:EnableMouse(true)
    b:SetScript("OnMouseUp", function() if onClick then onClick() end end)
    b:SetScript("OnEnter", function(self)
        self.label:SetTextColor(ns.Hex(ns.Theme().gold))
        if _G.GameTooltip and tooltipLine then
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltipTitle or text, 1, 0.82, 0, 1, true)
            _G.GameTooltip:AddLine(tostring(tooltipLine), 1, 1, 1, true)
            _G.GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.label:SetTextColor(ns.Hex(ns.Theme().grey or "#8F8777"))
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    b.Refresh = function()
        b.label:SetTextColor(ns.Hex(ns.Theme().grey or "#8F8777"))
    end
    return b
end

-- A small clickable logo: white texture, dim until hovered (then it lights up
-- to full), shows a tooltip, and runs onClick.  Used for the social/support
-- icons in the settings footer.
function W.IconLink(parent, icon, onClick, tooltipTitle, tooltipLine, size)
    size = size or 20
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    b.tex:SetTexture(icon)
    b.tex:SetAlpha(0.45)
    b:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        if _G.GameTooltip and tooltipLine then
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltipTitle or "", 1, 0.82, 0, 1, true)
            _G.GameTooltip:AddLine(tostring(tooltipLine), 1, 1, 1, true)
            _G.GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.tex:SetAlpha(0.45)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function() if onClick then onClick() end end)
    b.Refresh = function() b.tex:SetAlpha(0.45) end
    return b
end
