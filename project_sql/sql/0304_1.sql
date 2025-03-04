-- 1단계: 2023년 8월부터 2024년 11월까지의 첫 주문 정보 임시 테이블 생성
CREATE TEMPORARY TABLE temp_first_orders AS
SELECT
    user_id,
    MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
FROM
    orders_completed
WHERE
    created_at >= '2023-08-01' AND created_at <= '2024-11-30'
GROUP BY
    user_id;

-- 2단계: 2024년 3월부터 첫 주문이 있는 신규 고객 임시 테이블 생성
CREATE TEMPORARY TABLE temp_new_customers AS
SELECT
    user_id,
    first_order_month
FROM
    temp_first_orders
WHERE
    first_order_month >= '2024-03';

-- 3단계: 기존 고객 임시 테이블 생성 (2024년 3월부터 11월까지)
CREATE TEMPORARY TABLE temp_existing_customers AS
SELECT
    DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
    COUNT(DISTINCT oc.user_id) AS active_customers,
    COUNT(oc.masked_id) AS total_orders
FROM
    orders_completed oc
WHERE oc.created_at >= '2024-03-01' AND oc.created_at <= '2024-11-30'
AND oc.user_id NOT IN (SELECT user_id FROM temp_new_customers)
GROUP BY
    order_month;

-- 4단계: 월별 주문 임시 테이블 생성 (2024년 3월부터 11월까지)
CREATE TEMPORARY TABLE temp_monthly_orders AS
SELECT
    DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
    COUNT(DISTINCT oc.user_id) AS total_customers,
    COUNT(oc.masked_id) AS total_orders
FROM
    orders_completed oc
WHERE oc.created_at >= '2024-03-01' AND oc.created_at <= '2024-11-30'
GROUP BY order_month;

-- 5단계: 최종 결과 출력
SELECT
    nc.first_order_month AS month,
    COUNT(DISTINCT nc.user_id) AS new_customers,
    ec.active_customers AS existing_customers,
    ec.total_orders AS existing_total_orders,
    mo.total_customers,
    mo.total_orders AS monthly_total_orders,
    (COUNT(DISTINCT nc.user_id) / mo.total_customers) * 100 AS new_customer_rate
FROM
    temp_new_customers nc
JOIN
    temp_existing_customers ec ON nc.first_order_month = ec.order_month
JOIN
    temp_monthly_orders mo ON nc.first_order_month = mo.order_month
GROUP BY
    nc.first_order_month, ec.active_customers, ec.total_orders, mo.total_customers, mo.total_orders
ORDER BY
    month;

-- 영구테이블
CREATE TABLE customer_analysis_results AS
SELECT
    nc.first_order_month AS month,
    COUNT(DISTINCT nc.user_id) AS new_customers,
    ec.active_customers AS existing_customers,
    ec.total_orders AS existing_total_orders,
    mo.total_customers,
    mo.total_orders AS monthly_total_orders,
    (COUNT(DISTINCT nc.user_id) / mo.total_customers) * 100 AS new_customer_rate
FROM
    temp_new_customers nc
JOIN
    temp_existing_customers ec ON nc.first_order_month = ec.order_month
JOIN
    temp_monthly_orders mo ON nc.first_order_month = mo.order_month
GROUP BY
    nc.first_order_month, ec.active_customers, ec.total_orders, mo.total_customers, mo.total_orders
ORDER BY
    month;

-- 6단계: 임시 테이블 삭제
DROP TEMPORARY TABLE temp_first_orders;
DROP TEMPORARY TABLE temp_new_customers;
DROP TEMPORARY TABLE temp_existing_customers;
DROP TEMPORARY TABLE temp_monthly_orders;


-- ------------------------------------------------------
-- ------------------------------------------------------
-- ------------------------------------------------------
-- 이탈률 코드 수정
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2023-08-01' AND oc.created_at <= '2024-11-30'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2023-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2023-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2023-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2023-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2023-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2024-01' THEN order_count ELSE 0 END) AS jan_orders,
        SUM(CASE WHEN order_month = '2024-02' THEN order_count ELSE 0 END) AS feb_orders,
        SUM(CASE WHEN order_month = '2024-03' THEN order_count ELSE 0 END) AS mar_orders,
        SUM(CASE WHEN order_month = '2024-04' THEN order_count ELSE 0 END) AS apr_orders,
        SUM(CASE WHEN order_month = '2024-05' THEN order_count ELSE 0 END) AS may_orders,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug2_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep2_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct2_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov2_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
ChurnedCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        mar_orders > 0 AND apr_orders = 0 AND may_orders = 0 AND jun_orders = 0 AND jul_orders = 0 AND aug2_orders = 0 AND sep2_orders = 0 AND oct2_orders = 0 AND nov2_orders = 0
)
SELECT
    cg.spending_grade,
    COUNT(DISTINCT cc.user_id) AS churned_customer_count
FROM
    ChurnedCustomers cc
JOIN
    customer_grades cg ON cc.user_id = cg.user_id
GROUP BY
    cg.spending_grade
ORDER BY
    churned_customer_count DESC;

-- 이탈률 코드 (2024년 1월~3월 주문 고객 기준)
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-01-01' AND oc.created_at <= '2024-11-30'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-01' THEN order_count ELSE 0 END) AS jan_orders,
        SUM(CASE WHEN order_month = '2024-02' THEN order_count ELSE 0 END) AS feb_orders,
        SUM(CASE WHEN order_month = '2024-03' THEN order_count ELSE 0 END) AS mar_orders,
        SUM(CASE WHEN order_month = '2024-04' THEN order_count ELSE 0 END) AS apr_orders,
        SUM(CASE WHEN order_month = '2024-05' THEN order_count ELSE 0 END) AS may_orders,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
ChurnedCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        jan_orders > 0 AND feb_orders > 0 AND mar_orders > 0 AND apr_orders = 0
)
SELECT
    cg.spending_grade,
    COUNT(DISTINCT cc.user_id) AS churned_customer_count
FROM
    ChurnedCustomers cc
JOIN
    customer_grades cg ON cc.user_id = cg.user_id
GROUP BY
    cg.spending_grade
ORDER BY
    churned_customer_count DESC;

-- -------------------------------------------------
-- 6개월로 줄임 (6~8월 주문 有, 이후 25년 1월까지 주문 없는 회원 기준)
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at < '2025-02-01' -- 2024년 6월부터 2025년 1월까지
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2024-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2025-01' THEN order_count ELSE 0 END) AS jan_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
ChurnedCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        jun_orders > 0 AND jul_orders > 0 AND aug_orders > 0  -- 2024년 6월부터 8월까지 거래를 했던 고객
        AND sep_orders = 0  -- 2024년 9월부터 주문이 없는 고객
)
SELECT
    cg.spending_grade,
    COUNT(DISTINCT cc.user_id) AS churned_customer_count
FROM
    ChurnedCustomers cc
JOIN
    customer_grades cg ON cc.user_id = cg.user_id
GROUP BY
    cg.spending_grade
ORDER BY
    churned_customer_count DESC;

CREATE TABLE existing_customers_analysis AS
SELECT
    DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
    COUNT(DISTINCT oc.user_id) AS active_customers,
    COUNT(oc.masked_id) AS total_orders
FROM
    orders_completed oc
WHERE oc.created_at >= '2024-03-01' AND oc.created_at <= '2024-11-30'
AND oc.user_id NOT IN (SELECT user_id FROM temp_first_orders)
GROUP BY
    order_month;

-- 영구테이블
CREATE TABLE 6m_customers_analysis AS
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at < '2025-02-01' -- 2024년 6월부터 2025년 1월까지
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2024-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2025-01' THEN order_count ELSE 0 END) AS jan_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
ChurnedCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        jun_orders > 0 AND jul_orders > 0 AND aug_orders > 0  -- 2024년 6월부터 8월까지 거래를 했던 고객
        AND sep_orders = 0  -- 2024년 9월부터 주문이 없는 고객
)
SELECT
    cg.spending_grade,
    COUNT(DISTINCT cc.user_id) AS churned_customer_count
FROM
    ChurnedCustomers cc
JOIN
    customer_grades cg ON cc.user_id = cg.user_id
GROUP BY
    cg.spending_grade
ORDER BY
    churned_customer_count DESC;

