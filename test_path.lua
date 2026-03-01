local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
print("git_root: [" .. git_root .. "]")

local projects_file = vim.fn.expand("~/.gemini/projects.json")
local f = io.open(projects_file, "r")
local content = f:read("*all")
f:close()
local projects_data = vim.json.decode(content)
local project_name = projects_data.projects[git_root]
print("project_name: [" .. tostring(project_name) .. "]")
