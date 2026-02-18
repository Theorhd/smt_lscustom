local Vehicles
local totalModCost = 0
local currentVehicle = nil
local myCar, originalCar = {}, {}
local activePreview = nil
local menuOpen = false
local hintDisplayed = false
local isWorking = false

local isMechanic = false
local menus = {}
local colorCache = nil
local headerTxd = 'smtrp_lscustom_headers'
local headerMainAvailable = false
local headerSubAvailable = false
local headerTxdCreated = false
local headerTxdHandle = nil

local ZonesList = {}
for k, v in pairs(Config.Zones) do
    ZonesList[#ZonesList + 1] = { key = k, pos = v.Pos, hint = v.Hint }
end
local DrawDistanceSq = Config.DrawDistance * Config.DrawDistance

local function GetVehiclePrice(vehicle)
    local vehiclePrice = Config.DefaultVehiclePrice or 50000
    if not Vehicles then
        return vehiclePrice
    end

    local model = GetEntityModel(vehicle)
    for i = 1, #Vehicles, 1 do
        if model == joaat(Vehicles[i].model) then
            vehiclePrice = Vehicles[i].price
            break
        end
    end

    return vehiclePrice
end

local function IsModelAllowed(model)
    if Config.AllowedModels and next(Config.AllowedModels) then
        local modelName = GetDisplayNameFromVehicleModel(model)
        if Config.AllowedModels[model] or (modelName and Config.AllowedModels[string.lower(modelName)]) then
            return true
        end
        return false
    end

    if Config.BlockedModels and next(Config.BlockedModels) then
        local modelName = GetDisplayNameFromVehicleModel(model)
        if Config.BlockedModels[model] or (modelName and Config.BlockedModels[string.lower(modelName)]) then
            return false
        end
    end

    return true
end

local function GetColorEntries()
    if colorCache then
        return colorCache
    end

    colorCache = {}
    local groups = {'black', 'white', 'grey', 'red', 'pink', 'blue', 'yellow', 'green', 'orange', 'brown', 'purple', 'chrome', 'gold'}
    for _, group in ipairs(groups) do
        local colors = GetColors(group)
        for _, c in ipairs(colors) do
            colorCache[#colorCache + 1] = c
        end
    end

    return colorCache
end

local function EnsureHeaderTextures()
    local mainPath = 'stream/header.png'
    local subPath = 'stream/header-bg.png'

    if not headerMainAvailable then
        local mainData = LoadResourceFile(GetCurrentResourceName(), mainPath)
        if mainData then
            if not headerTxdCreated then
                headerTxdHandle = CreateRuntimeTxd(headerTxd)
                headerTxdCreated = true
            end
            CreateRuntimeTextureFromImage(headerTxdHandle, 'header', mainPath)
            headerMainAvailable = true
        end
    end

    if not headerSubAvailable then
        local subData = LoadResourceFile(GetCurrentResourceName(), subPath)
        if subData then
            if not headerTxdCreated then
                headerTxdHandle = CreateRuntimeTxd(headerTxd)
                headerTxdCreated = true
            end
            CreateRuntimeTextureFromImage(headerTxdHandle, 'header-bg', subPath)
            headerSubAvailable = true
        end
    end
end

local function ApplyMenuHeader(menuKey, menuData)
    local menu = menus[menuKey]
    if not menu or not menuData then
        return
    end

    menu:SetSubtitle(' ')

    if not menuData.parent then
        if headerMainAvailable then
            menu:SetSpriteBanner(headerTxd, 'header')
            if menu.Sprite and not menu.Sprite.Color then
                menu.Sprite.Color = { R = 255, G = 255, B = 255, A = 255 }
            end
            menu:SetTitle('')
        end
    else
        if headerSubAvailable then
            menu:SetSpriteBanner(headerTxd, 'header-bg')
            if menu.Sprite and not menu.Sprite.Color then
                menu.Sprite.Color = { R = 255, G = 255, B = 255, A = 255 }
            end
            menu:SetTitle(menuData.label or menu.Title)
        end
    end
end

local function ApplyVehicleProperties(vehicle, props)
    if not vehicle or vehicle == 0 or not props then
        return
    end

    if props.color1 ~= nil and type(props.color1) ~= 'table' then
        ClearVehicleCustomPrimaryColour(vehicle)
    end

    if props.color2 ~= nil and type(props.color2) ~= 'table' then
        ClearVehicleCustomSecondaryColour(vehicle)
    end

    ESX.Game.SetVehicleProperties(vehicle, props)
end

local function ClampColor(value)
    local num = tonumber(value) or 0
    if num < 0 then
        return 0
    end
    if num > 255 then
        return 255
    end
    return math.floor(num)
end

local function ClampColorIndex(value)
    local num = tonumber(value)
    if not num then
        return 0
    end

    num = math.floor(num)
    if num < 0 then
        return 0
    end

    return num
end

local function RevertToMyCar()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then
        return
    end

    ApplyVehicleProperties(vehicle, myCar)
    if not myCar.modTurbo then
        ToggleVehicleMod(vehicle, 18, false)
    end
    if not myCar.modXenon then
        ToggleVehicleMod(vehicle, 22, false)
    end
    if not myCar.windowTint then
        SetVehicleWindowTint(vehicle, 0)
    end
end

local function UpdateVehicleMod(modType, modIndex, customPrice, isPreview, wheelType)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then
        return
    end

    if isPreview then
        RevertToMyCar()
    end

    SetVehicleModKit(vehicle, 0)

    if modType == 'neonColor' then
        local rgb = modIndex
        if rgb[1] == 0 and rgb[2] == 0 and rgb[3] == 0 then
            for i = 0, 3 do
                SetVehicleNeonLightEnabled(vehicle, i, false)
            end
        else
            for i = 0, 3 do
                SetVehicleNeonLightEnabled(vehicle, i, true)
            end
            SetVehicleNeonLightsColour(vehicle, rgb[1], rgb[2], rgb[3])
        end
    elseif modType == 'tyreSmokeColor' then
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, modIndex[1], modIndex[2], modIndex[3])
    elseif modType == 'xenonColor' then
        if type(modIndex) == 'number' and modIndex ~= -1 then
            ToggleVehicleMod(vehicle, 22, true)
            SetVehicleXenonLightsColor(vehicle, modIndex)
        else
            ToggleVehicleMod(vehicle, 22, false)
        end
    elseif modType == 'windowTint' then
        SetVehicleWindowTint(vehicle, modIndex)
    elseif modType == 'plateIndex' then
        SetVehicleNumberPlateTextIndex(vehicle, modIndex)
    elseif modType == 'color1' then
        local _, color2 = GetVehicleColours(vehicle)
        if type(modIndex) == 'table' then
            SetVehicleCustomPrimaryColour(vehicle, modIndex[1], modIndex[2], modIndex[3])
        else
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, ClampColorIndex(modIndex), color2)
        end
    elseif modType == 'color2' then
        local color1, _ = GetVehicleColours(vehicle)
        if type(modIndex) == 'table' then
            SetVehicleCustomSecondaryColour(vehicle, modIndex[1], modIndex[2], modIndex[3])
        else
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, color1, ClampColorIndex(modIndex))
        end
    elseif modType == 'pearlescentColor' then
        local _, wheelColor = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, ClampColorIndex(modIndex), wheelColor)
    elseif modType == 'wheelColor' then
        local pearlescentColor, _ = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, pearlescentColor, ClampColorIndex(modIndex))
    elseif modType == 'modFrontWheels' or modType == 'modBackWheels' then
        if wheelType then
            SetVehicleWheelType(vehicle, wheelType)
        end
        SetVehicleMod(vehicle, (modType == 'modFrontWheels' and 23 or 24), modIndex, false)
    elseif type(modType) == 'number' then
        if modType == 17 then
            ToggleVehicleMod(vehicle, 18, modIndex)
        elseif modType == 22 then
            ToggleVehicleMod(vehicle, 22, modIndex)
        elseif modType == 48 then
            SetVehicleMod(vehicle, 48, modIndex, false)
            if modIndex == -1 then
                SetVehicleLivery(vehicle, 0)
            else
                SetVehicleLivery(vehicle, modIndex)
            end
        else
            SetVehicleMod(vehicle, modType, modIndex, false)
        end
    end

    if isPreview then
        activePreview = { modType = modType, modIndex = modIndex, price = customPrice, wheelType = wheelType }
    else
        if customPrice and customPrice > 0 then
            totalModCost = totalModCost + customPrice
            ESX.ShowNotification(TranslateCap('purchased') .. ' ~g~+$' .. customPrice)
        end
        myCar = ESX.Game.GetVehicleProperties(vehicle)
        activePreview = nil
    end
