unit Unit1;

{$Mode ObjFPC}
{$H+}
{$Notes OFF}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Graphics, Dialogs, StdCtrls, Grids,
  LazUTF8, FGL, Math, Clipbrd, ComCtrls;

type

  { TEmoji }
  TEmoji = class
  private
    fCodepoints: array of longword;
    fEmoji: string;
    fDescriptor, fLowerCaseDescriptor: string;

  public
    constructor New;
    constructor New(const rawCodepoints: string; const aDescriptor: string);
    function Clone: TEmoji;

    property Emoji: string read fEmoji write fEmoji;
    property Descriptor: string read fDescriptor write fDescriptor;
    property LowerCaseDescriptor: string read fLowerCaseDescriptor write fLowerCaseDescriptor;
  end;

  TEmojiList = specialize TFPGObjectList<TEmoji>;

  { TForm1 }

  TForm1 = class(TForm)
    SearchEdit: TEdit;
    DescriptionMemo: TMemo;
    ResultGrid: TStringGrid;
    StatusBar1: TStatusBar;

    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure ResultGridDblClick(Sender: TObject);
    procedure ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ResultGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SearchEditChange(Sender: TObject);

    { Returns an empty string if there's nothing selected }
    { function GetSelectedEmoji: TEmoji; }
    procedure UpdateSelectedEmoji;

  private
    emojiList: TEmojiList;

    lastEmojiSearchResult: TEmojiList;
    selectedEmoji: TEmoji;

    procedure LoadEmojis;
    procedure UpdateSelectionDisplay;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TEmoji }

constructor TEmoji.New;
begin
end;

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

function TEmoji.Clone: TEmoji;
begin
  clone := TEmoji.new;

  clone.fEmoji := fEmoji;
  clone.fCodepoints := copy(fCodepoints);
  clone.fDescriptor := fDescriptor;
  Clone.fLowerCaseDescriptor := fLowerCaseDescriptor
end;


{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
var
  searchTerm: string;
  emoji: temoji;
  col, row: word;
begin
  if emojiList = nil then exit;

  searchTerm := lowercase(trim(SearchEdit.Text));
  if searchTerm = '' then begin
    ResultGrid.clear;
    exit;
  end;

  { emojis := TEmojiList.create; }
  lastEmojiSearchResult.clear;

  for emoji in emojiList do begin
    { for debugging }
    { DescriptionMemo.Text := 'Attempting to index ' + emoji.Descriptor;
    Invalidate; }

    if emoji.LowerCaseDescriptor.contains(searchTerm) then
      lastEmojiSearchResult.Add(emoji.clone);
  end;

  ResultGrid.clear;
  ResultGrid.RowCount := ceil(lastEmojiSearchResult.Count / 8);

  col := 0;  row := 0;

  for emoji in lastEmojiSearchResult do begin
    ResultGrid.Cells[col, row] := emoji.emoji;

    inc(col);
    if col >= ResultGrid.ColCount then begin
      inc(row);
      col := 0;
    end;
  end;

  { emojis.clear;
  emojis.free }
end;

procedure TForm1.UpdateSelectedEmoji;
var
  idx: word;
begin
  if emojiList = nil then exit;

  if ResultGrid.SelectedRangeCount = 0 then begin
    { FreeAndNil(selectedEmoji); }
    selectedEmoji := nil;
    exit
  end;

  idx := ResultGrid.Row * ResultGrid.ColCount + ResultGrid.Col;

  if idx >= lastEmojiSearchResult.Count then begin
    { FreeAndNil(selectedEmoji); }
    selectedEmoji := nil;
    exit
  end;

  selectedEmoji := lastEmojiSearchResult[idx]
end;

{ function TForm1.GetSelectedEmoji: string;
begin
  GetSelectedEmoji := '';
  if ResultGrid.SelectedRangeCount = 0 then exit;

  GetSelectedEmoji := ResultGrid.Cells[ResultGrid.Col, ResultGrid.Row]
end; }



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

    { DescriptionMemo.Append(rawCodepoints + ': ' + descriptor) }
  end;

  closefile(f);

  { for emoji in emojiList do
    DescriptionMemo.append(emoji.Emoji + ': ' + emoji.Descriptor); }

  DescriptionMemo.Text := format('Loaded %d emojis', [emojiList.count])
end;

procedure TForm1.UpdateSelectionDisplay;
begin
  if ResultGrid.SelectedRangeCount = 0 then begin
    DescriptionMemo.text := 'None selected!';
    exit
  end;

  UpdateSelectedEmoji;

  if selectedEmoji = nil then begin
    DescriptionMemo.clear;
    exit
  end;

  DescriptionMemo.Text :=
    selectedEmoji.Descriptor; { LineEnding }
    { 'Codepoints: ' + selectedEmoji.codepo; }
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  SearchEdit.clear;
  DescriptionMemo.clear;
  ResultGrid.Clear;

  lastEmojiSearchResult := TEmojiList.create;

  LoadEmojis
end;

procedure TForm1.ResultGridDblClick(Sender: TObject);
begin
  if selectedEmoji = nil then exit;
  Clipboard.AsText := selectedEmoji.Emoji
end;

procedure TForm1.ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  UpdateSelectionDisplay
end;

procedure TForm1.ResultGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  UpdateSelectionDisplay
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  freeandnil(lastEmojiSearchResult);
  FreeAndNil(emojiList)
end;

end.

