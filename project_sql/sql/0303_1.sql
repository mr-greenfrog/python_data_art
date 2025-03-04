-- 1. 누적 구매 금액과 순위를 계산하는 임시 테이블 생성
CREATE TEMPORARY TABLE ranked_data AS
SELECT 
    user_id, 
    SUM(discounted_price) AS total_spent,
    ROW_NUMBER() OVER (ORDER BY SUM(discounted_price) DESC) AS `rank`,
    COUNT(*) OVER () AS total_count
FROM orders_completed
GROUP BY user_id;

-- 2. 사분위수 계산을 위한 임시 테이블 생성
CREATE TEMPORARY TABLE percentile_values AS
SELECT 
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.25) THEN total_spent END) AS percentile_75,
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.50) THEN total_spent END) AS percentile_50,
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.75) THEN total_spent END) AS percentile_25
FROM ranked_data;

-- 3. 고객 등급 부여
SELECT 
    rd.user_id,
    rd.total_spent,
    CASE
        WHEN rd.total_spent >= pv.percentile_75 THEN 'VIP'
        WHEN rd.total_spent >= pv.percentile_50 THEN 'Gold'
        WHEN rd.total_spent >= pv.percentile_25 THEN 'Silver'
        ELSE 'Bronze'
    END AS spending_grade
FROM ranked_data rd
CROSS JOIN percentile_values pv;



-- 1. 기존의 영구 테이블을 삭제 (필요 시)
DROP TABLE IF EXISTS customer_grades;

-- 2. 고객 등급을 포함한 영구 테이블 생성
CREATE TABLE customer_grades AS
SELECT 
    rd.user_id,
    rd.total_spent,
    CASE
        WHEN rd.total_spent >= pv.percentile_75 THEN 'VIP'
        WHEN rd.total_spent >= pv.percentile_50 THEN 'Gold'
        WHEN rd.total_spent >= pv.percentile_25 THEN 'Silver'
        ELSE 'Bronze'
    END AS spending_grade
FROM ranked_data rd
CROSS JOIN percentile_values pv;





-- 4. 임시 테이블 삭제 (필요 시)
DROP TEMPORARY TABLE IF EXISTS ranked_data;
DROP TEMPORARY TABLE IF EXISTS percentile_values;





-- ---------------------------
-- 1. 기존 임시 테이블 삭제 (필요 시)
DROP TEMPORARY TABLE IF EXISTS order_count_data;
DROP TEMPORARY TABLE IF EXISTS order_data_with_rank;
DROP TEMPORARY TABLE IF EXISTS order_percentile_values;
DROP TEMPORARY TABLE IF EXISTS order_count_grades;

-- 1. 누적 구매 횟수와 순위를 계산하는 임시 테이블 생성
DROP TEMPORARY TABLE IF EXISTS ranked_order_data;
CREATE TEMPORARY TABLE ranked_order_data AS
SELECT 
    user_id, 
    COUNT(id) AS total_orders,
    ROW_NUMBER() OVER (ORDER BY COUNT(id) DESC) AS `rank`,
    COUNT(*) OVER () AS total_count
FROM orders_completed
GROUP BY user_id;

-- 2. 사분위수 계산을 위한 임시 테이블 생성
DROP TEMPORARY TABLE IF EXISTS order_percentile_values;
CREATE TEMPORARY TABLE order_percentile_values AS
SELECT 
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.25) THEN total_orders END) AS percentile_75,
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.50) THEN total_orders END) AS percentile_50,
    MAX(CASE WHEN `rank` = FLOOR(total_count * 0.75) THEN total_orders END) AS percentile_25
FROM ranked_order_data;

-- 3. 고객 등급 부여
SELECT 
    rod.user_id,
    rod.total_orders,
    CASE
        WHEN rod.total_orders >= opv.percentile_75 THEN 'VIP'
        WHEN rod.total_orders >= opv.percentile_50 THEN 'Gold'
        WHEN rod.total_orders >= opv.percentile_25 THEN 'Silver'
        ELSE 'Bronze'
    END AS order_count_grade
FROM ranked_order_data rod
CROSS JOIN order_percentile_values opv;

-- 1. 기존의 영구 테이블 삭제 (필요 시)
DROP TABLE IF EXISTS order_count_grades;

-- 2. 구매 횟수별 고객 등급을 계산하여 새로운 영구 테이블 생성
CREATE TABLE order_count_grades AS
SELECT 
    rod.user_id,
    rod.total_orders,
    CASE
        WHEN rod.total_orders >= opv.percentile_75 THEN 'VIP'
        WHEN rod.total_orders >= opv.percentile_50 THEN 'Gold'
        WHEN rod.total_orders >= opv.percentile_25 THEN 'Silver'
        ELSE 'Bronze'
    END AS order_count_grade
FROM ranked_order_data rod
CROSS JOIN order_percentile_values opv;

