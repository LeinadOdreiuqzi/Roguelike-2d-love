-- src/maps/perlin_noise.lua (MEJORADO CON SOPORTE 3D COMPLETO)

local PerlinNoise = {}

-- Tabla de permutación para el ruido de Perlin (expandida para mejor calidad)
local p = {}
local permutation = {
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
    140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
    247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
    57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
    74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
    60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
    65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
    200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
    52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
    207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
    119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
    129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
    218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
    81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
    184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
    222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}

-- Gradientes optimizados para ruido 3D
local gradients3D = {
    {1, 1, 0}, {-1, 1, 0}, {1, -1, 0}, {-1, -1, 0},
    {1, 0, 1}, {-1, 0, 1}, {1, 0, -1}, {-1, 0, -1},
    {0, 1, 1}, {0, -1, 1}, {0, 1, -1}, {0, -1, -1},
    {1, 1, 0}, {0, -1, 1}, {-1, 1, 0}, {0, -1, -1}
}



-- Inicializa la tabla de permutación con una semilla
function PerlinNoise.init(seed)
    seed = seed or os.time()
    math.randomseed(seed)
    
    -- Crear copia de la tabla de permutación base
    local tempPerm = {}
    for i = 1, 256 do
        tempPerm[i] = permutation[i]
    end
    
    -- Mezclar la tabla usando Fisher-Yates shuffle
    for i = 256, 2, -1 do
        local j = math.random(1, i)
        tempPerm[i], tempPerm[j] = tempPerm[j], tempPerm[i]
    end
    
    -- Duplicar la tabla para evitar desbordamientos con módulo
    for i = 0, 255 do
        p[i] = tempPerm[i + 1]
        p[i + 256] = tempPerm[i + 1]
    end
    

    
    print("PerlinNoise initialized with 3D support. Seed: " .. seed)
end

-- Función de interpolación suave mejorada (quintic)
local function fade(t)
    -- Quintic interpolation: 6t^5 - 15t^4 + 10t^3
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Función de interpolación lineal optimizada
local function lerp(t, a, b)
    return a + t * (b - a)
end

-- Función de gradiente 3D optimizada
local function grad3D(hash, x, y, z)
    -- Usar tabla de gradientes precomputadas
    local gradIndex = (hash % 16) + 1
    local grad = gradients3D[gradIndex]
    
    return grad[1] * x + grad[2] * y + grad[3] * z
end

-- Función de gradiente 2D para compatibilidad
local function grad2D(hash, x, y)
    local h = hash % 8
    local u = h < 4 and x or y
    local v = h < 4 and y or x
    return (h % 2 == 0 and u or -u) + (h < 2 and v or -v)
end

-- Función principal de ruido de Perlin 3D MEJORADA
function PerlinNoise.noise(x, y, z)
    z = z or 0
    
    -- No se manejan casos especiales de coordenadas muy grandes con modulo, ya que el ruido de Perlin es continuo por diseño.
    
    -- Encontrar las coordenadas de la unidad del cubo que contiene el punto
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    local Z = math.floor(z) % 256
    
    -- Encontrar las posiciones relativas del punto en el cubo
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)
    
    -- Calcular las curvas de desvanecimiento para cada coordenada
    local u = fade(x)
    local v = fade(y)
    local w = fade(z)
    
    -- Hash de las coordenadas de las 8 esquinas del cubo
    local A = p[X] + Y
    local AA = p[A] + Z
    local AB = p[A + 1] + Z
    local B = p[X + 1] + Y
    local BA = p[B] + Z
    local BB = p[B + 1] + Z
    
    -- Agregar los resultados mezclados de las 8 esquinas del cubo usando gradientes 3D
    local result = lerp(w, 
        lerp(v, 
            lerp(u, grad3D(p[AA], x, y, z),
                    grad3D(p[BA], x - 1, y, z)),
            lerp(u, grad3D(p[AB], x, y - 1, z),
                    grad3D(p[BB], x - 1, y - 1, z))),
        lerp(v, 
            lerp(u, grad3D(p[AA + 1], x, y, z - 1),
                    grad3D(p[BA + 1], x - 1, y, z - 1)),
            lerp(u, grad3D(p[AB + 1], x, y - 1, z - 1),
                    grad3D(p[BB + 1], x - 1, y - 1, z - 1))))
    
    return result
end

-- Función de ruido 2D optimizada (para compatibilidad hacia atrás)
function PerlinNoise.noise2D(x, y)
    -- No se manejan coordenadas muy grandes con modulo, ya que el ruido de Perlin es continuo por diseño.
    
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    
    x = x - math.floor(x)
    y = y - math.floor(y)
    
    local u = fade(x)
    local v = fade(y)
    
    local A = p[X] + Y
    local B = p[X + 1] + Y
    
    return lerp(v, 
        lerp(u, grad2D(p[A], x, y),
                grad2D(p[B], x - 1, y)),
        lerp(u, grad2D(p[A + 1], x, y - 1),
                grad2D(p[B + 1], x - 1, y - 1)))
