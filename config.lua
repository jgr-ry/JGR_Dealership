Config = {}

-- [[ Dealership Locations ]]
Config.Dealerships = {
    Main = {
        -- Coordinates for the dealership interact interaction point
        coords = vector3(-33.84, -1102.13, 26.42), 
        -- Interaction type: 'marker' or 'target'
        interactType = 'marker', 
        
        -- Where the car will spawn when previewing
        PreviewSpawn = vector4(-44.59, -1098.39, 26.42, 107.41),
        -- Where the camera should be placed looking at the car
        PreviewCam = vector3(-40.24, -1095.83, 27.5),
        
        -- Where the car spawns after buying
        BuySpawn = vector4(-31.62, -1090.87, 26.42, 340.35)
    }
}

-- [[ UI Settings ]]
Config.UI = {
    CurrencySymbol = "$",
    Locale = 'es' -- Options: 'es', 'en'
}
