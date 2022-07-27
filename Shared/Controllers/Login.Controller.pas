unit Login.Controller;

interface
uses
  Horse,
  Horse.Commons,
  Classes,
  SysUtils,
  System.Json,
  DB,
  UnitConnection.Model.Interfaces;


type
  TLoginController = class
    class procedure Registrar;
    class procedure Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetUsuarios(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

implementation

{ TLoginController }

uses UnitConstants, UnitDatabase, UnitFuncoesComuns;

class procedure TLoginController.GetUsuarios(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var Query: iQuery;
  aJson: TJSONArray;
  oJson: TJSONObject;
begin
  Query := TDatabase.Query;
  Query.Open('SELECT USU_CODIGO, USU_LOGIN FROM USUARIOS ORDER BY USU_LOGIN');
  aJson := TJSONArray.Create;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    oJson := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('USU_CODIGO').AsInteger));
    oJson.AddPair('login', Query.DataSet.FieldByName('USU_LOGIN').AsString);
    aJson.AddElement(oJson);
    Query.DataSet.Next;
  end;
  Res.Send<TJSONArray>(aJson);
end;

class procedure TLoginController.Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  login: String;
  senha: string;
  oJson: TJSONObject;
begin
  if Req.Body <> '' then
  begin
    login := Req.Body<TJSONObject>.GetValue<string>('login');
    senha := Req.Body<TJSONObject>.GetValue<string>('senha');
    Query := TDatabase.Query;
    Query.Clear;
    Query.Add('SELECT USU_CODIGO, USU_LOGIN FROM USUARIOS WHERE USU_LOGIN = :LOGIN AND USU_SENHA = :SENHA');
    Query.AddParam('LOGIN', login);
    Query.AddParam('SENHA', EnDecryptString(senha, 236));
    Query.Open();
    if not Query.DataSet.IsEmpty then
    begin
      oJson := TJSONObject.Create;
      oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('USU_CODIGO').AsInteger));
      oJson.AddPair('login', Query.DataSet.FieldByName('USU_LOGIN').AsString);
      Res.Send<TJSONObject>(oJson);
    end else
      Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'não autorizado')).Status(THTTPStatus.Unauthorized);
  end else
    Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>(TJSONObject.Create.AddPair('error', 'Usuario não informado'));
end;

class procedure TLoginController.Registrar;
begin
  THorse.Post('/login', Post)
        .Get('/usuarios', GetUsuarios);
end;

end.
