USE Com5600G05
GO

EXEC LogicaBD.sp_Informe01

EXEC LogicaBD.sp_Informe01 @mesInicio = 4, @mesFinal = 5, @nombreConsorcio = 'Azcuenaga', @piso = 'PB', @departamento = 'E'

EXEC LogicaBD.sp_Informe02

EXEC LogicaBD.sp_Informe03

EXEC LogicaBD.sp_Informe04 @nombreConsorcio = 'azcuenaga'

EXEC LogicaBD.sp_Informe05

EXEC LogicaBD.sp_Informe06