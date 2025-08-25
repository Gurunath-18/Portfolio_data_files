create database hr_project;
use hr_project;

## Employee_count
select  sum(employee_count) from hrdata ;

#Attrition Count

select count(attrition) from hrdata where attrition="Yes"  and department="R&D";
## and education="Doctoral Degree"

select concat( round((select count(attrition) from hrdata where attrition="Yes" and department="Sales")/
sum(employee_count)*100,2) ,"%")as attrition_Count from hrdata
where department="Sales";

select sum(employee_count)-(select count(attrition) from hrdata where attrition="Yes" and gender="Male") from hrdata
where gender="Male";

select  round(avg(age),0) as Avg_age from hrdata;

select gender, count(attrition) as Attrition  from hrdata where attrition="Yes"  and education="High School" group by gender order by Attrition desc;

## department and female wise attriton count and attriton %

select department,count(attrition)Attrition,concat(round(count(attrition)/(select count(attrition) from hrdata where attrition="Yes"and gender="Female")*100,2),"%")
as `Attrition_%` from hrdata 
where attrition="Yes" and gender="Female" group by department order by Attrition desc;

## no of employee by age group 

select age ,sum(employee_Count)no_of_Employee from hrdata group by age order by age asc;

## department wise attrition count 
select education_field, count(attrition) from hrdata where attrition="Yes" group by education_field order by 2 desc;

## Attrition rate by gender for different age group
select age_band, gender, count(attrition)Attriton ,concat(round(count(attrition)/(select count(attrition) from hrdata where attrition="Yes")*100,2),"%") `Attrition%`
from hrdata where attrition="Yes" group by age_band, gender order by age_band, gender;

##Job Satisfaction Rating 


select job_role,job_satisfaction,sum(employee_count)
from hrdata group by job_role,job_satisfaction 
order by job_role,job_satisfaction;
