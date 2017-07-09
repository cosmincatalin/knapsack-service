CREATE DATABASE knapsack;
USE knapsack;
CREATE TABLE `problems` (
  `id` varchar(36) NOT NULL DEFAULT '',
  `problem` text NOT NULL,
  `solution` text,
  `created` datetime DEFAULT CURRENT_TIMESTAMP,
  `solved` datetime DEFAULT NULL,
  `wontsolve` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;