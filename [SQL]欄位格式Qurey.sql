Declare @TableName As varchar(50)
SET @TableName = 'td_dtl'

select *,sColumnsName,
case when sColumnsType in ('varchar','nvarchar','char') then Convert(nvarchar,(sColumnsType + '(' + Convert(nvarchar,iColumnsLength) + ')')) else 
case when sColumnsType in ('decimal','numeric') then Convert(nvarchar,(sColumnsType + '(' + Convert(nvarchar,iColumnsLength) + ',' + Convert(nvarchar,iColumnsScale) + ')')) else 
sColumnsType end end as MsColumnsType
from 
(
SELECT         dbo.sysobjects.name AS sTableName, 
                          dbo.syscolumns.name AS sColumnsName, 
                          dbo.syscolumns.prec AS iColumnsLength, 
						  dbo.syscolumns.scale AS iColumnsScale,
                          dbo.syscolumns.colorder AS iColumnsOrder, 
                          dbo.systypes.name + '' AS sColumnsType, 
                          dbo.syscolumns.isnullable AS iIsNull
FROM             dbo.sysobjects INNER JOIN
                          dbo.syscolumns ON dbo.sysobjects.id = dbo.syscolumns.id INNER JOIN
                          dbo.systypes ON dbo.syscolumns.xusertype = dbo.systypes.xusertype
WHERE         (dbo.sysobjects.xtype = 'U')
) A
where A.sTableName = @TableName