end

-- Ruido fractal con múltiples octavas (mejorado para 3D)
function PerlinNoise.fractalNoise3D(x, y, z, octaves, persistence, scale, amplitude)
    octaves = octaves or 4
    persistence = persistence or 0.5
    scale = scale or 1.0
    amplitude = amplitude or 1.0
    
    local value = 0
    local currentAmplitude = amplitude
    local currentFrequency = scale
    local maxValue = 0 -- Para normalización
    
    for i = 1, octaves do
        value = value + PerlinNoise.noise(x * currentFrequency, y * currentFrequency, z * currentFrequency) * currentAmplitude
        maxValue = maxValue + currentAmplitude
        currentAmplitude = currentAmplitude * persistence
        currentFrequency = currentFrequency * 2
    end
    
    -- Normalizar al rango [-1, 1]
    return value / maxValue
end

-- Ruido fractal 2D (para compatibilidad)
function PerlinNoise.fractalNoise2D(x, y, octaves, persistence, scale, amplitude)
    octaves = octaves or 4
    persistence = persistence or 0.5
    scale = scale or 1.0
    amplitude = amplitude or 1.0
    
    local value = 0
    local currentAmplitude = amplitude
    local currentFrequency = scale
    local maxValue = 0
    
    for i = 1, octaves do
        value = value + PerlinNoise.noise2D(x * currentFrequency, y * currentFrequency) * currentAmplitude
        maxValue = maxValue + currentAmplitude
        currentAmplitude = currentAmplitude * persistence
        currentFrequency = currentFrequency * 2
    end
    
    return value / maxValue
end

-- Ruido de turbulencia (absoluto) para crear patrones más caóticos
function PerlinNoise.turbulence3D(x, y, z, octaves, scale)
    octaves = octaves or 4
    scale = scale or 1.0
    
    local value = 0
    local amplitude = 1.0
    local frequency = scale
    
    for i = 1, octaves do
        value = value + math.abs(PerlinNoise.noise(x * frequency, y * frequency, z * frequency)) * amplitude
        amplitude = amplitude * 0.5
        frequency = frequency * 2
    end
    
    return value
end

-- Ruido de cresta (ridge noise) para crear patrones de montañas/valles
function PerlinNoise.ridgeNoise3D(x, y, z, octaves, scale, ridgeOffset)
    octaves = octaves or 4
    scale = scale or 1.0
    ridgeOffset = ridgeOffset or 1.0
    
    local value = 0
    local amplitude = 1.0
    local frequency = scale
    local weight = 1.0
    
    for i = 1, octaves do
        local signal = PerlinNoise.noise(x * frequency, y * frequency, z * frequency)
        signal = ridgeOffset - math.abs(signal)
        signal = signal * signal * weight
        
        value = value + signal * amplitude
        weight = signal
        amplitude = amplitude * 0.5
        frequency = frequency * 2
        
        -- Limitar el peso para evitar valores extremos
        if weight > 1.0 then weight = 1.0 end
        if weight < 0.0 then weight = 0.0 end
    end
    
    return value
end

-- Ruido warped (distorsionado) para crear patrones más orgánicos
function PerlinNoise.warpedNoise3D(x, y, z, warpStrength, octaves, scale)
    warpStrength = warpStrength or 1.0
    octaves = octaves or 4
    scale = scale or 1.0
    
    -- Generar desplazamientos usando ruido
    local warpX = PerlinNoise.fractalNoise3D(x, y, z, octaves, 0.5, scale * 0.5) * warpStrength
    local warpY = PerlinNoise.fractalNoise3D(x + 100, y + 100, z + 100, octaves, 0.5, scale * 0.5) * warpStrength
    local warpZ = PerlinNoise.fractalNoise3D(x + 200, y + 200, z + 200, octaves, 0.5, scale * 0.5) * warpStrength
    
    -- Aplicar distorsión
    return PerlinNoise.fractalNoise3D(x + warpX, y + warpY, z + warpZ, octaves, 0.5, scale)
end

