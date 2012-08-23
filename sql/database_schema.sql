-- MySQL dump 10.13  Distrib 5.1.63, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: disorder
-- ------------------------------------------------------
-- Server version	5.1.63-0ubuntu0.10.04.1

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
-- Table structure for table `amino_assignment`
--

DROP TABLE IF EXISTS `amino_assignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `amino_assignment` (
  `protein` int(10) unsigned NOT NULL,
  `scores` text NOT NULL,
  `predictor` smallint(3) NOT NULL DEFAULT '0',
  PRIMARY KEY (`protein`,`predictor`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `binding_assignment`
--

DROP TABLE IF EXISTS `binding_assignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `binding_assignment` (
  `protein` int(10) unsigned NOT NULL,
  `start` smallint(5) unsigned NOT NULL,
  `end` smallint(5) unsigned NOT NULL,
  `predictor` smallint(3) DEFAULT NULL,
  `binding` int(20) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`binding`),
  KEY `binding_protein` (`protein`)
) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dis_assignment`
--

DROP TABLE IF EXISTS `dis_assignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dis_assignment` (
  `protein` int(10) unsigned NOT NULL,
  `start` smallint(5) unsigned NOT NULL,
  `end` smallint(5) unsigned NOT NULL,
  `predictor` smallint(3) NOT NULL,
  `disorder` int(20) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`disorder`),
  KEY `disordered_protein` (`protein`)
) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dis_consensus_assignment`
--

