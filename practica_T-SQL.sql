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
	from dbo.STOCK
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


--Ejercicio 2
if OBJECT_ID('funcion_retorno_stock') is not null
	drop function funcion_retorno_stock
go

create function funcion_retorno_stock(@articulo char(8), @fecha smalldatetime)
	returns decimal(12,2)
begin
	declare @stock decimal(12,2)

	select @stock = sum(Item_Factura.item_cantidad)
	from dbo.Item_Factura 
		join dbo.Factura on Factura.fact_numero = Item_Factura.item_numero
			and Factura.fact_tipo = Item_Factura.item_tipo
			and Factura.fact_sucursal = Item_Factura.item_sucursal
	where Factura.fact_fecha >= @fecha
		and Item_Factura.item_producto = @articulo
	group by Item_Factura.item_producto

	return @stock
end
go

--Prueba 1 
select sum(Item_Factura.item_cantidad) Cantidad
from dbo.Item_Factura 
	join dbo.Factura on Factura.fact_numero = Item_Factura.item_numero
		and Factura.fact_tipo = Item_Factura.item_tipo
		and Factura.fact_sucursal = Item_Factura.item_sucursal
where Factura.fact_fecha >= '2011-12-16'
	and Item_Factura.item_producto = '00010395'
group by Item_Factura.item_producto
	
select dbo.funcion_retorno_stock('00010395','2011-12-16');

--Ejercicio 3
if OBJECT_ID('buscar_gerente') is not null
	drop procedure buscar_gerente
go

create procedure buscar_gerente(@cant_empleados int output)
as
begin
	set @cant_empleados =
	(select count(*)
	from dbo.Empleado
	where Empleado.empl_jefe is null)

	if @cant_empleados = 0
	begin
		raiserror('No hay empleados sin jefe', 16, 1)
		return
	end

	if @cant_empleados > 0
	begin
		declare @gerente numeric(6,0)

		set @gerente =
		(select top 1
		Empleado.empl_codigo
		from dbo.Empleado
		where Empleado.empl_jefe is null
		order by Empleado.empl_salario desc, Empleado.empl_ingreso asc)
	
	update dbo.Empleado
	set Empleado.empl_jefe = @gerente
	where Empleado.empl_jefe is null

	update Empleado
	set Empleado.empl_tareas = 'Gerente'
	where Empleado.empl_codigo = @gerente
	end

end
go

--Prueba 1
select *
from dbo.Empleado
where Empleado.empl_jefe is null;

declare @resultado int
exec buscar_gerente @resultado output
select @resultado
go

--Ejercicio 4
if OBJECT_ID('actualizar_empleado') is not null
	drop procedure actualizar_empleado;
go

create procedure actualizar_empleado(@vendedor as numeric(6,0) output)
as
begin
	declare @anio int;

	set @anio = year((select MAX(Factura.fact_fecha) from dbo.Factura))
	
	set @vendedor = (select top 1 Factura.fact_vendedor
	from dbo.Factura
	where year(Factura.fact_fecha) = @anio
	group by Factura.fact_vendedor
	order by SUM(Factura.fact_total) desc)

	update dbo.Empleado
	set Empleado.empl_comision = isnull((select sum(Factura.fact_total)
	from dbo.Factura
	where year(Factura.fact_fecha) = @anio
	and Empleado.empl_codigo = Factura.fact_vendedor),0) 

end 
go

--Prueba 1 
declare @anio int;

set @anio = year((select MAX(Factura.fact_fecha) from dbo.Factura))

select distinct Empleado.empl_comision, Empleado.empl_codigo
	from dbo.Factura
		join dbo.Empleado on Empleado.empl_codigo = Factura.fact_vendedor
	where year(Factura.fact_fecha) = @anio;

declare @resultado numeric(6,0)
exec actualizar_empleado @resultado output
select @resultado
go

--Ejercicio 5
use GD2015C1;

if object_id('Fact_table') is not null 
	drop table Fact_table;

create table Fact_table(
	anio char(4) not null,
	mes char(2) not null,
	familia char(3) not null,
	rubro char(4) not null,
	zona char(3) not null,
	cliente char(6) not null,
	producto char(8) not null,
	cantidad decimal(12,2) not null,
	monto decimal(12,2) 
	primary key (anio, mes, familia, rubro, zona, cliente, producto))
go

create procedure Completar_Datos
as 
begin
	insert into Fact_table (anio, mes, familia, rubro, zona, cliente, producto, cantidad, monto)
	select distinct year(Factura.fact_fecha) anio, month(Factura.fact_fecha) mes, 
		 (Producto.prod_familia) familia, (Producto.prod_rubro) rubro, 
		  (Departamento.depa_zona) zona, Factura.fact_cliente cliente,
		  (Item_Factura.item_producto) producto, cantidad, monto
	from dbo.Factura
		join dbo.Item_Factura on Factura.fact_numero = Item_Factura.item_numero
		join dbo.Producto on Producto.prod_codigo = Item_Factura.item_producto
		join dbo.Empleado on Factura.fact_vendedor = Empleado.empl_codigo
		join dbo.Departamento on Departamento.depa_codigo = Empleado.empl_departamento
	where Factura.fact_fecha is not null and Factura.fact_fecha is not null and
		 Producto.prod_familia is not null and Producto.prod_rubro is not null and
		  Departamento.depa_zona is not null and Factura.fact_cliente is not null
	order by Factura.fact_fecha; 
end
go

--Prueba 1

exec Completar_Datos
go

select * from Fact_table;













