unit Unit1;

{$Mode ObjFPC}
{$H+}
{$Notes OFF}

interface

uses
  { Free Pascal stuff }
  Classes, SysUtils, FGL,

  { Lazarus GUI stuff }
  Forms, Controls, Graphics, Dialogs,
  StdCtrls, Grids, ComCtrls;

type

  { TEmoji }
  TEmoji = class
  private
    fCodepoints: string;
    fDWordCodepoints: array of longword;

    fEmoji: string;
    fDescriptor, fLowerCaseDescriptor: string;

  public
    constructor New;
    constructor New(const rawCodepoints: string);
    constructor New(const rawCodepoints: string; const aDescriptor: string);

    { function Clone: TEmoji; }

    property Codepoints: string read fCodepoints;
    property Emoji: string read fEmoji;
    property Descriptor: string read fDescriptor;
    property LowerCaseDescriptor: string read fLowerCaseDescriptor;

    { Performs conversion from the Emoji string, carried over from TFavourite back then }
    function ToHexCodepoints: string;
  end;

  { TFavourite }

  TFavourite = class
  private
    { fEmoji: TEmoji; }
    fCodepoints: string;
  public
    constructor New(const codepoints: string);

    { property Emoji: TEmoji read fEmoji; }
    property Codepoints: string read fCodepoints;
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
    procedure ResultGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
    procedure SearchEditChange(Sender: TObject);

  private
    { in seconds, assigned in LoadEmojis }
    loadingTime: double;

    lastSearchTerm: string;

    emojiList: TEmojiList;
    favouriteList: TFavouriteList;

    { Important: Do not own the instances }
    lastEmojiSearchResult: TEmojiList;
    selectedEmoji: TEmoji;

    const favouritesFile = 'favourites.txt';

    function GetSearchTerm: string;
    procedure LoadEmojis;
    procedure UpdateSelectedEmoji;
    procedure UpdateSelectionDisplay;

    function IsInFavourites(const codepoints: string): boolean;
    procedure AddFavourite(const codepoints: string);
    procedure RemoveFavourite(const codepoints: string);

    { Returns an object reference to emojiList }
    function FindByCodepoints(const codepoints: string): TEmoji;

    procedure SaveFavourites;
    function LoadFavourites: boolean;
  public

  end;

var
  Form1: TForm1;


implementation

uses Math, Clipbrd, LCL, LazUTF8, Windows;

{$R *.lfm}

{ TEmoji }

constructor TEmoji.New;
begin
end;

constructor TEmoji.New(const rawCodepoints: string);
begin
  new(rawCodepoints, '')
end;

constructor TEmoji.New(const rawCodepoints: string; const aDescriptor: string);
var
  chunks: TStringArray;
  a: word;
  s: string;
begin
  fCodepoints := rawCodepoints;

  chunks := trim(rawCodepoints).Split(' ');
  SetLength(fDWordCodepoints, length(chunks));

  for a := 0 to Length(chunks) - 1 do
    fDWordCodepoints[a] := StrToInt('$' + chunks[a]);

  fEmoji := '';

  for a:=0 to length(fDWordCodepoints) - 1 do
    fEmoji := fEmoji + UnicodeToUTF8(fDWordCodepoints[a]);

  { "(emoji) E0.6 grinning face with big eyes" }
  fDescriptor := trim(aDescriptor);
  chunks := fDescriptor.split(' ');
  chunks := copy(chunks, 2);

  fDescriptor := string.Join(' ', chunks);
  fLowerCaseDescriptor := LowerCase(fDescriptor)
end;

{ function TEmoji.Clone: TEmoji;
begin
  clone := TEmoji.new;

  clone.fEmoji := fEmoji;
  clone.fDWordCodepoints := copy(fDWordCodepoints);
  clone.fDescriptor := fDescriptor;
  Clone.fLowerCaseDescriptor := fLowerCaseDescriptor
end; }

{ TFavourite }

constructor TFavourite.New(const codepoints: string);
begin
  { fEmoji := TEmoji.New(codepoints) }
  fCodepoints := codepoints
end;

function TEmoji.ToHexCodepoints: string;
var
  codepoint: longword;
  len: word;
  c: string;
  idx: word;
  bytesLen: longint;
  strArray: TStringArray;
begin
  ToHexCodepoints := '';

  len := UTF8Length(fEmoji);
  SetLength(strArray, len);

  c := '';

  for idx := 1 to UTF8Length(fEmoji) do begin
    c := UTF8Copy(fEmoji, idx, 1);
    codepoint := UTF8CodepointToUnicode(pchar(c), bytesLen);
    strArray[idx - 1] := format('%X', [codepoint])
  end;

  ToHexCodepoints := string.Join(' ', strArray)
end;


{ TForm1 }

procedure TForm1.SearchEditChange(Sender: TObject);
var
  localSearchTerm: string;
  emoji: temoji;
  col, row: word;
  startTick, endTick: TDateTime;
