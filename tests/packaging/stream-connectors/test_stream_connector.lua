dofile("tests/packaging/mocks.lua")

local install_dir = "/usr/share/centreon-broker/lua"
local ok = true

local handle = io.popen("find " .. install_dir .. " -maxdepth 1 -name '*.lua' -type f 2>/dev/null")
if not handle then
  print("Cannot list files in " .. install_dir)
  os.exit(1)
end

local files = {}
for filepath in handle:lines() do
  files[#files + 1] = filepath
end
handle:close()

if #files == 0 then
  print("No Lua files found in " .. install_dir)
  os.exit(1)
end

for _, filepath in ipairs(files) do
  local script = filepath:match("([^/]+)$")
  local loaded, load_err = pcall(dofile, filepath)
  if not loaded then
    print("✗ " .. script .. ": load error: " .. tostring(load_err))
    ok = false
  else
    local inited, init_err = pcall(init, {logfile = "/tmp/test-packaging.log"})
    if not inited then
      print("✗ " .. script .. ": init() error: " .. tostring(init_err))
      ok = false
    else
      local wrote, write_err = pcall(write, {})
      if not wrote then
        print("✗ " .. script .. ": write() error: " .. tostring(write_err))
        ok = false
      else
        print("✓ " .. script)
      end
    end
  end
end

if not ok then
  os.exit(1)
end
print("\nAll tests passed!")
