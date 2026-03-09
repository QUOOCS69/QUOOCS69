if not game:IsLoaded() then game.Loaded:Wait() end
if game.PlaceId ~= 4490140733 then return end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"):WaitForChild("Library"))
assert(Library, "Oopps! Library has not been loaded. Maybe try re-joining?") 
while not Library.Loaded do wait() end

function GetPath(...)
    local path = {...}
    local oldPath = Library
	if path and #path > 0 then
		for _,v in ipairs(path) do
			oldPath = oldPath[v]
		end
	end
    return oldPath
end 

-------
-------------------------//
--// Libraries
-------------------------//
local Food = GetPath("Food")
local Entity = GetPath("Entity")
local Customer = GetPath("Customer")
local Waiter = GetPath("Waiter")
local Appliance = GetPath("Appliance")
local Bakery = GetPath("Bakery")
local Gamepasses = GetPath("Gamepasses")
local Network = GetPath("Network")

------------------//
--// Variables
-------------------------//
local StartTick = tick()

local Player = Players.LocalPlayer
local StoreTeleports = {}
local PlayerTeleports = {}
local Wells = {"101","49","50"}
local Slots = {"57"}
local FurnituresCooldowns = {}

-- Settings Variables
local FastWaiter = false
local HyperFood = false
local AutoGift = false
local FastOrder = false
local FastNPC = false
local TeleportNPC = false
local NPCSpeed = 100
local AutoInteract = false
local AutoBuyWorkers = false
local AutoBlacklist = false
local AutoCloseRestaurant = false
local AutoCloseEvery = 600
local LastTimeClose = 0

--// Force better customer
local ForceCustomers = false
local ForceVIP = false
local ForcePirate = false
local ForceYoutuber = false
local ForceHeadless = false
local ForceCorruptedVIP = false
local ForceSanta = false
local ForceElf = false
local ForceLifeguard = false
local ForceAlien = false
local ForcePrincess = false
local ForceSuperHero = false

local InstantCook = false
local InstantEat = false
local InstantWash = false

local IS_DEV_MODE = true
local PRINT_NETWORK = false

local OptimizedMode = false

-------------------------//
--// Delta X HTTP Request Helper
-------------------------//
local function DeltaRequest(url, method, headers, body)
	-- Delta X uses `request` or `http_request`
	local reqFunc = (syn and syn.request) or (http and http.request) or http_request or request
	if not reqFunc then
		warn("No HTTP request function found!")
		return nil
	end
	local success, result = pcall(reqFunc, {
		Url = url,
		Method = method or "GET",
		Headers = headers or {},
		Body = body or ""
	})
	if success then
		return result
	else
		warn("HTTP Request failed: " .. tostring(result))
		return nil
	end
end

-------------------------//
--// Overwrite Functions
-------------------------//
local Original_EntityNew = Entity.new
Entity.new = function(id, uid, entityType, p4, p5)
	local entity = Original_EntityNew(id, uid, entityType, p4, p5)

	if entityType == "Customer" and OptimizedMode then
		pcall(function()
			if entity and entity.model and entity.model:FindFirstChild("Humanoid") then
				entity.model.Humanoid:RemoveAccessories()
			end
		end)
	end
	return entity
end


local Original_StartWashingDishes = Appliance.StartWashingDishes
Appliance.StartWashingDishes = function(appliance)
	if not InstantWash then Original_StartWashingDishes(appliance) return end
	
	if appliance.stateData.isWashingDishes then
		return
	end
	
	appliance.stateData.isWashingDishes = true

	coroutine.wrap(function()
		while not appliance.isDeleted and appliance.stateData.numberDishes > 0 do
			appliance.stateData.dishStartTime = tick()
			appliance.stateData.dishwasherUI.Enabled = true
			wait(0.05)
			appliance:RemoveDish()	
		end
		
		if appliance.isDeleted then
			return
		end
		
		if not appliance.isDeleted then
			appliance.stateData.dishwasherUI.Frame.DishProgress.Bar.Size = UDim2.new(0, 0, 1, 0)
			appliance.stateData.dishwasherUI.Enabled = false
		end
		
		appliance.stateData.isWashingDishes = false
		if appliance.stateData.washingLoopSound then
			appliance.stateData.washingLoopSound:Destroy()
			appliance.stateData.washingLoopSound = nil
		end
	end)()
end

local Original_ChangeToReadyToExitState = Customer.ChangeToReadyToExitState
Customer.ChangeToReadyToExitState = function(customer, forceToLeaveATip)
	if InstantEat then 
		Original_ChangeToReadyToExitState(customer, true) 
	else 
		Original_ChangeToReadyToExitState(customer, forceToLeaveATip) 
	end
end

