/*
Enunciado: modificacion de SPs y creacion
de triggers para mantener la consistencia de la
base luego del cifrado de datos.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 07_ModificacionSPPostCifrado.sql
Proposito: modificacion de objetos para consistencia.
Script a ejecutar antes: 06_SPCifrado.sql
*/

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

CREATE OR ALTER PROCEDURE Personas.sp_AgregarPersona
	@dni VARCHAR(9),
	@nombre VARCHAR(50),
	@apellido VARCHAR(50),
	@email VARCHAR(100),
	@telefono VARCHAR(10),
	@cbu_cvu CHAR(22)
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		DECLARE 
			@ID INT;

		SET @dni = REPLACE(REPLACE(LTRIM(RTRIM(@dni)),' ',''),'.','');
		SET @nombre = CONCAT(UPPER(LEFT(LTRIM(RTRIM(@nombre)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(@nombre)),2,100)));
		SET @apellido = CONCAT(UPPER(LEFT(LTRIM(RTRIM(@apellido)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(@apellido)),2,100)));
		SET @email = NULLIF(LOWER(LTRIM(RTRIM(@email))), '');
		SET @telefono = NULLIF(LTRIM(RTRIM(@telefono)), '');
		SET @cbu_cvu = NULLIF(LTRIM(RTRIM(@cbu_cvu)), '');

		IF @dni IS NULL OR @dni = '' OR @dni LIKE '%[^0-9]%' OR LEN(@dni) NOT BETWEEN 7 AND 9
		BEGIN 
			PRINT('DNI invalido');
			RAISERROR('.', 16, 1);
		END
		
		IF EXISTS (
			SELECT 1
			FROM Personas.Persona
			WHERE CONVERT(VARCHAR(9), DecryptByPassPhrase(@Frase, dniCifrado, 1, CONVERT(VARBINARY, idPersona))) = @dni
		)
		BEGIN
			PRINT('Ya existe una persona con este DNI');
			RAISERROR('.', 16, 1);
		END

		IF @email IS NOT NULL AND (LEN(@email) > 100 OR @email NOT LIKE '%@%')
		BEGIN 
			PRINT('Email invalido');
			RAISERROR('.', 16, 1);
		END

		IF @email IS NOT NULL AND EXISTS (
			SELECT 1
			FROM Personas.Persona
			WHERE CONVERT(VARCHAR(100), DecryptByPassPhrase(@Frase, emailCifrado, 1, CONVERT(VARBINARY, idPersona))) = @email
		)
		BEGIN
			PRINT('Email repetido');
			RAISERROR('.', 16, 1);
		END


		IF @nombre = '' OR LEN(@nombre) > 50 OR @nombre LIKE '%[^a-zA-Z ]%'
		BEGIN 
			PRINT('Nombre invalido');
			RAISERROR('.', 16, 1);
		END

		IF @apellido = '' OR LEN(@apellido) > 50 OR @apellido LIKE '%[^a-zA-Z ]%'
		BEGIN 
			PRINT('Apellido invalido');
			RAISERROR('.', 16, 1);
		END

		IF @telefono IS NOT NULL AND (@telefono LIKE '%[^0-9]%' OR LEN(@telefono) <> 10)
		BEGIN 
			PRINT('Telefono invalido');
			RAISERROR('.', 16, 1);
		END

		IF @cbu_cvu IS NULL OR LEN(@cbu_cvu) <> 22 OR @cbu_cvu LIKE '%[^0-9]%'
		BEGIN 
			PRINT('Cbu/cvu invalido');
			RAISERROR('.', 16, 1);
		END

		IF EXISTS (
			SELECT 1
			FROM Personas.Persona
			WHERE CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, cbuCifrado, 1, CONVERT(VARBINARY, idPersona))) = @cbu_cvu
		)
		BEGIN
			PRINT('CBU/CVU repetido');
			RAISERROR('CBU/CVU repetido.', 16, 1);
		END

		INSERT INTO Personas.Persona(dni, nombre, apellido, email, telefono, cbu_cvu)
		VALUES (@dni, @nombre, @apellido, @email, @telefono, @cbu_cvu)

		PRINT('Persona insertada exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY
		
	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de persona', 16, 1);
			RETURN;
		END
	END CATCH
END
GO

CREATE OR ALTER TRIGGER Personas.tg_CifrarPersonaNueva
ON Personas.Persona
AFTER INSERT
AS
BEGIN

	BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

        -- Cifro SOLO las filas recién insertadas
        UPDATE p
        SET dniCifrado = EncryptByPassPhrase(@Frase, p.dni, 1, CONVERT(VARBINARY, p.idPersona)),
            nombreCifrado = EncryptByPassPhrase(@Frase, p.nombre, 1, CONVERT(VARBINARY, p.idPersona)),
            apellidoCifrado = EncryptByPassPhrase(@Frase, p.apellido, 1, CONVERT(VARBINARY, p.idPersona)),
            emailCifrado = EncryptByPassPhrase(@Frase, p.email, 1, CONVERT(VARBINARY, p.idPersona)),
            telefonoCifrado = EncryptByPassPhrase(@Frase, p.telefono, 1, CONVERT(VARBINARY, p.idPersona)),
            cbuCifrado = EncryptByPassPhrase(@Frase, p.cbu_cvu, 1, CONVERT(VARBINARY, p.idPersona))
        FROM Personas.Persona p
        INNER JOIN inserted i
            ON p.idPersona = i.idPersona;

        -- Borro los datos en claro SOLO de las filas recién insertadas
        UPDATE p
        SET dni      = NULL,
            nombre   = NULL,
            apellido = NULL,
            email    = NULL,
            telefono = NULL,
            cbu_cvu  = NULL
        FROM Personas.Persona p
        INNER JOIN inserted i
            ON p.idPersona = i.idPersona;

        PRINT('Persona cifrada con exito');
    END TRY
    BEGIN CATCH
        RAISERROR('Se produjo un error al cifrar persona', 16, 1);
        RETURN;
    END CATCH

END
GO

CREATE OR ALTER PROCEDURE Finanzas.sp_AgregarPago
	@fecha DATE,
	@monto DECIMAL(10, 2),
	@cuentaBancaria VARCHAR(22)
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE 
			@ID INT,
			@idExpensa INT,
			@idUF INT,
			@Frase NVARCHAR(128) = 'MiClaveSecreta_576',
			@cuentaBancariaCifrada VARBINARY(MAX);

		-- Limpieza y validación básica
		SET @cuentaBancaria = REPLACE(LTRIM(RTRIM(@cuentaBancaria)),' ','');
		IF @cuentaBancaria IS NULL OR LEN(@cuentaBancaria) <> 22 OR @cuentaBancaria LIKE '%[^0-9]%'
		BEGIN
			 PRINT('Cuenta bancaria inválida');
			 RAISERROR('Cuenta bancaria inválida.', 16, 1);
			 RETURN;
		END;

		IF @monto IS NULL OR @monto <= 0 OR @monto > 99999999.99
		BEGIN
			PRINT('Monto inválido');
			RAISERROR('Monto inválido.', 16, 1);
			RETURN;
		END;

		-- Buscar expensa correspondiente al período de la fecha del pago (MMYYYY)
		SELECT @idExpensa = id
		FROM Gastos.Expensa
		WHERE periodo = CAST(
				RIGHT('0' + CAST(MONTH(@fecha) AS VARCHAR(2)),2)
				+ CAST(YEAR(@fecha) AS VARCHAR(4)) AS CHAR(6)
			);

		-- Buscar unidad funcional asociada al CBU cifrado
		SELECT @idUF = uf.id
		FROM Infraestructura.UnidadFuncional uf
		WHERE CONVERT(VARCHAR(22),
			DecryptByPassPhrase(@Frase, uf.cbuCifrado, 1, CONVERT(VARBINARY, uf.id))
		) = @cuentaBancaria;

		-- Si no se encontró UF, el pago se marca como no válido
		IF @idUF IS NULL
		BEGIN
			PRINT('Advertencia: el CBU no pertenece a ninguna unidad funcional registrada. El pago se registrará con idUF NULL y valido=0.');
		END;

		-- Cifrar la cuenta bancaria antes de insertar
		SET @cuentaBancariaCifrada = EncryptByPassPhrase(@Frase, @cuentaBancaria, 1, CONVERT(VARBINARY, ISNULL(@idUF, 0)));

		-- Generar ID manual (si no es IDENTITY)
		SELECT @ID = ISNULL(MAX(p.id), 0) + 1
		FROM Finanzas.Pagos p;

		-- Inserción
		INSERT INTO Finanzas.Pagos 
			(id, fecha, monto, cuentaBancaria, cuentaBancariaCifrada, valido, idExpensa, idUF)
		VALUES (
			@ID,
			@fecha,
			@monto,
			NULL,
			@cuentaBancariaCifrada,
			CASE WHEN @idUF IS NOT NULL THEN 1 ELSE 0 END,
			@idExpensa,
			@idUF
		);

		PRINT('Pago insertado exitosamente.');
		SELECT @ID AS id;

	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN	
			RAISERROR('Algo salió mal en el registro de pago.', 16, 1);
			RETURN;
		END;
	END CATCH
END
GO


CREATE OR ALTER PROCEDURE Personas.sp_AgregarPersonaEnUF
	@dniPersona VARCHAR(9),
	@idUF INT,
	@inquilino BIT,
	@fechaDesde DATE,
	@fechaHasta DATE
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE 
			@ID INT,
			@unidadFuncionalExiste INT,
			@IDPersona INT,
			@Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		-- Normalización del DNI
		SET @dniPersona = REPLACE(REPLACE(LTRIM(RTRIM(@dniPersona)),' ',''),'.','');

		-- Validaciones básicas
		IF @idUF IS NULL OR @idUF <= 0
		BEGIN
			PRINT('ID de unidad funcional inválido');
			RAISERROR('ID de unidad funcional inválido.', 16, 1);
			RETURN;
		END;

		-- Validar existencia de la UF
		SELECT @unidadFuncionalExiste = id
		FROM Infraestructura.UnidadFuncional
		WHERE id = @idUF;

		IF @unidadFuncionalExiste IS NULL
		BEGIN
			PRINT('La unidad funcional no existe');
			RAISERROR('La unidad funcional no existe.', 16, 1);
			RETURN;
		END;

		IF @dniPersona IS NULL OR @dniPersona = '' OR @dniPersona LIKE '%[^0-9]%' OR LEN(@dniPersona) NOT BETWEEN 7 AND 9
        BEGIN
			PRINT('DNI inválido');
			RAISERROR('DNI inválido.', 16, 1);
			RETURN;
		END;

		-- Buscar persona por DNI cifrado
		SELECT @IDPersona = p.idPersona
		FROM Personas.Persona p
		WHERE CONVERT(VARCHAR(9),
				DecryptByPassPhrase(@Frase, p.dniCifrado, 1, CONVERT(VARBINARY, p.idPersona))
			  ) = @dniPersona;

		IF @IDPersona IS NULL
		BEGIN
			PRINT('La persona no existe');
			RAISERROR('La persona no existe.', 16, 1);
			RETURN;
		END;

		IF @inquilino NOT IN (0,1)
		BEGIN
			PRINT('Bit de inquilino inválido');
			RAISERROR('Bit de inquilino inválido.', 16, 1);
			RETURN;
		END;

		IF @fechaDesde IS NULL
		BEGIN
			PRINT('Fecha desde inválida');
			RAISERROR('Fecha desde inválida.', 16, 1);
			RETURN;
		END;

		IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaDesde
		BEGIN
			PRINT('Fecha hasta inválida');
			RAISERROR('Fecha hasta inválida.', 16, 1);
			RETURN;
		END;

		-- Verificar duplicado (persona ya asignada en misma fecha)
		SELECT @ID = idPersonaUF
		FROM Personas.PersonaEnUF
		WHERE idPersona = @IDPersona AND fechaDesde = @fechaDesde;

		IF @ID IS NOT NULL
		BEGIN
			PRINT('La persona ya está asignada a la unidad funcional en esa fecha');
			RAISERROR('La persona ya está asignada a la unidad funcional en esa fecha.', 16, 1);
			RETURN;
		END;

		-- Inserción
		INSERT INTO Personas.PersonaEnUF (idPersona, idUF, inquilino, fechaDesde, fechaHasta)
		VALUES (@IDPersona, @idUF, @inquilino, @fechaDesde, @fechaHasta);

		PRINT('Persona en unidad funcional insertada exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
			RAISERROR('Algo salió mal en el registro de persona en unidad funcional.', 16, 1);
	END CATCH
END;
GO

CREATE OR ALTER TRIGGER Infraestructura.tg_CifrarCBUUnidadFuncional
ON Infraestructura.UnidadFuncional
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

        -- Cifra el CBU de las filas afectadas
        UPDATE uf
        SET cbuCifrado = EncryptByPassPhrase(
                            @Frase,
                            uf.cbu_cvu,                 
                            1,
                            CONVERT(VARBINARY, uf.id)   
                         ),
            cbu_cvu = NULL   -- si querés borrar el valor en claro
        FROM Infraestructura.UnidadFuncional uf
        INNER JOIN inserted i
            ON uf.id = i.id
        WHERE uf.cbu_cvu IS NOT NULL;   -- solo las que tengan CBU cargado

        PRINT('CBU de unidad funcional cifrado correctamente');
    END TRY
    BEGIN CATCH
        RAISERROR('Error al cifrar CBU de unidad funcional', 16, 1);
    END CATCH
END;
GO
