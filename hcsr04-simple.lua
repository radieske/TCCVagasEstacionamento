--1) Executar: dofile("hcsr04-simple.lua")
--2) Executar: h = hcsr04(1, 2, 5, 10, 4)
--3) Executar: h.measure()
function hcsr04(trig_pin, echo_pin, max_distance, avg_readings, led)
	local self = {}
	--execucao continua (loop)
	self.CONTINUOUS = true
	--id do trigger (usado como padrao o zero)
	local trigger_timer_id = 0
	--intervalo da trigger em microsegundos (conforme documentação, o minimo é 10)
	local trigger_duration = 15
	--distancia maxima a ser lida (podendo ser até 5 metros)
	local maximum_distance = math.max(5, max_distance)
	--intervalo entre as leituras com 20% de margem conforme a distancia maxima.
	local reading_interval = math.ceil(((maximum_distance * 2 / 340 * 1000)
	    + trigger_duration) * 1.2)
	--numero minimo de leituras a serem realizadas (minimo considerado sera 5)
	self.avg_readings = math.max(5, avg_readings)
	--criacao de variaveis locais
	local time_start = 0
	local time_stop = 0
	local distance = 0
	local readings = {}
	local temp = {}
	local tab_distancias = {}
	
	gpio.mode(led, gpio.OUTPUT)
	--iniciar as leituras
	function self.measure()
		readings = {}
		temp = {}
		distance = 0
		tmr.start(trigger_timer_id)
	end
	--parar as leituras
	function self.stop()
		readings = {}
		temp = {}
		distance = 0
		gpio.write(led, gpio.HIGH);
		tmr.stop(trigger_timer_id)
	end
	--calcular a média
	function self.mean( t )
		local sum = 0
		local count= 0
		for k,v in pairs(t) do
			if type(v) == 'number' then
				sum = sum + v
				count = count + 1
			end
		end
		--retorno da media
		return (sum / count)
	end
	--calcular a distancia com o desvio padrão
	function self.standardDeviation( t )
		--variaveis para o calculo
		local m = 0
		local vm = 0
		local sum = 0
		local count = 0
		local result = 0
		--chamada da funcao para calcular a media
		m = self.mean(t)
		--calculo do desvio padrão
		for k,v in pairs(t) do
			if type(v) == 'number' then
				vm = v - m
				sum = sum + (vm * vm)
				count = count + 1
			end
		end
		result = math.sqrt(sum / (count-1))
		--insercao em tabela temporaria das distancia dentro da media com desvio padrao
		temp = {}
		for k,v in pairs(t) do
			if v >= (m - result) and v <= (m + result) then
				table.insert( temp, v )
			end
		end
		distance = 0
		for k,v in pairs(temp) do
			distance = distance + v
		end
		--distancia calculada com o desvio padrao
		distance = distance / #temp
	end
	--calculo da distancia, chamado ao retorno do echo
	function self.calculate()
		--tempo para o echo em segundos
		local echo_time = (time_stop - time_start) / 1000000
		--tempo de leitura valido
		if echo_time > 0 then
			--340 = velocidade do som, dividindo por 2 (envio e retorno)
			local distance = echo_time * 340 / 2
			table.insert(readings, distance)
		end
		--verificacao se ja realizou as leituras necessarias
		if #readings >= self.avg_readings then
			tmr.stop(trigger_timer_id)
			--chamada do calculo do desvio padrao
			self.standardDeviation(readings)
			--chamada da funcao de verificacao da vaga
			node.task.post(self.done_measuring)
		end
	end
	--retorno da situação da vaga
	function self.done_measuring()
		--insercao da distancia na tabela
		if distance >= 0 then
			table.insert(tab_distancias, distance)
		end
		--print("Distancia: "..string.format("%.3f", distance).." Leituras: "..#temp)
		--verificacao se a tabela contem 10 registros
		if #tab_distancias == 10 then
			count = 0
			--contagem das distancias que sao menores que a distancia maxima
			for k,v in pairs(tab_distancias) do
				if type(v) == 'number' then
					if v <= max_distance then
						count = count +1
					end
				end
			end
			if count > (#tab_distancias/2) then
				--se mais da metade das distancias, corresponde que a vaga esta ocupada, ligará o led e o post com true
				gpio.write(led, gpio.LOW)
				self.post("true")
			else
				--se menos da metade das distancias, corresponde que a vaga nao esta ocupada e o post com false
				gpio.write(led, gpio.HIGH);
				self.post("false")
			end
			tab_distancias = {}
		end
		--continuar as leituas (loop)
		if self.CONTINUOUS then
			node.task.post(self.measure)
		end
	end
	--função de callback do pino echo
	function self.echo_callback(level)
		--quando level for 1 o echo mandou o sinal
		if level == 1 then
			time_start = tmr.now()
		else
			time_stop = tmr.now()
			self.calculate()
		end
	end
	--envio do sinal
	function self.trigger()
		gpio.write(trig_pin, gpio.HIGH)
		tmr.delay(trigger_duration)
		gpio.write(trig_pin, gpio.LOW)
	end
	--função para dar o post no servlet
	function self.post(vaga)
		http.post("http://192.168.100.109:8080/VagasEstacionamento/ServerVagas?vaga="..vaga,
			nil, "",
			function(code, data)
				if (code < 0) then
					print("HTTP request failed")
				else
					print(code, data)
				end
			end)
	end
	--configuração dos pins
	gpio.mode(trig_pin, gpio.OUTPUT)
	gpio.mode(echo_pin, gpio.INT)
	--tempo do trigger
	tmr.register(trigger_timer_id, reading_interval, tmr.ALARM_AUTO, self.trigger)
	--configuracao da funcao a ser chamado no retorno do echo
	gpio.trig(echo_pin, "both", self.echo_callback)
	return self
end
