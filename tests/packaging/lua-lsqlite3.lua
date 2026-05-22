#!/usr/bin/env lua

-- Check if the module can be loaded
local status, sqlite3 = pcall(require, 'lsqlite3')

if not status then
  print("ERROR: Unable to load lsqlite3 module")
  print(sqlite3)
  os.exit(1)
end

print("✓ lsqlite3 module loaded successfully")

-- Open an in-memory database
local db = sqlite3.open_memory()

if not db then
  print("ERROR: Unable to open in-memory database")
  os.exit(1)
end

print("✓ In-memory database opened successfully")

-- Create a table
local rc = db:exec([[
  CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, value REAL);
]])

if rc ~= sqlite3.OK then
  print("ERROR: Unable to create table: " .. db:errmsg())
  db:close()
  os.exit(1)
end

print("✓ Table created successfully")

-- Insert rows
local stmt = db:prepare("INSERT INTO test (name, value) VALUES (?, ?)")

if not stmt then
  print("ERROR: Unable to prepare insert statement: " .. db:errmsg())
  db:close()
  os.exit(1)
end

local rows = {
  { "alpha", 1.1 },
  { "beta",  2.2 },
  { "gamma", 3.3 },
}

for _, row in ipairs(rows) do
  stmt:bind_values(row[1], row[2])
  rc = stmt:step()
  if rc ~= sqlite3.DONE then
    print("ERROR: Unable to insert row: " .. db:errmsg())
    stmt:finalize()
    db:close()
    os.exit(1)
  end
  stmt:reset()
end

stmt:finalize()
print("✓ Rows inserted successfully")

-- Query and verify data
local count = 0
for row in db:nrows("SELECT name, value FROM test ORDER BY id") do
  count = count + 1
  local expected = rows[count]
  if row.name ~= expected[1] or math.abs(row.value - expected[2]) > 1e-9 then
    print(string.format("ERROR: Row %d mismatch: got (%s, %f), expected (%s, %f)",
      count, row.name, row.value, expected[1], expected[2]))
    db:close()
    os.exit(1)
  end
end

if count ~= #rows then
  print(string.format("ERROR: Expected %d rows, got %d", #rows, count))
  db:close()
  os.exit(1)
end

print("✓ Data queried and verified successfully")

db:close()
print("\nAll tests passed - lua-lsqlite3 is working correctly!")
