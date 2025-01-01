-- pastebin run fu4uhmQP

local client_files = {
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/client.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/deque.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/shared.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/ui.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-email/refs/heads/main/utils.lua"
}

local email_dir = shell.resolve("./email")
if not fs.isDir(email_dir) then
    fs.makeDir(email_dir)
end
shell.setDir(email_dir)
for _, f in pairs(client_files) do
    shell.run("wget", f)
end

shell.run("client.lua")
