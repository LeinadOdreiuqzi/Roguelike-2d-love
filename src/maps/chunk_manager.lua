-- src/maps/chunk_manager.lua (ADAPTADO PARA LÍMITES DEL MUNDO 200K x 200K)
-- Sistema avanzado de gestión de chunks con pooling, priorización y límites del mundo

local ChunkManager = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'

-- LÍMITES DEL MUNDO
ChunkManager.WORLD_LIMIT = 200000  -- ±200,000 unidades

-- Configuración del gestor de chunks
ChunkManager.config = {
    -- Tamaño de cada chunk
    chunkSize = 48,
    tileSize = 32,
    
    -- Gestión de memoria
    maxActiveChunks = 60,      -- Further reduced for memory optimization
    maxCachedChunks = 120,      -- Further reduced for memory optimization
    poolSize = 30,              -- Further reduced for pooling optimization
    
    -- Distancias de carga/descarga
    loadDistance = 2,           -- Adjusted for even closer loading
    unloadDistance = 4,         -- Adjusted for earlier unloading
    preloadDistance = 1,         -- More conservative preloading
    
    -- Prioridades de carga
    priority = {
        immediate = 1,          -- Chunk donde está el jugador
        adjacent = 2,           -- Chunks adyacentes
        visible = 3,            -- Chunks visibles en pantalla
        preload = 4,            -- Chunks de precarga
        background = 5,         -- Chunks de fondo
        edge = 6               -- Chunks cerca del límite del mundo
    },
    
    -- Configuración de generación
    maxGenerationTime = 0.003,  -- Tiempo máximo por frame para generación (3ms)
    maxObjectsPerFrame = 150,   -- Objetos máximos a generar por frame
    objectGenerationDistance = 5, -- Reduced distance for detailed object generation
    
    -- Límites del mundo
    worldLimits = {
        enabled = true,
        maxChunkX = nil,        -- Se calcula automáticamente
        maxChunkY = nil,        -- Se calcula automáticamente
        bufferChunks = 2        -- Chunks de buffer antes del límite
    },
    
    -- Estadísticas
    enableStats = true

}

-- Estado del gestor
ChunkManager.state = {
    -- Chunks activos (completamente cargados)
    activeChunks = {},
    -- Chunks en cache (parcialmente cargados)
    cachedChunks = {},
    -- Pool de chunks reutilizables
    chunkPool = {},
    
    -- Queues de carga/descarga
    loadQueue = {},
    unloadQueue = {},
    generationQueue = {},
    
    -- Estado del jugador
    lastPlayerChunkX = 0,
    lastPlayerChunkY = 0,
    
    -- Límites calculados
    calculatedLimits = {
        minChunkX = 0,
        maxChunkX = 0,
        minChunkY = 0,
        maxChunkY = 0
    },
    
    -- Estadísticas
    stats = {
        activeCount = 0,
        cachedCount = 0,
        poolCount = 0,
        loadRequests = 0,
        unloadRequests = 0,
        cacheHits = 0,
        cacheMisses = 0,
        generationTime = 0,
        lastFrameTime = 0,
        chunksOutsideLimits = 0,
        limitEnforcedChunks = 0
    }
}

-- Estructura de chunk mejorada
local ChunkStructure = {
    -- Identificación
    x = 0,
    y = 0,
    id = "",
    
    -- Estado
    status = "empty",      -- empty, generating, partial, complete
    lastAccess = 0,
    priority = 5,
    loadProgress = 0,      -- Progreso de carga 0-1
    
    -- Límites del mundo
    withinLimits = true,
    distanceToLimit = 0,
    
    -- Datos del chunk
    tiles = {},
    objects = {},
    biome = nil,
    specialObjects = {},
    
    -- Propiedades de renderizado
    bounds = {},
    visible = false,
    lodLevel = 0,
    
    -- Metadatos
    seed = 0,
    generated = false,
    version = 1,
    
    -- Información 3D de bioma
    biomeParameters = nil
}

