-- main.lua (SISTEMA CON FALSA ALTURA Y LÍMITES DEL MUNDO)

local Camera = require 'src.utils.camera'
local Map = require 'src.maps.map'
local Player = require 'src.entities.player'
local HUD = require 'src.ui.hud'
local BiomeSystem = require 'src.maps.biome_system'
local CoordinateSystem = require 'src.maps.coordinate_system'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local SeedSystem = require 'src.utils.seed_system'

-- LÍMITES DEL MUNDO
local WORLD_LIMIT = 200000  -- ±200,000 unidades en ambos ejes

-- Estado del juego con semilla alfanumérica y límites del mundo
local gameState = {
    currentSeed = SeedSystem.generate(),
    paused = false,
    worldLimits = {
        enabled = true,
        maxDistance = WORLD_LIMIT,
        totalSize = WORLD_LIMIT * 2,
        enforced = true
    }
}

-- Sistema de iluminación
local lighting = {
    playerLight = {
        x = 0,
        y = 0,
        radius = 35 * Map.worldScale,
        color = {0.7, 0.9, 1.0, 0.4}
    },
    ambientColor = {0.05, 0.05, 0.15, 1},
    enabled = true
}

-- Variables globales
_G.camera = nil
_G.showGrid = false
local player

-- Sistema de debug para biomas 3D y sistemas avanzados
local biomeDebug = {
    enabled = false,
    showRegions = false,
    showInfluences = false,
    show3DParameters = false,  -- Debug parámetros 3D
    showWorldLimits = false,   -- Debug límites del mundo
    showFalseHeight = false,   -- Visualización altura falsa
    lastDebugUpdate = 0,
    testDistribution = false,
    showSystemStats = false,
    showPerformanceOverlay = false
}

-- Sistema de estadísticas
local advancedStats = {
    enabled = false,
    updateInterval = 1.0,
    lastUpdate = 0,
    frameTimeHistory = {},
    maxHistorySize = 60,
    worldLimitStats = {
        violations = 0,
        relocations = 0,
        nearLimitTime = 0
    }
}

-- Sistema de alertas para límites del mundo
local worldLimitAlerts = {
    enabled = true,
    lastAlert = 0,
    alertCooldown = 5.0,  -- 5 segundos entre alertas
    criticalDistance = 1000,  -- Distancia crítica para alertas
    warningDistance = 5000    -- Distancia de advertencia
}

function love.load()
    -- Configuración inicial
    love.window.setTitle("Space Roguelike - 3D Enhanced Systems - Seed: " .. gameState.currentSeed)
    love.window.setMode(1200, 800, {resizable = true})
    
    -- Inicializar semilla aleatoria real
    math.randomseed(os.time())
    gameState.currentSeed = SeedSystem.generate()
    
    -- Inicializar cámara con manejo de errores
    local success, cam = pcall(function() return Camera:new() end)
    if not success or not cam then
        error("Failed to initialize camera: " .. tostring(cam))
    end
    _G.camera = cam
    _G.camera:updateScreenDimensions()
    
    -- Crear jugador en el centro con verificación de límites
    local playerX, playerY = 0, 0
    
    -- Verificar que la posición inicial está dentro de los límites
    if math.abs(playerX) > WORLD_LIMIT or math.abs(playerY) > WORLD_LIMIT then
        playerX, playerY = 0, 0  -- Forzar al centro si hay problema
        print("Player position reset to world center due to limit violation")
    end
    
    player = Player:new(playerX, playerY)
    
    -- Inicializar sistema de coordenadas CON LÍMITES DEL MUNDO
    local coordSuccess = pcall(function() 
        CoordinateSystem.init(playerX, playerY) 
    end)
    if not coordSuccess then
        print("Warning: CoordinateSystem initialization failed")
    else
        print("✓ CoordinateSystem initialized with world limits")
    end
    
    -- Inicializar sistema de mapas 3D con semilla alfanumérica
    local mapSuccess = pcall(function() 
        Map.init(gameState.currentSeed) 
    end)
    if not mapSuccess then
        print("Warning: Enhanced 3D Map initialization had issues")
    else
        print("✓ 3D Map System initialized successfully")
    end
    
    -- Inicializar gestor de chunks CON LÍMITES DEL MUNDO
    local chunkSuccess = pcall(function()
        ChunkManager.init(SeedSystem.toNumeric(gameState.currentSeed))
    end)
    if not chunkSuccess then
        print("Warning: ChunkManager initialization failed")
    else
        print("✓ ChunkManager initialized with world limits")
    end
    
    -- Inicializar renderizador optimizado
    local rendererSuccess = pcall(function()
        OptimizedRenderer.init()
    end)
    if not rendererSuccess then
        print("Warning: OptimizedRenderer initialization failed")
    else
        print("✓ OptimizedRenderer initialized")
    end
    
    -- Inicializar HUD
    HUD.init(gameState, player, Map)
    
    -- Configurar iluminación inicial
    if lighting then
        lighting.playerLight.x = playerX
        lighting.playerLight.y = playerY
    end
    
    print("")
    print("=== 3D SPACE ROGUELIKE ENHANCED LOADED ===")
    print("Alphanumeric Seed: " .. gameState.currentSeed)
    print("Numeric Seed: " .. SeedSystem.toNumeric(gameState.currentSeed))
    print("World Limits: ±" .. WORLD_LIMIT .. " units (" .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " total)")
    
    print("")
    print("=== 3D ENHANCED SYSTEMS ACTIVE ===")
    print("✓ 6-Parameter 3D Biome System: Energy, Density, Continentalness, Turbulence, Weirdness, False Height")
    print("✓ False Height Dimension: Invisible Z-coordinate for natural 3D generation")
    print("✓ World Boundaries: Enforced " .. (WORLD_LIMIT * 2) .. "x" .. (WORLD_LIMIT * 2) .. " unit world")
    print("✓ Alphanumeric Seed System: 36^10 possibilities (3.6 trillion galaxies)")
    print("✓ Coordinate System: Relative coordinates with world limit enforcement")
    print("✓ Chunk Manager: Dynamic loading with world boundary awareness")
    print("✓ Optimized Renderer: LOD, frustum culling, adaptive quality")
    print("✓ Enhanced Performance: Batch rendering and memory optimization")
    
    print("")
    print("=== 3D BIOME FEATURES ===")
    print("• Deep Space acts as spatial ocean separating other biomes")
    print("• 6 dimensional parameter space creates natural biome distribution")
    print("• False height adds vertical variation without 3D perception")
    print("• Coherent biome regions with smooth 3D transitions")
    print("• Rare biomes require precise 6-parameter alignment")
    print("• Enhanced spatial coherence mimics Minecraft's natural feel")
    print("• World boundaries prevent infinite expansion beyond " .. WORLD_LIMIT .. " units")
    
    -- Información sobre estrellas
    if Map.starConfig then
        print("")
        print("=== ENHANCED STARS SYSTEM ===")
        print("Max stars per frame: " .. Map.starConfig.maxStarsPerFrame)
        print("Enhanced effects: " .. (Map.starConfig.enhancedEffects and "ON" or "OFF"))
        print("Parallax strength: " .. Map.starConfig.parallaxStrength)
        print("Star types: 6 unique types with multi-layer parallax and 3D positioning")
        print("Effects: Optimized rendering with LOD scaling and false height influence")
    end
    
    print("")
    print("=== ENHANCED CONTROLS ===")
    print("F1: System Info / Performance & Memory Stats | F2: Seed Input (Alphanumeric) | F3: Debug Mode")
        print("F4: Enhanced Grid | F5: Lighting | F6: Test Damage")
        print("F7: Star Effects | F8: Star Quality | F9: Invulnerability")
        print("F10: Infinite Fuel | F11: Fast Regen | F12: Biome Scanner / 3D Debug Panels")
    print("` (Grave): Advanced Debug | T: Test 3D Distribution")
    print("R: New Galaxy | P: Pause | H: Heal | U: Add Fuel")
    print("")
    print("=== 3D BIOME SYSTEM CONTROLS ===")
    print("• F12: Toggle 3D debug panels (Biome, LOD, Parameters, World Limits)") 
    print("• Ctrl+T: Test 3D biome distribution with false height")
    print("• Ctrl+L: Test world limit boundary behavior")
    print("• Ctrl+H: Toggle false height visualization")
    print("")
    print("=== ALPHANUMERIC SEED SYSTEM ===")
    print("• Seeds are 10 characters: 5 letters + 5 digits mixed")
    print("• Example: A5B9C2D7E1, F3K8M1N6P4, X7Y2Z9W4Q8")
    print("• 36^10 = 3,656,158,440,062,976 possible 3D worlds")
    print("• Each seed generates unique 6-parameter 3D space")
    print("• Natural distribution ensures consistent biome generation")
    print("• Type custom seeds in F2 input or use preset 3D-optimized options")
    print("")
    print("=== WORLD BOUNDARIES SYSTEM ===")
    print("• World size limited to " .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " units")
    print("• Automatic boundary enforcement prevents out-of-bounds exploration")
    print("• Proximity warnings when approaching world edges")
    print("• Object density reduction near boundaries for natural feel")
    print("• F17 shows detailed boundary status and distance information")
