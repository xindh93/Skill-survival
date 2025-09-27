local Signal = {}
Signal.__index = Signal

export type Connection = {
    Connected: boolean,
    Disconnect: () -> (),
}

local function createConnection(signal: Signal, handler: (...any) -> ())
    local connection
    connection = {
        Connected = true,
        Disconnect = function()
            if not connection or not connection.Connected then
                return
            end
            connection.Connected = false
            signal._listeners[connection] = nil
            connection = nil
        end,
    }

    signal._listeners[connection] = handler
    return connection
end

function Signal.new(): Signal
    local self = setmetatable({}, Signal)
    self._listeners = {} :: {[Connection]: (...any) -> ()}
    return self
end

function Signal:Connect(handler: (...any) -> ()): Connection
    assert(typeof(handler) == "function", "Signal handler must be a function")
    return createConnection(self, handler)
end

function Signal:Once(handler: (...any) -> ()): Connection
    local connection: Connection
    connection = self:Connect(function(...)
        if connection then
            connection:Disconnect()
        end
        handler(...)
    end)
    return connection
end

function Signal:Wait(...): ...any
    local thread = coroutine.running()
    local arguments
    local connection
    connection = self:Connect(function(...)
        if connection then
            connection:Disconnect()
        end
        arguments = table.pack(...)
        task.spawn(function()
            coroutine.resume(thread)
        end)
    end)

    coroutine.yield()
    return table.unpack(arguments or table.pack())
end

function Signal:Fire(...)
    for connection, handler in pairs(self._listeners) do
        if connection and connection.Connected then
            task.spawn(handler, ...)
        end
    end
end

function Signal:Destroy()
    for connection in pairs(self._listeners) do
        if connection then
            connection.Connected = false
            self._listeners[connection] = nil
        end
    end
end

return Signal
