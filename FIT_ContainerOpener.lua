FIT_ContainerOpener = {}
FIT_ContainerOpener.namespaceId = "FIT_ContainerOpener"
FIT_ContainerOpener.version = "1"
FIT_ContainerOpener.author = "@token419"
FIT_ContainerOpener.Containers = {}
FIT_ContainerOpener.vars = {}
FIT_ContainerOpener.vars.AutoCloseIfMaxTransmutes = true
FIT_ContainerOpener.vars.AutoCloseIfAlreadyCollected = true
FIT_ContainerOpener.vars.AutoLootItems = true
FIT_ContainerOpener.vars.busy = false
FIT_ContainerOpener.vars.delay = 400 -- Was 2000 maybe higher?
FIT_ContainerOpener.vars.HasNewContainers = false
FIT_ContainerOpener.vars.inHUD = true

function FIT_ContainerOpener.UseItem(bag_id, slotIndex)
  if IsProtectedFunction("UseItem") then
    local result = CallSecureProtected("UseItem", bag_id, slotIndex)
  else
    UseItem(bag_id, slotIndex)
  end
end

function FIT_ContainerOpener.ProcessNewContainer()
  if FIT_ContainerOpener.vars.inHUD == true and FIT_ContainerOpener.vars.busy == false then
    FIT_ContainerOpener.vars.busy = true
    local containers = FIT_ContainerOpener.Containers -- This is so if the list is updated while we're iterating, it doesn't do weird things
    for slotIndex, value in pairs(containers) do
      if value.isNew == true then
        -- d("Processing: (Slot:"..slotIndex..") "..value.itemLink)
        FIT_ContainerOpener.Containers[slotIndex].isNew = false
        FIT_ContainerOpener.vars.busy = false
        FIT_ContainerOpener.UseItem(BAG_BACKPACK, slotIndex)
        return true
      end
    end
    FIT_ContainerOpener.vars.HasNewContainers = false
    FIT_ContainerOpener.vars.busy = false
  end
end

-- EVENT_INVENTORY_SINGLE_SLOT_UPDATE sends us (number eventCode, Bag bagId, number slotId, boolean isNewItem, ItemUISoundCategory itemSoundCategory, number inventoryUpdateReason, number stackCountChange)
function FIT_ContainerOpener.onSingleSlotUpdate(eventCode, bagId, slotId, isNewItem, ItemUISoundCategory, inventoryUpdateReason, stackCountChange)
  if isNewItem == true and bagId == BAG_BACKPACK then
    local ItemType, SpecializedItemType = GetItemType(bagId, slotId)
    local itemLink = GetItemLink(bagId, slotId)
    -- d(tostring(isNewItem).." New Item in Batckpack: "..itemLink)
    if ItemType == ITEMTYPE_CONTAINER then
      -- d("onSingleSlotUpdate Is Container: "..itemLink)
      if FIT_ContainerOpener.Containers[slotId] == nil then
        FIT_ContainerOpener.Containers[slotId] = {}
      end
      FIT_ContainerOpener.Containers[slotId].isNew = true
      FIT_ContainerOpener.Containers[slotId].itemLink = itemLink
      FIT_ContainerOpener.vars.HasNewContainers = true
    end
  end
end

function FIT_ContainerOpener.UpdateContainers()
  for slotIndex=0, GetBagSize(BAG_BACKPACK)-1 do
    local itemType = GetItemType(BAG_BACKPACK, slotIndex)
    local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
    if itemType == ITEMTYPE_CONTAINER then
      d(slotIndex.." "..itemLink)
      if FIT_ContainerOpener.Containers[slotIndex] == nil then
        FIT_ContainerOpener.Containers[slotIndex] = {}
        FIT_ContainerOpener.Containers[slotIndex].isNew = true
        FIT_ContainerOpener.Containers[slotIndex].itemLink = itemLink
        FIT_ContainerOpener.vars.HasNewContainers = true
      end
    end
  end

  FIT_ContainerOpener.ProcessNewContainer()

end

function FIT_ContainerOpener.HudWatcher(oldState, newState)
  if newState==SCENE_SHOWN then
    FIT_ContainerOpener.vars.inHUD = true
    if FIT_ContainerOpener.vars.HasNewContainers == true then
      -- d("Hud: true - HasNewContainers: true")
      zo_callLater(FIT_ContainerOpener.ProcessNewContainer, FIT_ContainerOpener.vars.delay)
    end
  elseif newState==SCENE_HIDDEN then
    FIT_ContainerOpener.vars.inHUD = false
  end
end

function FIT_ContainerOpener.SceneWatcher(oldState, newState)
  -- EVENT_MANAGER:UnregisterForEvent("TOKEN_Event", EVENT_LOOT_UPDATED)
  local hasAlreadyCollectedItems = false
  if newState==SCENE_SHOWN then

    for slotIndex = 1, GetNumLootItems() do
      -- Returns: integer lootId, string name, textureName icon, integer count, integer quality, integer value, bool isQuest, bool stolen, LootItemType lootType
      local lootId, name, icon, count, quality, value, isQuest, stolen, lootType = GetLootItemInfo(slotIndex)

      if FIT_ContainerOpener.vars.AutoLootItems == true and lootType == LOOT_TYPE_ITEM then
        local itemLink = GetLootItemLink(lootId)
        local itemType, specializedType = GetItemLinkItemType(itemLink)
        -- d("Has (lootId: "..lootId.."): "..itemLink.." (x"..count..")")
        LootItemById(lootId)
      end

    end

    if FIT_ContainerOpener.vars.AutoCloseIfMaxTransmutes == true then
      local currentCurrency = GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)
      local maxCurrency = GetMaxPossibleCurrency(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)
      local containercurrency = GetLootCurrency(CURT_CHAOTIC_CREATIA)

      if (currentCurrency + containercurrency) > maxCurrency then
        -- d("Auto Closed due to Transmutes: Current: ("..currentCurrency..") + Container: ("..containercurrency..") > Max: ("..maxCurrency..")")
        zo_callLater(EndLooting, 500)
      end
    end

-- LootMoney()
-- https://wiki.esoui.com/Globals#CurrencyType
-- LootCurrency(CurrencyType type)





  elseif newState==SCENE_HIDING then
    -- d("loot Hiding")
  elseif newState==SCENE_HIDDEN then
    -- d("loot Hidden")
  end
end



local function initialize(eventCode, name)
  if name ~= FIT_ContainerOpener.namespaceId then return end
  -- Stop checking for addons once we're loaded
  EVENT_MANAGER:UnregisterForEvent(FIT_ContainerOpener.namespaceId, EVENT_ADD_ON_LOADED )


  SCENE_MANAGER:GetScene("loot"):RegisterCallback("StateChange", FIT_ContainerOpener.SceneWatcher)
  SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", FIT_ContainerOpener.HudWatcher)
  EVENT_MANAGER:RegisterForEvent(FIT_ContainerOpener.namespaceId .. "_LOOT", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, FIT_ContainerOpener.onSingleSlotUpdate)

  -- SLASH_COMMANDS["/listcontainers"] = FIT_ContainerOpener.UpdateContainers
  -- SLASH_COMMANDS["/usecontainer"] = FIT_ContainerOpener.UseItem

end -- End initialize

EVENT_MANAGER:RegisterForEvent(FIT_ContainerOpener.namespaceId, EVENT_ADD_ON_LOADED, initialize )