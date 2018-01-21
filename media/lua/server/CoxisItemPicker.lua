--[[
#########################################################################################################
#	@mod:		CoxisLootSpawn                                                                               #
#	@author: 	Dr_Cox1911					                                                                        #
#	@notes:		Many thanks to the PZ dev team and all the modders!                    	            				#
#	@notes:		For usage instructions check forum link below                                          			#
#	@link: 												       										#
#########################################################################################################
--]]

require 'CoxisUtil'
require "Items/ItemPicker"

CoxisLootSpawn = {}
CoxisLootSpawn.coxisDistribution = {}

CoxisLootSpawn.rollItem = function(containerDist, container, doItemContainer, character)
  if not isClient() and not isServer() then
          ItemPicker.player = getPlayer();
          character = getPlayer();
      end
  	if containerDist ~= nil and container ~= nil then
  --        print("roll item");
  		-- we're looking for the zombie density in this area, more zombie density mean more loots
  		local zombieDensity = 0;
  		local chunk = nil;
          if ItemPicker.player ~= nil and getWorld() then
              chunk = getWorld():getMetaChunk((ItemPicker.player:getX()/10), (ItemPicker.player:getY()/10));
          end
  		if chunk then
  			zombieDensity = chunk:getLootZombieIntensity();
          end
          if zombieDensity > ItemPicker.zombieDensityCap then
              zombieDensity = ItemPicker.zombieDensityCap;
          end
  		local alt = false;
  		local itemname = nil;
          local lucky = false;
          local unlucky = false;
          if ItemPicker.player and character then
              lucky = character:HasTrait("Lucky");
              unlucky = character:HasTrait("Unlucky");
          end
  		for m = 1, containerDist.rolls do
  			for i, k in ipairs(containerDist.items) do
  				if not alt then -- first we take the name of the item
  					itemname = k;
  -- 					print (itemname);
  				else -- next step is the random spawn part
                      local itemNumber = k;
                      if lucky then
                          itemNumber = itemNumber * 1.1;
                      end
                      if unlucky then
                          itemNumber = itemNumber * 0.9;
                      end
                      local lootModifier = CoxisLootSpawn.getLootModifier(itemname) or 0.6;
  					if ZombRand(10000) <= ((((itemNumber*100) * lootModifier) + (zombieDensity * 10))) then
  						-- make an item in the container of that type.
  						local item = ItemPicker.tryAddItemToContainer(container, itemname);
                          if not item then return; end
                          StashSystem.checkStashItem(item);
                          if container:getType() == "freezer" and instanceof(item, "Food") and item:isFreezing() then
                              item:freeze();
                          end
                          if instanceof(item, "Key") then
                              item:takeKeyId();
  --                            item:setName("Key " .. item:getKeyId());
                              -- no more than 2 keys per houses
                              if container:getSourceGrid() and container:getSourceGrid():getBuilding() and container:getSourceGrid():getBuilding():getDef() then
                                  if container:getSourceGrid():getBuilding():getDef():getKeySpawned() < 2 then
                                      container:getSourceGrid():getBuilding():getDef():setKeySpawned(container:getSourceGrid():getBuilding():getDef():getKeySpawned() + 1);
                                  else
                                      container:Remove(item);
                                  end
                              end
                          end
                          if WeaponUpgrades[item:getType()] then
                              ItemPicker.doWeaponUpgrade(item);
                          end
                          if not containerDist.noAutoAge then
  						    item:setAutoAge();
                          end
                          -- randomized used delta
                          if instanceof(item, "DrainableComboItem") and ZombRand(100) < 40 then
                              local maxUse = 1 / item:getUseDelta();
                              item:setUsedDelta(ZombRand(1,maxUse-1)*item:getUseDelta());
                          end
                          -- randomize weapon condition
                          if instanceof(item, "HandWeapon") and ZombRand(100) < 40 then
                              item:setCondition(ZombRand(1, item:getConditionMax()));
                          end
                          -- if the item is a container, we look to spawn item inside it
                          if(SuburbsDistributions[item:getType()]) then
                              if instanceof(item, "InventoryContainer") and doItemContainer and ZombRand(SuburbsDistributions[item:getType()].fillRand) == 0 then
                                  ItemPicker.rollContainerItem(item, character, SuburbsDistributions[item:getType()]);
                              end
                          end
  					end
  				end
  				alt = not alt;
  			end
  		end
  	end
