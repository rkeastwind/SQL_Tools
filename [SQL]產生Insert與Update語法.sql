/*
[SQL]����Insert�PUpdate�y�k

�@�̡G���j�S�W�Ū��Ѥ~&�ҦV�L�Ī����j�j

�o�O�@�ӶW�Ŵ��z���u��A�i�H���Ͱ���y�k��@�����A�ⲣ�X���y�k�K�bSelect���Ĥ@��
�\��G
1.date�ഫ��yyyy-mm-dd�Adatetime�ഫ��yyyy-mm-dd hh:mm:ss.mmm�A��l������r��
2.�ϥ�CASE WHEN�B�zNULL�ANULL����[�޸�
3.�r��w�Ǥ@��COLLATE Chinese_Taiwan_Stroke_CS_AS�A�קK�w�ǰ��D�X��
4.��r���A���Ҽ{���]�t�u'�v������
5.Identity�|�۰ʱư�
*/

SET NOCOUNT ON

DECLARE @TableName AS VARCHAR(50)
DECLARE @Action AS INT
DECLARE @Upd_Columns AS VARCHAR(MAX)
DECLARE @Upd_Keys AS VARCHAR(MAX)

--�����ѼƳ]�w_BEGIN��
SET @TableName = 'skl_GlStkPool'
SET @Action = 1 --1.Insert  2.Update

--Update����(�r�I�Ϲj)
SET @Upd_Columns = 'd_cost,t_cost'
SET @Upd_Keys = 'tran_no'

--���o��
SELECT 
	*,
	CASE WHEN sColumnsType IN ('varchar','nvarchar','char') THEN CONVERT(NVARCHAR,(sColumnsType + '(' + CONVERT(NVARCHAR,iColumnsLength) + ')')) ELSE 
		CASE WHEN sColumnsType IN ('decimal','numeric') THEN CONVERT(NVARCHAR,(sColumnsType + '(' + CONVERT(NVARCHAR,iColumnsLength) + ',' + CONVERT(NVARCHAR,iColumnsScale) + ')')) ELSE 
		sColumnsType END END AS MsColumnsType,
	CASE WHEN sColumnsType = 'date' THEN 'CONVERT(NVARCHAR, '+sColumnsName+', 120)' ELSE
		CASE WHEN sColumnsType like '%datetime%' THEN 'CONVERT(NVARCHAR, '+sColumnsName+', 121)' ELSE
		'REPLACE(CAST('+sColumnsName+' AS NVARCHAR(MAX)),'''''''','''''''''''') COLLATE Chinese_Taiwan_Stroke_CS_AS' END END AS ConvertText,
		--REPLACE(CAST(sColumnsName AS NVARCHAR),'''','''''')
	COLUMNPROPERTY(sColumnsId, sColumnsName, 'IsIdentity') AS IsIdentity
INTO #BAS
FROM 
(
	SELECT
		dbo.sysobjects.name AS sTableName,
		dbo.syscolumns.id AS sColumnsId,
		dbo.syscolumns.name AS sColumnsName, 
		dbo.syscolumns.prec AS iColumnsLength, 
		dbo.syscolumns.scale AS iColumnsScale,
		dbo.syscolumns.colorder AS iColumnsOrder, 
		dbo.systypes.name + '' AS sColumnsType, 
		dbo.syscolumns.isnullable AS iIsNull
	FROM dbo.sysobjects
	INNER JOIN dbo.syscolumns ON dbo.sysobjects.id = dbo.syscolumns.id 
	INNER JOIN dbo.systypes ON dbo.syscolumns.xusertype = dbo.systypes.xusertype
	WHERE (dbo.sysobjects.xtype = 'U')
	) A
WHERE A.sTableName = @TableName
ORDER BY A.iColumnsOrder

--�B�z���
DECLARE @ErrCol AS NVARCHAR(MAX) = ''
DECLARE @ErrMsg AS NVARCHAR(MAX) = ''

DECLARE @InsertText AS NVARCHAR(MAX)
DECLARE @UpdText_Set AS NVARCHAR(MAX) = ''
DECLARE @UpdText_Where AS NVARCHAR(MAX) = ''

DECLARE @x XML
DECLARE @Upd_Columns_T TABLE
(
	Col	NVARCHAR(50) DEFAULT('')
)
DECLARE @Upd_Keys_T TABLE
(
	Col	NVARCHAR(50) DEFAULT('')
)

IF(@Action = 2)
	BEGIN
		--�ഫ��Table
		SET @x = CONVERT(XML, '<n>' + replace(@Upd_Columns, ',', '</n><n>') + '</n>')
		INSERT INTO @Upd_Columns_T SELECT T.n.value('.','varchar(50)') FROM @x.nodes('n') T(n)

		SET @x = CONVERT(XML, '<n>' + replace(@Upd_Keys, ',', '</n><n>') + '</n>')
		INSERT INTO @Upd_Keys_T SELECT T.n.value('.','varchar(50)') FROM @x.nodes('n') T(n)
	END

--���ˮ֡�
IF ((SELECT COUNT(*) FROM #BAS) =0)
	BEGIN
		SET @ErrMsg = '[ERROR]��ƪ�'+@TableName+'���s�b�t��'
		GOTO End_Command
	END
IF (@Action = 2 AND (@Upd_Columns = '' OR @Upd_Keys = ''))
	BEGIN
		SET @ErrMsg = '[ERROR]Update�y�k@Upd_Columns�M@Upd_Keys���i����'
		GOTO End_Command
	END
IF ((SELECT COUNT(*) FROM @Upd_Columns_T WHERE Col NOT IN (SELECT sColumnsName FROM #BAS)) > 0)
	BEGIN
		SET @ErrCol = (SELECT '['+Col+'],' FROM @Upd_Columns_T WHERE Col NOT IN (SELECT sColumnsName FROM #BAS) FOR XML PATH(''))
		SET @ErrMsg = '[ERROR]Update�y�kUpd���'+@ErrCol+'���s�b'
		GOTO End_Command
	END
IF ((SELECT COUNT(*) FROM @Upd_Columns_T WHERE Col IN (SELECT sColumnsName FROM #BAS WHERE IsIdentity = 1)) > 0)
	BEGIN
		SET @ErrCol = (SELECT '['+Col+'],' FROM @Upd_Columns_T WHERE Col IN (SELECT sColumnsName FROM #BAS WHERE IsIdentity = 1) FOR XML PATH(''))
		SET @ErrMsg = '[ERROR]Update�y�kUpd���'+@ErrCol+'��Identity'
		GOTO End_Command
	END
IF ((SELECT COUNT(*) FROM @Upd_Keys_T WHERE Col NOT IN (SELECT sColumnsName FROM #BAS)) > 0)
	BEGIN
		SET @ErrCol = (SELECT '['+Col+'],' FROM @Upd_Keys_T WHERE Col NOT IN (SELECT sColumnsName FROM #BAS) FOR XML PATH(''))
		SET @ErrMsg = '[ERROR]Update�y�kWhere���'+@ErrCol+'���s�b'
		GOTO End_Command
	END

--�ջy�k
IF (@Action = 1)
	BEGIN
		--@InsertText
		SET @InsertText = (
				SELECT
					'+CASE WHEN '+sColumnsName+' IS NULL THEN ''NULL'' ELSE ''''''''+'+ConvertText+'+'''''''' END+'','''
				FROM #BAS A
				WHERE IsIdentity != 1
				FOR XML PATH('')
			)
		SET @InsertText = SUBSTRING(@InsertText,1,LEN(@InsertText)-3)+''')'''
	END

