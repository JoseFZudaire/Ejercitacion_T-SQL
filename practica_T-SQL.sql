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

--Ejercicio 6
use GD2015C1;

if OBJECT_ID('PR_UNIFICAR_PRODUCTOS') is not null
	drop procedure PR_UNIFICAR_PRODUCTOS
go

create procedure PR_UNIFICAR_PRODUCTOS
as
begin
	declare @producto char(8)
	declare @componente char(8)
	declare @tipo char(1)
	declare @sucursal char(4)
	declare @numero char(8)
	declare @cantidad_vendida decimal(12,2)
	declare @precio_producto decimal(12,2)
	declare @cantidad_componente decimal(12,2)

	declare c_componente cursor for
	select item_tipo, item_sucursal, item_numero,
		item_producto, item_cantidad, comp_cantidad,
		comp_producto, prod_precio
	from Item_Factura
	join Composicion on Item_Factura.item_producto = Composicion.comp_componente
	join Producto on Producto.prod_codigo = Composicion.comp_producto
	and Item_Factura.item_cantidad % Composicion.comp_cantidad = 0

	open c_componente

	fetch next from c_componente into @tipo, @sucursal,
		@numero, @precio_producto, @cantidad_vendida, 
		@cantidad_componente, @producto, @precio_producto

	while @@FETCH_STATUS = 0
	begin
		declare @componente2 char(8)
		declare @cantidad decimal(12,2)

		set @cantidad = @cantidad_vendida / @cantidad_componente

		set @componente2 =
		(select item_producto
		from Item_Factura
		join Composicion on Item_Factura.item_producto = Composicion.comp_producto
		where Item_Factura.item_tipo = @tipo
		and Item_Factura.item_sucursal = @sucursal
		and Item_Factura.item_numero = @numero
		and Item_Factura.item_producto != @componente
		and (Item_Factura.item_cantidad/Composicion.comp_cantidad) = @cantidad)

		if @componente is not null
		and @componente2 is not null
		begin
			delete from Item_Factura
			where Item_Factura.item_tipo = @tipo
			and Item_Factura.item_sucursal = @sucursal
			and Item_Factura.item_numero = @numero
			and Item_Factura.item_producto = @componente

			delete from Item_Factura
			where Item_Factura.item_tipo = @tipo
			and Item_Factura.item_sucursal = @sucursal
			and Item_Factura.item_numero = @numero
			and Item_Factura.item_producto = @componente2

			insert into Item_Factura
			values (@tipo, @sucursal, @numero,
			@producto, @cantidad, @precio_producto)
		end

	fetch next from c_componente into @tipo, @sucursal,
		@numero, @componente, @cantidad_vendida,
		@cantidad_componente, @producto, @precio_producto

	end

	close c_componente
	deallocate c_componente

end
go

--Prueba 1
INSERT INTO Producto VALUES ('99999999', 'PROD1', 15, '001', '0001', 1)
INSERT INTO Producto VALUES ('99999998', 'COMP1', 10, '001', '0001', 1)
INSERT INTO Producto VALUES ('99999997', 'COMP2', 10, '001', '0001', 1)
INSERT INTO Composicion VALUES (1, '99999999', '99999998')
INSERT INTO Composicion VALUES (2, '99999999', '99999997')
INSERT INTO Factura VALUES ('A', '0003', '99999999', GETDATE(), 1, 0, 0, NULL)
INSERT INTO Item_Factura VALUES ('A', '0003', '99999999', '99999998', 2, 10)
INSERT INTO Item_Factura VALUES ('A', '0003', '99999999', '99999997', 4, 20)

select * from Item_Factura
where Item_Factura.item_sucursal = '0003' and
	Item_Factura.item_numero = '99999999'

exec PR_UNIFICAR_PRODUCTOS;

ALTER TABLE Producto DISABLE TRIGGER ALL

DELETE FROM Item_Factura WHERE item_tipo = 'A' AND item_numero = '99999999'
AND item_sucursal = '0003' AND item_producto = '99999999'

DELETE FROM Factura WHERE fact_tipo = 'A' AND fact_numero = '99999999'
AND fact_sucursal = '0003'

DELETE FROM Composicion WHERE comp_producto = '99999999' AND comp_componente = '99999998'
DELETE FROM Composicion WHERE comp_producto = '99999999' AND comp_componente = '99999997'

DELETE FROM Producto WHERE prod_codigo = '99999999'
DELETE FROM Producto WHERE prod_codigo = '99999998'
DELETE FROM Producto WHERE prod_codigo = '99999997'

ALTER TABLE Producto ENABLE TRIGGER ALL
go

--Ejercicio 7

if OBJECT_ID('TABLA_VENTAS') is not null
	drop table TABLA_VENTAS
go

create table TABLA_VENTAS(
	venta_codigo char(8),
	venta_detalle char(50),
	venta_mov int,
	venta_precio decimal(12,2),
	venta_renglon int,
	venta_ganancia decimal(12,2)
)
go

if object_ID('PR_COMPLETAR_VENTAS') is not null
	drop procedure PR_COMPLETAR_VENTAS
