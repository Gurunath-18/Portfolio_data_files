use sql_project;

CREATE TABLE Combined_Internet_Sales AS
SELECT * FROM Fact_Internet_Sales_New
UNION ALL
SELECT * FROM FactInternetSales;

ALTER TABLE Combined_Internet_Sales
ADD COLUMN SalesAmount DECIMAL(18,2),
ADD COLUMN ProductionCost DECIMAL(18,2),
ADD COLUMN TotalProfit DECIMAL(18,2);

SET SQL_SAFE_UPDATES = 0;
UPDATE Combined_Internet_Sales
SET 
    SalesAmount = (OrderQuantity * UnitPrice) - DiscountAmount,
    ProductionCost = OrderQuantity * ProductStandardCost,
    TotalProfit = ((OrderQuantity * UnitPrice) - DiscountAmount) - (OrderQuantity * ProductStandardCost);
    
-- 1 Quarterly and Overall Sales, Cost, and Profit Summary (in Thousands)
SELECT 
    CONCAT(d.CalendarYear, ' Q', d.FiscalQuarter) AS Period,
    FORMAT(SUM(f.SalesAmount) / 1000, 0) AS TotalSales_K,
    FORMAT(SUM(f.ProductionCost) / 1000, 0) AS ProductionCost_K,
    FORMAT(SUM(f.TotalProfit) / 1000, 0) AS TotalProfit_K,
    1 AS SortOrder
FROM Combined_Internet_Sales f
JOIN DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.CalendarYear, d.FiscalQuarter

UNION ALL

SELECT 
    'Overall' AS Period,
    FORMAT(SUM(f.SalesAmount) / 1000, 0) AS TotalSales_K,
    FORMAT(SUM(f.ProductionCost) / 1000, 0) AS ProductionCost_K,
    FORMAT(SUM(f.TotalProfit) / 1000, 0) AS TotalProfit_K,
    2 AS SortOrder
FROM Combined_Internet_Sales f
ORDER BY SortOrder, Period;

-- 2 Product-Level Sales, Cost, and Profit Analysis with Category Subtotals
SELECT 
    pc.EnglishProductCategoryName,
    ps.EnglishProductSubcategoryName,
    p.EnglishProductName,
    FORMAT(SUM(f.SalesAmount) / 1000, 2) AS TotalSales_K,
    FORMAT(SUM(f.ProductionCost) / 1000, 2) AS ProductionCost_K,
    FORMAT(SUM(f.TotalProfit) / 1000, 2) AS TotalProfit_K
FROM 
    Combined_Internet_Sales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
JOIN DimProductSubCategory ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
JOIN DimProductCategory pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
GROUP BY 
    pc.EnglishProductCategoryName,
    ps.EnglishProductSubcategoryName,
    p.EnglishProductName
WITH ROLLUP;

-- 3 View for Regional Product Sales Classification with Sales Labels
CREATE OR REPLACE VIEW vw_SalesManagerDashboard AS
SELECT 
    st.SalesTerritoryCountry,
    st.SalesTerritoryRegion,
    p.EnglishProductName,
    SUM(f.SalesAmount) AS TotalSales,
    CASE 
        WHEN SUM(f.SalesAmount) < 10000 THEN 'Low Sales'
        WHEN SUM(f.SalesAmount) BETWEEN 10000 AND 100000 THEN 'Average Sales'
        ELSE 'High Sales'
    END AS SalesLabel
FROM 
    Combined_Internet_Sales f
JOIN DimSalesTerritory st ON f.SalesTerritoryKey = st.SalesTerritoryKey
JOIN DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY 
    st.SalesTerritoryCountry, st.SalesTerritoryRegion, p.EnglishProductName;

SELECT * FROM vw_SalesManagerDashboard
WHERE SalesLabel = 'Low Sales'
Limit 1;

