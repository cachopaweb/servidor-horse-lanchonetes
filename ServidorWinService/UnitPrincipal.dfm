object TMainService: TTMainService
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'Servidor Lanchonete'
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