local Original_AddCustomersToQueueIfNecessary = Bakery.AddCustomersToQueueIfNecessary
Bakery.AddCustomersToQueueIfNecessary = function(bakery, kickCustomerIfNecessary, UIDBatch)
	if not ForceCustomers then return Original_AddCustomersToQueueIfNecessary(bakery, kickCustomerIfNecessary, UIDBatch) end
	
	if #bakery.customerQueue >= 4 then
		return 0
	end

	local firstFloor = bakery.floors[1]

	local selectedTable, selectedSeatGroup
	local indices = Library.Functions.RandomIndices(Library.Variables.MyBakery.floors)
	for _, index in ipairs(indices) do
		if index and tonumber(index) and index > 0 then 
			local floor = bakery.floors[index]
			selectedTable, selectedSeatGroup = floor:GetAvailableSeatGroupings()
			if selectedTable and selectedSeatGroup then
				break
			end
		end
	end
	
	if not (selectedTable and selectedSeatGroup) then
		if kickCustomerIfNecessary then
			local didKickCustomer = false
			for _, floor in ipairs(bakery.floors) do
				for _, customer in ipairs(floor.customers) do
					if customer.state ~= "ReadyToExit" then
						customer:ForcedToLeave()
						didKickCustomer = true
						break
					end
				end
				if didKickCustomer then
					break
				end
			end
			
		end
		
		return 0
	end
	local queueEntry = {}
	
		
	local didPlayVIPCustomerSound = false

	local vipOverride = {}	
	local pirateOverride = {}
	local youtuberOverride = {}
	local shadowOverride = {}
	local corruptedVIPOverride = {}
	local santaOverride = {}
	local elfOverride = {}
	local treeTable = {}
	local lifeguardOverride = {}
	local alienOverride = {}
	local princessOverride = {}
	local superheroOverride = {}
	
	-- create customers to fill this seat grouping
	local containsGhostOrSpecial = false
	for i, seatGroup in pairs(selectedSeatGroup) do
		local seat = seatGroup
		local tabl = selectedTable
		
		local hasAlreadyBeenForced = false

		local floor = bakery.floors[seat.floorLevel]
		for _, entity in ipairs(floor:GetEntitiesFromClassAndSubClass("Furniture", "ChristmasTree")) do
			local dist = math.sqrt(math.pow(entity.xVoxel - seat.xVoxel, 2) + math.pow(entity.zVoxel - seat.zVoxel, 2))
			if dist < 4*math.sqrt(2)+0.1 then
				treeTable[i] = true
				break
			end
		end
		

		local overrideUID = nil
			
		--// ROYAL TABLE
		if not hasAlreadyBeenForced and ForceVIP then
			if seat.ID == "43" and tabl.ID == "44" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "43" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "44" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "13"
				vipOverride[i] = overrideUID
			end
		end
		
		--// ROYAL HALLOWEEN TABLE
		if not hasAlreadyBeenForced and ForceHeadless then
			if seat.ID == "98" and tabl.ID == "99" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "98" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "99" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end

			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "26"
				corruptedVIPOverride[i] = overrideUID
			end
		end
		
		--// LIFEGUARD
		if not hasAlreadyBeenForced and ForceLifeguard then
			if seat.ID == "118" and tabl.ID == "119" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "118" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "119" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "29"
				lifeguardOverride[i] = overrideUID
			end
		end
		
		--// ALIEN
		if not hasAlreadyBeenForced and ForceAlien then
			if seat.ID == "120" and tabl.ID == "121" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "120" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "121" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "30"
				alienOverride[i] = overrideUID	
			end
		end
		
		-- FIX: removed reference to undefined variable v219, replaced with seat.UID
		if not hasAlreadyBeenForced and ForcePrincess then
			if seat.ID == "124" and tabl.ID == "125" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "124" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID  -- FIXED: was v219.UID (undefined variable)
			elseif tabl.ID == "125" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "31"
				princessOverride[i] = overrideUID
			end
		end

		-- FIX: added ForceSuperHero check (was missing), removed undefined v219
		if not hasAlreadyBeenForced and ForceSuperHero then
			if seat.ID == "127" and tabl.ID == "128" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "127" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID  -- FIXED: was v219.UID (undefined variable)
			elseif tabl.ID == "128" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "32"
				superheroOverride[i] = overrideUID
			end
		end
		
		-- PIRATE
		if not hasAlreadyBeenForced and ForcePirate then
			if seat.ID == "74" and tabl.ID == "75" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "74" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "75" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "21"
				pirateOverride[i] = overrideUID
			end
		end
		
		--// YOUTUBER
		if not hasAlreadyBeenForced and ForceYoutuber then
			if seat.ID == "84" and tabl.ID == "85" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "84" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "85" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "22"
				youtuberOverride[i] = overrideUID
			end
		end
		
		-- SANTA
		if not hasAlreadyBeenForced and ForceSanta then
			if seat.ID == "108" and true then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
				UIDBatch[i].ID = "27"
				santaOverride[i] = overrideUID
			end
		end
		
		-- ELF
		if not hasAlreadyBeenForced and ForceElf then 
			if seat.ID == "110" and tabl.ID == "111" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif seat.ID == "110" then
				hasAlreadyBeenForced = true
				overrideUID = seat.UID
			elseif tabl.ID == "111" then
				hasAlreadyBeenForced = true
				overrideUID = tabl.UID
			end
			
			if hasAlreadyBeenForced then
				UIDBatch[i].ID = "28"
				elfOverride[i] = overrideUID
			end
		end
	end
	
	local originalResponse  = {Original_AddCustomersToQueueIfNecessary(bakery, kickCustomerIfNecessary, UIDBatch)}

	--// EDIT THE ORIGINAL RESPONSE
	originalResponse[1] = #selectedSeatGroup
	originalResponse[2] = vipOverride
	originalResponse[3] = pirateOverride
	originalResponse[4] = youtuberOverride
	originalResponse[5] = shadowOverride
	originalResponse[6] = corruptedVIPOverride
	originalResponse[7] = santaOverride
	originalResponse[8] = elfOverride
	originalResponse[9] = treeTable
	originalResponse[10] = lifeguardOverride
	originalResponse[11] = alienOverride
	originalResponse[12] = princessOverride
	originalResponse[13] = superheroOverride
	
	return unpack(originalResponse)
	
end
local Original_NetworkInvoke = Network.Invoke
Network.Invoke = function(...)
	local args = {...}

	if args[1] then
		if args[1] == "WaitForCookTime" and InstantCook then
			coroutine.wrap(function() Original_NetworkInvoke(unpack(args)) end)()
			return true
		elseif args[1] == "WaitForEatTime" and InstantEat then
			coroutine.wrap(function() Original_NetworkInvoke(unpack(args)) end)()
			return true
		end
	end
	
	if IS_DEV_MODE and PRINT_NETWORK then 
		local stringBuilder = "Network.Invoke: "
		for _, n in pairs(args) do 
			stringBuilder = stringBuilder .. " | " .. tostring(n)
		end
		print(stringBuilder)
	end
	
	return Original_NetworkInvoke(unpack(args))
end

Waiter.StartActionLoop = function(waiter)
	coroutine.wrap(function()
		while not waiter.isDeleted do
			Waiter.PerformAction(waiter)
			-- Wait for next waiter action
			if FastWaiter then
				wait()
			else
				wait(1.5)
			end
		end
	end)()
end

local Original_UpdateCustomerQueuePositioning = Bakery.UpdateCustomerQueuePositioning
Bakery.UpdateCustomerQueuePositioning = function(bakery)
	Original_UpdateCustomerQueuePositioning(bakery)
	if not FastWaiter then return end
	
	-- this fix stuck on door problem?
	wait(0.05)
	
	if bakery:IsMyBakery() then
		for _, groupQueue in ipairs(bakery.customerQueue) do 
			if groupQueue and groupQueue[1] then 
				local entity = groupQueue[1]
				entity:StopGroupEmoji()
				entity:CleanupGroupInteract()
				bakery:SeatQueuedCustomerGroup(entity)
				bakery:UpdateCustomerQueuePositioning()
			end
		end
	end
end

local Original_PerformAction = Waiter.PerformAction
Waiter.PerformAction = function(waiter)
	if not FastWaiter then Original_PerformAction(waiter) return end
	
	if waiter.state == "Idle" then
		local waiterFunctions = { Waiter.CheckForCustomerOrder, Waiter.CheckForFoodDelivery, Waiter.CheckForDishPickup }

		for _, action in ipairs(Library.Functions.RandomizeTable(waiterFunctions)) do 
			if action(waiter) then
				break
			end
		end
	end
end

