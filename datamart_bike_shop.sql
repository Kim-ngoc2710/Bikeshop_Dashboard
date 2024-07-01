SELECT o.order_id,
	c.customer_id,
	concat(c.first_name,' ',c.last_name) as customer,
	c.city,
	c.state,
	o.order_date,
	p.product_name,
	ca.category_name,
	br.brand_name,
	sto.store_name,
	concat(sta.first_name,' ',sta.last_name) as staffs,
	sum(oi.quantity) as total_units,
	sum(oi.quantity*oi.list_price) as revenue
from sales.customers c
join sales.orders o
	on c.customer_id = o.customer_id
join sales.order_items oi
	on o.order_id = oi.order_id
join production.products p
	on p.product_id = oi.product_id
join production.categories ca
	on ca.category_id = p.category_id
join production.brands br
	on br.brand_id = p.brand_id
join sales.stores sto
	on sto.store_id = o.store_id
join sales.staffs sta
	on sta.staff_id= o.staff_id
group by c.customer_id,
	o.order_id,
	p.product_id,
	ca.category_name,
	br.brand_name,
	sto.store_name,
	staffs;

-- Calculate the total revenue by date
select o.order_date,
	sum(oi.list_price*oi.quantity) as daily_revenue
from sales.orders o
join sales.order_items oi
	on o.order_id = oi.order_id
group by o.order_date
order by o.order_date desc;

--Ranking of the products by the total quantity sold
--Window Fonction
select oi.product_id,
	p.product_name,
	sum(oi.quantity) as quantity_sold,
	dense_rank()over(order by sum(oi.quantity)) as sales_ranking
from sales.order_items oi
join production.products p
	on oi.product_id = p.product_id
group by oi.product_id, p.product_name;

--Best-selling product in each category by the quantity sold
-- With CTEs
with saless as(
	select oi.product_id,
	p.product_name,
	sum(oi.quantity) as quantity_sold,
	ca.category_name,
	dense_rank()over(partition by ca.category_name order by sum(oi.quantity)desc ) as category_rank
from sales.order_items oi
join production.products p
	on oi.product_id = p.product_id
join production.categories ca
	on ca.category_id = p.category_id
group by oi.product_id, p.product_name, ca.category_name
)

select product_id, 
	product_name,
	category_name,
	quantity_sold,
	category_rank
from saless
where category_rank=1;

--How the price of each product 
--compares to the least expensive and the most expensive items 
--of the same category as the product
--with windows function

select p.product_id,
	p.product_name,
	c.category_name,
	p.list_price,
	max(p.list_price)over(partition by c.category_id) as max_price_in_category,
	min(p.list_price)over(partition by c.category_id) as min_price_in_category
	
from production.products p
join production.categories c
	on p.category_id = c.category_id;

--how the store revenue for the month compares to the previous month.
with total_saless as(
	select extract('year' from o.order_date) as order_year,
		extract('month'from o.order_date) as order_month,
		sum(oi.quantity*oi.list_price) as total_sales
	from sales.orders o
	join sales.order_items oi
		on o.order_id= oi.order_id
	group by extract('year' from o.order_date),
		extract('month' from o.order_date))

select *,
	lag(total_sales,1)over(order by order_month asc) as last_month_sales,
	round((total_sales - lag(total_sales,1)over(order by order_month asc))/lag(total_sales,1)over(order by order_month asc)*100.0,2) as percentage
from total_saless;
	
--Calculate Running total of revenue
with cted as(
	select o.order_id,
		o.order_date,
		sum(oi.list_price*oi.quantity) as total_price
	from sales.orders o
	join sales.order_items oi
		on o.order_id = oi.order_id
	group by o.order_id, o.order_date)

select *,
	sum(total_price)over(order by order_date rows between unbounded preceding and current row) as running_total
from cted;


--Analyzing the 7-day average revenue (3 precedings & 3 followings)
with cte1 as(
	select o.order_date,
		sum(oi.list_price*oi.quantity) as total_price
	from sales.orders o
	join sales.order_items oi
		on o.order_id = oi.order_id
	group by o.order_date)

select order_date,
	total_price,
	round(avg(total_price)over(order by order_date rows between 3 preceding and 3 following),2) as average_revenue
from cte1
order by order_date;
