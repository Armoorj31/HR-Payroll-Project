-- load the dataset 
SELECT * FROM hr_payroll_data;
-- Step 1. Check for duplicates/clean and remove

SELECT employee_id, COUNT(employee_id)
FROM hr_payroll_data
GROUP BY employee_id
HAVING COUNT(employee_id) > 1;
-- many employeeid have a count greater than 1, so we need to verify if they are actually the same or different

SELECT * FROM hr_payroll_data
WHERE employee_id IN
(SELECT employee_id
FROM hr_payroll_data
GROUP BY employee_id
HAVING COUNT(employee_id) > 1);

-- One more check to see if they are actually distinct
SELECT employee_id
, COUNT(distinct(CONCAT(first_name, last_name, department, job_title, start_date, salary, work_email))) AS distinct_ver
FROM hr_payroll_data
GROUP BY employee_id
HAVING COUNT(*) > 1;

-- they are the exact same, so we will need to get rid of the duplicates. ADD a row_id because if deleted from employeeid, all the records that match will missing

ALTER TABLE hr_payroll_data ADD COLUMN row_id INT auto_increment Primary KEY;
-- 
SELECT * FROM 
(SELECT employee_id
, ROW_NUMBER () OVER(PARTITION BY employee_id ORDER BY employee_id) as row_num
FROM hr_payroll_data) as row_table
WHERE row_num > 1;

-- Delete duplicates from table
START TRANSACTION;

DELETE t1 FROM hr_payroll_data t1
JOIN hr_payroll_data t2
ON t1.employee_id = t2.employee_id
AND t1.row_id > t2.row_id;
-- check again for duplicates
SELECT employee_id, COUNT(employee_id)
FROM hr_payroll_data
GROUP BY employee_id
HAVING COUNT(employee_id) > 1;

commit;

-- No duplicates, so I can move on
-- Step 2. Name standarization

SELECT * FROM hr_payroll_data;
-- The first_name column is not properly formatted, so that needs to be dealt with first
UPDATE hr_payroll_data
SET first_name = CONCAT(
    UPPER(LEFT(first_name, 1)),
    LOWER(SUBSTRING(first_name, 2))
);
-- there is a few that didn't change due to whitespace being in front so I need to identify and fix
SELECT first_name from hr_payroll_data WHERE first_name != TRIM(first_name);
-- Make the update to the column
UPDATE hr_payroll_data
SET first_name = CONCAT(Upper(LEFT(TRIM(first_name) ,1)), LOWER(SUBSTRING(TRIM(first_name), 2)));

-- Check to see it worked
SELECT first_name from hr_payroll_data;

-- apply the same concepts to the Last_name column
UPDATE hr_payroll_data
SET last_name = CONCAT(
    UPPER(LEFT(last_name, 1)),
    LOWER(SUBSTRING(last_name, 2))
);
SELECT last_name from hr_payroll_data WHERE last_name != TRIM(last_name);
UPDATE hr_payroll_data
SET last_name = CONCAT(Upper(LEFT(TRIM(last_name) ,1)), LOWER(SUBSTRING(TRIM(last_name), 2)));

SELECT first_name
, last_name FROM hr_payroll_data;
-- Name columns look good so on to the department column next
-- Step 3. Department Standarization 

SELECT department from hr_payroll_data;
-- improper spelling, capitalization, etc so it needs to be standarized.

    Update hr_payroll_data
   SET department = 'Marketing'
   WHERE department LIKE '%mark%';
   
    Update hr_payroll_data
   SET department = 'Engineering'
   WHERE department LIKE '%engi%';
   
    Update hr_payroll_data
   SET department = 'Finance'
   WHERE department LIKE '%fina%';
   
    Update hr_payroll_data
   SET department = 'Customer Service'
   WHERE department LIKE '%custom%';
   
    Update hr_payroll_data
   SET department = 'Marketing'
   WHERE department LIKE '%mark%';
   
    Update hr_payroll_data
   SET department = 'Executive'
   WHERE department LIKE '%exec%';
   
    Update hr_payroll_data
   SET department = 'Human Resources'
   WHERE department LIKE '%Human%';
   
    Update hr_payroll_data
   SET department = 'Information Technology'
   WHERE department LIKE '%infor%';
   
    Update hr_payroll_data
   SET department = 'Legal'
   WHERE department LIKE '%lega%';
   
    Update hr_payroll_data
   SET department = 'Sales'
   WHERE department LIKE '%sale%';
   
    Update hr_payroll_data
   SET department = 'Operations'
   WHERE department LIKE '%Operat%';

