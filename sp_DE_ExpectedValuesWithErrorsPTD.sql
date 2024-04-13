USE [DWH_Workspace]
GO
/****** Object:  StoredProcedure [DWH\skacar].[sp_DE_ExpectedValuesWithErrorsPTD]    Script Date: 4/8/2024 1:44:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- When the 1st of the month occurs, delete the previous month and write it from the beginning. We will say Error Rate > 1-Error and say that the number was this clear last month. For this, we need to get the error rate of the last month.ALTER PROCEDURE [DWH\skacar].[sp_DE_ExpectedValuesWithErrorsPTD] (@BaseDay AS DATE) AS
DROP TABLE IF EXISTS #TEMP_DummyWeekTable

--DECLARE @BaseDay as Date = '2024-02-01'
DECLARE
		@inc	 as INT  =  1,
		@d       as INT  =  1,
		@y		 as INT  =  0,
		@m		 as INT  =  1,
		@StartDate as Date,
		@DailySP   as Date =  DATEADD(DAY,-1,@BaseDay),
		@LoopReferenceDate as date = @BaseDay
	    IF YEAR(@BaseDay) !=  YEAR(@DailySP)
		   BEGIN
		   SET @y = @y + 1
		   END
		IF DAY(@BaseDay) = 1
		   BEGIN
		   SET @m = @m + 1
		   END
select
	 MIN(CAST(CreateDate as Date))					FirstDayOfWeek
	,DATEADD(WEEK,-1,MIN(CAST(CreateDate as Date))) FirstDayOfLastWeek
	INTO #TEMP_DummyWeekTable
from
(
	select WeekReAdjustment
	from DWH_Papara.dbo.DIM_Date with (Nolock)
	where @DailySP = CAST(CreateDate as Date)
) M
LEFT JOIN DWH_Papara.dbo.DIM_Date D with (Nolock) ON M.WeekReadJustment = D.WeekReAdjustment
		DECLARE @Param_R_FirstDayOfWeek		  AS DATE = (SELECT FirstDayOfWeek     FROM #TEMP_DummyWeekTable),
				@Param_R_FirstDayOfLastWeek   AS DATE = (SELECT FirstDayOfLastWeek FROM #TEMP_DummyWeekTable),
				@Param_MTDIndicator		  AS DATE =					 Dateadd(Day,1,EOMonth(dateadd(MONTH,-@m,@BaseDay))),
				@Param_2MTDIndicator	  AS DATE = DATEADD(MONTH,-1,Dateadd(Day,1,EOMonth(dateadd(MONTH,-@m,@BaseDay)))),
				@Param_3MTDIndicator	  AS DATE = DATEADD(MONTH,-2,Dateadd(Day,1,EOMonth(dateadd(MONTH,-@m,@BaseDay)))),
				@Param_4MTDIndicator	  AS DATE = DATEADD(MONTH,-3,Dateadd(Day,1,EOMonth(dateadd(MONTH,-@m,@BaseDay))))
			 --   @Param_QTDIndicator		  AS DATE = DATEFROMPARTS(YEAR(Dateadd(day,-@m,@BaseDay)), ((MONTH(dateadd(day,-@m,@BaseDay)) -1)/3)*3+1,1),
			 --   @Param_SemiYTDIndicator	  AS DATE = DATEFROMPARTS(YEAR(Dateadd(day,-@m,@BaseDay)),(((MONTH(dateadd(day,-@m,@BaseDay)))-1)/6)*6+1,1),
			 --   @Param_YTDIndicator		  AS DATE = DATEFROMPARTS(YEAR(Dateadd(day,-@y,@BaseDay)),1,1),
				--@Param_2YTDIndicator	  AS DATE = DATEFROMPARTS(YEAR(Dateadd(day,-@y,@BaseDay))-1,1,1)
		DECLARE @EOPofThisMonth		 as DATE = EOMONTH(@Param_MTDIndicator),
				@EOPofLastMonth		 as DATE = EOMONTH(@Param_2MTDIndicator),
				@EOPofTwoMonthsAgo	 as DATE = EOMONTH(@Param_3MTDIndicator),
				@EOPofThreeMonthsAgo as DATE = EOMONTH(@Param_4MTDIndicator)
		DECLARE @EOPDayDiff		    as INT = IIF(DAY(@EOPofThisMonth) < DAY(@EOPofLastMonth)     ,DAY(@EOPofThisMonth)-DAY(@EOPofLastMonth)     ,0),
				@EOPDayDiff_TwoMt	as INT = IIF(DAY(@EOPofThisMonth) <	DAY(@EOPofTwoMonthsAgo)  ,DAY(@EOPofThisMonth)-DAY(@EOPofTwoMonthsAgo)  ,0),
				@EOPDayDiff_ThreeMt as INT = IIF(DAY(@EOPofThisMonth) <	DAY(@EOPofThreeMonthsAgo),DAY(@EOPofThisMonth)-DAY(@EOPofThreeMonthsAgo),0)
		DECLARE @ManipulatingEOPofLastMonth As DATE = DATEADD(DAY,@EOPDayDiff,@EOPofLastMonth),
				@ManipulatingEOPofTwoMonthAgo	As DATE = DATEADD(DAY,@EOPDayDiff_TwoMt,@EOPofTwoMonthsAgo),
				@ManipulatingEOPofThreeMonthAgo As DATE = DATEADD(DAY,@EOPDayDiff,@EOPofThreeMonthsAgo),

				@PTDOfLastMonth		 AS DATE = DATEADD(MONTH,-1,@DailySP),
				@PTDOfTwoMonthsAgo	 AS DATE = DATEADD(MONTH,-2,@DailySP),
				@PTDOfThreeMonthsAgo AS DATE = DATEADD(MONTH,-3,@DailySP)

IF DAY(@BaseDay)=1
BEGIN
	SET @DailySP = @Param_MTDIndicator
	
	SET				@PTDOfLastMonth		  = DATEADD(MONTH,-1,@DailySP)
	SET				@PTDOfTwoMonthsAgo	  = DATEADD(MONTH,-2,@DailySP)
	SET				@PTDOfThreeMonthsAgo  = DATEADD(MONTH,-3,@DailySP)
	DELETE FROM DWH_Workspace.dbo.FACT_DE_ExpectedValuesWithErrorsPTD_ms1 WHERE [Date]>=@DailySP AND [Date]<@BaseDay
END
ELSE
BEGIN
	SET @DailySP = @DailySP
	SET				@PTDOfLastMonth		  = DATEADD(MONTH,-1,@DailySP)
	SET				@PTDOfTwoMonthsAgo	  = DATEADD(MONTH,-2,@DailySP)
	SET				@PTDOfThreeMonthsAgo  = DATEADD(MONTH,-3,@DailySP)
	DELETE FROM DWH_Workspace.dbo.FACT_DE_ExpectedValuesWithErrorsPTD_ms1 WHERE [Date]>=@DailySP AND [Date]<@BaseDay
END
WHILE @DailySP < @BaseDay
BEGIN

; WITH MTD_Calculations AS
(
SELECT [Date]
	  ,cast(0 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(2 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,	   cast(ISNULL(OnlinePOSTxVolume,0) as decimal(20,2))+cast(ISNULL(OfflinePOSTxVolume,0) as decimal(20,2)) [Value]
	  ,SUM(cast(ISNULL(OnlinePOSTxVolume,0) as decimal(20,2))+cast(ISNULL(OfflinePOSTxVolume,0) as decimal(20,2))) OVER (PARTITION BY YEAR([Date]),MONTH([Date]) ORDER BY [Date])  Value_PTD
FROM DWH_CustomTables.dbo.FACT_DE_DailyPaparaCardReports with (Nolock)
WHERE [Date] >= @Param_4MTDIndicator --AND [Date] < @BaseDay
UNION ALL
SELECT [Date]
	  ,cast(0 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(2 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,   cast(ISNULL(OnlinePosTxCount ,0) as decimal(20,2))+cast(ISNULL(OfflinePosTxCount ,0) as decimal(20,2)) [Value]
	  ,SUM(cast(ISNULL(OnlinePosTxCount ,0)  as decimal(20,2))+cast(ISNULL(OfflinePosTxCount ,0) as decimal(20,2))) OVER (PARTITION BY YEAR([Date]),MONTH([Date]) ORDER BY [Date]) Value_PTD
FROM DWH_CustomTables.dbo.FACT_DE_DailyPaparaCardReports with (Nolock)
WHERE [Date] >= @Param_4MTDIndicator
UNION ALL
SELECT [Date]
	  ,cast(1 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)	  as decimal(20,2))  [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType IN (71,73) AND [Date] >= @Param_4MTDIndicator/*Precious Metal Total mutlak değer hacim TRY*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(2 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)    as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0)as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 64 AND [Date] >= @Param_4MTDIndicator/*Uluslararası para transferi*/
