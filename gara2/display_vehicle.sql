CREATE TABLE IF NOT EXISTS `display_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(50) DEFAULT NULL,
  `plate` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT NULL,
  `mods` text DEFAULT NULL,
  `parking_lot` varchar(50) DEFAULT 'default',
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE `display_vehicles`
ADD COLUMN `parked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `parking_lot`;