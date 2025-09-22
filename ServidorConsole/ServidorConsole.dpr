program ServidorConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Horse,
  Horse.CORS,
  Horse.Jhonson,
  Horse.HandleException,
  Horse.Logger,
  Horse.Logger.Provider.Console,
  Horse.ServerStatic,
  UnitConstants in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitConstants.pas',
  UnitFuncoesComuns in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitFuncoesComuns.pas',
  UnitUtils in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitUtils.pas',
  UnitComanda.Model in '..\Shared\Model\UnitComanda.Model.pas',
  UnitComplemento.Model in '..\Shared\Model\UnitComplemento.Model.pas',
  UnitDatabase in '..\..\..\FormsComuns\Classes\FuncoesComuns\Database\UnitDatabase.pas',
  Comandas.Controller in '..\Shared\Controllers\Comandas.Controller.pas',
  Complementos.Controller in '..\Shared\Controllers\Complementos.Controller.pas',
  UnitLogin.Controller in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitLogin.Controller.pas',
  Mesas.Controller in '..\Shared\Controllers\Mesas.Controller.pas',
  Produtos.Controller in '..\Shared\Controllers\Produtos.Controller.pas',
  UnitFuncoesComuns.Controller in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitFuncoesComuns.Controller.pas',
  UnitFunctions in '..\..\..\FormsComuns\Classes\FuncoesComuns\UnitFunctions.pas';

var
  LLogFileConfig: THorseLoggerConsoleConfig;
begin
  ReportMemoryLeaksOnShutdown := True;
  LLogFileConfig := THorseLoggerConsoleConfig.New
                           .SetLogFormat('${request_clientip} [${time}] ${response_status}');
  try
    try
      THorseLoggerManager.RegisterProvider(THorseLoggerProviderConsole.New());
      //middlewares
      THorse.Use(CORS);
      THorse.Use(Jhonson);
      THorse.Use(THorseLoggerManager.HorseCallback);
      THorse.Use(HandleException);
      THorse.Use(ServerStatic('site'));

      //Controllers
      TLoginController.Registrar;
      TMesasController.Registrar;
      TComandasController.Registrar;
      TProdutosController.Registrar;
      TComplementosController.Registrar;
      TFuncoesComunsController.Router;

      //start server
      THorse.Listen(9000,
      procedure (App: THorse)
      begin
        Writeln('Servidor rodando na porta', ': ', App.Port.ToString);
        Readln;
      end);
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    LLogFileConfig.Free;
  end;
end.