-- 4 Top 5 Customers by Total Sales
SELECT 
    c.FirstName, c.LastName, c.CustomerKey,
    SUM(f.SalesAmount) AS TotalSales
FROM 
    Combined_Internet_Sales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY 
    c.CustomerKey, c.FirstName, c.LastName
ORDER BY 
    TotalSales DESC
LIMIT 5;

-- 5 Sales Breakdown by Gender and Marital Status (in Thousands)
SELECT 
    c.Gender,
    c.MaritalStatus,
    format(SUM(f.SalesAmount)/1000,0) AS TotalSales_K
FROM 
    Combined_Internet_Sales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY 
    c.Gender, c.MaritalStatus;

-- 6 Age and Gender-wise Customer Sales Distribution
SELECT 
    TIMESTAMPDIFF(YEAR, c.BirthDate, CURDATE()) AS Age,
    c.Gender,
    SUM(f.SalesAmount) AS TotalSales
FROM 
    Combined_Internet_Sales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY 
    Age, c.Gender
ORDER BY 
    Age, c.Gender;

-- 7 Most and Least Sold Products by Quantity
(
  SELECT 
    'Most Sold' AS RankType,
    p.EnglishProductName,
    SUM(f.OrderQuantity) AS TotalSold
  FROM Combined_Internet_Sales f
  JOIN DimProduct p ON f.ProductKey = p.ProductKey
  GROUP BY p.EnglishProductName
  ORDER BY TotalSold DESC
  LIMIT 1
)
UNION ALL
(
  SELECT 
    'Least Sold' AS RankType,
    p.EnglishProductName,
    SUM(f.OrderQuantity) AS TotalSold
  FROM Combined_Internet_Sales f
  JOIN DimProduct p ON f.ProductKey = p.ProductKey
  GROUP BY p.EnglishProductName
  ORDER BY TotalSold ASC
  LIMIT 1);

-- 8 Stored Procedure for Segmenting Customers by Purchase Frequency
SELECT 
    f.CustomerKey,
    c.FirstName,
    c.LastName,
    COUNT(*) AS PurchaseCount
FROM 
    Combined_Internet_Sales f
JOIN 
    DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY 
    f.CustomerKey, c.FirstName, c.LastName
HAVING 
    COUNT(*) > 1
ORDER BY 
    PurchaseCount DESC;

DELIMITER //

CREATE PROCEDURE GetCustomerSegments()
BEGIN
    SELECT 
        f.CustomerKey,
        c.FirstName,
        c.LastName,
        COUNT(*) AS PurchaseCount,
        CASE
            WHEN COUNT(*) >= 50 THEN 'High'
            WHEN COUNT(*) >= 30 THEN 'Medium'
            ELSE 'Low'
        END AS Segment
    FROM 
        Combined_Internet_Sales f
    JOIN 
        DimCustomer c ON f.CustomerKey = c.CustomerKey
    GROUP BY 
        f.CustomerKey, c.FirstName, c.LastName
    ORDER BY 
        PurchaseCount DESC;
END;
//

DELIMITER ;

Call GetCustomerSegments();

-- 9 Trigger to Validate Numeric CustomerKey on Insert with Error Handling
DELIMITER //

CREATE TRIGGER trg_validate_customer_key
BEFORE INSERT ON Combined_Internet_Sales
FOR EACH ROW
BEGIN
    -- Check if CustomerKey is NULL
    IF NEW.CustomerKey IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: CustomerKey cannot be NULL';
    
    -- Check if CustomerKey contains non-numeric characters
    ELSEIF NEW.CustomerKey REGEXP '[^0-9]' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: CustomerKey must contain only numeric digits';
    END IF;
END;
//

DELIMITER ;
INSERT INTO Combined_Internet_Sales 
(ProductKey, OrderDateKey, OrderQuantity, UnitPrice, DiscountAmount, ProductStandardCost)
VALUES 
(101, 20240618, 2, 250.00, 10.00, 200.00);