go

create procedure PR_COMPLETAR_VENTAS(@fecha1 smalldatetime, @fecha2 smalldatetime)
as
begin
	declare @codigo char(8)
	declare @detalle char(50)
	declare @movimiento int
	declare @precio decimal(12,2)
	declare @renglon int
	declare @ganancia decimal(12,2)

	declare c_venta cursor for
	select Producto.prod_codigo,
		Producto.prod_detalle,
		sum(Item_Factura.item_cantidad),
		avg(Item_Factura.item_precio),
		sum(Item_Factura.item_precio*Item_Factura.item_cantidad) 
			- sum(Producto.prod_precio*Item_Factura.item_cantidad)
	from Producto
		join Item_Factura on Item_Factura.item_producto = Producto.prod_codigo
		join Factura on Factura.fact_tipo = Item_Factura.item_tipo
		 and Factura.fact_sucursal = Item_Factura.item_sucursal
		 and Factura.fact_numero = Item_Factura.item_numero
	where Factura.fact_fecha between @fecha1 and @fecha2
	group by Producto.prod_codigo, Producto.prod_detalle

	open c_venta

	fetch next from c_venta into @codigo, @detalle,
		@movimiento, @precio, @ganancia

	if OBJECT_ID('TABLA_VENTAS') is not null
		set @renglon = (select MAX(@renglon) from TABLA_VENTAS) + 1
	else 
		set @renglon = 0

	while @@FETCH_STATUS = 0
	begin 
		insert into TABLA_VENTAS values
		(@codigo, @detalle, @movimiento, @precio,
			@renglon, @ganancia)

		set @renglon = @renglon + 1

		fetch next from c_venta into @codigo, @detalle,
			@movimiento, @precio, @ganancia
	end

	close c_venta
	deallocate c_venta
end
go

--Prueba
select Item_Factura.item_producto, count(*), 
	SUM(Item_Factura.item_cantidad*Item_Factura.item_precio)
from Item_Factura
	join Factura on Item_Factura.item_tipo = Factura.fact_tipo
		and Item_Factura.item_sucursal = Factura.fact_sucursal
		and Item_Factura.item_numero = Factura.fact_numero
	where Item_Factura.item_producto = '00001415'
		and Factura.fact_fecha between '2012-01-01'
			and '2012-06-01'
	group by Item_Factura.item_producto

exec PR_COMPLETAR_VENTAS '2012-01-01', '2012-06-01'

select * from TABLA_VENTAS
	where venta_codigo = '00001415'

if OBJECT_ID('TABLA_VENTAS') is not null
	drop table TABLA_VENTAS
go

--Ejercicio 8
if OBJECT_ID('DIF_PRECIOS') is not null
	drop table DIF_PRECIOS
go

create table DIF_PRECIOS (
	dif_codigo char(8),
	dif_detalle char(50),
	dif_cantidad decimal(12,2),
	dif_precio decimal(12,2),
	dif_precio_facturado decimal(12,2)
)

if OBJECT_ID('PR_DIF_PRECIOS') is not null
	drop procedure PR_DIF_PRECIOS
go

create procedure PR_DIF_PRECIOS
as
begin
	insert into DIF_PRECIOS
	select Producto.prod_codigo, Producto.prod_detalle,
		COUNT(Composicion.comp_componente), 
		(select sum(Producto.prod_precio)
		from Producto P1
			join Composicion C1 on P1.prod_codigo = C1.comp_componente
		where Composicion.comp_componente = P1.prod_codigo
			and Producto.prod_codigo = C1.comp_producto
		/*group by Composicion.comp_producto, Composicion.comp_componente*/),
		Producto.prod_precio
	from Producto
		join Composicion on Composicion.comp_producto = Producto.prod_codigo
	where (select sum(Producto.prod_precio)
		from Producto
		where Producto.prod_codigo = Composicion.comp_componente
		group by Producto.prod_codigo, Producto.prod_precio) != Producto.prod_precio
	group by Producto.prod_codigo, Producto.prod_detalle, Composicion.comp_componente,
		Producto.prod_precio
	
end
go

--Prueba 1
SELECT *
FROM Producto
WHERE prod_codigo = '00001707'

exec PR_DIF_PRECIOS

select * from DIF_PRECIOS


-- Ejercicio 9
--Too difficult

--Ejercicio 10
if OBJECT_ID('TR_BORRAR_ARTICULO') is not null
	drop trigger TR_BORRAR_ARTICULO
go

create trigger TR_BORRAR_ARTICULO
on Producto instead of delete
as
begin
	declare @producto char(8)

	declare c_producto cursor for
		select prod_codigo from deleted

	open c_producto
	fetch next from c_producto into @producto

	while @@FETCH_STATUS = 0
	begin 
		declare @stock decimal(12,2)

		set @stock = (select STOCK.stoc_cantidad
			from Producto
				join STOCK on STOCK.stoc_producto = Producto.prod_codigo
			where Producto.prod_codigo = @producto)

		if @stock <= 0
			delete from Producto where prod_codigo = @producto
		else 
			raiserror('No se puede borrar el producto porque hay stock', 16, 1, @producto)

		fetch next from c_producto into @producto

	end
	
	close c_producto
	deallocate c_producto