GROUP BY [Date]
UNION ALL
SELECT cast(CreatedAt as date) [Date]
	  ,cast(3 as int) Feature
	  ,CAST(6 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(2 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,CAST(	   ISNULL(TotalFee ,0) as decimal(20,2))  [Value]
	  ,cast(SUM(ISNULL(TotalFee ,0)) OVER (PARTITION BY YEAR(CreatedAt),MONTH(CreatedAt) ORDER BY CreatedAt) as decimal(20,2)) Value_PTD
FROM DWH_Papara.dbo.FACT_Reports With (NOLOCK)/*Total Fee*/
WHERE  CreatedAt >= @Param_4MTDIndicator
UNION ALL
SELECT [Date]
	  ,cast(4 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0) as decimal(20,2))   [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 29 AND [Date] >= @Param_4MTDIndicator/*Cashback kazanımları*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(5 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)     as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 28 AND [Date] >= @Param_4MTDIndicator/*Fatura Ödeme İşlemleri*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(6 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)    as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0)as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 30 AND [Date] >= @Param_4MTDIndicator/*Oyun Ödemesi İşlemleri*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(7 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)   as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 31 AND [Date] >= @Param_4MTDIndicator/*Ulaşım Kartı Bakiye Yükleme İşlemleri*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(8 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0)    as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0)as decimal(20,2))  Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 91 AND [Date] >= @Param_4MTDIndicator /*Havalimanı Hizmetleri Ödemesi*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(9 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))   [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Offline*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(10 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(11 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=0 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Domestic*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(12 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(13 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(14 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeDaily)) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(ABS(NetTxVolumeMTD))   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Offline*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(9 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Offline*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(10 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(11 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=0 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Domestic*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(12 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(13 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0)as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0)as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(14 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(UUDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(UUMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Offline*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(9 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Offline*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(10 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=10000 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(11 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=0 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Domestic*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(12 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=10000 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(13 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=0 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Online*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(14 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TxCountDaily) ,0) as decimal(20,2))    [Value]
	  ,cast(ISNULL(SUM(TxCountMTD)   ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_ExternalCardAcceptorBrandReportMTD with (Nolock)
WHERE ExternalCardAcceptorId = 10000 AND CategoryId=10000 AND Is_Abroad=1 AND Is_Offline=1 AND [Date] >= @Param_4MTDIndicator /*User POS Tx.V.(Net)|Abroad&Offline*/
GROUP BY [Date]
UNION ALL
select
 cast(DateHour as date) [Date]
 	  ,cast(5 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(max(UUHourly) as decimal(20,2)) [Value]
,cast(MAX(UUMTD) as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_DEllPaymentTransactionsByCompaniesToDateCube With (nolock) /*DEll Payment UU*/
where DEllCategoryId=10000 and DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
select
 cast(DateHour as date) [Date]
  	  ,cast(5 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(MAX(TxCountHourly) as decimal(20,2)) [Value]
,cast(MAX(TxCountMTD) as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_DEllPaymentTransactionsByCompaniesToDateCube With (nolock) /*DEll Payment-Tx.#*/
where DEllCategoryId=10000 and DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
select
 cast(DateHour as date) [Date]
  	  ,cast(6 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(max(UUHourly) as decimal(20,2)) [Value]
,cast(MAX(UUMTD)	as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_GamePaymentTransactionsByCompaniesToDateCube With (nolock) /*Game Payment-UU*/
WHERE CompanySubTypeId=10000 AND DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
select
 cast(DateHour as date) [Date]
   	  ,cast(6 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(MAX(TxCountHourly) as decimal(20,2)) [Value]
,cast(MAX(TxCountMTD)	 as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_GamePaymentTransactionsByCompaniesToDateCube With (nolock) /*Game Payment-Tx.#*/
WHERE CompanySubTypeId=10000 AND DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
select
 cast(DateHour as date) [Date]
      ,cast(7 as int) Feature
	  ,CAST(0 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(MAX(UUHourly) as decimal(20,2)) [Value]
,cast(MAX(UUMTD) as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_TravelCardTransactionsByCompaniesToDateCube With (nolock) /*TravelCard Payment-UU*/
where DEllCategoryId=10000 and DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
select
 cast(DateHour as date) [Date]
      ,cast(7 as int) Feature
	  ,CAST(4 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
,cast(MAX(TxCountHourly)as decimal(20,2))  [Value]
,cast(MAX(TxCountMTD) as decimal(20,2)) Value_MTD
from papara_DEllpayment.dbo.FACT_TravelCardTransactionsByCompaniesToDateCube With (nolock) /*TravelCard Payment-Tx.#*/
where DEllCategoryId=10000 and DEllCompanyId=10000 AND DateHour >= @Param_4MTDIndicator
GROUP BY cast(DateHour as date)
UNION ALL
SELECT [Date]
	  ,cast(15 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0) as decimal(20,2))   [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 14 AND [Date] >= @Param_4MTDIndicator/*Kapalı devre para transferi-Alıcı*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(16 as int) Feature
	  ,CAST(5 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxVolume) ,0) as decimal(20,2))   [Value]
	  ,cast(ISNULL(SUM(TotalTxVolume_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 15 AND [Date] >= @Param_4MTDIndicator/*Kapalı devre para transferi-gönderici*/
GROUP BY [Date]
UNION ALL
SELECT [Date]
	  ,cast(15 as int) Feature
	  ,CAST(6 AS int) MeasureType
	  ,CAST(0 as int) PeriodType
	  ,CAST(0 AS int) EntityType
	  ,CAST(0 AS int) Currency
	  ,cast(ISNULL(SUM(TotalTxFee) ,0)     as decimal(20,2)) [Value]
	  ,cast(ISNULL(SUM(TotalTxFee_MTD) ,0) as decimal(20,2)) Value_PTD
FROM DWH_CustomTables.dbo.FACT_EntryTypeMetricAnalysiswithMTD with (Nolock)
WHERE ComDEnationType = 14 AND [Date] >= @Param_4MTDIndicator/*Kapalı devre para transferi-Alıcı-işlem ücreti*/
GROUP BY [Date]
), EOP_Calculation AS
(
SELECT
	  @DailySP [Date]
	  ,Feature
	  ,MeasureType
	  ,PeriodType
	  ,EntityType
	  ,Currency
	 ,max(CASE WHEN [Date] = @DailySP					 THEN Value_PTD END) PTD
	 ,max(CASE WHEN [Date] = @PTDOfLastMonth			 THEN Value_PTD END) PTDLastMonth
	 ,max(CASE WHEN [Date] = @ManipulatingEOPofLastMonth THEN Value_PTD END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofLastMonth),ABS(day(@EOPofThisMonth)-day(@EOPofLastMonth))*max(case when [Date] = @EOPofLastMonth THEN [Value] END),max(0))																	EOPofLastMonthWithManupilation
	 ,COALESCE((max(CASE WHEN [Date] = @PTDOfLastMonth   THEN cast(Value_PTD as decimal(20,6)) END))*1.0/(NULLIF(((max(CASE WHEN [Date] = @ManipulatingEOPofLastMonth THEN cast(Value_PTD as decimal(20,6)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofLastMonth),ABS(day(@EOPofThisMonth)-day(@EOPofLastMonth))*max(case when [Date] = @EOPofLastMonth THEN cast([Value]as decimal(20,6)) END),max(0)))), 0)), 0)	RateOfLastMonth
	 ,cast(COALESCE((
max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD AS DECIMAL(38,10)) END)
)*1.0
/
(NULLIF((COALESCE((max(CASE WHEN [Date] = @PTDOfLastMonth THEN CAST(Value_PTD AS DECIMAL(38,10)) END))*1.0
/
(NULLIF(((max(CASE WHEN [Date] = @ManipulatingEOPofLastMonth THEN CAST(Value_PTD AS DECIMAL(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofLastMonth),ABS(day(@EOPofThisMonth)-day(@EOPofLastMonth))*max(case when [Date] = @EOPofLastMonth THEN CAST([Value] as decimal(38,10)) END),max(0))))
, 0)), 0)),0)), 0) as decimal(20,2)) ExpectedEOPValueWrtLastMonth
	 ,MAX(CASE WHEN [Date] = @EOPofThisMonth then Value_PTD end) RealizedEOPValue
	 ,MAX(CASE WHEN [Date] = @EOPofLastMonth then Value_PTD end) EOPLastMonthValue
/**/
	 ,max(CASE WHEN [Date] = @PTDOfTwoMonthsAgo			   THEN Value_PTD END) PTDTwoMonthAgo
	 ,max(CASE WHEN [Date] = @ManipulatingEOPofTwoMonthAgo THEN Value_PTD END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofTwoMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofTwoMonthsAgo))*max(case when [Date] = @EOPofTwoMonthsAgo THEN [Value] END),max(0))																																									EOPofTwoMonthAgoMonthWithManupilation
	 ,cast(COALESCE((
		max(CASE WHEN [Date] = @PTDOfTwoMonthsAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END) 
		)*1.0
		/
		(NULLIF(
		((max(CASE WHEN [Date] = @ManipulatingEOPofTwoMonthAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofTwoMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofTwoMonthsAgo))*max(case when [Date] = @EOPofTwoMonthsAgo THEN CAST([Value] as decimal(38,10)) END),max(0))))																					
		, 0)), 0) as decimal(20,6))																					RateOfTwoMonthAgo
	 ,cast(COALESCE((
			max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD AS DECIMAL(38,10)) END)  
			)*1.0
			/ 
			(NULLIF(
			(
			COALESCE((
			max(CASE WHEN [Date] = @PTDOfTwoMonthsAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END)
			)*1.0
			/
			(NULLIF(
			((max(CASE WHEN [Date] = @ManipulatingEOPofTwoMonthAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofTwoMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofTwoMonthsAgo))*max(case when [Date] = @EOPofTwoMonthsAgo THEN CAST([Value] as decimal(38,10)) END),max(0))))
			, 0)), 0)
			)
			, 0)), 0) as decimal(20,2)) ExpectedEOPValueWrtTwoMonthAgo
	 ,MAX(CASE WHEN [Date] = @EOPofTwoMonthsAgo then Value_PTD end) EOPTwoMonthAgoValue

	 ,max(CASE WHEN [Date] = @PTDOfThreeMonthsAgo			   THEN Value_PTD END) PTDThreeMonthAgo
	 ,max(CASE WHEN [Date] = @ManipulatingEOPofThreeMonthAgo   THEN Value_PTD END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofThreeMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofThreeMonthsAgo))*max(case when [Date] = @EOPofThreeMonthsAgo THEN [Value] END),max(0))																																											EOPofThreeMonthAgoMonthWithManupilation
	 ,cast(COALESCE((max(CASE WHEN [Date] = @PTDOfThreeMonthsAgo			   THEN CAST(Value_PTD AS DECIMAL(38,10)) END))*1.0  /(NULLIF(((max(CASE WHEN [Date] = @ManipulatingEOPofThreeMonthAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofThreeMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofThreeMonthsAgo))*max(case when [Date] = @EOPofThreeMonthsAgo THEN CAST([Value] AS DECIMAL(38,10)) END),max(0)))), 0)), 0)	as decimal(20,6))												RateOfThreeMonthAgo
	 ,cast(COALESCE((max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD AS DECIMAL(38,10)) END)*((max(CASE WHEN [Date] = @ManipulatingEOPofThreeMonthAgo THEN CAST(Value_PTD AS DECIMAL(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofThreeMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofThreeMonthsAgo))*max(case when [Date] = @EOPofThreeMonthsAgo THEN CAST([Value] AS DECIMAL(38,10)) END),max(0)))))*1.0  / (NULLIF(max(CASE WHEN [Date] = @PTDOfThreeMonthsAgo THEN cast(Value_PTD AS DECIMAL(38,10)) END), 0)), 0) as decimal(20,2)) ExpectedEOPValueWrtThreeMonthAgo
	 ,MAX(CASE WHEN [Date] = @EOPofThreeMonthsAgo then Value_PTD end) EOPThreeMonthAgoValue

	 ,cast((

	   COALESCE((
		max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD as decimal(38,10)) END)
		)*1.0
		/
		(NULLIF((COALESCE((max(CASE WHEN [Date] = @PTDOfLastMonth THEN CAST(Value_PTD as decimal(38,10)) END))*1.0
		/
		(NULLIF(((max(CASE WHEN [Date] = @ManipulatingEOPofLastMonth THEN CAST(Value_PTD as decimal(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofLastMonth),ABS(day(@EOPofThisMonth)-day(@EOPofLastMonth))*max(case when [Date] = @EOPofLastMonth THEN CAST([Value] as decimal(38,10)) END),max(0))))
		, 0)), 0)),0)), 0)
		+
	   COALESCE((
			max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD as decimal(38,10)) END)  
			)*1.0
			/ 
			(NULLIF(
			(
			COALESCE((
			max(CASE WHEN [Date] = @PTDOfTwoMonthsAgo THEN CAST(Value_PTD as decimal(38,10)) END)
			)*1.0
			/
			(NULLIF(
			((max(CASE WHEN [Date] = @ManipulatingEOPofTwoMonthAgo THEN CAST(Value_PTD as decimal(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofTwoMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofTwoMonthsAgo))*max(case when [Date] = @EOPofTwoMonthsAgo THEN CAST([Value] as decimal(38,10)) END),max(0))))
			, 0)), 0)
			)
			, 0)), 0)
		+
	   COALESCE((max(CASE WHEN [Date] = @DailySP THEN CAST(Value_PTD as decimal(38,10)) END)*((max(CASE WHEN [Date] = @ManipulatingEOPofThreeMonthAgo THEN CAST(Value_PTD as decimal(38,10)) END) + IIF(DAY(@EOPofThisMonth)>DAY(@EOPofThreeMonthsAgo),ABS(day(@EOPofThisMonth)-day(@EOPofThreeMonthsAgo))*max(case when [Date] = @EOPofThreeMonthsAgo THEN CAST([Value] as decimal(38,10)) END),max(0)))))*1.0  / (NULLIF(max(CASE WHEN [Date] = @PTDOfThreeMonthsAgo THEN CAST(Value_PTD as decimal(38,10)) END), 0)), 0)

	   ) / 3 as decimal(20,2)) MeanOfExpectedEOPValueOfLastThreeMonths
