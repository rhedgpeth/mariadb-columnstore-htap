CREATE DATABASE IF NOT EXISTS `columnstore_schema`;
CREATE DATABASE IF NOT EXISTS `innodb_schema`;

CREATE TABLE IF NOT EXISTS `columnstore_schema`.`orders` (
	id INT,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50),
	gender VARCHAR(50),
	ip_address VARCHAR(20)
) ENGINE=ColumnStore;

CREATE TABLE IF NOT EXISTS `innodb_schema`.`orders` (
	id INT,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50),
	gender VARCHAR(50),
	ip_address VARCHAR(20)
) ENGINE=InnoDB;
