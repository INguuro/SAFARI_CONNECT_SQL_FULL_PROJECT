CREATE SCHEMA IF NOT EXISTS safari_connect;
SET search_path TO safari_connect;

-- Staging table: ALL columns TEXT - accepts dirty data without failing
CREATE TABLE IF NOT EXISTS bookings_staging (
    booking_id       TEXT,
    passenger_name    TEXT, 
    passenger_phone  TEXT,
    passenger_gender TEXT, 
    passenger_city    TEXT, 
    route_code       TEXT,
    route_from       TEXT, 
    route_to          TEXT, 
    vehicle_plate    TEXT,
    vehicle_type     TEXT, 
    driver_name       TEXT, 
    driver_rating    TEXT,
    departure_date   TEXT, 
    departure_time    TEXT, 
    seat_class       TEXT,
    seats_booked     TEXT, 
    fare_per_seat     TEXT, 
    total_fare       TEXT,
    payment_method   TEXT, 
    booking_status    TEXT, 
    trip_rating      TEXT
);
--Sanity Check--------------------------------------
select * from safari_connect.bookings_staging bs ;
--=========================================================================================
--Create a staging table from the raw table (Incase of data loass we can retrieve the data)
create table safari_connect.stagings_bookings as 
select * from safari_connect.bookings_staging;

--====================Cleaning the Staging Table===========================================
--====================Passenger Name=======================================================
--Check number of rows that require cleaning
select
	count(*)
from safari_connect.bookings_staging
where passenger_name != initcap(TRIM(passenger_name));

--Update passenger_name column
update safari_connect.bookings_staging
set passenger_name = initcap(TRIM(passenger_name))
where passenger_name != initcap(TRIM(passenger_name));

--=====================Passenger Phone=====================================================
-- Check number of rows that require cleaning
select 
	count(*)
from safari_connect.bookings_staging 
where passenger_phone is not null and passenger_phone !~ '^0[0-9]{9}$';

-- Remove dashes and special characters
update safari_connect.bookings_staging 
set passenger_phone = regexp_replace(passenger_phone, '[^0-9+]','','g')
where passenger_phone is not null and passenger_phone !~ '^0[0-9]{9}$';

-- Remove +254 and swap with 0
update safari_connect.bookings_staging 
set passenger_phone = regexp_replace(passenger_phone, '^\+254','0')
where passenger_phone like '+254%';

-- Convert empty strings to null
update safari_connect.bookings_staging 
set passenger_phone = coalesce(nullif(passenger_phone,''),null)
where passenger_phone = '';

--=====================Departure Date======================================================
-- Update DD/MM/YYYY
update safari_connect.bookings_staging 
set departure_date = to_char(to_date(departure_date,'DD/MM/YYYY'), 'YYYY-MM-DD')
where departure_date ~ '^\d{2}/\d{2}/\d{4}$';

-- Update MM-DD-YYYY
update safari_connect.bookings_staging 
set departure_date = to_char(to_date(departure_date, 'MM-DD-YYYY'), 'YYYY-MM-DD')
where departure_date ~ '^\d{2}-\d{2}-\d{4}$';

-- Update DD-MM-YY
update safari_connect.bookings_staging 
set departure_date = to_char(to_date(departure_date, 'DD-MM-YY'), 'YYYY-MM-DD')
where departure_date ~ '^\d{2}-\d{2}-\d{2}$';

-- Change data type to date
alter table safari_connect.bookings_staging 
alter column departure_date type date using departure_date::date;

--=====================Passenger City======================================================
--Update Passenger City casing
update safari_connect.bookings_staging
set passenger_city = initcap(trim(passenger_city))
where passenger_city != initcap(TRIM(passenger_city));

--Replace null/empty city in passenger city with 'Unknown'
update safari_connect.bookings_staging
set passenger_city = coalesce(nullif(passenger_city,''),'Unknown');

--=====================Vehicle Type=======================================================
-- Update vehicle type casing
update safari_connect.bookings_staging 
set vehicle_type = initcap(TRIM(vehicle_type))
where vehicle_type != initcap(TRIM(vehicle_type));

--=====================Passenger Gender====================================================
update safari_connect.bookings_staging
set passenger_gender = case
	when trim(passenger_gender) = 'F' then 'Female'
	when trim(passenger_gender) = 'M' then 'Male'
	else initcap(trim(passenger_gender)) 
end
where passenger_gender not in ('Male','Female');

--=====================Payment Method======================================================
--Check number of rows that require cleaning
select
	count(*)
from safari_connect.bookings_staging
where  payment_method != initcap(TRIM(payment_method));

