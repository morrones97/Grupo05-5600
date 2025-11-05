USE Grupo05_5600
GO

/* FUNCIONES COMUNES A TODOS LOS PROCEDURES */
IF OBJECT_ID('LogicaNormalizacion.fn_NormalizarNombreArchivoCSV','FN') IS NOT NULL
BEGIN
    DROP FUNCTION LogicaNormalizacion.fn_NormalizarNombreArchivoCSV
END
GO
CREATE FUNCTION LogicaNormalizacion.fn_NormalizarNombreArchivoCSV
(
    @nombreArchivo VARCHAR(100),
    @extension VARCHAR(5) 
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @archivo VARCHAR(100)
    DECLARE @nom VARCHAR(100)
    IF LOWER(@nombreArchivo) LIKE '%.'+LOWER(LTRIM(RTRIM(@extension)))
    BEGIN
        SET @archivo = @nombreArchivo
    END
    ELSE
    BEGIN
        IF LOWER(@nombreArchivo) LIKE '%.%'
        BEGIN
            SET @archivo = ''
        END
        ELSE
        BEGIN
            SET @archivo = @nombreArchivo + '.'+LOWER(LTRIM(RTRIM(@extension)))
        END
    END

    RETURN @archivo
END
GO

IF OBJECT_ID('LogicaNormalizacion.fn_NormalizarRutaArchivo','FN') IS NOT NULL
BEGIN
    DROP FUNCTION LogicaNormalizacion.fn_NormalizarRutaArchivo
END
GO
CREATE FUNCTION LogicaNormalizacion.fn_NormalizarRutaArchivo
( @rutaArchivo VARCHAR(100) )
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @ruta VARCHAR(100)
    IF RIGHT(LTRIM(RTRIM(@rutaArchivo)),1) <> '\'
    BEGIN
        SET @ruta = @rutaArchivo + '\'
    END
    ELSE
    BEGIN
        SET @ruta = @rutaArchivo
    END

    RETURN @ruta
END
GO

IF OBJECT_ID('LogicaNormalizacion.fn_NumeroMes','FN') IS NOT NULL
BEGIN
    DROP FUNCTION LogicaNormalizacion.fn_NumeroMes
END
GO
CREATE FUNCTION LogicaNormalizacion.fn_NumeroMes
( @mes VARCHAR(15) )
RETURNS INT
AS
BEGIN
    DECLARE @numeroMes INT

    SET @numeroMes = CASE 
        WHEN LOWER(@mes) = 'enero' THEN 1
        WHEN LOWER(@mes) = 'febrero' THEN 2
        WHEN LOWER(@mes) = 'marzo' THEN 3
        WHEN LOWER(@mes) = 'abril' THEN 4
        WHEN LOWER(@mes) = 'mayo' THEN 5
        WHEN LOWER(@mes) = 'junio' THEN 6
        WHEN LOWER(@mes) = 'julio' THEN 7
        WHEN LOWER(@mes) = 'agosto' THEN 8
        WHEN LOWER(@mes) = 'septiembre' THEN 9
        WHEN LOWER(@mes) = 'octubre' THEN 10
        WHEN LOWER(@mes) = 'noviembre' THEN 11
        WHEN LOWER(@mes) = 'diciembre' THEN 12
        ELSE NULL
    END

    RETURN @numeroMes
END
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR CONSORCIOS */
IF OBJECT_ID('sp_InsertarEnConsorcio','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_InsertarEnConsorcio
END
GO

CREATE PROCEDURE sp_InsertarEnConsorcio 
@direccion VARCHAR(100),
@nombre VARCHAR(100)
AS
BEGIN
    DECLARE @idEdificio INT
    SET @idEdificio = ( SELECT TOP 1 id FROM Infraestructura.Edificio WHERE direccion = @direccion)
    IF @idEdificio IS NOT NULL AND NOT EXISTS (
        SELECT 1 
        FROM Administracion.Consorcio 
        WHERE idEdificio = @idEdificio
    )
    BEGIN
        INSERT INTO Administracion.Consorcio (nombre, idEdificio) VALUES (@nombre, @idEdificio)
        PRINT 'Consorcio ' + @nombre + ' insertado.'
    END
END
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR EDIFCIOS Y CONSORCIOS */
IF OBJECT_ID('sp_ImportarConsorciosYEdificios','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_ImportarConsorciosYEdificios
END
GO

CREATE PROCEDURE sp_ImportarConsorciosYEdificios
AS
BEGIN
    INSERT INTO Infraestructura.Edificio (direccion, metrosTotales) VALUES
        ('Belgrano 3344', 1281),
        ('Callao 1122', 914),
        ('Santa Fe 910', 784),
        ('Corrientes 5678', 1316),
        ('Rivadavia 1234', 1691)

    PRINT 'Edificios Insertados'
    
    EXEC sp_InsertarEnConsorcio @direccion='Belgrano 3344', @nombre='Azcuenaga'
    EXEC sp_InsertarEnConsorcio @direccion='Callao 1122', @nombre='Alzaga'
    EXEC sp_InsertarEnConsorcio @direccion='Santa Fe 910', @nombre='Alberdi'
    EXEC sp_InsertarEnConsorcio @direccion='Corrientes 5678', @nombre='Unzue'
    EXEC sp_InsertarEnConsorcio @direccion='Rivadavia 1234', @nombre='Pereyra Iraola'
END
GO

EXEC sp_ImportarConsorciosYEdificios
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR EN TABLA TEMPORAL AUXILIAR DATOS DE INIQUILINOS/PROPIETARIOS Y SUS UFs*/
IF OBJECT_ID('sp_ImportarInquilinosPropietarios','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_ImportarInquilinosPropietarios
    IF OBJECT_ID('tempdb..#temporalInquilinosPropietariosCSV') IS NOT NULL
    BEGIN
        DROP TABLE #temporalInquilinosPropietariosCSV
    END
END
GO

-- Creo tabla temporal
CREATE TABLE #temporalInquilinosPropietariosCSV (
    cvu VARCHAR(100),
    consorcio VARCHAR(100),
    nroUF VARCHAR(5),
    piso VARCHAR(5),
    dpto VARCHAR(5)
)
GO

CREATE PROCEDURE sp_ImportarInquilinosPropietarios
@rutaArchivoInquilinosPropietarios VARCHAR(100),
@nombreArchivoInquilinosPropietarios VARCHAR(100)
AS
BEGIN
    DECLARE @ruta VARCHAR(100)
    DECLARE @archivo VARCHAR(100)
    
    -- Normalizo la ruta y el archivo checkeando que sea un csv y que la ruta sea con \ final
    SET @archivo = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivoInquilinosPropietarios, 'csv')
    IF(@archivo = '')
    BEGIN 
        PRINT 'El archivo no es un archivo .csv'
        RETURN
    END

    SET @ruta = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivoInquilinosPropietarios)

    DECLARE @rutaArchivoCompleto VARCHAR(200)
    SET @rutaArchivoCompleto = @ruta + @archivo
    PRINT @rutaArchivoCompleto

    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #temporalInquilinosPropietariosCSV
        FROM ''' + @rutaArchivoCompleto + '''
        WITH (
            FIELDTERMINATOR = ''|'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    
    EXEC sp_executesql @sql;
END
GO

EXEC sp_ImportarInquilinosPropietarios 
    @rutaArchivoInquilinosPropietarios = 'H:\Users\Morrones\Downloads\consorcios', 
    @nombreArchivoInquilinosPropietarios='Inquilino-propietarios-UF.csv'
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR DATOS DE UNIDADES FUNCIONAES*/
IF OBJECT_ID('sp_InsertarUnidadesFuncionales','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_InsertarUnidadesFuncionales
END
GO

CREATE PROCEDURE sp_InsertarUnidadesFuncionales
@rutaArchivoUniadesFuncionales VARCHAR(200),
@nombreArchivoUnidadesFuncionales VARCHAR(200)
AS
BEGIN
    CREATE TABLE #temporalUF (
        nombreConsorcio VARCHAR(100),
        uF VARCHAR(10),
        piso VARCHAR(10),
        dpto VARCHAR(10),
        coeficiente VARCHAR(10),
        m2UF INT,
        baulera CHAR(2),
        cochera CHAR(2),
        m2Baulera INT,
        m2Cochera INT
    )  

    DECLARE @ruta VARCHAR(100)
    DECLARE @archivo VARCHAR(100)

    SET @archivo = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivoUnidadesFuncionales, 'txt')
    IF(@archivo = '')
    BEGIN 
        PRINT 'El archivo no es un archivo .txt'
        RETURN
    END

    SET @ruta = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivoUniadesFuncionales)

    DECLARE @rutaArchivoCompleto VARCHAR(200)
    SET @rutaArchivoCompleto = @ruta + @archivo
    PRINT @rutaArchivoCompleto

    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #temporalUF
        FROM ''' + @rutaArchivoCompleto + '''
        WITH (
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    
    EXEC sp_executesql @sql;

    DELETE FROM #temporalUF WHERE nombreConsorcio IS NULL

    DELETE tUF
    FROM #temporalUF AS tUF
    INNER JOIN Administracion.Consorcio AS c
        ON tUF.nombreConsorcio = c.nombre
    INNER JOIN Infraestructura.UnidadFuncional AS uf
        ON tUF.piso = uf.piso
        AND tUF.dpto = uf.departamento
        AND c.idEdificio = uf.idEdificio;

    -- Inserto haciendo JOIN con Consorcio para traerme el idEdificio y con la temporal #temporalInquilinosPropietariosCSV para traer el CV
    INSERT INTO Infraestructura.UnidadFuncional (piso, departamento, dimension, m2Cochera, m2Baulera, porcentajeParticipacion, cbu_cvu, idEdificio)
    SELECT 
        tUF.piso,
        tUF.dpto, 
        CAST(tUF.m2UF AS DECIMAL(5,2)) as m2, 
        tUF.m2Cochera,
        tUF.m2Baulera,
        CAST(REPLACE(tUF.coeficiente, ',', '.') AS DECIMAL(4,2)) as coeficiente,
        tPI.cvu as claveBancaria, 
        c.idEdificio
    FROM #temporalUF as tUF LEFT JOIN Administracion.Consorcio c 
        ON tUF.nombreConsorcio = c.nombre
    LEFT JOIN #temporalInquilinosPropietariosCSV as tPI
        ON tUF.nombreConsorcio = tPI.consorcio AND tUF.piso = tPI.piso AND tUF.dpto = tPI.dpto
END
GO

EXEC sp_InsertarUnidadesFuncionales
    @rutaArchivoUniadesFuncionales = 'H:\Users\Morrones\Downloads\consorcios',
    @nombreArchivoUnidadesFuncionales = 'UF por consorcio.txt'
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR DATOS DE PERSONAS */
IF OBJECT_ID('sp_ImportarDatosInquilinos','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_ImportarDatosInquilinos
    DELETE FROM Personas.Persona WHERE dni >= 1
END
GO
-- DNI DUPLICADOS? Los elimino por ahora, Emails con espacios los elimino
CREATE PROCEDURE sp_ImportarDatosInquilinos
@nombreArchivo VARCHAR(100),
@rutaArchivo VARCHAR(100)
AS
BEGIN
    DECLARE @ruta VARCHAR(100)
    DECLARE @archivo VARCHAR(100)

    -- Normalizo la ruta y el archivo checkeando que sea un csv y que la ruta sea con \ final
    SET @archivo = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv')
    IF(@archivo = '')
    BEGIN 
        PRINT 'El archivo no es un archivo .csv'
        RETURN
    END
    SET @ruta = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo)


    -- Creo tabla temporal
    IF OBJECT_ID('tempdb..#temporalInquilinosCSV') IS NOT NULL
    BEGIN
        DROP TABLE #temporalInquilinosCSV;
    END

    CREATE TABLE #temporalInquilinosCSV (
        nombre VARCHAR(100),
        apellido VARCHAR(100),
        dni VARCHAR(100),
        email VARCHAR(100),
        telefono VARCHAR(100),
        cvbu VARCHAR(100),
        inquilino VARCHAR(100)
    )  

    DECLARE @rutaArchivoCompleto VARCHAR(200)
    SET @rutaArchivoCompleto = @ruta + @archivo
    
    -- Leo archivo
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #temporalInquilinosCSV
        FROM ''' + @rutaArchivoCompleto + '''
        WITH (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';

    EXEC sp_executesql @sql;

    -- Elimino datos NULL, normalizo datos y elimino DNI duplicados
    DELETE FROM #temporalInquilinosCSV 
    WHERE nombre IS NULL OR apellido IS NULL OR dni IS NULL OR cvbu IS NULL OR inquilino IS NULL

    UPDATE #temporalInquilinosCSV
    SET 
        nombre = UPPER(LEFT(LTRIM(RTRIM(nombre)),1)) + LOWER(SUBSTRING(LTRIM(RTRIM(nombre)),2,LEN(nombre))),
        apellido = UPPER(LEFT(LTRIM(RTRIM(apellido)),1)) + LOWER(SUBSTRING(LTRIM(RTRIM(apellido)),2,LEN(apellido))),
        dni = LTRIM(RTRIM(dni)),
        email = LTRIM(RTRIM(email)),
        telefono = LTRIM(RTRIM(telefono)),
        cvbu = LTRIM(RTRIM(cvbu)),
        inquilino = LTRIM(RTRIM(inquilino));
    
    WITH dni_repetidos AS
    (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY dni ORDER BY dni) AS filas
        FROM #temporalInquilinosCSV
    )
    DELETE FROM dni_repetidos WHERE filas > 1;

    UPDATE #temporalInquilinosCSV
    SET email = NULL
    WHERE email LIKE '% %'

    -- Inserto datos en Persona
    INSERT INTO Personas.Persona (dni, nombre, apellido, email, telefono, cbu_cvu)
    SELECT dni, nombre, apellido, email, telefono, cvbu 
    FROM #temporalInquilinosCSV


    INSERT INTO Personas.PersonaEnUF (dniPersona, idUF, inquilino, propietario, fechaDesde, fechaHasta)
    SELECT p.dni, uf.id, tI.inquilino, 1, GETDATE(), NULL
    FROM Personas.Persona as p RIGHT JOIN #temporalInquilinosPropietariosCSV as tIP
        ON p.cbu_cvu = tIP.cvu
    RIGHT JOIN Infraestructura.UnidadFuncional as uf
        ON uf.cbu_cvu = p.cbu_cvu
    RIGHT JOIN #temporalInquilinosCSV as tI
        ON tI.dni = p.dni
