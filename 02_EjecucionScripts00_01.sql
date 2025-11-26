/*
Enunciado: ejecucion de los scripts para la importacion,
transformacion y carga de los datos.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 03_EjecucionScripts00_01.sql
Proposito: Ejecutables de los SP de importacion.
Script a ejecutar antes: 01_SPImportacionDatos.sql
*/

/* ============================ Ejecución con rutas locales ============================ */
USE Com5600G05
GO

DECLARE @ruta VARCHAR(200) = 'C:\SQL_SERVER_IMPORTS'

EXEC LogicaBD.sp_InsertaConsorcioProveedor
	@rutaArchivo = @ruta,
	@nombreArchivo = 'datos varios.xlsx';

EXEC LogicaBD.sp_InsertarUnidadesFuncionales
  @rutaArchivo = @ruta,
  @nombreArchivo = 'UF por consorcio.txt'

EXEC LogicaBD.sp_ImportarInquilinosPropietarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-UF.csv';

EXEC LogicaBD.sp_ImportarDatosInquilinos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-datos.csv';

EXEC LogicaBD.sp_ImportarGastosOrdinarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Servicios.Servicios.json';

EXEC LogicaBD.sp_GenerarExpensa;

EXEC LogicaBD.sp_GenerarExpensaPorMes @mes = 11

EXEC LogicaBD.sp_ImportarPagos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'pagos_consorcios.csv';

EXEC LogicaBD.sp_GenerarDetalles

SELECT * FROM Administracion.Consorcio
SELECT * FROM Infraestructura.UnidadFuncional
SELECT * FROM Personas.Persona
SELECT * FROM Personas.PersonaEnUF
SELECT * FROM Gastos.GastoOrdinario
SELECT * FROM Gastos.GastoExtraordinario
SELECT * FROM Gastos.Expensa
SELECT * FROM Gastos.DetalleExpensa
SELECT * FROM Gastos.EnvioExpensa
SELECT * FROM Finanzas.Pagos
