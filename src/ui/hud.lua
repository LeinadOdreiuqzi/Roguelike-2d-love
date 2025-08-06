-- src/ui/hud.lua (SOPORTE 3D Y LÍMITES DEL MUNDO)

local HUD = {}

-- Importar el módulo de sistema de semillas externo
local SeedSystem = require 'src.utils.seed_system'

-- Estado del HUD unificado
local hudState = {
    showInfo = true,
    showSeedInput = false,
    showBiomeInfo = true,
    show3DDebug = false,    
    showWorldLimits = false, 
    seedInputText = "",
    font = nil,
    smallFont = nil,
    tinyFont = nil
}

-- Lista de semillas predefinidas alfanuméricas optimizadas (sin cambios)
local presetSeeds = {
    {name = "Random", seed = SeedSystem.generate()},
    {name = "Dense Nebula", seed = "A5N9E3B7U1"},
    {name = "Open Void", seed = "S2P4A6C8E0"},
    {name = "Asteroid Fields", seed = "R3O7C9K2S6"},
    {name = "Ancient Mysteries", seed = "M1Y8S4T6I3"},
    {name = "Radiation Storm", seed = "H2A5Z9R3D7"},
    {name = "Crystal Caverns", seed = "C4R8Y1S5T9"},
    {name = "Quantum Rifts", seed = "Q3U6A7N2T4"},
    {name = "Lost Worlds", seed = "L6O1S4T9W3"},
    {name = "Deep Explorer", seed = "E2X8P5L7O9"}
}
local currentPresetIndex = 1

-- Referencias externas
local gameState = nil
local player = nil
local Map = nil
local BiomeSystem = nil
local CoordinateSystem = nil  --Referencia al sistema de coordenadas

-- Cache de información de bioma del jugador (mejorado)
local biomeCache = {
    lastUpdate = 0,
    updateInterval = 0.5,
    currentBiome = nil,
    biomeHistory = {},
    maxHistory = 10,
    current3DParams = nil,  -- Parámetros 3D actuales
    worldLimitInfo = nil    -- Info de límites del mundo
}

-- LÍMITES DEL MUNDO
local WORLD_LIMIT = 200000

-- Inicialización del HUD
function HUD.init(gameStateRef, playerRef, mapRef)
    hudState.font = love.graphics.newFont(13)
    hudState.smallFont = love.graphics.newFont(11)
    hudState.tinyFont = love.graphics.newFont(9)
    
    gameState = gameStateRef
    player = playerRef
    Map = mapRef
    
    -- Obtener referencia al sistema de biomas
    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)
    
    if success then
        BiomeSystem = biomeSystemModule
        print("HUD: BiomeSystem loaded successfully")
    else
        print("HUD: BiomeSystem not available")
    end
    
    -- Obtener referencia al sistema de coordenadas
    local coordSuccess, coordSystemModule = pcall(function()
        return require 'src.maps.coordinate_system'
    end)
    
    if coordSuccess then
        CoordinateSystem = coordSystemModule
        print("HUD: CoordinateSystem loaded successfully")
    else
        print("HUD: CoordinateSystem not available")
    end
    
    -- Regenerar semillas aleatorias en presets
    for i, preset in ipairs(presetSeeds) do
        if preset.name == "Random" then
            preset.seed = SeedSystem.generate()
        end
    end
    
    print("Enhanced HUD system initialized with 3D biome support and world limits")
end

-- Función de actualización principal del HUD
function HUD.update(dt)
    HUD.updateBiomeInfo(dt)
    HUD.updateWorldLimitInfo(dt) 
end

-- Actualizar información de límites del mundo
function HUD.updateWorldLimitInfo(dt)
    if not player or not CoordinateSystem then return end
    
    local currentTime = love.timer.getTime()
    
    if currentTime - (biomeCache.lastLimitUpdate or 0) >= 1.0 then  -- Cada segundo
        local success, limitInfo = pcall(function()
            local warnings, distanceToLimit = CoordinateSystem.getLimitWarnings(player.x, player.y)
            local isNearLimit = CoordinateSystem.isNearLimit and CoordinateSystem.isNearLimit(player.x, player.y) or false
            
            return {
                distanceToLimit = distanceToLimit,
                warnings = warnings,
                isNearLimit = isNearLimit,
                withinLimits = CoordinateSystem.isWithinWorldLimits(player.x, player.y),
                worldSize = WORLD_LIMIT * 2,
                currentPosition = {x = player.x, y = player.y}
            }
        end)
        
        if success and limitInfo then
            biomeCache.worldLimitInfo = limitInfo
        end
        
        biomeCache.lastLimitUpdate = currentTime
    end
end