end

local function ComputeModPrice(menuData, modIndex)
    if not menuData or not menuData.price then
        return 0
    end

    local percent
    if type(menuData.price) == 'table' then
        percent = menuData.price[(modIndex or 0) + 1] or menuData.price[#menuData.price] or 0
    else
        percent = menuData.price or 0
    end

    local vehiclePrice = GetVehiclePrice(currentVehicle)
    return math.floor(vehiclePrice * percent / 100)
end

local function PositionMechanic3ForLscustom(vehicle, pointName)
    if not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local offsetX, offsetY, offsetZ, headingOffset = 0.0, 0.0, -0.35, 0.0

    if pointName == 'Rear' then
        offsetX, offsetY, offsetZ = 0.0, -2.50, -0.75
        headingOffset = 180.0
    elseif pointName == 'Left' then
        offsetX, offsetY, offsetZ = -1.20, 0.10, -0.35
        headingOffset = 90.0
    elseif pointName == 'Right' then
        offsetX, offsetY, offsetZ = 1.20, 0.10, -0.35
        headingOffset = -90.0
    end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local targetPos = GetOffsetFromEntityInWorldCoords(vehicle, offsetX, offsetY, offsetZ)
    RequestCollisionAtCoord(targetPos.x, targetPos.y, targetPos.z)
    Wait(50)

    local foundGround, groundZ = GetGroundZFor_3dCoord(targetPos.x, targetPos.y, targetPos.z + 2.0, false)

    if foundGround then
        local safeZ = groundZ + 0.02
        targetPos = vec3(targetPos.x, targetPos.y, safeZ)
    else
        targetPos = vec3(targetPos.x, targetPos.y, pedCoords.z)
    end

    SetEntityCoords(ped, targetPos.x, targetPos.y, targetPos.z, false, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(vehicle) + headingOffset)
    Wait(50)
end

local function StartMechanicWork(vehicle, propsToApply)
    isWorking = true
    local points = {
        { name = 'Front', offset = vector3(0.0, 2.5, 0.0), anim = 'welding', useMechanic3 = false },
        { name = 'Rear', offset = vector3(0.0, -2.5, 0.0), anim = 'hammering', useMechanic3 = true },
        { name = 'Left', offset = vector3(-1.5, 0.0, 0.0), anim = 'welding', useMechanic3 = true },
        { name = 'Right', offset = vector3(1.5, 0.0, 0.0), anim = 'hammering', useMechanic3 = true }
    }

    local progress = 0
    local completed = {false, false, false, false}

    ESX.ShowNotification(TranslateCap('perform_maintenance'))

    CreateThread(function()
        while progress < 4 and DoesEntityExist(vehicle) do
            local sleep = 1000
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)

            for i, pt in ipairs(points) do
                if not completed[i] then
                    local worldPos = GetOffsetFromEntityInWorldCoords(vehicle, pt.offset.x, pt.offset.y, pt.offset.z)
                    local dist = #(plyCoords - worldPos)

                    if dist < 5.0 then
                        sleep = 0
                        DrawMarker(2, worldPos.x, worldPos.y, worldPos.z + 0.5, 0, 0, 0, 0, 180.0, 0, 0.3, 0.3, 0.3, 255, 255, 0, 150, true, true, 2, false, nil, nil, false)

                        if dist < 1.5 then
                            ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to work on ' .. TranslateCap('side_' .. string.lower(pt.name)))
                            if IsControlJustReleased(0, 38) then
                                TaskTurnPedToFaceCoord(plyPed, worldPos.x, worldPos.y, worldPos.z, 1000)
                                Wait(1000)

                                local openedHood = false
                                if pt.name == 'Front' then
                                    SetVehicleDoorOpen(vehicle, 4, false, false)
                                    openedHood = true
                                end

                                if pt.useMechanic3 then
                                    PositionMechanic3ForLscustom(vehicle, pt.name)
                                    TriggerEvent('animations:client:EmoteCommandStart', { 'mechanic3' })
                                end

                                local ok = lib.progressBar({
                                    duration = pt.useMechanic3 and 10000 or 5000,
                                    label = (pt.anim == 'welding' and TranslateCap('welding') or TranslateCap('hammering')) .. ' ' .. TranslateCap('side_' .. string.lower(pt.name)),
                                    useWhileDead = false,
                                    canCancel = true,
                                    disable = { move = true, car = true },
                                    anim = (not pt.useMechanic3) and (pt.anim == 'welding'
                                        and { dict = 'mini@repair', clip = 'fixing_a_ped' }
                                        or { dict = 'missmechanic', clip = 'work_base' }) or nil
                                })

                                if pt.useMechanic3 then
                                    ExecuteCommand('e c')
                                end

                                if openedHood then
                                    SetVehicleDoorShut(vehicle, 4, false)
                                end

                                if ok then
                                    completed[i] = true
                                    progress = progress + 1
                                end
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end

        if progress >= 4 then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            TriggerServerEvent('smtrp_lscustom:refreshOwnedVehicle', propsToApply, netId)
            TriggerServerEvent('smtrp_lscustom:stopModing', propsToApply.plate)

            ApplyVehicleProperties(vehicle, propsToApply)

            ESX.ShowNotification(TranslateCap('mods_applied'))
            FreezeEntityPosition(vehicle, false)
            currentVehicle = nil
            isWorking = false
        end
    end)
