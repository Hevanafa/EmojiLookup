unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    SearchEdit: TEdit;
    ResultMemo: TMemo;

    procedure FormShow(Sender: TObject);
    procedure SearchEditChange(Sender: TObject);

  private
    procedure LoadEmojis;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
begin

end;

procedure TForm1.LoadEmojis;
begin

end;

procedure TForm1.FormShow(Sender: TObject);
begin
  LoadEmojis
end;

end.