-- Actualizar información de bioma del jugador
function HUD.updateBiomeInfo(dt)
    local currentTime = love.timer.getTime()
    
    if currentTime - biomeCache.lastUpdate >= biomeCache.updateInterval then
        if player and player.x and player.y and BiomeSystem then
            local success, currentBiome = pcall(function()
                if BiomeSystem.updatePlayerBiome then
                    return BiomeSystem.updatePlayerBiome(player.x, player.y)
                end
                return nil
            end)
            
            --Obtener parámetros 3D actuales
            local params3DSuccess, current3DParams = pcall(function()
                if BiomeSystem.getPlayerBiomeInfo then
                    local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
                    return biomeInfo.parameters or nil
                end
                return nil
            end)
            
            if success and currentBiome then
                if biomeCache.currentBiome ~= currentBiome then
                    local configSuccess, config = pcall(function()
                        if BiomeSystem.getBiomeConfig then
                            return BiomeSystem.getBiomeConfig(currentBiome)
                        end
                        return nil
                    end)
                    
                    if configSuccess and config then
                        table.insert(biomeCache.biomeHistory, 1, {
                            biome = currentBiome,
                            time = currentTime,
                            config = config,
                            parameters3D = params3DSuccess and current3DParams or nil  -- NUEVO
                        })
                        
                        if #biomeCache.biomeHistory > biomeCache.maxHistory then
                            table.remove(biomeCache.biomeHistory)
                        end
                        
                        biomeCache.currentBiome = currentBiome
                    end
                end
                
                -- Actualizar parámetros 3D actuales
                if params3DSuccess and current3DParams then
                    biomeCache.current3DParams = current3DParams
                end
            end
        end
        
        biomeCache.lastUpdate = currentTime
    end
end

-- Función de compatibilidad para estadísticas
function HUD.getSafeStats()
    local stats = {
        loadedChunks = 0,
        cachedChunks = 0,
        seed = "UNKNOWN00",
        worldScale = 1,
        frameTime = 0,
        biomesActive = 0,
        fps = love.timer.getFPS(),
        renderStats = {
            totalObjects = 0,
            renderedObjects = 0,
            culledObjects = 0
        },
        -- Estadísticas de límites del mundo
        worldLimits = {
            enabled = true,
            maxSize = WORLD_LIMIT,
            totalSize = WORLD_LIMIT * 2,
            distanceToLimit = 0,
            nearLimit = false,
            withinLimits = true
        },
        -- Estadísticas 3D
        biome3D = {
            hasParameters = false,
            parameters = nil
        }
    }
    
    -- Obtener semilla actual de forma segura
    if gameState and gameState.currentSeed then
        stats.seed = gameState.currentSeed
    end
    
    -- Información de límites del mundo
    if player and CoordinateSystem then
        local limitSuccess, limitData = pcall(function()
            return {
                distanceToLimit = CoordinateSystem.getDistanceToLimit and CoordinateSystem.getDistanceToLimit(player.x, player.y) or 0,
                nearLimit = CoordinateSystem.isNearLimit and CoordinateSystem.isNearLimit(player.x, player.y) or false,
                withinLimits = CoordinateSystem.isWithinWorldLimits and CoordinateSystem.isWithinWorldLimits(player.x, player.y) or true
            }
        end)
        
        if limitSuccess and limitData then
            stats.worldLimits.distanceToLimit = limitData.distanceToLimit
            stats.worldLimits.nearLimit = limitData.nearLimit
            stats.worldLimits.withinLimits = limitData.withinLimits
        end
    end
    
    -- Información de parámetros 3D
    if biomeCache.current3DParams then
        stats.biome3D.hasParameters = true
        stats.biome3D.parameters = biomeCache.current3DParams
    end
    
    -- Obtener información básica del Map de forma segura
    if Map then
        if Map.seed then stats.seed = Map.seed end
        if Map.worldScale then stats.worldScale = Map.worldScale end
        
        local success, mapStats = pcall(function() 
            if Map.getStats then
                return Map.getStats() 
            end
            return nil
        end)
        
        if success and mapStats then
            if mapStats.chunks then
                stats.chunks = mapStats.chunks
            elseif mapStats.loadedChunks then
                stats.loadedChunks = mapStats.loadedChunks
            end
            
            if mapStats.rendering then
                stats.rendering = mapStats.rendering
            elseif mapStats.renderStats then
                stats.renderStats = mapStats.renderStats
            end
            
            if mapStats.coordinates then
                stats.coordinates = mapStats.coordinates
            end
            
            if mapStats.frameTime then stats.frameTime = mapStats.frameTime end
            if mapStats.biomesActive then stats.biomesActive = mapStats.biomesActive end
        else
            if Map.renderStats then 
                stats.renderStats = Map.renderStats
                stats.biomesActive = Map.renderStats.biomesActive or 0
            end
            
            if Map.chunks then
                pcall(function()
                    for x, row in pairs(Map.chunks) do
                        for y, chunk in pairs(row) do
                            if chunk then stats.loadedChunks = stats.loadedChunks + 1 end
                        end
                    end
                end)
            end
        end
    end
    
    return stats
end

-- Calcular coordenadas de chunk de forma segura
function HUD.getSafeChunkCoords(worldX, worldY)
    local chunkX, chunkY = 0, 0
    
    if Map then
        local success, cx, cy = pcall(function()
            if Map.getChunkInfo then
                return Map.getChunkInfo(worldX, worldY)
            end
            return nil, nil
        end)
        
        if success and cx and cy then
            return cx, cy
        end
        
        if Map.chunkSize and Map.tileSize then
            local chunkSize = Map.chunkSize * Map.tileSize
            chunkX = math.floor(worldX / chunkSize)
            chunkY = math.floor(worldY / chunkSize)
        end
    end
    
    return chunkX, chunkY
end

