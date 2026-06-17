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

  TEmojiViewModes = (ViewModeAll, ViewModeFavourites);

  { TForm1 }

  TForm1 = class(TForm)
    CopyButton: TButton;
    EmojiBufferEdit: TEdit;
    Label1: TLabel;
    AllRadio: TRadioButton;
    FavouritesRadio: TRadioButton;
    SearchEdit: TEdit;
    DescriptionMemo: TMemo;
    ResultGrid: TStringGrid;
    StatusBar1: TStatusBar;

    procedure AllRadioChange(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure FavouritesRadioChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);

    procedure ResultGridDblClick(Sender: TObject);
    procedure ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ResultGridMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ResultGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
    procedure SearchEditChange(Sender: TObject);

  private
    fActualViewMode, lastViewMode: TEmojiViewModes;

    { in seconds, assigned in LoadEmojis }
    loadingTime: double;

    lastSearchTerm: string;

    emojiList: TEmojiList;
    favouriteList: TFavouriteList;

    { Important: Do not own the instances }
    lastEmojiSearchResult: TEmojiList;
    selectedEmoji: TEmoji;

    const
      FavouritesFile = 'favourites.txt';
      DefaultColCount = 8;

    procedure AppendToResult(const content: string);
    procedure ClearGrid;
    { Returns the column number of the last row, otherwise -1 if all cells of the row are occupied }
    function FindEmptyLastCell: smallint;

    function GetSearchTerm: string;
    procedure LoadEmojis;

    procedure SetActualViewMode(value: TEmojiViewModes);

    procedure ShowAllEmojis;
    procedure ShowFavouritedEmojis;

    procedure UpdateSelectedEmoji;
    { This proceedure depends on UpdateSelectedEmoji }
    procedure UpdateSelectionDisplay;

    function IsInFavourites(const codepoints: string): boolean;
    procedure AddFavourite(const codepoints: string);
    procedure RemoveFavourite(const codepoints: string);

    { Returns an object reference to emojiList }
    function FindEmojiByCodepoints(const codepoints: string): TEmoji;

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

function TForm1.FindEmptyLastCell: smallint;
var
  col: smallint;
begin
  FindEmptyLastCell := -1;

  if ResultGrid.RowCount = 0 then exit;
  if ResultGrid.ColCount = 0 then exit;

  for col:=0 to ResultGrid.ColCount - 1 do
    if ResultGrid.cells[col, ResultGrid.RowCount - 1] = '' then begin
      FindEmptyLastCell := col;
      exit
    end;
end;

procedure TForm1.AppendToResult(const content: string);
var
  row, col: smallint;
begin
  if ResultGrid.RowCount = 0 then begin
    ResultGrid.RowCount := 1;
    col := 0
  end;

  col := FindEmptyLastCell;

  if col < 0 then begin
    ResultGrid.RowCount := ResultGrid.RowCount + 1;
    col := 0;
  end;

  row := ResultGrid.RowCount - 1;
  ResultGrid.cells[col, row] := content
end;

procedure TForm1.ShowAllEmojis;
var
  emoji: TEmoji;
begin
  if emojiList = nil then exit;

  ClearGrid;

  for emoji in emojiList do
    AppendToResult(emoji.emoji);

  { DescriptionMemo.text := format(
    'Loaded %d emojis' + LineEnding + 'Enter a few words to search', [
      emojiList.count
    ]); }
end;

procedure TForm1.ShowFavouritedEmojis;
var
  favitem: TFavourite;
begin
  ClearGrid;

  for favitem in favouriteList do
    AppendToResult(FindEmojiByCodepoints(favitem.Codepoints).Emoji);
end;

procedure TForm1.SearchEditChange(Sender: TObject);
var
  localSearchTerm: string;
  emoji: TEmoji;
  favitem: TFavourite;

  startTick, endTick: TDateTime;
