-- src/maps/biome_system.lua (SISTEMA 3D CON FALSA ALTURA INSPIRADO EN MINECRAFT)

local BiomeSystem = {}
local PerlinNoise = require 'src.maps.perlin_noise'

-- Límites del mundo (200k x 200k)
BiomeSystem.WORLD_LIMIT = 200000

-- Tipos de biomas ordenados por rareza
BiomeSystem.BiomeType = {
    DEEP_SPACE = 1,           -- Espacio profundo (océano espacial - predominante)
    NEBULA_FIELD = 2,         -- Campo de Nebulosa (común)
    ASTEROID_BELT = 3,        -- Campo de Asteroides (poco común)
    GRAVITY_ANOMALY = 4,      -- Zona de Gravedad Anómala (raro)
    RADIOACTIVE_ZONE = 5,     -- Sistema Radiactivo (muy raro)
    ANCIENT_RUINS = 6         -- Zona de Civilización Antigua (extremadamente raro)
}

-- Configuración de parámetros espaciales (inspirados en Minecraft)
BiomeSystem.SpaceParameters = {
    -- Energía Espacial (equivale a Temperature en Minecraft)
    energy = {
        levels = {
            {min = -1.0, max = -0.45, name = "FROZEN"},      -- Zonas muertas
            {min = -0.45, max = -0.15, name = "COLD"},       -- Zonas frías
            {min = -0.15, max = 0.2, name = "TEMPERATE"},    -- Zonas templadas
            {min = 0.2, max = 0.55, name = "WARM"},          -- Zonas cálidas
            {min = 0.55, max = 1.0, name = "HOT"}            -- Zonas ardientes
        }
    },
    
    -- Densidad de Materia (equivale a Humidity en Minecraft)
    density = {
        levels = {
            {min = -1.0, max = -0.35, name = "VOID"},        -- Vacío total
            {min = -0.35, max = -0.1, name = "SPARSE"},      -- Disperso
            {min = -0.1, max = 0.1, name = "NORMAL"},        -- Normal
            {min = 0.1, max = 0.3, name = "DENSE"},          -- Denso
            {min = 0.3, max = 1.0, name = "ULTRA_DENSE"}     -- Ultra denso
        }
    },
    
    -- Distancia desde Deep Space (equivale a Continentalness)
    continentalness = {
        levels = {
            {min = -1.2, max = -1.05, name = "DEEP_OCEAN"},     -- Deep Space profundo
            {min = -1.05, max = -0.455, name = "OCEAN"},        -- Deep Space normal
            {min = -0.455, max = -0.19, name = "COAST"},        -- Borde espacial
            {min = -0.19, max = 0.03, name = "NEAR_INLAND"},    -- Cerca de estructuras
            {min = 0.03, max = 0.3, name = "MID_INLAND"},      -- Zonas medias
            {min = 0.3, max = 1.0, name = "FAR_INLAND"}        -- Zonas lejanas
        }
    },
    
    -- Turbulencia Espacial (equivale a Erosion)
    turbulence = {
        levels = {
            {min = -1.0, max = -0.78, name = "EXTREME"},     -- Turbulencia extrema
            {min = -0.78, max = -0.375, name = "HIGH"},      -- Alta turbulencia
            {min = -0.375, max = -0.2225, name = "MEDIUM"}, -- Turbulencia media
            {min = -0.2225, max = 0.05, name = "LOW"},       -- Baja turbulencia
            {min = 0.05, max = 0.45, name = "MINIMAL"},      -- Turbulencia mínima
            {min = 0.45, max = 1.0, name = "STABLE"}         -- Estable
        }
    },
    
    -- Anomalías Gravitatorias (equivale a Weirdness)
    weirdness = {
        levels = {
            {min = -1.0, max = -0.93333, name = "ULTRA_WEIRD"},
            {min = -0.93333, max = -0.7, name = "VERY_WEIRD"},
            {min = -0.7, max = -0.26667, name = "WEIRD"},
            {min = -0.26667, max = 0.26667, name = "NORMAL"},
            {min = 0.26667, max = 0.7, name = "POSITIVE_WEIRD"},
            {min = 0.7, max = 1.0, name = "ULTRA_POSITIVE_WEIRD"}
        }
    }
}