end

local function CloseAllMenus()
    for _, menu in pairs(menus) do
        RageUI.Visible(menu, false)
    end
    menuOpen = false
end

local function ResetCustomizationState()
    totalModCost = 0
    activePreview = nil
    currentVehicle = nil
end

local function CancelCustomization(reason)
    CloseAllMenus()

    local vehicle = currentVehicle
    if vehicle and vehicle ~= 0 then
        ApplyVehicleProperties(vehicle, originalCar)
        FreezeEntityPosition(vehicle, false)
        TriggerServerEvent('smtrp_lscustom:stopModing', originalCar.plate)
    end

    ResetCustomizationState()

    if reason == 'menu_closed' then
        ESX.ShowNotification(TranslateCap('custom_cancelled'))
    end
end

local function IsAnyMenuVisible()
    for _, menu in pairs(menus) do
        if RageUI.Visible(menu) then
            return true
        end
    end
    return false
end

local function EnsureMenu(menuKey)
    if menus[menuKey] then
        return
    end

    local menuData = Config.Menus[menuKey]
    if not menuData then
        return
    end

    if not menuData.parent then
        menus[menuKey] = RageUI.CreateMenu(menuData.label, ' ')
    else
        EnsureMenu(menuData.parent)
        menus[menuKey] = RageUI.CreateSubMenu(menus[menuData.parent], menuData.label, ' ')
    end

    ApplyMenuHeader(menuKey, menuData)
