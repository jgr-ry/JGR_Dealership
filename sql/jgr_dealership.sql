CREATE TABLE IF NOT EXISTS `jgr_dealership_vehicles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `model` varchar(50) NOT NULL,
    `name` varchar(100) NOT NULL,
    `price` int(11) NOT NULL DEFAULT 10000,
    `category` varchar(50) NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Referencia: el recurso crea esta tabla y los vehículos por defecto solo al arrancar.
-- Ejecútalo a mano solo si quieres crearla tú (no lo ejecutes si la tabla ya tiene datos).
-- Vehículos por defecto (categorías: compactos, sedanes, suvs, coupes, electricos, musclecars,
-- deportivos_clasicos, deportivos, superdeportivos, motos)
INSERT INTO `jgr_dealership_vehicles` (`model`, `name`, `price`, `category`) VALUES
('adder', 'Truffade Adder', 1000000, 'superdeportivos'),
('t20', 'Progen T20', 2200000, 'superdeportivos'),
('tailgater', 'Obey Tailgater', 55000, 'sedanes'),
('schafter2', 'Benefactor Schafter V12', 116000, 'sedanes'),
('dubsta', 'Benefactor Dubsta', 70000, 'suvs'),
('sanchez', 'Maibatsu Sanchez', 8000, 'motos');
