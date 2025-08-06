-- Sistema de coordenadas relativas para manejo de grandes distancias con límites

local CoordinateSystem = {}

-- LÍMITES DEL MUNDO (200k x 200k)
CoordinateSystem.WORLD_LIMIT = 200000  -- ±200,000 unidades en ambos ejes

-- Configuración del sistema
CoordinateSystem.config = {
    -- Tamaño de cada sector (en unidades del juego)
    sectorSize = 1000000,  -- 1 millón de unidades por sector
    -- Distancia máxima desde el origen antes de recalcular
    maxDistanceFromOrigin = 500000,  -- 500k unidades
    -- Precisión mínima para comparaciones
    epsilon = 0.001,
    -- Zona de amortiguamiento cerca de los límites
    bufferZone = 10000  -- 10k unidades de buffer
}

-- Estado actual del sistema
CoordinateSystem.state = {
    -- Origen actual del mundo (sector coordinates)
    originSectorX = 0,
    originSectorY = 0,
    -- Offset actual dentro del sector
    originOffsetX = 0,
    originOffsetY = 0,
    -- Contador de reubicaciones
    relocations = 0,
    -- Tiempo de la última reubicación
    lastRelocation = 0,
    -- Límites activos
    worldLimitsActive = true,
    -- Estadísticas de violaciones de límites
    limitViolations = 0
}

-- Cache de conversiones para optimización
CoordinateSystem.cache = {
    lastPlayerX = 0,
    lastPlayerY = 0,
    lastSectorX = 0,
    lastSectorY = 0,
    cacheValid = false,
    nearLimit = false,
    limitDistance = 0
}

