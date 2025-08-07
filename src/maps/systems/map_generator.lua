-- src/maps/systems/map_generator.lua (ADAPTADO PARA SISTEMA 3D CON LÍMITES DEL MUNDO)
-- Sistema de generación de contenido del mapa con soporte 3D y límites del mundo

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local CoordinateSystem = require 'src.maps.coordinate_system'
local MapConfig = require 'src.maps.config.map_config'

-- LÍMITES DEL MUNDO
MapGenerator.WORLD_LIMIT = 200000  -- ±200,000 unidades

-- Configuración de generación 3D
MapGenerator.config = {
    -- Escalas de ruido 3D optimizadas
    noise3D = {
        asteroids = {
            scale = 0.025,
            octaves = 4,
            persistence = 0.6,
            heightInfluence = 0.3  -- Cuánto influye la altura falsa
        },
        nebulae = {
            scale = 0.035,
            octaves = 3,
            persistence = 0.7,
            heightInfluence = 0.5
        },
        stars = {
            scale = 0.02,
            octaves = 5,
            persistence = 0.4,
            heightInfluence = 0.2
        },
        specialObjects = {
            scale = 0.08,
            octaves = 2,
            persistence = 0.8,
            heightInfluence = 0.7
        }
    },
    
    -- Modificadores basados en parámetros 3D
    parameterInfluence = {
        energy = 0.4,        -- Influencia de la energía espacial
        density = 0.6,       -- Influencia de la densidad de materia
        turbulence = 0.3,    -- Influencia de la turbulencia
        weirdness = 0.5,     -- Influencia de las anomalías
        continentalness = 0.2 -- Influencia de la continentalidad
    },
    
    -- Configuración de límites
    worldLimits = {
        enabled = true,
        fadeDistance = 5000,  -- Distancia para empezar a reducir objetos
        minObjectDensity = 0.1, -- Densidad mínima cerca de límites
        boundaryEffect = true   -- Efectos especiales en los límites
    }
}

-- Verificar si una posición está dentro de los límites del mundo
function MapGenerator.isWithinWorldLimits(worldX, worldY)
    return math.abs(worldX) <= MapGenerator.WORLD_LIMIT and math.abs(worldY) <= MapGenerator.WORLD_LIMIT
end

-- Calcular factor de atenuación basado en distancia a límites del mundo
function MapGenerator.calculateLimitFadeFactor(worldX, worldY)
    if not MapGenerator.config.worldLimits.enabled then
        return 1.0
    end
    
    local distanceToLimit = math.min(
        MapGenerator.WORLD_LIMIT - math.abs(worldX),
        MapGenerator.WORLD_LIMIT - math.abs(worldY)
    )
    
    if distanceToLimit <= 0 then
        return 0.0  -- Fuera de límites
    end
    
    if distanceToLimit >= MapGenerator.config.worldLimits.fadeDistance then
        return 1.0  -- Lejos de límites
    end
    
    -- Interpolación suave hacia los límites
    local fadeFactor = distanceToLimit / MapGenerator.config.worldLimits.fadeDistance
    return math.max(MapGenerator.config.worldLimits.minObjectDensity, fadeFactor)
end

