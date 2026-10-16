local Structs = {}

for k, v in require("./StructsPublic") do
	Structs[k] = v
end

for k, v in require("./StructsInternal") do
	Structs[k] = v
end

return Structs
