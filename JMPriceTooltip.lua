
---
--- JMPriceTooltip
---

--[[

    Variable declaration

 ]]

---
-- @field name
-- @field savedVariablesName
--
local Config = {
    name = 'JMPriceTooltip',
    savedVariablesName = 'JMPriceTooltipSavedVariables',
}

local function resolveItemLinkFromControl(control)
    if not control.dataEntry or not control.dataEntry.data then
        return false
    end

    local parent = control:GetParent()
    if not parent then
        return false
    end

    local parentName = parent:GetName()
    if parentName.find(parentName, 'BackpackContents') then
        return GetItemLink(control.dataEntry.data.bagId, control.dataEntry.data.slotIndex, LINK_STYLE_DEFAULT)
    end

    if parentName == 'ZO_StoreWindowListContents' then
        return GetStoreItemLink(control.dataEntry.data.slotIndex, LINK_STYLE_DEFAULT)
    end

    if parentName == 'ZO_TradingHouseItemPaneSearchResultsContents' then
        if control.dataEntry.data.timeRemaining <= 0 then
            return false
        end

        return GetTradingHouseSearchResultItemLink(control.dataEntry.data.slotIndex)
    end

    if parentName == 'ZO_TradingHousePostedItemsListContents' then
        return GetTradingHouseListingItemLink(control.dataEntry.data.slotIndex)
    end

    if parentName == 'ZO_BuyBackListContents' then
        return GetBuybackItemLink(control.dataEntry.data.slotIndex)
    end

    return false
end

local lastControl
local lastItemLink

local function updateToolTip(itemLink, tooltip)
    if itemLink == lastItemLink then
        return
    end
    lastItemLink = itemLink


--    local array = {ZO_LinkHandler_ParseLink(itemLink) }
--    array[20] = 0 -- Crafted
--    array[22] = 0 -- Stolen
--    array[23] = 0 -- Condition
--    local code = table.concat(array, '_')
--    d(code)



    local _, _, _, itemId = ZO_LinkHandler_ParseLink(itemLink)



--    d('---start')
--    local saleList = JMGuildSaleHistoryTracker.getSalesFromItemId(itemId)
--    for _, sale in ipairs(saleList) do
--        local array = {ZO_LinkHandler_ParseLink(itemLink) }
--        array[20] = 0 -- Crafted
--        array[22] = 0 -- Stolen
--        array[23] = 0 -- Condition
--        local code = table.concat(array, '_')
--        d(code)
--    end
--    d('---end')


    local priceSuggestion = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.MEDIAN
    )

    if not priceSuggestion.hasPrice then
        return
    end

    ZO_Tooltip_AddDivider(tooltip)
    tooltip:AddLine('Last sale was ' .. ZO_FormatDurationAgo(GetTimeStamp() - priceSuggestion.lastSaleTimestamp))
    tooltip:AddLine('Sell for ' .. priceSuggestion.bestPrice.pricePerPiece .. ' in ' .. priceSuggestion.bestPrice.guildName .. ' (' .. priceSuggestion.bestPrice.saleCount .. ')')
    ZO_Tooltip_AddDivider(tooltip)

    local newestPrice = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.NEWEST
    )

    for guildName, data in pairs(newestPrice.suggestedPriceForGuild) do
        local itemList = JMTradingHouseSnapshot.getByGuildAndItem(guildName, itemId)
        local cheapestPricePerPiece = '-'
        if itemList and #itemList > 0 then
            table.sort(itemList, function(a, b)
                return a.pricePerPiece < b.pricePerPiece
            end)
            cheapestPricePerPiece = itemList[1].pricePerPiece
        end

        tooltip:AddLine('Newest: ' .. data.pricePerPiece .. ' in ' .. guildName .. ' (' .. data.saleCount .. ') ' .. ZO_FormatDurationAgo(GetTimeStamp() - data.saleTimestamp) .. ' (CH: ' .. cheapestPricePerPiece .. ')')
    end

    local cheapestPrice = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.CHEAPEST
    )
    local expensivePrice = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.MOST_EXPENSIVE
    )
    local averagePrice = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.AVERAGE
    )
    local normalPrice = JMPriceSuggestion.getPriceSuggestion(
        itemLink,
        JMPriceSuggestion.algorithms.NORMAL
    )

    ZO_Tooltip_AddDivider(tooltip)
    tooltip:AddLine('Most expensive: ' .. expensivePrice.bestPrice.pricePerPiece .. ' in ' .. expensivePrice.bestPrice.guildName .. ' (' .. expensivePrice.bestPrice.saleCount .. ')')
    tooltip:AddLine('Cheapest: ' .. cheapestPrice.bestPrice.pricePerPiece .. ' in ' .. cheapestPrice.bestPrice.guildName .. ' (' .. cheapestPrice.bestPrice.saleCount .. ')')
    tooltip:AddLine('Average: ' .. averagePrice.bestPrice.pricePerPiece .. ' in ' .. averagePrice.bestPrice.guildName .. ' (' .. averagePrice.bestPrice.saleCount .. ')')
    tooltip:AddLine('Normal: ' .. normalPrice.bestPrice.pricePerPiece .. ' in ' .. normalPrice.bestPrice.guildName .. ' (' .. normalPrice.bestPrice.saleCount .. ')')
end

local function onTooltipHide()
    lastItemLink = nil
    lastControl = nil
end

--[[

    Initialize

 ]]

---
-- Start of the addon
--
local function Initialize()

    ZO_PreHookHandler(ItemTooltip, "OnUpdate", function()
        local control = moc()
        if control == lastControl then
            return
        end
        lastControl = control

        local itemLink = resolveItemLinkFromControl(control)
        if itemLink then
            updateToolTip(itemLink, ItemTooltip)
        end
    end)
    ZO_PreHookHandler(ItemTooltip, "OnHide", function()
        onTooltipHide()
    end)

    ZO_PreHookHandler(PopupTooltip, "OnUpdate", function()
        if PopupTooltip.lastLink then
            updateToolTip(PopupTooltip.lastLink, PopupTooltip)
        end
    end)
    ZO_PreHookHandler(PopupTooltip, "OnHide", function()
        onTooltipHide()
    end)
end

--[[

    Events

 ]]

--- Adding the initialize handler
EVENT_MANAGER:RegisterForEvent(
    Config.name,
    EVENT_ADD_ON_LOADED,
    function (_, addonName)
        if addonName ~= Config.name then
            return
        end

        Initialize()
        EVENT_MANAGER:UnregisterForEvent(Config.name, EVENT_ADD_ON_LOADED)
    end
)