end 
go

--Prueba 1

DELETE FROM Producto
WHERE prod_codigo = '00010417'

SELECT * 
FROM Producto
WHERE prod_codigo = '00010417'

--Prueba 2
INSERT INTO Producto VALUES('99999999', 'PRUEBA', 0.1, '001', '0001', 1)
INSERT INTO STOCK VALUES(0, 0, 100, NULL, NULL, '99999999', '00')

SELECT * 
FROM Producto
WHERE prod_codigo = '99999999'

SELECT * 
FROM STOCK
WHERE stoc_producto = '99999999'
AND stoc_deposito = '00'

ALTER TABLE STOCK NOCHECK CONSTRAINT R_11

DELETE FROM Producto
WHERE prod_codigo = '99999999'

DELETE FROM STOCK
WHERE stoc_producto = '99999999'
AND stoc_deposito = '00'

--Ejercicio 11
if OBJECT_ID('EMPL_A_CARGO') is not null
	drop function EMPL_A_CARGO
go

create function EMPL_A_CARGO(@empleado numeric(6,0))
	returns int
as
begin
	declare @cantidadEmpleados int

	set @cantidadEmpleados = (select isnull(SUM(dbo.EMPL_A_CARGO(E2.empl_codigo)+ 1), 0)
		from Empleado E1
			join Empleado E2 on E2.empl_jefe = E1.empl_codigo
		where E1.empl_codigo = @empleado
			and E2.empl_codigo > E1.empl_jefe)
	
	return @cantidadEmpleados
end
go

--Prueba 1
SELECT DBO.EMPL_A_CARGO(1)
select DBO.EMPL_A_CARGO(2)
select DBO.EMPL_A_CARGO(6)

--Ejercicio 12
if OBJECT_ID('TR_CONTROLAR_COMPOSICION') is not null
	drop trigger TR_CONTROLAR_COMPOSICION
go

create trigger TR_CONTROLAR_COMPOSICION
	on Composicion instead of insert
as
begin
	declare @componente char(8)
	declare @producto char(8)
	
	declare c_composicion cursor for
		select inserted.comp_componente, inserted.comp_producto
		from inserted
	
	open c_composicion
	fetch next from c_composicion into @componente, @producto

	while @@FETCH_STATUS = 0
	begin 
		if @componente != @producto
		begin
			insert into Composicion
			select * from inserted
			where inserted.comp_producto = @producto
				and inserted.comp_componente = @componente
		end
		else
			raiserror('El producto %s no se puede insertar', 16, 1, @producto)

	fetch next from c_composicion into @componente, @producto
	end

	close c_composicion
	deallocate c_composicion

end

--Prueba 1
INSERT INTO Composicion VALUES (2, '00001707', '00001707')

INSERT INTO Composicion VALUES (2, '00001707', '00001708')

DELETE FROM Composicion 
WHERE comp_producto = '00001707' 
AND comp_componente = '00001708'

--Ejercicio 13
if OBJECT_ID('CALCULAR_SALARIO') is not null
	drop function CALCULAR_SALARIO
go

create function CALCULAR_SALARIO (@empleado numeric(6,0))
	returns decimal(12,2)
as
begin
	declare @salarioEmpleado decimal(12,2)

	set @salarioEmpleado = isnull((select sum(dbo.CALCULAR_SALARIO(Empleado.empl_codigo) + Empleado.empl_salario)
		from Empleado 
		where Empleado.empl_jefe = @empleado),0)

	return @salarioEmpleado
end
go

if OBJECT_ID('TR_SALARIO') is not null
	drop trigger TR_SALARIO
go

create trigger TR_SALARIO
	on Empleado instead of update
as 
begin
	declare c_empleado cursor for
		select deleted.empl_codigo, deleted.empl_salario
			from deleted

	declare @empleado numeric(6,0)
	declare @salarioEmpleado decimal(12,2)

	open c_empleado

	fetch next from c_empleado into @empleado, @salarioEmpleado

	while @@FETCH_STATUS = 0
	begin

		if (@salarioEmpleado < 0.2*dbo.CALCULAR_SALARIO(@empleado)) or
			(select COUNT(*) from Empleado where Empleado.empl_jefe = @empleado) = 0
		begin
			update Empleado
			set Empleado.empl_salario = @salarioEmpleado
			where Empleado.empl_codigo = @empleado
		end
		else
			raiserror('El salario es demasiado alto', 16, 1, @Empleado)

		fetch next from c_empleado into @empleado, @salarioEmpleado

	end

	close c_empleado
	deallocate c_empleado
			
end
go

--Prueba 1
SELECT SUM(empl_salario) 
FROM Empleado
WHERE empl_jefe = 3

UPDATE Empleado
SET empl_salario = 1
WHERE empl_codigo = 3

UPDATE Empleado
SET empl_salario = 8741
WHERE empl_codigo = 3

