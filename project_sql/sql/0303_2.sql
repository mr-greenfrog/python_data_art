-- 1. 기존 임시 테이블 삭제 (필요 시)
DROP TEMPORARY TABLE IF EXISTS inactive_in_summer;
DROP TEMPORARY TABLE IF EXISTS completely_inactive;

-- 2. 6월에 거래가 있었으나 7~9월에 거래가 없는 고객을 임시 테이블에 저장
CREATE TEMPORARY TABLE inactive_in_summer AS
SELECT DISTINCT user_id
FROM orders_completed
WHERE created_at BETWEEN '2024-06-01' AND '2024-06-30'
AND user_id NOT IN (
    SELECT DISTINCT user_id
    FROM orders_completed
    WHERE created_at BETWEEN '2024-07-01' AND '2024-09-30'
);

-- 3. 위의 고객 중 10월부터 내년 1월까지도 거래가 없는 고객 저장
CREATE TEMPORARY TABLE completely_inactive AS
SELECT user_id
FROM inactive_in_summer
WHERE user_id NOT IN (
    SELECT DISTINCT user_id
    FROM orders_completed
    WHERE created_at BETWEEN '2024-10-01' AND '2025-01-31'
);

-- 4. 최종 결과 출력
SELECT count(*) 
FROM inactive_in_summer;

SELECT count(*) 
FROM completely_inactive;

-- 1. 기존 영구 테이블 삭제 (필요 시)
DROP TABLE IF EXISTS inactive_in_summer_permanent;
DROP TABLE IF EXISTS completely_inactive_permanent;

-- 2. inactive_in_summer 임시 테이블을 영구 테이블로 저장
CREATE TABLE inactive_in_summer_permanent AS
SELECT * FROM inactive_in_summer;

-- 3. completely_inactive 임시 테이블을 영구 테이블로 저장
CREATE TABLE completely_inactive_permanent AS
SELECT * FROM completely_inactive;

-- 1. 3개월 동안 꾸준히 주문한 고객을 조회
SELECT 
    user_id,
    COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) AS active_months
FROM orders_completed
WHERE created_at BETWEEN '2024-03-01' AND '2024-05-31'
AND user_id IN (SELECT user_id FROM inactive_in_summer_permanent)
GROUP BY user_id;

-- 2. 꾸준히 주문한 고객과 비활성화된 고객을 비교
SELECT 
    user_id,
    CASE 
        WHEN active_months = 3 THEN 'Consistent Buyer' 
        ELSE 'Irregular Buyer' 
    END AS purchase_pattern
FROM (
    SELECT 
        user_id,
        COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) AS active_months
    FROM orders_completed
    WHERE created_at BETWEEN '2024-03-01' AND '2024-05-31'
    AND user_id IN (SELECT user_id FROM inactive_in_summer_permanent)
    GROUP BY user_id
) AS purchase_data;


-- 이탈 고객의 등급별 분석
CREATE TEMPORARY TABLE temp_cb AS
SELECT 
    user_id
FROM (
    SELECT 
        user_id,
        COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) AS active_months
    FROM orders_completed
    WHERE created_at BETWEEN '2024-03-01' AND '2024-05-31'
    AND user_id IN (SELECT user_id FROM inactive_in_summer_permanent)
    GROUP BY user_id
) AS purchase_data
WHERE active_months = 3;

CREATE TEMPORARY TABLE temp_recent AS
SELECT DISTINCT user_id
FROM orders_completed
WHERE created_at >= '2024-10-01';

SELECT 
    cb.user_id, 
    cg.spending_grade,
    'Consistent Buyer' AS purchase_pattern
FROM temp_cb cb
JOIN customer_grades cg ON cb.user_id = cg.user_id
LEFT JOIN temp_recent recent ON cb.user_id = recent.user_id
WHERE recent.user_id IS NULL;


-- 통합 테이블
-- 1. 기존 임시 테이블 삭제 (필요 시)
DROP TEMPORARY TABLE IF EXISTS temp_cb;
DROP TEMPORARY TABLE IF EXISTS temp_recent;
DROP TEMPORARY TABLE IF EXISTS customer_activity_status;

-- 2. 3개월 동안 꾸준히 구매했던 고객 (Consistent Buyer) 임시 테이블 생성
CREATE TEMPORARY TABLE temp_cb AS
SELECT 
    user_id
FROM (
    SELECT 
        user_id,
        COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) AS active_months
    FROM orders_completed
    WHERE created_at BETWEEN '2024-03-01' AND '2024-05-31'
    AND user_id IN (SELECT user_id FROM inactive_in_summer_permanent)
    GROUP BY user_id
) AS purchase_data
WHERE active_months = 3;

