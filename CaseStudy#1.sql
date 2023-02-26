-- 8 Week SQL Challenge: Case Study 1
-- 1. What is the total amount each customer spent at the restaurant?
select customer_id, sum(price) as "TOTAL AMOUNT" from SALES as s inner join MENU as m on s.product_id = m.product_id group by customer_id

-- 2. How many days has each customer visited the restaurant?
with days_of_sales as(select customer_id, dense_rank() over (partition by customer_id order by order_date) as "DAYS" from SALES)
select customer_id, max("DAYS") as "TOTAL DAYS" from days_of_sales group by customer_id


-- 3. What was the first item from the menu purchased by each customer?
-- All items from the first order by each customer
with first_dates (customer_id, earliest) as(
select customer_id, min(order_date) as "earliest" from SALES group by customer_id
)

select t.customer_id, t.product_name as "FIRST ORDER ITEMS" from( 
select * from SALES as s inner join MENU as m on s.product_id = m.product_id order by customer_id, order_date) as t join first_dates as fd
on t.customer_id = fd.customer_id and t.order_date = fd.earliest

-- An item from the first order by each customer 
select distinct customer_id, "FIRST PICK" from(
    select s.*, m.*, first_value(product_name) over(partition by customer_id order by order_date) as "FIRST PICK"
    from SALES as s inner join MENU as m 
    on s.product_id = m.product_id
)

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
with purchases as (
select product_name, count(*) as "PURCHASE COUNT" from SALES as s inner join MENU as m on s.product_id = m.product_id group by product_name
) 
select * from purchases where purchases."PURCHASE COUNT" = (select max("PURCHASE COUNT") from purchases)

-- 5. Which item was the most popular for each customer?
with purchases_by_customer as (
select customer_id, product_name, count(*) as "PRODUCT COUNT", 
    dense_rank() over (partition by customer_id order by "PRODUCT COUNT" desc) as "RANKING"
from SALES as s inner join MENU as m on s.product_id = m.product_id group by customer_id, product_name
)
select * exclude "RANKING" from purchases_by_customer where "RANKING" = 1

-- 6. Which item was purchased first by the customer after they became a member?
with first_order_member (customer_id, product_id) as (
select s.customer_id, min_by(product_id, order_date) from SALES as s join MEMBERS as mb 
on s.customer_id = mb.customer_id where order_date >= join_date group by s.customer_id
)

select customer_id, product_name from MENU as m join first_order_member as fom 
on m.product_id = fom.product_id order by customer_id

-- 7.Which item was purchased just before the customer became a member?
with item_before_membership (customer_id, product_id) as (
select s.customer_id, max_by(product_id, order_date) from SALES as s join MEMBERS as mb 
on s.customer_id = mb.customer_id where order_date < join_date group by s.customer_id
)

select customer_id, product_name from MENU as m join item_before_membership as fom 
on m.product_id = fom.product_id order by customer_id

-- 8. What is the total items and amount spent for each member before they became a member?
with purchases_before_membership as (
select m.*, sub1.customer_id from MENU as m join
(select s.*, mb.join_date from SALES as s 
 inner join MEMBERS as mb
on s.customer_id = mb.customer_id where order_date < join_date) as sub1
on m.product_id = sub1.product_id
)
select count(distinct product_name) as "TOTAL ITEMS", sum(price) "AMOUNT SPENT"
from purchases_before_membership group by customer_id

-- 9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select s.customer_id, sum(iff(product_name = 'sushi', price*20, price*10)) as "POINTS" from SALES as s inner join MENU as m
on s.product_id = m.product_id group by customer_id

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customers A and B have at the end of January?
with points_end_jan as (
select m.*, sub2.* exclude product_id from MENU as m join 
(select s.*, mb.* exclude customer_id, dateadd(day, 6, join_date) as "FIRST WEEK" from SALES as s inner join MEMBERS as mb on s.customer_id = mb.customer_id where order_date >= join_date and order_date <= '2021-01-31') as sub2
on m.product_id = sub2.product_id
) 
select customer_id, sum(iff(order_date <= "FIRST WEEK", price*20, iff(product_name = 'sushi', price*20, price*10))) as points from points_end_jan
group by customer_id


-- BONUS: Join All The Things
select sub3.customer_id, sub3.order_date, m.product_name, m.price, sub3.member from 
(select s.*, mb.* exclude customer_id, iff(join_date is null, 'N', iff(join_date > order_date, 'N', 'Y')) as member from SALES as s left join MEMBERS as mb on s.customer_id = mb.customer_id) sub3 join MENU as m 
on sub3.product_id = m.product_id

-- BONUS: Rank All The Things
select sub3.customer_id, sub3.order_date, m.product_name, m.price, sub3.member, iff(member = 'Y', rank() over (partition by customer_id, member order by order_date), NULL) as RANKING from 
(select s.*, mb.* exclude customer_id, iff(join_date is null, 'N', iff(join_date > order_date, 'N', 'Y')) as member from SALES as s left join MEMBERS as mb on s.customer_id = mb.customer_id) sub3 join MENU as m 
on sub3.product_id = m.product_id