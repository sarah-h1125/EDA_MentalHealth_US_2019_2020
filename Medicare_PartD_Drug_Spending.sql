---------------------------------------------------------------
-- Data Cleaning & Exploratory Data Analysis ------------------
-- Medicare Part D Spending by Drug ---------------------------
-- Data Source: https://data.cms.gov/summary-statistics-on-use-and-payments/medicare-medicaid-spending-by-drug/medicare-part-d-spending-by-drug
---------------------------------------------------------------

SELECT * 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020; 

SELECT COUNT(*) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020; 
-- 13,570 records total in dataset 

SELECT COUNT(*) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
WHERE Mftr_Name = 'Overall';
-- 3,576 

SELECT COUNT(DISTINCT(Brnd_Name)) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020;
-- 3,439 distinct brand names for drugs 


----- Question #1: How many drugs are only available as brand name and not generic? -------------- 
SELECT COUNT(DISTINCT(Gnrc_Name)) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020;
-- 1,869 distinct generic names for drugs 

SELECT COUNT(*) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
WHERE Brnd_Name = Gnrc_Name; 
-- 4,476 records where drug is sold as its generic 

SELECT DISTINCT(Gnrc_Name) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
WHERE Brnd_Name = Gnrc_Name;
-- 569 drugs are offered as their generic 

SELECT
((SELECT COUNT(DISTINCT(Gnrc_Name)) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020) 
-
(SELECT COUNT(DISTINCT(Gnrc_Name)) 
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
WHERE Brnd_Name = Gnrc_Name))
AS Tot_Avl_Only_Brandname;
-- 1,300 drugs out of 1,869 are only available as Brand Name 

---- Question #2: How many manufacturers? Which manufacturers had highest total spending in each year? ----
SELECT COUNT(DISTINCT(Mftr_Name))
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020; 
-- 901 total manufacturers 

-- Lists percent of total spending contributed for each drug manufacturer for each year 
WITH total AS 
	(SELECT 
		SUM(Tot_Spndng_2016) AS Total_2016, 
		SUM(Tot_Spndng_2017) AS Total_2017, 
		SUM(Tot_Spndng_2018) AS Total_2018,
		SUM(Tot_Spndng_2019) AS Total_2019,
		SUM(Tot_Spndng_2020) AS Total_2020
	FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
	GROUP BY Mftr_Name
	HAVING Mftr_Name = 'Overall') 
SELECT	Mftr_Name, 
(SUM(Tot_Spndng_2016)/total.Total_2016)*100 AS Pct_Spending_2016, 
(SUM(Tot_Spndng_2017)/total.Total_2017)*100 AS Pct_Spending_2017, 
(SUM(Tot_Spndng_2018)/total.Total_2018)*100 AS Pct_Spending_2018,
(SUM(Tot_Spndng_2019)/total.Total_2019)*100 AS Pct_Spending_2019,
(SUM(Tot_Spndng_2020)/total.Total_2020)*100 AS Pct_Spending_2020
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020, total
GROUP BY Mftr_Name, Total_2016, Total_2017, Total_2018, Total_2019, Total_2020
ORDER BY Pct_Spending_2020 DESC; 

-- Question #3 Which drugs have the highest avg spending for 2020? (Last year available)-- 
SELECT TOP(10) Gnrc_Name, Tot_Spndng_2020
FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
WHERE Mftr_Name = 'Overall'
ORDER BY Tot_Spndng_2020 DESC; 

--- Question#4  Can we predict 2021 spending using the rate change of 2019-2020? ---  
WITH overall AS 
	(SELECT Gnrc_Name, Avg_Spnd_Per_Dsg_Unt_Wghtd_2020, Chg_Avg_Spnd_Per_Dsg_Unt_19_20
	FROM CMS.dbo.Medicare_Part_D_Spending_by_Drug_2020
	WHERE Mftr_Name = 'Overall')
SELECT Gnrc_Name, 
	   Avg_Spnd_Per_Dsg_Unt_Wghtd_2020 + (Avg_Spnd_Per_Dsg_Unt_Wghtd_2020*Chg_Avg_Spnd_Per_Dsg_Unt_19_20) AS Predicted_Avg_Spnd_Per_Dsg_Unit_2021
FROM overall
ORDER BY Predicted_Avg_Spnd_Per_Dsg_Unit_2021 DESC
-- This result predicts the 2021 average spending per dosage unit if rate of change stays the same as 2019-2020 rate 