end

local function BuildMenus()
    EnsureHeaderTextures()
    for key, _ in pairs(Config.Menus) do
        EnsureMenu(key)
    end
end

local function FinishCustomization(action)
    local vehicle = currentVehicle
    CloseAllMenus()

    if not vehicle or vehicle == 0 then
        return
    end

    if action == 'save' then
        if totalModCost > 0 then
            ESX.ShowNotification(TranslateCap('quote_saved', totalModCost))
            TriggerServerEvent('smtrp_lscustom:savePendingCustom', originalCar.plate, totalModCost)

            TaskLeaveVehicle(PlayerPedId(), vehicle, 0)
            ApplyVehicleProperties(vehicle, originalCar)
            Wait(2000)
            StartMechanicWork(vehicle, myCar)
        else
            ESX.ShowNotification(TranslateCap('vehicle_unmodified'))
            FreezeEntityPosition(vehicle, false)
            activePreview = nil
        end
    elseif action == 'personal' then
        if totalModCost > 0 then
            ESX.TriggerServerCallback('smtrp_lscustom:payPersonal', function(success)
                if success then
                    ESX.ShowNotification(TranslateCap('purchased'))
                    TaskLeaveVehicle(PlayerPedId(), vehicle, 0)
                    ApplyVehicleProperties(vehicle, originalCar)
                    Wait(2000)
                    StartMechanicWork(vehicle, myCar)
                else
                    ESX.ShowNotification(TranslateCap('not_enough_money'))
                    ApplyVehicleProperties(vehicle, originalCar)
                    FreezeEntityPosition(vehicle, false)
                    TriggerServerEvent('smtrp_lscustom:stopModing', originalCar.plate)
                    activePreview = nil
                end
            end, totalModCost)
        else
            ESX.ShowNotification(TranslateCap('vehicle_unmodified'))
            FreezeEntityPosition(vehicle, false)
            activePreview = nil
        end
    else
        ApplyVehicleProperties(vehicle, originalCar)
        ESX.ShowNotification(TranslateCap('custom_cancelled'))
        FreezeEntityPosition(vehicle, false)
        TriggerServerEvent('smtrp_lscustom:stopModing', originalCar.plate)
        ResetCustomizationState()
    end
