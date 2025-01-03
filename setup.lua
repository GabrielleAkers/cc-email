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

local dir = shell.resolve("./email")
if not fs.isDir(dir) then
    fs.makeDir(dir)
end
shell.setDir(dir)
for k, f in pairs(files) do
    if fs.exists(shell.resolve("./" .. k .. ".lua")) then
        fs.delete(shell.resolve("./" .. k .. ".lua"))
    end
    shell.run("wget", f)
end
