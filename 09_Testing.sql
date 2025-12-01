/*
Enunciado: testing que incluye agreagacion de nuevos 
datos a la base, y generacion de una expensa especifica
a partir de esos nuevos datos.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 09_Testing.sql
Proposito: Test de procedures y generacion de expensas.
Script a ejecutar antes: Todos los anteriores.
*/

USE Com5600G05;

/*====================================================================
                MODIFICAR TABLAS                        
====================================================================*/
-- Modificar solo dimensiones 
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @dimension = 60.00,
    @m2Cochera = 14.00,
    @m2Baulera = 4.00;

-- Modificar CBU/CVU (validación: 22 dígitos)
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 137,
    @cbu_cvu = '2044613354400000000000';

-- Modificar piso/departamento (requiere que no exista duplicado en el consorcio)
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @piso = '02',
    @departamento = 'B';

-- Modificar porcentaje de participación y reasignar a otro consorcio
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @porcentajeParticipacion = 2.50,
    @idConsorcio = 1;


/*====================================================================
                AGREGAR DATOS                        
====================================================================*/
	-- Alta de Consorcio
EXEC Administracion.sp_AgregarConsorcio 
    @nombre = 'ConsorcioDemo',
    @direccion = 'Av. Siempre Viva 742 5600-05',
    @metrosTotales = 5000.00;

-- Alta de Persona
EXEC Personas.sp_AgregarPersona 
    @dni='44613354',
    @nombre='Franco',
    @apellido='Ermasi',
    @email=NULL,
    @telefono=1131688005,
    @cbu_cvu=2044613354400000000000;

-- Alta de Unidad Funcional (usar un idConsorcio existente)
EXEC Infraestructura.sp_AgregarUnidadFuncional
    @piso = '01',
    @departamento = 'C',
    @dimension = 55.00,
    @m2Cochera = 12.00,
    @m2Baulera = 3.00,
    @porcentajeParticipacion = 2.20,
    @cbu_cvu = '2044613354400000000000',
    @idConsorcio = 6;

EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '02', @departamento = 'A', @dimension = 48.75, @m2Cochera = 10.50, @m2Baulera = 2.00, @porcentajeParticipacion = 1.85, @cbu_cvu = '2719034578123400000001', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '02', @departamento = 'B', @dimension = 62.30, @m2Cochera = 14.00, @m2Baulera = 3.50, @porcentajeParticipacion = 2.55, @cbu_cvu = '2719034578123400000002', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '03', @departamento = 'D', @dimension = 57.10, @m2Cochera = 11.00, @m2Baulera = 2.50, @porcentajeParticipacion = 2.10, @cbu_cvu = '2719034578123400000003', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '03', @departamento = 'E', @dimension = 71.80, @m2Cochera = 16.00, @m2Baulera = 4.00, @porcentajeParticipacion = 2.95, @cbu_cvu = '2719034578123400000004', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '04', @departamento = 'A', @dimension = 45.20, @m2Cochera = 0.00,  @m2Baulera = 1.80, @porcentajeParticipacion = 1.60, @cbu_cvu = '2719034578123400000005', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '04', @departamento = 'C', @dimension = 66.95, @m2Cochera = 12.50, @m2Baulera = 3.20, @porcentajeParticipacion = 2.70, @cbu_cvu = '2719034578123400000006', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '05', @departamento = 'B', @dimension = 59.40, @m2Cochera = 11.50, @m2Baulera = 2.70, @porcentajeParticipacion = 2.25, @cbu_cvu = '2719034578123400000007', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '05', @departamento = 'F', @dimension = 78.00, @m2Cochera = 18.00, @m2Baulera = 4.50, @porcentajeParticipacion = 3.10, @cbu_cvu = '2719034578123400000008', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '06', @departamento = 'A', @dimension = 52.60, @m2Cochera = 9.00,  @m2Baulera = 2.20, @porcentajeParticipacion = 1.95, @cbu_cvu = '2719034578123400000009', @idConsorcio = 6;
EXEC Infraestructura.sp_AgregarUnidadFuncional @piso = '06', @departamento = 'D', @dimension = 69.15, @m2Cochera = 15.00, @m2Baulera = 3.80, @porcentajeParticipacion = 2.85, @cbu_cvu = '2719034578123400000010', @idConsorcio = 6;

-- Alta de relación Persona en UF
EXEC Personas.sp_AgregarPersonaEnUF
    @dniPersona = '44613354',
    @idUF = 132,
    @inquilino = 0,
    @fechaDesde = '2025-11-07',
    @fechaHasta = NULL;