end

local function IsMenuAvailable(menuKey, vehicle)
    local menuData = Config.Menus[menuKey]
    if not menuData then
        return false
    end

    if menuData.modType then
        local modType = menuData.modType
        if type(modType) == 'number' then
            if modType == 17 or modType == 22 then
                return true
            end

            local realModType = modType
            if menuKey == 'modFrontWheels' then
                realModType = 23
            elseif menuKey == 'modBackWheels' then
                realModType = 24
            end

            if realModType == 23 or realModType == 24 then
                return true
            end

            local modCount = GetNumVehicleMods(vehicle, realModType)
            if realModType == 48 then
                local liveryCount = GetVehicleLiveryCount(vehicle)
                if liveryCount and liveryCount > modCount then
                    modCount = liveryCount
                end
            end
            return modCount > 0
        else
            return true
        end
    end

    for k, v in pairs(menuData) do
        if k ~= 'label' and k ~= 'parent' and k ~= 'modType' and k ~= 'price' and k ~= 'wheelType' and Config.Menus[k] then
            if IsMenuAvailable(k, vehicle) then
                return true
            end
        end
    end

    return false
end

local function RenderMenu(menuKey)
    local menuData = Config.Menus[menuKey]
    if not menuData then
        return
    end

    local vehicle = currentVehicle or GetVehiclePedIsIn(PlayerPedId(), false)

    local subMenus = {}
    for k, v in pairs(menuData) do
        if k ~= 'label' and k ~= 'parent' and k ~= 'modType' and k ~= 'price' and k ~= 'wheelType' and Config.Menus[k] then
            if IsMenuAvailable(k, vehicle) then
                subMenus[#subMenus + 1] = { key = k, label = v }
            end
        end
    end
    table.sort(subMenus, function(a, b) return a.label < b.label end)

    for _, sub in ipairs(subMenus) do
        RageUI.Button(sub.label, nil, { RightLabel = '>' }, true, {}, menus[sub.key])
    end

    if menuData.modType and vehicle and vehicle ~= 0 then
        local modType = menuData.modType

        if modType == 'color1' or modType == 'color2' or modType == 'pearlescentColor' or modType == 'wheelColor' then
            local colors = GetColorEntries()
            local curCol1, curCol2 = GetVehicleColours(vehicle)
            local curPear, curWheel = GetVehicleExtraColours(vehicle)
            local price = ComputeModPrice(menuData, 0)
            local primaryCustom = GetIsVehiclePrimaryColourCustom(vehicle)
            local secondaryCustom = GetIsVehicleSecondaryColourCustom(vehicle)

            if modType == 'color1' or modType == 'color2' then
                local isPrimary = (modType == 'color1')
                local isCustom = isPrimary and primaryCustom or secondaryCustom
                local cr, cg, cb
                if isCustom then
                    if isPrimary then
                        cr, cg, cb = GetVehicleCustomPrimaryColour(vehicle)
                    else
                        cr, cg, cb = GetVehicleCustomSecondaryColour(vehicle)
                    end
                end

                local customLabel = TranslateCap('custom_rgb')
                if isCustom and cr and cg and cb then
                    customLabel = customLabel .. string.format(' (%d,%d,%d)', cr, cg, cb)
                end

                RageUI.Button(customLabel, nil, { RightLabel = isCustom and TranslateCap('installed') or ('$' .. price) }, true, {
                    onSelected = function()
                        local input = lib.inputDialog(TranslateCap('custom_rgb'), {
                            { type = 'number', label = 'R', min = 0, max = 255, default = cr or 0 },
                            { type = 'number', label = 'G', min = 0, max = 255, default = cg or 0 },
                            { type = 'number', label = 'B', min = 0, max = 255, default = cb or 0 }
                        })

                        if not input then
                            return
                        end

                        local r = ClampColor(input[1])
                        local g = ClampColor(input[2])
                        local b = ClampColor(input[3])
                        UpdateVehicleMod(modType, { r, g, b }, price, true, nil)
                    end
                })

                RageUI.Separator()
            end

            for _, c in ipairs(colors) do
                local isInstalled = false
                if modType == 'color1' then
                    isInstalled = (not primaryCustom) and (curCol1 == c.index)
                elseif modType == 'color2' then
                    isInstalled = (not secondaryCustom) and (curCol2 == c.index)
                elseif modType == 'pearlescentColor' then
                    isInstalled = (curPear == c.index)
                elseif modType == 'wheelColor' then
                    isInstalled = (curWheel == c.index)
                end

                if modType == 'pearlescentColor' and c == colors[1] then
                    local basePearlescent = (originalCar and originalCar.pearlescentColor) or 0
                    local noneInstalled = (curPear == basePearlescent)
                    RageUI.Button('Aucun nacrage', nil, { RightLabel = noneInstalled and TranslateCap('installed') or '$0' }, not noneInstalled, {
                        onSelected = function()
                            UpdateVehicleMod(modType, basePearlescent, 0, true, nil)
                        end
                    })
                    RageUI.Separator()
                end

                RageUI.Button(c.label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                    onSelected = function()
                        UpdateVehicleMod(modType, c.index, price, true, nil)
                    end
                })
            end
        elseif modType == 'neonColor' then
            local neons = GetNeons()
            local price = ComputeModPrice(menuData, 0)
            local hasAny = false
            for i = 0, 3 do
                if IsVehicleNeonLightEnabled(vehicle, i) then
                    hasAny = true
                    break
                end
            end

            RageUI.Button(TranslateCap('by_default'), nil, { RightLabel = hasAny and '$0' or TranslateCap('installed') }, hasAny, {
                onSelected = function()
                    UpdateVehicleMod(modType, {0, 0, 0}, 0, true, nil)
                end
            })

            local r, g, b = GetVehicleNeonLightsColour(vehicle)
            for _, n in ipairs(neons) do
                local isInstalled = hasAny and r == n.r and g == n.g and b == n.b
                RageUI.Button(n.label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                    onSelected = function()
                        UpdateVehicleMod(modType, {n.r, n.g, n.b}, price, true, nil)
                    end
                })
            end
        elseif modType == 'xenonColor' then
            local xenons = GetXenonColors()
            local price = ComputeModPrice(menuData, 0)
            local curXenon = GetVehicleXenonLightsColor(vehicle)
            local hasXenon = IsToggleModOn(vehicle, 22)

            for _, x in ipairs(xenons) do
                local isInstalled = (hasXenon and curXenon == x.index) or (x.index == -1 and not hasXenon)
                RageUI.Button(x.label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                    onSelected = function()
                        UpdateVehicleMod(modType, x.index, price, true, nil)
                    end
                })
            end
        elseif modType == 'plateIndex' then
            local price = ComputeModPrice(menuData, 0)
            local maxJ = (GetGameBuildNumber() >= 3095) and 12 or 5
            local curPlate = GetVehicleNumberPlateTextIndex(vehicle)
            for j = 0, maxJ do
                local label = GetPlatesName and GetPlatesName(j) or tostring(j)
                local isInstalled = (curPlate == j)
                RageUI.Button(label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                    onSelected = function()
                        UpdateVehicleMod(modType, j, price, true, nil)
                    end
                })
            end
        elseif modType == 'windowTint' then
            local price = ComputeModPrice(menuData, 0)
            local curTint = GetVehicleWindowTint(vehicle)
            for j = 1, 5 do
                local label = GetWindowName and GetWindowName(j) or tostring(j)
                local isInstalled = (curTint == j)
                RageUI.Button(label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                    onSelected = function()
                        UpdateVehicleMod(modType, j, price, true, nil)
                    end
                })
            end
        else
            local realModType = modType
            if menuKey == 'modFrontWheels' then
                realModType = 23
            elseif menuKey == 'modBackWheels' then
                realModType = 24
            end

            if menuData.wheelType then
                SetVehicleWheelType(vehicle, menuData.wheelType)
            end

            local modCount = GetNumVehicleMods(vehicle, realModType)
            local curMod = GetVehicleMod(vehicle, realModType)
            local curLivery = nil
            if realModType == 48 then
                local liveryCount = GetVehicleLiveryCount(vehicle)
                if liveryCount and liveryCount > modCount then
                    modCount = liveryCount
                end
                curLivery = GetVehicleLivery(vehicle)
            end

            local isDefault = curMod == -1
            if realModType == 48 then
                isDefault = curMod == -1 and (curLivery or 0) == 0
            end

            RageUI.Button(TranslateCap('by_default'), nil, { RightLabel = isDefault and TranslateCap('installed') or '$0' }, not isDefault, {
                onSelected = function()
                    UpdateVehicleMod(realModType, -1, 0, true, menuData.wheelType)
                end
            })

            if modCount > 0 then
                for j = 0, modCount - 1 do
                    local modName = GetModTextLabel(vehicle, realModType, j)
                    local label = modName and GetLabelText(modName) or TranslateCap('level', j + 1)
                    if label == 'NULL' then
                        label = TranslateCap('level', j + 1)
                    end

                    local price = ComputeModPrice(menuData, j)

                    local currentIndex = curMod
                    if realModType == 48 and curMod == -1 then
                        currentIndex = curLivery or 0
                    end

                    local isInstalled = (currentIndex == j)
                    RageUI.Button(label, nil, { RightLabel = isInstalled and TranslateCap('installed') or ('$' .. price) }, not isInstalled, {
                        onSelected = function()
                            UpdateVehicleMod(realModType, j, price, true, menuData.wheelType)
                        end
                    })
                end
            end

            if realModType == 17 then
                local price = ComputeModPrice(menuData, 0)
                local hasTurbo = IsToggleModOn(vehicle, 18)
                RageUI.Button(TranslateCap('no_turbo'), nil, { RightLabel = (not hasTurbo) and TranslateCap('installed') or '$0' }, hasTurbo, {
                    onSelected = function()
                        UpdateVehicleMod(17, false, 0, true, nil)
                    end
                })
                RageUI.Button(TranslateCap('turbo_tuning'), nil, { RightLabel = hasTurbo and TranslateCap('installed') or ('$' .. price) }, not hasTurbo, {
                    onSelected = function()
                        UpdateVehicleMod(17, true, price, true, nil)
                    end
                })
            end

            if realModType == 22 then
                local price = ComputeModPrice(menuData, 0)
                local hasXenon = IsToggleModOn(vehicle, 22)
                RageUI.Button(TranslateCap('no_xenon'), nil, { RightLabel = (not hasXenon) and TranslateCap('installed') or '$0' }, hasXenon, {
                    onSelected = function()
                        UpdateVehicleMod(22, false, 0, true, nil)
                    end
                })
                RageUI.Button(TranslateCap('xenon_lights'), nil, { RightLabel = hasXenon and TranslateCap('installed') or ('$' .. price) }, not hasXenon, {
                    onSelected = function()
                        UpdateVehicleMod(22, true, price, true, nil)
                    end
                })
            end
        end

        RageUI.Separator()
        RageUI.Button(TranslateCap('confirm'), nil, { RightLabel = activePreview and ('$' .. activePreview.price) or '' }, activePreview ~= nil, {
            onSelected = function()
                if activePreview then
                    UpdateVehicleMod(activePreview.modType, activePreview.modIndex, activePreview.price, false, activePreview.wheelType)
                end
            end
        })
        RageUI.Button(TranslateCap('cancel'), nil, {}, true, {
            onSelected = function()
                RevertToMyCar()
                activePreview = nil
            end
        })
    end

    if menuKey == 'main' then
        RageUI.Separator()
        if isMechanic or Config.IsMechanicJobOnly then
            RageUI.Button(TranslateCap('confirm_quote'), TranslateCap('total_quote') .. totalModCost, {}, totalModCost > 0, {
                onSelected = function()
                    FinishCustomization('save')
                end
            })

			if isMechanic then
				RageUI.Button('Confirmer le devis pour vous', TranslateCap('total_quote') .. totalModCost, {}, totalModCost > 0, {
					onSelected = function()
						local myServerId = GetPlayerServerId(PlayerId())
						TriggerServerEvent('esx_billing:sendBill', myServerId, 'society_mechanic', TranslateCap('custom_labor'), totalModCost)
						FinishCustomization('save')
					end
				})
			end
        end

        if not Config.IsMechanicJobOnly then
            RageUI.Button(TranslateCap('pay_personal'), TranslateCap('pay_personal_desc', totalModCost), {}, totalModCost > 0, {
                onSelected = function()
                    FinishCustomization('personal')
                end
            })
        end

        RageUI.Button(TranslateCap('cancel_quote'), nil, {}, true, {
            onSelected = function()
                FinishCustomization('cancel')
            end
        })
    end