SELECT * FROM hr_payroll_data;

-- job title looks solid, no errors so I move on to paygrade. 
-- Step 4. Salary cleaning
#check out the pay grade to make sure it's consistent
 SELECT pay_grade
    , MAX(Salary)
    , MIN(salary)
    , AVG(salary)
    , COUNT(*)
    from hr_payroll_data
    GROUP BY pay_grade
    ORDER BY AVG(Salary);
-- pay_grade ranges are similar but it is not accurate because the salary column is being read as different data types so that takes priority
 UPDATE hr_payroll_data
SET Salary = CASE
    WHEN Salary IS NULL OR TRIM(Salary) = ''
        THEN NULL
    WHEN Salary LIKE '%k' OR Salary LIKE '%K'
        THEN CAST(REPLACE(REPLACE(REPLACE(Salary, 'k', ''), 'K', ''), '$', '') AS DECIMAL(10,1)) * 1000
    ELSE CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(Salary, '$', ''), 'USD', ''), ',', ''), ' ', '')
        AS DECIMAL(10,2)
    )
END;

ALTER TABLE hr_payroll_data MODIFY Salary DECIMAL(10,2);

-- Step 5. Pay grade normlization
-- run pay grade query again
 SELECT pay_grade
    , MAX(Salary)
    , MIN(salary)
    , AVG(salary)
    , COUNT(*)
    from hr_payroll_data
    GROUP BY pay_grade
    ORDER BY AVG(Salary);


-- different pay bands but they're in similar ranges, so it needs to be more uniform
SELECT pay_grade
, CASE
		WHEN pay_grade IS NULL OR TRIM(pay_grade) = '' THEN NULL
        ELSE UPPER(REPLACE(TRIM(pay_grade), '-', ''))
        END AS normalized,
        COUNT(*) as cnt
FROM hr_payroll_data
GROUP BY pay_grade
ORDER BY normalized;

update hr_payroll_data
SET pay_grade = CASE
	WHEN pay_grade IS NULL OR TRIM(pay_grade) = ''
    THEN NULL
    ELSE UPPER(REPLACE(TRIM(pay_grade), '-', ''))
    END;
    
-- run paygrade query once again
 SELECT pay_grade
    , MAX(Salary)
    , MIN(salary)
    , AVG(salary)
    , COUNT(*)
    from hr_payroll_data
    GROUP BY pay_grade
    ORDER BY AVG(Salary);
    
    -- one pay grade is null, decide to leave it blank to preserve data integrity
   -- step 6. Date standarization 
   -- Move onto the start dates, want a standard format of yyyy-mm-dd
       SELECT DISTINCT start_date, LENGTH(start_date) 
FROM hr_payroll_data_practice
ORDER BY LENGTH(start_date);

START TRANSACTION;
UPDATE hr_payroll_data
SET start_date = CASE
    WHEN start_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(start_date, '%Y-%m-%d')
    WHEN start_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
        THEN STR_TO_DATE(start_date, '%Y/%m/%d')
    WHEN start_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN STR_TO_DATE(start_date, '%m/%d/%Y')
    WHEN start_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(start_date, '%m-%d-%y')
    WHEN start_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(start_date, '%d-%b-%Y')
    WHEN start_date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
        THEN STR_TO_DATE(start_date, '%M %d, %Y')
    ELSE NULL
END;
commit;
SELECT * FROM hr_payroll_data;
-- apply the same concepts to termination date, is blank they are still employed so we will make it null
UPDATE hr_payroll_data
SET termination_date = CASE
    WHEN termination_date IS NULL OR TRIM(termination_date) = '' THEN NULL
    WHEN termination_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(termination_date, '%Y-%m-%d')
    WHEN termination_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN STR_TO_DATE(termination_date, '%Y/%m/%d')
    WHEN termination_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN STR_TO_DATE(termination_date, '%m/%d/%Y')
    WHEN termination_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(termination_date, '%m-%d-%y')
    WHEN termination_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(termination_date, '%d-%b-%Y')
    WHEN termination_date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$' THEN STR_TO_DATE(termination_date, '%M %d, %Y')
    ELSE NULL
END;
SELECT * FROM hr_payroll_data;

-- checking to see if anyone was termed before they started
SELECT * FROM hr_payroll_data WHERE termination_date IS NOT NULL and termination_date < start_date;
-- we have 7 employees so we will need to change that

Update hr_payroll_data A
JOIN hr_payroll_data B
ON A.row_id = B.row_id
SET a.start_date = b.termination_date
WHERE b.termination_date IS NOT NULL AND b.termination_date < b.start_date;

