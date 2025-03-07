-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

\set ECHO errors
create view chunk_info as
with
   chunks as (
      select format('%I.%I', ch.schema_name, ch.table_name)::regclass as chunk,
             format('%I.%I', cc.schema_name, cc.table_name)::regclass as compressed_chunk
        from _timescaledb_catalog.chunk ch
        join _timescaledb_catalog.chunk cc
          on ch.compressed_chunk_id = cc.id),
   parents as (
      select inh.inhparent::regclass as hypertable,
	     cl.oid::regclass as chunk,
	     am.amname
	from pg_class cl
	join pg_am am on cl.relam = am.oid
	join pg_inherits inh on inh.inhrelid = cl.oid)
select hypertable, chunk, compressed_chunk, amname from chunks join parents using (chunk);

\ir include/hypercore_helpers.sql
\set ECHO all

-- Disable incremental sort to make tests stable
set enable_incremental_sort = false;
select setseed(1);

create table readings(
       time timestamptz not null unique,
       location int not null,
       device int not null,
       temp numeric(4,1),
       humidity float,
       jdata jsonb
);

select create_hypertable('readings', by_range('time', '1d'::interval));

alter table readings
      set (timescaledb.compress_orderby = 'time',
	   timescaledb.compress_segmentby = 'device');

insert into readings (time, location, device, temp, humidity, jdata)
select t, ceil(random()*10), ceil(random()*30), random()*40, random()*100, '{"a":1,"b":2}'::jsonb
from generate_series('2022-06-01'::timestamptz, '2022-06-04'::timestamptz, '5m') t;

select compress_chunk(show_chunks('readings'), hypercore_use_access_method => true);

select chunk, amname from chunk_info where hypertable = 'readings'::regclass;

-- Pick a chunk to play with that is not the first chunk. This is
-- mostly a precaution to make sure that there is no bias towards the
-- first chunk and we could just as well pick the first chunk.
select chunk from show_chunks('readings') x(chunk) limit 1 offset 3 \gset

----------------------------------------------------------------
-- Test ALTER TABLE .... ALTER COLUMN commands

-- This should fail since "location" is NOT NULL
\set ON_ERROR_STOP 0
insert into readings(time,device,temp,humidity,jdata)
values ('2024-01-01 00:00:10', 1, 99.0, 99.0, '{"magic": "yes"}'::jsonb);
\set ON_ERROR_STOP 1

-- Test altering column definitions to drop NOT NULL and check that it
-- propagates to the chunks. We just pick one chunk here and check
-- that the setting propagates.
alter table readings alter column location drop not null;
\d readings
\d :chunk

-- This should now work since we allow NULL values
insert into readings(time,device,temp,humidity,jdata)
values ('2024-01-01 00:00:10', 1, 99.0, 99.0, '{"magic": "yes"}'::jsonb);

select count(*) from readings where location is null;
select compress_chunk(show_chunks('readings'), hypercore_use_access_method => true);
select count(*) from readings where location is null;

-- We insert another row with nulls, that will end up in the
-- non-compressed region.
insert into readings(time,device,temp,humidity,jdata)
values ('2024-01-02 00:00:10', 1, 66.0, 66.0, '{"magic": "more"}'::jsonb);

-- We should not be able to set the not null before we have removed
-- the null rows in the table. This works for hypercore-compressed
-- chunks but not for heap-compressed chunks.
\set ON_ERROR_STOP 0
alter table readings alter column location set not null;
\set ON_ERROR_STOP 1
delete from readings where location is null;
-- Compress the data to make sure that we are not working on
-- non-compressed data.
select compress_chunk(show_chunks('readings'), hypercore_use_access_method => true);
select count(*) from readings where location is null;
alter table readings alter column location set not null;
\d readings
\d :chunk
select count(*) from readings where location is null;

----------------------------------------------------------------
-- TRUNCATE test
-- We keep the truncate test last in the file to avoid having to
-- re-populate it.

-- Insert some extra data to get some non-compressed data as
-- well. This checks that truncate will deal with with write-store
-- (WS) and read-store (RS)
insert into readings (time, location, device, temp, humidity, jdata)
select t, ceil(random()*10), ceil(random()*30), random()*40, random()*100, '{"a":1,"b":2}'::jsonb
from generate_series('2022-06-01 00:01:00'::timestamptz, '2022-06-04'::timestamptz, '5m') t;

-- Check that the number of bytes in the table before and after the
-- truncate.
--
-- Note that a table with a toastable attribute will always have a
-- toast table assigned, so pg_table_size() shows one page allocated
-- since this includes the toast table.
select pg_table_size(chunk) as chunk_size,
       pg_table_size(compressed_chunk) as compressed_chunk_size
  from chunk_info
 where chunk = :'chunk'::regclass;
truncate :chunk;
select pg_table_size(chunk) as chunk_size,
       pg_table_size(compressed_chunk) as compressed_chunk_size
  from chunk_info
 where chunk = :'chunk'::regclass;

-- We test TRUNCATE on a hypertable as well, but truncating a
-- hypertable is done by deleting all chunks, not by truncating each
-- chunk.
select (select count(*) from readings) tuples,
       (select count(*) from show_chunks('readings')) chunks;
truncate readings;
select (select count(*) from readings) tuples,
       (select count(*) from show_chunks('readings')) chunks;
