-- pastebin run LSdUFXvx
local client_manifest = "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/client.manifest"
local server_manifest = "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/server.manifest"

local args = { ... }
local manifest
if args[1] == "client" then
    manifest = client_manifest
elseif args[1] == "server" then
    manifest = server_manifest
else
    print(textutils.serialise(args))
    error("must pass 'client' or 'server' as first arg")
end

shell.run("wget", manifest, "manifest")
local file = fs.open(shell.resolve("./manifest"), "r")
manifest = file.readAll()
file.close()
fs.delete(shell.resolve("./manifest"))
local files = textutils.unserialise(manifest)

local auth_dir = shell.resolve("./email")
if not fs.isDir(auth_dir) then
    fs.makeDir(auth_dir)
end
shell.setDir(auth_dir)
local files_in_dir = fs.list(shell.resolve("."))
for _, v in pairs(files_in_dir) do
    if string.find(v, ".lua") then
        fs.delete(shell.resolve("./" .. v))
    end
end
for k, f in pairs(files) do
    shell.run("wget", f)
end
