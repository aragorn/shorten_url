-- MySQL dump 10.11
--
-- Host: localhost    Database: preview
-- ------------------------------------------------------
-- Server version	5.0.77-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `fetch_queue`
--

DROP TABLE IF EXISTS `fetch_queue`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `fetch_queue` (
  `shorten_url` varchar(128) NOT NULL,
  `retry_count` int(10) unsigned NOT NULL default '0',
  `created_on` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `updated_on` timestamp NOT NULL default '0000-00-00 00:00:00',
  `has_no_info` tinyint(1) NOT NULL default '1',
  `is_dead` tinyint(1) NOT NULL default '0',
  `is_unreachable` tinyint(1) NOT NULL default '0',
  `under_progress` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`shorten_url`),
  KEY `idx_created_on` USING BTREE (`created_on`),
  KEY `idx_updated_on` USING BTREE (`updated_on`),
  KEY `idx_under_progress` USING HASH (`under_progress`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `url_translation`
--

DROP TABLE IF EXISTS `url_translation`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `url_translation` (
  `url_id` int(10) unsigned NOT NULL auto_increment,
  `shorten_url` varchar(128) NOT NULL,
  `original_url` varchar(512) NOT NULL,
  `mime_type` varchar(64) NOT NULL,
  `original_title` varchar(128) NOT NULL,
  `website` varchar(128) NOT NULL,
  `created_on` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_on` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `has_no_info` tinyint(1) NOT NULL default '1',
  `has_original_url` tinyint(1) NOT NULL default '0',
  `has_title` tinyint(1) NOT NULL default '0',
  `has_image` tinyint(1) NOT NULL default '0',
  `is_dead` tinyint(1) NOT NULL default '0',
  `is_unreachable` tinyint(1) NOT NULL default '0',
  `http_code` char(3) NOT NULL default '0',
  `source` char(12) NOT NULL,
  PRIMARY KEY  USING BTREE (`url_id`),
  UNIQUE KEY `idx_unique_url` USING HASH (`shorten_url`),
  KEY `idx_created_on` USING BTREE (`created_on`),
  KEY `idx_updated_on` USING BTREE (`updated_on`),
  KEY `idx_website` USING HASH (`website`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `website_names`
--

DROP TABLE IF EXISTS `website_names`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `website_names` (
  `website` varchar(128) NOT NULL,
  `name` varchar(128) NOT NULL,
  `created_on` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_on` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  USING HASH (`website`),
  KEY `idx_created_on` USING BTREE (`created_on`),
  KEY `idx_updated_on` USING BTREE (`updated_on`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2010-08-24  8:34:37
