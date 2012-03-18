require "net"

local timer = net.timer()

-- Timer example
timer:every(3, function()
  print("tick5", os.time())
end)

-- Client example
timer:every(2, function()
  local c = net.client()
  c:connect("localhost", 4567, function(err)
    if err then
      print("connect failed", err)
      return
    end
    c:write("GET /reactor HTTP/1.1\r\n\r\n", function()
      c:on("data", function(data)
        print("http response:", data)
        c:close()
      end)
      c:on("end", function(err)
        print("client con closed, error: ", err)
      end)
    end)
  end)
end)

-- Server example
local server = net.server(function(c)
  c:on("data", function(data)
    c:write(data)
  end)
end)

local ip, port = server:listen("*", 51111)

-- Main loop
reactor.loop()