-- CONFIGURACIÓN MEJORADA para distribución 3D natural
BiomeSystem.biomeConfigs = {
    [BiomeSystem.BiomeType.DEEP_SPACE] = {
        name = "Deep Space",
        rarity = "Very Common",
        color = {0.02, 0.02, 0.1, 1},
        spawnWeight = 0.45,  -- 45% del mapa - océano espacial (reducido para más variedad)
        
        -- Condiciones 3D para generar este bioma
        conditions = {
            continentalness = {"DEEP_OCEAN", "OCEAN", "COAST"},  -- Actúa como océano
            energy = {"FROZEN", "COLD", "TEMPERATE", "WARM"},   -- Temperaturas bajas-medias
            density = {"VOID", "SPARSE", "NORMAL", "DENSE"},     -- Densidades bajas-normales
            turbulence = {"LOW", "MINIMAL", "STABLE", "MEDIUM"},  -- Poco turbulento
            weirdness = {"NORMAL", "POSITIVE_WEIRD"},                     -- Sin anomalías
            depthRange = {0.0, 1.0}                     -- Todas las alturas
        },
        
        coherenceRadius = 12,
        biomeScale = 0.015,
        properties = {
            visibility = 1.0,
            mobility = 1.0,
            radiation = 0.0,
            gravity = 1.0
        }
    },
    
    [BiomeSystem.BiomeType.NEBULA_FIELD] = {
        name = "Nebula Field",
        rarity = "Common",
        color = {0.1, 0.05, 0.2, 1},
        spawnWeight = 0.25,  -- 25% del mapa (aumentado)
        
        conditions = {
            continentalness = {"COAST", "NEAR_INLAND", "MID_INLAND"},
            energy = {"TEMPERATE", "WARM", "HOT"},
            density = {"DENSE", "ULTRA_DENSE", "NORMAL"},         -- Densidades altas
            turbulence = {"MEDIUM", "HIGH", "EXTREME"},            -- Más turbulento
            weirdness = {"NORMAL", "POSITIVE_WEIRD", "WEIRD"},
            depthRange = {0.0, 1.0}                     -- Todas las alturas (ampliado)
        },
        
        coherenceRadius = 8,
        biomeScale = 0.025,
        specialFeatures = {
            "dense_nebula",
            "nebula_storm",
            "hidden_station"
        },
        properties = {
            visibility = 0.7,
            mobility = 0.8,
            radiation = 0.1,
            gravity = 0.9
        }
    },
    
    [BiomeSystem.BiomeType.ASTEROID_BELT] = {
        name = "Asteroid Belt",
        rarity = "Uncommon",
        color = {0.15, 0.1, 0.05, 1},
        spawnWeight = 0.20,  -- 20% del mapa (aumentado)
        
        conditions = {
            continentalness = {"MID_INLAND", "FAR_INLAND", "NEAR_INLAND"},
            energy = {"COLD", "TEMPERATE", "WARM"},
            density = {"NORMAL", "DENSE", "SPARSE"},
            turbulence = {"HIGH", "EXTREME", "MEDIUM"},           -- Muy turbulento
            weirdness = {"NORMAL", "WEIRD"},
            depthRange = {0.0, 1.0}                     -- Todas las alturas (ampliado)
        },
        
        coherenceRadius = 6,
        biomeScale = 0.035,
        specialFeatures = {
            "mega_asteroid",
            "mining_station",
            "asteroid_cluster",
            "hidden_cave"
        },
        properties = {
            visibility = 0.9,
            mobility = 0.6,
            radiation = 0.0,
            gravity = 1.1
        }
    },
    
    [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = {
        name = "Gravity Anomaly",
        rarity = "Rare",
        color = {0.2, 0.05, 0.2, 1},
        spawnWeight = 0.05,  -- 5% del mapa (ligeramente aumentado)
        
        conditions = {
            continentalness = {"NEAR_INLAND", "MID_INLAND", "FAR_INLAND"},
            energy = {"HOT", "WARM", "TEMPERATE"},                   -- Energía alta
            density = {"SPARSE", "NORMAL", "DENSE"},
            turbulence = {"EXTREME", "HIGH", "MEDIUM"},           -- Turbulencia extrema
            weirdness = {"WEIRD", "VERY_WEIRD", "ULTRA_WEIRD"},        -- Anomalías importantes
            depthRange = {0.0, 1.0}                     -- Todas las alturas (ampliado)
        },
        
        coherenceRadius = 4,
        biomeScale = 0.05,
        specialFeatures = {
            "gravity_well",
            "space_distortion",
            "floating_debris",
            "gravity_storm"
        },
        properties = {
            visibility = 0.8,
            mobility = 0.4,
            radiation = 0.2,
            gravity = 2.5
        }
    },
    
    [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = {
        name = "Radioactive Zone",
        rarity = "Very Rare",
        color = {0.05, 0.2, 0.05, 1},
        spawnWeight = 0.03,  -- 3% del mapa (ligeramente aumentado)
        
        conditions = {
            continentalness = {"FAR_INLAND"},
            energy = {"HOT"},
            density = {"ULTRA_DENSE"},
            turbulence = {"EXTREME"},
            weirdness = {"ULTRA_WEIRD"},
            depthRange = {0.0, 1.0}                     -- Todas las alturas (ampliado)
        },
        
        coherenceRadius = 3,
        biomeScale = 0.06,
        specialFeatures = {
            "radioactive_core",
            "mutated_flora",
            "abandoned_lab"
        },
        properties = {
            visibility = 0.6,
            mobility = 0.3,
            radiation = 5.0,
            gravity = 1.0
        }
    },
    
    [BiomeSystem.BiomeType.ANCIENT_RUINS] = {
        name = "Ancient Ruins",
        rarity = "Extremely Rare",
        color = {0.1, 0.1, 0.1, 1},
        spawnWeight = 0.02,  -- 2% del mapa (ligeramente aumentado)
        
        conditions = {
            continentalness = {"FAR_INLAND"},
            energy = {"FROZEN", "HOT"},
            density = {"ULTRA_DENSE"},
            turbulence = {"EXTREME"},
            weirdness = {"ULTRA_WEIRD", "ULTRA_POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}                     -- Todas las alturas (ampliado)
        },
        
        coherenceRadius = 2,
        biomeScale = 0.07,
        specialFeatures = {
            "ancient_artifact",
            "alien_structure",
            "lost_technology"
        },
        properties = {
            visibility = 0.5,
            mobility = 0.2,
            radiation = 0.5,
            gravity = 1.5
        }
    }

}

-- Cache y configuración
BiomeSystem.biomeCache = {}
BiomeSystem.parameterCache = {}
BiomeSystem.debugInfo = {
    lastPlayerBiome = nil,
    biomeChangeCount = 0
}
BiomeSystem.debugMode = true -- Establecer a true para depurar, false para producción
BiomeSystem.seed = 12345
BiomeSystem.numericSeed = 12345

-- Función para convertir semilla alfanumérica a numérica
function BiomeSystem.seedToNumeric(alphaSeed)
    if type(alphaSeed) == "number" then
        return alphaSeed
    end
    
    local numericValue = 0
    local seedStr = tostring(alphaSeed)
    
    for i = 1, #seedStr do
        local char = seedStr:sub(i, i)
        local charValue = 0
        
        if char:match("%d") then
            charValue = tonumber(char)
        else
            charValue = string.byte(char:upper()) - string.byte('A') + 10
        end
        
        numericValue = numericValue + charValue * (37 ^ (i - 1))
    end
    
    return math.abs(numericValue) % 2147483647
end

-- Inicialización del sistema
function BiomeSystem.init(seed)
    BiomeSystem.seed = seed or "A1B2C"
    BiomeSystem.numericSeed = BiomeSystem.seedToNumeric(seed)
    BiomeSystem.biomeCache = {}
    BiomeSystem.parameterCache = {}
    BiomeSystem.debugInfo = {
        lastPlayerBiome = nil,
        biomeChangeCount = 0
    }
    
    -- Inicializar Perlin con semilla numérica
    PerlinNoise.init(BiomeSystem.numericSeed)
    
    print("3D ENHANCED Biome System initialized with seed: " .. tostring(BiomeSystem.seed))
    print("Numeric seed: " .. BiomeSystem.numericSeed)
    print("World limits: ±" .. BiomeSystem.WORLD_LIMIT .. " units")
    print("Using 6-parameter 3D biome generation system:")
    print("  • Energy (spatial temperature)")
    print("  • Density (matter concentration)")
    print("  • Continentalness (distance from deep space)")
    print("  • Turbulence (spatial stability)")
    print("  • Weirdness (gravitational anomalies)")
    print("  • Depth (false height dimension)")
end

-- Verificar límites del mundo
function BiomeSystem.isWithinWorldLimits(x, y)
    return math.abs(x) <= BiomeSystem.WORLD_LIMIT and math.abs(y) <= BiomeSystem.WORLD_LIMIT
end

-- Calcular altura falsa basada en posición (X,Y)
function BiomeSystem.calculateFalseHeight(worldX, worldY)
    -- Normalizar coordenadas al rango del mundo
    local normalizedX = worldX / BiomeSystem.WORLD_LIMIT
    local normalizedY = worldY / BiomeSystem.WORLD_LIMIT
    
    -- Usar ruido de baja frecuencia para calcular la "altura falsa"
    local heightNoise1 = PerlinNoise.noise(normalizedX * 0.1, normalizedY * 0.1, 0) -- Baja frecuencia
    local heightNoise2 = PerlinNoise.noise(normalizedX * 0.3, normalizedY * 0.3, 100) -- Media frecuencia
    local heightNoise3 = PerlinNoise.noise(normalizedX * 0.8, normalizedY * 0.8, 200) -- Alta frecuencia
    
    -- Combinar octavas para crear variación de altura
    local combinedHeight = (heightNoise1 * 0.6 + heightNoise2 * 0.3 + heightNoise3 * 0.1)
    
    -- Normalizar a rango [0, 1]
    combinedHeight = (combinedHeight + 1) * 0.5
    
    -- Añadir efecto de "capas" como en Minecraft, pero más sutil
    local layerEffect = math.sin(combinedHeight * math.pi * 2) * 0.05 -- Reducir la frecuencia y la intensidad
    combinedHeight = math.max(0, math.min(1, combinedHeight + layerEffect))
    
    return combinedHeight
end

-- Generar parámetros espaciales 3D para una posición
function BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local cacheKey = chunkX .. "," .. chunkY
    
    if BiomeSystem.parameterCache[cacheKey] then
        return BiomeSystem.parameterCache[cacheKey]
    end
    
    -- Verificar límites del mundo
    local worldX = chunkX * 48 * 32  -- Convertir chunk a coordenadas del mundo
    local worldY = chunkY * 48 * 32
    
    if not BiomeSystem.isWithinWorldLimits(worldX, worldY) then
        -- Fuera de los límites - devolver Deep Space
        local params = {
            energy = -0.8,
            density = -0.9,
            continentalness = -1.1,
            turbulence = 0.3,
            weirdness = 0.0,
            depth = 0.5
        }
        BiomeSystem.parameterCache[cacheKey] = params
        return params
    end
    
    -- Normalizar coordenadas
    local normalizedX = worldX / BiomeSystem.WORLD_LIMIT
    local normalizedY = worldY / BiomeSystem.WORLD_LIMIT
    
    -- Calcular altura falsa
    local falseHeight = BiomeSystem.calculateFalseHeight(worldX, worldY)
    
    -- Generar parámetros usando ruido 3D
    local baseScale = 0.05
    local detailScale = 0.15
    
    -- ENERGÍA ESPACIAL (equivale a temperatura)
    local energy1 = PerlinNoise.noise(normalizedX * baseScale, normalizedY * baseScale, falseHeight * 0.5)
    local energy2 = PerlinNoise.noise(normalizedX * detailScale, normalizedY * detailScale, falseHeight * 2.0 + 50)
    local energy = (energy1 * 0.7 + energy2 * 0.3)
    
    -- Modificar energía por altura (más alto = más frío, como en Minecraft)
    energy = energy - (falseHeight - 0.5) * 0.4
    
    -- DENSIDAD DE MATERIA (equivale a humedad)
    local density1 = PerlinNoise.noise(normalizedX * baseScale + 100, normalizedY * baseScale + 100, falseHeight * 0.3 + 100)
    local density2 = PerlinNoise.noise(normalizedX * detailScale + 100, normalizedY * detailScale + 100, falseHeight * 1.5 + 150)
    local density = (density1 * 0.6 + density2 * 0.4)
    
    -- Ajustar densidad por energía (zonas muy calientes o muy frías tienen menos materia)
    local energyEffect = 1.0 - math.abs(energy) * 0.3
    density = density * energyEffect
    
    -- CONTINENTALIDAD (distancia desde deep space)
    local cont1 = PerlinNoise.noise(normalizedX * baseScale * 0.8 + 200, normalizedY * baseScale * 0.8 + 200, falseHeight * 0.4 + 200)
    local cont2 = PerlinNoise.noise(normalizedX * 0.06 + 250, normalizedY * 0.06 + 250, falseHeight * 1.2 + 250)
    local continentalness = (cont1 * 0.8 + cont2 * 0.2)
    
    -- TURBULENCIA ESPACIAL (equivale a erosión)
    local turb1 = PerlinNoise.noise(normalizedX * 0.04 + 300, normalizedY * 0.04 + 300, falseHeight * 0.8 + 300)
    local turb2 = PerlinNoise.noise(normalizedX * 0.12 + 350, normalizedY * 0.12 + 350, falseHeight * 2.5 + 350)
    local turbulence = (turb1 * 0.5 + turb2 * 0.5)
    
    -- ANOMALÍAS GRAVITATORIAS (weirdness)
    local weird1 = PerlinNoise.noise(normalizedX * 0.03 + 400, normalizedY * 0.03 + 400, falseHeight * 0.6 + 400)
    local weird2 = PerlinNoise.noise(normalizedX * 0.09 + 450, normalizedY * 0.09 + 450, falseHeight * 1.8 + 450)
    local weirdness = (weird1 * 0.7 + weird2 * 0.3)
    
    -- Crear estructura de parámetros
    local params = {
        energy = math.max(-1, math.min(1, energy)),
        density = math.max(-1, math.min(1, density)),
        continentalness = math.max(-1.2, math.min(1, continentalness)),
        turbulence = math.max(-1, math.min(1, turbulence)),
        weirdness = math.max(-1, math.min(1, weirdness)),
        depth = falseHeight
    }
    
    BiomeSystem.parameterCache[cacheKey] = params
    return params
end

-- Encontrar nivel de parámetro
function BiomeSystem.findParameterLevel(value, parameterType)
    local levels = BiomeSystem.SpaceParameters[parameterType].levels
    
    for _, level in ipairs(levels) do
        if value >= level.min and value <= level.max then
            return level.name
        end
    end
    
    -- Fallback al nivel más cercano
    local closestLevel = levels[1]
    local minDistance = math.abs(value - (levels[1].min + levels[1].max) / 2)
    
    for _, level in ipairs(levels) do
        local levelCenter = (level.min + level.max) / 2
        local distance = math.abs(value - levelCenter)
        if distance < minDistance then
            minDistance = distance
            closestLevel = level
        end
    end
    
    return closestLevel.name
end

-- Verificar si los parámetros coinciden con las condiciones del bioma
function BiomeSystem.matchesBiomeConditions(params, conditions)
    -- Verificar rango de profundidad
    if params.depth < conditions.depthRange[1] or params.depth > conditions.depthRange[2] then
        return false
    end
    
    -- Verificar continentalidad
    local contLevel = BiomeSystem.findParameterLevel(params.continentalness, "continentalness")
    local contMatch = false
    for _, allowedLevel in ipairs(conditions.continentalness) do
        if contLevel == allowedLevel then
            contMatch = true
            break
        end
    end
    if not contMatch then return false end
    
    -- Verificar energía
    local energyLevel = BiomeSystem.findParameterLevel(params.energy, "energy")
    local energyMatch = false
    for _, allowedLevel in ipairs(conditions.energy) do
        if energyLevel == allowedLevel then
            energyMatch = true
            break
        end
    end
    if not energyMatch then return false end
    
    -- Verificar densidad
    local densityLevel = BiomeSystem.findParameterLevel(params.density, "density")
    local densityMatch = false
    for _, allowedLevel in ipairs(conditions.density) do
        if densityLevel == allowedLevel then
            densityMatch = true
            break
        end
    end
    if not densityMatch then return false end
    
    -- Verificar turbulencia
    local turbLevel = BiomeSystem.findParameterLevel(params.turbulence, "turbulence")
    local turbMatch = false
    for _, allowedLevel in ipairs(conditions.turbulence) do
        if turbLevel == allowedLevel then
            turbMatch = true
            break
        end
    end
    if not turbMatch then return false end
    
    -- Verificar weirdness
    local weirdLevel = BiomeSystem.findParameterLevel(params.weirdness, "weirdness")
    local weirdMatch = false
    for _, allowedLevel in ipairs(conditions.weirdness) do
        if weirdLevel == allowedLevel then
            weirdMatch = true
            break
        end
    end
    if not weirdMatch then return false end
    
    return true
end

-- Determinar bioma basado en parámetros 3D
function BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    local key = chunkX .. "," .. chunkY
    
    if BiomeSystem.biomeCache[key] then
        return BiomeSystem.biomeCache[key]
    end
    
    -- Generar parámetros espaciales 3D
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    -- Buscar bioma que coincida con las condiciones
    local matchingBiomes = {}
    
    for biomeType, config in pairs(BiomeSystem.biomeConfigs) do
        if BiomeSystem.matchesBiomeConditions(params, config.conditions) then
            table.insert(matchingBiomes, {
                type = biomeType,
                config = config,
                priority = config.spawnWeight
            })
        end
    end
    
    -- Si no hay coincidencias exactas, usar Deep Space como fallback
    if #matchingBiomes == 0 then
        BiomeSystem.biomeCache[key] = BiomeSystem.BiomeType.DEEP_SPACE
        return BiomeSystem.BiomeType.DEEP_SPACE
    end
    
    -- Implementar selección de ruleta ponderada
    local totalWeight = 0
    for _, biomeEntry in ipairs(matchingBiomes) do
        totalWeight = totalWeight + biomeEntry.priority
    end

    -- La aleatoriedad se maneja globalmente con math.randomseed inicializado una vez.

    local randomPoint = math.random() * totalWeight
    local selectedBiome = nil

    for _, biomeEntry in ipairs(matchingBiomes) do
        randomPoint = randomPoint - biomeEntry.priority
        if randomPoint <= 0 then
            selectedBiome = biomeEntry.type
            break
        end
    end

    -- Fallback si por alguna razón no se selecciona un bioma (no debería ocurrir con la lógica de ruleta)
    if not selectedBiome then
        selectedBiome = matchingBiomes[1].type -- Seleccionar el primero como fallback
    end
    
    -- Aplicar coherencia espacial
    selectedBiome = BiomeSystem.applyCoherence3D(chunkX, chunkY, selectedBiome, params)
    
    if BiomeSystem.debugMode then
        print(string.format("Chunk (%d, %d) - Biome: %s, Params: E=%.2f, D=%.2f, C=%.2f, T=%.2f, W=%.2f, Depth=%.2f",
            chunkX, chunkY, selectedBiome,
            params.energy, params.density, params.continentalness, params.turbulence, params.weirdness, params.depth))
    end

    BiomeSystem.biomeCache[key] = selectedBiome
    return selectedBiome
end

-- Sistema de coherencia espacial mejorado para 3D
function BiomeSystem.applyCoherence3D(chunkX, chunkY, proposedBiome, params)
    local proposedConfig = BiomeSystem.biomeConfigs[proposedBiome]
    local coherenceRadius = proposedConfig.coherenceRadius or 1
    
    -- Contar biomas vecinos en un radio
    local neighborCounts = {}
    local totalNeighbors = 0
    
    for dx = -coherenceRadius, coherenceRadius do
        for dy = -coherenceRadius, coherenceRadius do
            if dx == 0 and dy == 0 then goto continue end
            
            local neighborKey = (chunkX + dx) .. "," .. (chunkY + dy)
            local neighborBiome = BiomeSystem.biomeCache[neighborKey]
            
            if neighborBiome then
                neighborCounts[neighborBiome] = (neighborCounts[neighborBiome] or 0) + 1
                totalNeighbors = totalNeighbors + 1
            end
            
            ::continue::
        end
    end
    
    -- Si no hay suficientes vecinos, usar propuesta original
    if totalNeighbors < 3 then
        return proposedBiome
    end
    
    -- Encontrar bioma más común en vecindario
    local dominantBiome = nil
    local maxCount = 0
    
    for biome, count in pairs(neighborCounts) do
        if count > maxCount then
            maxCount = count
            dominantBiome = biome
        end
    end
    
    -- Aplicar lógica de coherencia basada en compatibilidad 3D
    if dominantBiome and maxCount >= totalNeighbors * 0.75 then
        local dominantConfig = BiomeSystem.biomeConfigs[dominantBiome]
        
        -- Verificar si el bioma dominante es compatible con los parámetros actuales
        if BiomeSystem.matchesBiomeConditions(params, dominantConfig.conditions) then
            return dominantBiome
        end
    end
    
    -- Para biomas muy raros, requerir condiciones más precisas
    if proposedConfig.spawnWeight <= 0.02 then
        -- Verificar que realmente esté en el centro de la zona apropiada
        local energyLevel = BiomeSystem.findParameterLevel(params.energy, "energy")
        local densityLevel = BiomeSystem.findParameterLevel(params.density, "density")
        
        -- Si está en el borde de las condiciones, preferir un bioma más común
        local energyMatch = false
        local densityMatch = false
        
        for _, level in ipairs(proposedConfig.conditions.energy) do
            if level == energyLevel then energyMatch = true; break end
        end
        
        for _, level in ipairs(proposedConfig.conditions.density) do
            if level == densityLevel then densityMatch = true; break end
        end
        
        if not energyMatch or not densityMatch then
            return BiomeSystem.BiomeType.DEEP_SPACE
        end
    end
    
    return proposedBiome
end

-- Resto de funciones mantienen la misma funcionalidad pero adaptadas al nuevo sistema

function BiomeSystem.getBiomeConfig(biomeType)
    return BiomeSystem.biomeConfigs[biomeType] or BiomeSystem.biomeConfigs[BiomeSystem.BiomeType.DEEP_SPACE]
end

function BiomeSystem.getBiomeInfo(chunkX, chunkY)
    local biomeType = BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    return {
        type = biomeType,
        name = config.name,
        config = config,
        coordinates = {x = chunkX, y = chunkY},
        parameters = {
            energy = params.energy,
            density = params.density,
            continentalness = params.continentalness,
            turbulence = params.turbulence,
            weirdness = params.weirdness,
            depth = params.depth
        }
    }
end

function BiomeSystem.modifyDensities(baseDensities, biomeType, chunkX, chunkY)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local modifiedDensities = {}
    
    -- Obtener parámetros para ajustes dinámicos
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local energyMultiplier = 1.0 + params.energy * 0.3  -- Más energía = más objetos activos
    local densityMultiplier = 1.0 + params.density * 0.5  -- Más densidad = más objetos en general
    local turbulenceMultiplier = 1.0 + math.abs(params.turbulence) * 0.2  -- Más turbulencia = más variación
    
    -- Densidades base mejoradas por bioma
    local biomeDensities = {
        [BiomeSystem.BiomeType.DEEP_SPACE] = {
            asteroids = 0.01 * densityMultiplier,
            nebulae = 0.001 * energyMultiplier,
            stations = 0.0001,
            wormholes = 0.00005,
            stars = 0.30 * energyMultiplier,
            specialFeatures = 0.0002
        },
        
        [BiomeSystem.BiomeType.NEBULA_FIELD] = {
            asteroids = 0.02 * densityMultiplier,
            nebulae = 0.20 * energyMultiplier * densityMultiplier,  -- Mucho más en nebulosas
            stations = 0.0008,
            wormholes = 0.001 * turbulenceMultiplier,
            stars = 0.35 * energyMultiplier,
            specialFeatures = 0.015 * densityMultiplier
        },
        
        [BiomeSystem.BiomeType.ASTEROID_BELT] = {
            asteroids = 0.25 * densityMultiplier * turbulenceMultiplier,  -- Muchos asteroides
            nebulae = 0.001,
            stations = 0.003,  -- Más estaciones mineras
            wormholes = 0.0001,
            stars = 0.12,  -- Menos estrellas por los asteroides
            specialFeatures = 0.025 * turbulenceMultiplier
        },
        
        [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = {
            asteroids = 0.03 * turbulenceMultiplier,
            nebulae = 0.005 * energyMultiplier,
            stations = 0.0002,
            wormholes = 0.002 * energyMultiplier,  -- Más agujeros de gusano
            stars = 0.18 * energyMultiplier,
            specialFeatures = 0.08 * energyMultiplier  -- Muchas anomalías
        },
        
        [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = {
            asteroids = 0.005,  -- Pocos por la radiación
            nebulae = 0.001,
            stations = 0.0001,
            wormholes = 0.0003,
            stars = 0.45 * energyMultiplier,  -- Muchas estrellas radioactivas
            specialFeatures = 0.12 * energyMultiplier  -- Muchas características especiales
        },
        
        [BiomeSystem.BiomeType.ANCIENT_RUINS] = {
            asteroids = 0.003,
            nebulae = 0.002,
            stations = 0.008,  -- Muchas estructuras antiguas
            wormholes = 0.004,  -- Portales antiguos
            stars = 0.15,
            specialFeatures = 0.15  -- Muchas ruinas
        }
    }
    
    local densitySet = biomeDensities[biomeType]
    if densitySet then
        for key, baseDensity in pairs(baseDensities) do
            modifiedDensities[key] = densitySet[key] or baseDensity
        end
    else
        modifiedDensities = baseDensities
    end
    
    return modifiedDensities
end

function BiomeSystem.updatePlayerBiome(playerX, playerY)
    local Map = require 'src.maps.map'
    local chunkX, chunkY = Map.getChunkInfo(playerX, playerY)
    local currentBiome = BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    
    if BiomeSystem.debugInfo.lastPlayerBiome ~= currentBiome then
        BiomeSystem.debugInfo.lastPlayerBiome = currentBiome
        BiomeSystem.debugInfo.biomeChangeCount = BiomeSystem.debugInfo.biomeChangeCount + 1
        
        local config = BiomeSystem.getBiomeConfig(currentBiome)
        local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
        
        if _G.advancedStats and _G.advancedStats.enabled then
            print("=== 3D BIOME CHANGE #" .. BiomeSystem.debugInfo.biomeChangeCount .. " ===")
            print("Entered: " .. config.name .. " (" .. config.rarity .. ")")
            print("3D Parameters:")
            print("  Energy: " .. string.format("%.3f", params.energy) .. " (" .. BiomeSystem.findParameterLevel(params.energy, "energy") .. ")")
            print("  Density: " .. string.format("%.3f", params.density) .. " (" .. BiomeSystem.findParameterLevel(params.density, "density") .. ")")
            print("  Continental: " .. string.format("%.3f", params.continentalness) .. " (" .. BiomeSystem.findParameterLevel(params.continentalness, "continentalness") .. ")")
            print("  Turbulence: " .. string.format("%.3f", params.turbulence) .. " (" .. BiomeSystem.findParameterLevel(params.turbulence, "turbulence") .. ")")
            print("  Weirdness: " .. string.format("%.3f", params.weirdness) .. " (" .. BiomeSystem.findParameterLevel(params.weirdness, "weirdness") .. ")")
            print("  False Height: " .. string.format("%.3f", params.depth))
            
            -- Notificación especial para biomas raros
            if config.spawnWeight <= 0.02 then
                print("*** RARE BIOME DISCOVERY! 3D CONDITIONS ALIGNED! ***")
            end
        end
    end
    
    return currentBiome
end

function BiomeSystem.getPlayerBiomeInfo(playerX, playerY)
    local Map = require 'src.maps.map'
    local chunkX, chunkY = Map.getChunkInfo(playerX, playerY)
    local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
    
    return {
        type = biomeInfo.type,
        name = biomeInfo.name,
        rarity = biomeInfo.config.rarity,
        config = biomeInfo.config,
        coordinates = {
            chunk = {x = chunkX, y = chunkY},
            world = {x = playerX, y = playerY}
        },
        parameters = biomeInfo.parameters
    }
end

-- Función de debug mejorada para verificar distribución 3D
function BiomeSystem.debugDistribution(sampleSize)
    sampleSize = sampleSize or 2000
    local counts = {}
    local parameterStats = {
        energy = {total = 0, samples = 0},
        density = {total = 0, samples = 0},
        continentalness = {total = 0, samples = 0},
        turbulence = {total = 0, samples = 0},
        weirdness = {total = 0, samples = 0},
        depth = {total = 0, samples = 0}
    }
    
    -- Inicializar contadores
    for biomeType, _ in pairs(BiomeSystem.biomeConfigs) do
        counts[biomeType] = 0
    end
    
    -- Generar muestra aleatoria dentro de los límites del mundo
    local maxChunk = math.floor(BiomeSystem.WORLD_LIMIT / (48 * 32))
    
    for i = 1, sampleSize do
        local x = math.random(-maxChunk, maxChunk)
        local y = math.random(-maxChunk, maxChunk)
        local biome = BiomeSystem.getBiomeForChunk(x, y)
        local params = BiomeSystem.generateSpaceParameters(x, y)
        
        counts[biome] = counts[biome] + 1
        
        -- Acumular estadísticas de parámetros
        for paramName, value in pairs(params) do
            if parameterStats[paramName] then
                parameterStats[paramName].total = parameterStats[paramName].total + value
                parameterStats[paramName].samples = parameterStats[paramName].samples + 1
            end
        end
    end
    
    print("=== 3D BIOME DISTRIBUTION TEST (Sample: " .. sampleSize .. ") ===")
    print("World Limits: ±" .. BiomeSystem.WORLD_LIMIT .. " units")
    print("Using 6-parameter 3D generation system")
    print("")
    
    for biomeType, count in pairs(counts) do
        local config = BiomeSystem.getBiomeConfig(biomeType)
        local actualPercentage = (count / sampleSize) * 100
        local expectedPercentage = config.spawnWeight * 100
        local difference = actualPercentage - expectedPercentage
        local status = ""
        
        if math.abs(difference) <= 2 then
            status = " ✓ EXCELLENT"
        elseif math.abs(difference) <= 4 then
            status = " ~ GOOD"
        elseif math.abs(difference) <= 8 then
            status = " ! ACCEPTABLE"
        else
            status = " ✗ NEEDS ADJUSTMENT"
        end
        
        print(string.format("%s: %.1f%% (target: %.1f%%, diff: %+.1f%%)%s", 
              config.name, actualPercentage, expectedPercentage, difference, status))
    end
    
    print("")
    print("=== 3D PARAMETER AVERAGES ===")
    for paramName, stats in pairs(parameterStats) do
        if stats.samples > 0 then
            local average = stats.total / stats.samples
            print(string.format("%s: %.3f (range: -1.0 to 1.0)", paramName, average))
        end
    end
    
    -- Análisis de calidad específico para el sistema 3D
    local deepSpacePercentage = (counts[BiomeSystem.BiomeType.DEEP_SPACE] / sampleSize) * 100
    if deepSpacePercentage >= 55 and deepSpacePercentage <= 65 then
        print("✓ DEEP SPACE DISTRIBUTION IS OPTIMAL (acts as spatial ocean)")
    elseif deepSpacePercentage > 65 then
        print("! Deep Space might be too dominant - adjust 3D parameters")
    else
        print("! Deep Space might be too sparse - increase continentalness ocean zones")
    end
    
    print("✓ 3D Biome system with false height active")
    print("✓ World boundaries enforced at ±" .. BiomeSystem.WORLD_LIMIT)
end

-- Generar características especiales con parámetros 3D
function BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeType)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local specialFeatures = config.specialFeatures or {}
    
    if #specialFeatures == 0 then return end
    
    -- Obtener parámetros 3D para ajustar la generación
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    -- Ajustar probabilidad basada en parámetros 3D
    local energyBonus = params.energy > 0.5 and 1.5 or 1.0
    local weirdnessBonus = math.abs(params.weirdness) > 0.5 and 2.0 or 1.0
    local depthBonus = (params.depth < 0.2 or params.depth > 0.8) and 1.3 or 1.0
    
    local totalBonus = energyBonus * weirdnessBonus * depthBonus
    
    local featureSeed = ((chunkX * 1000 + chunkY) % 100000) + BiomeSystem.numericSeed
    math.randomseed(featureSeed)
    
    for _, featureType in ipairs(specialFeatures) do
        local baseChance = (config.properties and config.properties.specialFeatures) or 0.01
        local adjustedChance = baseChance * totalBonus
        
        if math.random() < adjustedChance then
            BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
        end
    end
end

function BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
    local feature = {
        type = featureType,
        x = math.random(5, chunk.size or 43) * 32,
        y = math.random(5, chunk.size or 43) * 32,
        size = math.random(20, 60),
        properties = {},
        active = true,
        parameters = params  -- Guardar parámetros 3D para efectos
    }
    
    -- Ajustar características según parámetros 3D
    local energyScale = 1.0 + params.energy * 0.3
    local weirdnessScale = 1.0 + math.abs(params.weirdness) * 0.5
    
    -- Configuración de features específicas mejorada
    if featureType == "dense_nebula" then
        feature.color = {0.8, 0.3, 0.8, 0.6 + params.density * 0.2}
        feature.size = math.random(80, 150) * (1.0 + params.density * 0.4)
        feature.properties.visibility_reduction = 0.5 + math.abs(params.density) * 0.3
        
    elseif featureType == "mega_asteroid" then
        feature.size = math.random(40, 80) * (1.0 + params.turbulence * 0.3)
        feature.color = {0.5, 0.4, 0.3, 1}
        feature.properties.mining_yield = 3.0 * energyScale
        
    elseif featureType == "gravity_well" then
        feature.color = {0.4, 0.2, 0.8, 0.4 + math.abs(params.weirdness) * 0.3}
        feature.size = math.random(30, 50) * weirdnessScale
        feature.properties.gravity_strength = 2.5 * weirdnessScale
        feature.properties.pull_radius = feature.size * 3
        
    elseif featureType == "dead_star" then
        feature.color = {0.8, 0.6, 0.2, 0.9}
        feature.size = math.random(15, 25) * energyScale
        feature.properties.radiation_intensity = 1.5 * energyScale
        feature.properties.radiation_radius = feature.size * 8
        
    elseif featureType == "ancient_station" then
        feature.color = {0.3, 0.7, 0.5, 0.8}
        feature.size = math.random(25, 45)
        feature.properties.tech_level = math.min(5, math.floor(1 + math.abs(params.weirdness) * 5))
        feature.properties.intact = math.random() > (0.3 - params.depth * 0.2)
    end
    
    chunk.specialObjects = chunk.specialObjects or {}
    table.insert(chunk.specialObjects, feature)
end

function BiomeSystem.getBackgroundColor(biomeType)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    return config.color
end

function BiomeSystem.getProperty(biomeType, property)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    return config.properties and config.properties[property] or 1.0
end

function BiomeSystem.regenerate(newSeed)
    BiomeSystem.init(newSeed)
    print("3D ENHANCED Biome System regenerated with seed: " .. tostring(newSeed))
    print("New 3D parameter space generated with false height dimension")
end

function BiomeSystem.getAdvancedStats()
    local stats = {
        totalChunksGenerated = 0,
        biomeDistribution = {},
        rarityDistribution = {},
        parameterDistribution = {},
        playerStats = {
            currentBiome = BiomeSystem.debugInfo.lastPlayerBiome,
            biomeChanges = BiomeSystem.debugInfo.biomeChangeCount
        },
        seed = BiomeSystem.seed,
        numericSeed = BiomeSystem.numericSeed,
        worldLimits = BiomeSystem.WORLD_LIMIT,
        system = "3D_6_PARAMETER"
    }
    
    -- Inicializar contadores
    for biomeType, config in pairs(BiomeSystem.biomeConfigs) do
        stats.biomeDistribution[config.name] = 0
        stats.rarityDistribution[config.rarity] = 0
    end
    
    -- Contar biomas generados
    for _, biomeType in pairs(BiomeSystem.biomeCache) do
        local config = BiomeSystem.getBiomeConfig(biomeType)
        stats.biomeDistribution[config.name] = stats.biomeDistribution[config.name] + 1
        stats.rarityDistribution[config.rarity] = stats.rarityDistribution[config.rarity] + 1
        stats.totalChunksGenerated = stats.totalChunksGenerated + 1
    end
    
    return stats
end

-- Find all unique biomes within a given radius (MEJORADO PARA 3D)
function BiomeSystem.findNearbyBiomes(x, y, radius)
    radius = radius or 10000
    local Map = require 'src.maps.map'
    local chunkSize = Map.chunkSize * Map.tileSize
    
    -- Verificar límites del mundo
    if not BiomeSystem.isWithinWorldLimits(x, y) then
        return {{
            type = BiomeSystem.BiomeType.DEEP_SPACE,
            name = "Deep Space",
            distance = 0,
            config = BiomeSystem.getBiomeConfig(BiomeSystem.BiomeType.DEEP_SPACE),
            chunkX = 0,
            chunkY = 0,
            note = "Outside world limits"
        }}
    end
    
    -- Convertir radio a chunks
    local chunkRadius = math.ceil(radius / chunkSize)
    
    -- Obtener chunk del jugador
    local startChunkX, startChunkY = math.floor(x / chunkSize), math.floor(y / chunkSize)
    
    local foundBiomes = {}
    local minDistances = {}
    
    -- Buscar en área cuadrada alrededor del jugador
    for dx = -chunkRadius, chunkRadius do
        for dy = -chunkRadius, chunkRadius do
            local chunkX = startChunkX + dx
            local chunkY = startChunkY + dy
            
            -- Calcular distancia en unidades del mundo
            local worldX = (chunkX + 0.5) * chunkSize
            local worldY = (chunkY + 0.5) * chunkSize
            local distance = math.sqrt((worldX - x)^2 + (worldY - y)^2)
            
            -- Solo procesar si está dentro del radio
            if distance <= radius then
                local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
                if biomeInfo and biomeInfo.type then
                    local biomeType = biomeInfo.type
                    
                    -- Actualizar distancia mínima para este tipo de bioma
                    if not minDistances[biomeType] or distance < minDistances[biomeType] then
                        minDistances[biomeType] = distance
                        foundBiomes[biomeType] = {
                            type = biomeType,
                            name = biomeInfo.name,
                            distance = distance,
                            config = biomeInfo.config,
                            chunkX = chunkX,
                            chunkY = chunkY,
                            parameters = biomeInfo.parameters  -- Incluir parámetros 3D
                        }
                    end
                end
            end
        end
    end
    
    -- Convertir a array y ordenar por distancia
    local result = {}
    for _, biome in pairs(foundBiomes) do
        table.insert(result, biome)
    end
    
    table.sort(result, function(a, b) 
        return a.distance < b.distance
    end)
    
    return result
end

return BiomeSystem