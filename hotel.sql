CREATE DATABASE hotel;
USE hotel;
-- The first step is to create a copy of the table being used. This is to prevent possible damage to the dataset in situations of any error from my end 
create table hotel_copy
like hotel_reservation_dataset;

insert into hotel_copy
select *
from hotel_reservation_dataset;

SELECT * FROM hotel_copy LIMIT 10;

-- After this, the next step is to solve the problem statements. 
-- 1. What is the total number of reservations in the dataset? 
select count(Booking_ID) as total_number_of_reservations
from hotel_copy;

-- 2 Which meal plan is the most popular among guests?
select type_of_meal_plan, count(type_of_meal_plan) as popular_meal_plan
from hotel_copy
group by type_of_meal_plan
order by popular_meal_plan desc -- FIX: without ORDER BY, LIMIT 1 returns an arbitrary group
limit 1;

-- 3. What is the average price per room for reservations involving children?
-- FIX: the question asks for one overall figure, so no GROUP BY
select count(Booking_ID) as num_reservations, round(avg(avg_price_per_room), 2) as avg_price_with_children
from hotel_copy
where no_of_children > 0;

-- 4. How many reservations were made for the year 20XX (replace XX with the desired year)?
-- The Column (arrival_date) was stored as a text. To run a query that finds the year 2018, arrival_date has to be changed to a `date` column
-- FIX: every date in the file uses dashes (e.g. 02-10-2017), so only the '%d-%m-%Y' format is needed.
-- The earlier '%d/%m/%Y' update could set the whole column to NULL, so it has been removed.
SET SQL_SAFE_UPDATES = 0;

UPDATE hotel_copy
SET arrival_date = STR_TO_DATE(arrival_date, '%d-%m-%Y');

SET SQL_SAFE_UPDATES = 1; -- Re-enable safe mode after update

-- After changing the str to date, the next step is to apply the change to the column in the table so it can reflect on the dataset
alter table hotel_copy
modify column arrival_date date;

-- Once that has been done, the next step is to solve the problem statement
select arrival_date
from hotel_copy;

select year(arrival_date), Booking_ID
from hotel_copy
where year(arrival_date) = 2018 
;

select year(arrival_date), count(Booking_ID) as reservation_numbers
from hotel_copy
where year(arrival_date) = 2018
group by year(arrival_date) 
;

-- 5. What is the most commonly booked room type?
select room_type_reserved, COUNT(Booking_ID) as num_bookings
from hotel_copy
group by room_type_reserved
order by num_bookings desc
limit 1;

-- 6. How many reservations fall on a weekend (no_of_weekend_nights > 0)?
select count(Booking_ID) as weekend_reservations
from hotel_copy
where no_of_weekend_nights > 0
;

-- 7. What is the highest and lowest lead time for reservations?
select max(lead_time) as max_lead_time, min(lead_time) as min_lead_time
from hotel_copy;

-- 8. What is the most common market segment type for reservations?
select market_segment_type, count(market_segment_type) as market_segment
from hotel_copy
group by market_segment_type
order by market_segment desc
limit 1;

-- 9. How many reservations have a booking status of "Confirmed"?
select count(Booking_ID) as confirmed_booking_status
from hotel_copy
where booking_status = 'Not_Canceled' -- NOTE: no 'Confirmed' label exists; Not_Canceled is treated as confirmed
;

-- 10. What is the total number of adults and children across all reservations?
select sum(no_of_adults) as total_adults, sum(no_of_children) as total_children
from hotel_copy;

-- 11. What is the average number of weekend nights for reservations involving children?
select avg(no_of_weekend_nights) as avg_children_weekend_nights
from hotel_copy
where no_of_children > 0
;

-- 12. How many reservations were made in each month of the year?
select month(arrival_date) as `month`, year(arrival_date) as `year`, count(Booking_ID) as monthly_reservations
from hotel_copy
group by month(arrival_date), year(arrival_date)
order by `year`, `month`; -- FIX: sorted so the trend reads in date order