end

local function OpenMenu()
    BuildMenus()
    RageUI.Visible(menus.main, true)
    menuOpen = true
end

RegisterNetEvent('smtrp_lscustom:restoreMods', function(netId, props)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        ApplyVehicleProperties(entity, props)
    end
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    isMechanic = xPlayer and xPlayer.job and xPlayer.job.name == 'mechanic' or false
    ESX.TriggerServerCallback('smtrp_lscustom:getVehiclesPrices', function(vehicles)
        Vehicles = vehicles
    end)
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
    isMechanic = job and job.name == 'mechanic' or false
end)

CreateThread(function()
    local options = {
        {
            name = 'mechanic_bill_customs',
            label = TranslateCap('bill_custom'),
            icon = 'fa-solid fa-file-invoice-dollar',
            groups = 'mechanic',
            onSelect = function(data)
                local targetPlayer = data.entity
                local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPlayer))

                ESX.TriggerServerCallback('smtrp_lscustom:getPendingBill', function(pendingPrice, plate)
                    if not pendingPrice or pendingPrice == 0 then
                        ESX.ShowNotification(TranslateCap('no_pending_bill'))
                        return
                    end

                    local input = lib.inputDialog(TranslateCap('create_invoice'), {
                        {type = 'input', label = TranslateCap('plate'), default = plate, disabled = true},
                        {type = 'number', label = TranslateCap('parts_cost'), default = pendingPrice, disabled = true},
                        {type = 'number', label = TranslateCap('labor_fees'), default = 0, min = 0}
                    })

                    if not input then
                        return
                    end

                    local labor = input[3] or 0
                    local total = pendingPrice + labor

                    TriggerServerEvent('esx_billing:sendBill', targetServerId, 'society_mechanic', TranslateCap('custom_labor'), total)
                    TriggerServerEvent('smtrp_lscustom:clearPendingCustom', plate)
                end, targetServerId)
            end
        }
    }

    if exports.ox_target then
        exports.ox_target:addGlobalPlayer(options)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1500
        local playerPed = PlayerPedId()

        if IsPedInAnyVehicle(playerPed, false) and not isWorking then
            local coords = GetEntityCoords(playerPed)
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            if GetPedInVehicleSeat(vehicle, -1) == playerPed then
                if (isMechanic or not Config.IsMechanicJobOnly) and IsModelAllowed(GetEntityModel(vehicle)) then
                    for i = 1, #ZonesList do
                        local zone = ZonesList[i]
                        local dx = coords.x - zone.pos.x
                        local dy = coords.y - zone.pos.y
                        local dz = coords.z - zone.pos.z
                        local distSq = (dx * dx) + (dy * dy) + (dz * dz)

                        if distSq < DrawDistanceSq then
                            sleep = 0
                            if not menuOpen then
                                if not hintDisplayed then
                                    hintDisplayed = true
                                    ESX.TextUI(zone.hint)
                                end
                                if IsControlJustReleased(0, 38) then
                                    menuOpen = true
                                    totalModCost = 0
                                    activePreview = nil

                                    FreezeEntityPosition(vehicle, true)
                                    SetVehicleModKit(vehicle, 0)
                                    myCar = ESX.Game.GetVehicleProperties(vehicle)
                                    originalCar = ESX.Game.GetVehicleProperties(vehicle)
                                    currentVehicle = vehicle

                                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                                    TriggerServerEvent('smtrp_lscustom:startModing', myCar, netId)

                                    OpenMenu()
                                    ESX.HideUI()
                                end
                            end
                            break
                        end
                    end

                    if menuOpen then
                        local stillDriver = IsPedInVehicle(playerPed, vehicle, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed
                        if not stillDriver then
                            CancelCustomization('menu_closed')
                        end
                    end

                    if not menuOpen and hintDisplayed then
                        local nearby = false
                        for i = 1, #ZonesList do
                            local zone = ZonesList[i]
                            local dx = coords.x - zone.pos.x
                            local dy = coords.y - zone.pos.y
                            local dz = coords.z - zone.pos.z
                            local distSq = (dx * dx) + (dy * dy) + (dz * dz)
                            if distSq < DrawDistanceSq then
                                nearby = true
                                break
                            end
                        end
                        if not nearby then
                            hintDisplayed = false
                            ESX.HideUI()
                        end
                    end
                end
            end
        end

        if menuOpen then
            sleep = 0
            DisableControlAction(2, 288, true)
            DisableControlAction(2, 289, true)
            DisableControlAction(2, 170, true)
            DisableControlAction(2, 167, true)
            DisableControlAction(2, 168, true)
            DisableControlAction(2, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(27, 75, true)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            local anyVisible = false
            for menuKey, menu in pairs(menus) do
                if RageUI.Visible(menu) then
                    anyVisible = true
                end
                RageUI.IsVisible(menu, function()
                    RenderMenu(menuKey)
                end)
            end
            if not anyVisible then
                CancelCustomization('menu_closed')
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
