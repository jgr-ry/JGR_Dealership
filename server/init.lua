-- Nombre oficial del recurso. La misma regla está en server/main.lua (no quitar).
-- La comprobación de versiones está en server/version_check.lua (común a todos los scripts JGR).
local EXPECTED_RESOURCE_NAME = 'JGR_Dealership'

do
    local n = GetCurrentResourceName()
    if n ~= EXPECTED_RESOURCE_NAME then
        print(('^1[%s]^0 ^1Renombra la carpeta del recurso a^0 ^3%s^0 (nombre oficial).^0'):format(n, EXPECTED_RESOURCE_NAME))
        StopResource(n)
        return
    end
end
