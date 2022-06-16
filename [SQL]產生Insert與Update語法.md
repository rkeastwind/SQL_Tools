# [SQL]產生Insert與Update語法

## Indroduction

將Select出來的資料轉換成Insert或Update語法。目前有些第三方軟體有此功能，但有些公司因為企業用途或軟體安裝限制無法使用，所以自己寫一個。

## How to use

1. 先設定以下參數

```SQL
	--※★參數設定_BEGIN★
	SET @TableName = 'skl_GlStkPool'
	SET @Action = 1 --1.Insert  2.Update

	--Update條件(逗點區隔)
	SET @Upd_Columns = 'd_cost,t_cost'
	SET @Upd_Keys = 'tran_no'
```

2. 把產出的語法貼在Select的第一欄，執行後的結果，第一欄就會是你要的語法

```SQL
	SELECT
		[產生出的語法]
		,*
	WHERE [你的條件]
```

## Guid

1. date轉換為yyyy-mm-dd，datetime轉換為yyyy-mm-dd hh:mm:ss.mmm，其餘直接轉字串
2. 使用CASE WHEN處理NULL，NULL不能加引號
3. 字串定序一律COLLATE Chinese_Taiwan_Stroke_CS_AS，避免定序問題出錯
4. 文字型態有考慮當中包含「'」的情形
5. Identity會自動排除

## Check

語法會檢查「資料表、Update的Columns、Keys...」，是否存在系統

## License

![GitHub User's stars](https://img.shields.io/badge/Copyright%40-Rick%20Lin-blue?style=?style=plastic&logo=GitHub)
