unit UnitQuery.FireDAC.Model;

interface

uses UnitConnection.Model.Interfaces, Data.DB,
     System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
     FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
     FireDAC.Phys, FireDAC.Comp.Client, FireDAC.Phys.FB,
     FireDAC.Phys.FBDef, FireDAC.Phys.IBBase, FireDAC.Stan.Param,
     FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet,
     System.Generics.Collections;

type
  TQueryFiredac = class(TInterfacedObject, iQuery)
    private
      FQuery: TFDQuery;
      FSQL: TStringList;
      FParams: TDictionary<string, variant>;
      FCampoBlob: TDictionary<string, boolean>;
      FIndiceConexao: Integer;
    public
      constructor Create();
      destructor Destroy; override;
      class function New() : iQuery;
      function Open(Value: string): iQuery;overload;
      function Open: iQuery;overload;
      function Add(Value: string): iQuery;
      function AddParam(Param: string; Value: variant; Blob: Boolean = false): iQuery;
      function ExecSQL: iQuery;
      function Query: TObject;
      function Clear: iQuery;
      function DataSet: TDataSet;
  end;

implementation

uses
  System.SysUtils, ServerHorse.Model.Connection;



{ TQueryFireDAC }

function TQueryFiredac.AddParam(Param: string; Value: variant; Blob: Boolean = false): iQuery;
begin
  Result := Self;
  FParams.AddOrSetValue(Param, Value);
  FCampoBlob.AddOrSetValue(Param, Blob);
end;

function TQueryFiredac.Clear: iQuery;
begin
  Result := Self;
  FSQL.Clear;
  FParams.Clear;
  FCampoBlob.Clear;
end;

constructor TQueryFiredac.Create();
begin
  FQuery := TFDQuery.Create(nil);
  FIndiceConexao := ServerHorse.Model.Connection.Connected;
  FQuery.Connection  := ServerHorse.Model.Connection.FConnList.Items[FIndiceConexao];
  FSQL := TStringList.Create;
  FParams := TDictionary<string, variant>.Create;
  FCampoBlob := TDictionary<String, Boolean>.Create;
end;

function TQueryFiredac.DataSet: TDataSet;
begin
  Result := FQuery;
end;

destructor TQueryFiredac.Destroy;
begin
  try
    FSQL.Free;
    FParams.Free;
    FCampoBlob.Free;
    ServerHorse.Model.Connection.Disconnected(FIndiceConexao);
    FreeAndNil(FQuery);
  except on E: Exception do
    raise Exception.Create('Erro destruir objetos query!'+sLineBreak+E.Message)
  end;
  inherited;
end;

function TQueryFiredac.ExecSQL: iQuery;
var
  param: string;
  Valor: Variant;
  campoBlob: Boolean;
begin
  try
    FQuery.Close;
    FQuery.SQL.Clear;
    FQuery.SQL.Add(FSQL.Text);
    if FParams.Keys.Count > 0 then
    begin
      for param in FParams.Keys do
      begin
        if FParams.TryGetValue(param, Valor) then
        begin
          FCampoBlob.TryGetValue(param, campoBlob);
          if campoBlob then
          begin
            FQuery.ParamByName(param).AsString := Valor
          end else
            FQuery.ParamByName(param).Value := Valor;
        end;
      end;
    end;
    FQuery.ExecSQL;
  except on E: exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

class function TQueryFiredac.New() : iQuery;
begin
  result := Self.Create();
end;

function TQueryFiredac.Open: iQuery;
var
  param: string;
  Valor: Variant;
begin
  try
    FQuery.Close;
    FQuery.SQL.Clear;
    FQuery.SQL.Add(FSQL.Text);
    if FParams.Keys.Count > 0 then
    begin
      for param in FParams.Keys do
      begin
        if FParams.TryGetValue(param, Valor) then
          FQuery.ParamByName(param).Value := Valor;
      end;
    end;
    FQuery.Open;
  except on E: exception do
    begin
      raise Exception.Create(E.Message);
    end;
  end;
end;

function TQueryFiredac.Open(Value: string): iQuery;
begin
  Result := Self;
  FQuery.Close;
  FQuery.SQL.Clear;
  FQuery.SQL.Add(Value);
  FQuery.Open;
end;

function TQueryFiredac.Query: TObject;
begin
   Result := FQuery;
end;

function TQueryFiredac.Add(Value: string): iQuery;
begin
  Result := Self;
  FSQL.Add(Value);
end;

end.
