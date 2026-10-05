-- FS25 view objects are simulated. Rendering still requires an in-game check.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local mod = path:match("^(.*)/tests/[^/]+$") or "."
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end

function Class(class, parent)
    class.__index = class
    class.superClass = function() return parent end
    return setmetatable(class, {__index = parent})
end
DialogElement = {}
function DialogElement.new(_, mt) return setmetatable({}, mt) end
function DialogElement:onOpen() self.isOpen = true end
function DialogElement:onClose() self.isOpen = false end
function DialogElement:close() g_gui:closeDialogByName(self.name) end
Logging = {warning = function() end}

local function textElement()
    return {text = "", setText = function(self, text) self.text = text end}
end
local filtered = 0
local function textInput()
    local input = textElement()
    input.applyProfanityFilter = true
    function input:setText(text) self.text = text:sub(1, self.maxCharacters or 30) end
    function input:getText() return self.text end
    function input:setForcePressed(value)
        if self.capturing and not value and self.applyProfanityFilter then
            filtered = filtered + 1
            self.text = self.text:gsub("youtube", "y#$&*@e")
        end
        self.capturing = value
    end
    function input:onFocusActivate() self:setForcePressed(true) end
    function input:abortIme() end
    return input
end

local loads = 0
local sharedInput = textInput()
g_gui = {guis = {TextInputDialog = {target = {textInputElement = sharedInput}}}}
function g_gui:loadGui(filename, name, target)
    check(filename == mod .. "/assets/gui/TMSLinkDialog.xml", "Own GUI file")
    target.name = name
    target.titleElement, target.promptElement, target.confirmButton = textElement(), textElement(), textElement()
    target.videoTestButton = textElement()
    target.textInputElement = textInput()
    local gui = {target = target}
    self.guis[name] = gui
    loads = loads + 1
    return gui
end
function g_gui:showDialog(name)
    local gui = self.guis[name]
    self.openName = name
    gui.target:onOpen()
    return gui
end
function g_gui:closeDialogByName(name)
    check(self.openName == name, "Close only the owned dialog")
    self.guis[name].target:onClose()
    self.openName = nil
end

dofile(mod .. "/scripts/gui/TMSLinkDialog.lua")
dofile(mod .. "/scripts/media/TMSMediaSource.lua")
check(not TMSLinkDialog.show(function() end), "No unregistered dialog")
check(TMSLinkDialog.register(mod .. "/"), "Register URL dialog")
check(TMSLinkDialog.register(mod .. "/") and loads == 1, "Reuse registered view")

local target, args = {}, {generation = 3}
local result, calls
local function callback(self, text, accepted, data, action)
    calls = (calls or 0) + 1
    check(g_gui.openName == nil, "Close before invoking callback")
    result = {target = self, text = text, accepted = accepted, args = data, action = action}
end
local fullUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123&index=2&t=32s"
check(TMSLinkDialog.show(callback, target, fullUrl, "Title", "Prompt", "Check", args), "Open URL dialog")
local view = TMSLinkDialog.instance
check(view.titleElement.text == "Title" and view.confirmButton.text == "Check", "Dialog labels")
check(not sharedInput.capturing and sharedInput.applyProfanityFilter, "Shared game dialog unchanged")
check(not TMSLinkDialog.show(callback), "Avoid replacing an open dialog callback")
view.textInputElement:setForcePressed(false)
check(view.textInputElement:getText() == fullUrl and filtered == 0, "Leaving input preserves provider and query")
view:onClickOk()
check(result.target == target and result.text == fullUrl and result.accepted and result.args == args,
    "Return the complete original URL and session arguments")
check(view.callback == nil and view.textInputElement.text == "" and not view.textInputElement.capturing,
    "Closed dialog releases capture and personal URL")
check(TMSMediaSource.parse(result.text).provider == "youtube", "Link survives the complete dialog path")

local longPrefix = "https://youtu.be/dQw4w9WgXcQ?si="
local longUrl = longPrefix .. string.rep("a", 2048 - #longPrefix)
check(#longUrl == 2048, "Boundary fixture")
TMSLinkDialog.show(callback, target, longUrl, nil, nil, nil, args)
view:onEnterPressed()
check(result.text == longUrl and TMSMediaSource.parse(result.text) ~= nil, "Full 2048-character link accepted")
TMSLinkDialog.show(callback, target, "", nil, nil, nil, args, "Test video")
view:onClickVideoTest()
check(result.accepted and result.action == "videoTest" and result.text == "",
    "Test video can start without a link and after closing the dialog")
TMSLinkDialog.show(callback, target, fullUrl)
view:onEscPressed()
check(not result.accepted, "Escape cancels")
TMSLinkDialog.show(callback, target, fullUrl)
local previousCalls = calls
TMSLinkDialog.reset()
check(calls == previousCalls and view.callbackTarget == nil and view.textInputElement.text == "",
    "Map reset drops pending callback and clears local URL")
check(TMSLinkDialog.register(mod .. "/") and loads == 1, "Next map reuses the view")
for _, char in ipairs({"?", "&", "=", "%", "_", "-", "/", ":", "#"}) do
    check(view:onIsUnicodeAllowed(char:byte()), "URL punctuation accepted")
end
check(not view:onIsUnicodeAllowed(10) and not view:onIsUnicodeAllowed(0), "Reject control characters")
for _, url in ipairs({"https://youtu.be/dQw4w9WgXcQ?si=Abc_12-34&t=42",
    "https://www.youtube.com/watch?si=abc&v=dQw4w9WgXcQ&feature=shared",
    "https://youtube.com/live/dQw4w9WgXcQ?si=abc", "https://youtube.com/embed/dQw4w9WgXcQ"}) do
    check(TMSMediaSource.parse(url).id == "dQw4w9WgXcQ", "Shared and embedded YouTube links")
end
print(string.format("TractorMediaScreen link dialog: %d checks passed (%s)", checks, _VERSION))
