USE Com5600G05
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe05
(
    @nombreConsorcio VARCHAR(100) = NULL,
    @periodoDesde CHAR(6) = NULL,
    @periodoHasta CHAR(6) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH propietarios AS (
        SELECT 
            p.idPersona,
            Personas.fn_DesencriptarNombre(p.idPersona) as [nombre],
            Personas.fn_DesencriptarApellido(p.idPersona) as [apellido],
            Personas.fn_DesencriptarDNI(p.idPersona) as [dni],
            Personas.fn_DesencriptarEmail(p.idPersona) as [email],
            Personas.fn_DesencriptarTelefono(p.idPersona) as [telefono],
            uf.id          AS idUF,
            c.id           AS idConsorcio,
            c.nombre       AS consorcio
        FROM Personas.PersonaEnUF peu
        INNER JOIN Personas.Persona p ON p.idPersona = peu.idPersona
        INNER JOIN Infraestructura.UnidadFuncional uf ON uf.id = peu.idUF
        INNER JOIN Administracion.Consorcio c ON c.id = uf.idConsorcio
        WHERE peu.inquilino = 0  -- solo propietarios
          AND peu.fechaHasta IS NULL -- relación activa
          AND (@nombreConsorcio IS NULL OR c.nombre = @nombreConsorcio)
    )
    SELECT TOP 3 
        pr.apellido,
        pr.nombre,
        pr.dni,
        pr.email,
        pr.telefono,
        SUM(CASE WHEN (d.deuda + d.intereses) > 0 THEN (d.deuda + d.intereses) ELSE 0 END) AS morosidad_total
    FROM propietarios pr
    INNER JOIN Gastos.DetalleExpensa d ON d.idUF = pr.idUF
    INNER JOIN Gastos.Expensa ex ON ex.id = d.idExpensa AND ex.idConsorcio = pr.idConsorcio
    WHERE (@periodoDesde IS NULL OR ex.periodo >= @periodoDesde)
      AND (@periodoHasta IS NULL OR ex.periodo <= @periodoHasta)
    GROUP BY pr.apellido, pr.nombre, pr.dni, pr.email, pr.telefono
    ORDER BY morosidad_total DESC
    FOR XML PATH('Propietario'), ELEMENTS, ROOT('Morosos')
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarDatosInquilinos
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo), 
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv')

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');

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
        cvu VARCHAR(100),
        inquilino char(1)
    );

    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #temporalInquilinosCSV
        FROM ''' + @rutaArchivoCompleto + N'''
        WITH (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';

    EXEC sp_executesql @sql;

    UPDATE #temporalInquilinosCSV
    SET nombre = CONCAT(UPPER(LEFT(LTRIM(RTRIM(nombre)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(nombre)),2,100))),
        apellido = CONCAT(UPPER(LEFT(LTRIM(RTRIM(apellido)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(apellido)),2,100))),
        dni = REPLACE(REPLACE(LTRIM(RTRIM(dni)),' ',''),'.',''),
        email = NULLIF(LOWER(LTRIM(RTRIM(email))), ''),
        telefono = NULLIF(LTRIM(RTRIM(telefono)), ''),
        cvu = NULLIF(LTRIM(RTRIM(cvu)), ''),
        inquilino = LTRIM(RTRIM(inquilino));

    DELETE FROM #temporalInquilinosCSV 
    WHERE nombre IS NULL OR apellido IS NULL OR dni IS NULL OR cvu IS NULL OR inquilino IS NULL 
        OR telefono LIKE '%[^0-9]%' OR LEN(telefono) <> 10 OR LEN(cvu) <> 22
        OR cvu LIKE '%[^0-9]%';
		
    ;WITH dni_repetidos AS
    (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY dni ORDER BY dni, email) AS filasDni
        FROM #temporalInquilinosCSV
    )
    DELETE FROM dni_repetidos WHERE filasDni > 1;

    ;WITH cvu_repetidos AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY cvu ORDER BY cvu, dni) as filasCvu
      FROM #temporalInquilinosCSV
    )
    DELETE FROM cvu_repetidos WHERE filasCvu > 1;

    ;WITH email_repetidos AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(LTRIM(RTRIM(email))) ORDER BY dni) filasEmail
      FROM #temporalInquilinosCSV
    )
    DELETE FROM email_repetidos WHERE filasEmail > 1;

	UPDATE #temporalInquilinosCSV
		SET 
			cvu = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(cvu,CHAR(13),''))), ' ', ''), '.', ''), CHAR(9), ''),
			dni = REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(dni,CHAR(13),''))), ' ', ''), '.', ''),
			email = LOWER(LTRIM(RTRIM(email)));

	DELETE FROM #temporalInquilinosCSV
		WHERE inquilino NOT IN ('0','1');

    INSERT INTO Personas.Persona (dni, nombre, apellido, email, telefono, cbu_cvu)
	SELECT S.dni, S.nombre, S.apellido, S.email, S.telefono, CAST(S.cvu AS CHAR(22))
	FROM #temporalInquilinosCSV S
	WHERE NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE Personas.fn_DesencriptarDNI(T.idPersona) = S.dni)
	  AND NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE Personas.fn_DesencriptarClaveBancaria(T.idPersona) = S.cvu)
	  AND (S.email IS NULL OR NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE Personas.fn_DesencriptarEmail(T.email) = LOWER(LTRIM(RTRIM(S.email)))));

    -- Materializamos los potenciales nuevos vínculos para reutilizarlos en múltiples sentencias
    IF OBJECT_ID('tempdb..#Nuevos') IS NOT NULL DROP TABLE #Nuevos;
    CREATE TABLE #Nuevos(
      idPersona INT,
      idUF INT,
      inquilino BIT
    );
    INSERT INTO #Nuevos(idPersona, idUF, inquilino)
    SELECT DISTINCT 
	  P.idPersona,
      UF.id,
      CAST(T.inquilino AS bit) AS inquilino
    FROM #temporalInquilinosCSV T
	JOIN Personas.Persona P ON Personas.fn_DesencriptarDNI(P.idPersona) = T.dni 
    JOIN Infraestructura.UnidadFuncional UF ON UF.cbu_cvu = T.cvu;

    -- Cerrar activo del mismo rol en la misma UF si es OTRO DNI
    UPDATE pe
      SET pe.fechaHasta = CASE 
                            WHEN CAST(GETDATE() AS DATE) > pe.fechaDesde 
                              THEN CAST(GETDATE() AS DATE)
                            ELSE DATEADD(DAY, 1, pe.fechaDesde) -- evita violar CK (>)
                          END
    FROM Personas.PersonaEnUF pe
    JOIN #Nuevos n
      ON n.idUF = pe.idUF
     AND n.inquilino = pe.inquilino
    WHERE pe.fechaHasta IS NULL
      AND pe.idPersona <> n.idPersona;

    -- Insertar solo si esa misma persona no está activa en ese rol/UF
    INSERT INTO Personas.PersonaEnUF (idPersona, idUF, inquilino, fechaDesde, fechaHasta)
    SELECT n.idPersona, n.idUF, n.inquilino, CAST(GETDATE() AS DATE), NULL
    FROM #Nuevos n
    WHERE NOT EXISTS (
      SELECT 1
      FROM Personas.PersonaEnUF x
      WHERE x.idUF = n.idUF
        AND x.inquilino = n.inquilino
        AND x.fechaHasta IS NULL
        AND x.idPersona = n.idPersona
    );

    DROP TABLE #Nuevos;

    EXEC Personas.sp_CifrarPersonas
