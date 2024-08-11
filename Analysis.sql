/*1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region. */
SELECT market FROM dim_customer
	WHERE customer='Atliq Exclusive' AND region='APAC';



/*2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields: unique_products_2020, unique_products_2021, percentage_chg */
with unique_products_2020 as (
SELECT COUNT(DISTINCT product_code) AS unique_products_2020 FROM fact_gross_price
WHERE fiscal_year=2020),

unique_products_2021 as (
select count(distinct product_code) as unique_products_2021 from fact_gross_price
where fiscal_year=2021)

select unique_products_2020, unique_products_2021, (unique_products_2021-unique_products_2020)/unique_products_2020 as percentage_chg
from unique_products_2020
join unique_products_2021;



/*3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields: segment, product_count */
select segment, count(product_code) as product_count 
from dim_product
group by segment
order by product_count desc;



/*4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields: segment, product_count_2020, product_count_2021, difference */
with segment_product_2020 as (
select dim_product.segment, count(fact_gross_price.product_code) as product_count_2020
from dim_product
right join fact_gross_price
on dim_product.product_code = fact_gross_price.product_code
where fact_gross_price.fiscal_year=2020
group by segment
),
segment_product_2021 as (
select dim_product.segment, count(fact_gross_price.product_code) as product_count_2021
from dim_product
right join fact_gross_price
on dim_product.product_code = fact_gross_price.product_code
where fact_gross_price.fiscal_year=2021
group by segment)

select s20.segment, product_count_2020, product_count_2021, (product_count_2021-product_count_2020) as difference
from segment_product_2020 as s20
join segment_product_2021 as s21
on s20.segment = s21.segment
order by segment;



/*5. Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields: product_code, product manufacturing_cost */
with 
manu_cost_max_min 
as (
select max(manufacturing_cost) as manufacturing_cost_max_min
from fact_manufacturing_cost
union
select min(manufacturing_cost)
from fact_manufacturing_cost
)
select fact_manufacturing_cost.product_code, dim_product.product, manufacturing_cost_max_min
from manu_cost_max_min
left join fact_manufacturing_cost
on fact_manufacturing_cost.manufacturing_cost = manu_cost_max_min.manufacturing_cost_max_min
join dim_product
on dim_product.product_code = fact_manufacturing_cost.product_code
order by manufacturing_cost_max_min desc;



/*6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 
and in the Indian market. The final output contains these fields: customer_code, customer average_discount_percentage */
with 
customer_discount_market (market, customer, customer_code, fiscal_year, pre_invoice_discount_pct)
as (
select dim_customer.market, dim_customer.customer, fact_pre_invoice_deductions.customer_code, fact_pre_invoice_deductions.fiscal_year, fact_pre_invoice_deductions.pre_invoice_discount_pct
from fact_pre_invoice_deductions
left join dim_customer
on dim_customer.customer_code=fact_pre_invoice_deductions.customer_code
)
select customer_code, customer, pre_invoice_discount_pct as average_discount_percentage 
from customer_discount_market
where market='India' and fiscal_year=2021
order by average_discount_percentage desc
limit 5;



/*7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: Month, Year, Gross sales Amount */
alter table fact_sales_monthly 
add `month` int;
update fact_sales_monthly
set `month`=month(fact_sales_monthly.`date`);
select fact_sales_monthly.`month` as `Month`, fact_sales_monthly.fiscal_year as `Year`, round(sum(fact_gross_price.gross_price*fact_sales_monthly.sold_quantity)) as `Gross sales Amount`
from fact_sales_monthly
join fact_gross_price
on fact_sales_monthly.product_code = fact_gross_price.product_code
where fact_sales_monthly.customer_code in (
select customer_code from dim_customer
where customer='Atliq Exclusive')
group by `Year`, `Month`
order by `Year`, `Month`;



/*8. In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity */
select case
	when `month` <= 3 then 1
    when `month` <= 6 then 2
    when `month` <= 9 then 3
    else 4
    end as `Quarter`,
    sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by `Quarter`
order by total_sold_quantity desc;



/*9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields: channel, gross_sales_mln, percentage */
with channel_sales (channels, quantity, price, fiscal_year) as (
	select cus.`channel`, sales.sold_quantity, price.gross_price, sales.fiscal_year
    from fact_sales_monthly as sales
    left join dim_customer as cus
    on cus.customer_code = sales.customer_code
    left join fact_gross_price as price
    on sales.product_code = price.product_code
    where sales.fiscal_year = 2021
)
select channels as `channel`, round(sum(quantity*price)/1000000, 2) as gross_sales_mln, round(sum(quantity*price)*100/(select sum(quantity*price) from channel_sales), 2) as percentage
from channel_sales
group by `channel`
order by percentage desc;



/*10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields: division, product_code */
with division_quantity as (
	select product.division, sales.product_code, sum(sales.sold_quantity) as sold_quantity
    from dim_product as product
    right join fact_sales_monthly as sales
    on product.product_code = sales.product_code
    where sales.fiscal_year = 2021
    group by sales.product_code, product.division
)
select division, product_code
from (select division, product_code,
	row_number() over(partition by division order by sold_quantity desc) as sold_quantity_order
	from division_quantity) as division_product_code
    where sold_quantity_order <= 3;