begin
  if emojiList = nil then exit;
  if GetSearchTerm = lastSearchTerm then exit;

  lastSearchTerm := GetSearchTerm;
  localSearchTerm := lastSearchTerm;

  if localSearchTerm = '' then begin
    case fActualViewMode of
      ViewModeAll:
        ShowAllEmojis;
      ViewModeFavourites:
        ShowFavouritedEmojis;
    end;

    exit
  end;

  startTick := now;

  lastEmojiSearchResult.clear;

  case fActualViewMode of
    ViewModeAll: begin
      for emoji in emojiList do
        if emoji.LowerCaseDescriptor.contains(localSearchTerm) then
          lastEmojiSearchResult.Add(emoji);
    end;
    ViewModeFavourites: begin
      for favitem in favouriteList do begin
        emoji := FindEmojiByCodepoints(favitem.Codepoints);

        if emoji.LowerCaseDescriptor.Contains(localSearchTerm) then
          lastEmojiSearchResult.add(emoji);
      end;
    end;
  end;

  ClearGrid;

  for emoji in lastEmojiSearchResult do
    AppendToResult(emoji.emoji);

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

  if fActualViewMode = ViewModeAll then begin
    if GetSearchTerm = '' then
      selectedEmoji := emojiList[idx]
    else begin
      if idx >= lastEmojiSearchResult.Count then begin
        selectedEmoji := nil;
        exit
      end;

      selectedEmoji := lastEmojiSearchResult[idx]
    end;
  end;

  if fActualViewMode = ViewModeFavourites then begin
    if GetSearchTerm = '' then begin
      if idx < favouriteList.Count then
        selectedEmoji := FindEmojiByCodepoints(favouriteList[idx].Codepoints)
      else
        selectedEmoji := nil;
    end else begin
      { The same as ViewModeAll }
      if idx >= lastEmojiSearchResult.Count then begin
        selectedEmoji := nil;
        exit
      end;

      selectedEmoji := lastEmojiSearchResult[idx]
    end;
  end;
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
  if selectedEmoji = nil then begin
    DescriptionMemo.text := 'None selected!';
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
  AssignFile(f, FavouritesFile);
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

  if not FileExists(FavouritesFile) then begin
    LoadFavourites := false;
    exit
  end;

  if emojiList = nil then
    raise exception.create('emojiList is not yet loaded!');

  AssignFile(f, FavouritesFile);
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

procedure TForm1.ClearGrid;
begin
  { TStringGrid.Clear also clears ColCount }
  ResultGrid.Clear;

  ResultGrid.ColCount := DefaultColCount;
  ResultGrid.RowCount := 0
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

function TForm1.FindEmojiByCodepoints(const codepoints: string): TEmoji;
var
  e: TEmoji;
begin
  FindEmojiByCodepoints := nil;

  if emojiList = nil then exit;

  for e in emojiList do
    if e.Codepoints = codepoints then begin
      FindEmojiByCodepoints := e;
      exit
    end;
end;


procedure TForm1.FormShow(Sender: TObject);
begin
  LoadEmojis;
  LoadFavourites;

  DescriptionMemo.Text := format(
    'Loaded %d emojis in %.2f seconds', [
      emojiList.count,
      loadingTime]);

  if favouriteList.Count > 0 then
    DescriptionMemo.Append(format('Loaded %d favourites', [favouriteList.count]));

  SearchEdit.clear;
  ClearGrid;

  SetActualViewMode(ViewModeAll);

  lastEmojiSearchResult := TEmojiList.Create(false);
  EmojiBufferEdit.clear;

  { DescriptionMemo.text := format('colcount: %d', [ResultGrid.ColCount]); }

  ShowAllEmojis
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

procedure TForm1.AllRadioChange(Sender: TObject);
begin
  SetActualViewMode(ViewModeAll)
end;

procedure TForm1.FavouritesRadioChange(Sender: TObject);
begin
  SetActualViewMode(ViewModeFavourites)
end;

procedure TForm1.SetActualViewMode(value: TEmojiViewModes);
begin
  fActualViewMode := value;

  if lastViewMode <> fActualViewMode then begin
    lastViewMode := fActualViewMode;

    lastEmojiSearchResult.clear;

    lastSearchTerm := '';
    SearchEdit.Clear;
    ClearGrid;

    case fActualViewMode of
      ViewModeAll:
        ShowAllEmojis;
      ViewModeFavourites:
        ShowFavouritedEmojis;
    end;
  end;
end;

procedure TForm1.ResultGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  UpdateSelectedEmoji;
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

  if button = mbLeft then begin
    UpdateSelectedEmoji;
    UpdateSelectionDisplay;
  end;

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
  if fActualViewMode = ViewModeAll then begin
    idx := arow * ResultGrid.ColCount + acol;

    if (idx < lastEmojiSearchResult.Count)
      and IsInFavourites(lastEmojiSearchResult[idx].Codepoints) then
      ResultGrid.canvas.Brush.Color := clMoneyGreen;
  end;
end;

end.

