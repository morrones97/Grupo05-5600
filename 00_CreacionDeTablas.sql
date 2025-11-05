IF DB_ID('auxiliarDB') IS NULL
BEGIN
	CREATE DATABASE auxiliarDB
END
GO

USE auxiliarDB
GO

IF DB_ID('Grupo05_5600') IS NOT NULL
BEGIN
	ALTER DATABASE Grupo05_5600
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;	

	DROP DATABASE Grupo05_5600
END
GO

CREATE DATABASE Grupo05_5600
GO

USE Grupo05_5600
GO

DROP DATABASE auxiliarDB
GO

-- Incluye Edificio, UnidadFuncional
CREATE SCHEMA Infraestructura
GO

-- Incluye Consorcio
CREATE SCHEMA Administracion
GO

-- Incluye Perona, PersonaEnUF
CREATE SCHEMA Personas
GO

-- Incluye Expensa, DetalleExpensa, GastoOrdinario, GastoExtraordinario, EnvioExpensa
CREATE SCHEMA Gastos
GO

-- Incluye Pago, MovimientoBancario
CREATE SCHEMA Finanzas
GO

CREATE SCHEMA LogicaNormalizacion
GO

-- Incluye Edificio, UnidadFuncional
CREATE TABLE Infraestructura.Edificio(
	id INT IDENTITY(1,1),
	direccion VARCHAR(100) NOT NULL,
	metrosTotales DECIMAL(8,2) NOT NULL,
	CONSTRAINT pk_Edificio PRIMARY KEY (id)
)
GO

CREATE TABLE Infraestructura.UnidadFuncional(
	id INT IDENTITY (1,1),
	piso CHAR(2) CHECK (piso LIKE 'PB' OR piso BETWEEN '01' AND '99'),
	departamento CHAR(1) CHECK (departamento LIKE '[A-Z]'),
	dimension DECIMAL(5,2) NOT NULL,
	m2Cochera DECIMAL(5,2),
	m2Baulera DECIMAL(5,2),
	porcentajeParticipacion DECIMAL(4,2) NOT NULL CHECK (porcentajeParticipacion > 0 AND porcentajeParticipacion <= 100),
	cbu_cvu CHAR(22) NOT NULL UNIQUE CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),
	idEdificio INT,
	CONSTRAINT pk_UF PRIMARY KEY (id),
	CONSTRAINT fk_UF_Edificio FOREIGN KEY (idEdificio) REFERENCES Infraestructura.Edificio(id)
)
GO

-- Incluye Consorcio
CREATE TABLE Administracion.Consorcio(
	id INT IDENTITY(1,1),
	nombre VARCHAR(100) NOT NULL,
	idEdificio INT,
	CONSTRAINT pk_Consorcio PRIMARY KEY (id),
	CONSTRAINT fk_Consorcio_Edificio FOREIGN KEY (idEdificio) REFERENCES Infraestructura.Edificio(id)
)
GO

-- Incluye Perona, PersonaEnUF
CREATE TABLE Personas.Persona(
	dni VARCHAR(9),
	nombre VARCHAR(50),
	apellido VARCHAR(50),
	email VARCHAR(100) NULL CHECK (email LIKE '%@%'),
	telefono VARCHAR(10) NOT NULL CHECK (telefono NOT LIKE '%[^0-9]%'),
	cbu_cvu CHAR(22) NOT NULL UNIQUE CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),
	CONSTRAINT pk_Persona PRIMARY KEY (dni)
)
GO

CREATE TABLE Personas.PersonaEnUF(
	dniPersona VARCHAR(9) CHECK (dniPersona NOT LIKE '%[^0-9]%'),
	idUF INT,
	inquilino BIT,
	propietario BIT,
	fechaDesde DATE DEFAULT GETDATE(),
	fechaHasta DATE,
	CONSTRAINT pk_PersonaEnUF PRIMARY KEY (dniPersona, idUF),
	CONSTRAINT fk_PersonaUF_Persona FOREIGN KEY (dniPersona) REFERENCES Personas.Persona(dni),
	CONSTRAINT fk_PersonaUF_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
)
GO

CREATE UNIQUE INDEX UQ_Persona_Email
ON Personas.Persona(email)
WHERE email IS NOT NULL;

