unit Mesas.Controller;

interface

uses
  Horse,
  Horse.Commons,
  Classes,
  SysUtils,
  System.Json,
  DB,
  UnitConnection.Model.Interfaces,
  DataSet.Serialize;

type
  TMesasController = class
    class procedure Registrar;
    class procedure Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetMesa(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

implementation

{ TMesasController }

uses UnitConstants, UnitDatabase;

class procedure TMesasController.Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Dados: TDataSource;
begin
  Dados := TDataSource.Create(nil);
  Query := TDatabase.Query;
  Query.Clear;
  Query.Open('SELECT M.*, COM_VALOR MES_VALOR FROM MESAS M LEFT JOIN COMANDAS ON COM_MESA = MES_CODIGO AND COM_DATA_FECHAMENTO IS NULL');
  Dados.DataSet := Query.DataSet;
  Res.Send<TJSONArray>(Dados.DataSet.ToJSONArray);
end;

class procedure TMesasController.GetMesa(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Dados: TDataSource;
  CodMesa: Integer;
begin
  if Req.Params.Count > 0 then
  begin
    CodMesa := Req.Params.Items['codigo'].ToInteger();
    Dados := TDataSource.Create(nil);
    Query := TDatabase.Query;
    Query.Clear;
    Query.Add('SELECT M.*, COM_VALOR MES_VALOR FROM MESAS M LEFT JOIN COMANDAS ON COM_MESA = MES_CODIGO AND COM_DATA_FECHAMENTO IS NULL WHERE MES_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', CodMesa);
    Query.Open();
    Dados.DataSet := Query.DataSet;
    Res.Send<TJSONObject>(Dados.DataSet.ToJSONObject);
  end else
    Res.Send(TJSONObject.Create.AddPair('error', 'Codigo da mesa não informado')).Status(THTTPStatus.BadRequest);
end;

class procedure TMesasController.Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Codigo: Integer;
  Status: string;
begin
  Query := TDatabase.Query;
  if Req.Params.ContainsKey('codigo') then
    Codigo := Req.Params['codigo'].ToInteger();
  if Req.Params.ContainsKey('status') then
    Status := Req.Params['status'];
  // Atualiza o estado da mesa
  try
    Query.Clear;
    Query.Add('UPDATE MESAS SET MES_ESTADO = :STATUS WHERE MES_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.AddParam('STATUS', Status);
    Query.ExecSQL;
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('status', Status)).Status(THTTPStatus.OK);
  except on E: Exception do
    raise Exception.Create('Erro ao tentar mudar status da mesa '+Codigo.ToString+sLineBreak+E.Message);
  end;
end;

class procedure TMesasController.Registrar;
begin
  THorse.Get('/Mesas', Get);
  THorse.Post('/Mesas/:codigo/status/:status', Post);
  THorse.Get('/Mesas/:codigo', GetMesa);
end;

end.
