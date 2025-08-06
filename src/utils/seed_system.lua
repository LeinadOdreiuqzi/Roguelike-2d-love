-- src/utils/seed_system.lua

local SeedSystem = {}

-- Caracteres permitidos
SeedSystem.letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
SeedSystem.digits = "0123456789"

-- Generar semilla alfanumérica (5 letras + 5 dígitos mezclados)
function SeedSystem.generate()
    local chars = {}
    
    -- Agregar 5 letras aleatorias
    for i = 1, 5 do
        local randomIndex = math.random(1, #SeedSystem.letters)
        table.insert(chars, SeedSystem.letters:sub(randomIndex, randomIndex))
    end
    
    -- Agregar 5 dígitos aleatorios
    for i = 1, 5 do
        local randomIndex = math.random(1, #SeedSystem.digits)
        table.insert(chars, SeedSystem.digits:sub(randomIndex, randomIndex))
    end
    
    -- Mezclar los caracteres
    for i = #chars, 2, -1 do
        local j = math.random(i)
        chars[i], chars[j] = chars[j], chars[i]
    end
    
    return table.concat(chars)
end

-- Validar formato de semilla (10 caracteres alfanuméricos)
function SeedSystem.validate(seed)
    if type(seed) ~= "string" or #seed ~= 10 then
        return false
    end
    
    -- Verificar que todos los caracteres sean alfanuméricos
    if not seed:match("^[A-Z0-9]+$") then
        return false
    end
    
    -- Verificar que haya al menos una letra y un dígito
    if not seed:match("%a") or not seed:match("%d") then
        return false
    end
    
    return true
end

-- Convertir semilla a número para usar con math.randomseed
function SeedSystem.toNumber(seed)
    -- Si ya es un número, devolverlo directamente
    if type(seed) == "number" then
        return math.floor(seed) % (2^31)
    end
    
    -- Si no es un string o está vacío, generar una semilla aleatoria
    if type(seed) ~= "string" or #seed == 0 then
        seed = SeedSystem.generate()
    end
    
    -- Asegurarse de que la semilla sea válida
    if not SeedSystem.validate(seed) then
        -- Si no es válida, generar un hash numérico a partir de la cadena
        local hash = 0
        for i = 1, #seed do
            hash = (hash * 31 + string.byte(seed, i)) % (2^31)
        end
        return hash
    end
    
    -- Convertir la semilla a un número
    local num = 0
    for i = 1, #seed do
        local c = seed:sub(i, i)
        num = (num * 31 + string.byte(c)) % (2^31)
    end
    
    return num
end

-- Normalizar una semilla para asegurar que cumple con el formato
function SeedSystem.normalize(input)
    if not input or input == "" then
        return SeedSystem.generate()
    end
    
    local normalized = tostring(input):upper()
    
    if SeedSystem.validate(normalized) then
        return normalized
    end
    
    -- Si es muy corta, completar con caracteres aleatorios
    if #normalized < 10 then
        local remaining = 10 - #normalized
        for i = 1, remaining do
            if math.random() < 0.5 then
                normalized = normalized .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
            else
                normalized = normalized .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
            end
        end
    elseif #normalized > 10 then
        -- Si es muy larga, truncar
        normalized = normalized:sub(1, 10)
    end
    
    -- Limpiar caracteres no válidos
    local cleanSeed = ""
    for i = 1, #normalized do
        local char = normalized:sub(i, i)
        if char:match("[A-Z0-9]") then
            cleanSeed = cleanSeed .. char
        else
            -- Reemplazar caracteres no válidos con caracteres aleatorios
            if math.random() < 0.5 then
                cleanSeed = cleanSeed .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
            else
                cleanSeed = cleanSeed .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
            end
        end
    end
    
    -- Asegurar un balance razonable entre letras y dígitos
    local letterCount = 0
    local digitCount = 0
    for i = 1, #cleanSeed do
        local char = cleanSeed:sub(i, i)
        if char:match("[A-Z]") then
            letterCount = letterCount + 1
        else
            digitCount = digitCount + 1
        end
    end
    
    -- Si hay un desbalance muy grande, generar una semilla nueva
    if math.abs(letterCount - digitCount) > 2 then
        return SeedSystem.generate()
    end
    
    return cleanSeed
end

-- Alias para compatibilidad con el código existente
SeedSystem.toNumeric = SeedSystem.toNumber

return SeedSystem
