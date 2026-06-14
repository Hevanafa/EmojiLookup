unit Unit1;

{$Mode ObjFPC}
{$H+}
{$Notes OFF}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Graphics, Dialogs, StdCtrls, Grids,
  LazUTF8, FGL, Math;

type

  { TEmoji }
  TEmoji = class
  private
    fCodepoints: array of longword;
    fEmoji: string;
    fDescriptor, fLowerCaseDescriptor: string;

  public
    constructor New(const rawCodepoints: string; const aDescriptor: string);
    property Emoji: string read fEmoji;
    property Descriptor: string read fDescriptor;
    property LowerCaseDescriptor: string read fLowerCaseDescriptor;
  end;

  TEmojiList = specialize TFPGObjectList<TEmoji>;

  { TForm1 }

  TForm1 = class(TForm)
    SearchEdit: TEdit;
    ResultMemo: TMemo;
    ResultGrid: TStringGrid;

    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure SearchEditChange(Sender: TObject);

  private
    emojiList: TEmojiList;
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

  fEmoji := '';

  for a:=0 to length(fCodepoints) - 1 do
    fEmoji := fEmoji + UnicodeToUTF8(fCodepoints[a]);

  { "(emoji) E0.6 grinning face with big eyes" }
  fDescriptor := trim(aDescriptor);
  chunks := fDescriptor.split(' ');
  chunks := copy(chunks, 2);

  fDescriptor := string.Join(' ', chunks);
  fLowerCaseDescriptor := LowerCase(fDescriptor)
end;


{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
var
  searchTerm: string;
  emojis: TEmojiList;
  emoji: temoji;
  col, row: word;
begin
  if emojiList = nil then exit;

  emojis := TEmojiList.create;
  searchTerm := lowercase(SearchEdit.Text);

  for emoji in emojiList do begin
    { for debugging }
    { ResultMemo.Text := 'Attempting to index ' + emoji.Descriptor;
    Invalidate; }

    if emoji.LowerCaseDescriptor.contains(searchTerm) then
      emojis.Add(emoji);
  end;

  ResultGrid.clear;
  ResultGrid.RowCount := ceil(emojis.Count / 8);

  col := 0;  row := 0;

  for emoji in emojis do begin
    ResultGrid.Cells[col, row] := emoji.emoji;

    inc(col);
    if col >= ResultGrid.ColCount then begin
      inc(row);
      col := 0;
    end;
  end;

  emojis.free
end;

procedure TForm1.LoadEmojis;
var
  f: text;
  line, descriptor: string;
  rawCodepoints: string;
  qualified: boolean; { unqualified, minimally-qualified, fully-qualified }
  parts: TStringArray;
  pair: TStringArray;

  emoji: TEmoji;
begin
  emojiList := TEmojiList.create;

  AssignFile(f, 'data\emoji-test.txt');
  {$I-} reset(f); {$I+}

  while not eof(f) do begin
    readln(f, line);

    if line.StartsWith('#') then continue;
    if line = '' then continue;

    parts := line.Split('#');
    line := parts[0];
    line := trim(line);

    pair := line.Split(';');
    qualified := trim(pair[1]) = 'fully-qualified';

    if not qualified then continue;

    { # (emoji_char) E1.0 grinning face }
    descriptor := trim(parts[1]);
    rawCodepoints := trim(pair[0]);
    emojiList.Add(TEmoji.New(rawCodepoints, descriptor));

    { ResultMemo.Append(rawCodepoints + ': ' + descriptor) }
  end;

  closefile(f);

  { for emoji in emojiList do
    ResultMemo.append(emoji.Emoji + ': ' + emoji.Descriptor); }

  ResultMemo.Text := format('Loaded %d emojis', [emojiList.count])
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  SearchEdit.clear;
  ResultMemo.clear;

  LoadEmojis
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FreeAndNil(emojiList)
end;

end.

