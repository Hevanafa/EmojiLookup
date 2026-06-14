unit Unit1;

{$Mode ObjFPC}
{$H+}
{$Notes OFF}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Graphics, Dialogs, StdCtrls, LazUTF8, FGL;

type

  { TEmoji }
  TEmoji = class
  private
    fCodepoints: array of longword;
    fEmoji: string;
    fDescriptor: string;

  public
    constructor New(const rawCodepoints: string; const aDescriptor: string);
    property Emoji: string read fEmoji;
    property Descriptor: string read fDescriptor;
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

constructor TEmoji.New(const rawCodepoints: string; const aDescriptor: string);
var
  chunks: TStringArray;
  a: word;
  s: string;
begin
  chunks := trim(rawCodepoints).Split(' ');
  SetLength(fCodepoints, length(chunks));

  for a := 0 to Length(chunks) - 1 do
    fCodepoints[a] := StrToInt('$' + chunks[a]);

  fDescriptor := aDescriptor;

  fEmoji := '';

  for a:=0 to length(fCodepoints) - 1 do
    fEmoji := fEmoji + UnicodeToUTF8(fCodepoints[a]);
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

  emoji: TEmoji;
begin
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

    { ResultMemo.Append(rawCodepoints + ': ' + descriptor) }
  end;

  closefile(f);

  for emoji in emojis do
    ResultMemo.append(emoji.Emoji + ': ' + emoji.Descriptor);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  SearchEdit.clear;
  ResultMemo.clear;

  LoadEmojis
end;

end.