END
GO

EXEC sp_ImportarDatosInquilinos 
    @nombreArchivo = 'Inquilino-propietarios-datos.csv', 
    @rutaArchivo = 'H:\Users\Morrones\Downloads\consorcios'
GO

/* PROCEDURE PARA IMPORTAR E INSERTAR DATOS DE GASTOS ORDINARIOS */
IF OBJECT_ID('sp_ImportarGastosOrdinarios','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_ImportarGastosOrdinarios
END
GO

CREATE PROCEDURE sp_ImportarGastosOrdinarios 
AS
BEGIN
    CREATE TABLE #datosGastosOrdinarios (
        id varchar(100),
        consorcio varchar(100),
        mes varchar(15),
        bancarios varchar(100),
        limpieza varchar(100),
        administracion varchar(100),
        seguros varchar(100),
        generales varchar(100),
        agua varchar(100),
        luz varchar(100),
        internet varchar(100)
    )

    CREATE TABLE #datosProveedores (
        tipoGasto varchar(100),
        empresa varchar(100),
        cuentaBancaria varchar(100),
        consorcio VARCHAR(100)
    )

    INSERT INTO #datosProveedores (tipoGasto, empresa, cuentaBancaria, consorcio)
    VALUES
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Azcuenaga'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Azcuenaga'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 195329', 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4363152506', 'Azcuenaga'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limptech', 'Azcuenaga'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Alzaga'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Alzaga'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Alzaga'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 174329', 'Alzaga'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4363125506', 'Alzaga'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limpi AR', 'Alzaga'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Alberdi'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 215329', 'Alberdi'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4463152506', 'Alberdi'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Clean SA', 'Alberdi'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Unzue'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Unzue'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Unzue'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 544329', 'Unzue'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4447852506', 'Unzue'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limpieza General SA', 'Unzue'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Pereyra Iraola'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Pereyra Iraola'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Pereyra Iraola'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 5147329', 'Pereyra Iraola'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 445742506', 'Pereyra Iraola'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limptech', 'Pereyra Iraola')

    INSERT INTO #datosGastosOrdinarios(id,consorcio,mes,bancarios,limpieza,administracion,seguros,generales, agua, luz, internet)
    SELECT JSON_VALUE(_id, '$."$oid"') AS id, consorcio, mes, bancarios, limpieza, administracion, seguros, generales, agua, luz, internet
    FROM OPENROWSET (BULK 'H:\Users\Morrones\Downloads\consorcios\Servicios.Servicios.json', SINGLE_CLOB) AS ordinariosJSON
    CROSS APPLY OPENJSON(ordinariosJSON.BulkColumn, '$') 
    WITH ( 
 	    _id NVARCHAR(MAX) as JSON,
        consorcio varchar(100) '$."Nombre del consorcio"',
        mes varchar(15) '$.Mes',
        bancarios varchar(100) '$.BANCARIOS',
        limpieza varchar(100) '$.LIMPIEZA',
        administracion varchar(100) '$.ADMINISTRACION',
        seguros varchar(100) '$.SEGUROS',
        generales varchar(100) '$."GASTOS GENERALES"',
        agua varchar(100) '$."SERVICIOS PUBLICOS-Agua"',
        luz varchar(100) '$."SERVICIOS PUBLICOS-Luz"',
        internet varchar(100) '$."SERVICIOS PUBLICOS-Internet"'
    )

    DELETE FROM #datosGastosOrdinarios WHERE consorcio IS NULL

    UPDATE #datosGastosOrdinarios
    SET 
        consorcio = ( SELECT idEdificio FROM Administracion.Consorcio c WHERE c.nombre = #datosGastosOrdinarios.consorcio),
        mes = LogicaNormalizacion.fn_NumeroMes(mes),
        bancarios = REPLACE(bancarios,'.',''),
        limpieza = REPLACE(limpieza,'.',''),
        administracion = REPLACE(administracion,'.',''),
        seguros = REPLACE(seguros,'.',''),
        generales = REPLACE(generales,'.',''),
        agua = REPLACE(agua,'.',''),
        luz = REPLACE(luz,'.',''),
        internet = REPLACE(internet,'.','')
    
    UPDATE #datosGastosOrdinarios
    SET 
        bancarios = REPLACE(LTRIM(RTRIM(bancarios)),',',''),
        limpieza = REPLACE(LTRIM(RTRIM(limpieza)),',',''),
        administracion = REPLACE(LTRIM(RTRIM(administracion)),',',''),
        seguros = REPLACE(LTRIM(RTRIM(seguros)),',',''),
        generales = REPLACE(LTRIM(RTRIM(generales)),',',''),
        agua = REPLACE(LTRIM(RTRIM(agua)),',',''),
        luz = REPLACE(LTRIM(RTRIM(luz)),',',''),
        internet = REPLACE(LTRIM(RTRIM(internet)),',','')

    UPDATE #datosProveedores
    
    SET consorcio = (SELECT id FROM Administracion.Consorcio WHERE nombre = #datosProveedores.consorcio)
    DECLARE @contador INT
    DECLARE @cantidadRegistros INT
    SET @cantidadRegistros = (SELECT COUNT(*) FROM #datosGastosOrdinarios)
    SET @contador = 0
    DECLARE @numeroFactura INT
    SET @numeroFactura = ISNULL((SELECT MAX(nroFactura) FROM Gastos.GastoOrdinario), 999) + 1
    WHILE @contador < @cantidadRegistros
    BEGIN
        DECLARE @gastoBan DECIMAL(10,2)
        DECLARE @gastoLim DECIMAL (10,2)
        DECLARE @gastoAdm DECIMAL (10,2)
        DECLARE @gastoSeg DECIMAL (10,2)
        DECLARE @gastoGen DECIMAL (10,2)
        DECLARE @gastoAgu DECIMAL (10,2)
        DECLARE @gastoLuz DECIMAL (10,2)
        DECLARE @gastoNet DECIMAL (10,2)
        DECLARE @mes INT
        DECLARE @idConsorcio INT
        DECLARE @empresa VARCHAR(100)

        SET @gastoBan = CAST((SELECT bancarios  FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY) AS DECIMAL(10,2))
        SET @gastoLim = CAST((SELECT limpieza FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoAdm = CAST((SELECT administracion FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoSeg = CAST((SELECT seguros FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoGen = CAST((SELECT generales FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoAgu = CAST((SELECT agua FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoLuz = CAST((SELECT luz FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @gastoNet = CAST((SELECT internet FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        SET @mes = (SELECT mes FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)
        SET @idConsorcio = (SELECT consorcio FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)
        
        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%BANCARIOS%')
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Mantenimiento de cuenta bancaria', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoBan/100, NULL, '', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%LIMPIEZA%')
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Limpieza', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLim/100, NULL, '', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%ADMINISTRACION%')
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Administracion/Honorarios', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoAdm/100, NULL, '', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%SEGUROS%')
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Seguro', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoSeg/100, NULL, '', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = NULL
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Generales', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoGen/100, NULL, '', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND empresa LIKE '%AYSA%')
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoAgu/100, NULL, 'Agua', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa LIKE '%EDENOR%' OR empresa LIKE '%EDESUR%'))
        INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
        VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLuz/100, NULL, 'Luz', @idConsorcio)
        SET @numeroFactura = @numeroFactura + 1

        IF @gastoNet IS NOT NULL
        BEGIN
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa NOT LIKE '%EDENOR%' AND empresa NOT LIKE '%EDESUR%' AND empresa NOT LIKE '%AYSA%'))
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, sueldoEmpleadoDomestico, detalle, idConsorcio)
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLuz/100, NULL, 'Luz', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        SET @contador = @contador + 1
     END

    INSERT INTO Gastos.Expensa 
        (periodo, totalGastoOrdinario, totalGastoExtraordinario, primerVencimiento, segundoVencimiento, idConsorcio)
    SELECT 
        CONCAT(RIGHT('0' + CAST(gOrd.mes AS VARCHAR(2)),2), CAST(YEAR(GETDATE()) AS VARCHAR(4))) AS Periodo, 
        ISNULL(sum(gOrd.importeFactura),0), 
        ISNULL(sum(gEOrd.importe),0), 
        CAST(GETDATE() AS DATE),
        CAST(DATEADD(DAY, 7, GETDATE()) AS DATE),
        gOrd.idConsorcio  
    FROM Gastos.GastoOrdinario as gOrd LEFT JOIN Gastos.GastoExtraordinario as gEOrd
        ON gEord.mes = gOrd.mes AND gEOrd.idConsorcio = gOrd.idConsorcio
    GROUP BY gOrd.mes, gOrd.idConsorcio
END
GO

EXEC sp_ImportarGastosOrdinarios

/* PROCEDURE PARA IMPORTAR E INSERTAR DATOS DE PAGOS Y CREAR EXPENSAS */
IF OBJECT_ID('sp_ImportarPagos','P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_ImportarPagos
END
GO

CREATE PROCEDURE sp_ImportarPagos
AS
BEGIN
    CREATE TABLE #temporalPagos (
        id CHAR(5),
        fecha VARCHAR(10),
        claveBancaria VARCHAR(22),
        monto VARCHAR(20)
    )

    BULK INSERT #temporalPagos
    FROM 'H:\Users\Morrones\Downloads\consorcios\pagos_consorcios.csv'
    WITH (
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n',
        CODEPAGE = '65001',
        FIRSTROW = 2
    )

    DELETE FROM #temporalPagos WHERE monto IS NULL OR fecha IS NULL OR claveBancaria IS NULL
    
    UPDATE #temporalPagos
    SET 
        id = LTRIM(RTRIM(id)),
        claveBancaria =  LTRIM(RTRIM(claveBancaria)),
        monto = REPLACE(LTRIM(RTRIM(monto)),'$','')

    UPDATE #temporalPagos
    SET monto = REPLACE(monto, '.','')

    INSERT INTO Finanzas.Pagos
        (id,
        fecha,
        monto,
        cuentaBancaria,
        valido,
        idExpensa,
        idUF) 
    SELECT 
        CAST(tP.id AS INT), 
        CONVERT(DATE, LTRIM(RTRIM(fecha)), 103), 
        CAST(tP.monto AS DECIMAL(10,2)), 
        tP.claveBancaria, 
        1, 
        e.id, 
        uf.id
    FROM #temporalPagos as tP
    LEFT JOIN Infraestructura.UnidadFuncional as uf
        ON uf.cbu_cvu = tP.claveBancaria
    LEFT JOIN Infraestructura.Edificio as ed
        ON uf.idEdificio = ed.id
    LEFT JOIN Administracion.Consorcio as c
        ON ed.id = c.idEdificio
    LEFT JOIN Gastos.Expensa as e
        ON c.id = e.id
    WHERE uf.id IS NOT NULL

    -- Habria que agregar una tabla para los gastos no validos porque no podrian ponerse aca porque no tiene idExpensa e idUF a la que relacionarse
END
GO

EXEC sp_ImportarPagos
GO
