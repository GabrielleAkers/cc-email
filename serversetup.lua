-- pastebin run dtfq1Hei

local client_files = {
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/server.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/deque.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/shared.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/utils.lua"
}

local email_dir = shell.resolve("./email_server")
if not fs.isDir(email_dir) then
    fs.makeDir(email_dir)
end
shell.setDir(email_dir)
for _, f in pairs(client_files) do
    shell.run("wget", f)
end

term.clear()
term.write("Starting server...")
shell.run("server.lua")
