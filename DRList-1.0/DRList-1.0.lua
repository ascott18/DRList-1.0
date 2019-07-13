--[[
Name: DRList-1.0
Description: Diminishing returns database. Fork of DRData-1.0.
Website: https://wow.curseforge.com/projects/drlist-1-0
Documentation: https://wardz.github.io/DRList-1.0/
Version: @project-version@
Dependencies: LibStub
License: MIT
]]

--- DRList-1.0
-- @module DRList-1.0
local MAJOR, MINOR = "DRList-1.0", 3
local Lib = assert(LibStub, MAJOR .. " requires LibStub."):NewLibrary(MAJOR, MINOR)
if not Lib then return end -- already loaded

-------------------------------------------------------------------------------
-- *** LOCALIZATIONS ARE AUTOMATICALLY GENERATED ***
-- Please see Curseforge localization page if you'd like to help translate.
-- https://wow.curseforge.com/projects/drlist-1-0/localization
local L = {}
Lib.L = L
L["DISARMS"] = "Disarms"
L["DISORIENTS"] = "Disorients"
L["INCAPACITATES"] = "Incapacitates"
L["KNOCKBACKS"] = "Knockbacks"
L["ROOTS"] = "Roots"
L["SILENCES"] = "Silences"
L["STUNS"] = "Stuns"
L["TAUNTS"] = "Taunts"

-- Classic
L["FEARS"] = "Fears"
L["HORRORS"] = "Horrors"
L["SHORT_ROOTS"] = "Roots (short)"
L["SHORT_STUNS"] = "Stuns (short)"
L["OPENER_STUN"] = "Opener stun" -- Cheap Shot & Pounce
L["MIND_CONTROL"] = GetSpellInfo(605)
L["CHARGE"] = GetSpellInfo(100)
L["ENTRAPMENT"] = GetSpellInfo(19184) or GetSpellInfo(19387)
L["FROST_SHOCK"] = GetSpellInfo(8056) or GetSpellInfo(196840)

