-- Central switch for every log message emitted by this mod.
-- Set DEBUG = false and rebuild the ZIP to disable diagnostics for a release.
-- Native engine/other-mod messages and explicit console return text are separate.
TMSLog = {DEBUG = true}

function TMSLog.info(...)
    if TMSLog.DEBUG then Logging.info(...) end
end

function TMSLog.warning(...)
    if TMSLog.DEBUG then Logging.warning(...) end
end

function TMSLog.error(...)
    if TMSLog.DEBUG then Logging.error(...) end
end
