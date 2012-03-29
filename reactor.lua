local base = _G
local socket = require "socket"

module(..., package.seeall)

local run = true
local timeout = 0.1
local handlers = {}
local timers = {}


function stop()
  run = false
end

function remove_handler(handler)
  if (not handler or not handler.con) then return end
  local con = handler.con
  handlers[con] = nil
end

function handle_event(event_type, con)
  local handler = handlers[con]
  -- If there is no handler we will get into endless loop need to assert
  if (not handler) then error("no handler") end

  if (event_type == "read") then handler.wants_read = nil end
  if (event_type == "write") then handler.wants_write = nil end
  if (not handler.wants_read and not handler.wants_write or handler.closed) then 
    remove_handler(handler)
  end
  -- Tail call ftw
  handler:handle_event(event_type)
end

-- Debug print
function printt(t)
  if t == nil then print(nil) end
  local out = "{"
  for k,v in pairs(t) do out = out..tostring(k).."="..tostring(v).."," end
  return out.."}"
end

-- For the timer
function tick() 
  local time = socket.gettime()
  for _,t in ipairs(timers) do
    t:tick(time)
  end
end

-- Main loop
function loop()
  run = true
  while (run) do
    -- Build the list of sockets to select from
    local readers, writers = {}, {}
    for c,h in pairs(handlers) do 
      if (h.wants_read) then table.insert(readers, c) end
      if (h.wants_write) then table.insert(writers, c) end
    end
    local rr, rw, msg = socket.select(readers, writers, timeout)
    -- print("after select", printt(rr), printt(rw), msg, printt(handlers))
    if (msg ~= "timeout") then
      for _,con in ipairs(rr) do
        handle_event("read", con)
      end
      for _,con in ipairs(rw) do
        handle_event("write", con)
      end
    end
    tick()
  end
end

function register_read(handler)
  if handler.closed then return end
  handler.wants_read = true
  handlers[handler.con] = handler
end

function register_write(handler)
  if handler.closed then return end
  handler.wants_write = true
  handlers[handler.con] = handler
end

function register_timer(timer)
  table.insert(timers, timer)
end

