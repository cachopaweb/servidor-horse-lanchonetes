unit UnitComanda.Model;

interface

uses UnitComplemento.Model;

type
  TModelItens = class
  private
    FProduto: integer;
    FValor: Currency;
    FQuantidade: Double;
    FEstado: string;
    FObs: string;
    FGrade: integer;
    Fnome: string;
    FComplementos: TArray<TModelComplemento>;
    Fusuario: integer;
  public
    property Produto: integer read FProduto write FProduto;
    property Valor: Currency read FValor write FValor;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property Estado: string read FEstado write FEstado;
    property Obs: string read FObs write FObs;
    property Grade: integer read FGrade write FGrade;
    property nome: string read Fnome write Fnome;
    property usuario: integer read Fusuario write Fusuario;
    property Complementos: TArray<TModelComplemento> read FComplementos write FComplementos;
  end;

  TModelComanda = class
  private
    FMesa: integer;
    FValor: Currency;
    FItens: TArray<TModelItens>;
  public
    property Mesa: integer read FMesa write FMesa;
    property Valor: Currency read FValor write FValor;
    property Itens: TArray<TModelItens> read FItens write FItens;
    class function FromJsonString(JsonString: string): TModelComanda;
    function ToJsonString: string;
  end;

implementation
  uses Rest.Json;

{ TModelComanda }

class function TModelComanda.FromJsonString(JsonString: string): TModelComanda;
begin
  Result := TJson.JsonToObject<TModelComanda>(JsonString)
end;

function TModelComanda.ToJsonString: string;
begin
  Result := TJson.ObjectToJsonString(Self);
end;

end.