-- 6월~8월 주문 고객들이 어떤 상승세로 이탈했는지?
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at < '2025-02-01'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2024-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2025-01' THEN order_count ELSE 0 END) AS jan_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
InitialCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        jun_orders > 0 AND jul_orders > 0 AND aug_orders > 0
),
ChurnedCustomers AS (
    SELECT
        user_id,
        CASE
            WHEN sep_orders = 0 THEN '2024-09'
            WHEN oct_orders = 0 THEN '2024-10'
            WHEN nov_orders = 0 THEN '2024-11'
            WHEN dec_orders = 0 THEN '2024-12'
            WHEN jan_orders = 0 THEN '2025-01'
            ELSE 'Still Active'
        END AS churned_month
    FROM
        MonthlyOrders
    WHERE
        user_id IN (SELECT user_id FROM InitialCustomers)
)
SELECT
    churned_month,
    COUNT(DISTINCT user_id) AS churned_customer_count
FROM
    ChurnedCustomers
GROUP BY
    churned_month
ORDER BY
    churned_month;

-- 상승세 영구테이블 (6월~8월 고객 기준)
CREATE TABLE churned_customers_by_month AS  -- 테이블 이름을 지정합니다.
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at < '2025-02-01'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2024-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2025-01' THEN order_count ELSE 0 END) AS jan_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
InitialCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        jun_orders > 0 AND jul_orders > 0 AND aug_orders > 0
),
ChurnedCustomers AS (
    SELECT
        user_id,
        CASE
            WHEN sep_orders = 0 THEN '2024-09'
            WHEN oct_orders = 0 THEN '2024-10'
            WHEN nov_orders = 0 THEN '2024-11'
            WHEN dec_orders = 0 THEN '2024-12'
            WHEN jan_orders = 0 THEN '2025-01'
            ELSE 'Still Active'
        END AS churned_month
    FROM
        MonthlyOrders
    WHERE
        user_id IN (SELECT user_id FROM InitialCustomers)
)
SELECT
    churned_month,
    COUNT(DISTINCT user_id) AS churned_customer_count
FROM
    ChurnedCustomers
GROUP BY
    churned_month
ORDER BY
    churned_month;


-- 유입률 (23년 8월부터 봤을 때 24년 6월에 신규 고객인 사람들 상승세)
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2025-01-31'
    GROUP BY
        user_id
),
NewCustomers AS (
    SELECT
        first_order_month,
        COUNT(DISTINCT user_id) AS new_customers
    FROM
        FirstOrders
    WHERE
        first_order_month >= '2024-06'
    GROUP BY
        first_order_month
),
MonthlyOrders AS (
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS order_month,
        COUNT(DISTINCT user_id) AS total_customers
    FROM
        orders_completed
    WHERE
        created_at >= '2024-06-01' AND created_at <= '2025-01-31'
    GROUP BY
        order_month
)
SELECT
    nc.first_order_month AS month,
    nc.new_customers,
    mo.total_customers,
    (nc.new_customers / mo.total_customers) * 100 AS new_customer_rate
FROM
    NewCustomers nc
JOIN
    MonthlyOrders mo ON nc.first_order_month = mo.order_month
ORDER BY
    month;

CREATE TABLE new_customer_monthly_rate AS  -- 테이블 이름을 지정합니다.
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2025-01-31'
    GROUP BY
        user_id
),
NewCustomers AS (
    SELECT
        first_order_month,
        COUNT(DISTINCT user_id) AS new_customers
    FROM
        FirstOrders
    WHERE
        first_order_month >= '2024-06'
    GROUP BY
        first_order_month
),
MonthlyOrders AS (
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS order_month,
        COUNT(DISTINCT user_id) AS total_customers
    FROM
        orders_completed
    WHERE
        created_at >= '2024-06-01' AND created_at <= '2025-01-31'
    GROUP BY
        order_month
)
SELECT
    nc.first_order_month AS month,
    nc.new_customers,
    mo.total_customers,
    (nc.new_customers / mo.total_customers) * 100 AS new_customer_rate
FROM
    NewCustomers nc
JOIN
    MonthlyOrders mo ON nc.first_order_month = mo.order_month
ORDER BY
    month;


WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-03-01' AND oc.created_at < '2025-02-01'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-03' THEN order_count ELSE 0 END) AS mar_orders,
        SUM(CASE WHEN order_month = '2024-04' THEN order_count ELSE 0 END) AS apr_orders,
        SUM(CASE WHEN order_month = '2024-05' THEN order_count ELSE 0 END) AS may_orders,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS jun_orders,
        SUM(CASE WHEN order_month = '2024-07' THEN order_count ELSE 0 END) AS jul_orders,
        SUM(CASE WHEN order_month = '2024-08' THEN order_count ELSE 0 END) AS aug_orders,
        SUM(CASE WHEN order_month = '2024-09' THEN order_count ELSE 0 END) AS sep_orders,
        SUM(CASE WHEN order_month = '2024-10' THEN order_count ELSE 0 END) AS oct_orders,
        SUM(CASE WHEN order_month = '2024-11' THEN order_count ELSE 0 END) AS nov_orders,
        SUM(CASE WHEN order_month = '2024-12' THEN order_count ELSE 0 END) AS dec_orders,
        SUM(CASE WHEN order_month = '2025-01' THEN order_count ELSE 0 END) AS jan_orders
    FROM
        CustomerOrders
    GROUP BY
        user_id
),
InitialCustomers AS (
    SELECT
        user_id
    FROM
        MonthlyOrders
    WHERE
        mar_orders > 0 AND apr_orders > 0 AND may_orders > 0
),
ChurnedCustomers AS (
    SELECT
        user_id,
        CASE
            WHEN jun_orders = 0 THEN '2024-06'
            WHEN jul_orders = 0 THEN '2024-07'
            WHEN aug_orders = 0 THEN '2024-08'
            WHEN sep_orders = 0 THEN '2024-09'
            WHEN oct_orders = 0 THEN '2024-10'
            WHEN nov_orders = 0 THEN '2024-11'
            WHEN dec_orders = 0 THEN '2024-12'
            WHEN jan_orders = 0 THEN '2025-01'
            ELSE 'Still Active'
        END AS churned_month
    FROM
        MonthlyOrders
    WHERE
        user_id IN (SELECT user_id FROM InitialCustomers)
)
SELECT
    churned_month,
    COUNT(DISTINCT user_id) AS churned_customer_count
FROM
    ChurnedCustomers
GROUP BY
    churned_month
ORDER BY
    churned_month;

-- 2023년 8월부터 2025년 1월까지의 데이터를 보고, 2024년 6월에 첫 주문을 한 고객들의 월별 이탈 여부
CREATE TEMPORARY TABLE ChurnedCustomers AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2025-01-31'
    GROUP BY
        user_id
),
June2024FirstOrders AS (
    SELECT
        user_id
    FROM
        FirstOrders
    WHERE
        first_order_month = '2024-06'
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at <= '2025-01-31'
)
SELECT
    fo.user_id,
    fo.first_order_month,
    COALESCE(
        CASE WHEN mo7.order_month IS NULL THEN '2024-07' END,
        CASE WHEN mo8.order_month IS NULL THEN '2024-08' END,
        CASE WHEN mo9.order_month IS NULL THEN '2024-09' END,
        CASE WHEN mo10.order_month IS NULL THEN '2024-10' END,
        CASE WHEN mo11.order_month IS NULL THEN '2024-11' END,
        CASE WHEN mo12.order_month IS NULL THEN '2024-12' END,
        CASE WHEN mo1.order_month IS NULL THEN '2025-01' END
    ) AS churned_month
FROM
    FirstOrders fo
LEFT JOIN
    MonthlyOrders mo7 ON fo.user_id = mo7.user_id AND mo7.order_month = '2024-07'
LEFT JOIN
    MonthlyOrders mo8 ON fo.user_id = mo8.user_id AND mo8.order_month = '2024-08'
LEFT JOIN
    MonthlyOrders mo9 ON fo.user_id = mo9.user_id AND mo9.order_month = '2024-09'
LEFT JOIN
    MonthlyOrders mo10 ON fo.user_id = mo10.user_id AND mo10.order_month = '2024-10'
LEFT JOIN
    MonthlyOrders mo11 ON fo.user_id = mo11.user_id AND mo11.order_month = '2024-11'
