unit UnitConnection.Model.Interfaces;

interface

uses
  Data.DB;

  type
    iQuery = interface
      ['{16864F5A-8685-41B9-8201-2DE1440D931F}']
      function Open(Value: string): iQuery;overload;
      function Open: iQuery;overload;
      function Query: TObject;
      function Clear: iQuery;
      function Add(Value: string): iQuery;
      function AddParam(Param: string; Value: variant; Blob: Boolean = false): iQuery;
      function ExecSQL: iQuery;
      function DataSet: TDataSet;
    end;

implementation

end.
