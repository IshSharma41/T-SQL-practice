use learningDB
go

select C.customerid, count(O.orderid) as numOrders
from dbo.customers as C
	left outer join dbo.orders as O
		on C.customerid = O.customerid
where C.city = 'Madrid'
Group by c.customerid
having count(o.orderid) < 3
order by numorders;