-- Incluye Expensa, DetalleExpensa, GastoOrdinario, GastoExtraordinario, EnvioExpensa
CREATE TABLE Gastos.Expensa (
	id INT IDENTITY(1,1),
	periodo CHAR(6) CHECK (LEN(periodo) = 6 AND periodo LIKE '%[0-9]%'),
	totalGastoOrdinario DECIMAL(12,2) CHECK (totalGastoOrdinario >= 0),
	totalGastoExtraordinario DECIMAL(12,2) CHECK (totalGastoExtraordinario >= 0),
	primerVencimiento DATE NOT NULL,
	segundoVencimiento DATE NOT NULL,
	idConsorcio INT,
	CONSTRAINT pk_Expensa PRIMARY KEY (id),
	CONSTRAINT fk_Expensa_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
)
GO

/*
Numero de factura siento que no deberia ser INT, deberia ser CHAR
Basado en los archivos, GastoOrdinario, quizas deberia ser que cada campo sea el tipoDeGasto, y periodo (mes+año)?
Cambiaria y en lugar de relacionarlo con la expensa, lo relacionaria con el consorcio. Porque de la otra manera, 
no puedo crear un gasto ordinario sin antes crear una expensa
*/
CREATE TABLE Gastos.GastoOrdinario (
	id INT IDENTITY(1,1),
	mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
	tipoGasto VARCHAR(50) CHECK 
		(tipoGasto IN 
			(	'Mantenimiento de cuenta bancaria', 'Limpieza', 
				'Administracion/Honorarios', 'Seguro',
				'Generales', 'Servicios Publico')
			),
	empresaPersona VARCHAR(100),
	nroFactura INT,
	importeFactura DECIMAL(8,2),
	sueldoEmpleadoDomestico DECIMAL(10,2),
	detalle VARCHAR(200),
	idConsorcio INT,
	CONSTRAINT pk_GastoOrdinario PRIMARY KEY (id),
	CONSTRAINT fk_GastoOrdinario_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
)
GO

CREATE TABLE Gastos.GastoExtraordinario (
	id INT,
	mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
	detalle VARCHAR(200) NOT NULL,
	importe DECIMAL(10,2) NOT NULL,
	formaPago VARCHAR(6) CHECK (formaPago IN ('Cuotas','Total')) NOT NULL,
	nroCuotaAPagar INT CHECK (nroCuotaAPagar > 0),
	nroTotalCuotas INT CHECK (nroTotalCuotas > 0),
	idConsorcio INT,
	CONSTRAINT pk_GastoExtraordinario PRIMARY KEY (id),
	CONSTRAINT fk_GastoExtraordinario_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
)
GO

CREATE TABLE Gastos.DetalleExpensa (
	id INT,
	montoBase DECIMAL(10,2) CHECK (montoBase > 0),
	deuda DECIMAL(10,2),
	intereses DECIMAL (10,2),
	montoCochera DECIMAL(8,2),
	montoBaulera DECIMAL(8,2),
	montoTotal DECIMAL(20,2) CHECK (montoTotal > 0),
	estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
	idExpensa INT,
	idUF INT,
	CONSTRAINT pk_DetalleExpensa PRIMARY KEY (id),
	CONSTRAINT fk_Detalle_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
	CONSTRAINT fk_Detalle_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
)
GO

CREATE TABLE Gastos.EnvioExpensa (
	id INT,
	rol VARCHAR(10),
	metodo VARCHAR(8) CHECK (metodo IN ('email', 'telefono', 'impreso')),
	email VARCHAR(100) NOT NULL UNIQUE CHECK (email LIKE '%@%'),
	telefono VARCHAR(10) NOT NULL CHECK (telefono NOT LIKE '%[^0-9]%'),
	fecha DATE NOT NULL,
	estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
	dniPersona VARCHAR(9),
	idExpensa INT,
	CONSTRAINT pk_EnvioExpensa PRIMARY KEY (id),
	CONSTRAINT fk_Envio_Persona FOREIGN KEY (dniPersona) REFERENCES Personas.Persona(dni),
	CONSTRAINT fk_Envio_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id)
)
GO

CREATE TABLE Finanzas.Pagos (
	id INT,
	fecha DATE,
	monto DECIMAL(10,2),
	cuentaBancaria VARCHAR(22),
	valido BIT,
	idExpensa INT,
	idUF INT,
	CONSTRAINT pk_Pagos PRIMARY KEY (id),
	CONSTRAINT fk_Pagos_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
	CONSTRAINT fk_Pagos_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
)

