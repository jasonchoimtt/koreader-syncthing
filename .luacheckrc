unused_args = false
std = "luajit"
-- ignore implicit self
self = false

globals = {
    "G_reader_settings",
    "G_defaults",
    "table.pack",
    "table.unpack",
}

read_globals = {
    "_ENV",
}

-- 211 - Unused local variable
-- 631 - Line is too long
ignore = {
    "211/__*",
    "631",
}