end

function love.update(dt)
    -- Pausar el juego si es necesario
    if gameState.paused then return end
    
    -- Limitar delta time para evitar saltos grandes
    dt = math.min(dt or 1/60, 1/30)
    
    -- Actualizar estadísticas avanzadas
    updateAdvancedStats(dt)
    
    -- NUEVO: Verificar y aplicar límites del mundo al jugador
    if player and gameState.worldLimits.enforced then
        local originalX, originalY = player.x, player.y
        local limitedX, limitedY = enforcePlayerWorldLimits(player.x, player.y)
        
        if limitedX ~= originalX or limitedY ~= originalY then
            player.x = limitedX
            player.y = limitedY
            player.dx = math.min(player.dx, 0)  -- Detener movimiento hacia límite
            player.dy = math.min(player.dy, 0)  -- Detener movimiento hacia límite
            
            advancedStats.worldLimitStats.violations = advancedStats.worldLimitStats.violations + 1
            
            -- Mostrar alerta de límite
            showWorldLimitAlert("BOUNDARY_REACHED")
        end
        
        -- Verificar proximidad a límites para alertas
        checkWorldLimitProximity(player.x, player.y)
    end
    
    -- Actualizar HUD (incluye tracking de biomas 3D)
    if HUD and HUD.update then
        HUD.update(dt)
    end
    
    -- Actualizar jugador
    if player and type(player.update) == "function" then
        local success, err = pcall(function() player:update(dt) end)
        if not success then
            print("Error updating player:", err)
        end
    end
    
    -- Actualizar sistema de coordenadas con límites del mundo
    if player and player.x and player.y then
        local success, relocated, limitedX, limitedY = pcall(function()
            return CoordinateSystem.update(dt, player.x, player.y)
        end)
        
        if success then
            if relocated then
                advancedStats.worldLimitStats.relocations = advancedStats.worldLimitStats.relocations + 1
                print("Coordinate system relocated (within world limits) - total: " .. advancedStats.worldLimitStats.relocations)
            end
            
            -- Si el sistema de coordenadas devolvió posición limitada, aplicarla
            if limitedX and limitedY and (limitedX ~= player.x or limitedY ~= player.y) then
                player.x = limitedX
                player.y = limitedY
            end
        else
            print("Error updating coordinate system")
        end
    end
    
    -- Actualizar sistema de mapas 3D mejorado
    if player and player.x and player.y then
        Map.update(dt, player.x, player.y)
    end
    
    -- Actualizar cámara para seguir al jugador
    if _G.camera and player and type(_G.camera.follow) == "function" then
        local success, err = pcall(function() 
            _G.camera:follow(player, dt)
        end)
        if not success then
            print("Error updating camera:", err)
        end
    end
    -- Actualizar debug de biomas 3D y sistemas
    if biomeDebug.enabled and player then
        local currentTime = love.timer.getTime()
        if currentTime - biomeDebug.lastDebugUpdate >= 1.0 then  -- Cada segundo
            local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
            if biomeInfo then
                print("=== 3D ENHANCED BIOME DEBUG ===")
                print("Current Biome: " .. biomeInfo.name .. " (" .. biomeInfo.rarity .. ")")
                print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")")
                print("Target Weight: " .. string.format("%.1f%%", biomeInfo.config.spawnWeight * 100))
                
                -- NUEVO: Mostrar parámetros 3D detallados
                if biomeInfo.parameters then
                    print("=== 3D PARAMETERS ===")
                    print("Energy (Spatial Temp): " .. string.format("%.3f", biomeInfo.parameters.energy))
                    print("Density (Matter): " .. string.format("%.3f", biomeInfo.parameters.density))
                    print("Continentalness: " .. string.format("%.3f", biomeInfo.parameters.continentalness))
                    print("Turbulence: " .. string.format("%.3f", biomeInfo.parameters.turbulence))
                    print("Weirdness (Anomalies): " .. string.format("%.3f", biomeInfo.parameters.weirdness))
                    print("FALSE HEIGHT: " .. string.format("%.3f", biomeInfo.parameters.depth))
                    
                    -- Análisis de parámetros
                    local heightCategory = "Medium"
                    if biomeInfo.parameters.depth < 0.2 then
                        heightCategory = "Deep"
                    elseif biomeInfo.parameters.depth > 0.8 then
                        heightCategory = "High"
                    end
                    print("Height Category: " .. heightCategory)
                    
                    local energyLevel = biomeInfo.parameters.energy > 0.5 and "Hot" or 
                                      biomeInfo.parameters.energy < -0.5 and "Cold" or "Temperate"
                    print("Energy Level: " .. energyLevel)
                end
                
                -- Mostrar estadísticas del sistema de coordenadas
                local coordStats = CoordinateSystem.getStats()
                if coordStats then
                    print("=== COORDINATE SYSTEM ===")
                    print("Current Sector: (" .. coordStats.currentSector.x .. ", " .. coordStats.currentSector.y .. ")")
                    print("Relocations: " .. coordStats.relocations)
                    
                    -- Información de límites del mundo
                    if coordStats.worldLimits then
                        print("World Limits Active: " .. (coordStats.worldLimits.active and "YES" or "NO"))
                        print("Distance to Limit: " .. math.floor(coordStats.worldLimits.distanceToLimit))
                        print("Near Limit: " .. (coordStats.worldLimits.nearLimit and "YES" or "NO"))
                        print("Violations: " .. coordStats.worldLimits.violations)
                    end
                end
                
                -- Mostrar estadísticas de chunks
                local chunkStats = ChunkManager.getStats()
                if chunkStats then
                    print("=== CHUNK MANAGER ===")
                    print("Chunks - Active: " .. chunkStats.active .. ", Cached: " .. chunkStats.cached .. ", Pool: " .. chunkStats.pooled)
                    
                    -- Información de límites en chunks
                    if chunkStats.worldLimits then
                        print("Chunks Outside Limits: " .. chunkStats.worldLimits.chunksOutsideLimits)
                        print("Limit Enforced Chunks: " .. chunkStats.worldLimits.limitEnforcedChunks)
                    end
                end
                
                -- Mostrar estadísticas de renderizado
                if biomeDebug.showSystemStats then
                    local rendererStats = OptimizedRenderer.getStats()
                    if rendererStats then
                        print("=== RENDERER STATS ===")
                        print("FPS: " .. rendererStats.performance.fps .. 
                              ", Objects: " .. rendererStats.rendering.objectsRendered ..
                              ", Culled: " .. string.format("%.1f%%", rendererStats.rendering.cullingEfficiency))
                        print("Quality Level: " .. string.format("%.1f%%", rendererStats.quality.current * 100))
                    end
                end
                
                -- Debug específico de semillas 3D
                print("=== SEED DEBUG ===")
                print("Alpha: " .. gameState.currentSeed .. 
                      ", Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed))
                print("3D System: 6-Parameter Generation Active")
                print("False Height: Provides invisible Z-dimension variation")
            end
            biomeDebug.lastDebugUpdate = currentTime
        end
    end
    
    -- Test automático de distribución de biomas 3D
    if biomeDebug.testDistribution then
        local currentTime = love.timer.getTime()
        if currentTime - biomeDebug.lastDebugUpdate >= 15.0 then  -- Cada 15 segundos
            print("=== AUTOMATIC 3D DISTRIBUTION TEST ===")
            BiomeSystem.debugDistribution(1500)  -- Muestra más grande para 3D
            biomeDebug.lastDebugUpdate = currentTime
        end
    end
    
    -- Actualizar dimensiones de la cámara en caso de redimensionamiento
    if _G.camera then
        _G.camera:updateScreenDimensions()
    end
end

-- Aplicar límites del mundo al jugador
function enforcePlayerWorldLimits(x, y)
    local originalX, originalY = x, y
    
    -- Aplicar límites con pequeña tolerancia
    local limit = WORLD_LIMIT - 10  -- 10 unidades de buffer
    x = math.max(-limit, math.min(limit, x))
    y = math.max(-limit, math.min(limit, y))
    
    return x, y
end

-- Verificar proximidad a límites del mundo
function checkWorldLimitProximity(x, y)
    if not worldLimitAlerts.enabled then return end
    
    local currentTime = love.timer.getTime()
    if currentTime - worldLimitAlerts.lastAlert < worldLimitAlerts.alertCooldown then
        return
    end
    
    local distanceToLimit = math.min(
        WORLD_LIMIT - math.abs(x),
        WORLD_LIMIT - math.abs(y)
    )
    
    if distanceToLimit <= worldLimitAlerts.criticalDistance then
        showWorldLimitAlert("CRITICAL_PROXIMITY", distanceToLimit)
        worldLimitAlerts.lastAlert = currentTime
    elseif distanceToLimit <= worldLimitAlerts.warningDistance then
        -- Solo mostrar advertencia cada 10 segundos
        if currentTime - worldLimitAlerts.lastAlert >= 10.0 then
            showWorldLimitAlert("WARNING_PROXIMITY", distanceToLimit)
            worldLimitAlerts.lastAlert = currentTime
        end
    end
end

-- Mostrar alertas de límites del mundo
function showWorldLimitAlert(alertType, distance)
    if alertType == "BOUNDARY_REACHED" then
        print("⚠️  WORLD BOUNDARY REACHED - Position clamped to world limits")
    elseif alertType == "CRITICAL_PROXIMITY" then
        print("🚨 CRITICAL: " .. math.floor(distance) .. " units from world boundary!")
    elseif alertType == "WARNING_PROXIMITY" then
        print("⚠️  Warning: " .. math.floor(distance) .. " units from world boundary")
    end
end

function love.draw()
    -- Aplicar transformación de cámara
    if _G.camera then
        _G.camera:apply()
    end
    
    -- Dibujar el mapa usando el sistema 3D mejorado
    Map.draw(_G.camera)
    
    -- Dibujar debug de biomas 3D si está activado
    if biomeDebug.enabled and biomeDebug.showRegions then
        drawBiomeRegionDebug()
    end
    
    -- Dibujar debug de límites del mundo
    if biomeDebug.enabled and biomeDebug.showWorldLimits then
        drawWorldLimitsDebug()
    end
    
    -- Dibujar visualización de altura falsa
    if biomeDebug.enabled and biomeDebug.show3DParameters then
        draw3DParametersDebug()
    end
    
    -- Dibujar el jugador
    if player then
        player:draw()
    end
    
    -- Dibujar efectos de iluminación si están habilitados
    if lighting.enabled then
        drawLightingEffects()
    end
    
    -- Restaurar transformación de cámara
    if _G.camera then
        _G.camera:unapply()
    end
    
    -- Dibujar HUD (no afectado por la cámara)
    HUD.draw()
    
    -- Dibujar información de debug de biomas 3D y sistemas en pantalla
    if biomeDebug.enabled then
        drawBiomeDebugOverlay()
    end
    
    -- Dibujar overlay de performance si está activado
    if biomeDebug.showPerformanceOverlay or advancedStats.enabled then
        drawPerformanceOverlay()
    end
end

-- Dibujar debug de límites del mundo
function drawWorldLimitsDebug()
    if not _G.camera or not player then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Convertir límites del mundo a coordenadas relativas
    local relativeCorners = {}
    for _, corner in ipairs({
        {-WORLD_LIMIT, -WORLD_LIMIT},
        {WORLD_LIMIT, -WORLD_LIMIT},
        {WORLD_LIMIT, WORLD_LIMIT},
        {-WORLD_LIMIT, WORLD_LIMIT}
    }) do
        local relX, relY = CoordinateSystem.worldToRelative(corner[1], corner[2])
        local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
        
        local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
        local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
        
        table.insert(relativeCorners, {screenX, screenY})
    end
    
    -- Dibujar límites del mundo
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.setLineWidth(3)
    
    -- Dibujar rectángulo de límites
    if #relativeCorners == 4 then
        love.graphics.line(
            relativeCorners[1][1], relativeCorners[1][2],  -- Esquina superior izquierda
            relativeCorners[2][1], relativeCorners[2][2],  -- Esquina superior derecha
            relativeCorners[3][1], relativeCorners[3][2],  -- Esquina inferior derecha
            relativeCorners[4][1], relativeCorners[4][2],  -- Esquina inferior izquierda
            relativeCorners[1][1], relativeCorners[1][2]   -- Volver al inicio
        )
    end
    
    -- Dibujar zona de advertencia
    love.graphics.setColor(1, 1, 0.2, 0.3)
    local warningMargin = 5000  -- 5000 unidades hacia adentro
    local warningCorners = {}
    for _, corner in ipairs({
        {-WORLD_LIMIT + warningMargin, -WORLD_LIMIT + warningMargin},
        {WORLD_LIMIT - warningMargin, -WORLD_LIMIT + warningMargin},
        {WORLD_LIMIT - warningMargin, WORLD_LIMIT - warningMargin},
        {-WORLD_LIMIT + warningMargin, WORLD_LIMIT - warningMargin}
    }) do
        local relX, relY = CoordinateSystem.worldToRelative(corner[1], corner[2])
        local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
        
        local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
        local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
        
        table.insert(warningCorners, {screenX, screenY})
    end
    
    if #warningCorners == 4 then
        love.graphics.line(
            warningCorners[1][1], warningCorners[1][2],
            warningCorners[2][1], warningCorners[2][2],
            warningCorners[3][1], warningCorners[3][2],
            warningCorners[4][1], warningCorners[4][2],
            warningCorners[1][1], warningCorners[1][2]
        )
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar debug de parámetros 3D
function draw3DParametersDebug()
    if not _G.camera or not player or not BiomeSystem then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Obtener información actual del bioma con parámetros 3D
    local success, biomeInfo = pcall(function()
        return BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
    end)
    
    if not success or not biomeInfo or not biomeInfo.parameters then
        return
    end
    
    local params = biomeInfo.parameters
    
    -- Dibujar grid de altura falsa alrededor del jugador
    local gridSize = 1000  -- Tamaño de cada celda del grid
    local gridRange = 5    -- Rango de celdas alrededor del jugador
    
    for dx = -gridRange, gridRange do
        for dy = -gridRange, gridRange do
            local testX = player.x + dx * gridSize
            local testY = player.y + dy * gridSize
            
            -- Verificar que esté dentro de límites del mundo
            if math.abs(testX) <= WORLD_LIMIT and math.abs(testY) <= WORLD_LIMIT then
                local testParams = BiomeSystem.generateSpaceParameters(
                    math.floor(testX / (48 * 32)),
                    math.floor(testY / (48 * 32))
                )
                
                -- Convertir a coordenadas de pantalla
                local relX, relY = CoordinateSystem.worldToRelative(testX, testY)
                local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
                
                local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
                local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
                
                -- Solo dibujar si está en pantalla
                if screenX >= -50 and screenX <= love.graphics.getWidth() + 50 and
                   screenY >= -50 and screenY <= love.graphics.getHeight() + 50 then
                    
                    -- Color basado en altura falsa
                    local depthColor = {
                        0.2 + testParams.depth * 0.8,
                        0.3 + testParams.depth * 0.4,
                        0.1 + testParams.depth * 0.9,
                        0.6
                    }
                    
                    love.graphics.setColor(depthColor)
                    local size = math.max(2, 10 * _G.camera.zoom)
                    love.graphics.circle("fill", screenX, screenY, size)
                    
                    -- Mostrar valor de altura falsa si el zoom es suficiente
                    if _G.camera.zoom > 0.1 then
                        love.graphics.setColor(1, 1, 1, 0.8)
                        love.graphics.print(string.format("%.2f", testParams.depth), 
                                          screenX - 10, screenY - 15)
                    end
                end
            end
        end
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Actualizar estadísticas avanzadas (MEJORADO)
function updateAdvancedStats(dt)
    local currentTime = love.timer.getTime()
    
    -- Agregar tiempo de frame actual al historial
    table.insert(advancedStats.frameTimeHistory, dt)
    if #advancedStats.frameTimeHistory > advancedStats.maxHistorySize then
        table.remove(advancedStats.frameTimeHistory, 1)
    end
    
    -- Actualizar estadísticas de límites del mundo
    if player and CoordinateSystem then
        local distanceToLimit = CoordinateSystem.getDistanceToLimit and 
                               CoordinateSystem.getDistanceToLimit(player.x, player.y) or 0
        
        if distanceToLimit <= worldLimitAlerts.warningDistance then
            advancedStats.worldLimitStats.nearLimitTime = advancedStats.worldLimitStats.nearLimitTime + dt
        end
    end
    
    -- Actualizar estadísticas cada intervalo
    if currentTime - advancedStats.lastUpdate >= advancedStats.updateInterval then
        advancedStats.lastUpdate = currentTime
        
        if advancedStats.enabled then
            -- Calcular FPS promedio
            local avgFrameTime = 0
            for _, frameTime in ipairs(advancedStats.frameTimeHistory) do
                avgFrameTime = avgFrameTime + frameTime
            end
            avgFrameTime = avgFrameTime / #advancedStats.frameTimeHistory
            
            print("=== ADVANCED 3D STATS UPDATE ===")
            print("Avg FPS: " .. math.floor(1 / avgFrameTime))
            print("Frame Time: " .. string.format("%.2f", avgFrameTime * 1000) .. "ms")
            print("Current Seed: " .. gameState.currentSeed)
            print("3D System: 6-Parameter Generation Active")
            
            -- Estadísticas de límites del mundo
            if advancedStats.worldLimitStats.violations > 0 then
                print("World Limit Violations: " .. advancedStats.worldLimitStats.violations)
            end
            if advancedStats.worldLimitStats.nearLimitTime > 0 then
                print("Time Near Limits: " .. string.format("%.1f", advancedStats.worldLimitStats.nearLimitTime) .. "s")
            end
            
            -- Estadísticas de memoria
            local memoryKB = collectgarbage("count")
            print("Memory: " .. string.format("%.1f", memoryKB / 1024) .. "MB")
        end
    end
end

-- Dibujar overlay de performance
function drawPerformanceOverlay()
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de performance en la esquina inferior izquierda (expandido)
    local panelWidth = 350
    local panelHeight = 220  -- Más alto para información 3D y límites
    local x = 10
    local y = love.graphics.getHeight() - panelHeight - 10
    
    -- Fondo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("3D PERFORMANCE MONITOR", x + 10, y + 8)
    
    -- Información en tiempo real
    love.graphics.setFont(love.graphics.newFont(10))
    
    local infoY = y + 25
    
    -- Información de semilla 3D
    love.graphics.setColor(1, 1, 0.5, 1)
    love.graphics.print("3D Seed: " .. gameState.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed), x + 10, infoY)
    infoY = infoY + 15
    
    -- FPS actual
    local currentFPS = love.timer.getFPS()
    local fpsColor = currentFPS >= 55 and {0, 1, 0, 1} or currentFPS >= 30 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(fpsColor)
    love.graphics.print("FPS: " .. currentFPS, x + 10, infoY)
    infoY = infoY + 12
    
    -- Información de límites del mundo
    if player and CoordinateSystem then
        local limitSuccess, distanceToLimit = pcall(function()
            return CoordinateSystem.getDistanceToLimit and CoordinateSystem.getDistanceToLimit(player.x, player.y) or 0
        end)
        
        if limitSuccess then
            local limitColor = distanceToLimit < 1000 and {1, 0.2, 0.2, 1} or 
                              distanceToLimit < 5000 and {1, 1, 0.2, 1} or {0.2, 1, 0.2, 1}
            love.graphics.setColor(limitColor)
            love.graphics.print("Limit Distance: " .. math.floor(distanceToLimit), x + 10, infoY)
            infoY = infoY + 12
        end
    end
    
    -- Estadísticas del renderizador
    local rendererStats = OptimizedRenderer.getStats()
    if rendererStats then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Frame Time: " .. string.format("%.1f", rendererStats.performance.frameTime) .. "ms", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Draw Calls: " .. rendererStats.performance.drawCalls, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Objects Rendered: " .. rendererStats.rendering.objectsRendered, x + 10, infoY)
        infoY = infoY + 12
        
        -- Eficiencia de culling con color
        local cullingEff = rendererStats.rendering.cullingEfficiency
        local cullingColor = cullingEff >= 80 and {0, 1, 0, 1} or cullingEff >= 60 and {1, 1, 0, 1} or {1, 0, 0, 1}
        love.graphics.setColor(cullingColor)
        love.graphics.print("Culling Efficiency: " .. string.format("%.1f%%", cullingEff), x + 10, infoY)
        infoY = infoY + 12
        
        -- Calidad adaptativa
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Quality Level: " .. string.format("%.1f%%", rendererStats.quality.current * 100), x + 10, infoY)
        infoY = infoY + 12
    end
    
    -- Estadísticas 3D
    if biomeCache and biomeCache.current3DParams then
        love.graphics.setColor(0.8, 1, 1, 1)
        love.graphics.print("False Height: " .. string.format("%.3f", biomeCache.current3DParams.depth), x + 10, infoY)
        infoY = infoY + 12
    end
    
    -- Memoria
    local memoryMB = collectgarbage("count") / 1024
    local memoryColor = memoryMB < 100 and {0, 1, 0, 1} or memoryMB < 200 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(memoryColor)
    love.graphics.print("Memory: " .. string.format("%.1f", memoryMB) .. "MB", x + 10, infoY)
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar overlay de debug de biomas
function drawBiomeDebugOverlay()
    if not player then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de debug en la esquina superior derecha (expandido para 3D)
    local panelWidth = 450
    local panelHeight = 380  -- Más alto para información 3D
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = HUD.isBiomeInfoVisible() and 280 or 10
    
    -- Fondo
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("3D ENHANCED SYSTEM DEBUG", x + 10, y + 8)
    
    local infoY = y + 25
    
    -- Información de semilla 3D
    love.graphics.setColor(1, 0.8, 0.5, 1)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.print("3D SEED SYSTEM", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Alpha: " .. gameState.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed), x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print("System: 6-Parameter 3D Generation", x + 10, infoY)
    infoY = infoY + 15
    
    -- Información de límites del mundo
    love.graphics.setColor(1, 0.8, 0.8, 1)
    love.graphics.print("WORLD BOUNDARIES", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Size: " .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " units", x + 10, infoY)
    infoY = infoY + 12
    
    if player and CoordinateSystem then
        local limitSuccess, distanceToLimit, isNear = pcall(function()
            local dist = CoordinateSystem.getDistanceToLimit and CoordinateSystem.getDistanceToLimit(player.x, player.y) or 0
            local near = CoordinateSystem.isNearLimit and CoordinateSystem.isNearLimit(player.x, player.y) or false
            return dist, near
        end)
        
        if limitSuccess then
            local limitColor = isNear and {1, 0.8, 0.2, 1} or {0.8, 1, 0.8, 1}
            love.graphics.setColor(limitColor)
            love.graphics.print("Distance to Limit: " .. math.floor(distanceToLimit), x + 10, infoY)
            infoY = infoY + 12
            
            local statusText = isNear and "NEAR BOUNDARY" or "SAFE"
            love.graphics.print("Status: " .. statusText, x + 10, infoY)
            infoY = infoY + 15
        end
    end
    
    -- Información detallada de biomas 3D
    local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
    if biomeInfo then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("CURRENT 3D BIOME", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Name: " .. biomeInfo.name, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Rarity: " .. biomeInfo.rarity, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Target Weight: " .. string.format("%.1f%%", biomeInfo.config.spawnWeight * 100), x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Position: (" .. math.floor(player.x) .. ", " .. math.floor(player.y) .. ")", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")", x + 10, infoY)
        infoY = infoY + 15
        
        -- Parámetros 3D detallados
        if biomeInfo.parameters then
            love.graphics.setColor(0.8, 1, 1, 1)
            love.graphics.print("3D PARAMETERS", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.setColor(1, 1, 1, 1)
            
            local params = biomeInfo.parameters
            love.graphics.print("Energy: " .. string.format("%.3f", params.energy) .. " (Spatial Temperature)", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Density: " .. string.format("%.3f", params.density) .. " (Matter Concentration)", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Continental: " .. string.format("%.3f", params.continentalness) .. " (Distance from Deep Space)", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Turbulence: " .. string.format("%.3f", params.turbulence) .. " (Spatial Stability)", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Weirdness: " .. string.format("%.3f", params.weirdness) .. " (Gravitational Anomalies)", x + 10, infoY)
            infoY = infoY + 12
            
            -- Altura falsa destacada
            love.graphics.setColor(1, 1, 0.5, 1)
            love.graphics.print("FALSE HEIGHT: " .. string.format("%.3f", params.depth) .. " (Invisible Z-Dimension)", x + 10, infoY)
            infoY = infoY + 15
        end
        
        -- Resto de información (sistema de coordenadas, chunks, etc.) - compacto
        local coordStats = CoordinateSystem.getStats()
        if coordStats then
            love.graphics.setColor(0.8, 1, 1, 1)
            love.graphics.print("COORDINATE SYSTEM", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("Sector: (" .. coordStats.currentSector.x .. ", " .. coordStats.currentSector.y .. ")", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Relocations: " .. coordStats.relocations, x + 10, infoY)
            infoY = infoY + 15
        end
        
        local chunkStats = ChunkManager.getStats()
        if chunkStats then
            love.graphics.setColor(1, 0.8, 1, 1)
            love.graphics.print("CHUNK MANAGER", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("Active: " .. chunkStats.active .. " | Cached: " .. chunkStats.cached .. " | Pool: " .. chunkStats.pooled, x + 10, infoY)
            infoY = infoY + 12
            
            if chunkStats.worldLimits then
                love.graphics.print("Outside Limits: " .. chunkStats.worldLimits.chunksOutsideLimits, x + 10, infoY)
                infoY = infoY + 12
            end
        end
        
        -- Indicador de test automático
        if biomeDebug.testDistribution then
            love.graphics.setColor(1, 0.5, 1, 1)
            love.graphics.print("3D AUTO-TESTING ENABLED", x + 10, y + panelHeight - 25)
        end
        
        -- Indicadores de sistemas 3D activos
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.print("3D Enhanced: ✓ False Height ✓ 6-Param ✓ World Limits ✓ Coords ✓ Chunks ✓ Render", x + 10, y + panelHeight - 15)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Resto de funciones de dibujo
function drawBiomeRegionDebug()
    if not _G.camera or not player then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    local visibleChunks, chunkInfo = ChunkManager.getVisibleChunks(_G.camera)
    
    love.graphics.setColor(1, 1, 0, 0.5)
    
    local chunkSize = Map.chunkSize * Map.tileSize
    
    for _, chunk in ipairs(visibleChunks) do
        if chunk.biome then
            local worldX = chunk.x * chunkSize
            local worldY = chunk.y * chunkSize
            
            local relX, relY = CoordinateSystem.worldToRelative(worldX, worldY)
            local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
            
            local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
            local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
            local screenSize = chunkSize * _G.camera.zoom
            
            love.graphics.rectangle("line", screenX, screenY, screenSize, screenSize)
            
            local config = chunk.biome.config
            love.graphics.setColor(config.color[1] + 0.3, config.color[2] + 0.3, config.color[3] + 0.3, 0.7)
            love.graphics.circle("fill", screenX + screenSize/2, screenY + screenSize/2, 10)
            
            if _G.camera.zoom > 0.5 then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf(config.name:sub(1, 8), screenX + 5, screenY + 5, screenSize - 10, "center")
                
                -- Mostrar altura falsa si está disponible
                if chunk.biomeParameters and chunk.biomeParameters.depth then
                    love.graphics.setColor(1, 1, 0.5, 0.8)
                    love.graphics.printf("H:" .. string.format("%.2f", chunk.biomeParameters.depth), 
                                       screenX + 5, screenY + 20, screenSize - 10, "center")
                end
            end
        end
    end
    
    love.graphics.setColor(r, g, b, a)
end

function drawLightingEffects()
    local r, g, b, a = love.graphics.getColor()
    
    local relX, relY = CoordinateSystem.worldToRelative(lighting.playerLight.x, lighting.playerLight.y)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
    
    local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
    local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
    local screenRadius = lighting.playerLight.radius * _G.camera.zoom
    
    love.graphics.setColor(lighting.playerLight.color)
    love.graphics.circle("fill", screenX, screenY, screenRadius, 32)
    
    love.graphics.setColor(lighting.playerLight.color[1], 
                          lighting.playerLight.color[2], 
                          lighting.playerLight.color[3], 
                          lighting.playerLight.color[4] * 0.3)
    love.graphics.circle("fill", screenX, screenY, screenRadius * 1.5, 32)
    
    love.graphics.setColor(r, g, b, a)
end

function love.keypressed(key)
    -- Manejar input de semilla si el HUD lo está mostrando
    if HUD.isSeedInputVisible() then
        local newSeed, seedType = HUD.handleSeedInput(key)
        if newSeed then
            changeSeed(newSeed)
        end
        return
    end
    
    -- Controles generales (sin cambios)
    if key == "escape" then
        love.event.quit()
    elseif key == "f1" then
        HUD.toggleInfo()
        local rendererStats = OptimizedRenderer.getStats()
        local chunkStats = ChunkManager.getStats()
        local coordStats = CoordinateSystem.getStats()

        print("=== 3D ENHANCED PERFORMANCE & MEMORY STATS ===")
        print("Seed: " .. gameState.currentSeed .. " (Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed) .. ")")
        print("3D System: 6-Parameter Generation with False Height")
        print("World Limits: " .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " units")

        if rendererStats then
            print("Frame Time: " .. string.format("%.2f", rendererStats.performance.frameTime) .. "ms")
            print("FPS: " .. rendererStats.performance.fps)
            print("Draw Calls: " .. rendererStats.performance.drawCalls)
            print("Objects Rendered: " .. rendererStats.rendering.objectsRendered)
            print("Culling Efficiency: " .. string.format("%.1f", rendererStats.rendering.cullingEfficiency) .. "%")
            print("Quality Level: " .. string.format("%.1f", rendererStats.quality.current * 100) .. "%")
        end

        if chunkStats then
            print("Chunks Active: " .. chunkStats.active .. ", Cached: " .. chunkStats.cached)
            print("Cache Hit Ratio: " .. string.format("%.1f", chunkStats.cacheHitRatio * 100) .. "%")
            if chunkStats.worldLimits then
                print("Chunks Outside Limits: " .. chunkStats.worldLimits.chunksOutsideLimits)
                print("Limit Enforced Chunks: " .. chunkStats.worldLimits.limitEnforcedChunks)
            end
            print("Chunk Pool Usage: " .. chunkStats.pooled .. " available")
            print("Memory Management: Active=" .. chunkStats.active .. " Cached=" .. chunkStats.cached)
            print("Load Queue: " .. chunkStats.loadQueue .. " pending")
            print("Player Chunk: (" .. chunkStats.playerChunk.x .. ", " .. chunkStats.playerChunk.y .. ")")
        end

        if coordStats then
            if coordStats.currentSector then
                print("Current Sector: (" .. coordStats.currentSector.x .. ", " .. coordStats.currentSector.y .. ")")
            else
                print("Current Sector: N/A")
            end
            print("Coordinate Relocations: " .. coordStats.relocations)
            if coordStats.worldLimits then
                print("World Limits Active: " .. (coordStats.worldLimits.active and "YES" or "NO"))
                print("Distance to Limit: " .. math.floor(coordStats.worldLimits.distanceToLimit))
                print("Near Limit: " .. (coordStats.worldLimits.nearLimit and "YES" or "NO"))
                print("Limit Violations: " .. coordStats.worldLimits.violations)
            end
        end

        print("Memory Usage: " .. string.format("%.1f", collectgarbage("count") / 1024) .. "MB")

        biomeDebug.showPerformanceOverlay = not biomeDebug.showPerformanceOverlay
        print("3D Performance overlay: " .. (biomeDebug.showPerformanceOverlay and "ON" or "OFF"))

        advancedStats.enabled = not advancedStats.enabled
        print("Advanced 3D stats monitoring: " .. (advancedStats.enabled and "ON" or "OFF"))
    elseif key == "f2" then
        HUD.showSeedInput()
    elseif key == "f3" then
        if player and player.stats then
            local enabled = player.stats:toggleDebugMode()
            print("Debug mode: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f4" then
        _G.showGrid = not _G.showGrid
        print("Enhanced grid display: " .. (_G.showGrid and "ON" or "OFF"))
    elseif key == "f5" then
        lighting.enabled = not lighting.enabled
        print("Lighting: " .. (lighting.enabled and "ON" or "OFF"))
    elseif key == "f6" then
        if player and player.stats then
            local died = player:takeDamage(1)
            print("Test damage applied. Died: " .. tostring(died))
        end
    elseif key == "f7" then
        if Map.starConfig then
            Map.starConfig.enhancedEffects = not Map.starConfig.enhancedEffects
            local status = Map.starConfig.enhancedEffects and "ON" or "OFF"
            print("Enhanced star effects: " .. status)
        end
    elseif key == "f8" then
        if Map.starConfig then
            local currentMax = Map.starConfig.maxStarsPerFrame
            if currentMax <= 1500 then
                Map.starConfig.maxStarsPerFrame = 3000
                print("Star quality: MEDIUM (3000 stars/frame)")
            elseif currentMax <= 3000 then
                Map.starConfig.maxStarsPerFrame = 5000
                print("Star quality: HIGH (5000 stars/frame)")
            else
                Map.starConfig.maxStarsPerFrame = 1500
                print("Star quality: LOW (1500 stars/frame)")
            end
        end
    elseif key == "f9" then
        if player and player.stats then
            local enabled = player.stats:toggleInvulnerability()
            print("Invulnerability: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f10" then
        if player and player.stats then
            local enabled = player.stats:toggleInfiniteFuel()
            print("Infinite fuel: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f11" then
        if player and player.stats then
            local enabled = player.stats:toggleFastRegen()
            print("Fast shield regen: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f12" then
        HUD.toggleBiomeInfo()
        OptimizedRenderer.toggleDebug("lod")
        print("LOD debug visualization toggled")
        print("LOD levels: 0=High, 1=Medium, 2=Low, 3=Minimal")
        HUD.toggle3DDebug()
        HUD.toggleWorldLimits()
    elseif key == "`" or key == "~" then
        biomeDebug.enabled = not biomeDebug.enabled
        local status = biomeDebug.enabled and "ON" or "OFF"
        print("Advanced 3D biome debug: " .. status)
        if biomeDebug.enabled then
            print("Enhanced 3D debug controls:")
            print("  F1: Performance Stats & Overlay / Memory & Coordinate Info")
            print("  F12: Biome Scanner / LOD Debug Visualization / 3D Parameter Debug Panel / World Limits Debug Panel")
            print("  T: Test 3D distribution | Y: Auto-test toggle")
            print("  Z: Coordinate precision test")
            print("  X: Force coordinate relocation")
            print("  H: Toggle false height visualization")
            print("  L: Toggle world limits visualization")
            print("  Ctrl+T: 3D Distribution test | Ctrl+L: Limit boundary test")
            print("  Ctrl+R: Memory cleanup (force GC)")
        end
    elseif key == "t" and biomeDebug.enabled then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            print("=== 3D ENHANCED DISTRIBUTION TEST ===")
            BiomeSystem.debugDistribution(3000)  -- Muestra más grande para 3D
        else
            print("=== STANDARD 3D DISTRIBUTION TEST ===")
            BiomeSystem.debugDistribution(2000)
        end
    elseif key == "y" and biomeDebug.enabled then
        biomeDebug.testDistribution = not biomeDebug.testDistribution
        print("Auto 3D distribution test: " .. (biomeDebug.testDistribution and "ON" or "OFF"))
    elseif key == "z" and biomeDebug.enabled then
        if player then
            local testResult = CoordinateSystem.debugPrecision(player.x, player.y)
            print("Coordinate precision test: " .. (testResult and "PASSED" or "FAILED"))
        end
    elseif key == "x" and biomeDebug.enabled then
        if player then
            CoordinateSystem.relocateOrigin(player.x, player.y)
            print("Coordinate system manually relocated")
        end
    elseif key == "h" and biomeDebug.enabled then
        biomeDebug.show3DParameters = not biomeDebug.show3DParameters
        print("False height visualization: " .. (biomeDebug.show3DParameters and "ON" or "OFF"))
    elseif key == "l" and biomeDebug.enabled then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            -- Test de límites del mundo
            if player then
                print("=== WORLD LIMIT BOUNDARY TEST ===")
                local testPositions = {
                    {WORLD_LIMIT - 100, 0},
                    {0, WORLD_LIMIT - 100},
                    {WORLD_LIMIT + 100, 0},  -- Fuera de límites
                    {0, WORLD_LIMIT + 100}   -- Fuera de límites
                }
                
                for i, pos in ipairs(testPositions) do
                    local withinLimits = CoordinateSystem.isWithinWorldLimits(pos[1], pos[2])
                    local distance = CoordinateSystem.getDistanceToLimit(pos[1], pos[2])
                    print("Position " .. i .. ": (" .. pos[1] .. ", " .. pos[2] .. ")")
                    print("  Within limits: " .. (withinLimits and "YES" or "NO"))
                    print("  Distance to limit: " .. math.floor(distance))
                end
            end
        else
            biomeDebug.showWorldLimits = not biomeDebug.showWorldLimits
            print("World limits visualization: " .. (biomeDebug.showWorldLimits and "ON" or "OFF"))
        end
    elseif key == "r" then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            if biomeDebug.enabled then
                print("=== MANUAL MEMORY CLEANUP ===")
                local beforeMB = collectgarbage("count") / 1024
                collectgarbage("collect")
                local afterMB = collectgarbage("count") / 1024
                print("Memory before: " .. string.format("%.1f", beforeMB) .. "MB")
                print("Memory after: " .. string.format("%.1f", afterMB) .. "MB")
                print("Freed: " .. string.format("%.1f", beforeMB - afterMB) .. "MB")
            end
        else
            local newSeed = SeedSystem.generate()
            changeSeed(newSeed)
        end
    elseif key == "p" then
        gameState.paused = not gameState.paused
        print("Game " .. (gameState.paused and "PAUSED" or "RESUMED"))
    elseif key == "h" then
        if player and player.stats then
            player:heal(2)
            print("Player healed")
        end
    elseif key == "u" then
        if player and player.stats then
            player:addFuel(25)
            print("Fuel added")
        end
    -- Debug rápido de biomas con teclas numéricas (sin cambios)
    elseif key >= "1" and key <= "6" and biomeDebug.enabled then
        local biomeTypes = {
            ["1"] = BiomeSystem.BiomeType.DEEP_SPACE,
            ["2"] = BiomeSystem.BiomeType.NEBULA_FIELD,
            ["3"] = BiomeSystem.BiomeType.ASTEROID_BELT,
            ["4"] = BiomeSystem.BiomeType.GRAVITY_ANOMALY,
            ["5"] = BiomeSystem.BiomeType.RADIOACTIVE_ZONE,
            ["6"] = BiomeSystem.BiomeType.ANCIENT_RUINS
        }
        local biomeType = biomeTypes[key]
        if biomeType then
            local config = BiomeSystem.getBiomeConfig(biomeType)
            print("=== 3D ENHANCED BIOME INFO: " .. config.name .. " ===")
            print("Rarity: " .. config.rarity)
            print("Coverage: " .. string.format("%.1f%%", config.spawnWeight * 100))
            print("3D Conditions: Complex 6-parameter requirements")
            if biomeType == BiomeSystem.BiomeType.DEEP_SPACE then
                print("*** PREDOMINANT BIOME - Acts as spatial ocean separating other biomes ***")
            end
            print("Current 3D seed ensures natural distribution: " .. gameState.currentSeed)
        end
    end
end

function love.textinput(text)
    HUD.textinput(text)
end

function love.wheelmoved(x, y)
    if _G.camera and _G.camera.wheelmoved then
        _G.camera:wheelmoved(x, y)
    end
end

function changeSeed(newSeed)
    -- Validar la nueva semilla
    if not SeedSystem.validate(newSeed) then
        print("Invalid seed format. Using default seed.")
        newSeed = "A1B2C3D4E5"  -- Default seed
    end
    
    gameState.currentSeed = newSeed
    
    love.window.setTitle("Space Roguelike - 3D Enhanced Systems - Seed: " .. newSeed)
    regenerateMap(newSeed)
    print("New 3D enhanced galaxy generated with seed: " .. newSeed)
    print("Numeric equivalent: " .. SeedSystem.toNumeric(newSeed))
end

function regenerateMap(seed)
    -- Regenerar mapa con nueva semilla usando el sistema 3D
    Map.regenerate(seed)
    
    -- Reposicionar jugador al centro (dentro de límites del mundo)
    if player then
        player.x = 0
        player.y = 0
        player.dx = 0
        player.dy = 0
        
        -- Reset player stats
        if player.stats then
            player.stats.health.currentHealth = player.stats.health.maxHealth
            player.stats.shield.currentShield = player.stats.shield.maxShield
            player.stats.fuel.currentFuel = player.stats.fuel.maxFuel
            player.stats:updateHeartDisplay()
        end
    end
    
    -- Recentrar cámara
    if _G.camera then
        _G.camera:setPosition(0, 0)
    end
    
    -- Reinicializar sistema de coordenadas desde el origen
    CoordinateSystem.init(0, 0)
    
    -- Reinicializar gestor de chunks
    ChunkManager.init(SeedSystem.toNumeric(seed))
    
    -- Actualizar referencias del HUD
    HUD.updateReferences(gameState, player, Map)
    
    -- Reset estadísticas de límites del mundo
    advancedStats.worldLimitStats = {
        violations = 0,
        relocations = 0,
        nearLimitTime = 0
    }
    
    print("=== NEW 3D ENHANCED GALAXY GENERATED ===")
    print("Alphanumeric Seed: " .. seed)
    print("Numeric Seed: " .. SeedSystem.toNumeric(seed))
    print("World Limits: ±" .. WORLD_LIMIT .. " units (" .. (WORLD_LIMIT * 2) .. " x " .. (WORLD_LIMIT * 2) .. " total)")
    
    print("=== 3D ENHANCED SYSTEMS ACTIVE ===")
    print("✓ 6-Parameter 3D biome generation system")
    print("✓ False height dimension for natural vertical variation")
    print("✓ World boundaries enforced at " .. WORLD_LIMIT .. " units")
    print("✓ Natural biome distribution with improved spatial coherence")
    print("✓ Alphanumeric seed system with 36^10 possibilities")
    print("✓ Infinite exploration within defined world boundaries")
    print("✓ Dynamic chunk management with world limit awareness") 
    print("✓ Adaptive performance rendering with 3D optimization")
    print("✓ Enhanced memory efficiency for long-term exploration")
    
    -- Mostrar información de sistemas mejorados
    local coordStats = CoordinateSystem.getStats()
    local chunkStats = ChunkManager.getStats()
    print("Coordinate System: Sector (0,0), Ready for bounded infinite exploration")
    if chunkStats then
        print("Chunk Manager: Pool ready with " .. chunkStats.pooled .. " chunks available")
    end
    print("Enhanced Renderer: LOD and culling systems active")
    print("3D Biome System: 6-parameter generation with false height")
    print("World Limits: Automatic boundary enforcement active")
    print("Use F13/F14 for detailed system statistics")
    print("Use F16/F17 for 3D debug panels")
end

function love.resize(w, h)
    if _G.camera then
        _G.camera:updateScreenDimensions()
    end
    
    -- Actualizar dimensiones de pantalla para el culling optimizado
    if Map and Map.updateScreenDimensions then
        Map.updateScreenDimensions()
    end
end

-- NUEVO: Función de cleanup al cerrar
function love.quit()
    print("=== 3D ENHANCED SPACE ROGUELIKE SHUTTING DOWN ===")
    
    -- Limpiar sistemas
    if ChunkManager and ChunkManager.cleanup then
        ChunkManager.cleanup()
    end
    
    -- Mostrar estadísticas finales
    if advancedStats.worldLimitStats.violations > 0 then
        print("Final world limit violations: " .. advancedStats.worldLimitStats.violations)
    end
    
    if advancedStats.worldLimitStats.nearLimitTime > 0 then
        print("Total time near limits: " .. string.format("%.1f", advancedStats.worldLimitStats.nearLimitTime) .. " seconds")
    end
    
    print("Memory at shutdown: " .. string.format("%.1f", collectgarbage("count") / 1024) .. "MB")
    print("3D Enhanced galaxy exploration session ended")
    print("Seed: " .. gameState.currentSeed)
end