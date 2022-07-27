unit UnitDatabase;

interface
uses
  UnitConnection.Model.Interfaces,
  UnitQuery.FireDAC.Model;

type
  TDatabase = class
    class function Query: iQuery;
  end;

implementation

{ TDatabase }

uses UnitConstants;

class function TDatabase.Query: iQuery;
begin
  Result := TQueryFireDAC.New;
end;

end.
