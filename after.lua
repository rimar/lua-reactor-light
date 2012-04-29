require "net"


function oo()
  net.timer():after(1, 
  function() 
    print(" <h1> i waited 1 seconds </h1> ") 
    oo()
  end)
end
oo()

reactor.loop()