-- Inicializar el gestor de chunks
function ChunkManager.init(seed)
    ChunkManager.state.activeChunks = {}
    ChunkManager.state.cachedChunks = {}
    ChunkManager.state.chunkPool = {}
    ChunkManager.state.loadQueue = {}
    ChunkManager.state.unloadQueue = {}
    ChunkManager.state.generationQueue = {}
    
    -- Calcular límites del mundo en términos de chunks
    ChunkManager.calculateWorldLimits()
    
    -- Crear pool inicial de chunks
    for i = 1, ChunkManager.config.poolSize do
        local chunk = ChunkManager.createEmptyChunk()
        table.insert(ChunkManager.state.chunkPool, chunk)
    end
    
    -- Reset estadísticas
    ChunkManager.resetStats()
    
    print("ChunkManager initialized with world limits:")
    print("  World size: " .. (ChunkManager.WORLD_LIMIT * 2) .. " x " .. (ChunkManager.WORLD_LIMIT * 2) .. " units")
    print("  Chunk limits: X[" .. ChunkManager.state.calculatedLimits.minChunkX .. 
          " to " .. ChunkManager.state.calculatedLimits.maxChunkX .. "], Y[" .. 
          ChunkManager.state.calculatedLimits.minChunkY .. " to " .. ChunkManager.state.calculatedLimits.maxChunkY .. "]")
    print("  Pool size: " .. ChunkManager.config.poolSize)
    print("  Max active chunks: " .. ChunkManager.config.maxActiveChunks)
end

-- Calcular límites del mundo en términos de chunks
function ChunkManager.calculateWorldLimits()
    local chunkWorldSize = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
    local maxChunksFromCenter = math.floor(ChunkManager.WORLD_LIMIT / chunkWorldSize)
    
    ChunkManager.state.calculatedLimits = {
        minChunkX = -maxChunksFromCenter,
        maxChunkX = maxChunksFromCenter,
        minChunkY = -maxChunksFromCenter,
        maxChunkY = maxChunksFromCenter
    }
    
    -- Actualizar configuración
    ChunkManager.config.worldLimits.maxChunkX = maxChunksFromCenter
    ChunkManager.config.worldLimits.maxChunkY = maxChunksFromCenter
end

-- Verificar si un chunk está dentro de los límites del mundo
function ChunkManager.isChunkWithinLimits(chunkX, chunkY)
    local limits = ChunkManager.state.calculatedLimits
    return chunkX >= limits.minChunkX and chunkX <= limits.maxChunkX and
           chunkY >= limits.minChunkY and chunkY <= limits.maxChunkY
end

-- Calcular distancia de un chunk al límite más cercano
function ChunkManager.getChunkDistanceToLimit(chunkX, chunkY)
    local limits = ChunkManager.state.calculatedLimits
    
    local distanceX = math.min(chunkX - limits.minChunkX, limits.maxChunkX - chunkX)
    local distanceY = math.min(chunkY - limits.minChunkY, limits.maxChunkY - chunkY)
    
    return math.min(distanceX, distanceY)
end

-- Aplicar límites del mundo a coordenadas de chunk
function ChunkManager.enforceChunkLimits(chunkX, chunkY)
    local limits = ChunkManager.state.calculatedLimits
    local originalX, originalY = chunkX, chunkY
    
    chunkX = math.max(limits.minChunkX, math.min(limits.maxChunkX, chunkX))
    chunkY = math.max(limits.minChunkY, math.min(limits.maxChunkY, chunkY))
    
    if chunkX ~= originalX or chunkY ~= originalY then
        ChunkManager.state.stats.limitEnforcedChunks = ChunkManager.state.stats.limitEnforcedChunks + 1
    end
    
    return chunkX, chunkY
end

-- Crear chunk vacío mejorado
function ChunkManager.createEmptyChunk()
    local chunk = {}
    for key, value in pairs(ChunkStructure) do
        if type(value) == "table" then
            chunk[key] = {}
        else
            chunk[key] = value
        end
    end
    return chunk
end

