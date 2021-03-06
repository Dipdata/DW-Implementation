/****** Script for SelectTopNRows command from SSMS  ******/

select * from [Spring].[dbo].[ODSProdTable]
go

/*Creating the an enterprise data warehouse database*/
Use dw_env
go
Create Procedure DWProc
as
 
 If not exists(Select * from sys.databases 
 where name='edw_prod')
 Create Database edw_prod
Go


/* Procedures to create 5 different dimension tables */
--Country Dimension Table
Use dw_env
Go
Create Procedure DimCountryProc
as 

if object_id('DimCountry') is not null Drop table DimCountry

Create Table DimCountry
(
CountryKey   int identity(1,1) primary key,
CountryName  varchar(50) 
) 

--Create Retailer Dimension Table
Use dw_env
Go
Create Procedure DimRetailerProc 
as 

If OBJECT_ID ('DimRetail') is not null Drop table DimRetail

Create Table DimRetailer 
(
RetailKey   int identity(1,1) primary key,
RetailType  varchar(25)
)

Go

--Create Product Dimension Table
Use dw_env
go
Create procedure DimProductProc
as 

if OBJECT_ID('DimProduct') is not null Drop table DimProduct

Create Table DimProduct 
(
ProductKey  int identity(1,1) primary key,
ProductLine varchar(100),
ProductType varchar(50),
Product     varchar(100)
)

--Create Period Dimension Table
Create Procedure DimPeriodProc
as 
If object_id('DimPeriod') is not null Drop Table DimPeriod 

Create Table DimPeriod 
(
PeriodKey   int identity(1,1) primary key,
Year   int,
Quarter varchar(10)
)

--Order Dimension Table 
Use dw_env
go
Create Procedure DimOrderProc 
as 

If object_id ('DimOrder') is not null Drop Table DimOrder 

Create Table DimOrder 
(
OrderKey  int identity(1,1) primary key,
OrderMethdType varchar(25)
)

Go

/*Create the Fact Table to hold all additive and semi-additive measures*/
Use dw_env
go
Create Procedure FactOrderRevenueProc 
as 

If object_id('FactOrderRevenue') is not null Drop Table FactOrderRevenue 

Create Table FactOrderRevenue 
(
FactOrderRevenueKey  int identity(1,1)  primary key,
CountryKey int references DimCountry(CountryKey),
ProductKey int references DimProduct(ProductKey),
PeriodKey  int references DimPeriod(PeriodKey),
OrderKey   int references DimOrder(OrderKey),
Revenue    float,
Quantity   int,
GrossMargin float  
)
Go


/*Populate Distinct Country records into the Country Dimension from Operational Data Store*/
Use dw_env
Go 
Declare @Country varchar(50);
Declare c_cur Cursor For Select distinct[Retailer country] from Spring.dbo.ODSProdTable

Open c_cur;
 Fetch next from c_cur into @Country 
While @@FETCH_STATUS = 0 
  Begin 
    Fetch next from c_cur into @Country 
	 Insert into DimCountry(CountryName)
	  Values(@Country)
  End 
Close c_cur;
Deallocate c_cur;


Go 


/*Populating data into the Product dimension table from ODS*/
Use dw_env
go
--Declare @Counter int = 1;
Declare @ProductLine varchar(100);
Declare @ProductType varchar(50);
Declare @Product  varchar(100);
Declare acur Cursor For Select Distinct[Product line],[Product type],Product
from Spring.dbo.ODSProdTable;

Open acur;

Fetch Next from acur into @ProductLine,@ProductType,@Product
while @@FETCH_STATUS = 0 
begin 

--set @Counter = @Counter + 1;

 fetch next from acur into @ProductLine,@ProductType,@Product

Insert into dw_env.dbo.DimProduct(ProductLine,ProductType,Product)
Values(@ProductLine,@ProductType,@Product)


--select * from dw_env.dbo.DimProduct
end

close acur;
--set @Counter = @Counter + 1;
deallocate acur;
go


/*Populating the Order dimension table from OLTP*/
Use dw_env 
Go 
Declare @Order varchar(25);
Declare fincur Cursor For Select distinct[Order method type] from Spring.dbo.ODSProdTable;

open fincur; 

While @@Fetch_Status = 0 
 Fetch next from fincur Into @Order 
  Begin 
	Fetch next from fincur Into @Order 
	 Insert into dw_env.dbo.DimOrder(OrderMethdType)
	  Values(@Order)
  End 
    
Close fincur ;
Deallocate fincur ;
Go

select * from dw_env.dbo.DimOrder
Drop Procedure DimPeriodProc

Go 

/*Populate Dimension Period Table with data from ODS*/
Use dw_env 
go 
Declare @Yr int;
Declare @Qtr varchar(10);
Declare pe_cur Cursor For Select distinct[YEAR],[Quarter] from Spring.dbo.ODSProdTable;

Open pe_cur;
Fetch Next from pe_cur Into @Yr,@Qtr
 While @@FETCH_STATUS = 0 
   Begin 
     Fetch Next from pe_cur Into @Yr,@Qtr
	  Insert into dw_env.dbo.DimPeriod([Year],[Quarter])
	   Values(@Yr,@Qtr)
   End 
Close pe_cur;
Deallocate pe_cur;
Go


/*Populate Retailer Dimension table with records from the OLTP System*/
Use dw_env
Go
Declare @Retail  varchar(25);
Declare retcur Cursor for Select distinct[Retailer type]
from Spring.dbo.ODSProdTable;

Open retcur; 
 Fetch next from retcur into @Retail
  While @@FETCH_STATUS = 0 
   Begin
    Fetch next from retcur into @Retail
	 Insert into [dw_env].[dbo].[DimRetailer](RetailType)
	  Values(@Retail);
   End 
   --select * from [dw_env].[dbo].[DimRetailer] 
close retcur;
deallocate retcur;
Go

select * from [dw_env].[dbo].[DimRetailer] 
  


/*Populate Order Dimension Table from the OLTP system */
Use dw_env
Go 
Declare @Order varchar(25);
Declare ocur Cursor For Select Distinct[Order method type] from Spring.dbo.ODSProdTable

Open ocur;

 Fetch next from ocur into @Order;

 While @@FETCH_STATUS = 0 
   Begin 
     Fetch next from ocur into @Order
	  Insert into dw_env.dbo.DimOrder(OrderMethdType)
	   Values(@Order)
   End
Close ocur; 
Deallocate ocur;  
Go


/*Populating the Fact Table with records Off the dimensions and ODS*/
Use dw_env 
Go 
Insert into FactOrderRevenue(CountryKey,ProductKey,PeriodKey,OrderKey
,Revenue,Quantity,GrossMargin)
 Select CountryKey 
        ,ProductKey
		,PeriodKey
		,OrderKey
		,Revenue
		,Quantity
		,[Gross Margin]
  from DimCountry dc, DimProduct dp, DimPeriod di, DimOrder do, 
  Spring.dbo.ODSProdTable opt
  where dc.CountryName = opt.[Retailer country]
    and dp.ProductLine = opt.[Product line]
	and dp.ProductType = opt.[Product type]
	and dp.Product = opt.Product
	and di.Year = opt.Year 
	and di.Quarter = opt.Quarter 
	and do.OrderMethdType = opt.[Order method type]

