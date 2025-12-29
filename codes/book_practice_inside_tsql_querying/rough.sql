use learningDb 
go

select c.customerid, count(o.orderid) as count_orders
from dbo.customers as C
	left outer join dbo.orders as O
		on C.customerid = O.customerid
where C.city = 'Madrid'
Group by c.customerid
order by count(o.orderid)