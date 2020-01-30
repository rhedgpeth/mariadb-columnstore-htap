# Hybrid Analytical / Transactional Processing
## Replication Proof Of Concept

### Instructions

This project will build a two node cluster. One MariaDB/ColumnStore server and one MaxScale server. However, before you can begin, please go to the MariaDB website and get your enterprise token. You will need it to run this project.

https://customers.mariadb.com/downloads/token/

#### Prerequisites

* [Git](https://git-scm.com/download/)
* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Virtualbox](https://www.virtualbox.org/wiki/Downloads)
* [Ansible](http://docs.ansible.com/ansible/latest/intro_installation.html)

#### Setup

* `git clone https://github.com/toddstoffel/htap_poc.git`
* `cd htap_poc`
* `vagrant plugin install vagrant-vbguest`
* `vagrant up`
* `ansible-playbook provision.yml -e "mariadb_token=<YOUR_TOKEN_HERE>"`

When provisioning is complete you should have two test schemas (`innodb_schema` and `columnstore_schema`) each containing a table called `orders`.

There will also be an `orders.csv` file located in the `/tmp/` folder on the MariaDB node.

#### Accessing Virtual Machines Directly:

* For MariaDB: `vagrant ssh node1`
* For MaxScale: `vagrant ssh node2`

#### Connecting To The Database From External Client:

* **Host:** 10.10.10.11
* **User:** dba
* **Password:** Demo_password1
* **Port:** 3306

#### Testing Replication:

```
MariaDB [(none)]> LOAD DATA INFILE '/tmp/orders.csv' INTO TABLE innodb_schema.orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';
```

The data should be immediately replicated from `innodb_schema.orders` to `columnstore_schema.orders`.

### Notes
#### The following items are already included in the playbook, they are just listed here for reference:

##### Additional my.cnf settings:

* [`replicate_same_server_id=1`](https://mariadb.com/kb/en/library/mysqld-options/#-replicate-same-server-id)
* [`log_slave_updates=0`](https://mariadb.com/kb/en/library/replication-and-binary-log-system-variables/#log_slave_updates)
* [`binlog_format=STATEMENT`](https://mariadb.com/kb/en/library/replication-and-binary-log-system-variables/#binlog_format)
* [`innodb_buffer_pool_size={{ (ansible_memtotal_mb/4 * 0.66)|round|int }}M`](https://mariadb.com/kb/en/library/innodb-system-variables/#innodb_buffer_pool_size)
* [`columnstore_replication_slave=on`](https://jira.mariadb.org/browse/MCOL-3556)

### Replication Filters

For this version of HTAP, we will rely on the functionality of MaxScale's [Binlog Filter](https://mariadb.com/kb/en/mariadb-maxscale-24-binlog-filter/) in order to **match** specific table names and **rewrite** _source_ to _target_ schema.  

1. InnoDB transactions are written to the MariaDB binary log.
1. MariaDB server becomes a slave of itself and connects through MaxScale.
1. MaxScale matches chosen tables, rewrites schema names, and sends the filtered information back to MariaDB for use in ColumnStore.

**Sample Configuration**:
```
[myreplicationfilter]
type=filter
module=binlogfilter
match=/[.]orders/
rewrite_src=innodb
rewrite_dest=columnstore
```
Note: This example uses a basic regex matching for demonstration purposes only. To learn about more complex regex matching please visit [Regex 101](https://regex101.com).

#### Alter Replicated Tables

Changing replicated tables is done dynamically through the MaxScale filters and the [REST-API](https://mariadb.com/kb/en/mariadb-maxscale-24-filter-resource/).

##### Create A Filter

To create a filter, you would use the POST command with a request body something like this:
```
{
   "data":{
      "id":"foo",
      "type":"filters",
      "attributes":{
         "module":"binlogfilter",
         "parameters":{
            "match":"orders",
            "exclude":"test_orders"
         }
      }
   }
}
```
This can be done in one line or with a text file called 'body.txt' for example:
```
curl -X POST -d '{"data":{"id":"foo","type":"filters","attributes":{"module":"binlogfilter","parameters":{"match":"orders","exclude":"test_orders"}}}}' admin:mariadb@localhost:8989/v1/filters
```
or
```
curl -X POST -d @body.txt admin:mariadb@localhost:8989/v1/filters
```
##### Get Filter Info
```
curl -X GET admin:mariadb@localhost:8989/v1/filters/foo
```
##### Delete A Filter
```
curl -X DELETE admin:mariadb@localhost:8989/v1/filters/foo
```
