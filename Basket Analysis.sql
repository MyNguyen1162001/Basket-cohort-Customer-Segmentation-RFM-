WITH CTE1 (Product1,Product2,CoS)
AS
(
SELECT c.ProductAlternateKey as Product1
, d.ProductAlternateKey as Product2
, COUNT(a.SalesOrderNumber) as CoS
FROM dbo.FactInternetSales as a
JOIN dbo.FactInternetSales as b
ON a.SalesOrderNumber=b.SalesOrderNumber
JOIN dbo.DimProduct as c
ON a.ProductKey = c.ProductKey
JOIN dbo.DimProduct as d
ON b.ProductKey=d.ProductKey
AND c.ProductAlternateKey<>d.ProductAlternateKey
GROUP BY c.ProductAlternateKey,d.ProductAlternateKey
),
CTE2 (ProductAlternateKey,CoTS)
AS
(
SELECT h.ProductAlternateKey
, COUNT(e.SalesOrderNumber) as CoTS
FROM dbo.FactInternetSales as e
JOIN dbo.FactInternetSales as f
ON e.SalesOrderNumber=f.SalesOrderNumber
JOIN dbo.DimProduct as h
ON e.ProductKey=h.ProductKey
GROUP BY h.ProductAlternateKey
)
SELECT CTE1.Product1
, CTE1.Product2
, FORMAT(CAST(CoS AS DECIMAL)/CAST(CoTS AS DECIMAL),'P3') as Percentage
FROM CTE1
JOIN CTE2
ON CTE1.Product1 = CTE2.ProductAlternateKey