os.loadAPI("api/redString")
os.loadAPI("api/sovietProtocol")

PROTOCOL_CHANNEL = 137
local yum = sovietProtocol.Protocol:new("yum", PROTOCOL_CHANNEL, PROTOCOL_CHANNEL)

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
		if line ~= "" and line:sub(1,1) ~= "#" then
			local details = {}
			local split = redString.split(line)
			details.fileName = split[2]
			details.installLocation = split[3]
			ret[split[1]] = details
		end
	end
	f:close()
	return ret
end

function dispatchPackage(package, replyChannel)
	local message = ""
	local parts = parseIndex(getIndex(package))
	for name, comp in pairs(parts) do
		if name:find(":") then
			local s = redString.split(name, 2, ":")
			local method = s[1]
			if method == 'package' then
				message = message..method.." "..comp.fileName.."\n"
			elseif method == 'alias' then
				message = message..method.." "..comp.fileName.." "..comp.installLocation.."\n"
			end
		else
			message = message..name.." "..comp.installLocation.." ".."force\n"
		end
	end
	yum:send("package_list", package, message, replyChannel)
end

function dispatchComponant(package, componantName, replyChannel)
	local parts = parseIndex(getIndex(package))
	local componant = parts[componantName]
	if componant then
		local actualFile = fs.combine(getPackageRoot(package), componant.fileName)
		local f = fs.open(actualFile, "r")
		print("sending "..actualFile)
		if f then
			local file = f:readAll()
			f:close()
			yum:send(
				"file",
				componant.installLocation,
				file,
				replyChannel)
			return true
		else
			print("file "..actualFile.." does not exist")
		end
	end

	yum:send("error", "404", "File Not Found")
end

function dispatchFile(fileLocation, replyChannel)
	local f = fs.open(fileLocation, "r")
	print("sending "..fileLocation)
	if f then
		local file = f:readAll()
		f:close()
		yum:send(
			"file",
			fileLocation,
			file,
			replyChannel)
		return true
	else
		yum:send("error", "404", "File Not Found")
		return false
	end
end

print("Starting Yum Server")
while true do

	local replyChannel, request = yum:listen()

	if request.method == "install" then
		local package = request.id
		local componant = request.body

		if getIndex(package) then
			if componant then
				dispatchComponant(package, componant, replyChannel)
			else
				dispatchPackage(package, replyChannel)
			end
		else
			yum:send("error", "404", "Package Not Found", replyChannel)
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
			yum:send("package_list", "ALL", packageList, replyChannel)
		end
	end

	if request.method == "replicate" then
		if request.id == "list" then
			local files = ""
			for k, package in pairs(fs.list("packages")) do
				for k, file in pairs(fs.list("/packages/"..package)) do
					if file ~= ".git" then
						files = files.."/packages/"..package.."/"..file.."\n"
					end
				end
			end
			yum:send("file_list", "ALL", files, replyChannel)
		else
			dispatchFile(request.id, replyChannel)
		end
	end

end