begin
  if emojiList = nil then exit;
  if GetSearchTerm = lastSearchTerm then exit;

  lastSearchTerm := GetSearchTerm;
  localSearchTerm := GetSearchTerm;

  if localSearchTerm = '' then begin
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
    if emoji.LowerCaseDescriptor.contains(localSearchTerm) then
      lastEmojiSearchResult.Add(emoji);

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

  DescriptionMemo.text := format(
    'Found %d emojis in %.2f seconds' + LineEnding +
    'Right click an emoji to save to favourites', [
      lastEmojiSearchResult.Count, (endTick - startTick) * SecsPerDay
    ]);
end;

procedure TForm1.UpdateSelectedEmoji;
var
  idx: word;
begin
  if emojiList = nil then exit;

  if ResultGrid.SelectedRangeCount = 0 then begin
    selectedEmoji := nil;
    exit
  end;

  idx := ResultGrid.Row * ResultGrid.ColCount + ResultGrid.Col;

  if idx >= lastEmojiSearchResult.Count then begin
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

  loadingTime := (endTick - startTick) * SecsPerDay
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
    selectedEmoji.Descriptor + LineEnding +
    'Codepoints: ' + selectedEmoji.Codepoints;
end;

procedure TForm1.SaveFavourites;
var
  f: text;
  favitem: TFavourite;
begin
  AssignFile(f, favouritesFile);
  Rewrite(f);

  for favitem in favouriteList do
    writeln(f, favitem.Codepoints);

  closefile(f)
end;

function TForm1.LoadFavourites: boolean;
var
  f: text;
  line: string;
  pair: TStringArray;
  rawCodepoints: string;

  chunks: TStringArray;
  hex: string;
  emojiStr: string;

  emoji: TEmoji;

begin
  favouriteList := TFavouriteList.create;

  if not FileExists(favouritesFile) then begin
    LoadFavourites := false;
    exit
  end;

  if emojiList = nil then
    raise exception.create('emojiList is not yet loaded!');

  AssignFile(f, favouritesFile);
  reset(f);

  while not EOF(f) do begin
    readln(f, line);

    if line.Contains('#') then begin
      pair := line.Split('#');
      rawCodepoints := trim(pair[0]);

      if rawCodepoints = '' then continue;
    end else
      rawCodepoints := trim(line);

    AddFavourite(rawCodepoints)
  end;

  closefile(f);

  LoadFavourites := true
end;


function TForm1.GetSearchTerm: string;
begin
  GetSearchTerm := trim(lowercase(SearchEdit.Text))
end;

function TForm1.IsInFavourites(const codepoints: string): boolean;
var
  favitem: TFavourite;
begin
  IsInFavourites := false;

  for favitem in favouriteList do
    if favitem.Codepoints = codepoints then begin
      { DescriptionMemo.text := 'Found "' + codepoints + '" in favs'; }

      IsInFavourites := true;
      exit
    end;
end;

procedure TForm1.AddFavourite(const codepoints: string);
var
  favitem: TFavourite;
begin
  if IsInFavourites(codepoints) then exit;

  favouriteList.Add(TFavourite.new(codepoints));

  DescriptionMemo.text := 'Adding "' + codepoints + '" into favs';
end;

procedure TForm1.RemoveFavourite(const codepoints: string);
var
  a: word;
begin
  if not IsInFavourites(codepoints) then exit;

  for a:=0 to favouriteList.count - 1 do
    if favouriteList[a].codepoints = codepoints then begin
      favouriteList.Delete(a);
      exit
    end;
end;

function TForm1.FindByCodepoints(const codepoints: string): TEmoji;
var
  e: TEmoji;
begin
  FindByCodepoints := nil;

  if emojiList = nil then exit;

  for e in emojiList do
    if e.Codepoints = codepoints then begin
      FindByCodepoints := e;
      exit
    end;
end;


procedure TForm1.FormShow(Sender: TObject);
begin
  SearchEdit.clear;
  DescriptionMemo.clear;
  ResultGrid.Clear;

  lastSearchTerm := '';

  lastEmojiSearchResult := TEmojiList.Create(false);
  EmojiBufferEdit.clear;

  LoadEmojis;
  LoadFavourites;

  DescriptionMemo.Text := format(
    'Loaded %d emojis in %.2f seconds', [
      emojiList.count,
      loadingTime]);

  if favouriteList.Count > 0 then
    DescriptionMemo.Append(format('Loaded %d favourites', [favouriteList.count]));
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

  if button = mbLeft then
    UpdateSelectionDisplay;

  if button = mbRight then begin
    if selectedEmoji <> nil then begin
      if IsInFavourites(selectedEmoji.Codepoints) then
        RemoveFavourite(selectedEmoji.Codepoints)
      else
        AddFavourite(selectedEmoji.Codepoints);

      UpdateSelectionDisplay;
      ResultGrid.InvalidateCell(col, row);
      SaveFavourites
    end;
  end;

end;

procedure TForm1.ResultGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
var
  cell: string;
  idx: word;
  favitem: TFavourite;
begin
  {
  cell := ResultGrid.Cells[acol, arow];

  for favitem in favouriteList do
    if favitem.emoji.emoji = cell then
      ResultGrid.canvas.Brush.Color := clMoneyGreen;
  }

  idx := arow * ResultGrid.ColCount + acol;

  if (idx < lastEmojiSearchResult.Count)
    and IsInFavourites(lastEmojiSearchResult[idx].Codepoints) then
    ResultGrid.canvas.Brush.Color := clMoneyGreen;
end;

end.

