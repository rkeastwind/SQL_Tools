SET NOCOUNT ON

DECLARE @beg_date AS DATE = '20210101'
DECLARE @end_date AS DATE = '20211231'

--計時
DECLARE @ct AS DATETIME = GETDATE()
DECLARE @csp AS VARCHAR(50)
DECLARE @rc AS INT

--step1.先更新結帳單位庫存
UPDATE inv_bnd_bal SET
	pno_cost = cost,
	pno_acc_cost = acc_cost,
	pno_eom_amortize = eom_amortize,
	pno_acc_eom_amortize = acc_eom_amortize
WHERE fno = ''  --結帳單位
	AND date BETWEEN @beg_date AND @end_date

SET @csp = (SELECT CONVERT(VARCHAR, DATEADD(s, datediff(ss,@ct,getdate()), 0), 108))
SET @ct = GETDATE()
PRINT '[完成]step1.先更新結帳單位庫存，耗時 ' + @csp

--利用sw判斷是否要進入分攤，沒有的話直接回壓
SELECT
	0 AS sw,
	A.date, A.code, A.pno, A.fno, A.cap_tp, A.trade_no,
	CONVERT(NVARCHAR,A.date,112) + '|' + A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no + '|' + A.fno AS I_Key,
	CONVERT(NVARCHAR,A.date,112) + '|' + A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no AS I_GroupKey,
	ISNULL(dbo.fn_GetCcyDigit(C.ccy),2) AS I_Decimal,  --bnd0002586沒資料先預設2
	dbo.fn_GetCcyDigit(D.book_ccy) AS I_Decimal_Acc,
	A.org_par_value AS I_RatioValue,  --用org_par_value
	B.cost AS I_cost,
	B.acc_cost AS I_acc_cost,
	B.eom_amortize AS I_eom_amortize,
	B.acc_eom_amortize AS I_acc_eom_amortize
INTO #For_AllowCation
FROM inv_bnd_bal A
INNER JOIN inv_bnd_bal B
	ON A.date = B.date
	AND A.code = B.code
	AND A.pno = B.pno
	AND A.cap_tp = B.cap_tp
	AND A.trade_no = B.trade_no
	AND B.fno = ''  --結帳單位
LEFT JOIN cmn_bond C ON A.code = C.code
LEFT JOIN ims_invt_unit D ON A.pno = D.pno
WHERE A.fno != ''  --投組
	AND (A.org_par_value !=0)  --排除庫存0資料
	AND A.date BETWEEN @beg_date AND @end_date
             