update safari_connect.bookings_staging
set payment_method = case
	when lower(trim(payment_method)) like '%pesa%' then 'M-Pesa'
	when lower(trim(payment_method)) = 'cash' then 'Cash'
	when lower(trim(payment_method)) = 'card' then 'Card'
	else payment_method
end
where payment_method not in ('M-Pesa','Cash','Card');

--=====================Booking Status=======================================================
--Check number of rows that require cleaning
select
	count(*)
from safari_connect.bookings_staging
where  booking_status != initcap(TRIM(booking_status));
	
update safari_connect.bookings_staging
set booking_status = case
	when lower(trim(booking_status)) = 'completed' then 'Completed'
	when lower(trim(booking_status)) = 'cancelled' then 'Cancelled'
	when lower(trim(booking_status)) = 'no show' then 'No Show'
	else booking_status
end
where booking_status not in ('Completed','Cancelled','No Show');

--============Total Fare======================================================================
alter table safari_connect.bookings_staging 
alter column total_fare type numeric
using  cast(regexp_replace(total_fare,'[^0-9.]','','g') as numeric);

--============Fare Per Seat===================================================================
alter table safari_connect.bookings_staging 
alter column fare_per_seat type numeric
using cast(regexp_replace(fare_per_seat,'[^0-9.]','','g') as numeric);

--============Seat Class======================================================================
update safari_connect.bookings_staging
set seat_class = case
	when upper(left(trim(seat_class),1)) = 'E' then 'Economy'
	when upper(left(trim(seat_class),1)) = 'B' then 'Business'
	else seat_class
end
where seat_class not in ('Economy','Business');

--=============Driver Name==============================================
update safari_connect.bookings_staging
set driver_name = initcap(TRIM(driver_name))
where driver_name != initcap(TRIM(driver_name));

--=============Trip Rating==============================================
update safari_connect.bookings_staging
set trip_rating = null 
where trip_rating is not null
and trip_rating != '' and trip_rating::int not between 1 and 5;

alter table safari_connect.bookings_staging
alter column trip_rating type integer using nullif(trip_rating, '') ::integer;

--=============Seats Booked=============================================
select * from safari_connect.bookings_staging
where seats_booked::numeric < 0;

--delete negative rows
delete from safari_connect.bookings_staging
where seats_booked::numeric < 0;

--=============Booking Id===============================================
delete from safari_connect.bookings_staging 
where ctid not in 
	(select min(ctid) 
	from safari_connect.bookings_staging
	group by booking_id
);

select booking_id,
	count(*) 
from safari_connect.bookings_staging
group by booking_id 
having count(*) > 1;
	
	
	
	
select * from safari_connect.bookings_staging;





---SQL PROJECT QUESTIONS AND WORKINGS---
/*Route Analysis Which routes earn the most? Which are most popular? 
 * Which is most efficient per seat sold?
Specific route codes with KES figures. A clear top route and a clear underperformer.
*/
-- SUM(total_fare) as route_revenue group ny route

SET SEARCH_PATH TO SAFARI_CONNECT;
WITH route_performance AS (
	SELECT 
		route_code,
		CONCAT(route_from, ' - ', route_to ) AS route_name,
		SUM(fare_per_seat) AS revenue_per_seat,
		ROUND(SUM(calculated_fare) / NULLIF(SUM(seats_booked), 0)) AS revenue_per_seat_sold,
		SUM(calculated_fare) AS route_revenue,
		SUM(seats_booked) AS total_seats_sold,
		COUNT(booking_id) AS total_bookings
FROM v_clean_trips
GROUP BY 1, 2
)
SELECT 
	route_code,
	route_name,
	revenue_per_seat_sold,
	route_revenue,
	total_seats_sold,
	total_bookings,
	RANK() OVER(
		ORDER BY route_revenue  DESC 
	) AS revenue_rank,
	RANK() OVER(
		ORDER BY revenue_per_seat_sold  DESC
	) efficiency_rank
FROM route_performance
ORDER BY route_revenue DESC;


SET search_path TO safari_connect;
/*Route Analysis Which routes earn the most? Which are most popular? 
 * Which is most efficient per seat sold?
Specific route codes with KES figures. A clear top route and a clear underperformer.
*/
---what we need; route code, route name, total revenue, bookings revenue per seats sold
WITH route_perfomance AS (
SELECT route_code,
      concat(route_from, ' - ', route_to) AS route_name,
      sum(calculated_fare) AS total_revenue,
      count(vct.booking_id) AS total_bookings,
      round(
      sum(vct.calculated_fare) / sum(vct.seats_booked ),0) AS revenue_per_seat_sold 
      FROM v_clean_trips vct 
      GROUP BY 1, 2
)
 SELECT route_code,
        route_name,
        total_revenue,
        total_bookings,
        revenue_per_seat_sold,
        rank() OVER (ORDER BY total_revenue desc) AS revenue_rank,
        RANK() OVER (ORDER BY total_bookings desc) AS bookings_rank,
        RANK() OVER (ORDER BY revenue_per_seat_sold desc) AS efficiency_rank
        FROM route_perfomance
        ORDER BY total_revenue desc;
