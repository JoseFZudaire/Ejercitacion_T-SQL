--Ejercicio 1
use GD2015C1;

if object_id('funcion_ocupacion_deposito') is not null
	drop function funcion_ocupacion_deposito
go

create function funcion_ocupacion_deposito (@producto char(8), @deposito char(2))
	returns char(255)
begin
	declare @mensaje char(255)
	declare @stock decimal(12,2)
	declare @limite decimal(12,2)
	declare @porcentaje decimal(12,2)

	select 
	@stock = STOCK.stoc_cantidad,
	@limite = STOCK.stoc_stock_maximo
	from STOCK
	where STOCK.stoc_producto = @producto
	and STOCK.stoc_deposito = @deposito

	if @limite is not null and
		@limite >= 0 and
		@stock < @limite
	
		begin
			set @porcentaje = (@stock/@limite)*100
			set @mensaje = concat ('OCUPACION DEL DEPOSITO ', @porcentaje, '%')
		end
	
	else 
		set @mensaje = 'DEPOSITO COMPLETO'
	return @mensaje

end
go

--Prueba 1
select *
from dbo.STOCK
where stoc_producto = '00000102' and stoc_deposito = '02';

select dbo.funcion_ocupacion_deposito('00000102','02');

--Prueba 2
select *
from dbo.STOCK
where stoc_producto = '00000172' and stoc_deposito = '00';

select dbo.funcion_ocupacion_deposito('00000172','00');




