--更新sw
UPDATE A SET sw = (SELECT COUNT(*) FROM #For_AllowCation WHERE I_GroupKey = A.I_GroupKey)
from #For_AllowCation A

--step2.sw=1處理
UPDATE A SET
	pno_cost = I_cost,
	pno_acc_cost = I_acc_cost,
	pno_eom_amortize = I_eom_amortize,
	pno_acc_eom_amortize = I_acc_eom_amortize
FROM inv_bnd_bal A
INNER JOIN #For_AllowCation B
	ON A.date = B.date
	AND A.code = B.code
	AND A.pno = B.pno
	AND A.cap_tp = B.cap_tp
	AND A.trade_no = B.trade_no
	AND A.fno = B.fno
WHERE B.sw = 1

SET @rc = (SELECT COUNT(*) FROM #For_AllowCation WHERE sw=1)
SET @csp = (SELECT CONVERT(VARCHAR, DATEADD(s, datediff(ss,@ct,getdate()), 0), 108))
SET @ct = GETDATE()
PRINT '[完成]step2.sw=1處理，筆數 ' + CAST(@rc AS VARCHAR) + ' ，耗時 ' + @csp

--step3.sw>1處理
DECLARE @TailSet AS INT = 0
DECLARE @result TABLE
(
	I_Key             NVARCHAR(MAX),    --主Key
	I_GroupKey        NVARCHAR(MAX),    --群組Key
	I_Decimal         INT,              --小數位精度
	I_Decimal_Acc     INT,              --小數位精度_ACC
	I_RatioValue      NUMERIC(25,8),    --計算比率用的數字
	----
	I_TotalValue1     NUMERIC(25,8),    --群組Key要分攤的數字
	I_TotalValue2     NUMERIC(25,8),    --群組Key要分攤的數字
	I_TotalValue3     NUMERIC(25,8),    --群組Key要分攤的數字
	I_TotalValue4     NUMERIC(25,8),    --群組Key要分攤的數字
	----
	O_NetValue1        NUMERIC(25,8),    --數字x比率
	O_TailDiff1        NUMERIC(25,8),    --尾差
	O_Value1           NUMERIC(25,8),    --結果
	O_NetValue2        NUMERIC(25,8),    --數字x比率
	O_TailDiff2        NUMERIC(25,8),    --尾差
	O_Value2           NUMERIC(25,8),    --結果
	O_NetValue3        NUMERIC(25,8),    --數字x比率
	O_TailDiff3        NUMERIC(25,8),    --尾差
	O_Value3           NUMERIC(25,8),    --結果
	O_NetValue4        NUMERIC(25,8),    --數字x比率
	O_TailDiff4        NUMERIC(25,8),    --尾差
	O_Value4           NUMERIC(25,8)     --結果
)

INSERT INTO @result
SELECT
	I_Key,
	I_GroupKey,
	I_Decimal,
	I_Decimal_Acc,
	I_RatioValue,
	----
	I_cost,
	I_acc_cost,
	I_eom_amortize,
	I_acc_eom_amortize,
	----
	0,0,0,
	0,0,0,
	0,0,0,
	0,0,0
FROM #For_AllowCation
WHERE sw > 1

	--計算比率
	UPDATE A
	SET
		--比率不加括號，計算無法整除的分數會比較貼近，如1/3
		O_NetValue1 = ROUND((CASE WHEN B.G_RatioValue <> 0 THEN A.I_TotalValue1 * A.I_RatioValue / B.G_RatioValue ELSE A.I_TotalValue1 END),
							A.I_Decimal,1),
		O_NetValue2 = ROUND((CASE WHEN B.G_RatioValue <> 0 THEN A.I_TotalValue2 * A.I_RatioValue / B.G_RatioValue ELSE A.I_TotalValue2 END),
							A.I_Decimal_Acc,1),
		O_NetValue3 = ROUND((CASE WHEN B.G_RatioValue <> 0 THEN A.I_TotalValue3 * A.I_RatioValue / B.G_RatioValue ELSE A.I_TotalValue3 END),
							A.I_Decimal,1),
		O_NetValue4 = ROUND((CASE WHEN B.G_RatioValue <> 0 THEN A.I_TotalValue4 * A.I_RatioValue / B.G_RatioValue ELSE A.I_TotalValue4 END),
							A.I_Decimal_Acc,1)
	FROM @result A
	LEFT JOIN (
		SELECT
			I_GroupKey,
			SUM(I_RatioValue) AS G_RatioValue
		FROM @result
		GROUP BY I_GroupKey
		) B ON A.I_GroupKey = B.I_GroupKey
		
	--調整尾差
	UPDATE R
	SET
		O_TailDiff1 = ISNULL(TailDiff1, 0.0),
		O_Value1 = O_NetValue1 + ISNULL(TailDiff1, 0.0),
		O_TailDiff2 = ISNULL(TailDiff2, 0.0),
		O_Value2 = O_NetValue2 + ISNULL(TailDiff2, 0.0),
		O_TailDiff3 = ISNULL(TailDiff3, 0.0),
		O_Value3 = O_NetValue3 + ISNULL(TailDiff3, 0.0),
		O_TailDiff4 = ISNULL(TailDiff4, 0.0),
		O_Value4 = O_NetValue4 + ISNULL(TailDiff4, 0.0)
	FROM @result R
	LEFT JOIN (
		SELECT
			F.I_Key,
			I_TotalValue1 - (SELECT SUM(O_NetValue1) FROM @result WHERE I_GroupKey = F.I_GroupKey) AS TailDiff1,
			I_TotalValue2 - (SELECT SUM(O_NetValue2) FROM @result WHERE I_GroupKey = F.I_GroupKey) AS TailDiff2,
			I_TotalValue3 - (SELECT SUM(O_NetValue3) FROM @result WHERE I_GroupKey = F.I_GroupKey) AS TailDiff3,
			I_TotalValue4 - (SELECT SUM(O_NetValue4) FROM @result WHERE I_GroupKey = F.I_GroupKey) AS TailDiff4
		FROM (
			SELECT
				ROW_NUMBER() OVER (PARTITION BY I_GroupKey ORDER BY I_RatioValue DESC) AS od0,  --給金額最大
				ROW_NUMBER() OVER (PARTITION BY I_GroupKey ORDER BY I_RatioValue ASC) AS od1,   --給金額最小
				*
				FROM @result
			) F
		WHERE od0 = IIF(@TailSet = 0, 1, od0) AND od1 = IIF(@TailSet = 1, 1, od1)
		) DIFF ON R.I_Key = DIFF.I_Key


UPDATE A SET
	pno_cost = O_Value1,
	pno_acc_cost = O_Value2,
	pno_eom_amortize = O_Value3,
	pno_acc_eom_amortize = O_Value4
FROM inv_bnd_bal A
INNER JOIN @result B
	ON CONVERT(NVARCHAR,A.date,112) + '|' + A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no + '|' + A.fno = B.I_Key


SET @rc = (SELECT COUNT(*) FROM #For_AllowCation WHERE sw > 1)
SET @csp = (SELECT CONVERT(VARCHAR, DATEADD(s, datediff(ss,@ct,getdate()), 0), 108))
SET @ct = GETDATE()
PRINT '[完成]step2.sw>1處理，筆數 ' + CAST(@rc AS VARCHAR) + ' ，耗時 ' + @csp

DROP TABLE #For_AllowCation

SET NOCOUNT OFF