-- luacheck: push ignore 542
local locale = GetLocale()
if locale == "deDE" then
    --@localization(locale="deDE", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "frFR" then
    --@localization(locale="frFR", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "itIT" then
    --@localization(locale="itIT", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "koKR" then
    --@localization(locale="koKR", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "ptBR" then
    --@localization(locale="ptBR", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "ruRU" then
    --@localization(locale="ruRU", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "esES" or locale == "esMX" then
    --@localization(locale="esES", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "zhCN" or locale == "zhTW" then
    --@localization(locale="zhCN", namespace="Categories", format="lua_additive_table", handle-unlocalized="ignore")@
end
-- luacheck: pop
-------------------------------------------------------------------------------

-- Whether we're running Classic or Retail WoW
Lib.gameExpansion = select(4, GetBuildInfo()) < 80000 and "classic" or "retail"

-- How long it takes for a DR to expire
Lib.resetTimes = {
    retail = {
        ["default"] = 18.3, -- Always 18s after patch 6.1. (We add extra 0.3s to account for latency)
        ["knockback"] = 10.3, -- Knockbacks are immediately immune and only DRs for 10s
    },

    classic = {
        ["default"] = 18.5, -- In classic this is between 15s and 20s, (first server batch tick after 15s have passed)
    },
}

-- List of all DR categories, english -> localized.
-- Note: unlocalized categories used for the API are always singular,
-- and localized user facing categories are always plural. (Except spell names in classic)
Lib.categoryNames = {
    retail = {
        ["disorient"] = L.DISORIENTS,
        ["incapacitate"] = L.INCAPACITATES,
        ["silence"] = L.SILENCES,
        ["stun"] = L.STUNS,
        ["root"] = L.ROOTS,
        ["disarm"] = L.DISARMS,
        ["taunt"] = L.TAUNTS,
        ["knockback"] = L.KNOCKBACKS,
    },

    classic = {
        ["incapacitate"] = L.INCAPACITATES,
        -- ["silence"] = L.SILENCES,
        ["stun"] = L.STUNS, -- controlled stun
        ["root"] = L.ROOTS, -- controlled root
        ["disarm"] = L.DISARMS,
        ["opener_stun"] = L.OPENER_STUN,
        ["short_stun"] = L.SHORT_STUNS, -- random proc stun, usually short
        ["short_root"] = L.SHORT_ROOTS,
        ["fear"] = L.FEARS,
        ["horror"] = L.HORRORS, -- short fears
        ["mind_control"] = L.MIND_CONTROL,
        ["frost_shock"] = L.FROST_SHOCK,
        ["entrapment"] = L.ENTRAPMENT,
        ["charge"] = L.CHARGE,
    },
}

-- Categories that have DR against mobs.
-- Note that only elites usually have root/taunt DR.
Lib.categoriesPvE = {
    retail = {
        ["taunt"] = L.TAUNTS,
        ["stun"] = L.STUNS,
        ["root"] = L.ROOTS,
    },

    classic = {
        ["stun"] = L.STUNS,
        ["opener_stun"] = L.OPENER_STUN,
        -- TODO: banish/MC?
    },
}

-- Successives diminished durations
Lib.diminishedDurations = {
    retail = {
        -- Decreases by 50%, immune at the 4th application
        ["default"] = { 0.50, 0.25 },
        -- Decreases by 35%, immune at the 5th application
        ["taunt"] = { 0.65, 0.42, 0.27 },
        -- Immediately immune
        ["knockback"] = {},
    },

    classic = {
        ["default"] = { 0.50, 0.25 },
    },
}

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Get table of all spells that DRs.
-- Key is the spellID, and value is the unlocalized DR category.
-- @see IterateSpellsByCategory
-- @treturn table {number=string}
function Lib:GetSpells()
    return Lib.spellList
end

--- Get table of all DR categories.
-- Key is unlocalized name used for API functions, value is localized name used for UI.
-- @treturn table {string=string}
function Lib:GetCategories()
    return Lib.categoryNames[Lib.gameExpansion]
end

--- Get table of all categories that DRs in PvE only.
-- Key is unlocalized name used for API functions, value is localized name used for UI.
-- Tip: you can combine :GetPvECategories() and :IterateSpellsByCategory() to get spellIDs only for PvE aswell.
-- @treturn table {string=string}
function Lib:GetPvECategories()
    return Lib.categoriesPvE[Lib.gameExpansion]
end

--- Get constant for how long a DR lasts.
-- @tparam[opt="default"] string category Unlocalized category name
-- @treturn number
function Lib:GetResetTime(category)
    return Lib.resetTimes[Lib.gameExpansion][category or "default"] or Lib.resetTimes[Lib.gameExpansion].default
end

--- Get unlocalized DR category by spell ID.
-- @tparam number spellID
-- @treturn ?string|nil The category name.
function Lib:GetCategoryBySpellID(spellID)
    return Lib.spellList[spellID]
end

--- Get localized category from unlocalized category name, case sensitive.
-- @tparam string category Unlocalized category name
-- @treturn ?string|nil The localized category name.
function Lib:GetCategoryLocalization(category)
    return Lib.categoryNames[Lib.gameExpansion][category]
end

--- Check if a category has DR against mobs.
-- Note that this is only for mobs, player pets have DR on all categories.
-- Also taunt, root & cyclone only have DR against special mobs.
-- See UnitClassification() and UnitIsQuestBoss().
-- @tparam string category Unlocalized category name
-- @treturn bool
function Lib:IsPvECategory(category)
    return Lib.categoriesPvE[Lib.gameExpansion][category] and true or false -- make sure bool is always returned here
end

--- Get next successive diminished duration
-- @tparam number diminished How many times the DR has been applied so far
-- @tparam[opt="default"] string category Unlocalized category name
-- @usage local reduction = DRList:GetNextDR(1) -- returns 0.50, half duration on debuff
-- @treturn number DR percentage in decimals. Returns 0 if max DR is reached or arguments are invalid.
function Lib:GetNextDR(diminished, category)
    local durations = Lib.diminishedDurations[Lib.gameExpansion][category or "default"]
    if not durations and Lib.categoryNames[Lib.gameExpansion][category] then
        -- Redirect to default when "stun", "root" etc is passed
        durations = Lib.diminishedDurations[Lib.gameExpansion]["default"]
    end

    return durations and durations[diminished] or 0
end

do
    local next = _G.next

    local function CategoryIterator(category, index)
        local newCat
        repeat
            index, newCat = next(Lib.spellList, index)
            if index and newCat == category then
                return index, category
            end
        until not index
    end

    --- Iterate through the spells of a given category.
    -- @tparam string category Unlocalized category name
    -- @usage for spellID in DRList:IterateSpellsByCategory("root") do print(spellID) end
    -- @warning Slow function, do not use for combat related stuff unless you cache results.
    -- @return Iterator function
    function Lib:IterateSpellsByCategory(category)
        assert(Lib.categoryNames[Lib.gameExpansion][category], "invalid category")
        return CategoryIterator, category
    end
end

-- keep same API as DRData-1.0 for easier transitions
Lib.GetCategoryName = Lib.GetCategoryLocalization
Lib.IsPVE = Lib.IsPvECategory
Lib.NextDR = Lib.GetNextDR
Lib.GetSpellCategory = Lib.GetCategoryBySpellID
Lib.IterateSpells = Lib.IterateSpellsByCategory
Lib.RESET_TIME = Lib.resetTimes[Lib.gameExpansion].default
Lib.spells = Lib.spellList
Lib.pveDR = Lib.categoriesPvE