-- Función para generar ruido específico de biomas espaciales
function PerlinNoise.spatialBiomeNoise(x, y, z, biomeType)
    biomeType = biomeType or "default"
    
    local configurations = {
        energy = {
            octaves = 4,
            persistence = 0.6,
            scale = 0.02,
            warpStrength = 0.5
        },
        density = {
            octaves = 5,
            persistence = 0.5,
            scale = 0.03,
            ridgeOffset = 0.8
        },
        continentalness = {
            octaves = 3,
            persistence = 0.7,
            scale = 0.015,
            warpStrength = 0.3
        },
        turbulence = {
            octaves = 6,
            persistence = 0.4,
            scale = 0.08,
            turbulence = true
        },
        weirdness = {
            octaves = 4,
            persistence = 0.6,
            scale = 0.05,
            ridgeOffset = 1.2
        }
    }
    
    local config = configurations[biomeType] or configurations.energy
    
    if config.turbulence then
        return PerlinNoise.turbulence3D(x, y, z, config.octaves, config.scale)
    elseif config.ridgeOffset then
        return PerlinNoise.ridgeNoise3D(x, y, z, config.octaves, config.scale, config.ridgeOffset)
    elseif config.warpStrength then
        return PerlinNoise.warpedNoise3D(x, y, z, config.warpStrength, config.octaves, config.scale)
    else
        return PerlinNoise.fractalNoise3D(x, y, z, config.octaves, config.persistence, config.scale)
    end
end

-- Función de utilidad para crear máscaras de ruido
function PerlinNoise.noiseMask(x, y, z, threshold, smoothness)
    threshold = threshold or 0.0
    smoothness = smoothness or 0.1
    
    local noise = PerlinNoise.noise(x, y, z)
    
    if smoothness <= 0 then
        return noise > threshold and 1 or 0
    end
    
    -- Suavizar la transición
    local distance = math.abs(noise - threshold)
    if distance >= smoothness then
        return noise > threshold and 1 or 0
    else
        local t = distance / smoothness
        local smoothValue = 3 * t * t - 2 * t * t * t  -- Smoothstep
        return noise > threshold and smoothValue or (1 - smoothValue)
    end
end

-- Función para generar campos vectoriales de ruido (útil para simulación de fluidos espaciales)
function PerlinNoise.vectorField3D(x, y, z, scale)
    scale = scale or 1.0
    
    return {
        x = PerlinNoise.noise(x * scale, y * scale, z * scale),
        y = PerlinNoise.noise(x * scale + 100, y * scale + 100, z * scale + 100),
        z = PerlinNoise.noise(x * scale + 200, y * scale + 200, z * scale + 200)
    }
end

-- Función para generar ruido con dominios específicos (útil para crear regiones distintas)
function PerlinNoise.domainNoise3D(x, y, z, domainSize, octaves, scale)
    domainSize = domainSize or 100
    octaves = octaves or 4
    scale = scale or 1.0
    
    -- Discretizar las coordenadas a dominios
    local domainX = math.floor(x / domainSize) * domainSize
    local domainY = math.floor(y / domainSize) * domainSize
    local domainZ = math.floor(z / domainSize) * domainSize
    
    -- Generar ruido base para el dominio
    local domainNoise = PerlinNoise.fractalNoise3D(domainX, domainY, domainZ, octaves, 0.5, scale * 0.1)
    
    -- Agregar variación local dentro del dominio
    local localNoise = PerlinNoise.fractalNoise3D(x, y, z, octaves, 0.5, scale)
    
    -- Combinar ruido de dominio con ruido local
    return domainNoise * 0.7 + localNoise * 0.3
end

-- Funciones de utilidad para debugging y optimización
function PerlinNoise.getCacheStats()
    local fadeCount = 0
    local gradientCount = 0
    
    for _ in pairs(fadeCache) do
        fadeCount = fadeCount + 1
    end
    
    for _ in pairs(gradientCache) do
        gradientCount = gradientCount + 1
    end
    
    return {
        fadeCacheSize = fadeCount,
        gradientCacheSize = gradientCount
    }
end

function PerlinNoise.clearCache()
    fadeCache = {}
    gradientCache = {}
end

-- Función para validar que el ruido está funcionando correctamente
function PerlinNoise.validateNoise()
    local samples = {}
    local sampleCount = 1000
    
    for i = 1, sampleCount do
        local x = math.random() * 100
        local y = math.random() * 100
        local z = math.random() * 100
        
        local noise2D = PerlinNoise.noise2D(x, y)
        local noise3D = PerlinNoise.noise(x, y, z)
        
        table.insert(samples, {
            pos = {x, y, z},
            noise2D = noise2D,
            noise3D = noise3D
        })
    end
    
    -- Calcular estadísticas básicas
    local min2D, max2D = 999, -999
    local min3D, max3D = 999, -999
    local sum2D, sum3D = 0, 0
    
    for _, sample in ipairs(samples) do
        min2D = math.min(min2D, sample.noise2D)
        max2D = math.max(max2D, sample.noise2D)
        min3D = math.min(min3D, sample.noise3D)
        max3D = math.max(max3D, sample.noise3D)
        sum2D = sum2D + sample.noise2D
        sum3D = sum3D + sample.noise3D
    end
    
    return {
        samples = sampleCount,
        noise2D = {
            min = min2D,
            max = max2D,
            avg = sum2D / sampleCount,
            range = max2D - min2D
        },
        noise3D = {
            min = min3D,
            max = max3D,
            avg = sum3D / sampleCount,
            range = max3D - min3D
        }
    }
end

return PerlinNoise