/*OVERVIEW AND NOTES
 * 
 *TOP REVENUE PERFORMER: ROT001 (Nairobi-Mombasa) generates the most revenue ksh 51,600
                          -- generates ksh 1259 per seat sold
* LEAST REVENUE PERFORMER: RT009 (Nairobi-Machakos) generates ksh 7,300
                          -- generates ksh 221 per seat sold
 *MOST EFFICIENT PER SEAT SOLD: ROT001 (Nairobi-Mombasa)
                          -- generates ksh 1259 per seat sold
 *LEAST EFFICIENT PER SEAT SOLD: ROT005 (Nairobi-Thika)
                          -- ksh generates 123 per seat sold
 *MOST POPULAR: ROT005 (Nairobi-Thika) with 30 total bookings
 *LEAST POPULAR: ROT009 (Nairobi-Machakos) with 20 total bookings
 */

SELECT * FROM v_clean_trips;


/*Driver Performance 
 * Who are the best drivers? Does driver rating affect passenger satisfaction?
 */
-- driver_name, total revenue(SUM(calculated_fare), driver_rating, satisfaction

SELECT 
	driver_name,
	AVG(driver_rating) AS avg_rating,
	ROUND(AVG(trip_rating),1) AS avg_trip_satisfaction,
	SUM(calculated_fare) AS total_revenue
FROM v_clean_trips
GROUP BY 1
ORDER BY total_revenue DESC;	


/*Driver Performance 
 * Who are the best drivers? Does driver rating affect passenger satisfaction?
 */
-- driver_name, vehicle_type, total revenue(SUM(calculated_fare), driver_rating, satisfaction,drivers route name, 
SELECT * FROM v_clean_trips;

WITH drive_perfomance AS (
SELECT
      vct.driver_name,
      vct.vehicle_type,
     sum(vct.calculated_fare) AS total_fares,
      vct.driver_rating,
      count(vct.booking_id) AS trips_count,
      round(
      avg(vct.trip_rating),1) AS avg_passenger_satisfaction
FROM v_clean_trips vct
GROUP BY 1, 2,4
ORDER BY avg_passenger_satisfaction DESC
)
SELECT 
driver_name,
vehicle_type,
driver_rating, 
total_fares, 
avg_passenger_satisfaction, 
trips_count,
RANK() OVER (ORDER BY total_fares desc)AS  fare_rank,
RANK() OVER (ORDER BY avg_passenger_satisfaction desc) AS satisfaction_rank,
rank() OVER (ORDER BY driver_rating desc) AS driver_rank 
FROM drive_perfomance 
ORDER BY total_fares desc;


---From the navas
WITH driver_totals AS (
    SELECT
        driver_name,
        vehicle_type,
        COUNT(*)             AS total_trips,
        SUM(total_fare)    AS total_revenue,
        ROUND(AVG(trip_rating),2) AS avg_passenger_rating
    FROM v_clean_trips
    GROUP BY driver_name, vehicle_type
)
SELECT
    driver_name, vehicle_type, total_trips, total_revenue, avg_passenger_rating,
    RANK() OVER (ORDER BY total_revenue DESC)                        AS overall_rank,
    RANK() OVER (PARTITION BY vehicle_type ORDER BY total_revenue DESC) AS vehicle_rank
FROM driver_totals
ORDER BY overall_rank;



/*TOP REVENUE PERFORMER: Isaac Korir - generates ksh 33045
      -- driver rating: 3.8
      -- passenger satisfaction: 3.4
 * WORST REVENUE PERFORMER: Peter Ngugi - generates ksh 23880
      -- driver rating: 4.3
      -- passenger satisfaction: 3.4
      
 * Driver rating doesn't automatically affect passenger satisfaction
 *Moses Kipchoge holds the top driver rating (4.8), but his average passenger trip rating is among the lowest (3.2).
 *Hassan Abdi holds a moderate driver rating (4.1), yet achieves the highest passenger satisfaction score (3.9).
 *Isaac Korir delivers the highest revenue (KES 33,045) with a moderate driver rating (3.8) and passenger satisfaction (3.4).
 *Samuel Gitonga performed best in the minibus and bus category with an avg rating of 4.5 in two trips and 3.53 respectively.
 *Isaac Korir was the best in the matatu section 
 

 *Operational Insight: Passenger trip ratings reflect overall trip experience
 *(punctuality, vehicle comfort, seat class, route length) rather than driver conduct alone.

  *Recommendations:
  * Hassan Abdi - maintains a balance between all the metrics
  *Isaac Korir - generates the most revenue
*/

/* Q3 - Revenue Trends How is revenue changing month by month? 
 * What are our best and worst months?
 */
-- Monthly revenue with month-over-month change 
-- month, bookings, revenue
with monthly_trend as (
	select 
		travel_month,
		count(*) as booking,
		sum(calculated_fare) as revenue_per_month
	from v_clean_trips
	group by travel_month
)
select 
	travel_month, 
	booking,
	revenue_per_month ,
	lag(revenue_per_month ) over (order by travel_month) as previous_month,
	revenue_per_month  - lag(revenue_per_month ) over (order by travel_month) as revenue_change,
	round((revenue_per_month  - lag(revenue_per_month ) over (order by travel_month))
		/nullif(lag(revenue_per_month ) over (order by travel_month),0) * 100, 1) as change_pct
from monthly_trend
order by travel_month;

-- Running total of revenue
select 
	travel_month,
	sum(calculated_fare) as monthly_total,
	sum(sum(calculated_fare)) over (order by travel_month) as running_total_revenue
from v_clean_trips
group by travel_month;

-- Best and Worst 3 months by Revenue
with monthly_trend as (
	select 
		travel_month,
		count(*) as booking,
		sum(calculated_fare) as revenue_per_month,
		rank() over (order by sum(calculated_fare) desc) as top_revenue_rank,
		rank() over (order by sum(calculated_fare) asc) as bottom_revenue_rank
	from v_clean_trips
	group by travel_month
)
select 
	travel_month,
	booking,
	revenue_per_month,
	case
		when top_revenue_rank <= 3 then 'Top'
		else 'Bottom'
	end as category	
from monthly_trend
where top_revenue_rank <= 3 or bottom_revenue_rank <= 3
order by revenue_per_month desc;

-- Revenue by Route per month (pivot)
select 
	travel_month,
	route_code,
	sum(calculated_fare) as total_revenue
from v_clean_trips
group by travel_month, route_code;
--===========================ANSWERS==================================================

-- Top months by Revenue
		-- Oct 2024 generated KES 23,680
		-- July 2024 generated KES 22,855
		-- Nov 2024 generated KES 20,270
-- Worst months by Revenue
		-- Jan 2025 generated KES 1,685
		-- Aug 2024 generated KES 13,400
		-- Feb 2024 generated KES 15,640

--====================================================================================
/* Q4 - Passenger Insights Where do passengers come from?
 * What seat class do they prefer? 
 * Are they satisfied?
 */
-- Passengers top cities
select 
	passenger_city,
	count(*) as total_bookings,
	sum(seats_booked) as total_seats,
	sum(calculated_fare) as total_revenue
from v_clean_trips
group by passenger_city 
having count(*) > 3
order by total_bookings desc;

-- Gender split and seat class preference
select 
	passenger_gender,
	count(*) as total_bookings,
	sum(calculated_fare) as total_revenue,
	sum(case when seat_class = 'Economy' then 1 else 0 end) as economy_bookings,
	sum(case when seat_class = 'Economy' then calculated_fare  else 0 end) as economy_revenue,
	sum(case when seat_class = 'Business' then 1 else 0 end) as business_bookings,
	sum(case when seat_class = 'Business' then calculated_fare  else 0 end) as business_revenue
from v_clean_trips
group by passenger_gender;

-- Satisfaction breakdown
select 
	satisfaction,
 	count(*) as satisfaction_count,
 	round(100 * count(*) / sum(count(*)) over (), 1) as pct_of_total
from v_clean_trips
group by satisfaction 
order by satisfaction_count desc;

-- Passenger quartiles by spend (NTILE)
with passenger_totals as (
	select 
		passenger_name,
		sum(calculated_fare) as total_spend,
		ntile(4) over (order by sum(calculated_fare) asc) as passenger_quartile
	from v_clean_trips
	group by passenger_name 
)
select
	passenger_name,
	total_spend,
	passenger_quartile,
	case 
		when passenger_quartile = 4 then 'Top Spender'
	end as quartile_label	
from passenger_totals
order by total_spend desc;


--===========================ANSWERS==================================================
-- Top Cities
		-- Nairobi is the top with 113 bookings generating a revenue of KES 112,000
-- 79.4%(201) of the bookings choose Economy class and 20.6%(52) choose Business class.

-- In gender the female generated the highest revenue(KES 120,885) compared to the 
-- male(KES 106,925), economy class was best preferred when it came to customer seat bookings.

-- 46.2%(117) of the passengers are satisfied, 28.9%(73)  are neutral and 19.4%(49) 
-- are unsatisfied. They can work on getting their customers satisfaction to atleast 50%.

--====================================================================================
/* Q5 - Cancellations What is the cancellation rate per route? 
 * How much revenue did cancellations cost us?
 */
-- Overall Status Breakdown
select 
	booking_status,
	count(*) as bookings
from safari_connect.bookings_staging
group by booking_status 
order by bookings desc;


-- Cancellation Rate by route
select
	route_code,
	concat(route_from, ' - ', route_to) as route_name,
	count(*) as total_bookings,
	sum(case when booking_status = 'Completed' then 1 else 0 end) as completed,
	sum(case when booking_status = 'Cancelled' then 1 else 0 end) as cancelled,
	sum(case when booking_status = 'No Show' then 1 else 0 end) as no_show,
	round(sum(case when booking_status in ('Cancelled','No Show')
		then 1 else 0 end) * 100.0 / count(*), 1) as cancel_rate_pct
from safari_connect.bookings_staging
group by route_code, route_name
order by cancel_rate_pct desc;

-- Revenue lost from cancellations and no-shows
select 
	booking_status,
	count(*) as bookings,
	sum(total_fare) as revenue_lost
from safari_connect.bookings_staging
where booking_status in ('Cancelled','No Show')
group by booking_status;

-- Revenue lost per route
select
    route_code,
    concat(route_from, ' - ', route_to) as route_name,
    sum(case when booking_status = 'Cancelled' then total_fare else 0 end) as cancelled_revenue_lost,
    sum(case when booking_status = 'No Show' then total_fare else 0 end) as no_show_revenue_lost,
    sum(case when booking_status in ('Cancelled','No Show') then total_fare else 0 end) as total_revenue_lost
from safari_connect.bookings_staging 
group by route_code, route_from, route_to
order by total_revenue_lost desc;

--===========================ANSWERS==================================================

-- Worst route for cancellations is Mombasa-Malindi at 18.5%
-- Least route for cancellations is Nairobi-Eldoret at 3.6%

-- Total Revenue lost is KES 32,150.
	-- Cancelled is KES 24,805
	-- No Show is KES 7,345

-- RT001(Nairobi-Mombasa) has the highest revenue lost at KES 10,800 but was not the worst route 
-- for cancellation. This is because its seat is expensive.

-- Policy Recommendation
-- No refund for cancellation and no show on travel day.
-- 50% refund for cancellations two days before departure.
--====================================================================================
/* Q6 - Operational Patterns What are our busiest days and times?
 * When should we add more vehicles?
 */
--Revenue by day of week
select 	
	day_of_week,
	day_name,
	count(*) as total_bookings,
	sum(calculated_fare) as total_revenue
from v_clean_trips
group by day_of_week, day_name
order by total_revenue desc;

-- Busiest departure times
select 
	departure_time,
	count(*) as total_bookings,
	sum(calculated_fare) as total_revenue
from v_clean_trips
group by departure_time
order by total_bookings desc;

-- Seat utilisation by vehicle type
select 	
	vehicle_type,
	round(avg(seats_booked),0) as avg_seats_booked,
	case 
		when avg(seats_booked) > 3 then 'High Load'
		when avg(seats_booked) >= 2 then 'Medium Load'
		else 'Low Load'
	end as load_label
from v_clean_trips
group by vehicle_type
order by avg_seats_booked desc;

--===========================ANSWERS==================================================
-- Monday generates the highest revenue (KES 47,350) and Wednesday more bookings were made
-- compared to other days (52).
-- Sunday generates the lowest revenue(KES 8,835) and 11 bookings.

-- The busiest departure time is 09:00 with 25 bookings and 06:00 with 24 bookings.
-- 16:00 - 17:30 bookings are slow with 18 bookings.

-- 19:00 generates the highest revenue(KES 22,240)
-- 13:00 generates the lowest revenue(KES 12,045)

-- All vehicle_types have low load(avg 2 seats booked)

-- Recommendation
	--1. from the analysis  at 09:00 there is more bookings made,
	-- to increase on vehicle load more vehicles should operate from 06:00 to 09:00.