local Original_CheckForDishPickup = Waiter.CheckForDishPickup
Waiter.CheckForDishPickup = function(waiter)
	if not FastWaiter then return Original_CheckForDishPickup(waiter) end
	
	local myFloor = waiter:GetMyFloor()
	local selectedDishChair, selectedDishChairFloor = nil
	
	local indices = Library.Functions.RandomIndices(Library.Variables.MyBakery.floors)
	
	if true then
		for i, index in ipairs(indices) do
			if index == myFloor.floorLevel then
				table.remove(indices, i)
				table.insert(indices, 1, myFloor.floorLevel)
				break
			end
		end
	end
	
	for _, index in ipairs(indices) do
		local thisFloor = Library.Variables.MyBakery.floors[index]
		local dishIndices = Library.Functions.RandomIndices(thisFloor.dishChairs)
		for _, dishIndex in ipairs(dishIndices) do
			local dishChair = thisFloor.dishChairs[dishIndex]
			if dishChair.isDeleted or dishChair.stateData.flaggedByWaiterForDishPickup or not dishChair.stateData.dish or dishChair.stateData.dish.isDeleted then
				continue
			end
			selectedDishChair = dishChair
			selectedDishChairFloor = dishChair:GetMyFloor()
			break
		end
		if selectedDishChair then
			break
		end
	end
	
	if not selectedDishChair then
		return false
	end

	local dishwashers = myFloor:GatherDishwashersOnAnyFloor()
	if #dishwashers == 0 then return false end
	
	local dishChair = selectedDishChair
	dishChair.stateData.flaggedByWaiterForDishPickup = true
	
	local dishwasher = dishwashers[math.random(#dishwashers)]
	dishwasher.stateData.dishWasherTargetCount += 1

	dishChair.stateData.dish.flaggedDishwasherUID = dishwasher.UID

	waiter.state = "WalkingToPickupDish"
	
	waiter:WalkToNewFloor(dishChair:GetMyFloor(), function()
		
		if dishChair.isDeleted or not dishChair.stateData.dish then
			dishwasher.stateData.dishWasherTargetCount -= 1
			waiter.state = "Idle"
			return
		end
		
		waiter:WalkToPoint(dishChair.xVoxel, dishChair.yVoxel, dishChair.zVoxel, function()
			
			if dishChair.isDeleted or not dishChair.stateData.dish then
				dishwasher.stateData.dishWasherTargetCount -= 1
				waiter.state = "Idle"
				return
			end
			
			dishChair.stateData.flaggedByWaiterForDishPickup = false
			
			if not dishChair.stateData.dish or dishChair.stateData.dish.isDeleted then
				dishwasher.stateData.dishWasherTargetCount -= 1
				waiter.state = "Idle"
				return
			end
			
			if dishChair.stateData.dish and dishChair.stateData.dish.model then
				
				for i, dishChairEntry in ipairs(selectedDishChairFloor.dishChairs) do
					if dishChairEntry == selectedDishChair then
						table.remove(selectedDishChairFloor.dishChairs, i)
						break
					end
				end
				
				dishChair.stateData.dish:CleanupInteract()
				
				if dishChair.stateData.dish.model and dishChair.stateData.dish.model.PrimaryPart then
					local dishSounds = {5205173686, 5205173942}
					Library.SFX.Play(dishSounds[math.random(#dishSounds)], dishChair.stateData.dish.model:GetPrimaryPartCFrame().p)
				end
				
				dishChair.stateData.dish:MoneyPickedUp()
				dishChair.stateData.dish:DestroyModel()
				dishChair.stateData.dish = nil
				
				waiter:HoldDirtyDish()

			end
			
			waiter:FaceEntity(dishChair)

			if dishwasher.isDeleted then
				waiter:StopLoadedAnimation("hold")
				if waiter.stateData.heldDish then
					waiter.stateData.heldDish = waiter.stateData.heldDish:Destroy()
				end
				waiter.state = "Idle"
				return
			end
			

			waiter:WalkToNewFloor(dishwasher:GetMyFloor(), function()
				
				if dishwasher.isDeleted then
					waiter:StopLoadedAnimation("hold")
					if waiter.stateData.heldDish then
						waiter.stateData.heldDish = waiter.stateData.heldDish:Destroy()
					end
					waiter.state = "Idle"
					return
				end
				
				waiter:WalkToPoint(dishwasher.xVoxel, dishwasher.yVoxel, dishwasher.zVoxel, function()

					waiter:DropFood()
					
					if dishwasher.isDeleted then
						waiter.state = "Idle"
						return
					end
					dishwasher:AddDish()
					
					waiter:FaceEntity(dishwasher)

					waiter:ResetAllStates()
		
				end)
			end)
		end)
	end)
	
	return true
	
end

local Original_CheckForCustomerOrder = Waiter.CheckForCustomerOrder
Waiter.CheckForCustomerOrder = function(waiter)
	if not FastWaiter then return Original_CheckForCustomerOrder(waiter) end
	
	local myFloor = waiter:GetMyFloor()
	
	local waitingCustomer = myFloor:GetCustomerWaitingToOrder()
	
	if not waitingCustomer then
		
		local indices = Library.Functions.RandomIndices(Library.Variables.MyBakery.floors)
		for _, index in ipairs(indices) do
			local floor = Library.Variables.MyBakery.floors[index]
			if floor ~= myFloor then
				if not floor:HasAtLeastOneIdleStateOfClass("Waiter") then
					waitingCustomer = floor:GetCustomerWaitingToOrder()
					if waitingCustomer then
						break
					end
				end
			end
		end
		
		if not waitingCustomer then
			return false
		end
	end
	
	waiter.state = "WalkingToTakeOrder"

	local customerGroup = {waitingCustomer}
	for _, customerPartner in ipairs(waitingCustomer.stateData.queueGroup) do
		if customerPartner.state == "WaitingToOrder" and not customerPartner.waiterIsAttendingToFoodOrder then
			table.insert(customerGroup, customerPartner)
		end
	end	

	for _, seatedCustomer in ipairs(customerGroup) do
		seatedCustomer.waiterIsAttendingToFoodOrder = true
	end
	
	local function untagGroup()
		for _, seatedCustomer in ipairs(customerGroup) do
			seatedCustomer.waiterIsAttendingToFoodOrder = false
		end
	end
	
	local firstCustomer = customerGroup[1]
	local groupTable = waiter:EntityTable()[firstCustomer.stateData.tableUID]
	if not groupTable or groupTable.isDeleted then
		waiter.state = "Idle"
		return
	end
	local tx, ty, tz = groupTable.xVoxel, groupTable.yVoxel, groupTable.zVoxel
	
	local customerFloor = firstCustomer:GetMyFloor()
	waiter:WalkToNewFloor(customerFloor, function()
		if firstCustomer.leaving or firstCustomer.isDeleted then
			waiter.state = "Idle"
			return
		end
		waiter:WalkToPoint(tx, ty, tz, function()
			
			if firstCustomer.isDeleted or firstCustomer.leaving then
				waiter.state = "Idle"
				return
			end
			
			local orderStand = customerFloor:FindOrderStandOnAnyFloor()
			if not orderStand then
				Library.Print("CRITICAL: NO ORDER STAND FOUND!", true)
				untagGroup()
				waiter.state = "Idle"
				waiter:TimedEmoji("ConcernedEmoji", 2)
				return
			end
			
			local firstCustomer = customerGroup[1]
			if firstCustomer then
				firstCustomer:StopGroupEmoji()
				firstCustomer:CleanupGroupInteract()
			end
					
			local groupOrder = {}
			local tookOrdersFrom = {}
			for _, seatedCustomer in ipairs(customerGroup) do
				if seatedCustomer.state == "WaitingToOrder" then
					table.insert(tookOrdersFrom, seatedCustomer)
					groupOrder[seatedCustomer.UID] = Library.Food.RandomFoodChoice(seatedCustomer.UID, seatedCustomer.ID, seatedCustomer:IsRichCustomer(), seatedCustomer:IsPirateCustomer(), seatedCustomer.isNearTree)
					seatedCustomer.state = "WaitingForFood"
					seatedCustomer:StopChat()
				end
			end
			
			-- if no orders are taken, abort
			if #tookOrdersFrom == 0 then
				waiter.state = "Idle"
				return
			end
			
			-- take order animation
			waiter:PlayLoadedAnimation("write")
			for _, customer in ipairs(customerGroup) do
				waiter:FaceEntity(customer)
			end
			waiter:StopLoadedAnimation("write")
			
			waiter.state = "WalkingToDropoffOrder"
			
			waiter:WalkToNewFloor(orderStand:GetMyFloor(), function()
				
				if orderStand.isDeleted then
					for _, customer in ipairs(customerGroup) do
						customer:ForcedToLeave()
					end
					waiter.state = "Idle"
					return
				end
				
				waiter:WalkToPoint(orderStand.xVoxel, orderStand.yVoxel, orderStand.zVoxel, function()
					
					if orderStand.isDeleted then
						for _, customer in ipairs(customerGroup) do
							customer:ForcedToLeave()
						end
						waiter.state = "Idle"
						return
					end
					
					-- deposit each of the orders
					for _, orderedCustomer in ipairs(tookOrdersFrom) do
						if orderedCustomer.isDeleted then
							continue
						end
						orderedCustomer:ChangeToWaitingForFoodState(groupOrder[orderedCustomer.UID])
						orderStand:AddFoodToQueue(groupOrder[orderedCustomer.UID])
					end
					
					
					Library.Network.Fire("AwardWaiterExperienceForTakingOrderWithVerification", waiter.UID)

					waiter:FaceEntity(orderStand)

					waiter.state = "Idle"
					
				end)
			end)
			
		end)
	end)
	
	return true
	
end

local Original_RandomFoodChoice = Food.RandomFoodChoice
Food.RandomFoodChoice = function(customerOwnerUID, customerOwnerID, isRichCustomer, isPirateCustomer, isNearTree)
    if HyperFood then
		local spoof = Food.new("45", customerOwnerUID, customerOwnerID, true, true)
		spoof.IsHyper = true
		return spoof
	end
	
	return Original_RandomFoodChoice(customerOwnerUID, customerOwnerID, isRichCustomer, isPirateCustomer, isNearTree)
end

local Original_DropPresent = Customer.DropPresent
Customer.DropPresent = function(gift) 
	if AutoGift then
		local character = Player.Character or Player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
		
		local UID = Library.Network.Invoke("Santa_RequestPresentUID", gift.UID)
		Library.Network.Fire("Santa_PickUpGift", UID, humanoidRootPart.Position + Vector3.new(1,0,0))
	else 
		Original_DropPresent(gift)
	end
end

local Original_CheckForFoodDelivery = Waiter.CheckForFoodDelivery
Waiter.CheckForFoodDelivery = function(waiter)
	if not HyperFood then 
		return Original_CheckForFoodDelivery(waiter)
	end
	
	local myFloor = waiter:GetMyFloor()
	local readyStands = myFloor:GatherOrderStandsWithDeliveryReady()
	if #readyStands == 0 then		
		local indices = Library.Functions.RandomIndices(Library.Variables.MyBakery.floors)
		for _, index in ipairs(indices) do
			local floor = Library.Variables.MyBakery.floors[index]
			if floor ~= myFloor and not floor:HasAtLeastOneIdleStateOfClass("Waiter") then
				readyStands = floor:GatherOrderStandsWithDeliveryReady()
				if #readyStands > 0 then break end
			end		
		end
		
		if #readyStands == 0 then
			return false
		end
	end
	
	local orderStand = readyStands[math.random(#readyStands)]
	if not orderStand then
		return false
	end
	
	orderStand.stateData.foodReadyTargetCount = orderStand.stateData.foodReadyTargetCount + 1
	waiter.state = "WalkingToPickupFood"
	waiter:WalkToNewFloor(orderStand:GetMyFloor(), function()
		if orderStand.isDeleted then
			waiter.state = "Idle"
			return
		end
		
		waiter:WalkToPoint(orderStand.xVoxel, orderStand.yVoxel, orderStand.zVoxel, function()
			if orderStand.isDeleted then
				waiter.state = "Idle"
				return
			end
			
			orderStand.stateData.foodReadyTargetCount = orderStand.stateData.foodReadyTargetCount - 1
			if #orderStand.stateData.foodReadyList == 0 then
				waiter.state = "Idle"
				return
			end
			
			local selectedFoodOrder = orderStand.stateData.foodReadyList[1]
			selectedFoodOrder.isHyper = true
			
			table.remove(orderStand.stateData.foodReadyList, 1)

			selectedFoodOrder:DestroyPopupListItemUI()
			local customerOfOrder = waiter:EntityTable()[selectedFoodOrder.customerOwnerUID]
			if not customerOfOrder then
				Library.Print("CRITICAL: customer owner of food not found", true)
				waiter.state = "Idle"
				return false
			end
			waiter:FaceEntity(orderStand)
			waiter:HoldFood(selectedFoodOrder.ID, selectedFoodOrder.isHyper)
			waiter.state = "WalkingToDeliverFood"
			if not customerOfOrder.isDeleted then
				waiter:WalkToNewFloor(customerOfOrder:GetMyFloor(), function()
					waiter:WalkToPoint(customerOfOrder.xVoxel, customerOfOrder.yVoxel, customerOfOrder.zVoxel, function()
						waiter:DropFood()
						if customerOfOrder.isDeleted then
							Library.Print("CRITICAL: walked to customer, but they were forced to leave.  aborting", true)
							waiter.state = "Idle"
							return
						end
						customerOfOrder:ChangeToEatingState()
						waiter:FaceEntity(customerOfOrder)
						Library.Network.Fire("AwardWaiterExperienceForDeliveringOrderWithVerification", waiter.UID)
						waiter.state = "Idle"
					end)
				end)
				return
			end
			waiter.state = "Idle"
			waiter.stateData.heldDish = waiter.stateData.heldDish:Destroy()
		end)
	end)
	
	return true
end

local Original_ChangeToWaitForOrderState = Customer.ChangeToWaitForOrderState
Customer.ChangeToWaitForOrderState = function(customer)
	if not FastOrder then 
		Original_ChangeToWaitForOrderState(customer) 
		return
	end

	if customer.state ~= "WalkingToSeat" then return end
	
	local seatLeaf = customer:EntityTable()[customer.stateData.seatUID]
	local tableLeaf = customer:EntityTable()[customer.stateData.tableUID]
			
	if seatLeaf.isDeleted or tableLeaf.isDeleted then
		customer:ForcedToLeave()
		return
	end
	
	customer:SetCustomerState("ThinkingAboutOrder")
	customer:SitInSeat(seatLeaf).Completed:Connect(function()
	
		customer.humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
		customer.xVoxel = seatLeaf.xVoxel
		customer.zVoxel = seatLeaf.zVoxel
		
		coroutine.wrap(function()
			wait(0.05)
			customer:ReadMenu()
			wait(0.1)
			
			if customer.isDeleted or customer.state ~= "ThinkingAboutOrder" then return end
			
			customer:StopReadingMenu()
			customer:SetCustomerState("DecidedOnOrder")
			
			local myGroup = {customer}
			for _, partner in ipairs(customer.stateData.queueGroup) do
				if not partner.isDeleted then
					table.insert(myGroup, partner)
				end
			end
			local foundUndecidedMember = false
			for _, groupMember in ipairs(myGroup) do
				if groupMember.state ~= "DecidedOnOrder" then
					foundUndecidedMember = true
					break
				end
			end
			
			if not foundUndecidedMember then
				for _, groupMember in ipairs(myGroup) do
					groupMember:ReadyToOrder()
				end
			end
		end)()
	end)
end

local Original_WalkThroughWaypoints = Entity.WalkThroughWaypoints
Entity.WalkThroughWaypoints = function(entity, voxelpoints, waypoints, undefined1, undefined2)
	if entity:BelongsToMyBakery() then
		if TeleportNPC then
			TeleportThroughWaypoints(entity, voxelpoints, waypoints)
			return
		elseif FastNPC and entity.humanoid then 
			entity.humanoid.WalkSpeed = NPCSpeed
		elseif not FastNPC and entity.humanoid and entity.data and entity.data.walkSpeed then
			entity.humanoid.WalkSpeed = entity.data.walkSpeed
		end
	end
	
	Original_WalkThroughWaypoints(entity, voxelpoints, waypoints, undefined1, undefined2)
end

function TeleportThroughWaypoints(entity, voxelpoints, waypoints)
    entity:PlayLoadedAnimation("walking")
	
	if #voxelpoints == 0 then
		return
	end
	
	if not entity:BelongsToMyBakery() and entity.stateData.walkingThroughWaypoints then
		repeat wait() until entity.isDeleted or not entity.stateData.walkingThroughWaypoints
		if entity.isDeleted then
			return
		end
	end
	if not entity:BelongsToMyBakery() then
		entity.stateData.walkingThroughWaypoints = true
	end
	
	-- replication fix?
	if not entity:BelongsToMyBakery() then
		entity.model.HumanoidRootPart.Anchored = false
	end
	
	local wayPoint = waypoints[#waypoints]
	local voxelPoint = voxelpoints[#waypoints]
	
	
	if wayPoint and voxelPoint and voxelPoint["x"] and voxelPoint["y"] then
		entity.model.HumanoidRootPart.CFrame = CFrame.new(wayPoint) * CFrame.new(0, 2, 0)
		local oldX, oldZ = entity.xVoxel, entity.zVoxel

		entity.xVoxel = voxelPoint.x
		entity.zVoxel = voxelPoint.y

		if entity:BelongsToMyBakery() then
			entity:GetMyFloor():BroadcastNPCPositionChange(entity, oldX, oldZ)
		end
	else
		for i, v in ipairs(waypoints) do
			entity.model.HumanoidRootPart.CFrame = CFrame.new(v) * CFrame.new(0, 2, 0)
			local oldX, oldZ = entity.xVoxel, entity.zVoxel
			entity.xVoxel = voxelpoints[i].x
			entity.zVoxel = voxelpoints[i].y
			

			if entity:BelongsToMyBakery() then
				entity:GetMyFloor():BroadcastNPCPositionChange(entity, oldX, oldZ)
			end
		end	
	end
	
	if not entity:BelongsToMyBakery() then
		entity.stateData.walkingThroughWaypoints = false
	end
		
	entity:StopLoadedAnimation("walking")
	entity:PlayLoadedAnimation("idle")
end

local Debris = workspace:WaitForChild("__DEBRIS")
Debris.ChildAdded:Connect(function(ch)
    task.wait()
	local children = ch:GetChildren()
    if OptimizedMode and (ch.Name == "host" or (children and #children == 1 and typeof(children[1]) == "Instance" and children[1].ClassName == "Sound"))  then
        ch:Destroy()
    end
end)


-------------------------//
--// UI - LinoriaLib (Delta X compatible)
-------------------------//
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'My Restaurant | Rafa & Quoocs',
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Farm = Window:AddTab('Farm'),
    Teleport = Window:AddTab('Teleport'),
    Automation = Window:AddTab('Automation'),
    Layout = Window:AddTab('Layout'),
    Webhook = Window:AddTab('Webhook'),
}

-------------------------//
--// FARM TAB
-------------------------//
local FarmLeft = Tabs.Farm:AddLeftGroupbox('Instant Options')

FarmLeft:AddToggle('FastOrder', {
    Text = 'Instant Order',
    Default = true,
    Callback = function(v) FastOrder = v end
})

FarmLeft:AddToggle('FastWaiter', {
    Text = 'Instant Waiter',
    Default = false,
    Callback = function(v) FastWaiter = v end
})

FarmLeft:AddToggle('InstantCook', {
    Text = 'Instant Cook',
    Default = false,
    Callback = function(v) InstantCook = v end
})

FarmLeft:AddToggle('InstantEat', {
    Text = 'Instant Eat',
    Default = false,
    Callback = function(v) InstantEat = v end
})

FarmLeft:AddToggle('InstantWash', {
    Text = 'Instant Wash',
    Default = false,
    Callback = function(v) InstantWash = v end
})

local FarmRight = Tabs.Farm:AddRightGroupbox('NPC & Farm')

FarmRight:AddToggle('TeleportNPC', {
    Text = 'Teleport NPC',
    Default = false,
    Callback = function(v) TeleportNPC = v end
})

FarmRight:AddToggle('FastNPC', {
    Text = 'Fast NPC',
    Default = false,
    Callback = function(v) FastNPC = v end
})

FarmRight:AddSlider('NPCSpeed', {
    Text = 'NPC Speed',
    Default = 100,
    Min = 16,
    Max = 500,
    Rounding = 0,
    Callback = function(v) NPCSpeed = v end
})

FarmRight:AddDivider()

FarmRight:AddToggle('OptimizedMode', {
    Text = 'Optimize Game',
    Default = false,
    Callback = function(v) OptimizedMode = v end
})

FarmRight:AddToggle('HyperFood', {
    Text = 'Hyper Food',
    Default = false,
    Callback = function(v) HyperFood = v end
})

-- Force Customer section
local ForceBox = Tabs.Farm:AddLeftGroupbox('Force Customer')

ForceBox:AddToggle('ForceCustomers', { Text='Force Best Customer', Default=false, Callback=function(v) ForceCustomers=v end })
ForceBox:AddToggle('ForceVIP',       { Text='Force Royal VIP',     Default=false, Callback=function(v) ForceVIP=v end })
ForceBox:AddToggle('ForcePirate',    { Text='Force Pirate',        Default=false, Callback=function(v) ForcePirate=v end })
ForceBox:AddToggle('ForceYoutuber', { Text='Force Youtuber',      Default=false, Callback=function(v) ForceYoutuber=v end })
ForceBox:AddToggle('ForceHeadless', { Text='Force Headless',      Default=false, Callback=function(v) ForceHeadless=v end })
ForceBox:AddToggle('ForceCorruptedVIP', { Text='Force Corrupted VIP', Default=false, Callback=function(v) ForceCorruptedVIP=v end })
ForceBox:AddToggle('ForceSanta',    { Text='Force Santa',         Default=false, Callback=function(v) ForceSanta=v end })
ForceBox:AddToggle('ForceElf',      { Text='Force Elf',           Default=false, Callback=function(v) ForceElf=v end })
ForceBox:AddToggle('ForceLifeguard',{ Text='Force Lifeguard',     Default=false, Callback=function(v) ForceLifeguard=v end })
ForceBox:AddToggle('ForceAlien',    { Text='Force Alien',         Default=false, Callback=function(v) ForceAlien=v end })
ForceBox:AddToggle('ForcePrincess', { Text='Force Princess',      Default=false, Callback=function(v) ForcePrincess=v end })
ForceBox:AddToggle('ForceSuperHero',{ Text='Force Superhero',     Default=false, Callback=function(v) ForceSuperHero=v end })

-------------------------//
--// TELEPORT TAB
-------------------------//
local TpStore = Tabs.Teleport:AddLeftGroupbox('Store')

local function TeleportToPosition(cf)
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild('HumanoidRootPart')
    if hrp then hrp.CFrame = cf end
end

TpStore:AddButton('Daily Offers', function()
    TeleportToPosition(CFrame.new(-97.3058167, 1611, 536.899536, -0.0209189299, -1.0223701e-07, -0.999781191, 1.16250276e-09, 1, -1.02283714e-07, 0.999781191, -3.3019143e-09, -0.0209189299))
end)
TpStore:AddButton('Restaurant Themes', function()
    TeleportToPosition(CFrame.new(-157.20842, 1611, 631.657166, -0.954549313, -3.4495919e-08, -0.298053086, -7.47909734e-09, 1, -9.1784834e-08, 0.298053086, -8.53839808e-08, -0.954549313))
end)
TpStore:AddButton('Twitter Verify', function()
    TeleportToPosition(CFrame.new(-375.098846, 1611, 500.056335, -0.150306463, 8.26021775e-08, 0.988639474, 1.4371575e-08, 1, -8.13664016e-08, -0.988639474, 1.97841032e-09, -0.150306463))
end)

local TpPlayers = Tabs.Teleport:AddRightGroupbox('Player Restaurants')

local function AddTeleportToPlayerBakery(player)
    if not player then return end
    TpPlayers:AddButton(player.Name, function()
        local playerBakery = Bakery.GetBakeryByOwner(player)
        if not playerBakery then return end
        local char = Player.Character or Player.CharacterAdded:Wait()
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end

        local VoxelX, VoxelY, VoxelZ = Bakery.GetCustomerStartVoxel(playerBakery, 1, 1)
        local position = playerBakery.floors[1]:WorldPositionFromVoxel(VoxelX, VoxelZ)

        local function testtt(p73, offset)
            local sz = playerBakery.floors[1].isBiggerPlot and 16 or 14
            if playerBakery.baseOrientation == 0   then return sz/2-1+p73, 0-offset+1 end
            if playerBakery.baseOrientation == 90  then return 0-offset+1, sz/2+2-p73 end
            if playerBakery.baseOrientation == 180 then return sz/2+2-p73, sz+offset end
            return sz+offset, sz/2+2-p73
        end

        local v236, v238 = testtt(1, 10)
        local v241 = playerBakery.floors[1]:WorldPositionFromVoxel(v236, v238)

        hrp.CFrame = CFrame.new(
            (CFrame.new(position+Vector3.new(0,2,0)) * CFrame.Angles(0,playerBakery.baseAngle,0) * CFrame.new(2,0,0)).p,
            (CFrame.new(v241) * CFrame.Angles(0,playerBakery.baseAngle,0) * CFrame.new(2,0,0)).p
        ) * CFrame.new(0,0,-10)
        hrp.CFrame *= CFrame.new(2,0,-10)
        hrp.CFrame *= CFrame.Angles(0, math.rad(180), 0)
    end)
end

AddTeleportToPlayerBakery(Player)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= Player then AddTeleportToPlayerBakery(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= Player then AddTeleportToPlayerBakery(p) end
end)

-------------------------//
--// AUTOMATION TAB
-------------------------//
local AutoLeft = Tabs.Automation:AddLeftGroupbox('Farm Automation')

AutoLeft:AddToggle('AutoGift', {
    Text = 'Auto Collect Santa Gifts',
    Default = false,
    Callback = function(v)
        AutoGift = v
        if v and workspace:FindFirstChild('__DEBRIS') then
            coroutine.wrap(function()
                for _, obj in pairs(workspace.__DEBRIS:GetChildren()) do
                    if obj.Name == 'SantaPresent' then
                        pcall(function()
                            local hrp = Player.Character:WaitForChild('HumanoidRootPart')
                            local UID = GameLib.Network.Invoke('Santa_RequestPresentUID', obj.Name)
                            if UID then GameLib.Network.Fire('Santa_PickUpGift', UID, hrp.Position + Vector3.new(1,0,0)) end
                        end)
                        wait(0.3)
                    end
                end
            end)()
        end
    end
})

AutoLeft:AddToggle('AutoInteract', {
    Text = 'Auto Slot / Wishing Well',
    Default = false,
    Callback = function(v) AutoInteract = v end
})

AutoLeft:AddToggle('AutoBuyWorkers', {
    Text = 'Auto Buy Workers',
    Default = false,
    Callback = function(v)
        AutoBuyWorkers = v
        if v then CheckIfCanBuy('Cook') CheckIfCanBuy('Waiter') end
    end
})

local AutoRight = Tabs.Automation:AddRightGroupbox('Other')

AutoRight:AddToggle('AutoBlacklist', {
    Text = 'Auto Blacklist',
    Default = false,
    Callback = function(v)
        AutoBlacklist = v
        if v then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player and p.Name then
                    GameLib.Network.Fire('BlacklistToggled', p.Name, true)
                    wait(0.1)
                end
            end
        end
    end
})

AutoRight:AddDivider()
AutoRight:AddLabel('Auto Close Restaurant')
AutoRight:AddSlider('AutoCloseEvery', {
    Text = 'Every (seconds)',
    Default = 600,
    Min = 20,
    Max = 3600,
    Rounding = 0,
    Callback = function(v) AutoCloseEvery = v end
})
AutoRight:AddToggle('AutoCloseRestaurant', {
    Text = 'Enable Auto Close',
    Default = false,
    Callback = function(v)
        if v then LastTimeClose = os.time() end
        AutoCloseRestaurant = v
    end
})

-------------------------//
--// LAYOUT TAB
-------------------------//
local LayoutLeft = Tabs.Layout:AddLeftGroupbox('Copy Layout')

local SelectedFloor = 1
LayoutLeft:AddSlider('SelectedFloor', {
    Text = 'Floor Number',
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(v) SelectedFloor = v end
})

LayoutLeft:AddButton('Copy Floor to Clipboard', function()
    local MyBakery = GameLib.Variables.MyBakery
    if not MyBakery then return end
    local Floor = MyBakery.floors[SelectedFloor]
    if not Floor then return end

    local function FurnitureToData(f)
        return { X=f.xVoxel, Y=f.yVoxel, Z=f.zVoxel, Orientation=f.orientation }
    end
    local Items = {}
    for _, item in pairs(Floor.appliances) do
        if item then
            Items[item.className] = Items[item.className] or {}
            Items[item.className][item.ID] = Items[item.className][item.ID] or {}
            table.insert(Items[item.className][item.ID], FurnitureToData(item))
        end
    end
    for _, item in pairs(Floor.furniture) do
        if item then
            Items[item.className] = Items[item.className] or {}
            Items[item.className][item.ID] = Items[item.className][item.ID] or {}
            table.insert(Items[item.className][item.ID], FurnitureToData(item))
        end
    end
    pcall(setclipboard, HttpService:JSONEncode(Items))
    Library:Notify('Copied floor ' .. SelectedFloor .. ' to clipboard!')
end)

local LayoutRight = Tabs.Layout:AddRightGroupbox('Paste Layout')
local LayoutToCopy = ''
local IsPastingLayout = false
local StopPasting = false

LayoutRight:AddInput('LayoutInput', {
    Text = 'Layout JSON',
    Default = '',
    Numeric = false,
    Finished = false,
    Placeholder = 'Paste JSON here...',
    Callback = function(v) LayoutToCopy = v end
})

LayoutRight:AddButton('Paste to Floor', function()
    if IsPastingLayout then StopPasting = true return end
    local MyBakery = GameLib.Variables.MyBakery
    if not MyBakery then return end
    local floor = MyBakery.floors[SelectedFloor]
    if not floor then return end
    local inventory = GameLib.Inventory.Get()
    if not inventory then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(LayoutToCopy) end)
    if not ok or not data then Library:Notify('Invalid JSON!') return end

    IsPastingLayout = true
    Library:Notify('Starting in 3 seconds...')
    wait(3)
    if StopPasting then IsPastingLayout=false StopPasting=false return end

    for className, ids in pairs(data) do
        if StopPasting then break end
        for id, items in pairs(ids) do
            if StopPasting then break end
            local item = GameLib.Directory.Furniture[id]
            if not inventory[className] or not inventory[className][id] or inventory[className][id] < #items then
                if item and GameLib.Stats.Get(true).Cash > item.baseCost and not item.offSale then
                    local cur = (inventory[className] and inventory[className][id]) or 0
                    local qty = #items - cur
                    local tries = 3
                    while qty > 0 do
                        local n = qty >= 3 and 3 or 1
                        local ok2 = GameLib.Network.Invoke('PurchaseGameItem', className, id, n)
                        if ok2 then qty -= n else tries -= 1 if tries <= 0 then break end end
                        wait(0.3)
                        if StopPasting then break end
                    end
                    inventory = GameLib.Inventory.Get()
                end
            end
            if item and item.name and inventory and inventory[className] and inventory[className][id] and inventory[className][id] > 1 then
                for _, furniture in pairs(items) do
                    if StopPasting then break end
                    if furniture and furniture.X then
                        local x,y,z,o = tonumber(furniture.X), tonumber(furniture.Y), tonumber(furniture.Z), tonumber(furniture.Orientation)
                        if x and y and z and o then
                            GameLib.Network.Invoke('Build_RequestEntityPlacementFromInventory', className, id, SelectedFloor, x, y, z, o)
                        end
                        wait(0.1)
                    end
                end
            end
        end
    end
    IsPastingLayout=false StopPasting=false
    Library:Notify('Paste complete!')
end)

-------------------------//
--// WEBHOOK TAB
-------------------------//
local WbLeft = Tabs.Webhook:AddLeftGroupbox('Discord Webhook')

local WebhookEnabled = false
local WebhookURL = ''
local WebhookUpdateTime = 20
local WebhookLastTime = tick()

local function SendWebhook(skipError)
    local stats = GameLib.Stats.Get()
    if not stats then
        if not skipError then wait(5) SendWebhook(false) end
        return
    end
    local str = ''
    if stats.TimeSpentInGame then
        local t = stats.TimeSpentInGame + math.floor(tick() - StartTick)
        local d=math.floor(t/86400) t=t%86400
        local h=math.floor(t/3600) t=t%3600
        local m=math.floor(t/60)
        local s=math.floor(t%60)
        str ..= '**Time Spent:** '
        if d>0 then str ..= d..'d ' end
        if h>0 then str ..= h..'h ' end
        if m>0 then str ..= m..'m ' end
        str ..= s..'s\n'
    end
    if stats.ServedCustomers then str ..= '**Served:** '..GameLib.Functions.Commas(stats.ServedCustomers)..'\n' end
    if stats.Cash then str ..= '**Cash:** $'..GameLib.Functions.Commas(stats.Cash)..'\n' end
    if stats.CashEarned then str ..= '**Total Earned:** $'..GameLib.Functions.Commas(stats.CashEarned)..'\n' end

    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        pcall(req, {
            Url = WebhookURL, Method = 'POST',
            Headers = { ['Content-Type'] = 'application/json' },
            Body = HttpService:JSONEncode({
                username = 'My Restaurant!',
                avatar_url = 'https://cdn.discordapp.com/attachments/897053118360064001/1132402302049853570/latest.png',
                embeds = {{ title='Restaurant Update', color=tonumber(0x3ce42f), fields={{ name='Stats', value=str, inline=false }} }}
            })
        })
    end
    WebhookLastTime = tick()
end

WbLeft:AddToggle('WebhookEnabled', {
    Text = 'Enable Webhook',
    Default = false,
    Callback = function(v) WebhookEnabled = v if v then WebhookLastTime = tick() end end
})

WbLeft:AddInput('WebhookURL', {
    Text = 'Webhook URL',
    Default = '',
    Placeholder = 'https://discord.com/api/webhooks/...',
    Numeric = false,
    Finished = false,
    Callback = function(v) WebhookURL = v end
})

WbLeft:AddSlider('WebhookUpdateTime', {
    Text = 'Send Every (minutes)',
    Default = 20, Min = 10, Max = 240, Rounding = 0,
    Callback = function(v) WebhookUpdateTime = v end
})

WbLeft:AddButton('Test Webhook', function() SendWebhook(true) end)

-------------------------//
--// Background Loops
-------------------------//

-- Auto Close
coroutine.wrap(function()
    while true do
        if AutoCloseRestaurant and LastTimeClose == 0 then LastTimeClose = os.time() end
        if AutoCloseRestaurant and os.time() > LastTimeClose + AutoCloseEvery then
            pcall(function() GameLib.Variables.MyBakery:SetOpenStatus(false) end)
            wait(5)
            pcall(function() GameLib.Variables.MyBakery:SetOpenStatus(true) end)
            LastTimeClose = os.time()
        end
        wait(1)
    end
end)()

-- Auto Interact (Well/Slot)
local function UseWell(wellUID, wellId)
    local event = wellId == '101' and 'RequestHauntedWishingWellUsage' or 'RequestWishingWellUsage'
    GameLib.Network.Fire(event, wellUID)
    wait(1)
end

coroutine.wrap(function()
    while true do
        if AutoInteract then
            local bakeryData = GameLib.Variables.UIDData
            if bakeryData then
                for _, v in pairs(bakeryData['Furniture']) do
                    local ID = v.ID
                    if ID and table.find(Wells, ID) and v.ClassName == 'Furniture' and not FurnituresCooldowns[v.UID] then
                        task.spawn(function()
                            local event = ID=='101' and 'GetHauntedWishingWellRefreshTime' or 'GetWishingWellRefreshTime'
                            local cd = GameLib.Network.Invoke(event, ID=='101' and v.UID or v.ID)
                            if cd and cd == 0 and AutoInteract then UseWell(v.UID, ID) FurnituresCooldowns[v]=nil
                            else FurnituresCooldowns[v] = tick() + (cd or 60) end
                        end)
                    end
                    if ID and table.find(Slots, ID) then
                        task.spawn(function()
                            local cd = GameLib.Network.Invoke('GetSlotRefreshTime')
                            if cd and cd == 0 and AutoInteract then
                                GameLib.Network.Fire('RequestSlotUsage', v.UID)
                                FurnituresCooldowns[v] = nil wait(0.5)
                            else FurnituresCooldowns[v] = tick() + (cd or 60) end
                        end)
                    end
                    wait()
                end
                if AutoInteract then
                    for furniture, cd in pairs(FurnituresCooldowns) do
                        local ID = furniture.ID
                        if cd and ID and tick() >= cd then
                            if table.find(Wells,ID) and furniture.ClassName=='Furniture' then
                                task.spawn(function() UseWell(furniture.UID, ID) FurnituresCooldowns[furniture]=nil end)
                            end
                            if table.find(Slots,ID) then
                                GameLib.Network.Fire('RequestSlotUsage', furniture.UID) wait(1) FurnituresCooldowns[furniture]=nil
                            end
                        elseif not cd then FurnituresCooldowns[furniture]=nil end
                    end
                end
            end
        end
        wait(1)
    end
end)()

-- Auto Buy Workers
local TiersLayout = { Cook = GameLib.Shared.CookTierLayout, Waiter = GameLib.Shared.WaiterTierLayout }

function CheckIfCanBuy(className)
    local stats = GameLib.Stats.Get(true)
    if not stats then return end
    local allWorkers = GameLib.Variables.MyBakery:GetAllOfClassName(className)
    if not allWorkers then return end
    local level = GameLib.Experience.BakeryExperienceToLevel(GameLib.Variables.MyBakery.experience)
    for _, tier in pairs(TiersLayout[className]) do
        local owned = false
        for _, w in pairs(allWorkers) do if tier.Tier == w.tier then owned=true break end end
        if not owned and tier.BakeryLevelRequired <= level and tier.Cost < stats.Cash and AutoBuyWorkers then
            GameLib.Network.Fire('RequestNPCPurchase', className, tier.Tier) wait(0.5)
        end
    end
end

GameLib.Network.Fired('BakeryLevelUp'):Connect(function()
    if not AutoBuyWorkers then return end
    CheckIfCanBuy('Cook') CheckIfCanBuy('Waiter')
end)

-- Webhook loop
coroutine.wrap(function()
    while true do
        if WebhookEnabled and WebhookURL ~= '' and tick() >= WebhookLastTime + (WebhookUpdateTime * 60) then
            SendWebhook(false)
        end
        wait(5)
    end
end)()

-- Players blacklist
Players.PlayerAdded:Connect(function(p)
    if p ~= Player then
        AddTeleportToPlayerBakery(p)
        if AutoBlacklist and p.Name then GameLib.Network.Fire('BlacklistToggled', p.Name, true) end
    end
end)

-------------------------//
--// Anti-AFK
-------------------------//
local VirtualUser = game:GetService('VirtualUser')
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Theme & Save
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:SetFolder('MyRestaurant')
SaveManager:BuildConfigSection(Tabs.Farm)
ThemeManager:ApplyDefault()

warn('Script loaded successfully!')