FROM MTD_Calculations
group by 
		 Feature
		,MeasureType
		,PeriodType
		,EntityType
		,Currency
), LastEstimates AS
(
	SELECT EC.[Date]
		  ,EC.Feature
		  ,EC.MeasureType
		  ,EC.PeriodType
		  ,EC.EntityType
		  ,EC.Currency
		  ,EC.PTD
		  ,EC.PTDLastMonth
		  ,EC.EOPofLastMonthWithManupilation
		  ,EC.RateOfLastMonth/**/
		  ,EC.ExpectedEOPValueWrtLastMonth
		  ,EC.RealizedEOPValue
		  ,EC.EOPLastMonthValue
		  ,EC.EOPofTwoMonthAgoMonthWithManupilation
		  ,EC.RateOfTwoMonthAgo/**/
		  ,EC.ExpectedEOPValueWrtTwoMonthAgo
		  ,EC.EOPTwoMonthAgoValue
		  ,EC.PTDThreeMonthAgo
		  ,EC.EOPofThreeMonthAgoMonthWithManupilation
		  ,EC.RateOfThreeMonthAgo/**/
		  ,EC.ExpectedEOPValueWrtThreeMonthAgo
		  ,EC.EOPThreeMonthAgoValue
		  ,EC.MeanOfExpectedEOPValueOfLastThreeMonths
		  ,SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) StdDevOfLastThreeMonth
		  ,EC.ExpectedEOPValueWrtLastMonth			 -SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) LowerIntervalOfExpectedEOPValueWrtLastMonth
		  ,EC.ExpectedEOPValueWrtLastMonth			 +SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) UpperIntervalOfExpectedEOPValueWrtLastMonth
		  ,EC.ExpectedEOPValueWrtTwoMonthAgo		 -SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) LowerIntervalOfExpectedEOPValueWrtTwoMonthAgo
		  ,EC.ExpectedEOPValueWrtTwoMonthAgo		 +SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) UpperIntervalOfExpectedEOPValueWrtTwoMonthAgo
		  ,EC.ExpectedEOPValueWrtThreeMonthAgo		 -SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) LowerIntervalOfExpectedEOPValueWrtThreeMonthAgo
		  ,EC.ExpectedEOPValueWrtThreeMonthAgo		 +SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) UpperIntervalOfExpectedEOPValueWrtThreeMonthAgo
		  ,EC.MeanOfExpectedEOPValueOfLastThreeMonths-SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) LowerIntervalOfExpectedEOPValueWrtMeanValue
		  ,EC.MeanOfExpectedEOPValueOfLastThreeMonths+SQRT((SQUARE(EC.ExpectedEOPValueWrtLastMonth-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths)+SQUARE(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.MeanOfExpectedEOPValueOfLastThreeMonths))/3) UpperIntervalOfExpectedEOPValueWrtMeanValue
		  ,EC.ExpectedEOPValueWrtLastMonth-EC.RealizedEOPValue								ErrorOfExpectedEOPValueWrtLastMonth
		  ,cast(COALESCE(((cast(EC.ExpectedEOPValueWrtLastMonth-EC.RealizedEOPValue as decimal(38,10))))*1.0/(NULLIF(cast(EC.RealizedEOPValue as decimal(38,10)), 0)), 0) as decimal(20,6))	ErrorRateOfExpectedEOPValueWrtLastMonth/**/
		  ,EC.ExpectedEOPValueWrtTwoMonthAgo-EC.RealizedEOPValue						    ErrorOfExpectedEOPValueWrtTwoMonthAgo
		  ,cast(COALESCE(((cast(EC.ExpectedEOPValueWrtTwoMonthAgo-EC.RealizedEOPValue as decimal(38,10))))*1.0/(NULLIF(cast(EC.RealizedEOPValue as decimal(38,10)), 0)), 0) as decimal(20,6))	ErrorRateOfExpectedEOPValueWrtTwoMonthAgo
		  ,EC.ExpectedEOPValueWrtThreeMonthAgo-EC.RealizedEOPValue							ErrorOfExpectedEOPValueWrtThreeMonthAgo
		  ,cast(COALESCE(((cast(EC.ExpectedEOPValueWrtThreeMonthAgo-EC.RealizedEOPValue as decimal(38,10))))*1.0/(NULLIF(cast(EC.RealizedEOPValue as decimal(38,10)), 0)), 0) as decimal(20,6)) ErrorRateOfExpectedEOPValueWrtThreeMonthAgo
		  ,cast(ABS(1-abs(MT1.ErrorRateOfExpectedEOPValueWrtLastMonth)) as decimal(20,6)) AccuracyOfLastMonthWrtPreviousMonth
		  ,cast(DAY(EOMONTH(@DailySP))*cast(EC.PTD as decimal(20,6))/DAY(@DailySP) as decimal(20,2)) ArithmeticExpectation
		  ,cast(DAY(EOMONTH(@DailySP))*cast(EC.PTD as decimal(20,6))/DAY(@DailySP)-cast(EC.RealizedEOPValue as decimal(20,6)) as decimal(20,2)) ErrorOfArithmeticExpectation
		  ,COALESCE(((DAY(EOMONTH(@DailySP))*cast(EC.PTD as decimal(20,6))/DAY(@DailySP)-cast(EC.RealizedEOPValue as decimal(20,6))))*1.0 / (NULLIF(cast(EC.RealizedEOPValue as decimal(20,6)), 0)), 0) ErrorRateOfArithmeticExpectation
		  ,cast(ABS(1-ABS(MT1.ErrorRateOfArithmeticExpectation)) as decimal(20,6)) AccuracyOflastMonthArithmeticExpectation
	FROM EOP_Calculation EC
	LEFT JOIN DWH_Workspace.dbo.FACT_DE_ExpectedValuesWithErrorsPTD_ms1 MT1 with (Nolock) ON DATEADD(MONTH,-1,EC.[Date]) = MT1.[Date] AND EC.Feature = MT1.Feature AND EC.MeasureType = MT1.MeasureType AND EC.PeriodType = MT1.PeriodType AND EC.EntityType = MT1.EntityType AND EC.Currency = MT1.Currency
)  INSERT INTO DWH_Workspace.dbo.FACT_DE_ExpectedValuesWithErrorsPTD_ms1
   SELECT*FROM LastEstimates
SET @DailySP=DATEADD(DAY,1,@DailySP)
SET				@PTDOfLastMonth		  = DATEADD(MONTH,-1,@DailySP)
SET				@PTDOfTwoMonthsAgo	  = DATEADD(MONTH,-2,@DailySP)
SET				@PTDOfThreeMonthsAgo  = DATEADD(MONTH,-3,@DailySP)
END