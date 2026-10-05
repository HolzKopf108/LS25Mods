-- Private URL entry view. FS25's name input applies a word filter which can
-- corrupt provider names. Change only this view, never the shared game dialog.
TMSLinkDialog = {
    GUI_NAME = "FS25_TractorMediaScreen_LinkDialog",
    MAX_CHARACTERS = 2048
}
local TMSLinkDialog_mt = Class(TMSLinkDialog, DialogElement)

function TMSLinkDialog.new()
    return DialogElement.new(nil, TMSLinkDialog_mt)
end

function TMSLinkDialog.register(modDirectory)
    if g_gui == nil or type(g_gui.loadGui) ~= "function" then return false end
    local existing = g_gui.guis[TMSLinkDialog.GUI_NAME]
    if TMSLinkDialog.instance ~= nil and existing ~= nil
        and existing.target == TMSLinkDialog.instance then return true end
    -- A distinct class and GUI name keep the game's own text dialogs intact.
    local instance = TMSLinkDialog.new()
    local ok, gui = pcall(g_gui.loadGui, g_gui,
        modDirectory .. "assets/gui/TMSLinkDialog.xml", TMSLinkDialog.GUI_NAME, instance)
    if not ok or gui == nil then
        Logging.warning("[TractorMediaScreen] Could not load the local URL dialog")
        return false
    end
    TMSLinkDialog.instance = instance
    return true
end

function TMSLinkDialog.show(callback, target, defaultText, title, prompt, confirmText, callbackArgs, videoTestText)
    local self = TMSLinkDialog.instance
    if self == nil or g_gui == nil or self.isOpen then return false end
    self.callback, self.callbackTarget, self.callbackArgs = callback, target, callbackArgs
    self.titleElement:setText(title or "")
    self.promptElement:setText(prompt or "")
    self.confirmButton:setText(confirmText or "")
    self.videoTestButton:setText(videoTestText or "")
    self.textInputElement.applyProfanityFilter = false
    self.textInputElement.maxCharacters = TMSLinkDialog.MAX_CHARACTERS
    self.textInputElement:setText(defaultText or "")
    local gui = g_gui:showDialog(TMSLinkDialog.GUI_NAME)
    if gui == nil then
        self.callback, self.callbackTarget, self.callbackArgs = nil, nil, nil
        return false
    end
    return true
end

function TMSLinkDialog:onOpen()
    TMSLinkDialog:superClass().onOpen(self)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
end

function TMSLinkDialog:onClose()
    -- Explicitly release capture before the parent restores dialog input.
    self.textInputElement:abortIme()
    self.textInputElement:setForcePressed(false)
    self.callback, self.callbackTarget, self.callbackArgs = nil, nil, nil
    self.textInputElement:setText("")
    TMSLinkDialog:superClass().onClose(self)
end

function TMSLinkDialog:finish(accepted, action)
    local callback, target, args = self.callback, self.callbackTarget, self.callbackArgs
    local text = self.textInputElement:getText()
    self.callback, self.callbackTarget, self.callbackArgs = nil, nil, nil
    self:close()
    -- getText returns the full value. The view's ellipsis is only rendering.
    if callback ~= nil then
        if target ~= nil then callback(target, text, accepted, args, action)
        else callback(text, accepted, args, action) end
    end
end

function TMSLinkDialog:onClickOk()
    self:finish(true, "link")
end

function TMSLinkDialog:onClickVideoTest()
    self:finish(true, "videoTest")
end

function TMSLinkDialog:onClickBack()
    self:finish(false)
    return false
end

function TMSLinkDialog:onEnterPressed()
    self:onClickOk()
end

function TMSLinkDialog:onEscPressed()
    self:onClickBack()
end

function TMSLinkDialog:onIsUnicodeAllowed(unicode)
    -- URLs use ASCII, including query separators, percent escapes and IDs.
    return type(unicode) == "number" and unicode >= 32 and unicode <= 126
end

function TMSLinkDialog.reset()
    local self = TMSLinkDialog.instance
    if self == nil then return end
    self.callback, self.callbackTarget, self.callbackArgs = nil, nil, nil
    if self.isOpen then self:close() end
    self.textInputElement:setText("")
    -- Reuse this registered view across maps, as the built-in GUI does.
end
