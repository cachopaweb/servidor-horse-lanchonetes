unit Produtos.Controller;

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
  TProdutosController = class
    class procedure Registrar;
    class procedure Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetProdutoPorCodigo(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetCategorias(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetFotoProduto(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetFotoCategoria(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetGradesProduto(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetGradeProduto(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

implementation

{ TProdutosController }

uses UnitFuncoesComuns, UnitDatabase;

class procedure TProdutosController.Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query    : iQuery;
  Categoria: integer;
  aJson    : TJSONArray;
  oJson    : TJSONObject;
begin
  Query := TDatabase.Query;
  aJson := TJSONArray.Create;
  Query.Clear;
  if Req.Query.Count > 0 then
  begin
    Categoria := Req.Query.Items['categoria'].ToInteger;
    Query.Add('SELECT PRO_CODIGO, PRO_NOME, PRO_VALORV, GRU_CODIGO, ');
    Query.Add('(SELECT FIRST 1 GRA_CODIGO FROM GRADES WHERE GRA_PRO = PRO_CODIGO) GRA_CODIGO');
    Query.Add('FROM PRODUTOS JOIN GRUPOS ON PRO_GRU = GRU_CODIGO AND GRU_CODIGO = :GRUPO');
    Query.Add('WHERE PRO_ESTADO = ''ATIVO''');
    Query.AddParam('GRUPO', Categoria);
    Query.Open;
  end
  else
  begin
    Query.Add('SELECT PRO_CODIGO, PRO_NOME, PRO_VALORV, GRU_CODIGO, ');
    Query.Add('(SELECT FIRST 1 GRA_CODIGO FROM GRADES WHERE GRA_PRO = PRO_CODIGO) GRA_CODIGO');
    Query.Add('FROM PRODUTOS JOIN GRUPOS ON PRO_GRU = GRU_CODIGO ');
    Query.Add('WHERE PRO_ESTADO = ''ATIVO''');
    Query.Open();
  end;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    oJson     := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('PRO_CODIGO').AsInteger));
    oJson.AddPair('nome', Query.DataSet.FieldByName('PRO_NOME').AsString);
    oJson.AddPair('valor', TJSONNumber.Create(Query.DataSet.FieldByName('PRO_VALORV').AsCurrency));
    oJson.AddPair('categoria', TJSONNumber.Create(Query.DataSet.FieldByName('GRU_CODIGO').AsInteger));
    oJson.AddPair('grade', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_CODIGO').AsInteger));
    aJson.AddElement(oJson);
    Query.DataSet.Next;
  end;
  Res.Send<TJSONArray>(aJson);
end;

class procedure TProdutosController.GetCategorias(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query    : iQuery;
  Categoria: string;
  aJson    : TJSONArray;
  oJson    : TJSONObject;
begin
  Query := TDatabase.Query;
  Query.Clear;
  Query.Open('SELECT GRU_CODIGO, GRU_NOME FROM GRUPOS');
  aJson := TJSONArray.Create;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    oJson     := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('GRU_CODIGO').AsInteger));
    oJson.AddPair('nome', Query.DataSet.FieldByName('GRU_NOME').AsString);
    aJson.AddElement(oJson);
    Query.DataSet.Next;
  end;
  Res.Send<TJSONArray>(aJson);
end;

class procedure TProdutosController.GetFotoCategoria(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query    : iQuery;
  Categoria: integer;
  oJson    : TJSONObject;
  imgBase64: string;
begin
  if Req.Params.Count > 0 then
  begin
    Categoria := Req.Params.Items['codigo'].ToInteger();
    Query := TDatabase.Query;
    Query.Clear;
    Query.Add('SELECT GRU_CAMINHO_IMAGEM FROM GRUPOS WHERE GRU_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Categoria);
    Query.Open();
    if not Query.DataSet.IsEmpty then
    begin
      oJson     := TJSONObject.Create;
      imgBase64 := ConvertFileToBase64(Query.DataSet.FieldByName('GRU_CAMINHO_IMAGEM').AsString);
      oJson.AddPair('base64', imgBase64);
      Res.Send<TJSONObject>(oJson);
    end;
  end else
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('error', 'Categoria não informada')).Status(THTTPStatus.BadRequest);
end;

class procedure TProdutosController.GetFotoProduto(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query    : iQuery;
  Codigo: integer;
  oJson    : TJSONObject;
  imgBase64: string;
begin
  Query := TDatabase.Query;
  Query.Clear;
  if Req.Params.Count > 0 then
  begin
    Codigo := Req.Params.Items['codigo'].ToInteger;
    Query.Add('SELECT PRO_CAMINHO_IMAGEM FROM PRODUTOS WHERE PRO_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.Open;
    Query.DataSet.First;
    if not Query.DataSet.IsEmpty then
    begin
      imgBase64 := ConvertFileToBase64(Query.DataSet.FieldByName('PRO_CAMINHO_IMAGEM').AsString);
      oJson     := TJSONObject.Create;
      oJson.AddPair('base64', imgBase64);
      Res.Send<TJSONObject>(oJson);
    end;
  end else
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('error', 'Codigo do produto não informado')).Status(THTTPStatus.BadRequest);
end;

class procedure TProdutosController.GetGradeProduto(Req: THorseRequest;
  Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Produto: Integer;
  oJson: TJSONObject;
  Tamanho: string;
begin
  if not Req.Params.ContainsKey('codigo') then
    raise Exception.Create('Codigo do Produto requerido');
  Produto := Req.Params.Items['codigo'].ToInteger;
  if not Req.Params.ContainsKey('tamanho') then
    raise Exception.Create('Tamanho do Produto requerido');
  Tamanho := Req.Params.Items['tamanho'];
  Query := TDatabase.Query;
  Query.Clear;
  Query.Add('SELECT GRA_CODIGO, GRA_VALOR, TAM_SIGLA FROM');
  Query.Add('GRADES JOIN TAMANHOS ON GRA_TAM = TAM_CODIGO');
  Query.Add('WHERE GRA_PRO = :PRODUTO AND TAM_SIGLA = :TAMANHO');
  Query.AddParam('PRODUTO', Produto);
  Query.AddParam('TAMANHO', Tamanho);
  Query.Open;
  if not Query.DataSet.IsEmpty then
  begin
    oJson := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_CODIGO').AsInteger));
    oJson.AddPair('valor', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_VALOR').AsCurrency));
    oJson.AddPair('tamanho', Query.DataSet.FieldByName('TAM_SIGLA').AsString);
  end;
  Res.Send<TJSONObject>(oJson);
end;

class procedure TProdutosController.GetGradesProduto(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Produto: Integer;
  aJson: TJSONArray;
  oJson: TJSONObject;
begin
  if Req.Params.Count = 0 then
    raise Exception.Create('Codigo do Produto requerido');
  Produto := Req.Params.Items['codigo'].ToInteger;
  Query := TDatabase.Query;
  Query.Clear;
  Query.Add('SELECT GRA_CODIGO, GRA_VALOR, TAM_SIGLA FROM');
  Query.Add('GRADES JOIN TAMANHOS ON GRA_TAM = TAM_CODIGO');
  Query.Add('WHERE GRA_PRO = :PRODUTO');
  Query.AddParam('PRODUTO', Produto);
  Query.Open;
  aJson := TJSONArray.Create;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    oJson := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_CODIGO').AsInteger));
    oJson.AddPair('valor', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_VALOR').AsCurrency));
    oJson.AddPair('tamanho', Query.DataSet.FieldByName('TAM_SIGLA').AsString);
    aJson.AddElement(oJson);
    Query.DataSet.Next;
  end;
  Res.Send<TJSONArray>(aJson);
end;

class procedure TProdutosController.GetProdutoPorCodigo(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query    : iQuery;
  Codigo: integer;
  oJson    : TJSONObject;
begin
  Query := TDatabase.Query;
  Query.Clear;
  Codigo := Req.Params.Items['codigo'].ToInteger;
  Query.Add('SELECT PRO_CODIGO, PRO_NOME, PRO_VALORV, PRO_GRU, ');
  Query.Add('(SELECT FIRST 1 GRA_CODIGO FROM GRADES WHERE GRA_PRO = PRO_CODIGO) GRA_CODIGO');
  Query.Add('FROM PRODUTOS JOIN GRUPOS ON PRO_GRU = GRU_CODIGO AND PRO_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', Codigo);
  Query.Open;
  if not Query.DataSet.IsEmpty then
  begin
    oJson     := TJSONObject.Create;
    oJson.AddPair('codigo', TJSONNumber.Create(Query.DataSet.FieldByName('PRO_CODIGO').AsInteger));
    oJson.AddPair('nome', Query.DataSet.FieldByName('PRO_NOME').AsString);
    oJson.AddPair('valor', TJSONNumber.Create(Query.DataSet.FieldByName('PRO_VALORV').AsCurrency));
    oJson.AddPair('categoria', TJSONNumber.Create(Query.DataSet.FieldByName('PRO_GRU').AsInteger));
    oJson.AddPair('grade', TJSONNumber.Create(Query.DataSet.FieldByName('GRA_CODIGO').AsInteger));
    Res.Send<TJSONObject>(oJson);
  end else
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'Produto not found')).Status(THTTPStatus.BadRequest);
end;

class procedure TProdutosController.Registrar;
begin
  THorse.Get('/Produtos', Get);
  THorse.Get('/Produtos/:codigo', GetProdutoPorCodigo);
  THorse.Get('/Categorias', GetCategorias);
  THorse.Get('/Categorias/:codigo/foto', GetFotoCategoria);
  THorse.Get('/Produtos/:codigo/foto', GetFotoProduto);
  THorse.Get('/Produtos/Grades/:codigo', GetGradesProduto);
  THorse.Get('/Produtos/Grades/:codigo/:tamanho', GetGradeProduto);
end;

end.
