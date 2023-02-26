-- A. PIZZA METRICS: 
-- 1. How many pizzas were ordered?
select COUNT(*) as "TOTAL ORDERS" from CUSTOMER_ORDERS

-- 2. How many unique customer orders were made?
select count(distinct order_id) as "UNIQUE ORDERS"  from CUSTOMER_ORDERS

-- 3. How many successful orders were delivered by each runner?
select runner_id, count(*) as "Successful Deliveries" from CUSTOMER_ORDERS c_orders inner join 
RUNNER_ORDERS r_orders on c_orders.order_id = r_orders.order_id
where duration <> 'null' group by runner_id

-- 4. How many of each type of pizza was delivered?
select pizza_name, "DELIVERY COUNT" from PIZZA_NAMES as p_names join
(select pizza_id, count(*) as "DELIVERY COUNT" from CUSTOMER_ORDERS c_orders 
 inner join RUNNER_ORDERS r_orders on c_orders.order_id = r_orders.order_id
where duration <> 'null' group by pizza_id) as sub1
on p_names.pizza_id = sub1.pizza_id

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select customer_id, pizza_name, count(*) as "PIZZA COUNT" from CUSTOMER_ORDERS c_orders inner join 
PIZZA_NAMES as p_names 
on c_orders.pizza_id = p_names.pizza_id group by customer_id, pizza_name 
order by customer_id

-- 6. What was the maximum number of pizzas delivered in a single order?
select max("ORDER COUNT") as "MAX PIZZA PER ORDER" from 
(select order_id, count(*) as "ORDER COUNT" from CUSTOMER_ORDERS group by order_id)

-- 7.For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
with pizza_changes as (
select *, iff((exclusions = 'null' or exclusions is null or exclusions = '') and (extras = 'null' or extras is null or extras = ''), 'N', 'Y') as "AT LEAST 1 CHANGE"
from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders
on c_orders.order_id = r_orders.order_id where duration <> 'null'
)

select customer_id, iff("AT LEAST 1 CHANGE" = 'N', 'No Change', 'At Least 1 Change') as "REQUEST", count(*) as "No. of Order"
from pizza_changes group by customer_id, "AT LEAST 1 CHANGE"

-- 8. How many pizzas were delivered that had both exclusions and extras?
with pizza_changes_both as (
select *, nullif(nullif(exclusions, ''), 'null') as excl, nullif(nullif(extras, ''), 'null') as extr, iff(excl is not null and extr is not null, 'Y', 'N') as "BOTH CHANGES"
from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders
on c_orders.order_id = r_orders.order_id where duration <> 'null'
)
select count(*) as "Pizza With Both Exclusions And Extra" from pizza_changes_both where "BOTH CHANGES" = 'Y'

-- 9. What was the total volume of pizzas ordered for each hour of the day?
select date_part(hour, order_time) as "HOUR OF THE DAY", count(*) as "VOLUME OF PIZZA" from CUSTOMER_ORDERS group by "HOUR OF THE DAY"

-- 10. What was the volume of orders for each day of the week?
select dayname(order_time) as "DAY OF THE WEEK", count(*) as "VOLUME OF PIZZA" from CUSTOMER_ORDERS group by "DAY OF THE WEEK"

-- B. RUNNER AND CUSTOMER EXPERIENCE
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

select weekofyear(order_time) as "WOY", count(distinct runner_id) as "RUNNER COUNT" from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders
on c_orders.order_id = r_orders.order_id group by "WOY"

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select runner_id, avg(datediff('minute', order_time, cast(pickup_time as TIMESTAMP_NTZ))) as "TIME TAKEN (MIN)" from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders on c_orders.order_id = r_orders.order_id where pickup_time <> 'null' group by runner_id

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

-- 4. What was the average distance travelled for each customer?
select customer_id, avg(replace(distance, 'km', '')::FLOAT) as "AVG DISTANCE" from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders on c_orders.order_id = r_orders.order_id where distance <> 'null' group by customer_id


-- 5. What was the difference between the longest and shortest delivery times for all orders?
with delivery_duration as (
select regexp_substr(nullif(duration, 'null'), '^\\d{2}')::NUMBER as "DELIVERY DURATION" from RUNNER_ORDERS
) 
select max("DELIVERY DURATION") - min("DELIVERY DURATION") as "DIFF (MINS)" from delivery_duration

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select runner_id, weekofyear(nullif(pickup_time, 'null')::TIMESTAMP_NTZ) as "WOY", regexp_substr(nullif(duration, 'null'), '^\\d{2}')::NUMBER as "DUR", replace(nullif(distance, 'null'), 'km', '')::FLOAT as "DIST", "DIST"/"DUR" as "SPEED" from RUNNER_ORDERS
-- All runners delivery in shorter time in second week

-- 7. What is the successful delivery percentage for each runner?
with total_delivery as (
select runner_id, count(*) as TOTAL_ORDER from RUNNER_ORDERS as r_orders inner join CUSTOMER_ORDERS c_orders on r_orders.order_id = c_orders.order_id
group by runner_id order by runner_id
),

