-- queries.sql — SQL Analytics Lab
-- Module 3: SQL & Relational Data

-- Q1: Employee Directory with Departments
SELECT e.first_name, e.last_name, e.title, e.salary, d.department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
ORDER BY d.department_name ASC, e.salary DESC;

-- Q2: Department Salary Analysis
SELECT d.department_name, SUM(e.salary) AS total_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_name
HAVING SUM(e.salary) > 150000;

-- Q3: Highest-Paid Employee per Department
WITH RankedEmployees AS (
    SELECT d.department_name, e.first_name, e.last_name, e.salary,
           RANK() OVER (PARTITION BY d.department_name ORDER BY e.salary DESC) as rnk
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
)
SELECT department_name, first_name, last_name, salary
FROM RankedEmployees
WHERE rnk = 1;

-- Q4: Project Staffing Overview
SELECT p.project_name, 
       COUNT(pa.employee_id) AS employee_count, 
       COALESCE(SUM(pa.hours_allocated), 0) AS total_hours
FROM projects p
LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.project_name;

-- Q5: Above-Average Departments
WITH DeptAvg AS (
    SELECT d.department_name, AVG(e.salary) as avg_salary
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
    GROUP BY d.department_name
),
CompanyAvg AS (
    SELECT AVG(salary) as total_avg FROM employees
)
SELECT department_name, avg_salary
FROM DeptAvg
WHERE avg_salary > (SELECT total_avg FROM CompanyAvg);

-- Q6: Running Salary Total
SELECT d.department_name, e.first_name, e.last_name, e.hire_date, e.salary,
       SUM(e.salary) OVER (PARTITION BY d.department_name ORDER BY e.hire_date) as running_total
FROM employees e
JOIN departments d ON e.department_id = d.department_id;

-- Q7: Unassigned Employees
SELECT e.first_name, e.last_name, d.department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
LEFT JOIN project_assignments pa ON e.employee_id = pa.employee_id
WHERE pa.project_id IS NULL;

-- Q8: Hiring Trends
SELECT 
    EXTRACT(YEAR FROM hire_date) AS hire_year, 
    EXTRACT(MONTH FROM hire_date) AS hire_month, 
    COUNT(*) AS hires
FROM employees
GROUP BY hire_year, hire_month
ORDER BY hire_year, hire_month;

-- Q9: Schema Design — Employee Certifications

-- Task 1 & 2: Create Tables
CREATE TABLE certifications (
    certification_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    issuing_org VARCHAR(255),
    level VARCHAR(50)
);

CREATE TABLE employee_certifications (
    id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(employee_id),
    certification_id INT REFERENCES certifications(certification_id),
    certification_date DATE NOT NULL
);

-- Task 3: Insert Records
INSERT INTO certifications (name, issuing_org, level) VALUES
('AWS Certified Solutions Architect', 'Amazon', 'Associate'),
('Professional Scrum Master I', 'Scrum.org', 'Intermediate'),
('Google Data Analytics', 'Google', 'Entry');

INSERT INTO employee_certifications (employee_id, certification_id, certification_date) VALUES
(1, 1, '2025-01-10'),
(2, 1, '2025-02-15'),
(3, 2, '2024-12-05'),
(4, 3, '2025-03-20'),
(5, 2, '2025-01-25');

-- Task 4: Final Join Query
SELECT e.first_name, e.last_name, c.name AS certification_name, c.issuing_org, ec.certification_date
FROM employees e
JOIN employee_certifications ec ON e.employee_id = ec.employee_id
JOIN certifications c ON ec.certification_id = c.certification_id;

-- Challenge Level 1: Complex Analytics

-- 1. المشاريع المعرضة للخطر (تجاوز 80% من الميزانية)
SELECT p.project_name, 
       p.budget, 
       SUM(pa.hours_allocated * 50) AS current_spending -- فرضنا تكلفة الساعة 50
FROM projects p
JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.project_name, p.budget
HAVING SUM(pa.hours_allocated * 50) > (p.budget * 0.8);

-- 2. موظفون يعملون في مشاريع خارج أقسامهم
SELECT e.first_name, e.last_name, d.department_name AS emp_dept, p.project_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN project_assignments pa ON e.employee_id = pa.employee_id
JOIN projects p ON pa.project_id = p.project_id
WHERE e.department_id != p.department_id;

-- Challenge Level 2: Dynamic Reporting

-- 1. إنشاء رؤية مادية (Materialized View) لملخص القسم
CREATE MATERIALIZED VIEW dept_project_summary AS
SELECT d.department_name, 
       COUNT(DISTINCT p.project_id) AS active_projects,
       COUNT(e.employee_id) AS staff_count,
       SUM(e.salary) AS payroll_cost
FROM departments d
LEFT JOIN projects p ON d.department_id = p.department_id
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_name;

-- 2. دالة PostgreSQL لإرجاع بيانات القسم كـ JSON
CREATE OR REPLACE FUNCTION get_dept_stats_json(dept_name TEXT)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'department', d.department_name,
            'employee_count', COUNT(e.employee_id),
            'total_salary', SUM(e.salary)
        )
        FROM departments d
        JOIN employees e ON d.department_id = e.department_id
        WHERE d.department_name = dept_name
        GROUP BY d.department_name
    );
END;
$$ LANGUAGE plpgsql;

-- Challenge Level 3: Schema Evolution

-- 1. جدول تتبع تاريخ الرواتب
CREATE TABLE salary_history (
    history_id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(employee_id),
    old_salary DECIMAL(10,2),
    new_salary DECIMAL(10,2),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. ترحيل البيانات الحالية للسجل
INSERT INTO salary_history (employee_id, new_salary)
SELECT employee_id, salary FROM employees;

-- 3. استعلام الموظفين المستحقين لمراجعة الراتب (مرور 12 شهر)
SELECT e.first_name, e.last_name, e.hire_date
FROM employees e
WHERE e.hire_date <= CURRENT_DATE - INTERVAL '12 months';