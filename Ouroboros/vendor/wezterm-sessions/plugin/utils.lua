local utils = {}

--- Displays a notification with the specified message.
function utils.notify(window, message)
    return window:toast_notification('WezTerm', message, nil, 2000)
end

return utils