successful_delivery as (
select runner_id, count(*) as TOTAL_SUCCESS from TIL_PLAYGROUND.CS2_PIZZA_RUNNER.RUNNER_ORDERS as r_orders inner join TIL_PLAYGROUND.CS2_PIZZA_RUNNER.CUSTOMER_ORDERS c_orders on r_orders.order_id = c_orders.order_id
where pickup_time <> 'null'
group by runner_id order by runner_id
)

select sd.runner_id, TOTAL_SUCCESS/TOTAL_ORDER*100 as SUCCESS_PERCENTAGE from successful_delivery as sd inner join total_delivery as td on sd.runner_id = td.runner_id

-- C. Ingredient Optimisation
-- 1. What are the standard ingredients for each pizza?
with std_ingred as (
select pizza_id, pt.* from PIZZA_TOPPINGS as pt inner join 
(select pizza_id, value as TOPPING_ID from PIZZA_RECIPES,lateral split_to_table(PIZZA_RECIPES.TOPPINGS, ',')
order by seq, index) as sub1 on pt.topping_id = sub1.topping_id order by pizza_id, topping_id
)
select pizza_id, listagg(topping_name, ', ') within group(order by pizza_id, topping_id) as INGREDIENTS from std_ingred
group by pizza_id order by pizza_id

-- 2. What was the most commonly added extra?
with extras_topping as(
select pizza_id, nullif(nullif(extras, ''), 'null') as extra_topping from CUSTOMER_ORDERS where extra_topping is not null
),
most_common_extra as(
select mode(extra_topp) as "MOST COMMON EXTRA" from
(select pizza_id, value as extra_topp from extras_topping, lateral split_to_table(extras_topping.extra_topping, ', ')
order by seq, index)
)
select topping_name as "MOST COMMON TOPPING" from PIZZA_TOPPINGS as pt inner join most_common_extra as mce
on mce."MOST COMMON EXTRA" = pt.topping_id

-- 3.What was the most common exclusion?
with excluded_topping as(
select pizza_id, nullif(nullif(exclusions, ''), 'null') as excluded from CUSTOMER_ORDERS where excluded is not null
),
most_common_exclusion as(
select mode(excluded_topp) as "MOST COMMON EXCLUSION" from
(select pizza_id, value as excluded_topp from excluded_topping, lateral split_to_table(excluded_topping.excluded, ', ')
order by seq, index)
)
select topping_name as "MOST COMMON EXCLUSION" from PIZZA_TOPPINGS as pt inner join most_common_exclusion as mcex
on mcex."MOST COMMON EXCLUSION" = pt.topping_id

-- 4. Generate an order item for each record in the customers_orders table
with modified_customer_orders as (
select * exclude extras,iff(extras is null, 'null', extras) as extras, row_number() over (order by order_id, customer_id, pizza_id) as ROW_ID from CUSTOMER_ORDERS
),
split_exclusions as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as exclusions from modified_customer_orders, lateral split_to_table(modified_customer_orders.exclusions, ', ') order by seq, index
),
modified_exclusions as(
select order_id, customer_id, pizza_id, order_time, row_id, listagg(exclusions, ', ') within group (order by order_id, customer_id, pizza_id, order_time, row_id) as exclusions
from (select spex.* exclude exclusions, pt.topping_name as exclusions from split_exclusions as spex left join PIZZA_TOPPINGS as pt on spex.exclusions = pt.topping_id) group by order_id, customer_id, pizza_id, order_time, row_id order by order_id, customer_id, pizza_id, row_id
),
split_extras as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as extras from modified_customer_orders, lateral split_to_table(modified_customer_orders.extras, ', ') order by seq, index
),
modified_extras as(
select order_id, customer_id, pizza_id, order_time, row_id, listagg(extras, ', ') within group (order by order_id, customer_id, pizza_id, order_time, row_id) as extras
from (select spex.* exclude extras, pt.topping_name as extras from split_extras as spex left join PIZZA_TOPPINGS as pt on spex.extras = pt.topping_id) group by order_id, customer_id, pizza_id, order_time, row_id order by order_id, customer_id, pizza_id, row_id
),
order_items as(
select sub3.* exclude pizza_id, concat(pn.pizza_name, iff(nullif(exclusions, '') is not null, concat(' - Exclude ', exclusions), ''), iff(nullif(extras, '') is not null, concat(' - Extra ', extras), '')) as order_item from PIZZA_NAMES as pn inner join (select m_extras.*, m_excl.exclusions from modified_extras as m_extras inner join modified_exclusions as m_excl on m_extras.row_id = m_excl.row_id) sub3 on pn.pizza_id = sub3.pizza_id
)
/*
select mod_co.order_id, mod_co.customer_id, mod_co.pizza_id, mod_co.exclusions, mod_co.extras, mod_co.order_time, order_item from order_items inner join modified_customer_orders as mod_co on order_items.row_id = mod_co.row_id
*/
-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
with ingred_list as (
select pizza_id, value::NUMBER as INGREDIENT from PIZZA_RECIPES, lateral split_to_table(PIZZA_RECIPES.TOPPINGS, ', ') order by pizza_id
),
modified_customer_orders as (
select * exclude extras,iff(extras is null, 'null', extras) as extras, row_number() over (order by order_id, customer_id, pizza_id) as ROW_ID from CUSTOMER_ORDERS
),
split_extras as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as ingredient from modified_customer_orders, lateral split_to_table(modified_customer_orders.extras, ', ') order by seq, index
),
split_exclusions as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as exclusions from modified_customer_orders, lateral split_to_table(modified_customer_orders.exclusions, ', ') order by seq, index
),
ingred_exclusions as(
select spex.* exclude exclusions, il.ingredient from split_exclusions as spex inner join ingred_list as il minus
select spex.* exclude exclusions, il.ingredient from split_exclusions as spex inner join ingred_list as il where exclusions = ingredient  order by order_id, customer_id, pizza_id, row_id, ingredient
),
all_ingred as (
select * from ingred_exclusions union all select * from split_extras order by order_id, customer_id, pizza_id, row_id, ingredient
),
topping_wCount as (
select sub5.* exclude ingredient, pt.topping_name from PIZZA_TOPPINGS as pt inner join 
(select order_id, customer_id, pizza_id, order_time, row_id, ingredient, count(*) as ingred_count from all_ingred group by order_id, customer_id, pizza_id, order_time, row_id, ingredient order by order_id, customer_id, pizza_id, row_id, ingredient) as sub5
on pt.topping_id = sub5.ingredient order by order_id, customer_id, pizza_id, order_time, topping_name
),
ingredient_list_wCount as (
select *, iff(ingred_count > 1, concat_ws('x', ingred_count::string, topping_name), topping_name) as topp_amount from topping_wCount
)
--select * from ingredient_list_wCount
select order_id, customer_id, pizza_id, order_time, listagg(topp_amount, ', ') within group(order by order_id, customer_id, pizza_id, order_time, row_id, topping_name) as ordered_ingredient_list from ingredient_list_wCount group by order_id, customer_id, pizza_id, order_time, row_id order by order_id, customer_id, pizza_id, order_time, row_id

