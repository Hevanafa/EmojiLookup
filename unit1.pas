unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Graphics, Dialogs, StdCtrls;

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
var
  f: text;
  line, descriptor: string;
  parts: TStringArray;
begin
  ResultMemo.clear;

  AssignFile(f, 'data\emoji-test.txt');
  {$I-} reset(f); {$I+}

  while not eof(f) do begin
    readln(f, line);

    if line = '' then continue;
    if line.StartsWith('#') then continue;

    parts := line.Split('#');
    line := parts[0];
    line := trim(line);
    descriptor := trim(parts[1]);

    if line = '' then continue;

    ResultMemo.Append(line)
  end;

  closefile(f)
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  LoadEmojis
end;

end.