-- Función de ruido multi-octava 3D mejorada
function MapGenerator.multiOctaveNoise3D(x, y, z, octaves, persistence, scale, heightInfluence)
    octaves = octaves or 4
    persistence = persistence or 0.5
    scale = scale or 1.0
    heightInfluence = heightInfluence or 0.3
    
    local value = 0
    local amplitude = 1
    local frequency = scale
    local maxValue = 0
    
    -- Aplicar influencia de altura falsa
    local adjustedZ = z * heightInfluence
    
    for i = 1, octaves do
        value = value + PerlinNoise.noise(x * frequency, y * frequency, adjustedZ * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    
    return value / maxValue
end

-- Generar asteroides con sistema 3D y límites del mundo
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities)
    local asteroids = {}
    local asteroidCount = 0
    local biomeParams = chunk.biomeParameters
    local falseHeight = biomeParams.depth or 0.5
    
    -- Obtener los límites de generación expandidos del chunk
    local overlapMargin = MapConfig.chunk.tileSize * 6 -- Aumentado para mayor superposición
    local genLeft = chunk.bounds.left - overlapMargin
    local genTop = chunk.bounds.top - overlapMargin
    local genRight = chunk.bounds.right + overlapMargin
    local genBottom = chunk.bounds.bottom + overlapMargin

    -- Iterar sobre cada tile dentro de los límites expandidos
    for y = math.floor(genTop / MapConfig.chunk.tileSize), math.ceil(genBottom / MapConfig.chunk.tileSize) - 1 do
        for x = math.floor(genLeft / MapConfig.chunk.tileSize), math.ceil(genRight / MapConfig.chunk.tileSize) - 1 do
            local tileWorldX = x * MapConfig.chunk.tileSize
            local tileWorldY = y * MapConfig.chunk.tileSize
            
            local globalX = tileWorldX * MapGenerator.config.noise3D.asteroids.scale
            local globalY = tileWorldY * MapGenerator.config.noise3D.asteroids.scale
            
            if not MapGenerator.isWithinWorldLimits(tileWorldX, tileWorldY) then
                goto continue_asteroid_tile
            end
            
            -- Factor de atenuación por proximidad a límites del mundo
            local limitFadeFactor = MapGenerator.calculateLimitFadeFactor(tileWorldX, tileWorldY)
            
            -- Generar ruido 3D para asteroides
            local noiseConfig = MapGenerator.config.noise3D.asteroids
            local noiseMain = MapGenerator.multiOctaveNoise3D(
                globalX, globalY, falseHeight, 
                noiseConfig.octaves, noiseConfig.persistence, noiseConfig.scale, noiseConfig.heightInfluence
            )
            
            local noiseDetail = PerlinNoise.noise(globalX * 0.12, globalY * 0.12, falseHeight * 2.0)
            local combinedNoise = (noiseMain * 0.7 + noiseDetail * 0.3)
            
            -- Modificar ruido basado en parámetros 3D del bioma
            local energyMod = 1.0 + biomeParams.energy * MapGenerator.config.parameterInfluence.energy
            local densityMod = 1.0 + biomeParams.density * MapGenerator.config.parameterInfluence.density
            local turbulenceMod = 1.0 + math.abs(biomeParams.turbulence) * MapGenerator.config.parameterInfluence.turbulence
            
            combinedNoise = combinedNoise * energyMod * densityMod * turbulenceMod
            
            -- Aplicar factor de límites del mundo, ajustado para la superposición
            local effectiveFadeFactor = 1.0
            if tileWorldX < chunk.bounds.left + overlapMargin or tileWorldX >= chunk.bounds.right - overlapMargin or
               tileWorldY < chunk.bounds.top + overlapMargin or tileWorldY >= chunk.bounds.bottom - overlapMargin then
                effectiveFadeFactor = 0.8 + (limitFadeFactor * 0.2) -- Menos restrictivo en la superposición
            else
                effectiveFadeFactor = limitFadeFactor
            end
            combinedNoise = combinedNoise * effectiveFadeFactor
            
            -- Calcular thresholds basados en el tipo de bioma
            local threshold = 0.20
            if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
                threshold = 0.10  -- Más asteroides en cinturones
                combinedNoise = combinedNoise * 1.4
            elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
                threshold = 0.28  -- Menos asteroides en espacio profundo
                combinedNoise = combinedNoise * 0.8
            elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                threshold = 0.35  -- Pocos asteroides en nebulosas
            elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                threshold = 0.15  -- Más asteroides por gravedad
                combinedNoise = combinedNoise * 1.2
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                threshold = 0.40  -- Muy pocos por radiación
            elseif chunk.biome.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
                threshold = 0.45  -- Muy pocos asteroides
            end
            
            -- Aplicar influencia de altura falsa a los thresholds
            local depthMod = 1.0 + (falseHeight - 0.5) * 0.3  -- Más asteroides en alturas medias
            threshold = threshold / depthMod
            
            -- Generar asteroides basado en threshold
            if combinedNoise > threshold then
                local asteroidTypeRoll = math.random(1, 100)
                local asteroidType = MapConfig.ObjectType.ASTEROID_SMALL
                local size = 0
                
                if asteroidTypeRoll <= 60 then
                    asteroidType = MapConfig.ObjectType.ASTEROID_SMALL
                    size = math.random(5, 10) * MapConfig.chunk.worldScale
                elseif asteroidTypeRoll <= 90 then
                    asteroidType = MapConfig.ObjectType.ASTEROID_MEDIUM
                    size = math.random(10, 20) * MapConfig.chunk.worldScale
                else
                    asteroidType = MapConfig.ObjectType.ASTEROID_LARGE
                    size = math.random(20, 40) * MapConfig.chunk.worldScale
                end
                
                -- Ajustar tamaño por effectiveFadeFactor
                size = size * (0.5 + effectiveFadeFactor * 0.5) -- Más pequeños cerca de los límites
                
                local asteroid = {
                    type = asteroidType,
                    x = tileWorldX + MapConfig.chunk.tileSize / 2,
                    y = tileWorldY + MapConfig.chunk.tileSize / 2,
                    size = size,
                    rotation = math.random() * math.pi * 2,
                    rotationSpeed = (math.random() - 0.5) * 0.05,
                    color = MapConfig.colors.asteroids[math.random(1, #MapConfig.colors.asteroids)],
                    biomeType = chunk.biome.type,
                    biomeParameters = biomeParams,
                    falseHeight = falseHeight
                }
                
                table.insert(asteroids, asteroid)
                asteroidCount = asteroidCount + 1
                -- No asignar a chunk.tiles[y][x] aquí, ya que 'y' y 'x' no son índices de chunk
            end
            
            ::continue_asteroid_tile::
        end
    end
    
    chunk.objects.asteroids = asteroids
    chunk.objectCount = (chunk.objectCount or 0) + asteroidCount
end

-- Generar nebulosas con sistema 3D y límites del mundo
function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities)
    local nebulaDensity = densities.nebulae or MapConfig.density.nebulae
    local nebulaObjects = {}
    local nebulaCount = 0
    local nebulaDensity = densities.nebulae or MapConfig.density.nebulae
    local nebulaObjects = {}
    
    -- Obtener parámetros 3D del bioma
    local biomeParams = chunk.biomeParameters or BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local falseHeight = biomeParams.depth or 0.5
    
    -- Obtener los límites de generación expandidos del chunk
    local overlapMargin = MapConfig.chunk.tileSize * 2 -- Reduced overlap for performance
    local genLeft = chunk.bounds.left - overlapMargin
    local genTop = chunk.bounds.top - overlapMargin
    local genRight = chunk.bounds.right + overlapMargin
    local genBottom = chunk.bounds.bottom + overlapMargin

    -- Calcular posición mundial del chunk (centro para biome y limitFadeFactor)
    local chunkWorldX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize
    local chunkWorldY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize
    
    -- Verificar límites del mundo
    if not MapGenerator.isWithinWorldLimits(chunkWorldX, chunkWorldY) then
        chunk.objects.nebulae = {}
        return
    end
    
    -- Factor de atenuación por proximidad a límites
    local limitFadeFactor = MapGenerator.calculateLimitFadeFactor(chunkWorldX, chunkWorldY)
    
    local baseNumNebulae = math.max(1, math.floor(nebulaDensity * 0.8 * limitFadeFactor))
    local maxNebulae = math.floor(8 * limitFadeFactor)
    
    local numNebulae
    if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numNebulae = math.min(2, baseNumNebulae)
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 5)
    elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 3)
    elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        numNebulae = math.min(5, baseNumNebulae * 2)
    else
        numNebulae = math.min(4, baseNumNebulae)
    end
    
    for i = 1, numNebulae do
        -- Generar posición aleatoria dentro de los límites expandidos del chunk
        local x = math.random(genLeft, genRight - 1)
        local y = math.random(genTop, genBottom - 1)
        
        -- Convertir a coordenadas mundiales para verificar límites
        local nebulaWorldX = x
        local nebulaWorldY = y
        
        if not MapGenerator.isWithinWorldLimits(nebulaWorldX, nebulaWorldY) then
            goto continue_nebula
        end
        
        -- Calcular un factor de atenuación local para nebulosas individuales
        local localLimitFadeFactor = MapGenerator.calculateLimitFadeFactor(nebulaWorldX, nebulaWorldY)
        local effectiveFadeFactor = 1.0
        if nebulaWorldX < chunk.bounds.left + overlapMargin or nebulaWorldX >= chunk.bounds.right - overlapMargin or
           nebulaWorldY < chunk.bounds.top + overlapMargin or nebulaWorldY >= chunk.bounds.bottom - overlapMargin then
            effectiveFadeFactor = 0.8 + (localLimitFadeFactor * 0.2) -- Menos restrictivo en la superposición
        else
            effectiveFadeFactor = localLimitFadeFactor
        end

        if math.random() > effectiveFadeFactor then
            goto continue_nebula
        end

        -- Generar ruido 3D para nebulosas
        local noiseConfig = MapGenerator.config.noise3D.nebulae
        local nebulaChance = MapGenerator.multiOctaveNoise3D(
            nebulaWorldX / MapConfig.chunk.tileSize, nebulaWorldY / MapConfig.chunk.tileSize, falseHeight,            noiseConfig.octaves, noiseConfig.persistence, noiseConfig.scale, noiseConfig.heightInfluence
        )
        
        -- Modificar por parámetros 3D
        local energyMod = 1.0 + biomeParams.energy * 0.3
        local densityMod = 1.0 + biomeParams.density * 0.5
        local weirdnessMod = 1.0 + math.abs(biomeParams.weirdness) * 0.4
        
        nebulaChance = nebulaChance * energyMod * densityMod * weirdnessMod * limitFadeFactor
        
        local threshold = 0.25
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            threshold = 0.02  -- Muchas nebulosas
        elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
            threshold = 0.40  -- Pocas nebulosas
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            threshold = 0.12  -- Nebulosas radioactivas
        elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
            threshold = 0.18  -- Nebulosas distorsionadas
        end
        
        -- Aplicar influencia de altura falsa
        local depthBonus = falseHeight > 0.3 and falseHeight < 0.7 and 1.3 or 1.0
        threshold = threshold / depthBonus
        
        local shouldGenerate = false
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.5 * limitFadeFactor)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.3 * limitFadeFactor)
        else
            shouldGenerate = nebulaChance > threshold
        end
        
        if shouldGenerate then
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                size = math.random(60, 160) * MapConfig.chunk.worldScale * limitFadeFactor,
                color = MapConfig.colors.nebulae[math.random(1, #MapConfig.colors.nebulae)],
                intensity = math.random(25, 60) / 100 * limitFadeFactor,
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY,
                falseHeight = falseHeight,
                biomeParameters = biomeParams
            }
            
            -- Modificaciones específicas por bioma usando parámetros 3D
            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * (1.2 + biomeParams.density * 0.3)
                nebula.intensity = nebula.intensity * (1.1 + biomeParams.energy * 0.4)
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * (0.9 + biomeParams.turbulence * 0.4)
                nebula.intensity = nebula.intensity * (1.3 + biomeParams.energy * 0.5)
                nebula.color = {0.8 + biomeParams.energy * 0.2, 0.6, 0.1 + biomeParams.weirdness * 0.1, 0.6}
            elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                -- Nebulosas distorsionadas por gravedad
                nebula.size = nebula.size * (0.8 + math.abs(biomeParams.weirdness) * 0.6)
                nebula.color = {0.4, 0.2 + biomeParams.weirdness * 0.3, 0.8, 0.5}
                nebula.distorted = true
                nebula.distortionStrength = math.abs(biomeParams.weirdness)
            end
            
            table.insert(nebulaObjects, nebula)
            nebulaCount = nebulaCount + 1
        end
        
        ::continue_nebula::
    end
    
    chunk.objects.nebulae = nebulaObjects
    chunk.objectCount = (chunk.objectCount or 0) + nebulaCount
end

-- Generar objetos especiales con sistema 3D y límites del mundo
function MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, densities)
    chunk.specialObjects = {}
    
    -- Obtener los límites de generación expandidos del chunk
    local overlapMargin = MapConfig.chunk.tileSize * 2 -- Debe coincidir con el margen en generateChunk
    local genLeft = chunk.bounds.left - overlapMargin
    local genTop = chunk.bounds.top - overlapMargin
    local genRight = chunk.bounds.right + overlapMargin
    local genBottom = chunk.bounds.bottom + overlapMargin

    -- Calcular posición mundial del chunk (centro para biome y limitFadeFactor)
    local chunkWorldX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize
    local chunkWorldY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize
    
    -- Verificar límites del mundo
    if not MapGenerator.isWithinWorldLimits(chunkWorldX, chunkWorldY) then
        return
    end
    
    -- Factor de atenuación por proximidad a límites
    local limitFadeFactor = MapGenerator.calculateLimitFadeFactor(chunkWorldX, chunkWorldY)
    
    local stationDensity = (densities.stations or MapConfig.density.stations) * limitFadeFactor
    local wormholeDensity = (densities.wormholes or MapConfig.density.wormholes) * limitFadeFactor
    
    -- Obtener parámetros 3D del bioma
    local biomeParams = chunk.biomeParameters or BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    -- Modificar densidades por parámetros 3D
    local continentalnessBonus = biomeParams.continentalness > 0.3 and 1.5 or 1.0
    local weirdnessBonus = math.abs(biomeParams.weirdness) > 0.5 and 2.0 or 1.0
    
    stationDensity = stationDensity * continentalnessBonus
    wormholeDensity = wormholeDensity * weirdnessBonus
    
    -- Generar estación
    if math.random() < stationDensity then
        local effectiveFadeFactor = 1.0
        local x, y

        -- Generar posición dentro de los límites expandidos
        x = math.random(genLeft, genRight)
        y = math.random(genTop, genBottom)

        -- Calcular effectiveFadeFactor basado en la posición dentro del overlapMargin
        local distToEdgeX = math.min(x - chunk.bounds.left, chunk.bounds.right - x)
        local distToEdgeY = math.min(y - chunk.bounds.top, chunk.bounds.bottom - y)
        local minDistToEdge = math.min(distToEdgeX, distToEdgeY)

        if minDistToEdge < overlapMargin then
            -- Atenuar el efecto del limitFadeFactor cerca de los bordes del chunk original
            local fadeInfluence = minDistToEdge / overlapMargin
            effectiveFadeFactor = limitFadeFactor * fadeInfluence + (1 - fadeInfluence) -- Transición suave
        else
            effectiveFadeFactor = limitFadeFactor
        end

        local station = {
            type = MapConfig.ObjectType.STATION,
            x = x,
            y = y,
            size = math.random(18, 40) * MapConfig.chunk.worldScale * (0.8 + effectiveFadeFactor * 0.4),
            rotation = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type,
            biomeParameters = biomeParams,
            falseHeight = biomeParams.depth or 0.5
        }
        
        -- Modificaciones basadas en parámetros 3D
        if biomeParams.energy > 0.5 then
            station.powerLevel = "high"
            station.size = station.size * 1.2
        elseif biomeParams.energy < -0.5 then
            station.powerLevel = "low"
            station.active = math.random() < 0.7  -- Algunas estaciones inactivas
        end
        
        if biomeParams.weirdness > 0.7 then
            station.anomalous = true
            station.effects = {"gravity_distortion", "time_dilation"}
        end
        
        table.insert(chunk.specialObjects, station)
    end
    
    -- Generar agujero de gusano
    if math.random() < wormholeDensity then
        local effectiveFadeFactor = 1.0
        local x, y

        -- Generar posición dentro de los límites expandidos
        x = math.random(genLeft, genRight)
        y = math.random(genTop, genBottom)

        -- Calcular effectiveFadeFactor basado en la posición dentro del overlapMargin
        local distToEdgeX = math.min(x - chunk.bounds.left, chunk.bounds.right - x)
        local distToEdgeY = math.min(y - chunk.bounds.top, chunk.bounds.bottom - y)
        local minDistToEdge = math.min(distToEdgeX, distToEdgeY)

        if minDistToEdge < overlapMargin then
            -- Atenuar el efecto del limitFadeFactor cerca de los bordes del chunk original
            local fadeInfluence = minDistToEdge / overlapMargin
            effectiveFadeFactor = limitFadeFactor * fadeInfluence + (1 - fadeInfluence) -- Transición suave
        else
            effectiveFadeFactor = limitFadeFactor
        end

        local wormhole = {
            type = MapConfig.ObjectType.WORMHOLE,
            x = x,
            y = y,
            size = math.random(15, 25) * MapConfig.chunk.worldScale * effectiveFadeFactor,
            pulsePhase = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type,
            biomeParameters = biomeParams,
            falseHeight = biomeParams.depth or 0.5
        }
        
        -- Modificaciones basadas en parámetros 3D
        local stabilityFactor = 1.0 - math.abs(biomeParams.turbulence) * 0.5
        wormhole.stability = math.max(0.1, stabilityFactor)
        
        if biomeParams.weirdness > 0.5 then
            wormhole.size = wormhole.size * (1.0 + biomeParams.weirdness)
            wormhole.unstable = biomeParams.weirdness > 0.8
        end
        
        if biomeParams.depth < 0.2 or biomeParams.depth > 0.8 then
            wormhole.dimensional = true  -- Agujeros de gusano dimensionales en alturas extremas
        end
        
        table.insert(chunk.specialObjects, wormhole)
    end
