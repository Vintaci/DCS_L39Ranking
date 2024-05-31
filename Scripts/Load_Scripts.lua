local script_path = "C:\\Users\\10462\\Saved Games\\DCS.openbeta\\Missions\\Scripts\\Buta\\DCS_L39Ranking\\Scripts\\"

local script_list =
{
    -- Load order must be correct
    "mist_4_5_122.lua",
    "Config.lua",
    "Utils.lua",
    "RankingSystem.lua",
}

local function load_scripts(path, list)
    for index, value in ipairs(list) do
        -- dofile(path .. value)
        local status, result = pcall(dofile, path .. value)
        if not status then
            dofile(lfs.writedir() .. "Missions\\Scripts\\Buta\\DCS_L39Ranking\\Scripts\\" .. value)
        end
    end
end

if lfs then
    script_path = lfs.writedir() .. "Missions\\Scripts\\Buta\\DCS_L39Ranking\\Scripts\\"

    env.info("Script Loader: LFS available, using relative script load path: " .. script_path)
else
    env.info("Script Loader: LFS not available, using default script load path: " .. script_path)
end
load_scripts(script_path, script_list)
-- local status, result = pcall(load_scripts,script_path, script_path)
