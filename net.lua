require "reactor"
require "socket"
require "util"

-- Define classes net(superclass), Connection : net, Server: net, Client: Connection
net = {}

function net:new(o)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local Connection = net:new()

function Connection:new(o)
  local o = net.new(self, o)
  o.callbacks = {}
  return o
end

local Server = net:new()
local Client = Connection:new()
local timer = {callbacks={}, counter = 0}

reactor.register_timer(timer)

function net.timer()
  return timer
end

function timer:every(sec, func)
  self:after(sec, func, true)
end

function timer:after(sec, func, repeating)
  local repeating = repeating or false
  if (sec == nil or sec <= 0) then error("sec must be not nil and positive. sec = " .. sec) end
  if (func == nil) then error("func is nil") end
  self.counter = self.counter + 1
  local id = "t" .. self.counter
  self.callbacks[id] = {after=sec, func=func, repeating=repeating}
  return id
end

function timer:cancel(id)
  self.callbacks[id] = nil
end

function timer:tick(time)
  for id,cb in pairs(table.copy(self.callbacks)) do
    if cb.last == nil then cb.last=time end
    if time - cb.last >= cb.after then
      cb.last = time
      if not cb.repeating then 
        self.callbacks[id] = nil 
      end
      pcall(cb.func)
    end
  end
end

function net.client()
  local c = Client:new()
  return c
end

function Client:connect(host, port, onconnect)

  local con = socket.tcp()
  self.con = con
  con:settimeout(0)
  local res, err = con:connect(host, port)
  -- print("after connect", res, err)

  if (err == "timeout") then
    reactor.register_write({
      con = con,
      handle_event = function(temp, event_type)
        local res, err = con:connect(host, port)
        if (err == "already connected") then err = nil end
        onconnect(err)
      end})
  else 
    onconnect(err) 
  end
end

function Connection:close()
  -- print('Closing the connection')
  if self.closed then return end
  self.closed = true
  self.con:close()
  reactor.remove_handler(self)
  local onend = self.callbacks["end"]
  if (onend) then onend(err) end
end

Connection.__tostring = function(c)
  return "[Con " .. c.i .. "cb:".. tostring(c.callbacks).." sock: " ..  tostring(c.con) .."]"
end

function net.server(func)
  local server = Server:new()
  server.on_accept = func
  return server
end

function Server:listen(ip, port)
  -- Create a TCP socket and bind it to the local host, at any port
  local sersock = assert(socket.bind(ip, port))
  -- Find out which port the OS chose for us
  local ip, port = sersock:getsockname()
  -- Print a message informing what's up
  -- print("Server ", sersock, " listening on port " .. port)
  sersock:settimeout(0)
  sersock:accept()
  self.con, self.ip, self.port = sersock, ip, port

  reactor.register_read(self)
  return ip, port
end

-- Accept
function Server:handle_event(event_type)
  local con_sock, err = self.con:accept()
  -- print("accept", con_sock, err)
  if err then error("failed to accept: " .. tostring(err)) end
  con_sock:settimeout(0)
  local conn = Connection:new()
  conn.callbacks = {}
  conn.con = con_sock
  -- print("new connection", conn)
  self.on_accept(conn)
  reactor.register_read(self)
end

function Connection:on(event, func)
  self.callbacks[event] = func
  reactor.register_read(self)
end

function Connection:handle_close(err)
  self:close()

end

function Connection:write(data, func)
  self.callbacks.write = func
  local sent, err, esent = self.con:send(data)
  -- print("send to", self.con, sent, err, esent, data:len())
  if (err == "closed") then
    self:handle_close(err)
    return
  end

  -- print("remaining data", self.data)
  if (err == "timeout") then
    self.data = string.sub(data, esent + 1)
    reactor.register_write(self)
    return
  end
  -- Everything ok callback if needed
  if func then func() end
end

function Connection:handle_event(event_type)
  if (event_type == "read") then
    local buf, err, overflow = self.con:receive(8192)
    -- print("read", uf, err, overflow)
    local data = buf or overflow
    if (data ~= nil and data:len() > 0) then 
      -- print("xxxdata", data, self)
      local ondata = self.callbacks.data
      if (ondata) then ondata(data) end
    end
    if (err ~= nil and err ~= "timeout") then
      self:handle_close(err)
      return
    end
    reactor.register_read(self)
  elseif (event_type == "write") then
    -- print("write callback")
    self:write(self.data, self.callbacks.write)
  else
    error("unknown event type: " .. event_type)
  end
end


