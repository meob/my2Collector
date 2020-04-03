-- by mail@meo.bogliolo.name
-- My2 Collector
-- 0.0.1  2013-02-14 First version for MySQL 5.6
-- 0.0.6  2017-04-01 DBCPU as SUM_TIMER_WAIT from events_statements_summary_global_by_event_name
-- 0.0.7  2017-11-01 bug fixed (0 as first value for delta), MariaDB 10.2 support, new custom statistics
-- 0.0.7a 2018-02-18 substr(EVENT_NAME,15) --> substr(EVENT_NAME,15,60)
-- 0.0.8  2018-04-01 MySQL v.8.0 support
-- 0.0.9a 2018-08-15 Delta statistics (useful for Grafana), (a) got some useful global_variable
-- 0.0.10 2018-10-31 Replication Lag (with multi-threaded slaves), (a) changed a variable name
-- 0.0.11 2019-05-05 Small changes (uppercase variables, enable events)
-- 0.0.12 2020-01-01 Host column, MariaDB 10.x better support

-- Create Database, Tables, Stored Routines and Jobs for My2 dashboard
create database IF NOT EXISTS my2;
use my2;
CREATE TABLE IF NOT EXISTS status (
  VARIABLE_NAME varchar(64) CHARACTER SET utf8 NOT NULL DEFAULT '',
  VARIABLE_VALUE varchar(1024) CHARACTER SET utf8 DEFAULT NULL,
  HOST varchar(128) CHARACTER SET utf8 DEFAULT 'MyHost',   -- concat(@@hostname, ':', @@port),
  TIMEST timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS current (
  VARIABLE_NAME varchar(64) CHARACTER SET utf8 NOT NULL DEFAULT '',
  VARIABLE_VALUE varchar(1024) CHARACTER SET utf8 DEFAULT NULL
) ENGINE=InnoDB;

ALTER TABLE status
 ADD unique KEY idx01 (VARIABLE_NAME,timest,host);
-- delete from my2.status where VARIABLE_NAME like 'PROCESSES_HOSTS.%';
-- update my2.status set variable_value=0, timest=timest where VARIABLE_NAME like '%-d' and variable_value<0;
ALTER TABLE current
 ADD unique KEY idx02 (VARIABLE_NAME);

DROP PROCEDURE IF EXISTS collect_stats;
DELIMITER // ;
CREATE PROCEDURE collect_stats()
BEGIN
DECLARE a datetime;
DECLARE v varchar(10);
-- set sql_log_bin = 0;
set a=now();
select substr(version(),1,3) into v;

if v='5.7' OR v='8.0' then
  insert into my2.status(variable_name,variable_value,timest) 
   select upper(variable_name),variable_value, a
     from performance_schema.global_status
    where variable_value REGEXP '^-*[[:digit:]]+(\.[[:digit:]]+)?$'
      and variable_name not like 'Performance_schema_%'
      and variable_name not like 'SSL_%';
  insert into my2.status(variable_name,variable_value,timest) 
   SELECT 'REPLICATION_MAX_WORKER_TIME', coalesce(max(PROCESSLIST_TIME), 0.1), a
     FROM performance_schema.threads
    WHERE (NAME = 'thread/sql/slave_worker'
            AND (PROCESSLIST_STATE IS NULL
                  OR PROCESSLIST_STATE != 'Waiting for an event from Coordinator'))
       OR NAME = 'thread/sql/slave_sql';
--  *** Comment the following 4 lines with 8.0  ***
 else
  insert into my2.status(variable_name,variable_value,timest) 
   select variable_name,variable_value,a
     from information_schema.global_status;
end if;
insert into my2.status(variable_name,variable_value,timest) 
 select concat('PROCESSES.',user),count(*),a
   from information_schema.processlist
  group by user;
insert into my2.status(variable_name,variable_value,timest) 
 select concat('PROCESSES_HOSTS.',SUBSTRING_INDEX(host,':',1)),count(*),a
   from information_schema.processlist
  group by concat('PROCESSES_HOSTS.',SUBSTRING_INDEX(host,':',1));
insert into my2.status(variable_name,variable_value,timest) 
 select concat('PROCESSES_COMMAND.',command),count(*),a
   from information_schema.processlist
  group by concat('PROCESSES_COMMAND.',command);
insert into my2.status(variable_name,variable_value,timest) 
 select substr(concat('PROCESSES_STATE.',state),1,64),count(*),a
   from information_schema.processlist
  group by substr(concat('PROCESSES_STATE.',state),1,64);
if v='5.6' OR v='5.7' OR v='8.0' OR v='10.' then
  insert into my2.status(variable_name,variable_value,timest) 
   SELECT 'SUM_TIMER_WAIT', sum(sum_timer_wait*1.0), a
     FROM performance_schema.events_statements_summary_global_by_event_name;
end if;

-- Delta values
if v='5.7' OR v='8.0' then
  insert into my2.status(variable_name,variable_value,timest) 
   select concat(upper(s.variable_name),'-d'), greatest(s.variable_value-c.variable_value,0), a
     from performance_schema.global_status s, my2.current c
    where s.variable_name=c.variable_name;
  insert into my2.status(variable_name,variable_value,timest) 
   SELECT concat('COM_',upper(substr(s.EVENT_NAME,15,58)), '-d'), greatest(s.COUNT_STAR-c.variable_value,0), a
     FROM performance_schema.events_statements_summary_global_by_event_name s, my2.current c
    WHERE s.EVENT_NAME LIKE 'statement/sql/%'
      AND s.EVENT_NAME = c.variable_name;
  insert into my2.status(variable_name,variable_value,timest)
   SELECT 'SUM_TIMER_WAIT-d', sum(sum_timer_wait*1.0)-c.variable_value, a
     FROM performance_schema.events_statements_summary_global_by_event_name, my2.current c
    WHERE c.variable_name='SUM_TIMER_WAIT';
  insert into my2.status(variable_name, variable_value, timest) 
   select 'REPLICATION_CONNECTION_STATUS', if(SERVICE_STATE='ON', 1, 0),a
     from performance_schema.replication_connection_status;
  insert into my2.status(variable_name, variable_value, timest) 
   select 'REPLICATION_APPLIER_STATUS', if(SERVICE_STATE='ON', 1, 0),a
     from performance_schema.replication_applier_status;

  delete from my2.current;
  insert into my2.current(variable_name,variable_value) 
   select upper(variable_name),variable_value+0
     from performance_schema.global_status
    where variable_value REGEXP '^-*[[:digit:]]+(\.[[:digit:]]+)?$'
      and variable_name not like 'Performance_schema_%'
      and variable_name not like 'SSL_%';
  insert into my2.current(variable_name,variable_value) 
   SELECT substr(EVENT_NAME,1,40), COUNT_STAR
     FROM performance_schema.events_statements_summary_global_by_event_name
    WHERE EVENT_NAME LIKE 'statement/sql/%';
  insert into my2.current(variable_name,variable_value) 
   SELECT 'SUM_TIMER_WAIT', sum(sum_timer_wait*1.0)
     FROM performance_schema.events_statements_summary_global_by_event_name;

  insert into my2.current(variable_name,variable_value) 
   select concat('PROCESSES_COMMAND.',command),count(*)
     from information_schema.processlist
    group by concat('PROCESSES_COMMAND.',command);
  insert into my2.current(variable_name,variable_value) 
   select upper(variable_name),variable_value
     from performance_schema.global_variables
    where variable_name in ('max_connections', 'innodb_buffer_pool_size', 'query_cache_size', 
                            'innodb_log_buffer_size', 'key_buffer_size', 'table_open_cache');
 else
  insert into my2.status(variable_name,variable_value,timest) 
   select concat(upper(s.variable_name),'-d'), greatest(s.variable_value-c.variable_value,0), a
     from information_schema.global_status s, my2.current c
    where s.variable_name=c.variable_name;
  delete from my2.current;
  insert into my2.current(variable_name,variable_value) 
   select upper(variable_name),variable_value+0
     from information_schema.global_status
    where variable_value REGEXP '^-*[[:digit:]]+(\.[[:digit:]]+)?$'
      and variable_name not like 'Performance_schema_%'
      and variable_name not like 'SSL_%';
  insert into my2.current(variable_name,variable_value) 
   select upper(variable_name),variable_value
     from information_schema.global_variables
    where variable_name in ('max_connections', 'innodb_buffer_pool_size', 'query_cache_size', 
                            'innodb_log_buffer_size', 'key_buffer_size', 'table_open_cache');
end if;

-- set sql_log_bin = 1;
END //
DELIMITER ; //

-- Collect daily statistics on space usage and delete old statistics (older than 62 days, 1 year for DB size)
DROP PROCEDURE IF EXISTS collect_daily_stats;
DELIMITER // ;
CREATE PROCEDURE collect_daily_stats()
BEGIN
DECLARE a datetime;
-- set sql_log_bin = 0;
set a=now();
insert into my2.status(variable_name,variable_value,timest)
 select concat('SIZEDB.',table_schema), sum(data_length+index_length), a
   from information_schema.tables group by table_schema;
insert into my2.status(variable_name,variable_value,timest) 
 select 'SIZEDB.TOTAL', sum(data_length+index_length), a
   from information_schema.tables;
delete from my2.status where timest < date_sub(now(), INTERVAL 62 DAY) and variable_name <>'SIZEDB.TOTAL';
delete from my2.status where timest < date_sub(now(), INTERVAL 365 DAY);
-- set sql_log_bin = 1;
END //
DELIMITER ; //

-- The event scheduler must also be activated in the my.cnf (event_scheduler=1)
set global event_scheduler=1;

-- set sql_log_bin = 0;
DROP EVENT IF EXISTS collect_stats;
CREATE EVENT collect_stats
    ON SCHEDULE EVERY 10 Minute
    DO call collect_stats();
DROP EVENT IF EXISTS collect_daily_stats;
CREATE EVENT collect_daily_stats
    ON SCHEDULE EVERY 1 DAY
    DO call collect_daily_stats();

ALTER EVENT collect_stats ENABLE;
ALTER EVENT collect_daily_stats ENABLE;
-- set sql_log_bin = 1;

-- Use a specific user (suggested)
-- create user my2@'%' identified by 'P1e@seCh@ngeMe';
-- grant all on my2.* to my2@'%';