-- 3. 최근 10월부터 1월까지 거래가 있는 고객 임시 테이블 생성
CREATE TEMPORARY TABLE temp_recent AS
SELECT DISTINCT user_id
FROM orders_completed
WHERE created_at BETWEEN '2024-10-01' AND '2025-01-31';

-- 4. 비활동 고객과 활동 고객을 모두 포함한 통합 테이블 생성
CREATE TEMPORARY TABLE customer_activity_status AS
SELECT 
    cb.user_id, 
    cg.spending_grade,
    'Inactive' AS activity_status
FROM temp_cb cb
JOIN customer_grades cg ON cb.user_id = cg.user_id
LEFT JOIN temp_recent recent ON cb.user_id = recent.user_id
WHERE recent.user_id IS NULL

UNION ALL

SELECT 
    active.user_id, 
    cg.spending_grade,
    'Active' AS activity_status
FROM temp_recent active
JOIN customer_grades cg ON active.user_id = cg.user_id;


-- 기존 테이블을 삭제하고 재생성
DROP TABLE IF EXISTS customer_activity_status_permanent;

-- Inactive 고객 데이터를 먼저 삽입
CREATE TABLE customer_activity_status_permanent AS
SELECT 
    cb.user_id, 
    cg.spending_grade,
    'Inactive' AS activity_status
FROM temp_cb cb
JOIN customer_grades cg ON cb.user_id = cg.user_id
LEFT JOIN temp_recent recent ON cb.user_id = recent.user_id
WHERE recent.user_id IS NULL;

-- Active 고객 데이터를 추가 (INSERT INTO 사용)
INSERT INTO customer_activity_status_permanent (user_id, spending_grade, activity_status)
SELECT 
    active.user_id, 
    cg.spending_grade,
    'Active' AS activity_status
FROM temp_recent active
JOIN customer_grades cg ON active.user_id = cg.user_id;


-- 1. 기존 테이블에 last_order_date 컬럼 추가 (이미 존재하면 무시)
ALTER TABLE customer_total_status_permanent 
ADD COLUMN last_order_date datetime;

-- 2. 고객의 마지막 주문 날짜 업데이트
UPDATE customer_total_status_permanent cts
JOIN (
    SELECT 
        user_id, 
        DATE_FORMAT(MAX(created_at), '%Y-%m-%d %H:%i:%s') AS last_order_date
    FROM orders_completed
    GROUP BY user_id
) latest_orders 
ON cts.user_id = latest_orders.user_id
SET cts.last_order_date = latest_orders.last_order_date;

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- 1. 2024년 3월~5월 꾸준한 주문 고객 식별 (수정):
SELECT
    user_id, count(user_id)
FROM
    orders_completed oc 
WHERE
    created_at >= '2024-03-01' AND created_at < '2024-06-01'
GROUP BY
    user_id
HAVING
    COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) = 3;

-- 2. 2024년 6월 이후 주문 감소 추세 분석
SELECT
    DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
    COUNT(DISTINCT oc.user_id) AS active_customers,
    COUNT(oc.masked_id) AS total_orders
FROM
    orders_completed oc
JOIN
    (SELECT user_id FROM orders_completed WHERE created_at >= '2024-03-01' AND created_at < '2024-06-01' GROUP BY user_id HAVING COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) = 3) AS cc ON oc.user_id = cc.user_id
WHERE
    oc.created_at >= '2024-03-01'
GROUP BY
    order_month
ORDER BY
    order_month;

-- 고객 등급별 이탈률 분석
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-03-01' AND oc.created_at < '2024-07-01'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-03' THEN order_count ELSE 0 END) AS march_orders,
        SUM(CASE WHEN order_month = '2024-04' THEN order_count ELSE 0 END) AS april_orders,
        SUM(CASE WHEN order_month = '2024-05' THEN order_count ELSE 0 END) AS may_orders,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS june_orders
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
        march_orders > 0 AND april_orders > 0 AND may_orders > 0 AND june_orders = 0
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


-- 영구테이블 저장
CREATE TABLE MonthlyOrderTrends AS
SELECT
    DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
    COUNT(DISTINCT oc.user_id) AS active_customers,
    COUNT(oc.masked_id) AS total_orders
FROM
    orders_completed oc
JOIN
    (SELECT user_id FROM orders_completed WHERE created_at >= '2024-03-01' AND created_at < '2024-06-01' GROUP BY user_id HAVING COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) = 3) AS cc ON oc.user_id = cc.user_id
WHERE
    oc.created_at >= '2024-03-01'
GROUP BY
    order_month
ORDER BY
    order_month;