-- Alta de Gasto Ordinario
EXEC Gastos.sp_AgregarGastoOrdinario
    @mes = 11,
    @tipoGasto = 'Limpieza',
    @empresaPersona = 'Limpieza S.A.',
    @nroFactura = '1237',
    @importeFactura = 150000.00,
    @detalle = ' ',
    @idConsorcio = 6;

-- Alta de Gasto Extraordinario
EXEC Gastos.sp_AgregarGastoExtraordinario
    @mes = 11,
    @detalle = 'Reparacion de espejos',
    @importe = 800000.00,
    @formaPago = 'Total',
    @nroCuotaAPagar = '',
    @nroTotalCuotas = '',
    @idConsorcio = 6;

/*====================================================================
                GENERAR EXPENSA ESPECIFICA (MES)                      
====================================================================*/

EXEC LogicaBD.sp_GenerarExpensaPorMes @mes = 10
EXEC LogicaBD.sp_GenerarExpensaPorMes @mes = 11
EXEC LogicaBD.sp_GenerarDetalles

-- Alta de Pago 
EXEC Finanzas.sp_AgregarPago
    @fecha = '2025-11-15',
    @monto = 60050.00,
    @cuentaBancaria = '2044613354400000000000';

/*====================================================================
                VISUALIZAR TABLAS                        
====================================================================*/
SELECT * FROM Administracion.Consorcio
SELECT * FROM Infraestructura.UnidadFuncional
SELECT * FROM Personas.Persona
SELECT * FROM Personas.PersonaEnUF

SELECT idConsorcio, mes, SUM(importeFactura) as ImporteTotalExpensa FROM Gastos.GastoOrdinario
GROUP BY idConsorcio, mes

SELECT * FROM Gastos.GastoOrdinario

SELECT * FROM Gastos.GastoExtraordinario


SELECT idConsorcio,mes, SUM(importe) as ImporteTotal FROM Gastos.GastoExtraordinario
GROUP BY idConsorcio, mes

SELECT idConsorcio,mes, SUM(importeFactura) as ImporteTotal FROM Gastos.GastoOrdinario
GROUP BY idConsorcio, mes

SELECT * FROM Gastos.Expensa

SELECT * FROM Gastos.DetalleExpensa
order by idExpensa

SELECT * FROM Gastos.EnvioExpensa

SELECT * FROM Finanzas.Pagos
WHERE idUF = 1
ORDER BY fecha

SELECT iduf, sum(monto) as total FROM Finanzas.Pagos WHERE fecha like '2025-04-%' group by iduf order by iduf


/*====================================================================
                INFORMES                      
====================================================================*/
EXEC LogicaBD.sp_Informe01

EXEC LogicaBD.sp_Informe01 @mesInicio = 4, @mesFinal = 5, @nombreConsorcio = 'Azcuenaga', @piso = 'PB', @departamento = 'E'

EXEC LogicaBD.sp_Informe02

EXEC LogicaBD.sp_Informe03

EXEC LogicaBD.sp_Informe04 @nombreConsorcio = 'azcuenaga'

EXEC LogicaBD.sp_Informe05

EXEC LogicaBD.sp_Informe06


/*====================================================================
                PERMISOS USUARIOS                       
====================================================================*/
-- 1
EXECUTE AS USER = 'u_admin_general';
GO

-- Ok
EXEC Infraestructura.sp_ModificarUnidadFuncional  
	@idUF = 1,
    @dimension = 60.00,
    @m2Cochera = 14.00,
    @m2Baulera = 4.00;


EXEC LogicaBD.sp_Informe01
GO

REVERT;
GO

--2
EXECUTE AS USER = 'u_admin_bancario';
GO

-- Ok
EXEC LogicaBD.sp_Informe01;

-- Falla
EXEC Infraestructura.sp_ModificarUnidadFuncional
	@idUF = 1,
    @dimension = 60.00,
    @m2Cochera = 14.00,
    @m2Baulera = 4.00;
GO

REVERT;
GO

--3
EXECUTE AS USER = 'u_admin_general';
EXECUTE AS LOGIN = 'lg_banco';
EXECUTE AS USER = 'u_admin_operativo';
EXECUTE AS USER = 'u_sistemas';
REVERT;

DECLARE @ruta VARCHAR(200) = 'C:\SQL_SERVER_IMPORTS'
EXEC LogicaBD.sp_ImportarPagos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'pagos_consorcios.csv';