end

CoxisLootSpawn.rollContainerItem = function(bag, character, containerDist)
    if containerDist then
        local zombieDensity = 0;
        local chunk = nil;
        if ItemPicker.player ~= nil then
            chunk = getWorld():getMetaChunk((ItemPicker.player:getX()/10), (ItemPicker.player:getY()/10));
        end
        if chunk then
            zombieDensity = chunk:getLootZombieIntensity();
        end
        if zombieDensity > ItemPicker.zombieDensityCap then
            zombieDensity = ItemPicker.zombieDensityCap;
        end
        local alt = false;
        local itemname = nil;
        for m = 1, containerDist.rolls do
            for i, k in ipairs(containerDist.items) do
                if not alt then -- first we take the name of the item
                    itemname = k;
                else -- next step is the random spawn part
                    local lootModifier = CoxisLootSpawn.getLootModifier(itemname) or 0.6;
                    if ZombRand(10000) <= ((((k*100) * lootModifier) + (zombieDensity * 10))) then
                        -- make an item in the container of that type
                        local item = ItemPicker.tryAddItemToContainer(bag:getItemContainer(), itemname);
                        if not item then return end
                        if instanceof(item, "Key") then
                            item:takeKeyId();
                            item:setName("Key " .. item:getKeyId());
                        end
                        item:setAutoAge();
                    end
                end
                alt = not alt;
            end
        end
    end
end

CoxisLootSpawn.getLootModifier = function(itemname)
  local item = ScriptManager.instance:FindItem(itemname)
    if not item then return; end
    local lootModifier = ZomboidGlobals.OtherLootModifier;
    local specialModifier = CoxisUtil.tableContainsKey(CoxisLootSpawn.coxisDistribution["SPECIALITEMS"], itemname);
    if specialModifier ~= nil then
      -- CoxisUtil.printDebug("CoxisLootSpawn", "Found specialModifier: "..tostring(specialModifier));
      return specialModifier
    end
    local categoryModifier = CoxisUtil.tableContainsKey(CoxisLootSpawn.coxisDistribution["CATEGORIES"], item:getTypeString());
    if categoryModifier ~= nil then
        -- CoxisUtil.printDebug("CoxisLootSpawn", "Found categoryModifier: "..tostring(categoryModifier));
        return categoryModifier
    end
    if item:getTypeString() == "Food" then
        lootModifier = ZomboidGlobals.FoodLootModifier;
    end
    if item:getTypeString() == "Weapon" or item:getTypeString() == "WeaponPart" or item:getDisplayCategory() == "Ammo" then
        lootModifier = ZomboidGlobals.WeaponLootModifier;
    end
    -- CoxisUtil.printDebug("CoxisLootSpawn", "Found no CoxisLootSpawn value, so using Sandbox setting: "..tostring(lootModifier));
    return lootModifier;
end

CoxisLootSpawn.readCoxisDistribution = function()
  CoxisUtil.printDebug("CoxisLootSpawn", "Trying to load CoxisDistribution...")
  CoxisLootSpawn.coxisDistribution = CoxisUtil.readINI("CoxisLootSpawn", "CoxisDistribution.ini");
  --if next(CoxisLootSpawn.coxisDistribution) then
  --  CoxisUtil.printDebug("CoxisLootSpawn", "Error loading CoxisDistribution!");
  --end
end

CoxisLootSpawn.initSP = function()
  if not isClient() and not isServer() then
    CoxisLootSpawn.readCoxisDistribution();
    ItemPicker.rollItem = CoxisLootSpawn.rollItem;
    ItemPicker.rollContainerItem = CoxisLootSpawn.rollContainerItem;
  end
end

CoxisLootSpawn.initMP = function()
  if isServer() then
    CoxisLootSpawn.readCoxisDistribution();
    ItemPicker.rollItem = CoxisLootSpawn.rollItem;
    ItemPicker.rollContainerItem = CoxisLootSpawn.rollContainerItem;
  end
end

Events.OnGameStart.Add(CoxisLootSpawn.initSP)
Events.OnGameBoot.Add(CoxisLootSpawn.initMP)
