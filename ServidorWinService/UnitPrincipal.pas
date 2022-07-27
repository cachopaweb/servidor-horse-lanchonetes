unit UnitPrincipal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.SvcMgr,
  Vcl.Dialogs,
  Horse,
  Horse.CORS,
  Horse.Jhonson,
  Horse.HandleException;

type
  TTMainService = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceCreate(Sender: TObject);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  TMainService: TTMainService;

implementation

{$R *.dfm}

uses Comandas.Controller,
     Login.Controller,
     Mesas.Controller,
     Produtos.Controller,
     Complementos.Controller;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  TMainService.Controller(CtrlCode);
end;

function TTMainService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TTMainService.ServiceCreate(Sender: TObject);
begin
  //midlewares
  THorse.Use(CORS);
  THorse.Use(Jhonson);
  THorse.Use(HandleException);
  //Controllers
  TLoginController.Registrar;
  TMesasController.Registrar;
  TComandasController.Registrar;
  TProdutosController.Registrar;
  TComplementosController.Registrar;
end;

procedure TTMainService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  THorse.Listen(9000);
  Started := true;
end;

procedure TTMainService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  THorse.StopListen;
  Stopped := true;
end;

end.
