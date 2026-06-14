unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Graphics, Dialogs, StdCtrls, LazUTF8, FGL;

type

  { TEmoji }
  TEmoji = class
  private
    parsed: string;
    description: string;

  public
    constructor New(const rawCodepoints: string; const aDescription: string);
  end;

  TEmojiList = specialize TFPGObjectList<TEmoji>;

  { TForm1 }

  TForm1 = class(TForm)
    SearchEdit: TEdit;
    ResultMemo: TMemo;

    procedure FormShow(Sender: TObject);
    procedure SearchEditChange(Sender: TObject);

  private
    emojis: TEmojiList;
    procedure LoadEmojis;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TEmoji }

constructor TEmoji.New(const rawCodepoints: string; const aDescription: string);
var
  chunks: TStringArray;
  a: word;
  s: string;
  codepoints: array of longword;
begin
  chunks := trim(rawCodepoints).Split(' ');
  SetLength(codepoints, length(chunks));

  for a := 0 to Length(chunks) - 1 do
    codepoints[a] := StrToInt('$' + chunks[a]);
end;

{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
begin

end;

procedure TForm1.LoadEmojis;
var
  f: text;
  line, descriptor: string;
  pair: TStringArray;
  rawCodepoints: string;
  qualified: boolean; { unqualified, minimally-qualified, fully-qualified }
  parts: TStringArray;
begin
  ResultMemo.clear;

  emojis := TEmojiList.create;

  AssignFile(f, 'data\emoji-test.txt');
  {$I-} reset(f); {$I+}

  while not eof(f) do begin
    readln(f, line);

    if line.StartsWith('#') then continue;
    if line = '' then continue;

    parts := line.Split('#');
    line := parts[0];
    line := trim(line);

    { # (emoji_char) E1.0 grinning face }
    descriptor := trim(parts[1]);

    pair := line.Split(';');
    rawCodepoints := trim(pair[0]);
    qualified := trim(pair[1]) = 'fully-qualified';

    if not qualified then continue;

    emojis.Add(TEmoji.New(rawCodepoints, descriptor));

    ResultMemo.Append(rawCodepoints + ': ' + descriptor)
  end;

  closefile(f)
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  LoadEmojis
end;

end.

