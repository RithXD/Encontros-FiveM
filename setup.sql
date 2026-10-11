CREATE TABLE IF NOT EXISTS `encontros` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `title` VARCHAR(100) NOT NULL,
  `description` TEXT NULL,
  `location` VARCHAR(100) NOT NULL,
  `coords_x` FLOAT NOT NULL, `coords_y` FLOAT NOT NULL, `coords_z` FLOAT NOT NULL,
  `radius` FLOAT NOT NULL DEFAULT 50.0,
  `height_tolerance` FLOAT NOT NULL DEFAULT 15.0,
  `event_type` VARCHAR(20) NOT NULL DEFAULT 'encontro',
  `area_message` TEXT NULL,
  `blip_sprite` INT NOT NULL DEFAULT 280,
  `npc_x` FLOAT NULL,
  `npc_y` FLOAT NULL,
  `npc_z` FLOAT NULL,
  `npc_w` FLOAT NOT NULL DEFAULT 0.0,
  `reward_item` VARCHAR(100) NOT NULL DEFAULT '',
  `reward_enabled` TINYINT(1) NOT NULL DEFAULT 0,
  `reward_table` VARCHAR(50) NOT NULL DEFAULT 'encontro',
  `reward_custom` LONGTEXT NULL,
  `start_time` BIGINT NOT NULL,
  `duration` INT NOT NULL DEFAULT 60,
  `recurring` TINYINT(1) NOT NULL DEFAULT 0,
  `status` VARCHAR(20) NOT NULL DEFAULT 'scheduled',
  `policy_version` INT NOT NULL DEFAULT 1,
  `started_at` BIGINT NULL,
  `finished_at` BIGINT NULL,
  `routing_bucket` INT NOT NULL DEFAULT 0,
  `status_reason` VARCHAR(255) NULL,
  `finish_token` VARCHAR(80) NULL,
  `recurrence_parent_id` INT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `unique_recurrence_parent` (`recurrence_parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `encontros_reward_claims` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `event_id` INT NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `event_title` VARCHAR(100) NOT NULL DEFAULT '',
  `claimed` TINYINT(1) NOT NULL DEFAULT 0,
  `reward_table` VARCHAR(50) NOT NULL DEFAULT 'encontro',
  `reward_custom` LONGTEXT NULL,
  `reward_item` VARCHAR(100) DEFAULT NULL,
  `reward_amount` INT DEFAULT NULL,
  `policy_version` INT NOT NULL DEFAULT 1,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `status_reason` VARCHAR(255) NULL,
  `drawn_at` BIGINT NULL,
  `expires_at` BIGINT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `claimed_at` TIMESTAMP NULL DEFAULT NULL,
  UNIQUE KEY `unique_event_citizen` (`event_id`, `citizenid`),
  INDEX `idx_citizen_claimed` (`citizenid`, `claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `encontros_attendance` (
  `event_id` INT NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `seconds` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`event_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Installation schema only. Existing databases are upgraded in awaited order by
-- server/schema.lua on startup, followed by the idempotent policy migration in
-- server/main.lua. Do not reset policy_version or drawn_at when reapplying this.
-- All BIGINT time values are Unix seconds; claimed_at keeps its legacy TIMESTAMP.
