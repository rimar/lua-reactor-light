require "net"

local timer = net.timer()

-- Timer example
timer:every(3, function()
  print("tick5", os.time())
end)

-- Server example 
local server = net.server(function(c)
  c:on("data", function(data)
    c:write("HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nLua")
    print("server received", data)
  end)
end)

local ip, port = server:listen("*", 51111)

-- Client example
timer:every(2, function()
  local c = net.client()
  c:connect("localhost", port, function(err)
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

-- Main loop
reactor.loop()