LEFT JOIN
    MonthlyOrders mo12 ON fo.user_id = mo12.user_id AND mo12.order_month = '2024-12'
LEFT JOIN
    MonthlyOrders mo1 ON fo.user_id = mo1.user_id AND mo1.order_month = '2025-01'
WHERE fo.user_id IN (SELECT user_id FROM June2024FirstOrders);


-- 유입된 신규고객 이탈률
-- 2023년 8월 1일부터 2025년 1월 31일 사이에 가입한 고객
-- 2024년 6월에 첫 주문을 한 고객
-- 2024년 7월부터 2025년 1월 사이에 주문 내역이 없는 고객
-- 1. 임시 테이블 생성 쿼리 (별도 실행)
CREATE TEMPORARY TABLE ChurnedCustomers AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2025-01-31'
    GROUP BY
        user_id
),
June2024FirstOrders AS (
    SELECT
        user_id
    FROM
        FirstOrders
    WHERE
        first_order_month = '2024-06'
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at <= '2025-01-31'
)
SELECT
    fo.user_id,
    fo.first_order_month,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-07') THEN '2024-07'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-08') THEN '2024-08'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-09') THEN '2024-09'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-10') THEN '2024-10'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-11') THEN '2024-11'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-12') THEN '2024-12'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2025-01') THEN '2025-01'
        ELSE NULL
    END AS churned_month
FROM
    FirstOrders fo
WHERE fo.user_id IN (SELECT user_id FROM June2024FirstOrders);

drop temporary table ChurnedCustomers;

-- 2. 결과 조회 쿼리 (별도 실행)
SELECT
    churned_month AS month,
    COUNT(*) AS churned_customers
FROM
    ChurnedCustomers
WHERE
    churned_month IS NOT NULL
GROUP BY
    churned_month
ORDER BY
    month;

-- 영구테이블
CREATE TABLE ChurnedCustomers_Permanent AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2025-01-31'
    GROUP BY
        user_id
),
June2024FirstOrders AS (
    SELECT
        user_id
    FROM
        FirstOrders
    WHERE
        first_order_month = '2024-06'
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-06-01' AND oc.created_at <= '2025-01-31'
)
SELECT
    fo.user_id,
    fo.first_order_month,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-07') THEN '2024-07'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-08') THEN '2024-08'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-09') THEN '2024-09'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-10') THEN '2024-10'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-11') THEN '2024-11'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-12') THEN '2024-12'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2025-01') THEN '2025-01'
        ELSE NULL
    END AS churned_month
FROM
    FirstOrders fo
WHERE fo.user_id IN (SELECT user_id FROM June2024FirstOrders);


-- 이탈률
-- 2023년 8월부터 2024년 5월 이전에 가입 후 첫 주문을 한 고객 
-- 2024년 7월부터 2025년 1월 사이에 주문 내역이 없는 고객
-- 1. 임시 테이블 생성 쿼리 (별도 실행)
CREATE TEMPORARY TABLE ChurnedCustomers2 AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2024-05-31'
    GROUP BY
        user_id
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-07-01' AND oc.created_at <= '2025-01-31'
)
SELECT
    fo.user_id,
    fo.first_order_month,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-07') THEN '2024-07'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-08') THEN '2024-08'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-09') THEN '2024-09'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-10') THEN '2024-10'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-11') THEN '2024-11'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-12') THEN '2024-12'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2025-01') THEN '2025-01'
        ELSE NULL
    END AS churned_month
FROM
    FirstOrders fo;

-- 2. 결과 조회 쿼리 (별도 실행)
SELECT
    churned_month AS month,
    COUNT(*) AS churned_customers
FROM
    ChurnedCustomers2
WHERE
    churned_month IS NOT NULL
GROUP BY
    churned_month
ORDER BY
    month;

-- 영구 테이블
CREATE TABLE final_ChurnedCustomers_Permanent AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2024-05-31'
    GROUP BY
        user_id
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-07-01' AND oc.created_at <= '2025-01-31'
)
SELECT
    fo.user_id,
    fo.first_order_month,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-07') THEN '2024-07'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-08') THEN '2024-08'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-09') THEN '2024-09'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-10') THEN '2024-10'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-11') THEN '2024-11'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-12') THEN '2024-12'
        WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2025-01') THEN '2025-01'
        ELSE NULL
    END AS churned_month