-- Obtener chunk del pool o crear uno nuevo
function ChunkManager.getChunkFromPool()
    if #ChunkManager.state.chunkPool > 0 then
        return table.remove(ChunkManager.state.chunkPool)
    else
        return ChunkManager.createEmptyChunk()
    end
end

-- Devolver chunk al pool
function ChunkManager.returnChunkToPool(chunk)
    if #ChunkManager.state.chunkPool < ChunkManager.config.poolSize then
        -- Limpiar chunk
        ChunkManager.cleanChunk(chunk)
        table.insert(ChunkManager.state.chunkPool, chunk)
        return true
    end
    return false
end

-- Limpiar chunk para reutilización
function ChunkManager.cleanChunk(chunk)
    chunk.tiles = {}
    chunk.objects = {}
    chunk.specialObjects = {}
    chunk.biome = nil
    chunk.biomeParameters = nil
    chunk.status = "empty"
    chunk.loadProgress = 0
    chunk.generated = false
    chunk.visible = false
    chunk.lodLevel = 0
    chunk.withinLimits = true
    chunk.distanceToLimit = 0
end

-- Generar ID único para chunk
function ChunkManager.generateChunkId(chunkX, chunkY)
    return string.format("chunk_%d_%d", chunkX, chunkY)
end

-- Calcular prioridad de carga basada en posición del jugador y límites del mundo
function ChunkManager.calculatePriority(chunkX, chunkY, playerChunkX, playerChunkY)
    -- Verificar límites del mundo primero
    if not ChunkManager.isChunkWithinLimits(chunkX, chunkY) then
        ChunkManager.state.stats.chunksOutsideLimits = ChunkManager.state.stats.chunksOutsideLimits + 1
        return ChunkManager.config.priority.edge + 10  -- Muy baja prioridad
    end
    
    local dx = math.abs(chunkX - playerChunkX)
    local dy = math.abs(chunkY - playerChunkY)
    local distance = math.max(dx, dy)  -- Distancia de Chebyshev
    
    -- Calcular prioridad base
    local basePriority
    if distance == 0 then
        basePriority = ChunkManager.config.priority.immediate
    elseif distance == 1 then
        basePriority = ChunkManager.config.priority.adjacent
    elseif distance <= ChunkManager.config.loadDistance then
        basePriority = ChunkManager.config.priority.visible
    elseif distance <= ChunkManager.config.preloadDistance then
        basePriority = ChunkManager.config.priority.preload
    else
        basePriority = ChunkManager.config.priority.background
    end
    
    -- Ajustar prioridad basada en proximidad a límites del mundo
    local distanceToLimit = ChunkManager.getChunkDistanceToLimit(chunkX, chunkY)
    if distanceToLimit <= ChunkManager.config.worldLimits.bufferChunks then
        basePriority = basePriority + 1  -- Menor prioridad para chunks cerca del límite
    end
    
    return basePriority
end

-- Obtener chunk (principal función de acceso)
function ChunkManager.getChunk(chunkX, chunkY, playerX, playerY)
    -- Aplicar límites del mundo
    chunkX, chunkY = ChunkManager.enforceChunkLimits(chunkX, chunkY)
    
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    local currentTime = love.timer.getTime()
    
    -- Verificar si está en chunks activos
    if ChunkManager.state.activeChunks[chunkId] then
        local chunk = ChunkManager.state.activeChunks[chunkId]
        chunk.lastAccess = currentTime
        ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
        return chunk
    end
    
    -- Verificar si está en cache
    if ChunkManager.state.cachedChunks[chunkId] then
        local chunk = ChunkManager.state.cachedChunks[chunkId]
        chunk.lastAccess = currentTime
        
        -- Promover a activo si está completo
        if chunk.status == "complete" then
            ChunkManager.state.cachedChunks[chunkId] = nil
            ChunkManager.state.activeChunks[chunkId] = chunk
            ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
            return chunk
        end
        
        ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
        return chunk
    end
    
    -- Cache miss - necesita cargar
    ChunkManager.state.stats.cacheMisses = ChunkManager.state.stats.cacheMisses + 1
    return ChunkManager.requestChunkLoad(chunkX, chunkY, playerX, playerY)
