# my2Collector
My2Collector (my2) is a simple, self contained MySQL statistics collector

##MySQL Statisctics Collector
Most intresting MySQL performance data is available in the GLOBAL_STATUS view,
but MySQL does not mantain any history of it.
My2Collector (my2) is a simple, self contained MySQL statistics collector.
my2 creates in the my2 schema a table that contain the history of performance statistics.
my2 automatically execute every 10 minutes a Stored Routine to collect data.

## Install my2

To install *my2* execute the following command on Your MySQL database:

	`mysql --user=root -pXXX < my2.sql`

#### Database structure

`my2.status` table has the same columns of MySQL GLOBAL_STATUS:
* variable_name
* variable_value

my2.status adds a third column `timest` with the timestamp


#### Available statistics

`my2.status` table contains several performance statistics:
* All numeric GLOBAL_STATUS variables
* All statement execution counters ("statement/sql/%" from events_statements_summary_global_by_event_name)
* Some PROCESSLIST information (eg. USER, HOST, COMMAND, STATE)
* Some summary statistic (eg. sum_timer_wait from events_statements_summary_global_by_event_name)
* Some GLOBAL_VARIABLE variables
* Database size (this statistic is collected daily and not every 10 minutes)
* ...


### Statistics usage

	SELECT variable_value+0 as value, timest as time_sec
	  FROM my.status
	 WHERE variable_name='THREADS_CONNECTED'
	 ORDER BY timest ASC;


## Version support

My2 can connect to any version of MySQL, MariaDB, Percona, or other forks but...
with old MySQL releases many statistics not available.
My2 Collector uses a Scheduled Job which is available since MySQL 5.1.
PROCESSLIST table is available since 5.1.7 while GLOBAL_STATUS is available since 5.1.12.
The PERFORMANCE_SCHEMA was introduced in 5.5 version and greatly enhanched in 5.6 version.
There are many little differences between different MySQL versions: My2 is aware of them
and tries to collect all the information available.
