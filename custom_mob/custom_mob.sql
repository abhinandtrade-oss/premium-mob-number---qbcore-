CREATE TABLE IF NOT EXISTS `premium_phone_numbers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL UNIQUE,
  `custom_number` VARCHAR(20) NOT NULL UNIQUE,
  `original_number` VARCHAR(20) NOT NULL,
  `expiry_date` TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