FROM
    FirstOrders fo;

-- 이탈(영구테이블)_ grade_ 2308~2405 주문자
CREATE TABLE final_grade_ChurnedCustomers_Permanent AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at >= '2023-08-01' AND created_at <= '2024-05-31'
    GROUP BY
        user_id
),
MonthlyOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-07-01' AND oc.created_at <= '2025-01-31'
),
ChurnedCustomers AS (
    SELECT
        fo.user_id,
        fo.first_order_month,
        CASE
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-07') THEN '2024-07'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-08') THEN '2024-08'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-09') THEN '2024-09'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-10') THEN '2024-10'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-11') THEN '2024-11'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2024-12') THEN '2024-12'
            WHEN NOT EXISTS (SELECT 1 FROM MonthlyOrders mo WHERE mo.user_id = fo.user_id AND mo.order_month = '2025-01') THEN '2025-01'
            ELSE NULL
        END AS churned_month
    FROM
        FirstOrders fo
)
SELECT 
    cc.user_id,
    cc.first_order_month,
    cc.churned_month,
    cg.spending_grade
FROM 
    ChurnedCustomers cc
JOIN 
    customer_grades cg ON cc.user_id = cg.user_id;


CREATE TABLE final_grade_ChurnedCustomers_Permanent AS
WITH FirstOrders AS (
    SELECT
        user_id,
        MIN(DATE_FORMAT(created_at, '%Y-%m')) AS first_order_month
    FROM
        orders_completed
    WHERE
        created_at BETWEEN '2023-08-01' AND '2024-05-31'
    GROUP BY
        user_id
),
MonthlyOrders AS (
    SELECT
        user_id,
        DATE_FORMAT(created_at, '%Y-%m') AS order_month
    FROM
        orders_completed
    WHERE
        created_at BETWEEN '2024-07-01' AND '2025-01-31'
),
ChurnedCustomers AS (
    SELECT
        fo.user_id,
        fo.first_order_month,
        MIN(target_month) AS churned_month
    FROM
        FirstOrders fo
        CROSS JOIN (
            SELECT '2024-07' AS target_month UNION ALL
            SELECT '2024-08' UNION ALL
            SELECT '2024-09' UNION ALL
            SELECT '2024-10' UNION ALL
            SELECT '2024-11' UNION ALL
            SELECT '2024-12' UNION ALL
            SELECT '2025-01'
        ) AS target
    LEFT JOIN 
        MonthlyOrders mo 
        ON fo.user_id = mo.user_id AND mo.order_month = target.target_month
    WHERE 
        mo.user_id IS NULL
    GROUP BY
        fo.user_id, fo.first_order_month
)
SELECT 
    cc.user_id,
    cc.first_order_month,
    cc.churned_month,
    cg.spending_grade
FROM 
    ChurnedCustomers cc
JOIN 
    customer_grades cg ON cc.user_id = cg.user_id;


-- 데이터 수정
UPDATE final_grade_churnedcustomers_permanent
SET first_order_month = STR_TO_DATE(CONCAT(first_order_month, '-01'), '%Y-%m-%d');

UPDATE final_grade_churnedcustomers_permanent
SET churned_month = STR_TO_DATE(CONCAT(churned_month, '-01'), '%Y-%m-%d');

-- 데이터 타입 변경
ALTER TABLE final_grade_churnedcustomers_permanent
MODIFY COLUMN first_order_month DATE;

ALTER TABLE final_grade_churnedcustomers_permanent
MODIFY COLUMN churned_month DATE;


-- 데이터 수정
UPDATE new_customer_monthly_rate
SET month = STR_TO_DATE(CONCAT(month, '-01'), '%Y-%m-%d');

UPDATE final_3rd_upper_churnedcustomer_permanent
SET churned_month = STR_TO_DATE(CONCAT(churned_month, '-01'), '%Y-%m-%d');

-- 데이터 타입 변경
ALTER TABLE new_customer_monthly_rate
MODIFY COLUMN month DATE;

ALTER TABLE final_3rd_upper_churnedcustomer_permanent
MODIFY COLUMN churned_month DATE;