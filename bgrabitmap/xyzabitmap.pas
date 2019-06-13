unit XYZABitmap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BGRABitmapTypes, UniversalDrawer;

type

  { TXYZABitmap }

  TXYZABitmap = class(specialize TGenericUniversalBitmap<TXYZA,TXYZAColorspace>)
  protected
    function InternalNew: TCustomUniversalBitmap; override;
  public
    class procedure SolidBrush(out ABrush: TUniversalBrush; const AColor: TXYZA; ADrawMode: TDrawMode = dmDrawWithTransparency); override;
    class procedure ScannerBrush(out ABrush: TUniversalBrush; AScanner: IBGRAScanner; ADrawMode: TDrawMode = dmDrawWithTransparency;
                                 AOffsetX: integer = 0; AOffsetY: integer = 0); override;
    class procedure EraseBrush(out ABrush: TUniversalBrush; AAlpha: Word); override;
    class procedure AlphaBrush(out ABrush: TUniversalBrush; AAlpha: Word); override;
    procedure ReplaceImaginary(const AAfter: TXYZA);
  end;

const
  XYZATransparent : TXYZA = (X:0; Y:0; Z:0; alpha:0);

operator = (const c1, c2: TXYZA): boolean; inline;
function IsRealColor(xyza: TXYZA): boolean;

implementation

uses BGRAFillInfo, Math;

operator = (const c1, c2: TXYZA): boolean;
begin
  if (c1.alpha = 0) and (c2.alpha = 0) then
    Result := True
  else
    Result := (c1.alpha = c2.alpha) and (c1.X = c2.X) and
      (c1.Y = c2.Y) and (c1.Z = c2.Z);
end;

var
  xyHorseshoePolygon: TFillShapeInfo;

procedure MakeXYHorseshoePolygon;
var
  pts: array of TPointF;
  i: Integer;
  n: Single;
begin
  setlength(pts, length(SpectralLocus));
  for i := 0 to high(pts) do
  begin
    n := SpectralLocus[i].X+SpectralLocus[i].Y+SpectralLocus[i].Z;
    pts[i].x := SpectralLocus[i].X/n;
    pts[i].y := SpectralLocus[i].Y/n;
  end;
  xyHorseshoePolygon := TFillPolyInfo.Create(pts, false);
  pts := nil;
end;

function IsRealColor(xyza: TXYZA): boolean;
var
  n: Single;
begin
  if (xyza.Y < 0) or (xyza.Y > 1) or (xyza.X < 0) or (xyza.Z < 0) then exit(false);
  if (xyza.Y = 0) then exit((xyza.X=0) and (xyza.Z=0));
  if xyHorseshoePolygon = nil then MakeXYHorseshoePolygon;
  n := xyza.X + xyza.Y + xyza.Z;
  result := xyHorseshoePolygon.IsPointInside(xyza.X/n, xyza.Y/n, false);
end;

procedure XYZASolidBrushSkipPixels({%H-}AFixedData: Pointer;
    AContextData: PUniBrushContext; {%H-}AAlpha: Word; ACount: integer);
begin
  inc(PXYZA(AContextData^.Dest), ACount);
end;

