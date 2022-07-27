unit UnitFuncoesComuns;

interface
uses
  IdCoderMIME,
  System.Classes;


function ConvertFileToBase64(const FileName: string): string;
function EnDecryptString(StrValue: String; Chave: Word): String;

implementation

uses
  System.SysUtils, Winapi.Windows;

function ConvertFileToBase64(const FileName: string): string;
var
  LInput : TFileStream;
  base64: TIdEncoderMIME;
begin
  Result := '';
  if FileName = '' then
    Exit;
  base64 := TIdEncoderMIME.Create(nil);
  LInput := TFileStream.Create(FileName, fmOpenRead);
  try
    LInput.Position := 0;
    Result := TIdEncoderMIME.EncodeStream(LInput);
  finally
    LInput.Free;
  end;
end;

function EnDecryptString(StrValue: String; Chave: Word): String;
var
  i: integer;
  OutValue: String;
begin
  OutValue   := '';
  for i      := 1 to Length(StrValue) do
    OutValue := OutValue + AnsiChar(Not(Ord(StrValue[i]) - Chave));
  Result     := OutValue;
end;

end.
