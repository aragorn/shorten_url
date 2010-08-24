DROP TABLE IF EXISTS `url_translation`;

CREATE TABLE `preview`.`url_translation` (
  `url_id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  `shorten_url` VARCHAR(128) NOT NULL,
  `original_url` VARCHAR(512) NOT NULL,
  `mime_type` VARCHAR(32) NOT NULL,
  `original_title` VARCHAR(128) NOT NULL,
  `website` VARCHAR(128) NOT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT 0,
  `updated_on` TIMESTAMP NOT NULL DEFAULT current_timestamp,
  `has_no_info` BOOLEAN NOT NULL DEFAULT 1,
  `has_original_url` BOOLEAN NOT NULL DEFAULT 0,
  `has_title` BOOLEAN NOT NULL DEFAULT 0,
  `has_text` BOOLEAN NOT NULL DEFAULT 0,
  `is_dead` BOOLEAN NOT NULL DEFAULT 0,
  `is_unreachable` BOOLEAN NOT NULL DEFAULT 0,
  PRIMARY KEY  USING BTREE(`url_id`),
  UNIQUE INDEX `idx_unique_url` USING HASH(`shorten_url`),
  INDEX `idx_created_on` USING BTREE(`created_on`),
  INDEX `idx_updated_on` USING BTREE(`updated_on`),
  INDEX `idx_website` USING HASH(`website`)
)
ENGINE = MyISAM
CHARACTER SET utf8 COLLATE utf8_general_ci;


CREATE TABLE `preview`.`website_names` (
  `website` VARCHAR(128) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT 0,
  `updated_on` TIMESTAMP NOT NULL DEFAULT current_timestamp,
  PRIMARY KEY  USING HASH(`website`),
  INDEX `idx_created_on` USING BTREE(`created_on`),
  INDEX `idx_updated_on` USING BTREE(`updated_on`)
)
ENGINE = MyISAM
CHARACTER SET utf8 COLLATE utf8_general_ci;


CREATE TABLE `preview`.`fetch_queue` (
  `shorten_url` VARCHAR(128) NOT NULL,
  `retry_count` INTEGER UNSIGNED NOT NULL DEFAULT 0,
  `created_on` TIMESTAMP NOT NULL,
  `updated_on` TIMESTAMP NOT NULL,
  `has_no_info` BOOLEAN NOT NULL DEFAULT 1,
  `is_dead` BOOLEAN NOT NULL DEFAULT 0,
  `is_unreachable` BOOLEAN NOT NULL DEFAULT 0,
  `under_progress` BOOLEAN NOT NULL DEFAULT 0,
  PRIMARY KEY (`shorten_url`),
  INDEX `idx_created_on` USING BTREE(`created_on`),
  INDEX `idx_updated_on` USING BTREE(`updated_on`),
  INDEX `idx_under_progress` USING HASH(`under_progress`)
)
ENGINE = MyISAM
CHARACTER SET utf8 COLLATE utf8_general_ci;