IF(@Action = 2)
	BEGIN
		--@UpdText_Set
		SET @UpdText_Set = (
			SELECT
				'+'''+Col+' = ''+CASE WHEN '+Col+' IS NULL THEN ''NULL'' ELSE ''''''''+'+ConvertText+'+'''''''' END+'','''
			FROM @Upd_Columns_T A
			INNER JOIN #BAS B ON A.Col = B.sColumnsName
			FOR XML PATH('')
		)
		SET @UpdText_Set = SUBSTRING(@UpdText_Set,1,LEN(@UpdText_Set)-4)

		--@UpdText_Where
		SET @UpdText_Where = '+'' WHERE ''' + (
			SELECT
				'+'''+Col+' = ''''''+'+ConvertText+'+'''''' AND '''
			FROM @Upd_Keys_T A
			INNER JOIN #BAS B ON A.Col = B.sColumnsName
			FOR XML PATH('')
		)
		SET @UpdText_Where = SUBSTRING(@UpdText_Where,1,LEN(@UpdText_Where)-9)+''''''''''
	END

--Final
IF (@Action = 1)
	SELECT '''INSERT INTO ' + @TableName + ' VALUES(''' + @InsertText + '+'';'''
IF (@Action = 2)
	SELECT '''UPDATE ' + @TableName + ' SET ''' + @UpdText_Set + @UpdText_Where + '+'';'''

End_Command:
IF (@ErrMsg <> '')
	PRINT @ErrMsg

DROP TABLE #BAS

SET NOCOUNT OFF