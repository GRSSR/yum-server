os.loadAPI("api/redString")
os.loadAPI("api/sovietProtocol")

PROTOCOL_CHANNEL = 137
sovietProtocol.init(PROTOCOL_CHANNEL, PROTOCOL_CHANNEL)
modem = peripheral.find("modem")
sovietProtocol.setDebugLevel(0)

function getIndex(package)
	local index = fs.combine(fs.combine("packages", package), "index")
	if fs.exists(index) then 
		return index
	else
		return false
	end
end

function getPackageRoot(package)
	return fs.combine("packages", package)
end

function parseIndex(index)
	local f = io.open(index, "r")
	local ret = {}
	for line in f:lines() do
		local details = {}
		local split = redString.split(line)
		details.fileName = split[2]
		details.installLocation = split[3]
		ret[split[1]] = details
	end
	f:close()
	return ret
end

function dispatchPackage(package, replyChannel)
	local message = ""
	local parts = parseIndex(getIndex(package))
	for name, comp in pairs(parts) do 
		print(comp)
		print(comp.installLocation)
		message = message..name.." "..comp.installLocation.." ".."force\n"
	end
	sovietProtocol.send(replyChannel, PROTOCOL_CHANNEL, "package_list", package, message)
end

function dispatchFile(package, componantName, replyChannel)
	local parts = parseIndex(getIndex(package))
	local componant = parts[componantName]
	if componant then
		local actualFile = fs.combine(getPackageRoot(package), componant.fileName)
		local f = fs.open(actualFile, "r")
		print("sending "..actualFile)
		if f then
			local file = f:readAll()
			f:close()
			sovietProtocol.send(
				replyChannel,
				PROTOCOL_CHANNEL,
				"file",
				componant.installLocation,
				file)
			return true
		end
	end

	sovietProtocol.send(replyChannel, PROTOCOL_CHANNEL, "error", "404", "File Not Found")
end

print("Starting Yum Server")
while true do

	local replyChannel, request = sovietProtocol.listen()

	if request.method == "install" then
		local package = request.id
		local componant = request.body

		if getIndex(package) then
			if componant then
				dispatchFile(package, componant, replyChannel)
			else
				dispatchPackage(package, replyChannel)
			end
		else
			sovietProtocol.send(replyChannel, PROTOCOL_CHANNEL, "error", "404", "Package Not Found")
		end
	end

	if request.method == "list" then
		local package = request.id
		if package then
			dispatchPackage(package, replyChannel)
		else
			local packageList = ""
			for k, package in pairs(fs.list("packages")) do
				if getIndex(package) then
					packageList = packageList..package.."\n"
				end
			end
			sovietProtocol.send(replyChannel, PROTOCOL_CHANNEL, "package_list", "ALL", packageList)
		end
	end

end