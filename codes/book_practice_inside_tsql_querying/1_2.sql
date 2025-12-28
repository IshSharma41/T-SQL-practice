set NOCOUNT on;
use tempdb;
GO
if Object_id('dbo.orders') is not null
    drop table dbo.orders;
GO
if object_id('dbo.customers') is NOT NULL
    drop table dbo.customers;
GO
create table dbo.customers
(
    customerid char(5)     not null primary key, 
    city       varchar(10) not null
);

insert into dbo.customers (customerid, city) values
('FISSA', 'madrid');
insert into dbo.customers(customerid, city) values 
('FRNDO', 'Madrid');
insert into dbo.customers(customerid, city) values 
('KRLOS', 'Madrid');
insert into dbo.customers(customerid, city) values 
('MRPHS','Zion');


create table dbo.orders
(
orderid    int not null primary key, 
customerid char(5) null references customers(customerid)
);
insert into dbo.orders(orderid, customerid) values 
(1,'FRNDO');
insert into dbo.orders(orderid, customerid) values 
(2,'FRNDO');
insert into dbo.orders(orderid, customerid) values 
(3,'KRLOS');
insert into dbo.orders(orderid, customerid) values 
(4,'KRLOS');
insert into dbo.orders(orderid, customerid) values 
(5,'KRLOS');
insert into dbo.orders(orderid, customerid) values 
(6,'MRPHS');
insert into dbo.orders(orderid, customerid) values 
(7,null);