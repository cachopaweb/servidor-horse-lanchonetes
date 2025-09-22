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
  UnitComanda.Model in '..\Shared\Model\UnitComanda.Model.pas',
  UnitComplemento.Model in '..\Shared\Model\UnitComplemento.Model.pas',
  Comandas.Controller in '..\Shared\Controllers\Comandas.Controller.pas',
  Complementos.Controller in '..\Shared\Controllers\Complementos.Controller.pas',
  Mesas.Controller in '..\Shared\Controllers\Mesas.Controller.pas',
  Produtos.Controller in '..\Shared\Controllers\Produtos.Controller.pas',
  UnitDatabase in '..\..\..\FormsComuns\Classes\ServidoresUtils\Database\UnitDatabase.pas',
  UnitConstants in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitConstants.pas',
  UnitDataset.Controller in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitDataset.Controller.pas',
  UnitFuncoesComuns.Controller in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitFuncoesComuns.Controller.pas',
  UnitFuncoesComuns in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitFuncoesComuns.pas',
  UnitFunctions in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitFunctions.pas',
  UnitLogin.Controller in '..\..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitLogin.Controller.pas';

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
      TLoginController.Router;
      TMesasController.Registrar;
      TComandasController.Registrar;
      TProdutosController.Registrar;
      TComplementosController.Registrar;
      TFuncoesComunsController.Router;

      //start server
      THorse.Listen(9000,
      procedure
      begin
        Writeln('Servidor rodando na porta', ': ', THorse.Port.ToString);
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
