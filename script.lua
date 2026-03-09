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
--// OrionLib UI
-------------------------//
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
	Name = "My Restaurant | by Rafa & Quoocs",
	HidePremium = false,
	SaveConfig = true,
	ConfigFolder = "MyRestaurant"
})

-------------------------//
--// Farm Tab
-------------------------//
local FarmTab = Window:MakeTab({
	Name = "Farm",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

FarmTab:AddSection({ Name = "Instant Options" })

FarmTab:AddToggle({
	Name = "Instant Order",
	Default = true,
	Save = true,
	Flag = "FastOrder",
	Callback = function(Value)
		FastOrder = Value
	end
})

FarmTab:AddToggle({
	Name = "Instant Waiter",
	Default = false,
	Save = true,
	Flag = "FastWaiter",
	Callback = function(Value)
		FastWaiter = Value
	end
})

FarmTab:AddToggle({
	Name = "Instant Cook",
	Default = false,
	Save = true,
	Flag = "InstantCook",
	Callback = function(Value)
		InstantCook = Value
	end
})

FarmTab:AddToggle({
	Name = "Instant Eat",
	Default = false,
	Save = true,
	Flag = "InstantEat",
	Callback = function(Value)
		InstantEat = Value
	end
})

FarmTab:AddToggle({
	Name = "Instant Wash",
	Default = false,
	Save = true,
	Flag = "InstantWash",
	Callback = function(Value)
		InstantWash = Value
	end
})

FarmTab:AddSection({ Name = "NPC Options" })

FarmTab:AddToggle({
	Name = "Teleport NPC",
	Default = false,
	Save = true,
	Flag = "TeleportNPC",
	Callback = function(Value)
		TeleportNPC = Value
	end
})

FarmTab:AddToggle({
	Name = "Fast NPC",
	Default = false,
	Save = true,
	Flag = "FastNPC",
	Callback = function(Value)
		FastNPC = Value
	end
})

FarmTab:AddSlider({
	Name = "NPC Speed",
	Min = 16,
	Max = 500,
	Default = 100,
	Color = Color3.fromRGB(255, 165, 0),
	Increment = 1,
	ValueName = "",
	Save = true,
	Flag = "NPCSpeed",
	Callback = function(Value)
		NPCSpeed = Value
	end
})

FarmTab:AddSection({ Name = "Farm Options" })

FarmTab:AddToggle({
	Name = "Optimize Game",
	Default = false,
	Save = true,
	Flag = "OptimizedMode",
	Callback = function(Value)
		OptimizedMode = Value
	end
})

FarmTab:AddToggle({
	Name = "Hyper Food",
	Default = false,
	Save = true,
	Flag = "HyperFood",
	Callback = function(Value)
		HyperFood = Value
	end
})

FarmTab:AddSection({ Name = "Force Best Customer" })

FarmTab:AddToggle({
	Name = "Force Best Customer",
	Default = false,
	Save = true,
	Flag = "ForceCustomers",
	Callback = function(Value)
		ForceCustomers = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Royal VIP",
	Default = false,
	Save = true,
	Flag = "ForceVIP",
	Callback = function(Value)
		ForceVIP = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Pirate",
	Default = false,
	Save = true,
	Flag = "ForcePirate",
	Callback = function(Value)
		ForcePirate = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Youtuber",
	Default = false,
	Save = true,
	Flag = "ForceYoutuber",
	Callback = function(Value)
		ForceYoutuber = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Headless",
	Default = false,
	Save = true,
	Flag = "ForceHeadless",
	Callback = function(Value)
		ForceHeadless = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Corrupted VIP",
	Default = false,
	Save = true,
	Flag = "ForceCorruptedVIP",
	Callback = function(Value)
		ForceCorruptedVIP = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Santa",
	Default = false,
	Save = true,
	Flag = "ForceSanta",
	Callback = function(Value)
		ForceSanta = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Elf",
	Default = false,
	Save = true,
	Flag = "ForceElf",
	Callback = function(Value)
		ForceElf = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Lifeguard",
	Default = false,
	Save = true,
	Flag = "ForceLifeguard",
	Callback = function(Value)
		ForceLifeguard = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Alien",
	Default = false,
	Save = true,
	Flag = "ForceAlien",
	Callback = function(Value)
		ForceAlien = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Princess",
	Default = false,
	Save = true,
	Flag = "ForcePrincess",
	Callback = function(Value)
		ForcePrincess = Value
	end
})

FarmTab:AddToggle({
	Name = "Force Superhero",
	Default = false,
	Save = true,
	Flag = "ForceSuperHero",
	Callback = function(Value)
		ForceSuperHero = Value
	end
})

-------------------------//
--// Teleport Tab
-------------------------//
local TeleportTab = Window:MakeTab({
	Name = "Teleport",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

TeleportTab:AddSection({ Name = "Store" })

local function TeleportToPosition(position)
	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = position
	end
end

TeleportTab:AddButton({
	Name = "Daily Offers",
	Callback = function()
		TeleportToPosition(CFrame.new(-97.3058167, 1611, 536.899536, -0.0209189299, -1.0223701e-07, -0.999781191, 1.16250276e-09, 1, -1.02283714e-07, 0.999781191, -3.3019143e-09, -0.0209189299))
	end
})

TeleportTab:AddButton({
	Name = "Restaurant Themes",
	Callback = function()
		TeleportToPosition(CFrame.new(-157.20842, 1611, 631.657166, -0.954549313, -3.4495919e-08, -0.298053086, -7.47909734e-09, 1, -9.1784834e-08, 0.298053086, -8.53839808e-08, -0.954549313))
	end
})

TeleportTab:AddButton({
	Name = "Twitter Verify",
	Callback = function()
		TeleportToPosition(CFrame.new(-375.098846, 1611, 500.056335, -0.150306463, 8.26021775e-08, 0.988639474, 1.4371575e-08, 1, -8.13664016e-08, -0.988639474, 1.97841032e-09, -0.150306463))
	end
})

TeleportTab:AddSection({ Name = "Player Restaurants" })

local PlayerTeleports = {}

local function AddTeleportToPlayerBakery(player)
	if not player then return end
	if PlayerTeleports[player] then return end

	PlayerTeleports[player] = true
	TeleportTab:AddButton({
		Name = player.Name,
		Callback = function()
			local playerBakery = Bakery.GetBakeryByOwner(player)
			if not playerBakery then return end
			local character = Player.Character or Player.CharacterAdded:Wait()
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end

			local VoxelX, VoxelY, VoxelZ = Bakery.GetCustomerStartVoxel(playerBakery, 1, 1)
			local position = playerBakery.floors[1]:WorldPositionFromVoxel(VoxelX, VoxelZ)

			local function testtt(p73, offsetFromBakery)
				local bakerySize = 14
				if playerBakery.floors[1].isBiggerPlot then bakerySize = 16 end
				if playerBakery.baseOrientation == 0 then return bakerySize / 2 - 1 + p73, 0 - offsetFromBakery + 1 end
				if playerBakery.baseOrientation == 90 then return 0 - offsetFromBakery + 1, bakerySize / 2 + 2 - p73 end
				if playerBakery.baseOrientation == 180 then return bakerySize / 2 + 2 - p73, bakerySize - 0 + offsetFromBakery end
				return bakerySize - 0 + offsetFromBakery, bakerySize / 2 + 2 - p73
			end

			local v236, v238 = testtt(1, 10)
			local v241 = playerBakery.floors[1]:WorldPositionFromVoxel(v236, v238)

			humanoidRootPart.CFrame = CFrame.new(
				(CFrame.new(position + Vector3.new(0,2,0)) * CFrame.Angles(0, playerBakery.baseAngle, 0) * CFrame.new(2,0,0)).p,
				(CFrame.new(v241) * CFrame.Angles(0, playerBakery.baseAngle, 0) * CFrame.new(2,0,0)).p
			) * CFrame.new(0,0,-10)
			humanoidRootPart.CFrame *= CFrame.new(2,0,-10)
			humanoidRootPart.CFrame *= CFrame.Angles(0, math.rad(180), 0)
		end
	})
end

AddTeleportToPlayerBakery(Player)
for _, player in pairs(Players:GetPlayers()) do
	if player ~= Player then
		AddTeleportToPlayerBakery(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	if player ~= Player then
		AddTeleportToPlayerBakery(player)
	end
end)

-------------------------//
--// Automation Tab
-------------------------//
local AutomationTab = Window:MakeTab({
	Name = "Automation",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

AutomationTab:AddSection({ Name = "Farm" })

AutomationTab:AddToggle({
	Name = "Auto Collect Santa Gifts",
	Default = false,
	Save = true,
	Flag = "AutoGift",
	Callback = function(Value)
		AutoGift = Value
		if Value and workspace:FindFirstChild("__DEBRIS") then
			coroutine.wrap(function()
				for _, object in pairs(workspace.__DEBRIS:GetChildren()) do
					if object.Name == "SantaPresent" then
						pcall(function()
							local character = Player.Character or Player.CharacterAdded:Wait()
							local hrp = character:WaitForChild("HumanoidRootPart")
							local UID = Library.Network.Invoke("Santa_RequestPresentUID", object.Name)
							if UID then
								Library.Network.Fire("Santa_PickUpGift", UID, hrp.Position + Vector3.new(1,0,0))
							end
						end)
						wait(0.3)
					end
				end
			end)()
		end
	end
})

AutomationTab:AddToggle({
	Name = "Auto Slot Machine / Wishing Well",
	Default = false,
	Save = true,
	Flag = "AutoInteract",
	Callback = function(Value)
		AutoInteract = Value
	end
})

AutomationTab:AddToggle({
	Name = "Auto Buy Workers",
	Default = false,
	Save = true,
	Flag = "AutoBuyWorkers",
	Callback = function(Value)
		AutoBuyWorkers = Value
		if Value then
			CheckIfCanBuy("Cook")
			CheckIfCanBuy("Waiter")
		end
	end
})

AutomationTab:AddSection({ Name = "Blacklist" })

AutomationTab:AddToggle({
	Name = "Auto Blacklist",
	Default = false,
	Save = true,
	Flag = "AutoBlacklist",
	Callback = function(Value)
		AutoBlacklist = Value
		if Value then
			for _, player in pairs(Players:GetPlayers()) do
				if player ~= Player and player and player.Name then
					Library.Network.Fire("BlacklistToggled", player.Name, true)
					wait(0.1)
				end
			end
		end
	end
})

AutomationTab:AddSection({ Name = "Close and Open Restaurant" })

AutomationTab:AddLabel("Useful if your Restaurant starts to lag over time")

AutomationTab:AddSlider({
	Name = "Close and Open Every (Seconds)",
	Min = 20,
	Max = 3600,
	Default = 600,
	Color = Color3.fromRGB(255, 165, 0),
	Increment = 10,
	ValueName = "s",
	Save = true,
	Flag = "AutoCloseEvery",
	Callback = function(Value)
		AutoCloseEvery = Value
	end
})

AutomationTab:AddToggle({
	Name = "Auto Close/Open Restaurant",
	Default = false,
	Save = true,
	Flag = "AutoCloseRestaurant",
	Callback = function(Value)
		if Value then LastTimeClose = os.time() end
		AutoCloseRestaurant = Value
	end
})

-------------------------//
--// Layout Tab
-------------------------//
local LayoutTab = Window:MakeTab({
	Name = "Layout",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local SelectedFloor = 1

LayoutTab:AddSection({ Name = "Floor Select" })

LayoutTab:AddDropdown({
	Name = "Select Floor",
	Default = "Floor 1",
	Options = {"Floor 1","Floor 2","Floor 3","Floor 4","Floor 5","Floor 6","Floor 7","Floor 8","Floor 9","Floor 10"},
	Save = true,
	Flag = "SelectedFloor",
	Callback = function(Option)
		local n = tonumber(string.sub(Option, 7))
		if n then SelectedFloor = n end
	end
})

LayoutTab:AddSection({ Name = "Copy Layout" })

LayoutTab:AddButton({
	Name = "Copy Floor to Clipboard",
	Callback = function()
		local MyBakery = Library.Variables.MyBakery
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

		local encoded = HttpService:JSONEncode(Items)
		pcall(setclipboard, encoded)
	end
})

LayoutTab:AddSection({ Name = "Paste Layout" })

local LayoutToCopy = ""
local IsPastingLayout = false
local StopPasting = false

LayoutTab:AddTextbox({
	Name = "Paste Layout JSON Here",
	Default = "",
	TextDisappear = false,
	Flag = "LayoutInput",
	Callback = function(Text)
		LayoutToCopy = Text
	end
})

LayoutTab:AddButton({
	Name = "Paste Layout to Floor",
	Callback = function()
		if IsPastingLayout then
			StopPasting = true
			return
		end

		local MyBakery = Library.Variables.MyBakery
		if not MyBakery then return end
		local floor = MyBakery.floors[SelectedFloor]
		if not floor then return end
		local inventory = Library.Inventory.Get()
		if not inventory then return end
		local ok, data = pcall(function() return HttpService:JSONDecode(LayoutToCopy) end)
		if not ok or not data then return end

		IsPastingLayout = true
		wait(3)
		if StopPasting then IsPastingLayout = false StopPasting = false return end

		for className, ids in pairs(data) do
			if StopPasting then break end
			for id, items in pairs(ids) do
				if StopPasting then break end
				local item = Library.Directory.Furniture[id]
				if not inventory[className] or not inventory[className][id] or inventory[className][id] < #items then
					if item and Library.Stats.Get(true).Cash > item.baseCost and not item.offSale then
						local currentItems = (inventory[className] and inventory[className][id]) or 0
						local quantityToBuy = #items - currentItems
						local attempts = 3
						while quantityToBuy > 0 do
							local qty = quantityToBuy >= 3 and 3 or 1
							local success = Library.Network.Invoke("PurchaseGameItem", className, id, qty)
							if success then quantityToBuy -= qty
							else attempts -= 1 if attempts <= 0 then break end end
							wait(0.3)
							if StopPasting then break end
						end
						inventory = Library.Inventory.Get()
					end
				end

				if item and item.name and inventory and inventory[className] and inventory[className][id] and inventory[className][id] > 1 then
					for _, furniture in pairs(items) do
						if StopPasting then break end
						if furniture and furniture.X and furniture.Y and furniture.Z and furniture.Orientation then
							local x,y,z,o = tonumber(furniture.X), tonumber(furniture.Y), tonumber(furniture.Z), tonumber(furniture.Orientation)
							if x and y and z and o then
								Library.Network.Invoke("Build_RequestEntityPlacementFromInventory", className, id, SelectedFloor, x, y, z, o)
							end
							wait(0.1)
						end
					end
				end
			end
		end

		IsPastingLayout = false
		StopPasting = false
	end
})

-------------------------//
--// Webhook Tab
-------------------------//
local WebhookTab = Window:MakeTab({
	Name = "Webhook",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local WebhookEnabled = false
local WebhookURL = ""
local WebhookUpdateTime = 20
local WebhookLastTime = tick()

local function SendWebhook(skipError)
	local stats = Library.Stats.Get()
	if not stats then
		if not skipError then wait(5) SendWebhook(false) end
		return
	end

	local statsString = ""
	if stats.TimeSpentInGame then
		local totalTime = stats.TimeSpentInGame + math.floor(tick() - StartTick)
		local days = math.floor(totalTime / 86400)
		totalTime = totalTime % 86400
		local hours = math.floor(totalTime / 3600)
		totalTime = totalTime % 3600
		local minutes = math.floor(totalTime / 60)
		local seconds = math.floor(totalTime % 60)
		statsString = statsString .. "**Time Spent:** "
		if days > 0 then statsString ..= days.." days " end
		if hours > 0 then statsString ..= hours.." hours " end
		if minutes > 0 then statsString ..= minutes.." minutes " end
		statsString ..= seconds.." seconds\n"
	end
	if stats.ServedCustomers then statsString ..= string.format("**Served Customers:** %s\n", Library.Functions.Commas(stats.ServedCustomers)) end
	if stats.Cash then statsString ..= string.format("**Current Cash:** $%s\n", Library.Functions.Commas(stats.Cash)) end
	if stats.CashEarned then statsString ..= string.format("**Total Cash Earned:** $%s\n", Library.Functions.Commas(stats.CashEarned)) end

	local reqFunc = (syn and syn.request) or (http and http.request) or http_request or request
	if reqFunc then
		pcall(reqFunc, {
			Url = WebhookURL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				username = "My Restaurant!",
				avatar_url = "https://cdn.discordapp.com/attachments/897053118360064001/1132402302049853570/latest.png",
				embeds = {{
					title = "Update from your restaurant!",
					color = tonumber(0x3ce42f),
					fields = {{ name = "Restaurant Stats", value = statsString, inline = false }}
				}}
			})
		})
	end
	WebhookLastTime = tick()
end

WebhookTab:AddToggle({
	Name = "Enable Discord Webhook",
	Default = false,
	Save = true,
	Flag = "WebhookEnabled",
	Callback = function(Value)
		WebhookEnabled = Value
		if Value then WebhookLastTime = tick() end
	end
})

WebhookTab:AddTextbox({
	Name = "Webhook URL",
	Default = "",
	TextDisappear = false,
	Flag = "WebhookURL",
	Callback = function(Text)
		WebhookURL = Text
	end
})

WebhookTab:AddSlider({
	Name = "Send Every (Minutes)",
	Min = 10,
	Max = 240,
	Default = 20,
	Color = Color3.fromRGB(255, 165, 0),
	Increment = 1,
	ValueName = "min",
	Save = true,
	Flag = "WebhookUpdateTime",
	Callback = function(Value)
		WebhookUpdateTime = Value
	end
})

WebhookTab:AddButton({
	Name = "Test Webhook",
	Callback = function()
		SendWebhook(true)
	end
})

-------------------------//
--// Background Logic
-------------------------//

-- Auto Close loop
coroutine.wrap(function()
	while true do
		if AutoCloseRestaurant and LastTimeClose == 0 then LastTimeClose = os.time() end
		if AutoCloseRestaurant and os.time() > LastTimeClose + AutoCloseEvery then
			pcall(function() Library.Variables.MyBakery:SetOpenStatus(false) end)
			wait(5)
			pcall(function() Library.Variables.MyBakery:SetOpenStatus(true) end)
			LastTimeClose = os.time()
		end
		wait(1)
	end
end)()

-- Auto Interact loop
local function UseWell(wellUID, wellId)
	local event = wellId == "101" and "RequestHauntedWishingWellUsage" or "RequestWishingWellUsage"
	Library.Network.Fire(event, wellUID)
	wait(1)
end

coroutine.wrap(function()
	while true do
		if AutoInteract then
			local bakeryData = Library.Variables.UIDData
			if bakeryData then
				for i, v in pairs(bakeryData["Furniture"]) do
					local ID = v.ID
					if ID and table.find(Wells, ID) and v.ClassName == "Furniture" and not FurnituresCooldowns[v.UID] then
						task.spawn(function()
							local event = ID == "101" and "GetHauntedWishingWellRefreshTime" or "GetWishingWellRefreshTime"
							local cooldown = Library.Network.Invoke(event, ID == "101" and v.UID or v.ID)
							if cooldown and cooldown == 0 and AutoInteract then
								UseWell(v.UID, ID)
								FurnituresCooldowns[v] = nil
							else
								FurnituresCooldowns[v] = tick() + (cooldown or 60)
							end
						end)
					end
					if ID and table.find(Slots, ID) then
						task.spawn(function()
							local cooldown = Library.Network.Invoke("GetSlotRefreshTime")
							if cooldown and cooldown == 0 and AutoInteract then
								Library.Network.Fire("RequestSlotUsage", v.UID)
								FurnituresCooldowns[v] = nil
								wait(0.5)
							else
								FurnituresCooldowns[v] = tick() + (cooldown or 60)
							end
						end)
					end
					wait()
				end

				if AutoInteract then
					for furniture, cooldown in pairs(FurnituresCooldowns) do
						local ID = furniture.ID
						if cooldown and ID and tick() >= cooldown then
							if table.find(Wells, ID) and furniture.ClassName == "Furniture" and AutoInteract then
								task.spawn(function()
									UseWell(furniture.UID, ID)
									FurnituresCooldowns[furniture] = nil
								end)
							end
							if table.find(Slots, ID) and AutoInteract then
								Library.Network.Fire("RequestSlotUsage", furniture.UID)
								wait(1)
								FurnituresCooldowns[furniture] = nil
							end
						elseif not cooldown then
							FurnituresCooldowns[furniture] = nil
						end
					end
				end
			end
		end
		wait(1)
	end
end)()

-- Auto Buy Workers
local TiersLayout = {
	Cook = Library.Shared.CookTierLayout,
	Waiter = Library.Shared.WaiterTierLayout
}

function CheckIfCanBuy(className)
	local stats = Library.Stats.Get(true)
	if not stats then return end
	local allWorkers = Library.Variables.MyBakery:GetAllOfClassName(className)
	if not allWorkers then return end
	local level = Library.Experience.BakeryExperienceToLevel(Library.Variables.MyBakery.experience)
	for _, tier in pairs(TiersLayout[className]) do
		local alreadyOwned = false
		for _, worker in pairs(allWorkers) do
			if tier.Tier == worker.tier then alreadyOwned = true break end
		end
		if not alreadyOwned and tier.BakeryLevelRequired <= level and tier.Cost < stats.Cash and AutoBuyWorkers then
			Library.Network.Fire("RequestNPCPurchase", className, tier.Tier)
			wait(0.5)
		end
	end
end

Library.Network.Fired("BakeryLevelUp"):Connect(function()
	if not AutoBuyWorkers then return end
	CheckIfCanBuy("Cook")
	CheckIfCanBuy("Waiter")
end)

-- Webhook loop
coroutine.wrap(function()
	WebhookLastTime = tick()
	while true do
		if WebhookEnabled and WebhookURL ~= "" and tick() >= WebhookLastTime + (WebhookUpdateTime * 60) then
			SendWebhook(false)
		end
		wait(5)
	end
end)()

-- Players Handler
Players.PlayerAdded:Connect(function(player)
	if player ~= Player then
		AddTeleportToPlayerBakery(player)
		if AutoBlacklist and player.Name then
			Library.Network.Fire("BlacklistToggled", player.Name, true)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerTeleports[player] = nil
end)

-- Auto Blacklist new players
for _, player in pairs(Players:GetPlayers()) do
	if player ~= Player and AutoBlacklist and player.Name then
		Library.Network.Fire("BlacklistToggled", player.Name, true)
		wait(0.1)
	end
end

-------------------------//
--// Anti-AFK
-------------------------//
local VirtualUser = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

OrionLib:Init()

warn("Script Loaded!")