end

-- Solicitar carga de chunk
function ChunkManager.requestChunkLoad(chunkX, chunkY, playerX, playerY)
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    
    -- Verificar si ya está en cola de carga
    for _, request in ipairs(ChunkManager.state.loadQueue) do
        if request.id == chunkId then
            return nil  -- Ya está siendo procesado
        end
    end
    
    -- Calcular prioridad
    local playerChunkX = math.floor(playerX / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local playerChunkY = math.floor(playerY / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local priority = ChunkManager.calculatePriority(chunkX, chunkY, playerChunkX, playerChunkY)
    
    -- Crear solicitud de carga
    local loadRequest = {
        id = chunkId,
        chunkX = chunkX,
        chunkY = chunkY,
        priority = priority,
        requestTime = love.timer.getTime(),
        withinLimits = ChunkManager.isChunkWithinLimits(chunkX, chunkY)
    }
    
    -- Insertar en cola de carga ordenada por prioridad
    ChunkManager.insertLoadRequest(loadRequest)
    ChunkManager.state.stats.loadRequests = ChunkManager.state.stats.loadRequests + 1
    
    return nil  -- Chunk no disponible inmediatamente
end

-- Insertar solicitud de carga manteniendo orden por prioridad
function ChunkManager.insertLoadRequest(request)
    local inserted = false
    for i, existingRequest in ipairs(ChunkManager.state.loadQueue) do
        if request.priority < existingRequest.priority then
            table.insert(ChunkManager.state.loadQueue, i, request)
            inserted = true
            break
        end
    end
    
    if not inserted then
        table.insert(ChunkManager.state.loadQueue, request)
    end
end

-- Procesar cola de carga (llamar cada frame)
function ChunkManager.processLoadQueue(dt, maxTime)
    maxTime = maxTime or ChunkManager.config.maxGenerationTime
    local startTime = love.timer.getTime()
    local processedCount = 0
    
    while #ChunkManager.state.loadQueue > 0 and (love.timer.getTime() - startTime) < maxTime do
        local request = table.remove(ChunkManager.state.loadQueue, 1)
        
        -- Verificar si el chunk aún es relevante y está dentro de límites
        if request.withinLimits and ChunkManager.isChunkRelevant(request.chunkX, request.chunkY) then
            ChunkManager.generateChunk(request.chunkX, request.chunkY)
            processedCount = processedCount + 1
        else
            -- Chunk fuera de límites o ya no relevante
            if not request.withinLimits then
                ChunkManager.state.stats.chunksOutsideLimits = ChunkManager.state.stats.chunksOutsideLimits + 1
            end
        end
        
        -- Limitar objetos procesados por frame
        if processedCount >= ChunkManager.config.maxObjectsPerFrame then
            break
        end
    end
    
    ChunkManager.state.stats.lastFrameTime = love.timer.getTime() - startTime
    return processedCount
end

-- Verificar si un chunk sigue siendo relevante
function ChunkManager.isChunkRelevant(chunkX, chunkY)
    -- Verificar límites del mundo
    if not ChunkManager.isChunkWithinLimits(chunkX, chunkY) then
        return false
    end
    
    local dx = math.abs(chunkX - ChunkManager.state.lastPlayerChunkX)
    local dy = math.abs(chunkY - ChunkManager.state.lastPlayerChunkY)
    local distance = math.max(dx, dy)
    
    return distance <= ChunkManager.config.unloadDistance
end

-- Generar chunk completamente
function ChunkManager.generateChunk(chunkX, chunkY)
    -- Aplicar límites del mundo
    chunkX, chunkY = ChunkManager.enforceChunkLimits(chunkX, chunkY)
    
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    
    -- Verificar si el chunk ya existe en caché
    if ChunkManager.state.activeChunks[chunkId] then
        return ChunkManager.state.activeChunks[chunkId]
    end
    
    local chunk = ChunkManager.getChunkFromPool()
    
    -- Configurar chunk básico
    chunk.x = chunkX
    chunk.y = chunkY
    chunk.id = chunkId
    chunk.status = "generating"
    chunk.lastAccess = love.timer.getTime()
    chunk.generated = false
    
    -- Verificar límites del mundo
    chunk.withinLimits = ChunkManager.isChunkWithinLimits(chunkX, chunkY)
    chunk.distanceToLimit = ChunkManager.getChunkDistanceToLimit(chunkX, chunkY)
    
    -- Calcular bounds
    chunk.bounds = {
        left = chunkX * ChunkManager.config.chunkSize * ChunkManager.config.tileSize,
        top = chunkY * ChunkManager.config.chunkSize * ChunkManager.config.tileSize,
        right = (chunkX + 1) * ChunkManager.config.chunkSize * ChunkManager.config.tileSize,
        bottom = (chunkY + 1) * ChunkManager.config.chunkSize * ChunkManager.config.tileSize
    }
    
    -- Verificar que los bounds estén dentro de los límites del mundo
    if not CoordinateSystem.isWithinWorldLimits(chunk.bounds.left, chunk.bounds.top) or
       not CoordinateSystem.isWithinWorldLimits(chunk.bounds.right, chunk.bounds.bottom) then
        chunk.withinLimits = false
    end
    
    -- Generar contenido del chunk (delegado al sistema existente)
    ChunkManager.generateChunkContent(chunk)
    
    -- Marcar como completo
    chunk.status = "complete"
    chunk.loadProgress = 1.0
    chunk.generated = true
    
    -- Agregar a chunks activos
    ChunkManager.state.activeChunks[chunkId] = chunk
    ChunkManager.state.stats.activeCount = ChunkManager.state.stats.activeCount + 1
    
    return chunk
end

-- Generar contenido del chunk (integración con sistema existente mejorado)
function ChunkManager.generateChunkContent(chunk)
    local Map = require 'src.maps.map'
    
    -- Si el chunk está fuera de límites, generar solo espacio vacío
    if not chunk.withinLimits then
        -- Determinar bioma como Deep Space para chunks fuera de límites
        chunk.biome = {
            type = BiomeSystem.BiomeType.DEEP_SPACE,
            name = "Deep Space",
            config = BiomeSystem.getBiomeConfig(BiomeSystem.BiomeType.DEEP_SPACE)
        }
        
        -- Generar parámetros 3D limitados
        chunk.biomeParameters = {
            energy = -0.8,
            density = -0.9,
            continentalness = -1.1,
            turbulence = 0.2,
            weirdness = 0.0,
            depth = 0.5
        }
        
        -- Inicializar tiles vacíos
        chunk.tiles = {}
        for y = 0, ChunkManager.config.chunkSize - 1 do
            chunk.tiles[y] = {}
            for x = 0, ChunkManager.config.chunkSize - 1 do
                chunk.tiles[y][x] = 0  -- Empty
            end
        end
        
        -- Objetos mínimos
        chunk.objects = {
            stars = {},
            nebulae = {}
        }
        chunk.specialObjects = {}
        
        return
    end
    
    -- Determinar bioma para este chunk usando el nuevo sistema 3D
    local biomeInfo = BiomeSystem.getBiomeInfo(chunk.x, chunk.y)
    chunk.biome = biomeInfo
    chunk.biomeParameters = biomeInfo.parameters
    
    -- Inicializar tiles
    chunk.tiles = {}
    for y = 0, ChunkManager.config.chunkSize - 1 do
        chunk.tiles[y] = {}
        for x = 0, ChunkManager.config.chunkSize - 1 do
            chunk.tiles[y][x] = 0  -- Empty by default
        end
    end
    
    -- Inicializar objetos
    chunk.objects = {
        stars = {},
        nebulae = {}
    }
    chunk.specialObjects = {}
    
    -- Generar usando el sistema existente del mapa
    local tempChunk = Map.generateChunk(chunk.x, chunk.y)
    
    -- Copiar datos generados
    chunk.tiles = tempChunk.tiles
    chunk.biome = tempChunk.biome
    
    -- Asegurar que los parámetros 3D se preserven
    if not chunk.biomeParameters and biomeInfo.parameters then
        chunk.biomeParameters = biomeInfo.parameters
    end

    -- Copiar todos los objetos generados, ya que el MapGenerator ya maneja el overlapMargin
    chunk.objects = tempChunk.objects
    chunk.specialObjects = tempChunk.specialObjects

end

-- Actualizar gestión de chunks (llamar cada frame)
function ChunkManager.update(dt, playerX, playerY)
    local startTime = love.timer.getTime()
    
    -- Aplicar límites del mundo al jugador
    playerX, playerY = CoordinateSystem.enforceWorldLimits(playerX, playerY)
    
    -- Actualizar posición del jugador
    local playerChunkX = math.floor(playerX / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local playerChunkY = math.floor(playerY / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    
    -- Aplicar límites a las coordenadas de chunk del jugador
    playerChunkX, playerChunkY = ChunkManager.enforceChunkLimits(playerChunkX, playerChunkY)
    
    -- Actualizar la posición del jugador antes de procesar la cola de carga
    ChunkManager.state.lastPlayerChunkX = playerChunkX
    ChunkManager.state.lastPlayerChunkY = playerChunkY
    
    -- Procesar cola de carga
    ChunkManager.processLoadQueue(dt)
    
    -- Procesar descargas si es necesario
    if ChunkManager.getActiveChunkCount() > ChunkManager.config.maxActiveChunks * 0.9 then
        ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
    end
    
    -- Gestión de memoria si es necesario
    if ChunkManager.getCachedChunkCount() > ChunkManager.config.maxCachedChunks * 0.9 then
        ChunkManager.cleanupCache()
    end
    
    ChunkManager.state.stats.generationTime = love.timer.getTime() - startTime
end

-- Procesar cola de descarga mejorada con consideración de límites
function ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
    local toUnload = {}
    
    -- Encontrar chunks a descargar
    for chunkId, chunk in pairs(ChunkManager.state.activeChunks) do
        local distance = math.max(
            math.abs(chunk.x - playerChunkX),
            math.abs(chunk.y - playerChunkY)
        )
        
        -- Descargar si está fuera del rango de descarga o fuera de límites del mundo
        if distance > ChunkManager.config.unloadDistance or not chunk.withinLimits then
            local priority = chunk.withinLimits and distance or distance + 100  -- Priorizar descarga de chunks fuera de límites
            table.insert(toUnload, {id = chunkId, chunk = chunk, distance = priority})
        end
    end
    
    -- Ordenar por prioridad de descarga
    table.sort(toUnload, function(a, b) return a.distance > b.distance end)
    
    -- Descargar chunks
    local unloadCount = 0
    local maxUnloads = 8  -- Aumentado para mejor gestión
    
    for _, unloadData in ipairs(toUnload) do
        if unloadCount >= maxUnloads then break end
        
        ChunkManager.unloadChunk(unloadData.id, unloadData.chunk)
        unloadCount = unloadCount + 1
    end
    
    ChunkManager.state.stats.unloadRequests = ChunkManager.state.stats.unloadRequests + unloadCount
end

-- Descargar chunk específico
function ChunkManager.unloadChunk(chunkId, chunk)
    -- Mover de activo a cache solo si está dentro de límites
    ChunkManager.state.activeChunks[chunkId] = nil
    
    if chunk.withinLimits then
        ChunkManager.state.cachedChunks[chunkId] = chunk
        chunk.status = "cached"
        ChunkManager.state.stats.cachedCount = ChunkManager.state.stats.cachedCount + 1
    else
        -- Chunks fuera de límites van directamente al pool
        ChunkManager.returnChunkToPool(chunk)
    end
    
    -- Actualizar estadísticas
    ChunkManager.state.stats.activeCount = ChunkManager.state.stats.activeCount - 1
end

-- Limpiar cache antiguo con consideración de límites
function ChunkManager.cleanupCache()
    local cacheList = {}
    
    -- Crear lista ordenada por tiempo de acceso y estado de límites
    for chunkId, chunk in pairs(ChunkManager.state.cachedChunks) do
        local priority = chunk.lastAccess
        if not chunk.withinLimits then
            priority = priority - 1000000  -- Priorizar eliminación de chunks fuera de límites
        end
        table.insert(cacheList, {id = chunkId, chunk = chunk, priority = priority})
    end
    
    table.sort(cacheList, function(a, b) return a.priority < b.priority end)
    
    -- Remover chunks más antiguos
    local removeCount = math.max(0, #cacheList - ChunkManager.config.maxCachedChunks)
    
    for i = 1, removeCount do
        local chunkData = cacheList[i]
        ChunkManager.state.cachedChunks[chunkData.id] = nil
        ChunkManager.returnChunkToPool(chunkData.chunk)
        ChunkManager.state.stats.cachedCount = ChunkManager.state.stats.cachedCount - 1
    end
end

-- Obtener chunks visibles para renderizado (mejorado con límites)
function ChunkManager.getVisibleChunks(camera)
    local visibleChunks = {}
    
    -- Calcular área visible
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local margin = 100
    local worldLeft, worldTop = camera:screenToWorld(0 - margin, 0 - margin)
    local worldRight, worldBottom = camera:screenToWorld(screenWidth + margin, screenHeight + margin)
    
    -- Aplicar límites del mundo al área visible
    worldLeft = math.max(-ChunkManager.WORLD_LIMIT, worldLeft)
    worldTop = math.max(-ChunkManager.WORLD_LIMIT, worldTop)
    worldRight = math.min(ChunkManager.WORLD_LIMIT, worldRight)
    worldBottom = math.min(ChunkManager.WORLD_LIMIT, worldBottom)
    
    local chunkStartX = math.floor(worldLeft / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local chunkStartY = math.floor(worldTop / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local chunkEndX = math.ceil(worldRight / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    local chunkEndY = math.ceil(worldBottom / (ChunkManager.config.chunkSize * ChunkManager.config.tileSize))
    
    -- Aplicar límites de chunks
    local limits = ChunkManager.state.calculatedLimits
    chunkStartX = math.max(limits.minChunkX, chunkStartX)
    chunkStartY = math.max(limits.minChunkY, chunkStartY)
    chunkEndX = math.min(limits.maxChunkX, chunkEndX)
    chunkEndY = math.min(limits.maxChunkY, chunkEndY)
    
    -- Recopilar chunks visibles
    for chunkY = chunkStartY, chunkEndY do
        for chunkX = chunkStartX, chunkEndX do
            local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
            local chunk = ChunkManager.state.activeChunks[chunkId]
            
            if chunk and chunk.status == "complete" and chunk.withinLimits then
                chunk.visible = true
                table.insert(visibleChunks, chunk)
            end
        end
    end
    
    return visibleChunks, {
        startX = chunkStartX, startY = chunkStartY,
        endX = chunkEndX, endY = chunkEndY,
        worldLeft = worldLeft, worldTop = worldTop,
        worldRight = worldRight, worldBottom = worldBottom,
        withinLimits = true
    }
end

-- Funciones de utilidad para conteo
function ChunkManager.getActiveChunkCount()
    local count = 0
    for _ in pairs(ChunkManager.state.activeChunks) do
        count = count + 1
    end
    return count
end

function ChunkManager.getCachedChunkCount()
    local count = 0
    for _ in pairs(ChunkManager.state.cachedChunks) do
        count = count + 1
    end
    return count
end

-- Obtener estadísticas del gestor (mejorado con información de límites)
function ChunkManager.getStats()
    -- Actualizar contadores actuales
    ChunkManager.state.stats.activeCount = ChunkManager.getActiveChunkCount()
    ChunkManager.state.stats.cachedCount = ChunkManager.getCachedChunkCount()
    ChunkManager.state.stats.poolCount = #ChunkManager.state.chunkPool
    
    return {
        active = ChunkManager.state.stats.activeCount,
        cached = ChunkManager.state.stats.cachedCount,
        pooled = ChunkManager.state.stats.poolCount,
        loadQueue = #ChunkManager.state.loadQueue,
        unloadQueue = #ChunkManager.state.unloadQueue,
        cacheHitRatio = ChunkManager.state.stats.cacheHits / 
                       math.max(1, ChunkManager.state.stats.cacheHits + ChunkManager.state.stats.cacheMisses),
        generationTime = ChunkManager.state.stats.generationTime,
        lastFrameTime = ChunkManager.state.stats.lastFrameTime,
        playerChunk = {
            x = ChunkManager.state.lastPlayerChunkX,
            y = ChunkManager.state.lastPlayerChunkY
        },
        worldLimits = {
            enabled = ChunkManager.config.worldLimits.enabled,
            maxSize = ChunkManager.WORLD_LIMIT,
            chunkLimits = ChunkManager.state.calculatedLimits,
            chunksOutsideLimits = ChunkManager.state.stats.chunksOutsideLimits,
            limitEnforcedChunks = ChunkManager.state.stats.limitEnforcedChunks
        }
    }
end

-- Reset estadísticas
function ChunkManager.resetStats()
    ChunkManager.state.stats = {
        activeCount = 0,
        cachedCount = 0,
        poolCount = 0,
        loadRequests = 0,
        unloadRequests = 0,
        cacheHits = 0,
        cacheMisses = 0,
        generationTime = 0,
        lastFrameTime = 0,
        chunksOutsideLimits = 0,
        limitEnforcedChunks = 0
    }
end

-- Función de limpieza completa mejorada
function ChunkManager.cleanup()
    -- Devolver todos los chunks al pool
    for chunkId, chunk in pairs(ChunkManager.state.activeChunks) do
        ChunkManager.returnChunkToPool(chunk)
    end
    
    for chunkId, chunk in pairs(ChunkManager.state.cachedChunks) do
        ChunkManager.returnChunkToPool(chunk)
    end
    
    -- Limpiar estructuras
    ChunkManager.state.activeChunks = {}
    ChunkManager.state.cachedChunks = {}
    ChunkManager.state.loadQueue = {}
    ChunkManager.state.unloadQueue = {}
    ChunkManager.state.generationQueue = {}
    
    print("ChunkManager cleanup completed (with world limits enforcement)")
end

-- Función de debug para límites del mundo
function ChunkManager.debugWorldLimits()
    local limits = ChunkManager.state.calculatedLimits
    local stats = ChunkManager.getStats()
    
    print("=== CHUNK MANAGER WORLD LIMITS DEBUG ===")
    print("World size: " .. (ChunkManager.WORLD_LIMIT * 2) .. " x " .. (ChunkManager.WORLD_LIMIT * 2) .. " units")
    print("Chunk limits: X[" .. limits.minChunkX .. " to " .. limits.maxChunkX .. "], Y[" .. limits.minChunkY .. " to " .. limits.maxChunkY .. "]")
    print("Active chunks: " .. stats.active)
    print("Cached chunks: " .. stats.cached)
    print("Chunks outside limits encountered: " .. stats.worldLimits.chunksOutsideLimits)
    print("Chunks with enforced limits: " .. stats.worldLimits.limitEnforcedChunks)
    print("Player chunk: (" .. stats.playerChunk.x .. ", " .. stats.playerChunk.y .. ")")
    
    -- Verificar si el jugador está cerca de los límites
    local playerChunkX = stats.playerChunk.x
    local playerChunkY = stats.playerChunk.y
    local distanceToLimit = ChunkManager.getChunkDistanceToLimit(playerChunkX, playerChunkY)
    
    if distanceToLimit <= ChunkManager.config.worldLimits.bufferChunks then
        print("⚠️  NEAR WORLD BOUNDARY - Distance: " .. distanceToLimit .. " chunks")
    else
        print("✓ Far from world boundaries")
    end
end

return ChunkManager