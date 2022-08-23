/*******************************************************
Data Cleaning & Exploratory Data Analysis in SQL Server 
Data is sourced from cdc.gov: U.S. Chronic Disease Indicators: Mental Health 
https://chronicdata.cdc.gov/Chronic-Disease-Indicators/U-S-Chronic-Disease-Indicators-Mental-Health/ixrt-gnsg
********************************************************/ 

SELECT TOP 100 * 
FROM HealthcareData.dbo.CDI_Mental_Health; 

-- Explore value ranges in each column ----------------------------------------------------------
-- Year Range 
SELECT DISTINCT(YearStart)
FROM HealthcareData.dbo.CDI_Mental_Health
ORDER BY YearStart; 
-- Year start ranges from 2009- 2020 with 2010 missing 

-- Year End 
SELECT DISTINCT(YearEnd)
FROM HealthcareData.dbo.CDI_Mental_Health
ORDER BY YearEnd; 
-- Year end  ranges from 2011 - 2020 with no years missing 

-- Check if all states are represented
SELECT COUNT(DISTINCT(LocationAbbr))
FROM HealthcareData.dbo.CDI_Mental_Health;
-- 55 returned... > 

-- Compare against list of 50 states to see what territories are included or if any states are listed in multiple formats 
SELECT DISTINCT(LocationAbbr)
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE LocationAbbr NOT IN ('AK', 'AL', 'AR', 'AZ', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'IA', 'ID', 'IL', 'IN', 'KS', 'KY', 'LA', 'MA', 'MD', 'ME', 'MI', 'MN', 'MO', 'MS', 'MT', 'NC', 'ND', 'NE', 'NH', 'NJ', 'NM', 'NV', 'NY', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VA', 'VT', 'WA', 'WI', 'WV', 'WY'); 
-- 5 additional territories include DC, GU, VI, PR, 
-- US (united states) values are the median of the 50 states + DC based on Datavalue Footnote 

SELECT COUNT(*), LocationAbbr
FROM HealthcareData.dbo.CDI_Mental_Health
GROUP BY LocationAbbr; 
-- All states and territories have the same amount (221) of records, except for the US abbr which only has 71.. will discard these records


SELECT DISTINCT(Topic)
FROM HealthcareData.dbo.CDI_Mental_Health; 
-- All values in Topic column are mental health, we can drop this row at the end of analysis 

SELECT DataSource, COUNT(*)
FROM HealthcareData.dbo.CDI_Mental_Health
GROUP BY DataSource;
-- Two data sources listed here: BRFSS, PRAMS with BRFSS being the data source for majority of the records 11950 vs 55 


--------------------------------------------------------------------------------------------------------------------------------
-- Find out how many different questions there are in dataset & what those questions are 
SELECT DISTINCT(Question)
FROM HealthcareData.dbo.CDI_Mental_Health;
-- Find out there are only 3 questions in data set, 2/3 specifically about mental health in women, general mental health ages 18-44 and postpartum depressive symptoms 
-- 'Recent mentally unhealthy days among adults >= 18 years (both genders) may be best indicator of state/territories overall mental health 

SELECT LocationDesc, ROUND(AVG(DataValue),2) AS Postpartum_depression_percent
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE Question = 'Postpartum depressive symptoms'
GROUP BY LocationDesc
ORDER BY Postpartum_depression_percent DESC; 
-- Many states are missing values, AVGs come back as null. May not be a good indicator to compare on. 
-- Arkansas with highest, followed by Utah, Oklahoma and West Virginia

SELECT LocationDesc, ROUND(AVG(DataValue),2) AS Recent_mentally_unhealthy_days_avg
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE Question = 'Recent mentally unhealthy days among adults aged >= 18 years'
GROUP BY LocationDesc
ORDER BY Recent_mentally_unhealthy_days_avg DESC;
-- West Virginia has the highest at 5.37 days, followed by a tie between Arkansas and Kentucky

SELECT LocationDesc, ROUND(AVG(DataValue),2) AS Percent_mentally_unhealthy_adult_women
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE Question = 'At least 14 recent mentally unhealthy days among women aged 18-44 years'
GROUP BY LocationDesc
ORDER BY Percent_mentally_unhealthy_adult_women DESC;
-- Arkansas has the highest at 21.6% followed by West Virginia and Ohio 

-- How many breakout categories per state? Looks like 8 categories total: 
-- Race/Ethnicity - (Multiracial, non-Hispanic), (Black, non-hispanic), (Other, non-hispanic), (White, non-hispanic), (Hispanic)
-- Gender - (Male), (Female) 
SELECT LocationAbbr, Question, DataValue, StratificationCategory1, Stratification1
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE YearEnd = 2020 AND DataValueType = 'Age-adjusted Mean'   
ORDER BY LocationAbbr DESC; 
-- Note that not all breakout categories have data for every states 

--Lets make sure there are no states where Overall value is NULL. If so, drop those states/territories from the table
SELECT LocationAbbr, Question, DataValue, StratificationCategory1, Stratification1
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE YearEnd = 2020 AND DataValueType = 'Age-adjusted Mean' 
AND StratificationCategory1 = 'Overall' AND DataValue IS NULL   
ORDER BY LocationAbbr DESC;
-- Virgin Islands are missing most data including Overall for this question so we will drop it from table later 

--------------------- Create and save a new table from existing table data than will be used in visualizations ------------
-- Only focusing on the Recent mentally unhealthy days among adults aged >= 18 years since it is already split by gender and race and other questions are lacking data in certain states
-- Lets focus on 2019 and 2020 to see differences pre-pandemic and during first year of pandemic. 
SELECT *
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE (YearEnd = 2019 OR YearEnd = 2020)
AND Question = 'Recent mentally unhealthy days among adults aged >= 18 years'
ORDER BY LocationDesc; 

--- Checking for which columns we can drop... Is DataValue ever different than DataValueAlt? 
SELECT * 
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE DataValue <> DataValueAlt; 
-- answer - no, we can drop the extra DataValueAlt column 

---- After exploring data, we can get rid of columns that contain unecessary information or duplicate information
--- Columns to include in new table: 
-- Year, State Abbr, State Name, Question, Age-adjusted mean (only want to count adults), confidence limits, strat category, stratification 
----------------------------------------------------------------------------------------------------------------
-- Create New Table 
SELECT YearEnd AS Year, 
LocationAbbr,
LocationDesc, 
Question, 
StratificationCategory1 AS Stratification_category,
Stratification1 AS Stratification,
ROUND(DataValue,4) AS Avg_mentally_unhealthy_days, 
ROUND(LowConfidenceLimit, 4) AS Low_confidence_limit, 
ROUND(HighConfidenceLimit, 4) AS High_confidence_limit
INTO HealthcareData.dbo.Cleaned_CDI_MentalHealth
FROM HealthcareData.dbo.CDI_Mental_Health
WHERE (YearEnd = 2020 OR YearEnd = 2019)
AND Question = 'Recent mentally unhealthy days among adults aged >= 18 years'
AND DataValueType = 'Age-adjusted Mean';

------------ Make sure new table has saved correctly ---------------------------------------------------
SELECT * 
FROM HealthcareData.dbo.Cleaned_CDI_MentalHealth
ORDER BY LocationDesc;

---- Issue when saving data as CSV - Stratification column was separating into two columns due to comma in text: ex "White, non-Hispanic"
-- Remove commas from Stratification column 
UPDATE HealthcareData.dbo.Cleaned_CDI_MentalHealth
SET Stratification = REPLACE(Stratification, ',','');



/************************************************************
PART 2 - Combine with other data for correlation later in Tableau 
Additional data for Mental Health project 
Sources for data: 
Poverty Data: US Census Bureau https://www.census.gov/library/publications/2021/demo/p60-273.html
Suicide Data: CDC https://www.cdc.gov/nchs/pressroom/sosmap/suicide-mortality/suicide.htm
HPSA (Health Provider Shortage Area) Data: https://data.hrsa.gov/data/download

******************************************/ 

---- Explore added tables ---- 
SELECT * 
FROM HealthcareData.dbo.CDC_Suicides_2019_2020;

SELECT * 
FROM HealthcareData.dbo.Poverty_USA_2019_2020;


-- HPSA stands for Health Provider Shortage Area. This is the HPSA for Mental Health Providers  
-- Dataset was filtered in GoogleSheets prior to importing to SQL server
-- Filtered for only geographic shortage areas, duplicate HPSA areas were removed, uneccessary columns dropped. 
-- Only designated and Proposed for Withdrawal areas included 
-- Goal is to get count by state of all geo areas designated as HPSA in mental health to see if it correlates to the CDI in original data set 
-- Need to filter further in SQL to get count of facilities in 2019 and count of facilities in 2020 
SELECT * 
FROM HealthcareData.dbo.HPSA_Geo;
-- Note - some states are not listed/ do not have HPSA

-- Data summary for HPSA up to 2019
SELECT Common_State_Name, Year=2019, COUNT(*) AS count_HPSA, AVG(HPSA_Score) AS avg_HPSA_score
FROM HealthcareData.dbo.HPSA_Geo
WHERE HPSA_Designation_Date < '2020-01-01'
GROUP BY Common_State_Name
ORDER BY Common_State_Name;  

-- Data summary for HPSA up to 2020
SELECT Common_State_Name, Year=2020,COUNT(*) AS count_HPSA, AVG(HPSA_Score) AS avg_HPSA_score
FROM HealthcareData.dbo.HPSA_Geo
WHERE HPSA_Designation_Date < '2021-01-01'
GROUP BY Common_State_Name
ORDER BY Common_State_Name; 

-- Stack tables on top of each other so we have 2019 and 2020 summary together, ready to join with other data 
SELECT Common_State_Name, Year=2019, 
COUNT(*) AS count_HPSA, AVG(HPSA_Score) AS avg_HPSA_score
INTO HealthcareData.dbo.HPSA_Summary
FROM HealthcareData.dbo.HPSA_Geo
WHERE HPSA_Designation_Date < '2020-01-01'
GROUP BY Common_State_Name
UNION
SELECT Common_State_Name, Year=2020,
COUNT(*) AS count_HPSA, AVG(HPSA_Score) AS avg_HPSA_score
FROM HealthcareData.dbo.HPSA_Geo
WHERE HPSA_Designation_Date < '2021-01-01'
GROUP BY Common_State_Name;

-- Check if union ran properly 
SELECT * 
FROM HealthcareData.dbo.HPSA_Summary; 

----- Join tables together on state and year data ---- 
SELECT 
CDI.Year, 
CDI.LocationAbbr, 
CDI.LocationDesc, 
ROUND(SUI.RATE,2) AS suicides_rate, 
ROUND(POV.Poverty_Percentage_Avg,2) AS poverty_percentpop_2yravg,
HPSA.count_HPSA, 
HPSA.avg_HPSA_score,
CDI.Question, 
CDI.Stratification_category,
CDI.Stratification,
CDI.Avg_mentally_unhealthy_days
INTO HealthcareData.dbo.Mental_Health_Summary_2
FROM HealthcareData.dbo.Cleaned_CDI_MentalHealth AS CDI
LEFT JOIN HealthcareData.dbo.CDC_Suicides_2019_2020 AS SUI
ON (CDI.LocationAbbr = SUI.State AND CDI.Year = SUI.YEAR)
LEFT JOIN HealthcareData.dbo.Poverty_USA_2019_2020 AS POV
ON (CDI.LocationDesc = POV.Location)
LEFT JOIN HealthcareData.dbo.HPSA_Summary AS HPSA
ON (CDI.LocationDesc = HPSA.Common_State_Name AND CDI.Year = HPSA.Year) 
ORDER BY LocationDesc; 

-- Check if Mental_Health_Summary joined properly and contains all the data we need 
SELECT * 
FROM HealthcareData.dbo.Mental_Health_Summary_2;

-- Clean the data set
-- Let's drop the territories that are missing suicide, poverty and HPSA data 
-- For the remaining states, if any HPSA values are NULL, should be replaced with 0  
DELETE FROM HealthcareData.dbo.Mental_Health_Summary_2
WHERE (suicides_rate IS NULL) AND (poverty_percentpop_2yravg IS NULL) AND (count_HPSA IS NULL) AND (avg_HPSA_score IS NULL);
-- Deletes rows for Guam and Virgin Islands 

-- United States overall still in table, can delete and average out on our own in Tableau if needed 
DELETE FROM HealthcareData.dbo.Mental_Health_Summary_2
WHERE LocationDesc = 'United States'; 

-- Update HPSA values to 0 if currently NULL for count 
-- DC, Delaware, New Jersey, and Vermont 
UPDATE HealthcareData.dbo.Mental_Health_Summary_2
SET count_HPSA = 0, avg_HPSA_score = 0
WHERE (count_HPSA IS NULL) and (avg_HPSA_score IS NULL);

-- Downloaded as a CSV and uploaded into Tableau Public
SELECT * 
FROM HealthcareData.dbo.Mental_Health_Summary_2;