-- 13. What is the average number of nights (both weekend and weekday) spent by guests for each room type?
select room_type_reserved, avg(no_of_week_nights + no_of_weekend_nights)  as avg_week_nights
from hotel_copy
group by room_type_reserved;

-- 14. For reservations involving children, what is the most common room type, and what is the average price for that room type?
select room_type_reserved, count(Booking_ID) as children_reserve, avg(avg_price_per_room) as avg_price
from hotel_copy
where no_of_children > 0
group by room_type_reserved 
order by children_reserve desc -- FIX: DESC returns the most common, not the least common
limit 1;

-- 15. Find the market segment type that generates the highest average price per room. 
select market_segment_type, avg(avg_price_per_room) as avg_price
from hotel_copy
group by market_segment_type
order by avg_price desc
limit 1 ; -- NOTE: Online (112.46) wins; Aviation (110) is a single booking, so small segments can skew averages

select * from hotel_copy;


-- =====================================================================
-- PART 2: CANCELLATION ANALYSIS
-- =====================================================================

-- 16. What is the overall cancellation rate?
select count(*) as total_bookings,
       sum(booking_status = 'Canceled') as cancelled,
       round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct
from hotel_copy;

-- 17. Cancellation rate by market segment
select market_segment_type,
       count(*) as bookings,
       sum(booking_status = 'Canceled') as cancelled,
       round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct
from hotel_copy
group by market_segment_type
order by cancellation_rate_pct desc;

-- 18. Cancellation rate by lead-time band (CASE bucketing)
select case
         when lead_time <= 7   then '1. 0-7 days'
         when lead_time <= 30  then '2. 8-30 days'
         when lead_time <= 90  then '3. 31-90 days'
         when lead_time <= 180 then '4. 91-180 days'
         else                       '5. 181+ days'
       end as lead_time_band,
       count(*) as bookings,
       round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct
from hotel_copy
group by lead_time_band
order by lead_time_band;

-- 19. Average lead time and price: cancelled vs kept bookings
select booking_status,
       round(avg(lead_time), 1) as avg_lead_time,
       round(avg(avg_price_per_room), 2) as avg_price
from hotel_copy
group by booking_status;

-- 20. Cancellation rate by price band
select case
         when avg_price_per_room < 80   then '1. under 80'
         when avg_price_per_room <= 110 then '2. 80-110'
         when avg_price_per_room <= 140 then '3. 110-140'
         else                                '4. 140+'
       end as price_band,
       count(*) as bookings,
       round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct
from hotel_copy
group by price_band
order by price_band;

-- 21. Share of booked room revenue lost to cancellations (CTE)
-- Booked value = total nights x average room price (an estimate, not actual payments)
with booking_value as (
    select booking_status,
           (no_of_weekend_nights + no_of_week_nights) * avg_price_per_room as booked_value
    from hotel_copy
)
select round(sum(booked_value), 0) as total_booked_value,
       round(sum(case when booking_status = 'Canceled' then booked_value end), 0) as cancelled_value,
       round(100 * sum(case when booking_status = 'Canceled' then booked_value end) / sum(booked_value), 1) as pct_value_cancelled
from booking_value;

-- 22. Monthly cancellation rate, with each month's share of yearly bookings (window function)
select year(arrival_date) as `year`,
       month(arrival_date) as `month`,
       count(*) as bookings,
       round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct,
       round(100 * count(*) / sum(count(*)) over (partition by year(arrival_date)), 1) as pct_of_year_bookings
from hotel_copy
group by `year`, `month`
order by `year`, `month`;

-- 23. Rank segments by cancellation rate within each lead-time band (window function)
with seg_band as (
    select market_segment_type,
           case when lead_time > 90 then 'Long (90+ days)' else 'Short (0-90 days)' end as lead_band,
           count(*) as bookings,
           round(100 * avg(booking_status = 'Canceled'), 1) as cancellation_rate_pct
    from hotel_copy
    group by market_segment_type, lead_band
)
select *,
       rank() over (partition by lead_band order by cancellation_rate_pct desc) as risk_rank
from seg_band
where bookings >= 10 -- ignore very small groups
order by lead_band, risk_rank;
