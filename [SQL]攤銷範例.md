# [SQL]攤銷範例

將一筆金額，依照比例攤給各筆資料，將尾差調給最大或最小的一筆

以往所見到的帳務系統公司，遇到此問題皆採用迴圈處理，但迴圈很耗效能，於是我想出可以善用SQL Join的方法，兩個步驟完成攤銷，大幅改善效能。

- [SQL]攤銷範例.sql > 擴充性較高的公版寫法，攤銷範例於step3開始，並同時提供計時的範例
- [SQL]攤銷範例2.sql > 實際應用上較精簡的寫法，相較迴圈還要宣告cursor，只要幾行即可完成

## Indroduction <處理方式說明>

ex.股票配息90000元，要依照股數攤給持有者，尾差調給最大，要產生的結果如下

| 人 | 股數 | 分配金額(無條件捨去) | 尾差 | 實際金額 |
| ---- | ---- | ---- | ---- | ---- |
| 王先生 | 6000 | 49090 | 2 | 49092 |
| 林先生 | 4000 | 32727 | 0 | 32727 |
| 蔡先生 | 1000 | 8181 | 0 | 8181 |

依照過往帳務系統公司的寫法，會使用迴圈，由小至大，將金額逐筆扣除，最後一筆剛好包含尾差

| 人 | 股數 | 分配金額 | 90000(餘數) |
| ---- | ---- | ---- | ---- |
| 蔡先生 | 1000 | 8181 | 81819 |
| 林先生 | 4000 | 32727 | 49092 |
| 王先生 | 6000 | 49092(直接給) | 0 |

但筆數一多，就有效能疑慮，既然是關聯式資料庫，就應該善用Join語法，我的作法如下

step1.先在每一筆資料列上，算出無條件捨去金額、標註總金額、用ROW_NUMBER()列出排序

| 人 | 股數 | 分配金額(無條件捨去) | 總金額 | 排序 |
| ---- | ---- | ---- | ---- | ---- |
| 王先生 | 6000 | 49090 | 90000 | 1 |
| 林先生 | 4000 | 32727 | 90000 | 2 |
| 蔡先生 | 1000 | 8181 | 90000 | 3 |

step2.用排序1的資料，串接計算尾差的Table，將尾差update至金額上，其餘資料不動

| 人 | 股數 | 分配金額(無條件捨去) | 總金額 | 排序 | 串聯尾差Table | 分配金額加總 | 尾差 | update後金額 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 王先生 | 6000 | 49090 | 90000 | 1 | ... | 89998 | 2 | 49092 |

結果

| 人 | 股數 | 分配金額 | 總金額 | 排序 |
| ---- | ---- | ---- | ---- | ---- |
| 王先生 | 6000 | **49092** | 90000 | 1 |
| 林先生 | 4000 | 32727 | 90000 | 2 |
| 蔡先生 | 1000 | 8181 | 90000 | 3 |

## License

![GitHub User's stars](https://img.shields.io/badge/Copyright%40-Rick%20Lin-blue?style=?style=plastic&logo=GitHub)