end

-- Generar estrellas con sistema 3D y límites del mundo
function MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities)
    local starCount = 0
    local stars = {}
    
    -- Obtener los límites de generación expandidos del chunk
    local overlapMargin = MapConfig.chunk.tileSize * 6 -- Debe coincidir con el margen en generateChunk
    local genLeft = chunk.bounds.left - overlapMargin
    local genTop = chunk.bounds.top - overlapMargin
    local genRight = chunk.bounds.right + overlapMargin
    local genBottom = chunk.bounds.bottom + overlapMargin

    -- Calcular posición mundial del chunk (centro para biome y limitFadeFactor)
    local chunkWorldX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize
    local chunkWorldY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize
    
    -- Verificar límites del mundo
    if not MapGenerator.isWithinWorldLimits(chunkWorldX, chunkWorldY) then
        chunk.objects.stars = {}
        return
    end
    
    -- Factor de atenuación por proximidad a límites
    local limitFadeFactor = MapGenerator.calculateLimitFadeFactor(chunkWorldX, chunkWorldY)
    
    local starDensity = (densities.stars or MapConfig.density.stars) * limitFadeFactor
    local baseNumStars = math.floor(MapConfig.chunk.size * MapConfig.chunk.size * starDensity * 0.2)
    
    -- Obtener parámetros 3D del bioma
    local biomeParams = chunk.biomeParameters or BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local falseHeight = biomeParams.depth or 0.5
    
    -- Modificar densidad de estrellas por parámetros 3D
    local energyMultiplier = 1.0 + biomeParams.energy * 0.5  -- Más estrellas con más energía
    local densityMultiplier = 1.0 + biomeParams.density * 0.3
    
    local numStars = baseNumStars * energyMultiplier * densityMultiplier
    
    if chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numStars = numStars * 3.5  -- Muchas estrellas radioactivas
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numStars = numStars * 2.4  -- Estrellas nacientes en nebulosas
    elseif chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        numStars = numStars * 1.6  -- Menos estrellas por asteroides
    elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numStars = numStars * 2.8  -- Muchas estrellas en espacio profundo
    elseif chunk.biome.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
        numStars = numStars * 1.8  -- Estrellas antiguas
    elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        numStars = numStars * 2.1  -- Estrellas distorsionadas
    end
    
    -- Distribución usando ruido 3D para patrones más naturales
    local sectorsPerSide = 6
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(numStars / (sectorsPerSide * sectorsPerSide))
    
    -- Generar estrellas por sector usando ruido 3D
    for sectorY = 0, sectorsPerSide - 1 do
        for sectorX = 0, sectorsPerSide - 1 do
            -- Calcular las coordenadas mundiales del centro del sector para el ruido
            local sectorWorldX = chunkWorldX + sectorX * sectorSize + sectorSize / 2
            local sectorWorldY = chunkWorldY + sectorY * sectorSize + sectorSize / 2
            
            -- Usar ruido 3D para variar densidad por sector
            local noiseConfig = MapGenerator.config.noise3D.stars
            local sectorNoise = MapGenerator.multiOctaveNoise3D(
                sectorWorldX * noiseConfig.scale,
                sectorWorldY * noiseConfig.scale,
                falseHeight * noiseConfig.heightInfluence,
                noiseConfig.octaves, noiseConfig.persistence, noiseConfig.scale, noiseConfig.heightInfluence
            )
            
            local sectorStars = math.floor(starsPerSector * (1.0 + sectorNoise * 0.5))
            
            if math.random() < 0.4 then
                sectorStars = sectorStars + math.random(1, 4)  -- Variación adicional
            end
            
            for i = 1, sectorStars do
                -- Generar posición aleatoria dentro de los límites expandidos del chunk
                local x = math.random(genLeft, genRight - 1) - chunk.bounds.left
                local y = math.random(genTop, genBottom - 1) - chunk.bounds.top
                
                -- Convertir a coordenadas mundiales para verificar límites
                local starWorldX = chunk.bounds.left + x
                local starWorldY = chunk.bounds.top + y
                
                if not MapGenerator.isWithinWorldLimits(starWorldX, starWorldY) then
                    goto continue_star
                end
                
                -- Ajustar la aplicación de limitFadeFactor para reducir vacíos en los bordes
                local localLimitFadeFactor = MapGenerator.calculateLimitFadeFactor(starWorldX, starWorldY)
                -- Reducir el impacto del fade factor en las zonas de superposición
                local effectiveFadeFactor = 1.0
                if starWorldX < chunk.bounds.left + overlapMargin or starWorldX >= chunk.bounds.right - overlapMargin or
                   starWorldY < chunk.bounds.top + overlapMargin or starWorldY >= chunk.bounds.bottom - overlapMargin then
                    -- En la zona de superposición, el fade factor es menos restrictivo
                    effectiveFadeFactor = 0.8 + (localLimitFadeFactor * 0.2)
                else
                    effectiveFadeFactor = localLimitFadeFactor
                end

                if math.random() > effectiveFadeFactor then
                    goto continue_star
                end
                
                -- Determinar tipo de estrella basado en parámetros 3D y altura falsa
                local starTypeRoll = math.random(1, 100)
                local starType
                
                -- Modificar probabilidades por parámetros 3D
                if biomeParams.energy > 0.5 then
                    starTypeRoll = starTypeRoll + 20  -- Más estrellas brillantes
                elseif biomeParams.energy < -0.5 then
                    starTypeRoll = starTypeRoll - 15  -- Más estrellas tenues
                end
                
                if biomeParams.weirdness > 0.7 then
                    starTypeRoll = starTypeRoll + 30  -- Estrellas más exóticas
                end
                
                -- Influencia de altura falsa en tipos de estrella
                if falseHeight > 0.8 then
                    starTypeRoll = starTypeRoll + 25  -- Estrellas de gran altitud
                elseif falseHeight < 0.2 then
                    starTypeRoll = starTypeRoll - 10  -- Estrellas de baja altitud
                end
                
                if starTypeRoll <= 25 then
                    starType = 1
                elseif starTypeRoll <= 45 then
                    starType = 2
                elseif starTypeRoll <= 65 then
                    starType = 3
                elseif starTypeRoll <= 80 then
                    starType = 4
                elseif starTypeRoll <= 95 then
                    starType = 5
                else
                    starType = 6
                end
                
                -- Configuraciones de estrella basadas en tipo y parámetros 3D
                local starConfigs = {
                    [1] = {size = math.random(1, 2), depth = math.random(0.85, 0.95)},
                    [2] = {size = math.random(2, 3), depth = math.random(0.7, 0.85)},
                    [3] = {size = math.random(3, 4), depth = math.random(0.5, 0.7)},
                    [4] = {size = math.random(3, 5), depth = math.random(0.3, 0.5)},
                    [5] = {size = math.random(4, 6), depth = math.random(0.15, 0.3)},
                    [6] = {size = math.random(5, 8), depth = math.random(0.05, 0.15)}
                }
                
                local config = starConfigs[starType]
                local star = {
                    x = x,
                    y = y,
                    size = config.size * limitFadeFactor,
                    type = starType,
                    color = MapConfig.colors.stars[math.random(1, #MapConfig.colors.stars)],
                    twinkle = math.random() * math.pi * 2,
                    twinkleSpeed = math.random(0.5, 3.0),
                    depth = config.depth,
                    brightness = math.random(0.8, 1.2) * limitFadeFactor,
                    pulsePhase = math.random() * math.pi * 2,
                    biomeType = chunk.biome.type,
                    biomeParameters = biomeParams,
                    falseHeight = falseHeight
                }
                
                -- Modificaciones específicas por parámetros 3D
                if biomeParams.energy > 0.5 then
                    star.brightness = star.brightness * (1.0 + biomeParams.energy * 0.3)
                    star.energetic = true
                end
                
                if biomeParams.weirdness > 0.7 then
                    star.anomalous = true
                    star.color = {
                        star.color[1] * (1.0 + biomeParams.weirdness * 0.2),
                        star.color[2],
                        star.color[3] * (1.0 + biomeParams.weirdness * 0.3),
                        star.color[4]
                    }
                end
                
                if chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                    star.radioactive = true
                    star.radiationLevel = biomeParams.energy > 0 and "high" or "medium"
                elseif chunk.biome.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
                    star.ancient = true
                    star.age = "old"
                end
                
                table.insert(stars, star)
                starCount = starCount + 1
                
                ::continue_star::  
            end
        end
    end
    
    chunk.objects.stars = stars
    chunk.objectCount = (chunk.objectCount or 0) + starCount
end

-- Generar chunk completo con sistema 3D y límites del mundo
function MapGenerator.generateChunk(chunkX, chunkY)
    local chunk = {
        x = chunkX,
        y = chunkY,
        tiles = {},
        objects = {stars = {}, nebulae = {}},
        specialObjects = {},
        bounds = {
            left = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize,
            top = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize,
            right = (chunkX + 1) * MapConfig.chunk.size * MapConfig.chunk.tileSize,
            bottom = (chunkY + 1) * MapConfig.chunk.size * MapConfig.chunk.tileSize
        }
    }
    
    -- Definir un margen de superposición para la generación de objetos
    local overlapMargin = MapConfig.chunk.tileSize * 2 -- Por ejemplo, 2 tiles de superposición

    -- Calcular los límites de generación expandidos
    local genLeft = chunk.bounds.left - overlapMargin
    local genTop = chunk.bounds.top - overlapMargin
    local genRight = chunk.bounds.right + overlapMargin
    local genBottom = chunk.bounds.bottom + overlapMargin

    -- Verificar límites del mundo para el centro del chunk
    local chunkWorldX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize
    local chunkWorldY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize
    
    if not MapGenerator.isWithinWorldLimits(chunkWorldX, chunkWorldY) then
        -- Chunk fuera de límites - generar contenido mínimo
        chunk.biome = {
            type = BiomeSystem.BiomeType.DEEP_SPACE,
            name = "Deep Space",
            config = BiomeSystem.getBiomeConfig(BiomeSystem.BiomeType.DEEP_SPACE)
        }
        
        chunk.biomeParameters = {
            energy = -0.8,
            density = -0.9,
            continentalness = -1.1,
            turbulence = 0.1,
            weirdness = 0.0,
            depth = 0.5
        }
        
        -- Inicializar tiles vacíos
        for y = 0, MapConfig.chunk.size - 1 do
            chunk.tiles[y] = {}
            for x = 0, MapConfig.chunk.size - 1 do
                chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
            end
        end
        
        return chunk
    end
    
    -- Determinar bioma usando el sistema 3D mejorado
    local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
    chunk.biome = biomeInfo
    chunk.biomeParameters = biomeInfo.parameters
    
    -- Inicializar tiles
    for y = 0, MapConfig.chunk.size - 1 do
        chunk.tiles[y] = {}
        for x = 0, MapConfig.chunk.size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end
    
    -- Generar contenido usando densidades modificadas por bioma y parámetros 3D
    local modifiedDensities = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)
    
    MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modifiedDensities)
    
    -- Generar características especiales usando el sistema 3D
    BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)
    
    return chunk