-- Inicializar el sistema de coordenadas
function CoordinateSystem.init(playerX, playerY)
    playerX = playerX or 0
    playerY = playerY or 0
    
    -- Aplicar límites del mundo desde el inicio
    playerX, playerY = CoordinateSystem.enforceWorldLimits(playerX, playerY)
    
    -- Calcular sector inicial basado en posición del jugador
    local sectorX = math.floor(playerX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(playerY / CoordinateSystem.config.sectorSize)
    
    CoordinateSystem.state.originSectorX = sectorX
    CoordinateSystem.state.originSectorY = sectorY
    CoordinateSystem.state.originOffsetX = playerX - (sectorX * CoordinateSystem.config.sectorSize)
    CoordinateSystem.state.originOffsetY = playerY - (sectorY * CoordinateSystem.config.sectorSize)
    CoordinateSystem.state.relocations = 0
    CoordinateSystem.state.lastRelocation = love.timer.getTime()
    CoordinateSystem.state.worldLimitsActive = true
    CoordinateSystem.state.limitViolations = 0
    
    -- Invalidar cache
    CoordinateSystem.cache.cacheValid = false
    
    print("CoordinateSystem initialized with world limits:")
    print("  World size: " .. (CoordinateSystem.WORLD_LIMIT * 2) .. " x " .. (CoordinateSystem.WORLD_LIMIT * 2) .. " units")
    print("  Sector: (" .. sectorX .. ", " .. sectorY .. ")")
    print("  Origin offset: (" .. CoordinateSystem.state.originOffsetX .. ", " .. CoordinateSystem.state.originOffsetY .. ")")
    print("  Buffer zone: " .. CoordinateSystem.config.bufferZone .. " units")
end

-- Verificar si una posición está dentro de los límites del mundo
function CoordinateSystem.isWithinWorldLimits(x, y)
    return math.abs(x) <= CoordinateSystem.WORLD_LIMIT and math.abs(y) <= CoordinateSystem.WORLD_LIMIT
end

-- Calcular distancia al límite más cercano
function CoordinateSystem.getDistanceToLimit(x, y)
    local absX = math.abs(x)
    local absY = math.abs(y)
    
    local distanceX = CoordinateSystem.WORLD_LIMIT - absX
    local distanceY = CoordinateSystem.WORLD_LIMIT - absY
    
    return math.min(distanceX, distanceY)
end

-- Verificar si está cerca del límite
function CoordinateSystem.isNearLimit(x, y, threshold)
    threshold = threshold or CoordinateSystem.config.bufferZone
    return CoordinateSystem.getDistanceToLimit(x, y) <= threshold
end

-- Aplicar límites del mundo (forzar posición dentro de límites)
function CoordinateSystem.enforceWorldLimits(x, y)
    local originalX, originalY = x, y
    
    -- Aplicar límites con una pequeña tolerancia para evitar problemas de precisión
    local limit = CoordinateSystem.WORLD_LIMIT - 1
    x = math.max(-limit, math.min(limit, x))
    y = math.max(-limit, math.min(limit, y))
    
    -- Registrar violación si hubo cambio
    if x ~= originalX or y ~= originalY then
        CoordinateSystem.state.limitViolations = CoordinateSystem.state.limitViolations + 1
        
        if CoordinateSystem.state.limitViolations % 100 == 1 then  -- Log cada 100 violaciones
            print("World limit enforced. Total violations: " .. CoordinateSystem.state.limitViolations)
            print("  Original: (" .. originalX .. ", " .. originalY .. ")")
            print("  Clamped: (" .. x .. ", " .. y .. ")")
        end
    end
    
    return x, y
end

-- Convertir coordenadas del mundo a coordenadas relativas al origen actual
function CoordinateSystem.worldToRelative(worldX, worldY)
    -- Aplicar límites del mundo primero
    worldX, worldY = CoordinateSystem.enforceWorldLimits(worldX, worldY)
    
    -- Calcular sector de las coordenadas del mundo
    local sectorX = math.floor(worldX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(worldY / CoordinateSystem.config.sectorSize)
    
    -- Calcular offset dentro del sector
    local offsetX = worldX - (sectorX * CoordinateSystem.config.sectorSize)
    local offsetY = worldY - (sectorY * CoordinateSystem.config.sectorSize)
    
    -- Calcular diferencia de sectores respecto al origen
    local sectorDiffX = sectorX - CoordinateSystem.state.originSectorX
    local sectorDiffY = sectorY - CoordinateSystem.state.originSectorY
    
    -- Calcular coordenadas relativas
    local relativeX = (sectorDiffX * CoordinateSystem.config.sectorSize) + offsetX - CoordinateSystem.state.originOffsetX
    local relativeY = (sectorDiffY * CoordinateSystem.config.sectorSize) + offsetY - CoordinateSystem.state.originOffsetY
    
    return relativeX, relativeY
end

-- Convertir coordenadas relativas a coordenadas del mundo
function CoordinateSystem.relativeToWorld(relativeX, relativeY)
    -- Calcular coordenadas del mundo basadas en el origen actual
    local worldX = relativeX + CoordinateSystem.state.originOffsetX + 
                   (CoordinateSystem.state.originSectorX * CoordinateSystem.config.sectorSize)
    local worldY = relativeY + CoordinateSystem.state.originOffsetY + 
                   (CoordinateSystem.state.originSectorY * CoordinateSystem.config.sectorSize)
    
    -- Aplicar límites del mundo
    return CoordinateSystem.enforceWorldLimits(worldX, worldY)
end

-- Obtener coordenadas de sector para coordenadas del mundo
function CoordinateSystem.getSectorCoordinates(worldX, worldY)
    -- Aplicar límites primero
    worldX, worldY = CoordinateSystem.enforceWorldLimits(worldX, worldY)
    
    local sectorX = math.floor(worldX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(worldY / CoordinateSystem.config.sectorSize)
    local offsetX = worldX - (sectorX * CoordinateSystem.config.sectorSize)
    local offsetY = worldY - (sectorY * CoordinateSystem.config.sectorSize)
    
    return sectorX, sectorY, offsetX, offsetY
end

-- Verificar si es necesario reubicar el origen
function CoordinateSystem.needsRelocation(playerX, playerY)
    -- Aplicar límites del mundo primero
    playerX, playerY = CoordinateSystem.enforceWorldLimits(playerX, playerY)
    
    local relativeX, relativeY = CoordinateSystem.worldToRelative(playerX, playerY)
    local distance = math.sqrt(relativeX * relativeX + relativeY * relativeY)
    
    return distance > CoordinateSystem.config.maxDistanceFromOrigin
end

-- Reubicar el origen del sistema de coordenadas
function CoordinateSystem.relocateOrigin(newPlayerX, newPlayerY, callback)
    -- Aplicar límites del mundo
    newPlayerX, newPlayerY = CoordinateSystem.enforceWorldLimits(newPlayerX, newPlayerY)
    
    local oldSectorX = CoordinateSystem.state.originSectorX
    local oldSectorY = CoordinateSystem.state.originSectorY
    local oldOffsetX = CoordinateSystem.state.originOffsetX
    local oldOffsetY = CoordinateSystem.state.originOffsetY
    
    -- Calcular nuevo sector basado en posición del jugador
    local newSectorX = math.floor(newPlayerX / CoordinateSystem.config.sectorSize)
    local newSectorY = math.floor(newPlayerY / CoordinateSystem.config.sectorSize)
    
    -- Calcular nuevo offset
    local newOffsetX = newPlayerX - (newSectorX * CoordinateSystem.config.sectorSize)
    local newOffsetY = newPlayerY - (newSectorY * CoordinateSystem.config.sectorSize)
    
    -- Actualizar estado
    CoordinateSystem.state.originSectorX = newSectorX
    CoordinateSystem.state.originSectorY = newSectorY
    CoordinateSystem.state.originOffsetX = newOffsetX
    CoordinateSystem.state.originOffsetY = newOffsetY
    CoordinateSystem.state.relocations = CoordinateSystem.state.relocations + 1
    CoordinateSystem.state.lastRelocation = love.timer.getTime()
    
    -- Invalidar cache
    CoordinateSystem.cache.cacheValid = false
    
    print("Origin relocated to sector (" .. newSectorX .. ", " .. newSectorY .. ") with offset (" .. newOffsetX .. ", " .. newOffsetY .. ")")
    
    -- Ejecutar callback si se proporciona
    if callback then
        callback(oldSectorX, oldSectorY, newSectorX, newSectorY)
    end
end

-- Actualizar el sistema de coordenadas (llamado cada frame)
function CoordinateSystem.update(dt, playerX, playerY)
    -- Actualizar cache de posición del jugador
    CoordinateSystem.cache.lastPlayerX = playerX
    CoordinateSystem.cache.lastPlayerY = playerY
    
    -- Verificar si es necesario reubicar el origen
    if CoordinateSystem.needsRelocation(playerX, playerY) then
        CoordinateSystem.relocateOrigin(playerX, playerY)
    end
    
    -- Actualizar estado de cercanía a los límites
    CoordinateSystem.cache.nearLimit = CoordinateSystem.isNearLimit(playerX, playerY)
    CoordinateSystem.cache.limitDistance = CoordinateSystem.getDistanceToLimit(playerX, playerY)
    CoordinateSystem.cache.cacheValid = true
end

-- Obtener información del estado actual del sistema de coordenadas
function CoordinateSystem.getStats()
    return {
        originSectorX = CoordinateSystem.state.originSectorX,
        originSectorY = CoordinateSystem.state.originSectorY,
        originOffsetX = CoordinateSystem.state.originOffsetX,
        originOffsetY = CoordinateSystem.state.originOffsetY,
        relocations = CoordinateSystem.state.relocations,
        lastRelocationTime = CoordinateSystem.state.lastRelocation,
        worldLimitsActive = CoordinateSystem.state.worldLimitsActive,
        limitViolations = CoordinateSystem.state.limitViolations,
        isNearLimit = CoordinateSystem.cache.nearLimit,
        distanceToLimit = CoordinateSystem.cache.limitDistance
    }
end

return CoordinateSystem