USE Com5600G05
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_generarEstadoCuenta 
    @piso CHAR(2) = NULL, 
    @dpto CHAR(2) = NULL,
    @consorcio VARCHAR(100) = NULL
AS
BEGIN
    WITh ctePagosUF AS (
        SELECT 
            idUF,
            idExpensa,
            SUM(monto) AS pagos_recibidos,
            MIN(fecha) AS fechaPrimera
        FROM Finanzas.Pagos
        GROUP BY idUF, idExpensa
    ),
    cte01 AS
    (
        SELECT 
        pu.pagos_recibidos,
        e.periodo AS [periodo],
        c.nombre AS [Consorcio],
        uf.departamento,
        uf.piso,
        de.idUF AS [Uf], 
        uf.porcentajeParticipacion AS [%],
        CONCAT(
            UPPER(Personas.fn_DesencriptarNombre(p.idPersona)), ' ', 
            UPPER(Personas.fn_DesencriptarApellido(p.idPersona))) AS [Propietario], 
        ISNULL(LAG(montoTotal) OVER (PARTITION BY de.idUF ORDER BY de.idExpensa, de.idUF),0) AS [Saldo anterior],
        de.deuda AS [Deuda],
        de.intereses AS [Interes por mora],
        e.totalGastoOrdinario AS [Expensas ordinarias],
        de.montoCochera AS [Cocheras],
        de.montoBaulera AS [Bauleras],
        e.totalGastoExtraordinario AS [Expensas extraordinarias],
        montoTotal AS [Total a Pagar]
        FROM Gastos.DetalleExpensa de INNER JOIN Infraestructura.UnidadFuncional AS uf
        ON de.idUF = uf.id
        INNER JOIN Personas.Persona AS p
        ON Personas.fn_DesencriptarClaveBancaria(p.idPersona) = uf.cbu_cvu
        INNER JOIN Gastos.Expensa AS e
        ON e.id = de.idExpensa
        INNER JOIN Administracion.Consorcio AS c
        ON c.nombre = 'Azcuenaga'
        LEFT JOIN ctePagosUF AS pu 
        ON pu.idUF = de.idUF AND pu.idExpensa = de.idExpensa
    )
    SELECT 
        periodo,
        Uf,
        [%],
        Propietario,
        [Saldo anterior],
        [Pagos recibidos],
        Deuda,
        [Interes por mora],
        [Expensas ordinarias],
        Cocheras,
        Bauleras,
        [Expensas extraordinarias],
        [Total a Pagar]
    FROM (
    SELECT 
        Consorcio,
        piso,
        departamento,
        periodo,
        Uf,
        [%],
        Propietario,
        [Saldo anterior],
        ISNULL(LAG(pagos_recibidos) OVER (PARTITION BY Uf ORDER BY Uf),0) AS [Pagos recibidos],
        Deuda,
        [Interes por mora],
        [Expensas ordinarias],
        Cocheras,
        Bauleras,
        [Expensas extraordinarias],
        [Total a Pagar]
    FROM cte01) AS sub1
    WHERE 
        (@piso IS NULL OR sub1.piso = @piso) AND
        (@dpto IS NULL OR sub1.departamento = @dpto) AND
        (@consorcio IS NULL OR sub1.Consorcio = @consorcio)
    ORDER BY periodo, Uf
END
GO

EXEC LogicaBD.sp_generarEstadoCuenta
EXEC LogicaBD.sp_generarEstadoCuenta @consorcio = 'Azcuenaga'