-- 3번 영구테이블 저장
CREATE TABLE CustomerChurnRate AS
WITH CustomerOrders AS (
    SELECT
        oc.user_id,
        DATE_FORMAT(oc.created_at, '%Y-%m') AS order_month,
        COUNT(oc.masked_id) AS order_count
    FROM
        orders_completed oc
    WHERE
        oc.created_at >= '2024-03-01' AND oc.created_at < '2024-07-01'
    GROUP BY
        oc.user_id, order_month
),
MonthlyOrders AS (
    SELECT
        user_id,
        SUM(CASE WHEN order_month = '2024-03' THEN order_count ELSE 0 END) AS march_orders,
        SUM(CASE WHEN order_month = '2024-04' THEN order_count ELSE 0 END) AS april_orders,
        SUM(CASE WHEN order_month = '2024-05' THEN order_count ELSE 0 END) AS may_orders,
        SUM(CASE WHEN order_month = '2024-06' THEN order_count ELSE 0 END) AS june_orders
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
        march_orders > 0 AND april_orders > 0 AND may_orders > 0 AND june_orders = 0
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


-- 3개월간 주문이 있었으나 이후 3개월간 주문이 없으면 이후에도 주문을 하지 않는다
-- 데이트 오류 찾기
SELECT
    created_at
FROM
    orders_completed
WHERE
    created_at NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$';

-- 연도 월 추출(extract)
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    GROUP BY
        user_id, order_month
)
SELECT * FROM MonthlyOrders;


-- 본 실행 (3개월 이상 주문 했던 고객 이라는 조건절 삭제_로우가 없어짐)
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month -- 날짜 형식 수정
    FROM
        OrderPeriods op
    -- WHERE TIMESTAMPDIFF(MONTH, op.start_month, op.end_month) >= 2 -- 조건 제거 또는 완화
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m') -- 날짜 형식 수정
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m') -- 날짜 형식 수정
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;
-- churn_start_month : 잠재적인 이탈 고객의 이탈 시작 월

-- 영구테이블 생성
CREATE TABLE ChurnedCustomersAnalysis AS
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month
    FROM
        OrderPeriods op
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m')
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m')
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;


-- 데이터 범위 제한(12월까지로)
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    WHERE
        created_at < '2025-01-01' -- 데이터 범위 제한
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month
    FROM
        OrderPeriods op
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m')
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m')
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;
-- 영구테이블 생성
CREATE TABLE PotentialChurners AS 
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    WHERE
        created_at < '2025-01-01' -- 데이터 범위 제한
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month
    FROM
        OrderPeriods op
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m')
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m')
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;




-- 마지막 주문 후 2개월 동안 주문이 없는 고객만 잠재적 이탈 고객
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    WHERE
        created_at < '2025-01-01' -- 데이터 범위 제한
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month
    FROM
        OrderPeriods op
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m')
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m')
        )
        AND NOT EXISTS ( -- 추가 조건: 마지막 주문 후 2개월 동안 주문이 없는 고객
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month > pc.last_order_month
            AND mo.order_month < DATE_FORMAT(DATE_ADD(CONCAT(pc.last_order_month, '-01'), INTERVAL 2 MONTH), '%Y-%m')
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;
-- 영구테이블
CREATE TABLE PotentialChurners_2Month AS 
WITH MonthlyOrders AS (
    SELECT
        user_id,
        CONCAT(EXTRACT(YEAR FROM created_at), '-', LPAD(EXTRACT(MONTH FROM created_at), 2, '0')) AS order_month
    FROM
        orders_completed
    WHERE
        created_at < '2025-01-01' -- 데이터 범위 제한
    GROUP BY
        user_id, order_month
),
OrderPeriods AS (
    SELECT
        user_id,
        MIN(order_month) AS start_month,
        MAX(order_month) AS end_month
    FROM
        MonthlyOrders
    GROUP BY
        user_id
),
PotentialChurners AS (
    SELECT
        op.user_id,
        op.end_month AS last_order_month,
        DATE_ADD(CONCAT(op.end_month, '-01'), INTERVAL 3 MONTH) AS churn_start_month
    FROM
        OrderPeriods op
),
ChurnedCustomers AS (
    SELECT
        pc.user_id
    FROM
        PotentialChurners pc
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month >= DATE_FORMAT(pc.churn_start_month, '%Y-%m')
            AND mo.order_month < DATE_FORMAT(DATE_ADD(pc.churn_start_month, INTERVAL 3 MONTH), '%Y-%m')
        )
        AND NOT EXISTS ( -- 추가 조건: 마지막 주문 후 2개월 동안 주문이 없는 고객
            SELECT 1
            FROM MonthlyOrders mo
            WHERE mo.user_id = pc.user_id
            AND mo.order_month > pc.last_order_month
            AND mo.order_month < DATE_FORMAT(DATE_ADD(CONCAT(pc.last_order_month, '-01'), INTERVAL 2 MONTH), '%Y-%m')
        )
)
SELECT
    cc.user_id,
    pc.last_order_month,
    pc.churn_start_month
FROM
    ChurnedCustomers cc
JOIN
    PotentialChurners pc ON cc.user_id = pc.user_id;