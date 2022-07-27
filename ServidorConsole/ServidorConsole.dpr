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
  UnitConstants in '..\Shared\UnitConstants.pas',
  UnitFuncoesComuns in '..\Shared\UnitFuncoesComuns.pas',
  UnitUtils in '..\Shared\UnitUtils.pas',
  UnitComanda.Model in '..\Shared\Model\UnitComanda.Model.pas',
  UnitComplemento.Model in '..\Shared\Model\UnitComplemento.Model.pas',
  UnitDatabase in '..\Shared\Database\UnitDatabase.pas',
  Comandas.Controller in '..\Shared\Controllers\Comandas.Controller.pas',
  Complementos.Controller in '..\Shared\Controllers\Complementos.Controller.pas',
  Login.Controller in '..\Shared\Controllers\Login.Controller.pas',
  Mesas.Controller in '..\Shared\Controllers\Mesas.Controller.pas',
  Produtos.Controller in '..\Shared\Controllers\Produtos.Controller.pas',
  ServerHorse.Model.Connection in '..\Shared\Connection\ServerHorse.Model.Connection.pas',
  UnitConnection.Model.Interfaces in '..\Shared\Connection\UnitConnection.Model.Interfaces.pas',
  UnitQuery.FireDAC.Model in '..\Shared\Connection\Query\UnitQuery.FireDAC.Model.pas';

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
