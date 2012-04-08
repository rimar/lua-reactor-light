require "net"

function wb(c, body) c:write("HTTP/1.0 200 OK\r\nContent-Length:" .. body:len() .. "\r\n\r\n" .. body) end

local port = 8888
local server = net.server(function(c)
  c:on("data", function(data)
    local secs = string.match(data, " /(%d+) HTTP")
    if secs then 
      net.timer():after(tonumber(secs), function() wb(c, " <h1> i waited " .. secs .. " seconds </h1> ") end)
    else
      wb(c, "<h1>fraking oops</h1>")
    end
    -- print(data)
  end)
end)

local ip, port = server:listen("*", port)

reactor.loop()