DROP TABLE IF EXISTS `dis_consensus_assignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dis_consensus_assignment` (
  `protein` int(10) unsigned NOT NULL,
  `start` smallint(5) unsigned NOT NULL,
  `end` smallint(5) unsigned NOT NULL,
  `cutoff` float(5,4) unsigned NOT NULL,
  PRIMARY KEY (`protein`,`start`,`cutoff`),
  KEY `disordered_consensus_protein` (`protein`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `feedback`
--

DROP TABLE IF EXISTS `feedback`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feedback` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `name` varchar(40) NOT NULL DEFAULT '',
  `email` varchar(40) NOT NULL DEFAULT '',
  `comment` text NOT NULL,
  `contact_email` tinyint(1) NOT NULL DEFAULT '0',
  `type` char(10) DEFAULT NULL,
  `is_published` tinyint(1) NOT NULL DEFAULT '0',
  `is_new` tinyint(1) NOT NULL DEFAULT '1',
  `is_bug` tinyint(1) DEFAULT NULL,
  `is_new_feature` tinyint(1) DEFAULT NULL,
  `is_help_request` tinyint(1) DEFAULT NULL,
  `liked` int(5) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome`
--

DROP TABLE IF EXISTS `genome`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome` (
  `genome` char(3) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
  `name` varchar(150) NOT NULL,
  `include` enum('y','s','1','n','m','p') NOT NULL DEFAULT 'n',
  `excuse` varchar(15) NOT NULL DEFAULT '',
  `domain` enum('E','B','A','P','C','V','-') NOT NULL DEFAULT '-',
  `comment` varchar(255) NOT NULL DEFAULT '',
  `taxonomy` varchar(512) NOT NULL DEFAULT '',
  `taxon_id` mediumint(8) unsigned DEFAULT NULL,
  `download_link` varchar(512) NOT NULL DEFAULT '',
  `download_date` date NOT NULL DEFAULT '1970-01-01',
  `gene_link` varchar(512) NOT NULL DEFAULT '',
  `homepage` varchar(255) NOT NULL DEFAULT '',
  `password` varchar(9) NOT NULL DEFAULT '',
  `parse` varchar(64) NOT NULL DEFAULT '',
  `order1` smallint(5) unsigned DEFAULT NULL,
  `supfam` char(4) DEFAULT '1.73',
  `order2` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`genome`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hist_percent_protein_disordered`
--

DROP TABLE IF EXISTS `hist_percent_protein_disordered`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hist_percent_protein_disordered` (
  `predictor` smallint(3) NOT NULL DEFAULT '0',
  `percent` double(17,0) NOT NULL DEFAULT '0',
  `frequency` bigint(21) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hist_region_size_disordered`
--

DROP TABLE IF EXISTS `hist_region_size_disordered`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hist_region_size_disordered` (
  `predictor` smallint(3) NOT NULL,
  `region_size` bigint(13) DEFAULT NULL,
  `frequency` bigint(21) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `people`
--

DROP TABLE IF EXISTS `people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `people` (
  `person` smallint(3) unsigned NOT NULL AUTO_INCREMENT,
  `title` char(10) NOT NULL,
  `first_name` char(20) NOT NULL DEFAULT '',
  `second_name` char(20) NOT NULL DEFAULT '',
  `email` char(50) NOT NULL DEFAULT '',
  `affiliation` char(250) NOT NULL DEFAULT '',
  `website` char(200) DEFAULT NULL,
  `bio` text,
  `address` text,
  `display_order` smallint(3) DEFAULT NULL,
  PRIMARY KEY (`person`)
) ENGINE=MyISAM AUTO_INCREMENT=12 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `predictor`
--

DROP TABLE IF EXISTS `predictor`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `predictor` (
  `predictor` smallint(3) NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `description` text,
  `comments` text,
  `citation` text,
  `url` varchar(2000) DEFAULT NULL,
  `colour` char(6) NOT NULL,
  `has_probs` tinyint(1) NOT NULL,
  `private_group` int(11) NOT NULL DEFAULT '0',
  `type` enum('disorder','binding','structure','transmem','coil') NOT NULL DEFAULT 'disorder',
  `loaded_on` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated_on` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP,
  `display_order` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`predictor`)
) ENGINE=MyISAM AUTO_INCREMENT=12 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `predictor_coverage`
--

DROP TABLE IF EXISTS `predictor_coverage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `predictor_coverage` (
  `protein` int(10) unsigned NOT NULL,
  `predictor` smallint(3) NOT NULL DEFAULT '0',
  `num_aminos_disordered` smallint(5) unsigned NOT NULL,
  `percent_protein_disordered` float(7,4) unsigned NOT NULL,
  `num_aminos_conflicted` smallint(5) unsigned NOT NULL,
  `percent_predicted_conflicted` float(7,4) unsigned NOT NULL,
  `percent_protein_conflicted` float(7,4) unsigned NOT NULL,
  PRIMARY KEY (`protein`,`predictor`),
  KEY `predictor_coverage_protein` (`protein`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `predictor_people`
--

DROP TABLE IF EXISTS `predictor_people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `predictor_people` (
  `predictor` smallint(3) NOT NULL DEFAULT '0',
  `person` smallint(3) unsigned NOT NULL DEFAULT '0',
  `is_author` tinyint(1) NOT NULL DEFAULT '1',
  `made_predictions` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`predictor`,`person`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `predictors_compared`
--

DROP TABLE IF EXISTS `predictors_compared`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `predictors_compared` (
  `protein` int(10) unsigned NOT NULL,
  `pred1` smallint(3) NOT NULL,
  `pred2` smallint(3) NOT NULL,
  `num_aminos_agree` smallint(5) unsigned NOT NULL,
  `percent_pred1_agree` float(7,4) unsigned NOT NULL,
  `percent_protein_agree` float(7,4) unsigned NOT NULL,
  `num_aminos_overlapped_pred1` smallint(5) unsigned NOT NULL,
  `percent_pred1_overlapped` float(7,4) unsigned NOT NULL,
  `percent_protein_overlapped` float(7,4) unsigned NOT NULL,
  PRIMARY KEY (`protein`,`pred1`,`pred2`),
  KEY `compared_protein` (`protein`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `protein`
--

DROP TABLE IF EXISTS `protein`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `protein` (
  `genome` char(3) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
  `seqid` varchar(100) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `protein` int(11) unsigned NOT NULL,
  `comment` text,
  PRIMARY KEY (`genome`,`seqid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `protein_consensus_conflict`
--

DROP TABLE IF EXISTS `protein_consensus_conflict`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `protein_consensus_conflict` (
  `protein` int(10) unsigned NOT NULL,
  `consensus` text,
  `conflict` text,
  PRIMARY KEY (`protein`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-08-23 15:04:23