END
GO


CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarPagos
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #temporalPagos (
        id CHAR(5),
        fecha VARCHAR(10),
        cvu VARCHAR(22),
        monto VARCHAR(50)
    );

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv');

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    DECLARE @rutaCompleta VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #temporalPagos
        FROM ''' + @rutaCompleta + N'''
        WITH (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    EXEC sp_executesql @sql;
    
    UPDATE #temporalPagos
        SET 
            id    = LTRIM(RTRIM(id)),
            fecha = LTRIM(RTRIM(fecha)),
            cvu   = LTRIM(RTRIM(cvu  )),
            monto = LogicaNormalizacion.fn_ToDecimal(monto);

	UPDATE #temporalPagos
        SET cvu = NULL
        WHERE cvu LIKE '%[^0-9]%' OR LEN(cvu) <> 22;

	DELETE FROM #temporalPagos
		WHERE NULLIF(fecha,'') IS NULL
			OR NULLIF(cvu,'') IS NULL
			OR NULLIF(monto,'') IS NULL
			OR NULLIF(id, '') IS NULL;


    INSERT INTO Finanzas.Pagos
		(
		 id,
		 fecha,
         monto,
         cuentaBancaria,
         valido,
         idExpensa,
         idUF) 
    SELECT 
		tP.id,
        TRY_CONVERT(DATE, tP.fecha, 103), 
        tP.monto, 
        tP.cvu, 
         CASE
             WHEN uf.id IS NULL OR e.id IS NULL OR tP.cvu IS NULL THEN 0
             ELSE 1
        END AS valido, 
        e.id, 
        uf.id
    FROM #temporalPagos as tP
    LEFT JOIN Infraestructura.UnidadFuncional as uf	ON Infraestructura.fn_DescrifrarCBUUF(uf.id) = tP.cvu
    LEFT JOIN Administracion.Consorcio as c	ON uf.idConsorcio = c.id
    LEFT JOIN Gastos.Expensa e ON e.idConsorcio = c.id
       AND e.periodo = CAST(
            RIGHT('0' + CAST(MONTH(TRY_CONVERT(DATE, tP.fecha, 103)) AS VARCHAR(2)),2)
            + CAST(YEAR(TRY_CONVERT(DATE, tP.fecha, 103)) AS VARCHAR(4)) as CHAR(6)
		)
	WHERE NOT EXISTS (
        SELECT 1
        FROM Finanzas.Pagos p
        WHERE p.id = tP.id
    );

    EXEC Finanzas.sp_CifrarPagos
END
GO


CREATE OR ALTER FUNCTION LogicaBD.fn_ObtenerFechaVencimiento
( @fecha DATE )
RETURNS DATE
AS
BEGIN
    DECLARE @fechaFinal DATE = @fecha;

    -- Avanza hasta el próximo día hábil (no fin de semana ni feriado)
    WHILE (LogicaBD.fn_EsFeriado(@fechaFinal) = 1)
          OR (DATEPART(WEEKDAY, @fechaFinal) IN (1,7))
    BEGIN
        SET @fechaFinal = DATEADD(DAY, 1, @fechaFinal);
    END

    RETURN @fechaFinal;
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_AsociarPagosPorCuenta
    @cuentaBancaria VARCHAR(22)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET 
        p.idUF  = uf.id,
        p.valido = 1
    FROM Finanzas.Pagos p
    INNER JOIN Infraestructura.UnidadFuncional uf
        ON Infraestructura.fn_DescrifrarCBUUF(uf.id) = @cuentaBancaria
       AND Finanzas.fn_DescrifrarCBUPagos(p.id) = @cuentaBancaria
    WHERE p.idUF IS NULL;
END
GO