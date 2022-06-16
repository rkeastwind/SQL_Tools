
use Invest_Accounting
select * from sys.database_files 

USE Invest_Accounting;  
GO  
-- Truncate the log by changing the database recovery model to SIMPLE.  
ALTER DATABASE Invest_Accounting  
SET RECOVERY SIMPLE;  
GO  
-- Shrink the truncated log file to 1 MB.  
DBCC SHRINKFILE (Invest_Accounting_log, 1);  
GO  
-- Reset the database recovery model.  
ALTER DATABASE Invest_Accounting  
SET RECOVERY FULL;  

GO  
