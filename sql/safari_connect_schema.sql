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
