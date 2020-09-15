-- Get block stats
-- :stats_block_times
with month_interval as (
    select to_timestamp(time) as timestamp,
           time - (lead(time) over (order by height desc)) as diff_time
    from blocks
    where to_timestamp(time) > (now() - '1 month'::interval)
),
week_interval as (
    select * from month_interval where timestamp > (now() - '1 week'::interval)
),
day_interval as (
    select * from week_interval where timestamp > (now() - '24 hour'::interval)
),
hour_interval as (
    select * from day_interval where timestamp > (now() - '1 hour'::interval)
)
select
    (select avg(diff_time) from hour_interval)::float as last_hour_avg,
    (select avg(diff_time) from day_interval)::float as last_day_avg,
    (select avg(diff_time) from week_interval)::float as last_week_avg,
    (select avg(diff_time) from month_interval)::float as last_month_avg,
    (select stddev(diff_time) from hour_interval)::float as last_hour_stddev,
    (select stddev(diff_time) from day_interval)::float as last_day_stddev,
    (select stddev(diff_time) from week_interval)::float as last_week_stddev,
    (select stddev(diff_time) from month_interval)::float as last_month_stddev


-- Get election times
-- :stats_election_times
with month_interval as (
    select to_timestamp(time) as timestamp,
           time - (lead(time) over (order by block desc)) as diff_time
    from transactions
    where to_timestamp(time) > (now() - '1 month'::interval)
    and type = 'consensus_group_v1'
),
week_interval as (
    select * from month_interval where timestamp > (now() - '1 week'::interval)
),
day_interval as (
    select * from week_interval where timestamp > (now() - '24 hour'::interval)
),
hour_interval as (
    select * from day_interval where timestamp > (now() - '1 hour'::interval)
)
select
    (select avg(diff_time) from hour_interval)::float as last_hour_avg,
    (select avg(diff_time) from day_interval)::float as last_day_avg,
    (select avg(diff_time) from week_interval)::float as last_week_avg,
    (select avg(diff_time) from month_interval)::float as last_month_avg,
    (select stddev(diff_time) from hour_interval)::float as last_hour_stddev,
    (select stddev(diff_time) from day_interval)::float as last_day_stddev,
    (select stddev(diff_time) from week_interval)::float as last_week_stddev,
    (select stddev(diff_time) from month_interval)::float as last_month_stddev

-- Get all global count stats
-- :stats_counts
select name, value from stats_inventory

-- Get currently active and last day challenge count
-- :stats_challenges
with block_poc_range as (
    select greatest(0, max(height) - coalesce((select value::bigint from vars_inventory where name = 'poc_challenge_interval'), 30)) as min,
           max(height)
    from blocks
),
block_last_day_range as (
    select min(height), max(height) from blocks
    where timestamp between now() - '24 hour'::interval and now()
),
last_day_challenges as (
    select hash from transactions
    where block between (select min from block_last_day_range) and (select max from block_last_day_range)
          and type = 'poc_receipts_v1'
),
poc_receipts as (
    select hash, fields->>'onion_key_hash' as challenge_id from transactions
    where block between (select min from block_poc_range) and (select max from block_poc_range)
          and type = 'poc_receipts_v1'
),
poc_requests as (
    select hash, fields->>'onion_key_hash' as challenge_id from transactions
    where block between (select min from block_poc_range) and (select max from block_poc_range)
          and type = 'poc_request_v1'
)
select * from
    (select count(*) as active_challenges from poc_requests
     where challenge_id not in (select challenge_id from poc_receipts)) as active,
    (select count(*) as last_day_challenges from last_day_challenges) as last_day

-- Get token supply
-- :stats_token_supply
select (sum(balance) / 100000000)::float as token_supply from account_inventory

-- State channel details
-- :stats_state_channels
 with month_interval as (
     select to_timestamp(b.time) as timestamp,
        state_channel_counts(t.type, t.fields) as counts
     from blocks b inner join transactions t on b.height = t.block
     where to_timestamp(b.time) > (now() - '1 month'::interval)
         and t.type = 'state_channel_close_v1'
 ),
 week_interval as (
     select * from month_interval where timestamp > (now() - '1 week'::interval)
 ),
 day_interval as (
     select * from week_interval where timestamp > (now() - '24 hour'::interval)
 )
 select
     (select sum((t.counts).num_dcs) as num_dcs from day_interval t)::bigint as last_day_dcs,
     (select sum((t.counts).num_packets) as num_dcs from day_interval t)::bigint as last_day_packets,
     (select sum((t.counts).num_dcs) as num_dcs from week_interval t)::bigint as last_week_dcs,
     (select sum((t.counts).num_packets) as num_dcs from week_interval t)::bigint as last_week_packets,
     (select sum((t.counts).num_dcs) as num_dcs from month_interval t)::bigint as last_month_dcs,
     (select sum((t.counts).num_packets) as num_dcs from month_interval t)::bigint as last_month_packets