-- Dibujar todo el HUD
function HUD.draw()
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de información unificado
    if hudState.showInfo then
        HUD.drawUnifiedInfoPanel()
    end
    
    -- Panel de información de biomas
    if hudState.showBiomeInfo then
        HUD.drawBiomeInfoPanel()
    end
    
    -- Panel de debug 3D
    if hudState.show3DDebug then
        HUD.draw3DDebugPanel()
    end
    
    -- Panel de límites del mundo
    if hudState.showWorldLimits then
        HUD.drawWorldLimitsPanel()
    end
    
    -- Input de semilla alfanumérica
    if hudState.showSeedInput then
        HUD.drawSeedInput()
    end
    
    -- Información de la semilla actual 
    HUD.drawCurrentSeedInfo()
    
    -- HUD del jugador (barras de vida, escudo, combustible)
    if player and player.stats then
        HUD.drawPlayerHUD()
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Panel de debug 3D
function HUD.draw3DDebugPanel()
    if not player or not BiomeSystem then return end
    
    local panelWidth = 400
    local panelHeight = 350
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = love.graphics.getHeight() - panelHeight - 100
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(1, 0.5, 0, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(1, 0.8, 0, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("3D BIOME SYSTEM DEBUG", x + 10, y + 8)
    
    local infoY = y + 30
    local lineHeight = 12
    
    -- Información de parámetros 3D
    if biomeCache.current3DParams then
        love.graphics.setColor(0.8, 1, 1, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("FALSE HEIGHT SYSTEM", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(hudState.tinyFont)
        
        local params = biomeCache.current3DParams
        
        -- Energía Espacial
        local energyColor = params.energy > 0 and {1, 0.8, 0.5, 1} or {0.5, 0.8, 1, 1}
        love.graphics.setColor(energyColor)
        love.graphics.print("Energy: " .. string.format("%.3f", params.energy), x + 15, infoY)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("(Spatial Temperature)", x + 120, infoY)
        infoY = infoY + lineHeight
        
        -- Densidad de Materia
        local densityColor = params.density > 0 and {0.8, 1, 0.8, 1} or {1, 0.8, 0.8, 1}
        love.graphics.setColor(densityColor)
        love.graphics.print("Density: " .. string.format("%.3f", params.density), x + 15, infoY)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("(Matter Concentration)", x + 120, infoY)
        infoY = infoY + lineHeight
        
        -- Continentalidad
        local contColor = params.continentalness > 0 and {0.8, 0.8, 1, 1} or {0.6, 0.6, 0.8, 1}
        love.graphics.setColor(contColor)
        love.graphics.print("Continental: " .. string.format("%.3f", params.continentalness), x + 15, infoY)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("(Distance from Deep Space)", x + 120, infoY)
        infoY = infoY + lineHeight
        
        -- Turbulencia
        local turbColor = math.abs(params.turbulence) > 0.5 and {1, 0.6, 0.6, 1} or {0.8, 0.8, 0.8, 1}
        love.graphics.setColor(turbColor)
        love.graphics.print("Turbulence: " .. string.format("%.3f", params.turbulence), x + 15, infoY)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("(Spatial Stability)", x + 120, infoY)
        infoY = infoY + lineHeight
        
        -- Anomalías Gravitatorias
        local weirdColor = math.abs(params.weirdness) > 0.5 and {1, 0.5, 1, 1} or {0.8, 0.8, 0.8, 1}
        love.graphics.setColor(weirdColor)
        love.graphics.print("Weirdness: " .. string.format("%.3f", params.weirdness), x + 15, infoY)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("(Gravitational Anomalies)", x + 120, infoY)
        infoY = infoY + lineHeight + 5
        
        -- Altura Falsa (destacada)
        love.graphics.setColor(1, 1, 0.5, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("FALSE HEIGHT", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        local depthColor = {0.5 + params.depth * 0.5, 1, 0.5 + params.depth * 0.5, 1}
        love.graphics.setColor(depthColor)
        love.graphics.setFont(hudState.font)
        love.graphics.print(string.format("%.3f", params.depth), x + 15, infoY)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        love.graphics.print("(Invisible Z-coordinate for 3D generation)", x + 70, infoY + 3)
        infoY = infoY + lineHeight + 10
        
        -- Barra visual de altura falsa
        local barWidth = panelWidth - 40
        local barHeight = 8
        local barX = x + 20
        local barY = infoY
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        love.graphics.setColor(depthColor)
        love.graphics.rectangle("fill", barX, barY, barWidth * params.depth, barHeight)
        
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
        
        infoY = infoY + barHeight + 15
        
        -- Información técnica
        love.graphics.setColor(0.6, 0.8, 1, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("TECHNICAL INFO", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        love.graphics.print("• 6-parameter 3D biome generation", x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("• False height creates vertical variation", x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("• Player doesn't perceive Z-dimension", x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("• Improved biome coherence and distribution", x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("• World limits: ±" .. WORLD_LIMIT .. " units", x + 15, infoY)
    else
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("3D Parameters not available", x + 10, infoY)
    end
end

-- Panel de límites del mundo
function HUD.drawWorldLimitsPanel()
    if not player then return end
    
    local panelWidth = 350  
    local panelHeight = 200
    local x = 10
    local y = love.graphics.getHeight() - panelHeight - 10
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde (color según proximidad a límites)
    local borderColor = {0.5, 0.7, 0.9, 1}
    if biomeCache.worldLimitInfo then
        if not biomeCache.worldLimitInfo.withinLimits then
            borderColor = {1, 0.2, 0.2, 1}  -- Rojo si fuera de límites
        elseif biomeCache.worldLimitInfo.isNearLimit then
            borderColor = {1, 0.8, 0.2, 1}  -- Amarillo si cerca
        else
            borderColor = {0.2, 1, 0.2, 1}  -- Verde si seguro
        end
    end
    
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("WORLD BOUNDARIES", x + 10, y + 8)
    
    local infoY = y + 30
    local lineHeight = 12
    
    -- Información de límites
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print("WORLD SIZE", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("Total: " .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " units", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Range: ±" .. WORLD_LIMIT .. " units in both axes", x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
    -- Estado actual
    love.graphics.setColor(0.8, 1, 0.8, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print("CURRENT STATUS", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    if biomeCache.worldLimitInfo then
        local info = biomeCache.worldLimitInfo
        
        -- Posición actual
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(hudState.tinyFont)
        love.graphics.print("Position: (" .. math.floor(info.currentPosition.x) .. ", " .. 
                          math.floor(info.currentPosition.y) .. ")", x + 15, infoY)
        infoY = infoY + lineHeight
        
        -- Estado
        local statusColor = info.withinLimits and {0.2, 1, 0.2, 1} or {1, 0.2, 0.2, 1}
        love.graphics.setColor(statusColor)
        local statusText = info.withinLimits and "WITHIN LIMITS" or "OUTSIDE LIMITS"
        love.graphics.print("Status: " .. statusText, x + 15, infoY)
        infoY = infoY + lineHeight
        
        -- Distancia al límite
        local distanceColor = {1, 1, 1, 1}
        if info.distanceToLimit < 1000 then
            distanceColor = {1, 0.2, 0.2, 1}  -- Rojo si muy cerca
        elseif info.distanceToLimit < 5000 then
            distanceColor = {1, 0.8, 0.2, 1}  -- Amarillo si cerca
        else
            distanceColor = {0.2, 1, 0.2, 1}  -- Verde si lejos
        end
        
        love.graphics.setColor(distanceColor)
        love.graphics.print("Distance to limit: " .. math.floor(info.distanceToLimit) .. " units", x + 15, infoY)
        infoY = infoY + lineHeight + 5
        
        -- Advertencias
        if #info.warnings > 0 then
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.setFont(hudState.smallFont)
            love.graphics.print("WARNINGS", x + 10, infoY)
            infoY = infoY + lineHeight + 3
            
            love.graphics.setColor(1, 1, 0.5, 1)
            love.graphics.setFont(hudState.tinyFont)
            
            for _, warning in ipairs(info.warnings) do
                local warningText = warning
                if warning == "OUTSIDE_WORLD_LIMITS" then
                    warningText = "• Outside world boundaries!"
                elseif warning == "NEAR_WORLD_BOUNDARY" then
                    warningText = "• Approaching world boundary"
                elseif warning == "VERY_NEAR_BOUNDARY" then
                    warningText = "• Very close to boundary"
                elseif warning == "CRITICAL_BOUNDARY_PROXIMITY" then
                    warningText = "• CRITICAL: At boundary edge!"
                end
                
                love.graphics.print(warningText, x + 15, infoY)
                infoY = infoY + lineHeight
            end
        else
            love.graphics.setColor(0.2, 1, 0.2, 1)
            love.graphics.setFont(hudState.tinyFont)
            love.graphics.print("✓ Safe distance from boundaries", x + 15, infoY)
        end
        
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        love.graphics.print("Limit information loading...", x + 15, infoY)
    end
end

-- Panel de información de biomas en tiempo real
function HUD.drawBiomeInfoPanel()
    if not player or not BiomeSystem then return end
    
    -- Cache nearby biomes to avoid recalculating every frame
    if not HUD.lastBiomeScan or love.timer.getTime() - HUD.lastBiomeScan > 1.0 then
        HUD.nearbyBiomes = BiomeSystem.findNearbyBiomes(player.x, player.y, 10000)
        HUD.lastBiomeScan = love.timer.getTime()
    end
    
    local panelWidth = 320  -- Aumentado para info 3D
    local panelHeight = 250  -- Aumentado para más información
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = 10
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0.2, 0.6, 0.8, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título con información 3D
    love.graphics.setColor(0.6, 0.9, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("3D BIOME SCANNER", x + 10, y + 8)
    
    -- Información del sistema 3D
    love.graphics.setColor(0.7, 0.8, 1, 0.8)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("6-Parameter 3D System | 10km Radius", x + 10, y + 25)
    
    -- Línea separadora
    love.graphics.setColor(0.2, 0.6, 0.8, 0.8)
    love.graphics.line(x + 10, y + 40, x + panelWidth - 10, y + 40)
    
    -- Obtener información actual del bioma
    local success, biomeInfo = pcall(function()
        if BiomeSystem.getPlayerBiomeInfo then
            return BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
        end
        return nil
    end)
    
    if success and biomeInfo then
        local infoY = y + 45
        local lineHeight = 12
        
        -- Nombre del bioma actual
        local biomeColor = biomeInfo.config.color or {0.5, 0.5, 0.5, 1}
        love.graphics.setColor(biomeColor[1] + 0.3, biomeColor[2] + 0.3, biomeColor[3] + 0.3, 1)
        love.graphics.setFont(hudState.font)
        love.graphics.print("▶ " .. (biomeInfo.name or "Unknown"), x + 10, infoY)
        infoY = infoY + lineHeight + 2
        
        -- Rareza del bioma
        local rarityColors = {
            ["Very Common"] = {0.7, 0.7, 0.7, 1},
            ["Common"] = {0.8, 0.8, 0.8, 1},
            ["Uncommon"] = {0.6, 0.9, 0.6, 1},
            ["Rare"] = {0.6, 0.6, 1, 1},
            ["Very Rare"] = {0.9, 0.6, 1, 1},
            ["Legendary"] = {1, 0.8, 0.2, 1}
        }
        
        local rarityColor = rarityColors[biomeInfo.rarity] or {1, 1, 1, 1}
        love.graphics.setColor(rarityColor)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("Rarity: " .. (biomeInfo.rarity or "Unknown"), x + 15, infoY)
        infoY = infoY + lineHeight + 3
        
        -- Parámetros 3D resumidos
        if biomeInfo.parameters then
            love.graphics.setColor(0.8, 1, 1, 1)
            love.graphics.setFont(hudState.smallFont)
            love.graphics.print("3D PARAMETERS", x + 10, infoY)
            infoY = infoY + lineHeight + 2
            
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(hudState.tinyFont)
            
            local params = biomeInfo.parameters
            love.graphics.print("Energy: " .. string.format("%.2f", params.energy) .. 
                              " | Density: " .. string.format("%.2f", params.density), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Turbulence: " .. string.format("%.2f", params.turbulence) .. 
                              " | Weird: " .. string.format("%.2f", params.weirdness), x + 15, infoY)
            infoY = infoY + 10
            
            -- Altura falsa destacada
            love.graphics.setColor(1, 1, 0.5, 1)
            love.graphics.print("False Height: " .. string.format("%.3f", params.depth), x + 15, infoY)
            infoY = infoY + 12
        end
        
        -- Coordenadas
        love.graphics.setColor(0.9, 1, 0.9, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("LOCATION", x + 10, infoY)
        infoY = infoY + lineHeight + 2
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        if biomeInfo.coordinates and biomeInfo.coordinates.chunk then
            love.graphics.print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. 
                              biomeInfo.coordinates.chunk.y .. ")", x + 15, infoY)
            infoY = infoY + 10
        end
        
        -- Información de límites del mundo
        if biomeCache.worldLimitInfo then
            local limitColor = biomeCache.worldLimitInfo.withinLimits and {0.2, 1, 0.2, 1} or {1, 0.2, 0.2, 1}
            love.graphics.setColor(limitColor)
            local limitText = biomeCache.worldLimitInfo.withinLimits and "Within World" or "At Boundary"
            love.graphics.print("Status: " .. limitText, x + 15, infoY)
            infoY = infoY + 12
        end
        
        -- Lista de biomas cercanos (compacta)
        love.graphics.setColor(0.6, 0.9, 1, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("NEARBY BIOMES:", x + 10, infoY)
        infoY = infoY + lineHeight + 2
        
        love.graphics.setFont(hudState.tinyFont)
        
        local maxItems = 4  -- Reducido para hacer espacio
        for i = 1, math.min(#HUD.nearbyBiomes, maxItems) do
            local biome = HUD.nearbyBiomes[i]
            local distance = math.floor(biome.distance / 100) * 100
            local color = {0.8, 0.9, 1, 1}
            
            -- Fade por distancia
            if distance > 8000 then
                color[4] = 0.5
            end
            
            love.graphics.setColor(color)
            love.graphics.print(string.format("%s (%d m)", biome.name:sub(1, 12), distance), 
                              x + 15, infoY)
            infoY = infoY + 10
        end
        
    else
        -- Error fallback
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("3D Biome scanner offline", x + 10, y + 50)
    end
end

-- Panel de información principal   
function HUD.drawUnifiedInfoPanel()
    local panelWidth = 380  -- Aumentado para nueva información
    local panelHeight = 580  -- Aumentado para más contenido
    local x = 10
    local y = 10
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0.3, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título del panel
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("ENHANCED SPACE EXPLORER 3D", x + 10, y + 8)
    
    -- Línea separadora
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    -- Información del jugador
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    
    local posX = math.floor(player.x or 0)
    local posY = math.floor(player.y or 0)
    local speed = math.sqrt((player.dx or 0)^2 + (player.dy or 0)^2)
    
    local chunkX, chunkY = HUD.getSafeChunkCoords(posX, posY)
    local stats = HUD.getSafeStats()
    
    local infoY = y + 35
    local lineHeight = 12
    
    -- Información de semilla alfanumérica
    love.graphics.setColor(1, 1, 0.6, 1)
    love.graphics.print("GALAXY SEED", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Current: " .. (stats.seed or "UNKNOWN00"), x + 15, infoY)
    infoY = infoY + lineHeight
    
    local seedStatus = SeedSystem.validate(stats.seed) and "Valid" or "Legacy"
    local seedColor = SeedSystem.validate(stats.seed) and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    love.graphics.setColor(seedColor)
    love.graphics.print("Status: " .. seedStatus, x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
    -- Información de límites del mundo
    love.graphics.setColor(1, 0.8, 0.8, 1)
    love.graphics.print("WORLD BOUNDARIES", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    local limitColor = stats.worldLimits.withinLimits and {0.6, 1, 0.6, 1} or {1, 0.6, 0.6, 1}
    love.graphics.setColor(limitColor)
    local limitStatus = stats.worldLimits.withinLimits and "Within Limits" or "At Boundary"
    love.graphics.print("Status: " .. limitStatus, x + 15, infoY)
    infoY = infoY + lineHeight
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Size: " .. stats.worldLimits.totalSize .. " x " .. stats.worldLimits.totalSize .. " units", x + 15, infoY)
    infoY = infoY + lineHeight
    
    if stats.worldLimits.distanceToLimit > 0 then
        local distColor = stats.worldLimits.nearLimit and {1, 0.8, 0.4, 1} or {0.8, 0.8, 0.8, 1}
        love.graphics.setColor(distColor)
        love.graphics.print("Distance to limit: " .. math.floor(stats.worldLimits.distanceToLimit), x + 15, infoY)
        infoY = infoY + lineHeight
    end
    infoY = infoY + 5
    
    -- Información del jugador
    love.graphics.setColor(0.9, 0.9, 1, 1)
    love.graphics.print("PLAYER STATUS", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Position: (" .. posX .. ", " .. posY .. ")", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Speed: " .. math.floor(speed) .. " u/s", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Chunk: (" .. chunkX .. ", " .. chunkY .. ")", x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
    -- Información de parámetros 3D actuales
    if stats.biome3D.hasParameters and stats.biome3D.parameters then
        love.graphics.setColor(0.8, 1, 1, 1)
        love.graphics.print("3D BIOME PARAMETERS", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local params = stats.biome3D.parameters
        love.graphics.print("False Height: " .. string.format("%.3f", params.depth), x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("Energy: " .. string.format("%.2f", params.energy) .. 
                          " | Density: " .. string.format("%.2f", params.density), x + 15, infoY)
        infoY = infoY + lineHeight
        love.graphics.print("Turbulence: " .. string.format("%.2f", params.turbulence) .. 
                          " | Anomalies: " .. string.format("%.2f", params.weirdness), x + 15, infoY)
        infoY = infoY + lineHeight + 5
    end
    
    -- Estadísticas de biomas (simplificado)  
    if BiomeSystem then
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.print("BIOME EXPLORATION", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        local success, biomeStats = pcall(function()
            if BiomeSystem.getAdvancedStats then
                return BiomeSystem.getAdvancedStats()
            end
            return nil
        end)
        
        if success and biomeStats and biomeStats.playerStats then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print("Biome Changes: " .. (biomeStats.playerStats.biomeChanges or 0), x + 15, infoY)
            infoY = infoY + lineHeight
            love.graphics.print("System: " .. (biomeStats.system or "3D_6_PARAMETER"), x + 15, infoY)
            infoY = infoY + lineHeight
            
            if biomeStats.playerStats.currentBiome and BiomeSystem.getBiomeConfig then
                local configSuccess, currentConfig = pcall(function()
                    return BiomeSystem.getBiomeConfig(biomeStats.playerStats.currentBiome)
                end)
                if configSuccess and currentConfig then
                    love.graphics.print("Current: " .. currentConfig.name, x + 15, infoY)
                else
                    love.graphics.print("Current: Unknown Biome", x + 15, infoY)
                end
            else
                love.graphics.print("Current: Scanning...", x + 15, infoY)
            end
            infoY = infoY + lineHeight + 5
        else
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print("3D Biome data loading...", x + 15, infoY)
            infoY = infoY + lineHeight + 5
        end
    end
    
    -- Información del sistema
    love.graphics.setColor(0.9, 1, 0.9, 1)
    love.graphics.print("SYSTEM INFO", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("FPS: " .. stats.fps, x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Zoom: " .. string.format("%.1f", _G.camera and _G.camera.zoom or 1), x + 15, infoY)
    infoY = infoY + lineHeight
    
    local chunkInfo = "N/A"
    if stats.chunks and stats.chunks.active and stats.chunks.cached then
        chunkInfo = stats.chunks.active .. "/" .. stats.chunks.cached
    elseif stats.loadedChunks then
        chunkInfo = tostring(stats.loadedChunks)
    end
    love.graphics.print("Chunks: " .. chunkInfo, x + 15, infoY)
    infoY = infoY + lineHeight
    
    if _G.showGrid then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("Grid: ON", x + 15, infoY)
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Grid: OFF", x + 15, infoY)
    end
    infoY = infoY + lineHeight
    
    -- Estadísticas de renderizado (compacto)
    local renderStats = stats.rendering or stats.renderStats
    if renderStats and renderStats.totalObjects and renderStats.totalObjects > 0 then
        local efficiency = 0
        if renderStats.culledObjects and renderStats.totalObjects > 0 then
            efficiency = (renderStats.culledObjects / renderStats.totalObjects * 100)
        end
        
        love.graphics.print("Objects: " .. (renderStats.renderedObjects or 0) .. "/" .. renderStats.totalObjects, x + 15, infoY)
        infoY = infoY + lineHeight
        
        if efficiency > 0 then
            love.graphics.print("Culling: " .. string.format("%.1f%%", efficiency), x + 15, infoY)
            infoY = infoY + lineHeight
        end
    end
    
    -- Información de sistemas mejorados (compacto)
    if stats.chunks or stats.coordinates then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("ENHANCED SYSTEMS", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        
        if stats.chunks and stats.chunks.pooled then
            love.graphics.print("Pool: " .. stats.chunks.pooled .. " available", x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        if stats.coordinates and stats.coordinates.relocations then
            love.graphics.print("Coord Relocations: " .. stats.coordinates.relocations, x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        infoY = infoY + 5
    end
    
    -- DEBUG MODE 
    if player and player.stats and player.stats.debug and player.stats.debug.enabled then
        infoY = infoY + 5
        love.graphics.setColor(1, 1, 0.4, 1)
        love.graphics.print("DEBUG MODE", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local invulnStatus = player.stats.debug.invulnerable and "ON" or "OFF"
        love.graphics.print("Invulnerability: " .. invulnStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        
        local fuelStatus = player.stats.debug.infiniteFuel and "ON" or "OFF"
        love.graphics.print("Infinite Fuel: " .. fuelStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        
        local regenStatus = player.stats.debug.fastRegen and "ON" or "OFF"
        love.graphics.print("Fast Regen: " .. regenStatus, x + 15, infoY)
        infoY = infoY + lineHeight + 10
    end
    
    -- Controles básicos (actualizado)
    love.graphics.setColor(1, 1, 0.8, 1)
    love.graphics.print("CONTROLS", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("WASD + Mouse: Move & Aim", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Shift: Brake | Wheel: Zoom", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("F1: Info | F2: Seed | F12: Biomes", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("F16: 3D Debug | F17: World Limits", x + 15, infoY)  -- NUEVO
end

-- Input de semilla alfanumérica
function HUD.drawSeedInput()
    local panelWidth = 500
    local panelHeight = 400
    local x = (love.graphics.getWidth() - panelWidth) / 2
    local y = (love.graphics.getHeight() - panelHeight) / 2
    
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0.5, 0.7, 0.9, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.font)
    
    love.graphics.print("NEW ENHANCED GALAXY SEED", x + 20, y + 20)
    
    love.graphics.setFont(hudState.smallFont)
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.print("Alphanumeric Seeds: 5 letters + 5 digits mixed (e.g., A5B9C2D7E1)", x + 20, y + 45)
    love.graphics.print("36^10 = 3.6 trillion possible galaxies with 3D biome generation!", x + 20, y + 60)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Quick Select (Arrow Keys + Enter):", x + 20, y + 85)
    
    for i, preset in ipairs(presetSeeds) do
        local color = (i == currentPresetIndex) and {1, 1, 0.3, 1} or {0.8, 0.8, 0.8, 1}
        local prefix = (i == currentPresetIndex) and "> " or "  "
        
        love.graphics.setColor(color)
        love.graphics.print(prefix .. preset.name .. " (" .. preset.seed .. ")", x + 30, y + 100 + i * 15)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Custom Seed (10 characters: 5 letters + 5 digits):", x + 20, y + 280)
    
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x + 20, y + 300, 460, 25)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", x + 20, y + 300, 460, 25)
    
    love.graphics.setColor(1, 1, 1, 1)
    local displayText = hudState.seedInputText:upper()
    love.graphics.print(displayText, x + 25, y + 305)
    
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = hudState.font:getWidth(displayText)
        love.graphics.line(x + 25 + textWidth, y + 305, x + 25 + textWidth, y + 320)
    end
    
    local isValid = SeedSystem.validate(displayText)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.6, 0.6, 1}
    local validText = isValid and "✓ Valid Format" or "✗ Need 5 letters + 5 digits"
    love.graphics.setColor(validColor)
    love.graphics.print(validText, x + 25, y + 330)
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(#displayText .. "/10 characters", x + 300, y + 330)
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Letters A-Z and digits 0-9 only • Enter to confirm • Escape to cancel", x + 20, y + 355)
    
    love.graphics.setColor(0.6, 0.8, 1, 1)
    love.graphics.print("Examples: A5B2C9D1E7, X3Y8Z2K6M4, F9R1T5G3H8", x + 20, y + 375)
end

-- Información de la semilla actual
function HUD.drawCurrentSeedInfo()
    if not gameState then return end
    
    local currentSeed = gameState.currentSeed or "UNKNOWN00"
    local text = "Seed: " .. currentSeed
    local textWidth = hudState.smallFont:getWidth(text)
    local x = love.graphics.getWidth() - textWidth - 15
    local y = love.graphics.getHeight() - 65  -- Ajustado para hacer espacio a límites
    
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 3, textWidth + 16, 62)  -- Más alto
    
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.rectangle("line", x - 8, y - 3, textWidth + 16, 62)
    
    love.graphics.setColor(0.7, 1, 0.7, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print(text, x, y)
    
    local isValid = SeedSystem.validate(currentSeed)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    local validText = isValid and "3D Alpha" or "Legacy"
    love.graphics.setColor(validColor)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("Type: " .. validText, x, y + 15)
    
    -- Información adicional sobre el sistema 3D
    love.graphics.setColor(0.8, 0.9, 1, 1)
    love.graphics.print("6-Param 3D System", x, y + 27)
    love.graphics.print("World: ±" .. WORLD_LIMIT, x, y + 39)
end

-- HUD del jugador
function HUD.drawPlayerHUD()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local hudY = screenHeight - 80
    local heartStartX = 20
    local barWidth = 200
    local barHeight = 12
    
    local r, g, b, a = love.graphics.getColor()
    
    HUD.drawHearts(heartStartX, hudY - 30)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print("SHIELD", heartStartX, hudY)
    HUD.drawBar(heartStartX + 60, hudY + 2, barWidth, barHeight, 
                 player.stats:getShieldPercentage(), {0.2, 0.6, 1, 1}, {0.1, 0.3, 0.5, 0.8})
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FUEL", heartStartX, hudY + 20)
    HUD.drawBar(heartStartX + 60, hudY + 22, barWidth, barHeight, 
                 player.stats:getFuelPercentage(), {1, 0.8, 0.2, 1}, {0.5, 0.4, 0.1, 0.8})
    
    love.graphics.setColor(r, g, b, a)
end
 -- HUD de las stats del jugdaor
function HUD.drawHearts(x, y)
    local heartSize = 16
    local heartSpacing = 20
    
    for i = 1, player.stats.health.maxHearts do
        local heartX = x + (i - 1) * heartSpacing
        
        if i <= player.stats.health.currentHearts then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, true)
        elseif i == player.stats.health.currentHearts + 1 and player.stats.health.heartHalves > 0 then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, false)
        else
            love.graphics.setColor(0.3, 0.1, 0.1, 1)
            HUD.drawHeartOutline(heartX, y, heartSize)
        end
    end
end

function HUD.drawHeart(x, y, size, full)
    local halfSize = size / 2
    
    if full then
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.circle("fill", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + size, y + halfSize
        )
    else
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + halfSize, y + halfSize
        )
        
        love.graphics.setColor(0.3, 0.1, 0.1, 1)
        love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("line", 
            x + halfSize, y + halfSize,
            x + size, y + halfSize,
            x + halfSize, y + size
        )
    end
end

function HUD.drawHeartOutline(x, y, size)
    local halfSize = size / 2
    
    love.graphics.circle("line", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.polygon("line", 
        x, y + halfSize,
        x + halfSize, y + size,
        x + size, y + halfSize
    )
end

function HUD.drawBar(x, y, width, height, percentage, color, backgroundColor)
    love.graphics.setColor(backgroundColor)
    love.graphics.rectangle("fill", x, y, width, height)
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    if percentage > 0 then
        love.graphics.setColor(color)
        local fillWidth = (width - 2) * (percentage / 100)
        love.graphics.rectangle("fill", x + 1, y + 1, fillWidth, height - 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    local text = string.format("%.0f%%", percentage)
    local textWidth = hudState.smallFont:getWidth(text)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print(text, x + width/2 - textWidth/2, y - 1)
end

-- Manejo de entrada para el HUD 
function HUD.handleSeedInput(key)
    if key == "escape" then
        hudState.showSeedInput = false
        hudState.seedInputText = ""
    elseif key == "return" or key == "enter" then
        if hudState.seedInputText ~= "" then
            local normalizedSeed = SeedSystem.normalize(hudState.seedInputText)
            if SeedSystem.validate(normalizedSeed) then
                return normalizedSeed, "custom"
            else
                return normalizedSeed, "normalized"
            end
        else
            local selectedPreset = presetSeeds[currentPresetIndex]
            local selectedSeed = selectedPreset.seed
            
            if selectedPreset.name == "Random" then
                selectedSeed = SeedSystem.generate()
                selectedPreset.seed = selectedSeed
            end
            
            return selectedSeed, "preset"
        end
        hudState.showSeedInput = false
        hudState.seedInputText = ""
    elseif key == "backspace" then
        hudState.seedInputText = string.sub(hudState.seedInputText, 1, -2)
    elseif key == "up" then
        currentPresetIndex = math.max(1, currentPresetIndex - 1)
    elseif key == "down" then
        currentPresetIndex = math.min(#presetSeeds, currentPresetIndex + 1)
    end
    return nil, nil
end

function HUD.textinput(text)
    if hudState.showSeedInput then
        local upperText = text:upper()
        if upperText:match("[A-Z0-9]") and #hudState.seedInputText < 10 then
            hudState.seedInputText = hudState.seedInputText .. upperText
        end
    end
end

-- Funciones de control del HUD 
function HUD.toggleInfo()
    hudState.showInfo = not hudState.showInfo
end

function HUD.toggleBiomeInfo()
    hudState.showBiomeInfo = not hudState.showBiomeInfo
    local status = hudState.showBiomeInfo and "ON" or "OFF"
    print("3D Biome info panel: " .. status)
end

-- Toggle para debug 3D
function HUD.toggle3DDebug()
    hudState.show3DDebug = not hudState.show3DDebug
    local status = hudState.show3DDebug and "ON" or "OFF"
    print("3D Debug panel: " .. status)
end

-- Toggle para límites del mundo
function HUD.toggleWorldLimits()
    hudState.showWorldLimits = not hudState.showWorldLimits
    local status = hudState.showWorldLimits and "ON" or "OFF"
    print("World limits panel: " .. status)
end

function HUD.showSeedInput()
    hudState.showSeedInput = true
    hudState.seedInputText = ""
    presetSeeds[1].seed = SeedSystem.generate()
end

function HUD.hideSeedInput()
    hudState.showSeedInput = false
    hudState.seedInputText = ""
end

function HUD.isSeedInputVisible()
    return hudState.showSeedInput
end

function HUD.isInfoVisible()
    return hudState.showInfo
end

function HUD.isBiomeInfoVisible()
    return hudState.showBiomeInfo
end

-- Getters para nuevos paneles
function HUD.is3DDebugVisible()
    return hudState.show3DDebug
end

function HUD.isWorldLimitsVisible()
    return hudState.showWorldLimits
end

function HUD.updateReferences(gameStateRef, playerRef, mapRef)
    gameState = gameStateRef
    player = playerRef
    Map = mapRef
    
    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)
    
    if success then
        BiomeSystem = biomeSystemModule
    end
    
    -- Recargar sistema de coordenadas
    local coordSuccess, coordSystemModule = pcall(function()
        return require 'src.maps.coordinate_system'
    end)
    
    if coordSuccess then
        CoordinateSystem = coordSystemModule
    end
    
    biomeCache = {
        lastUpdate = 0,
        updateInterval = 0.5,
        currentBiome = nil,
        biomeHistory = {},
        maxHistory = 10,
        current3DParams = nil,
        worldLimitInfo = nil
    }
end

function HUD.getBiomeHistory()
    return biomeCache.biomeHistory
end

function HUD.getSeedSystem()
    return SeedSystem
end

return HUD