end

-- Función de debug para el generador 3D
function MapGenerator.debugGeneration3D(chunkX, chunkY)
    local biomeParams = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local chunkWorldX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize
    local chunkWorldY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize
    
    print("=== 3D MAP GENERATOR DEBUG ===")
    print("Chunk: (" .. chunkX .. ", " .. chunkY .. ")")
    print("World Position: (" .. chunkWorldX .. ", " .. chunkWorldY .. ")")
    print("Within Limits: " .. tostring(MapGenerator.isWithinWorldLimits(chunkWorldX, chunkWorldY)))
    print("Limit Fade Factor: " .. string.format("%.3f", MapGenerator.calculateLimitFadeFactor(chunkWorldX, chunkWorldY)))
    print("")
    print("3D Biome Parameters:")
    print("  Energy: " .. string.format("%.3f", biomeParams.energy))
    print("  Density: " .. string.format("%.3f", biomeParams.density))
    print("  Continentalness: " .. string.format("%.3f", biomeParams.continentalness))
    print("  Turbulence: " .. string.format("%.3f", biomeParams.turbulence))
    print("  Weirdness: " .. string.format("%.3f", biomeParams.weirdness))
    print("  False Height: " .. string.format("%.3f", biomeParams.depth))
    
    -- Generar chunk de prueba
    local testChunk = MapGenerator.generateChunk(chunkX, chunkY)
    print("")
    print("Generated Content:")
    print("  Biome: " .. testChunk.biome.name)
    print("  Stars: " .. #testChunk.objects.stars)
    print("  Nebulae: " .. #testChunk.objects.nebulae)
    print("  Special Objects: " .. #testChunk.specialObjects)
    
    -- Contar asteroides
    local asteroidCount = 0
    for y = 0, MapConfig.chunk.size - 1 do
        for x = 0, MapConfig.chunk.size - 1 do
            if testChunk.tiles[y][x] >= MapConfig.ObjectType.ASTEROID_SMALL and 
               testChunk.tiles[y][x] <= MapConfig.ObjectType.ASTEROID_LARGE then
                asteroidCount = asteroidCount + 1
            end
        end
    end
    print("  Asteroids: " .. asteroidCount)
end

return MapGenerator