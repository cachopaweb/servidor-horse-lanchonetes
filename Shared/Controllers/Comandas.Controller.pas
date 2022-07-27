unit Comandas.Controller;

interface

uses
  Horse,
  Horse.Commons,
  Classes,
  SysUtils,
  System.Json,
  UnitConnection.Model.Interfaces,
  DataSet.Serialize,
  UnitComanda.Model,
  UnitComplemento.Model;

type
  TComandasController = class
  private
    class function BuscaDadosGrade(CodGrade: integer): TJSONObject;
  public
    class procedure Registrar;
    class procedure Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetPorCodigo(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure EncerrarComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure AtualizarComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure DeletarItemComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure DeletarComplementos(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure GetItemComPro(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

implementation

{ TComandasController }

uses UnitConstants, UnitDatabase;

class procedure TComandasController.AtualizarComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Codigo: integer;
  CodigoComanda: integer;
  Comanda: TModelComanda;
  i: integer;
  Item: TModelItens;
  TotalComanda: Currency;
  CodigoComPro: integer;
  Complementos: TArray<TModelComplemento>;
  c: integer;
  TotalComplementos: Currency;
begin
  if Req.Params.Count = 0 then
    raise Exception.Create('Paramentro "Codigo" não informado!');
  Codigo  := Req.Params.Items['codigo'].ToInteger;
  Comanda := TModelComanda.FromJsonString(Req.Body);
  Query   := TDatabase.Query;
  Query.Clear;
  Query.Add('SELECT COM_CODIGO FROM COMANDAS WHERE COM_CODIGO = (SELECT MAX(COM_CODIGO) FROM COMANDAS WHERE COM_DATA_FECHAMENTO IS NULL AND COM_MESA = :CODIGO)');
  Query.AddParam('CODIGO', Codigo);
  Query.Open;
  CodigoComanda := Query.DataSet.FieldByName('COM_CODIGO').AsInteger;
  For i := Low(Comanda.Itens) to High(Comanda.Itens) do
  begin
    Item := Comanda.Itens[i];
    Query.Clear;
    Query.Add('UPDATE OR INSERT INTO COM_PRO ');
    Query.Add('(CP_CODIGO, CP_COM, CP_PRO, CP_QUANTIDADE, CP_VALOR, CP_GRA, CP_OBS, CP_ESTADO, CP_USU)');
    Query.Add('VALUES (GEN_ID(GEN_CP_CODIGO, 1), :COM, :PRO, :QUANTIDADE, :VALOR, :GRA, :OBS, :ESTADO, :USUARIO)');
    Query.Add('MATCHING (CP_CODIGO) RETURNING (CP_CODIGO)');
    Query.AddParam('COM', CodigoComanda);
    Query.AddParam('PRO', Item.Produto);
    Query.AddParam('QUANTIDADE', Item.Quantidade);
    Query.AddParam('VALOR', Item.Valor);
    Query.AddParam('GRA', Item.Grade);
    Query.AddParam('OBS', Item.Obs);
    Query.AddParam('ESTADO', 'A');
    Query.AddParam('USUARIO', Item.usuario);
    Query.Open();
    if not Query.DataSet.IsEmpty then
      CodigoComPro := Query.DataSet.FieldByName('CP_CODIGO').AsInteger;
    if CodigoComPro > 0 then
    begin
      Complementos := Comanda.Itens[i].Complementos;
      for c        := Low(Complementos) to High(Complementos) do
      begin
        Query.Clear;
        Query.Add('INSERT INTO CP_ADICIONAIS (CA_CODIGO, CA_CP, CA_ADI, CA_QUANTIDADE)');
        Query.Add('VALUES (GEN_ID(GEN_CP_ADICIONAIS, 1), :CP, :ADI, :QUANTIDADE);');
        Query.AddParam('CP', CodigoComPro);
        Query.AddParam('ADI', Complementos[c].Codigo);
        Query.AddParam('QUANTIDADE', Complementos[c].Quantidade);
        Query.ExecSQL;
      end;
    end;
  end;
  Query.Clear;
  Query.Add('SELECT SUM(CP_VALOR) TOTAL, SUM(ADI_VALOR * CA_QUANTIDADE) COMPLEMENTOS');
  Query.Add('FROM COM_PRO JOIN COMANDAS ON CP_COM = COM_CODIGO');
  Query.Add('LEFT JOIN CP_ADICIONAIS ON CA_CP = CP_CODIGO');
  Query.Add('LEFT JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO');
  Query.Add('WHERE COM_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.Open();
  TotalComanda      := Query.DataSet.FieldByName('TOTAL').AsCurrency;
  TotalComplementos := Query.DataSet.FieldByName('COMPLEMENTOS').AsCurrency;
  // Atualiza comandas
  Query.Clear;
  Query.Add('UPDATE COMANDAS SET COM_VALOR = :VALOR WHERE COM_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.AddParam('VALOR', TotalComanda + TotalComplementos);
  Query.ExecSQL;
  // Atualiza o estado da mesa
  Query.Clear;
  Query.Add('UPDATE MESAS SET MES_ESTADO = ''O'' WHERE MES_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', Codigo);
  Query.ExecSQL;
  Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'Comanda Atualizada com sucesso')).Status(THTTPStatus.OK);
end;

class function TComandasController.BuscaDadosGrade(CodGrade: integer): TJSONObject;
var
  Query: iQuery;
begin
  Result := TJSONObject.Create;
  if CodGrade > 0 then
  begin
    Query := TDatabase.Query;
    Query.Add('SELECT GRA_CODIGO codigo, TAM_SIGLA tamanho, GRA_VALOR valor FROM GRADES JOIN TAMANHOS ON GRA_TAM = TAM_CODIGO');
    Query.Add('WHERE GRA_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', CodGrade);
    Query.Open();
    Result := Query.DataSet.ToJSONObject;
  end;
end;

class procedure TComandasController.DeletarComplementos(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Codigo: integer;
begin
  if Req.Params.Count > 0 then
  begin
    Codigo := Req.Params.Items['codigo'].ToInteger();
    Query  := TDatabase.Query;
    // deleta cp adicionais
    Query.Clear;
    Query.Add('DELETE FROM CP_ADICIONAIS WHERE CA_CP = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.ExecSQL;
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'Complementos excluidos com sucesso!')).Status(THTTPStatus.OK);
  end
  else
    Res.Send<TJSONObject>(TJSONObject.Create().AddPair('error', 'Codigo da com_pro não informado')).Status(THTTPStatus.BadRequest);
end;

class procedure TComandasController.DeletarItemComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Codigo: integer;
  CodigoComanda: integer;
  TotalComanda: Currency;
  TotalComplementos: Currency;
  CodigoMesa: integer;
begin
  if Req.Params.Count > 0 then
  begin
    Codigo := Req.Params.Items['codigo'].ToInteger();
    Query  := TDatabase.Query;
    // busca o codigo da comanda
    Query.Clear;
    Query.Add('SELECT CP_COM FROM COM_PRO WHERE CP_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.Open();
    CodigoComanda := Query.DataSet.FieldByName('CP_COM').AsInteger;
    /// /
    Query.Clear;
    Query.Add('DELETE FROM COM_PRO WHERE CP_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.ExecSQL;
    // deleta cp adicionais
    Query.Clear;
    Query.Add('DELETE FROM CP_ADICIONAIS WHERE CA_CP = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.ExecSQL;
    // soma comanda
    Query.Clear;
    Query.Add('SELECT SUM(CP_VALOR) TOTAL');
    Query.Add('FROM COM_PRO JOIN COMANDAS ON CP_COM = COM_CODIGO');
    Query.Add('WHERE COM_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', CodigoComanda);
    Query.Open();
    TotalComanda := Query.DataSet.FieldByName('TOTAL').AsCurrency;
    // verifica se ainda existe itens na comanda
    Query.Clear;
    Query.Add('SELECT SUM(ADI_VALOR * CA_QUANTIDADE) COMPLEMENTOS');
    Query.Add('FROM COM_PRO JOIN COMANDAS ON CP_COM = COM_CODIGO');
    Query.Add('LEFT JOIN CP_ADICIONAIS ON CA_CP = CP_CODIGO');
    Query.Add('LEFT JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO');
    Query.Add('WHERE COM_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', CodigoComanda);
    Query.Open();
    TotalComplementos := Query.DataSet.FieldByName('COMPLEMENTOS').AsCurrency;
    if TotalComanda > 0 then
    begin
      // Atualiza comandas
      Query.Clear;
      Query.Add('UPDATE COMANDAS SET COM_VALOR = :VALOR WHERE COM_CODIGO = :CODIGO');
      Query.AddParam('CODIGO', CodigoComanda);
      Query.AddParam('VALOR', TotalComanda + TotalComplementos);
      Query.ExecSQL;
    end
    else
    begin
      // Atualiza comandas
      Query.Clear;
      Query.Add('UPDATE COMANDAS SET COM_DATA_FECHAMENTO = :DATA WHERE COM_CODIGO = :CODIGO');
      Query.AddParam('DATA', Date);
      Query.AddParam('CODIGO', CodigoComanda);
      Query.ExecSQL;
      // busca codigo da mesa
      Query.Clear;
      Query.Add('SELECT COM_MESA FROM COMANDAS WHERE COM_CODIGO = :CODIGO');
      Query.AddParam('CODIGO', CodigoComanda);
      Query.Open;
      CodigoMesa := Query.DataSet.FieldByName('COM_MESA').AsInteger;
      // Atualiza o estado da mesa
      Query.Clear;
      Query.Add('UPDATE MESAS SET MES_ESTADO = ''A'' WHERE MES_CODIGO = :CODIGO');
      Query.AddParam('CODIGO', CodigoMesa);
      Query.ExecSQL;
    end;
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'Item excluido com sucesso!')).Status(THTTPStatus.OK);
  end
  else
    Res.Send<TJSONObject>(TJSONObject.Create().AddPair('error', 'Codigo da com_pro não informado')).Status(THTTPStatus.BadRequest);
end;

class procedure TComandasController.EncerrarComanda(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Codigo: integer;
begin
  if Req.Params.Count > 0 then
  begin
    Codigo := Req.Params.Items['codigo'].ToInteger();
    Query  := TDatabase.Query;
    Query.Clear;
    Query.Add('UPDATE MESAS SET MES_ESTADO = ''F'' WHERE MES_CODIGO = :CODIGO');
    Query.AddParam('CODIGO', Codigo);
    Query.ExecSQL;
    Res.Send<TJSONObject>(TJSONObject.Create.AddPair('message', 'Mesa ' + Codigo.ToString + ' encerrada com sucesso')).Status(THTTPStatus.OK);
  end
  else
    Res.Send<TJSONObject>(TJSONObject.Create().AddPair('error', 'Codigo da comanda não informado')).Status(THTTPStatus.BadRequest);
end;

class procedure TComandasController.Get(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  QueryComandas, QueryComPro, QueryComplementos: iQuery;
  CodigoComanda: integer;
  Comandas: TJSONArray;
  Comanda: TJSONObject;
  Produtos: TJSONArray;
  Item: TJSONObject;
  Itens: TJSONArray;
  Complemento: TJSONObject;
  Complementos: TJSONArray;
begin
  Comandas      := TJSONArray.Create;
  QueryComandas := TDatabase.Query;
  QueryComandas.Clear;
  QueryComandas.Add('SELECT COM_CODIGO, COM_MESA, COM_DATA_ABERTURA, COM_HORA_ABERTURA, COM_DATA_FECHAMENTO, COM_HORA_FECHAMENTO, COM_DATAC, COM_VALOR, COM_COMANDA FROM COMANDAS');
  QueryComandas.Add('WHERE COM_DATA_FECHAMENTO IS NULL');
  QueryComandas.Open;
  QueryComandas.DataSet.First;
  while not QueryComandas.DataSet.Eof do
  begin
    CodigoComanda := QueryComandas.DataSet.FieldByName('COM_CODIGO').AsInteger;
    Comanda       := QueryComandas.DataSet.ToJSONObject;
    // itens
    QueryComPro := TDatabase.Query;
    QueryComPro.Clear;
    QueryComPro.Add('SELECT CP_CODIGO, CP_COM, CP_PRO, CP_QUANTIDADE, CP_VALOR, ');
    QueryComPro.Add('CP_GRA, CP_OBS, CP_ESTADO, PRO_NOME, CP_USU  ');
    QueryComPro.Add('FROM COM_PRO CP JOIN PRODUTOS ON PRO_CODIGO = CP_PRO WHERE CP_COM = :CODIGO ORDER BY CP_CODIGO');
    QueryComPro.AddParam('CODIGO', CodigoComanda);
    QueryComPro.Open;
    Itens := TJSONArray.Create;
    QueryComPro.DataSet.First;
    while not QueryComPro.DataSet.Eof do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('cpCodigo', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_CODIGO').AsInteger));
      Item.AddPair('cpCom', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_COM').AsInteger));
      Item.AddPair('cpPro', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_PRO').AsInteger));
      Item.AddPair('cpQuantidade', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_QUANTIDADE').AsFloat));
      Item.AddPair('cpValor', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_VALOR').AsCurrency));
      Item.AddPair('cpGra', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_GRA').AsInteger));
      Item.AddPair('cpObs', QueryComPro.DataSet.FieldByName('CP_OBS').AsString);
      Item.AddPair('cpEstado', QueryComPro.DataSet.FieldByName('CP_ESTADO').AsString);
      Item.AddPair('nome', QueryComPro.DataSet.FieldByName('PRO_NOME').AsString);
      Item.AddPair('gradeProduto', BuscaDadosGrade(QueryComPro.DataSet.FieldByName('CP_GRA').AsInteger));
      Item.AddPair('usuario', TJSONNumber.Create(QueryComPro.DataSet.FieldByName('CP_USU').AsInteger));
      QueryComplementos := TDatabase.Query;
      QueryComplementos.Clear;
      QueryComplementos.Add('SELECT CA_CODIGO, CA_CP, CA_ADI, CA_QUANTIDADE, ADI_NOME, ADI_VALOR FROM CP_ADICIONAIS JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO WHERE CA_CP = :COM_PRO ORDER BY CA_CODIGO');
      QueryComplementos.AddParam('COM_PRO', QueryComPro.DataSet.FieldByName('CP_CODIGO').AsInteger);
      QueryComplementos.Open;
      QueryComplementos.DataSet.First;
      Complementos := TJSONArray.Create;
      while not QueryComplementos.DataSet.Eof do
      begin
        Complemento := TJSONObject.Create;
        Complemento.AddPair('codigo', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_CODIGO').AsInteger));
        Complemento.AddPair('nome', QueryComplementos.DataSet.FieldByName('ADI_NOME').AsString);
        Complemento.AddPair('valor', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('ADI_VALOR').AsCurrency));
        Complemento.AddPair('quantidade', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_QUANTIDADE').AsFloat));
        Complementos.AddElement(Complemento);
        QueryComplementos.DataSet.Next;
      end;
      Item.AddPair('complementos', Complementos);
      Itens.AddElement(Item);
      QueryComPro.DataSet.Next;
    end;
    Comanda.AddPair('itens', Itens);
    Comandas.AddElement(Comanda);
    QueryComandas.DataSet.Next;
  end;
  Res.Send<TJSONArray>(Comandas);
end;

class procedure TComandasController.GetItemComPro(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  CodigoComPro: integer;
  QueryComplementos: iQuery;
  Item: TJSONObject;
  Complementos: TJSONArray;
  Complemento: TJSONObject;
  QueryProduto: iQuery;
  oProduto: TJSONObject;
begin
  // Codigo com_pro
  CodigoComPro := Req.Params.Items['codigo'].ToInteger();
  Query        := TDatabase.Query;
  Query.Clear;
  Query.Add('SELECT CP_CODIGO, CP_COM, CP_PRO, CP_QUANTIDADE, CP_VALOR, CP_GRA, ');
  Query.Add('CP_OBS, CP_ESTADO, PRO_NOME, CP_USU ');
  Query.Add('FROM COM_PRO CP JOIN PRODUTOS ON PRO_CODIGO = CP_PRO ');
  Query.Add('WHERE CP_CODIGO = :CODIGO ORDER BY CP_CODIGO');
  Query.AddParam('CODIGO', CodigoComPro);
  Query.Open;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    oProduto     := TJSONObject.Create;
    QueryProduto := TDatabase.Query;
    QueryProduto.Add('SELECT PRO_CODIGO codigo, PRO_NOME nome, PRO_VALORV valor, GRU_G1 categoria ');
    QueryProduto.Add('FROM PRODUTOS LEFT JOIN GRUPOS ON PRO_GRU = GRU_CODIGO WHERE PRO_CODIGO = :CODIGO');
    QueryProduto.AddParam('CODIGO', Query.DataSet.FieldByName('CP_PRO').AsInteger);
    QueryProduto.Open;
    Item := TJSONObject.Create;
    Item.AddPair('cpCodigo', TJSONNumber.Create(Query.DataSet.FieldByName('CP_CODIGO').AsInteger));
    Item.AddPair('cpCom', TJSONNumber.Create(Query.DataSet.FieldByName('CP_COM').AsInteger));
    Item.AddPair('produto', QueryProduto.DataSet.ToJSONObject());
    Item.AddPair('cpQuantidade', TJSONNumber.Create(Query.DataSet.FieldByName('CP_QUANTIDADE').AsFloat));
    Item.AddPair('cpValor', TJSONNumber.Create(Query.DataSet.FieldByName('CP_VALOR').AsCurrency));
    Item.AddPair('cpGra', TJSONNumber.Create(Query.DataSet.FieldByName('CP_GRA').AsInteger));
    Item.AddPair('cpObs', Query.DataSet.FieldByName('CP_OBS').AsString);
    Item.AddPair('cpEstado', Query.DataSet.FieldByName('CP_ESTADO').AsString);
    Item.AddPair('nome', Query.DataSet.FieldByName('PRO_NOME').AsString);
    Item.AddPair('usuario', TJSONNumber.Create(Query.DataSet.FieldByName('CP_USU').AsInteger));
    QueryComplementos := TDatabase.Query;
    QueryComplementos.Clear;
    QueryComplementos.Add('SELECT CA_CODIGO, CA_CP, CA_ADI, CA_QUANTIDADE, ADI_NOME, ADI_VALOR FROM CP_ADICIONAIS JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO WHERE CA_CP = :COM_PRO');
    QueryComplementos.AddParam('COM_PRO', Query.DataSet.FieldByName('CP_CODIGO').AsInteger);
    QueryComplementos.Open;
    QueryComplementos.DataSet.First;
    Complementos := TJSONArray.Create;
    while not QueryComplementos.DataSet.Eof do
    begin
      Complemento := TJSONObject.Create;
      Complemento.AddPair('codigo', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_CODIGO').AsInteger));
      Complemento.AddPair('nome', QueryComplementos.DataSet.FieldByName('ADI_NOME').AsString);
      Complemento.AddPair('valor', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('ADI_VALOR').AsCurrency));
      Complemento.AddPair('quantidade', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_QUANTIDADE').AsFloat));
      Complementos.AddElement(Complemento);
      QueryComplementos.DataSet.Next;
    end;
    Item.AddPair('complementos', Complementos);
    Query.DataSet.Next;
  end;
  Res.Send<TJSONObject>(Item);
end;

class procedure TComandasController.GetPorCodigo(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query, QueryComplementos: iQuery;
  Codigo: integer;
  CodigoComanda: integer;
  Comanda: TJSONObject;
  Produtos: TJSONArray;
  Item: TJSONObject;
  Itens: TJSONArray;
  Complemento: TJSONObject;
  Complementos: TJSONArray;
begin
  if Req.Params.Count = 0 then
    raise Exception.Create('Paramentro "Codigo" não informado!');
  Codigo := Req.Params.Items['codigo'].ToInteger;
  Query  := TDatabase.Query;
  Query.Clear;
  Query.Add('SELECT COM_CODIGO, COM_MESA, COM_DATA_ABERTURA, COM_HORA_ABERTURA, COM_DATA_FECHAMENTO, COM_HORA_FECHAMENTO, COM_DATAC, COM_VALOR, COM_COMANDA FROM COMANDAS');
  Query.Add('WHERE COM_CODIGO = (SELECT MAX(COM_CODIGO) FROM COMANDAS WHERE COM_DATA_FECHAMENTO IS NULL AND COM_MESA = :CODIGO)');
  Query.AddParam('CODIGO', Codigo);
  Query.Open;
  CodigoComanda := Query.DataSet.FieldByName('COM_CODIGO').AsInteger;
  Comanda       := Query.DataSet.ToJSONObject;
  // itens
  Query.Clear;
  Query.Add('SELECT CP_CODIGO, CP_COM, CP_PRO, CP_QUANTIDADE, CP_VALOR, CP_GRA, CP_OBS,');
  Query.Add('CP_ESTADO, PRO_NOME, CP_USU ');
  Query.Add('FROM COM_PRO CP JOIN PRODUTOS ON PRO_CODIGO = CP_PRO ');
  Query.Add('WHERE CP_COM = :CODIGO ORDER BY CP_CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.Open;
  Itens := TJSONArray.Create;
  Query.DataSet.First;
  while not Query.DataSet.Eof do
  begin
    Item := TJSONObject.Create;
    Item.AddPair('cpCodigo', TJSONNumber.Create(Query.DataSet.FieldByName('CP_CODIGO').AsInteger));
    Item.AddPair('cpCom', TJSONNumber.Create(Query.DataSet.FieldByName('CP_COM').AsInteger));
    Item.AddPair('cpPro', TJSONNumber.Create(Query.DataSet.FieldByName('CP_PRO').AsInteger));
    Item.AddPair('cpQuantidade', TJSONNumber.Create(Query.DataSet.FieldByName('CP_QUANTIDADE').AsFloat));
    Item.AddPair('cpValor', TJSONNumber.Create(Query.DataSet.FieldByName('CP_VALOR').AsCurrency));
    Item.AddPair('cpGra', TJSONNumber.Create(Query.DataSet.FieldByName('CP_GRA').AsInteger));
    Item.AddPair('cpObs', Query.DataSet.FieldByName('CP_OBS').AsString);
    Item.AddPair('cpEstado', Query.DataSet.FieldByName('CP_ESTADO').AsString);
    Item.AddPair('nome', Query.DataSet.FieldByName('PRO_NOME').AsString);
    Item.AddPair('gradeProduto', BuscaDadosGrade(Query.DataSet.FieldByName('CP_GRA').AsInteger));
    Item.AddPair('usuario', TJSONNumber.Create(Query.DataSet.FieldByName('CP_USU').AsInteger));
    QueryComplementos := TDatabase.Query;
    QueryComplementos.Clear;
    QueryComplementos.Add('SELECT CA_CODIGO, CA_CP, CA_ADI, CA_QUANTIDADE, ADI_NOME, ADI_VALOR FROM CP_ADICIONAIS JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO WHERE CA_CP = :COM_PRO ORDER BY CA_CODIGO');
    QueryComplementos.AddParam('COM_PRO', Query.DataSet.FieldByName('CP_CODIGO').AsInteger);
    QueryComplementos.Open;
    Complementos := TJSONArray.Create;
    while not QueryComplementos.DataSet.Eof do
    begin
      Complemento := TJSONObject.Create;
      Complemento.AddPair('codigo', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_CODIGO').AsInteger));
      Complemento.AddPair('nome', QueryComplementos.DataSet.FieldByName('ADI_NOME').AsString);
      Complemento.AddPair('valor', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('ADI_VALOR').AsCurrency));
      Complemento.AddPair('quantidade', TJSONNumber.Create(QueryComplementos.DataSet.FieldByName('CA_QUANTIDADE').AsFloat));
      Complementos.AddElement(Complemento);
      QueryComplementos.DataSet.Next;
    end;
    Item.AddPair('complementos', Complementos);
    Itens.AddElement(Item);
    Query.DataSet.Next;
  end;
  Comanda.AddPair('itens', Itens);
  Res.Send<TJSONObject>(Comanda);
end;

class procedure TComandasController.Post(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Query: iQuery;
  Comanda: TModelComanda;
  i: integer;
  CodigoComanda: integer;
  Item: TModelItens;
  CodigoComPro: integer;
  Complementos: TArray<TModelComplemento>;
  c: integer;
  TotalComanda: Currency;
  TotalComplementos: Currency;
begin
  if Req.Body = '' then
    raise Exception.Create('Comanda não encontrada');
  Comanda := TModelComanda.FromJsonString(Req.Body);
  Query   := TDatabase.Query;
  Query.Clear;
  Query.Add('INSERT INTO COMANDAS (COM_CODIGO, COM_MESA, COM_DATA_ABERTURA, COM_HORA_ABERTURA, COM_VALOR)');
  Query.Add('VALUES (GEN_ID(GEN_COM_CODIGO, 1), :MESA, :DATA_ABERTURA, :HORA_ABERTURA, :VALOR) RETURNING COM_CODIGO');
  Query.AddParam('MESA', Comanda.Mesa);
  Query.AddParam('DATA_ABERTURA', Date);
  Query.AddParam('HORA_ABERTURA', Now);
  Query.AddParam('VALOR', Comanda.Valor);
  Query.Open();
  CodigoComanda := Query.DataSet.FieldByName('COM_CODIGO').AsInteger;
  For i := Low(Comanda.Itens) to High(Comanda.Itens) do
  begin
    Item := Comanda.Itens[i];
    Query.Clear;
    Query.Add('UPDATE OR INSERT INTO COM_PRO (CP_CODIGO, CP_COM, CP_PRO, ');
    Query.Add('CP_QUANTIDADE, CP_VALOR, CP_GRA, CP_OBS, CP_ESTADO, CP_USU)');
    Query.Add('VALUES (GEN_ID(GEN_CP_CODIGO, 1), :COM, :PRO, ');
    Query.Add(':QUANTIDADE, :VALOR, :GRA, :OBS, :ESTADO, :USUARIO)');
    Query.Add('MATCHING (CP_CODIGO) RETURNING (CP_CODIGO)');
    Query.AddParam('COM', CodigoComanda);
    Query.AddParam('PRO', Item.Produto);
    Query.AddParam('QUANTIDADE', Item.Quantidade);
    Query.AddParam('VALOR', Item.Valor);
    Query.AddParam('GRA', Item.Grade);
    Query.AddParam('OBS', Item.Obs);
    Query.AddParam('ESTADO', 'A');
    Query.AddParam('USUARIO', Item.usuario);
    Query.Open;
    if not Query.DataSet.IsEmpty then
      CodigoComPro := Query.DataSet.FieldByName('CP_CODIGO').AsInteger;
    if CodigoComPro > 0 then
    begin
      Complementos := Comanda.Itens[i].Complementos;
      for c        := Low(Complementos) to High(Complementos) do
      begin
        Query.Clear;
        Query.Add('INSERT INTO CP_ADICIONAIS (CA_CODIGO, CA_CP, CA_ADI, CA_QUANTIDADE)');
        Query.Add('VALUES (GEN_ID(GEN_CP_ADICIONAIS, 1), :CP, :ADI, :QUANTIDADE);');
        Query.AddParam('CP', CodigoComPro);
        Query.AddParam('ADI', Complementos[c].Codigo);
        Query.AddParam('QUANTIDADE', Complementos[c].Quantidade);
        Query.ExecSQL;
      end;
    end;
  end;
  // soma comanda
  Query.Clear;
  Query.Add('SELECT SUM(CP_VALOR) TOTAL');
  Query.Add('FROM COM_PRO JOIN COMANDAS ON CP_COM = COM_CODIGO');
  Query.Add('WHERE COM_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.Open();
  TotalComanda := Query.DataSet.FieldByName('TOTAL').AsCurrency;
  // verifica se ainda existe itens na comanda
  Query.Clear;
  Query.Add('SELECT SUM(ADI_VALOR * CA_QUANTIDADE) COMPLEMENTOS');
  Query.Add('FROM COM_PRO JOIN COMANDAS ON CP_COM = COM_CODIGO');
  Query.Add('LEFT JOIN CP_ADICIONAIS ON CA_CP = CP_CODIGO');
  Query.Add('LEFT JOIN ADICIONAIS ON CA_ADI = ADI_CODIGO');
  Query.Add('WHERE COM_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.Open();
  TotalComplementos := Query.DataSet.FieldByName('COMPLEMENTOS').AsCurrency;
  // Atualiza comandas
  Query.Clear;
  Query.Add('UPDATE COMANDAS SET COM_VALOR = :VALOR WHERE COM_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', CodigoComanda);
  Query.AddParam('VALOR', TotalComanda + TotalComplementos);
  Query.ExecSQL;
  // Atualiza o estado da mesa
  Query.Clear;
  Query.Add('UPDATE MESAS SET MES_ESTADO = ''O'' WHERE MES_CODIGO = :CODIGO');
  Query.AddParam('CODIGO', Comanda.Mesa);
  Query.ExecSQL;
  Res.Status(THTTPStatus.Created).Send<TJSONObject>(TJSONObject.Create.AddPair('Comanda', TJSONNumber.Create(CodigoComanda)));
end;

class procedure TComandasController.Registrar;
begin
  THorse.Get('/Comandas', Get);
  THorse.Get('/Comandas/:codigo', GetPorCodigo);
  THorse.Post('/Comandas', Post);
  THorse.Put('/Comandas/:codigo/encerrar', EncerrarComanda);
  THorse.Put('/Comandas/:codigo', AtualizarComanda);
  THorse.Get('/Comandas/item/:codigo', GetItemComPro);
  THorse.Delete('/Comandas/:codigo/itens', DeletarItemComanda);
  THorse.Delete('/Comandas/:codigo/complementos', DeletarComplementos);
end;

end.
