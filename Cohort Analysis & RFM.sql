----Tính NoNewCustomer bằng cách tạo bảng Temp2 với dữ liệu trích từ CTE1 (Không bao gồm ObYear)
---- B1: Lập CTE1 bao gồm CustomerKey (unique), FirstPurchaseYear
---- B2: Đếm CustomerKey theo FirstPurchaseYear được NoNewCustomer
---- Lưu ý: Trước mệnh đề 'WITH CTE' không gồm lệnh lớn nào -> Muốn lồng lệnh phải dùng TEMP 
WITH CTE1 (CustomerKey,FirstPurchaseYear)
AS
(
SELECT DISTINCT CustomerKey
,YEAR(
	MIN(OrderDate) OVER (PARTITION BY CustomerKey)
) as 'FirstPurchaseYear'
FROM dbo.FactInternetSales
)
SELECT COUNT( DISTINCT CTE1.CustomerKey) AS NoNewCustomer
,FirstPurchaseYear
INTO #Temp1
FROM CTE1
GROUP BY FirstPurchaseYear 
--- Tính NoRetainCustomer bằng cách tạo bảng Temp1 với dữ liệu trích từ CTE2 (Bao gồm ObservationYear)
--- B3: Lập CTE2 bao gồm CustomerKey (unique), FirstPurchaseYear, ObservationYear
--- B4: Lọc  FirstPurchaseYear< ObservationYear, Đếm CustomerKey theo  FirstPurchaseYear, ObservationYear 
WITH CTE2 (CustomerKey,ObservationYear,FirstPurchaseYear)
AS
(
SELECT DISTINCT CustomerKey
,YEAR(OrderDate) as 'ObservationYear'
,YEAR(
	MIN(OrderDate) OVER (PARTITION BY CustomerKey)
) as 'FirstPurchaseYear'
FROM dbo.FactInternetSales
)
SELECT COUNT(CTE2.CustomerKey) AS NoRetain
, FirstPurchaseYear
, ObservationYear
INTO #Temp2
FROM CTE2
WHERE CTE2.FirstPurchaseYear<CTE2.ObservationYear
GROUP BY CTE2.FirstPurchaseYear
, CTE2.ObservationYear

SELECT #Temp1.FirstPurchaseYear
, ObservationYear
, NoRetain
, NoNewCustomer
, FORMAT (CAST(NoRetain AS decimal)/ CAST (NoNewCustomer AS decimal), 'P3') as PercentRetainCustomer
FROM #Temp1
JOIN #Temp2
on #Temp1.FirstPurchaseYear = #Temp2.FirstPurchaseYear
--- Execute lần lượt từng Temp -> Không hiểu tại sao không chạy được hết trong 1 lần

--- RFM assignment --
--- B1: Taọ CTE1 có CustomerKey,,CustomerName,FirstDatePurchase,OrderDate (Observation date) (date nhỏ 2015),SalesAmount,TotalProductCost
WITH CTE1 (CustomerKey,CustomerName,FirstDatePurchase,OrderDate,SalesAmount,TotalProductCost) 
AS 
(
SELECT a.CustomerKey
, CONCAT_WS(' ', FirstName,MiddleName,LastName) as CustomerName
, MIN(a.OrderDate) OVER (PARTITION BY a.CustomerKey) as FirstDatePurchase
, a.OrderDate
, a.SalesAmount
, a.TotalProductCost
FROM dbo.FactInternetSales a
JOIN dbo.DimCustomer b
on a.CustomerKey = b.CustomerKey
WHERE Year(OrderDate)<2015
)
--- B2 : Tạo bảng Temp 3 từ CTE1 có CustomerKey,,CustomerName, Number of Order (count theo CustomerKey), Number of sales (Sum theo customerkey), Tính tháng (tháng không đủ trừ 1), năm cũng thế
SELECT DISTINCT CustomerKey
,CustomerName
,COUNT(CustomerKey) OVER (PARTITION BY CustomerKey) 'NoB'
,SUM(SalesAmount) OVER (PARTITION BY CustomerKey) 'NoS'
,SUM(TotalProductCost) OVER (PARTITION BY CustomerKey) 'NoC'
, CASE 
WHEN DATEPART(DAY,FirstDatePurchase)  > DATEPART(DAY,'01/01/2015')
THEN DATEDIFF(MONTH, FirstDatePurchase,'01/01/2015') - 1
ELSE DATEDIFF(MONTH, FirstDatePurchase,'01/01/2015') 
END AS 'MonthDif'
, CASE 
WHEN (DATEPART(DAY,FirstDatePurchase)  > DATEPART(DAY,'01/01/2015')) AND (DATEPART(MONTH,FirstDatePurchase)  > DATEPART(MONTH,'01/01/2015'))
THEN DATEDIFF(YEAR, FirstDatePurchase,'01/01/2015') - 1
ELSE DATEDIFF(YEAR, FirstDatePurchase,'01/01/2015') 
END AS 'YearDif'
INTO #Temp3
FROM CTE1 
--- Tạo CTE g gồm CustomerKey,CustomerName,NoPurchasePerYear(Cast decimal) ,AmountPerYear,TotalProfit (tránh tạo thêm bảng TEMP)
WITH g (CustomerKey,CustomerName,NoPurchasePerYear,AmountPerYear,TotalProfit)
AS
(
SELECT CustomerKey
, CustomerName
, CAST(NoB AS decimal)/ CAST (MonthDif AS decimal) as NoPurchasePerYear
, CAST(NoS AS decimal)/ CAST (YearDif AS decimal) as AmountPerYear
, CAST(NoS AS decimal) - CAST (NoC AS decimal) as TotalProfit
FROM #Temp3
)
--- Tạo Temp5 join của CTE g và Temp 3, bao gồm CustomerKey,CustomerName,NoPurchasePerYear,AmountPerYear,TotalProfit, Score (dùng case rồi + case với nhau)
SELECT #Temp3.CustomerKey
, #Temp3.CustomerName
, g.NoPurchasePerYear
, g.AmountPerYear
, g.TotalProfit
,
	CASE
	WHEN #Temp3.YearDif >=1
	THEN 1
	ELSE 0
	END
	+ 
	CASE WHEN g.CustomerKey IN (SELECT TOP 20 PERCENT g.CustomerKey FROM g ORDER BY AmountPerYear ASC)
	THEN 2
	ELSE 0
	END 
	+
	CASE WHEN g.CustomerKey IN (SELECT TOP 20 PERCENT g.CustomerKey FROM g ORDER BY TotalProfit ASC)
	THEN 2
	ELSE 0
	END

	+ CASE WHEN NoPurchasePerYear > 1
	THEN 1
	ELSE 0
	END AS 'Score'
INTO #Temp5
FROM #Temp3
JOIN
g
on #Temp3.CustomerKey= g.CustomerKey
---- Classify dùng bảng Temp 5
SELECT CustomerKey,CustomerName,NoPurchasePerYear,AmountPerYear,TotalProfit
, CASE 
	WHEN Score > 5
	THEN 'Diamond'
	WHEN Score = 4
	THEN 'Gold'
	WHEN Score = 3
	THEN 'Silver'
	WHEN Score < 3 
	THEN 'Normal'
	ELSE 'None'
	END 'Classification'
FROM #Temp5
