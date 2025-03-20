-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

drop table if exists t1;
set timescaledb.enable_bool_compression = on;
create table t1 (ts int, b bool);
select create_hypertable('t1','ts');
alter table t1 set (timescaledb.compress, timescaledb.compress_orderby = 'ts');
insert into t1 values (1, true);
insert into t1 values (2, false);
insert into t1 values (3, true);
insert into t1 values (4, false);
select compress_chunk(show_chunks('t1'));
select * from t1;