-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
with ingred_list as (
select pizza_id, value::NUMBER as INGREDIENT from PIZZA_RECIPES, lateral split_to_table(PIZZA_RECIPES.TOPPINGS, ', ') order by pizza_id
),
modified_customer_orders as (
select * exclude extras,iff(extras is null, 'null', extras) as extras, row_number() over (order by order_id, customer_id, pizza_id) as ROW_ID from CUSTOMER_ORDERS
),
split_extras as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as ingredient from modified_customer_orders, lateral split_to_table(modified_customer_orders.extras, ', ') order by seq, index
),
split_exclusions as (
select * exclude (exclusions, seq, index, value, extras), try_cast(value as number) as exclusions from modified_customer_orders, lateral split_to_table(modified_customer_orders.exclusions, ', ') order by seq, index
),
ingred_exclusions as(
select spex.* exclude exclusions, il.ingredient from split_exclusions as spex inner join ingred_list as il minus
select spex.* exclude exclusions, il.ingredient from split_exclusions as spex inner join ingred_list as il where exclusions = ingredient  order by order_id, customer_id, pizza_id, row_id, ingredient
),
all_ingred as (
select * from ingred_exclusions union all select * from split_extras order by order_id, customer_id, pizza_id, row_id, ingredient
),
topping_wCount as (
select sub5.* exclude ingredient, pt.topping_name from PIZZA_TOPPINGS as pt inner join 
(select order_id, customer_id, pizza_id, order_time, row_id, ingredient, count(*) as ingred_count from all_ingred group by order_id, customer_id, pizza_id, order_time, row_id, ingredient order by order_id, customer_id, pizza_id, row_id, ingredient) as sub5
on pt.topping_id = sub5.ingredient order by order_id, customer_id, pizza_id, order_time, topping_name
),
delivered_pizza_ingred as(
select twc.* from topping_wCount as twc inner join RUNNER_ORDERS as r_orders on twc.order_id = r_orders.order_id where pickup_time <> 'null'
)
select topping_name, sum(ingred_count) as topping_count from delivered_pizza_ingred group by topping_name order by topping_count desc

-- D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
with pizza_sold as(
select *, iff(pizza_name = 'Meatlovers', 12, 10) as price from PIZZA_NAMES as pn inner join 
(select c_orders.* from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders on c_orders.order_id = r_orders.order_id where pickup_time <> 'null') as sub6 on pn.pizza_id = sub6.pizza_id
)
select sum(price) as total_profit from pizza_sold

-- 2. What if there was an additional $1 charge for any pizza extras?
with pizza_sold_extra as (
select *, iff(pizza_name = 'Meatlovers', 12, 10) + iff(nullif(nullif(extras, 'null'), '') is not null, 1, 0) as total_price from PIZZA_NAMES as pn inner join 
(select c_orders.* from CUSTOMER_ORDERS as c_orders inner join RUNNER_ORDERS as r_orders on c_orders.order_id = r_orders.order_id where pickup_time <> 'null') as sub7 on pn.pizza_id = sub7.pizza_id
)
select sum(total_price) as total_profit from pizza_sold_extra

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
