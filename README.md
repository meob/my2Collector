# my2Collector
My2Collector (my2) is a simple, self contained MySQL statistics collector

## MySQL Statistics Collector
Most intresting MySQL performance data is available in the GLOBAL_STATUS system table,
but MySQL does not mantain any history of it.
My2Collector (my2) is a simple, self contained MySQL statistics collector.
my2 creates the `my2.status` table that contains the history of performance statistics.
Every 10 minutes my2 automatically executes a Stored Routine to collect data.

## Install my2

To install *my2Collector* execute the following command on Your MySQL database:

	mysql --user=root -pXXX < my2.sql

For security reasons the creation of the user my2 is commented out: change the password and create the user!

my2 user creation is in the last 3 lines of the script.


#### Database structure

`my2.status` table has columns similar to the MySQL GLOBAL_STATUS system table:
* variable_name
* variable_value

my2.status adds a third column `timest` with the timestamp


#### Available statistics

`my2.status` table collects several performance statistics:
* All numeric GLOBAL_STATUS variables
* All statement execution counters ("statement/sql/%" from events_statements_summary_global_by_event_name)
* Some PROCESSLIST information (eg. USER, HOST, COMMAND, STATE)
* Some summary statistic (eg. sum_timer_wait from events_statements_summary_global_by_event_name)
* Some GLOBAL_VARIABLE variables
* Delta values for most used counters using `my2.current` stage table
* Database size (collected daily and not every 10 minutes)
* And other useful stats...


### Statistics usage

	SELECT variable_value+0 as value, timest as time_sec
	  FROM my2.status
	 WHERE variable_name='THREADS_CONNECTED'
	 ORDER BY timest ASC;


## Version support

my2 can connect to any version of MySQL, MariaDB, Percona, or other forks but...
with old MySQL releases many statistics not available.
my2 uses a Scheduled Job which is available since MySQL 5.1 (2008).
PROCESSLIST table is available since 5.1.7 while GLOBAL_STATUS is available since 5.1.12.
The PERFORMANCE_SCHEMA was introduced in 5.5 version and greatly enhanched in 5.6 version.
There are many little differences between different MySQL versions: My2 is aware of them
and tries to collect all the information available. For MySQL 8.0 a different script is provided.
my2 gives its best with MySQL 5.7, MySQL 8.0 and MariaDB 10.x with performance schema enabled.
