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

  { TFavourite }

  TFavourite = class
  private
    fEmoji: TEmoji;
  public
    constructor New(emoji: TEmoji);
    property Emoji: TEmoji read fEmoji;
    function ToHexCodepoints: string;
  end;

  TEmojiList = specialize TFPGObjectList<TEmoji>;
  TFavouriteList = specialize TFPGObjectList<TFavourite>;

  { TForm1 }

  TForm1 = class(TForm)
    CopyButton: TButton;
    EmojiBufferEdit: TEdit;
    Label1: TLabel;
    SearchEdit: TEdit;
    DescriptionMemo: TMemo;
    ResultGrid: TStringGrid;
    StatusBar1: TStatusBar;

    procedure CopyButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);

    procedure ResultGridDblClick(Sender: TObject);
    procedure ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ResultGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SearchEditChange(Sender: TObject);

  private
    emojiList: TEmojiList;
    favouriteList: TFavouriteList;

    lastEmojiSearchResult: TEmojiList;
    selectedEmoji: TEmoji;

    const favouritesFile = 'favourites.txt';

    procedure LoadEmojis;
    procedure UpdateSelectedEmoji;
    procedure UpdateSelectionDisplay;

    procedure SaveFavourites;
    function LoadFavourites: boolean;
  public

  end;

var
  Form1: TForm1;


implementation

uses Windows;

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

{ TFavourite }

constructor TFavourite.New(emoji: TEmoji);
begin
  fEmoji := emoji.clone
end;

function TFavourite.ToHexCodepoints: string;
var
  codepoint: longword;
  len: word;
  c: string;
  idx: word;
  bytesLen: longint;
  strArray: TStringArray;
begin
  ToHexCodepoints := '';

  len := UTF8Length(fEmoji.Emoji);
  SetLength(strArray, len);

  c := '';

  for idx := 1 to UTF8Length(fEmoji.emoji) do begin
    c := UTF8Copy(fEmoji.emoji, idx, 1);
    codepoint := UTF8CodepointToUnicode(pchar(c), bytesLen);
    strArray[idx - 1] := format('%X', [codepoint])
  end;

  ToHexCodepoints := string.Join(' ', strArray)
end;


{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
var
  searchTerm: string;
  emoji: temoji;
  col, row: word;
  startTick, endTick: TDateTime;
begin
  if emojiList = nil then exit;

  searchTerm := lowercase(trim(SearchEdit.Text));
  if searchTerm = '' then begin
    ResultGrid.clear;
    DescriptionMemo.text := format(
      'Loaded %d emojis' + LineEnding + 'Enter a few words to search', [
        emojiList.count
      ]);

    exit;
  end;

  startTick := now;

  lastEmojiSearchResult.clear;

  for emoji in emojiList do
    if emoji.LowerCaseDescriptor.contains(searchTerm) then
      lastEmojiSearchResult.Add(emoji.clone);

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

  endTick := now;

  DescriptionMemo.text := format('Found %d emojis in %.2f seconds', [
    lastEmojiSearchResult.Count, (endTick - startTick) * SecsPerDay
  ]);
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

procedure TForm1.LoadEmojis;
var
  f: text;
  line, descriptor: string;
  rawCodepoints: string;
  qualified: boolean; { unqualified, minimally-qualified, fully-qualified }
  parts: TStringArray;
  pair: TStringArray;

  emoji: TEmoji;
  startTick, endTick: TDateTime;
begin
  emojiList := TEmojiList.create;

  startTick := now;

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

  endTick := now;

  { for emoji in emojiList do
    DescriptionMemo.append(emoji.Emoji + ': ' + emoji.Descriptor); }

  DescriptionMemo.Text := format(
    'Loaded %d emojis in %.2f seconds', [
      emojiList.count,
      (endTick - startTick) * SecsPerDay])
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

procedure TForm1.SaveFavourites;
var
  f: text;
  favitem: TFavourite;
begin
  AssignFile(f, favouritesFile);
  Rewrite(f);

  for favitem in favouriteList do
    writeln(f, favitem.ToHexCodepoints);

  closefile(f)
end;

function TForm1.LoadFavourites: boolean;
begin
  LoadFavourites := false
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  SearchEdit.clear;
  DescriptionMemo.clear;
  ResultGrid.Clear;

  favouriteList := TFavouriteList.create;

  lastEmojiSearchResult := TEmojiList.create;
  EmojiBufferEdit.clear;

  LoadEmojis
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FreeAndNil(lastEmojiSearchResult);
  FreeAndNil(favouriteList);
  FreeAndNil(emojiList)
end;

procedure TForm1.ResultGridDblClick(Sender: TObject);
begin
  if selectedEmoji = nil then exit;

  EmojiBufferEdit.Text := EmojiBufferEdit.Text + selectedEmoji.emoji
end;

procedure TForm1.CopyButtonClick(Sender: TObject);
begin
  if trim(EmojiBufferEdit.Text) = '' then begin
    MessageBox(0, 'No emojis to copy!', 'Empty Box', MB_OK);
    exit
  end;

  Clipboard.AsText := EmojiBufferEdit.text;

  MessageBox(0, 'Copied to clipboard!', 'Copy Emoji', MB_OK)
end;

procedure TForm1.ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  UpdateSelectionDisplay
end;

procedure TForm1.ResultGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  col, row: longint;
begin
  { Select cell at position }
  ResultGrid.MouseToCell(x, y, col, row);

  if (col >= 0) and (row >= 0) then begin
    ResultGrid.Col := col;
    ResultGrid.row := row;
  end;

  ResultGrid.SetFocus;

  UpdateSelectionDisplay;

  if button = mbRight then begin
    if selectedEmoji <> nil then begin
      favouriteList.Add(TFavourite.new(selectedEmoji));

      { DescriptionMemo.text := favouriteList[favouriteList.Count - 1].Emoji.Emoji; }
      { DescriptionMemo.text := favouriteList[favouriteList.Count - 1].ToHexCodepoints }

      SaveFavourites
    end;
  end;
end;

end.