procedure XYZASolidBrushSetPixels(AFixedData: Pointer;
    AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
const oneOver65535 = 1/65535;
var
  pSrc,pDest: PXYZA;
  alphaOver, finalAlpha, finalAlphaInv, residualAlpha: single;
begin
  if AAlpha=0 then
  begin
    inc(PXYZA(AContextData^.Dest), ACount);
    exit;
  end;
  pDest := PXYZA(AContextData^.Dest);
  if AAlpha=65535 then
  begin
    while ACount > 0 do
    begin
      pDest^ := PXYZA(AFixedData)^;
      inc(pDest);
      dec(ACount);
    end;
  end else
  begin
    pSrc := PXYZA(AFixedData);
    alphaOver := AAlpha*single(oneOver65535);
    while ACount > 0 do
    begin
      residualAlpha := pDest^.alpha*(1-alphaOver);
      finalAlpha := residualAlpha + pSrc^.alpha*alphaOver;
      if finalAlpha <= 0 then pDest^ := XYZATransparent else
      begin
        pDest^.alpha:= finalAlpha;
        finalAlphaInv := 1/finalAlpha;
        pDest^.X := (pDest^.X*residualAlpha +
                     pSrc^.X*(finalAlpha-residualAlpha) ) * finalAlphaInv;
        pDest^.Y := (pDest^.Y*residualAlpha +
                     pSrc^.Y*(finalAlpha-residualAlpha) ) * finalAlphaInv;
        pDest^.Z := (pDest^.Z*residualAlpha +
                     pSrc^.Z*(finalAlpha-residualAlpha) ) * finalAlphaInv;
      end;
      inc(pDest);
      dec(ACount);
    end;
  end;
  PXYZA(AContextData^.Dest) := pDest;
end;

procedure XYZASolidBrushDrawPixels(AFixedData: Pointer;
    AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
const oneOver65535 = 1/65535;
var
  pSrc,pDest: PXYZA;
  alphaOver, finalAlpha, finalAlphaInv, residualAlpha: single;
begin
  if AAlpha=0 then
  begin
    inc(PXYZA(AContextData^.Dest), ACount);
    exit;
  end;
  pSrc := PXYZA(AFixedData);
  pDest := PXYZA(AContextData^.Dest);
  alphaOver := pSrc^.alpha*AAlpha*single(oneOver65535);
  while ACount > 0 do
  begin
    residualAlpha := pDest^.alpha*(1-alphaOver);
    finalAlpha := residualAlpha + alphaOver;
    if finalAlpha <= 0 then pDest^ := XYZATransparent else
    begin
      pDest^.alpha:= finalAlpha;
      finalAlphaInv := 1/finalAlpha;
      pDest^.X := (pDest^.X*residualAlpha +
                   pSrc^.X*alphaOver ) * finalAlphaInv;
      pDest^.Y := (pDest^.Y*residualAlpha +
                   pSrc^.Y*alphaOver ) * finalAlphaInv;
      pDest^.Z := (pDest^.Z*residualAlpha +
                   pSrc^.Z*alphaOver ) * finalAlphaInv;
    end;
    inc(pDest);
    dec(ACount);
  end;
  PXYZA(AContextData^.Dest) := pDest;
end;

type
  PXYZAScannerBrushFixedData = ^TXYZAScannerBrushFixedData;
  TXYZAScannerBrushFixedData = record
    Scanner: Pointer; //avoid ref count by using pointer type
    OffsetX, OffsetY: integer;
  end;

procedure XYZAScannerBrushInitContext(AFixedData: Pointer;
  AContextData: PUniBrushContext);
begin
  with PXYZAScannerBrushFixedData(AFixedData)^ do
    IBGRAScanner(Scanner).ScanMoveTo(AContextData^.Ofs.X + OffsetX,
                                     AContextData^.Ofs.Y + OffsetY);
end;

procedure XYZAScannerBrushSetPixels(AFixedData: Pointer;
  AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
var
  src: TXYZA;
begin
  with PXYZAScannerBrushFixedData(AFixedData)^ do
  begin
    if AAlpha = 0 then
    begin
      inc(PXYZA(AContextData^.Dest), ACount);
      IBGRAScanner(Scanner).ScanSkipPixels(ACount);
      exit;
    end;
    while ACount > 0 do
    begin
      src := IBGRAScanner(Scanner).ScanNextExpandedPixel.ToXYZA;
      XYZASolidBrushSetPixels(@src, AContextData, AAlpha, 1);
      dec(ACount);
    end;
  end;
end;

procedure XYZAScannerBrushSetPixelsExceptTransparent(AFixedData: Pointer;
  AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
var
  src: TXYZA;
  expPix: TExpandedPixel;
begin
  with PXYZAScannerBrushFixedData(AFixedData)^ do
  begin
    if AAlpha = 0 then
    begin
      inc(PXYZA(AContextData^.Dest), ACount);
      IBGRAScanner(Scanner).ScanSkipPixels(ACount);
      exit;
    end;
    while ACount > 0 do
    begin
      expPix := IBGRAScanner(Scanner).ScanNextExpandedPixel;
      if expPix.alpha = 65535 then
      begin
        src := expPix.ToXYZA;
        XYZASolidBrushSetPixels(@src, AContextData, AAlpha, 1);
      end else
        inc(PXYZA(AContextData^.Dest));
      dec(ACount);
    end;
  end;
end;

procedure XYZAScannerBrushDrawPixels(AFixedData: Pointer;
  AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
var
  src: TXYZA;
  expPix: TExpandedPixel;
begin
  with PXYZAScannerBrushFixedData(AFixedData)^ do
  begin
    if AAlpha = 0 then
    begin
      inc(PXYZA(AContextData^.Dest), ACount);
      IBGRAScanner(Scanner).ScanSkipPixels(ACount);
      exit;
    end;
    while ACount > 0 do
    begin
      expPix := IBGRAScanner(Scanner).ScanNextExpandedPixel;
      if expPix.alpha = 65535 then
      begin
        src := expPix.ToXYZA;
        XYZASolidBrushSetPixels(@src, AContextData, AAlpha, 1);
      end else if expPix.alpha > 0 then
      begin
        src := expPix.ToXYZA;
        XYZASolidBrushDrawPixels(@src, AContextData, AAlpha, 1);
      end else
        inc(PXYZA(AContextData^.Dest));
      dec(ACount);
    end;
  end;
end;

procedure XYZAAlphaBrushSetPixels(AFixedData: Pointer;
    AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
const oneOver65535 = 1/65535;
var
  pDest: PXYZA;
  alphaOver, residualAlpha, finalAlpha: single;
begin
  if AAlpha=0 then
  begin
    inc(PXYZA(AContextData^.Dest), ACount);
    exit;
  end;
  pDest := PXYZA(AContextData^.Dest);
  if AAlpha=65535 then
  begin
    finalAlpha := PSingle(AFixedData)^;
    while ACount > 0 do
    begin
      pDest^.alpha := finalAlpha;
      inc(pDest);
      dec(ACount);
    end;
  end else
  begin
    alphaOver := AAlpha*single(oneOver65535);
    while ACount > 0 do
    begin
      residualAlpha := pDest^.alpha*(1-alphaOver);
      finalAlpha := residualAlpha + PSingle(AFixedData)^*alphaOver;
      pDest^.alpha:= finalAlpha;
      inc(pDest);
      dec(ACount);
    end;
  end;
  PXYZA(AContextData^.Dest) := pDest;
end;

procedure XYZAAlphaBrushDrawPixels(AFixedData: Pointer;
    AContextData: PUniBrushContext; AAlpha: Word; ACount: integer);
const oneOver65535 = 1/65535;
var
  pDest: PXYZA;
  alphaMul, finalAlpha: single;
begin
  if AAlpha=0 then
  begin
    inc(PXYZA(AContextData^.Dest), ACount);
    exit;
  end;
  pDest := PXYZA(AContextData^.Dest);
  if AAlpha<>65535 then
    alphaMul := 1-PSingle(AFixedData)^*AAlpha*single(oneOver65535)
  else
    alphaMul := 1-PSingle(AFixedData)^;
  while ACount > 0 do
  begin
    finalAlpha := pDest^.alpha*alphaMul;
    if finalAlpha <= 0 then pDest^ := XYZATransparent else
      pDest^.alpha:= finalAlpha;
    inc(pDest);
    dec(ACount);
  end;
  PXYZA(AContextData^.Dest) := pDest;
end;

{ TXYZABitmap }

function TXYZABitmap.InternalNew: TCustomUniversalBitmap;
begin
  Result:= TXYZABitmap.Create;
end;

class procedure TXYZABitmap.SolidBrush(out ABrush: TUniversalBrush;
  const AColor: TXYZA; ADrawMode: TDrawMode);
begin
  ABrush.Colorspace:= TXYZAColorspace;
  PXYZA(@ABrush.FixedData)^ := AColor;
  case ADrawMode of
    dmSet: ABrush.InternalPutNextPixels:= @XYZASolidBrushSetPixels;

    dmSetExceptTransparent:
      if AColor.alpha < 1 then
        ABrush.InternalPutNextPixels:= @XYZASolidBrushSkipPixels
      else
      begin
        ABrush.InternalPutNextPixels:= @XYZASolidBrushSetPixels;
        ABrush.DoesNothing := true;
      end;

    dmDrawWithTransparency,dmLinearBlend:
      if AColor.alpha<=0 then
      begin
        ABrush.InternalPutNextPixels:= @XYZASolidBrushSkipPixels;
        ABrush.DoesNothing := true;
      end
      else if AColor.alpha>=1 then
        ABrush.InternalPutNextPixels:= @XYZASolidBrushSetPixels
      else
        ABrush.InternalPutNextPixels:= @XYZASolidBrushDrawPixels;

    dmXor: raise exception.Create('Xor mode not available with floating point values');
  end;
end;

class procedure TXYZABitmap.ScannerBrush(out ABrush: TUniversalBrush;
  AScanner: IBGRAScanner; ADrawMode: TDrawMode;
  AOffsetX: integer; AOffsetY: integer);
begin
  ABrush.Colorspace:= TXYZAColorspace;
  with PXYZAScannerBrushFixedData(@ABrush.FixedData)^ do
  begin
    Scanner := Pointer(AScanner);
    OffsetX := AOffsetX;
    OffsetY := AOffsetY;
  end;
  ABrush.InternalInitContext:= @XYZAScannerBrushInitContext;
  case ADrawMode of
    dmSet: ABrush.InternalPutNextPixels:= @XYZAScannerBrushSetPixels;
    dmSetExceptTransparent: ABrush.InternalPutNextPixels:= @XYZAScannerBrushSetPixelsExceptTransparent;
    dmDrawWithTransparency,dmLinearBlend:
      ABrush.InternalPutNextPixels:= @XYZAScannerBrushDrawPixels;
    dmXor: raise exception.Create('Xor mode not available with floating point values');
  end;
end;

class procedure TXYZABitmap.EraseBrush(out ABrush: TUniversalBrush;
  AAlpha: Word);
begin
  if AAlpha = 0 then
  begin
    SolidBrush(ABrush, XYZATransparent, dmDrawWithTransparency);
    exit;
  end;
  ABrush.Colorspace:= TXYZAColorspace;
  PSingle(@ABrush.FixedData)^ := AAlpha/65535;
  ABrush.InternalInitContext:= nil;
  ABrush.InternalPutNextPixels:= @XYZAAlphaBrushDrawPixels;
end;

class procedure TXYZABitmap.AlphaBrush(out ABrush: TUniversalBrush;
  AAlpha: Word);
begin
  if AAlpha = 0 then
  begin
    SolidBrush(ABrush, XYZATransparent, dmSet);
    exit;
  end;
  ABrush.Colorspace:= TXYZAColorspace;
  PSingle(@ABrush.FixedData)^ := AAlpha/65535;
  ABrush.InternalInitContext:= nil;
  ABrush.InternalPutNextPixels:= @XYZAAlphaBrushSetPixels;
end;

procedure TXYZABitmap.ReplaceImaginary(const AAfter: TXYZA);
var
  p: PXYZA;
  n: integer;
begin
  p := Data;
  for n := NbPixels - 1 downto 0 do
  begin
    if (p^.alpha>0) and not IsRealColor(p^) then p^ := AAfter;
    Inc(p);
  end;
  InvalidateBitmap;
end;

finalization

  xyHorseshoePolygon.Free;

end.

