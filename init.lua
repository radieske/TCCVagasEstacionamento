--Funcao para conectar
local t = 0
local conect = 0
function connect()
    dofile("config_wifi.lua")
    if (wifi.sta.status() == 5) then
        print("Conectado!")
        print(wifi.sta.getip())
        tmr.stop(0)
        tmr.alarm(1, 5000, 1, function() leitura() end)
    else
        print("Conectando... - tentativa "..t)
        if (t == 5)
        then
            tmr.stop(0)
        else
            t = t +1
        end
    end
end
tmr.alarm(0, 5000, 1, function() connect() end)
--Funcao para iniciar as leituras
function leitura()
    dofile("hcsr04-simple.lua")
    h = hcsr04(1, 2, 1, 10, 4)
    h.measure()
    tmr.stop(1)
end