-- run the term query beofre start date again 
SELECT * FROM hr_payroll_data WHERE termination_date IS NOT NULL and termination_date < start_date;

-- no rows are returned and then we can move onto the last thing and change the date columns to date types

ALTER TABLE hr_payroll_data MODIFY start_date DATE;
ALTER TABLE hr_payroll_data MODIFY termination_date DATE;

-- Step 7. Job Type standarization
-- Move onto next column of job type, I want it formatted aS Temp, Contract, Full-Time, Part-Time
Update hr_payroll_data
SET job_type = 'Temp'
WHERE job_type LIKE '%TEMP%';
    
Update hr_payroll_data
SET job_type = 'Full-Time'
WHERE job_type LIKE '%Full%';

Update hr_payroll_data
SET job_type = 'Full-Time'
WHERE job_type LIKE 'FT%';

Update hr_payroll_data
SET Job_Type = 'Part-Time'
WHERE job_type LIKE '%Part%';

Update hr_payroll_data
SET Job_Type = 'Part-Time'
WHERE job_type LIKE 'PT%';

Update hr_payroll_data
SET Job_Type = 'Contract'
WHERE job_type LIKE '%CONT%';

SELECT job_type FROM hr_payroll_data;

-- Step 8. Email normalization
-- Lastly all employees have an email that should be formated as FName + '.' LName + @atech.org ie Renfred.Armoo@atech.org. This ensyres we can differentiate between employees with same name.
-- find the amount of nulls
SELECT COUNT(*) FROM hr_payroll_data 
WHERE work_email iS NULL OR TRIM(work_email) = '';
-- check which specfiic employees are missing emails
SELECT * FROM hr_payroll_data
WHERE work_email iS NULL OR TRIM(work_email) = '';
-- update records to have emails for anything null or blank
Update hr_payroll_data
SET work_email = LOWER(CONCAT(first_name, '.', last_name, '@atech.org'))
WHERE work_email IS NULL OR TRIM(work_email) = '';

SELECT work_email FROM hr_payroll_data;
-- There are still some emails with the wrong domain so they need to identified and fixed

SELECT DISTINCT work_email FROM hr_payroll_data
WHERE work_email NOT LIKE '%@atech.org%' 
AND work_email IS NOT NULL
AND work_email != '';

-- Update emails
UPDATE hr_payroll_data
SET work_email = LOWER(CONCAT(first_name, '.', last_name, '@atech.org'))
WHERE work_email NOT LIKE '%@atech.org%' 
AND work_email IS NOT NULL
AND work_email != '';

-- check for potential same-name collisions created by standard format in the email
SELECT work_email, COUNT(*) from hr_payroll_data
GROUP BY work_email
HAVING COUNT(*) > 1;

SELECT work_email
, employee_id
, first_name
, last_name
, department
, job_title
FROM hr_payroll_data
WHERE work_email IN 
				(select work_email from hr_payroll_data
                GROUP BY work_email
                HAVING COUNT(*) > 1);
                
-- update email format, where there are same name collision, first occurence is standard format, next will be appended                
UPDATE hr_payroll_data a
JOIN (
    SELECT row_id,
           ROW_NUMBER() OVER (PARTITION BY work_email ORDER BY row_id) AS dupe_rank
    FROM hr_payroll_data
    WHERE work_email IN (
        SELECT work_email FROM hr_payroll_data GROUP BY work_email HAVING COUNT(*) > 1
    )
) b ON a.row_id = b.row_id
SET a.work_email = CASE
    WHEN b.dupe_rank = 1 THEN a.work_email
    ELSE CONCAT(SUBSTRING_INDEX(a.work_email, '@', 1), b.dupe_rank, '@atech.org')
END;
-- All done with data cleaning, now exploratory analysis.


-- Salary stats by department

SELECT department
, ROUND(AVG(salary),2) AS avg_salary
, MIN(salary) AS min_salary
, MAX(salary) AS max_salary
, COUNT(*) AS employeecount
FROM hr_payroll_data
GROUP BY department
ORDER BY avg_salary DESC;


-- New hires by year
SELECT YEAR(start_date) as hire_year
, COUNT(*) AS hires
from hr_payroll_data
GROUP BY hire_year
ORDER BY hire_year;

-- most common job titles and the respctive average slary of the position
SELECT job_title
, COUNT(*) AS employeecount
, ROUND(AVG(salary),2) AS avg_salary
FROM hr_payroll_data
GROUP BY job_title
ORDER BY employeecount DESC;

SELECT * FROM hr_payroll_data;
