unit FhtHelper;

{
  * Copyright (c) 2015 Ugochukwu Mmaduekwe ugo4brain@gmail.com

  *   This Source Code Form is subject to the terms of the Mozilla Public License
  * v. 2.0. If a copy of the MPL was not distributed with this file, You can
  * obtain one at http://mozilla.org/MPL/2.0/.

  *   Neither the name of Ugochukwu Mmaduekwe nor the names of its contributors may
  *  be used to endorse or promote products derived from this software without
  *  specific prior written permission.

}

{$POINTERMATH ON}

interface

uses
  DTypes, Math, Constants, Bits, DigitHelper, SyncObjs, IntX;

type
  /// <summary>
  /// Contains helping methods for work with FHT (Fast Hartley Transform).
  /// FHT is a better alternative of FFT (Fast Fourier Transform) - at least for <see cref="TIntX" />.
  /// </summary>

  TFhtHelper = class

  type
    /// <summary>
    /// Trigonometry values.
    /// </summary>

    TTrigValues = Record

    public
      /// <summary>
      /// Sin value from <see cref="SineTable" />.
      /// </summary>

      TableSin: Double;

      /// <summary>
      /// Cos value from <see cref="SineTable" />.
      /// </summary>

      TableCos: Double;

      /// <summary>
      /// Sin value.
      /// </summary>

      Sin: Double;

      /// <summary>
      /// Cos value.
      /// </summary>

      Cos: Double;

      constructor Create(Dummy: Double);

    end;

    // Pointer to our Record

    PTrigValues = ^TTrigValues;

  private
    class procedure FillSineTable(var sineTable: TMyDoubleArray); static;
    class procedure Fht4(slice: PMyDouble); static;
    class procedure ReverseFht8(slice: PMyDouble); static;
    class procedure FhtButterfly(slice1: PMyDouble; slice2: PMyDouble;
      index1: UInt32; index2: UInt32; Cos: Double; Sin: Double); static;
    class procedure ReverseFhtButterfly(slice1: PMyDouble; slice2: PMyDouble;
      index1: UInt32; index2: UInt32; Cos: Double; Sin: Double); static;
    class procedure ReverseFhtButterfly2(slice1: PMyDouble; slice2: PMyDouble;
      index1: UInt32; index2: UInt32; Cos: Double; Sin: Double); static;
    class procedure GetInitialTrigValues(valuesPtr: PTrigValues;
      lengthLog2: Integer);
    class procedure NextTrigValues(valuesPtr: PTrigValues);

  public

    class constructor Create();
    class destructor Destroy();
    class function Sqrt2: Double; static;
    class function Sqrt2Div2: Double; static;
    class function ConvertDigitsToDouble(digits: TMyUInt32Array;
      mlength: UInt32; newLength: UInt32): TMyDoubleArray; overload; static;
    class function ConvertDigitsToDouble(digitsPtr: PMyUInt32; mlength: UInt32;
      newLength: UInt32): TMyDoubleArray; overload; static;
    class procedure ConvertDoubleToDigits(marray: TMyDoubleArray;
      mlength: UInt32; digitsLength: UInt32; digitsRes: TMyUInt32Array);
      overload; static;
    class procedure ConvertDoubleToDigits(slice: PMyDouble; mlength: UInt32;
      digitsLength: UInt32; digitsResPtr: PMyUInt32); overload; static;
    class procedure Fht(marray: TMyDoubleArray; mlength: UInt32);
      overload; static;
    class procedure Fht(slice: PMyDouble; mlength: UInt32; lengthLog2: Integer);
      overload; static;
    class procedure MultiplyFhtResults(data: TMyDoubleArray;
      data2: TMyDoubleArray; mlength: UInt32); overload; static;
    class procedure MultiplyFhtResults(slice: PMyDouble; slice2: PMyDouble;
      mlength: UInt32); overload; static;
    class procedure ReverseFht(marray: TMyDoubleArray; mlength: UInt32);
      overload; static;
    class procedure ReverseFht(slice: PMyDouble; mlength: UInt32;
      lengthLog2: Integer); overload; static;

  class var

    FLock: TCriticalSection;
    F_sineTable: TMyDoubleArray;

  const

    DoubleDataBytes: Integer = 1;
    DoubleDataLengthShift: Integer = 2;
    // already calculated //2 - (DoubleDataBytes shr 1)
    DoubleDataDigitShift: Integer = 8; // already calculated // DoubleDataBytes
    // shl 3
    DoubleDataBaseInt: Int64 = 256; // already calculated //Int64(1) shl
    // DoubleDataDigitShift
    DoubleDataBase: Double = 256.0; // already calculated // DoubleDataBaseInt
    DoubleDataBaseDiv2: Double = 128.0;
    // already calculated //DoubleDataBase / 2.0

  end;

implementation

// static class constructor

class constructor TFhtHelper.Create();

begin
  // Initialize SinTable
  SetLength(F_sineTable, 31);
  FillSineTable(F_sineTable);
  // Create Critical Section
  FLock := TCriticalSection.Create;
end;

class destructor TFhtHelper.Destroy();
begin
  FLock.Free;
end;

// Since Records do not allow Parameterless Constructors, we pass a
// dummy value to the Constructor.

constructor TFhtHelper.TTrigValues.Create(Dummy: Double);
begin

end;

// SQRT(2)

class function TFhtHelper.Sqrt2: Double;
begin
  result := Sqrt(2.0);
end;

// SQRT(2) / 2

class function TFhtHelper.Sqrt2Div2: Double;
begin
  result := (Sqrt2 / 2.0);
end;

/// <summary>
/// Converts <see cref="TIntX" /> digits into real representation (used in FHT).
/// </summary>
/// <param name="digits">Big integer digits.</param>
/// <param name="mlength"><paramref name="digits" /> length.</param>
/// <param name="newLength">Multiplication result length (must be pow of 2).</param>
/// <returns>Double array.</returns>

class function TFhtHelper.ConvertDigitsToDouble(digits: TMyUInt32Array;
  mlength: UInt32; newLength: UInt32): TMyDoubleArray;
var
  digitsPtr: PMyUInt32;

begin
  digitsPtr := @digits[0];

  result := ConvertDigitsToDouble(digitsPtr, mlength, newLength);

end;

/// <summary>
/// Converts <see cref="TIntX" /> digits into real representation (used in FHT).
/// </summary>
/// <param name="digitsPtr">Big integer digits.</param>
/// <param name="length"><paramref name="digitsPtr" /> length.</param>
/// <param name="newLength">Multiplication result length (must be pow of 2).</param>
/// <returns>Double array.</returns>

class function TFhtHelper.ConvertDigitsToDouble(digitsPtr: PMyUInt32;
  mlength: UInt32; newLength: UInt32): TMyDoubleArray;
var
  data: TMyDoubleArray;
  slice: PMyDouble;
  unitCount, i: UInt32;
  unitDigitsPtr: PMyByte;
  carry, dataDigit: Double;

begin
  // Maybe fix newLength (make it the nearest bigger pow of 2)
  newLength := UInt32(1) shl TBits.CeilLog2(newLength);

  // For better FHT accuracy we will choose length smaller then dwords.
  // So new length must be modified accordingly
  newLength := newLength shl DoubleDataLengthShift;
  SetLength(data, newLength);

  slice := @data[0];

  // Amount of units pointed by digitsPtr
  unitCount := mlength shl DoubleDataLengthShift;

  // Copy all words from digits into new double array
  unitDigitsPtr := PMyByte(digitsPtr);
  i := 0;
  while i < (unitCount) do
  begin
    slice[i] := unitDigitsPtr[i];
    Inc(i);
  end;

  // Clear remaining double values
  TDigitHelper.SetBlockDigits(slice + unitCount, newLength - unitCount, 0.0);

  // FHT (as well as FFT) works more accurate with "balanced" data, so let's balance it
  carry := 0;
  i := 0;
  while ((i < unitCount) or ((i < newLength) and (carry <> 0))) do
  begin
    dataDigit := slice[i] + carry;
    if (dataDigit >= DoubleDataBaseDiv2) then
    begin
      dataDigit := dataDigit - DoubleDataBase;
      carry := 1.0;
    end
    else
    begin
      carry := 0;
    end;
    slice[i] := dataDigit;
    Inc(i);
  end;

  if (carry > 0) then
  begin
    slice[0] := slice[0] - carry;
  end;
  result := data;
end;

/// <summary>
/// Converts real digits representation (result of FHT) into usual <see cref="TIntX" /> digits.
/// </summary>
/// <param name="array">Real digits representation.</param>
/// <param name="mlength"><paramref name="array" /> length.</param>
/// <param name="digitsLength">New digits array length (we always do know the upper value for this array).</param>
/// <param name="digitsRes">Big integer digits.</param>

class procedure TFhtHelper.ConvertDoubleToDigits(marray: TMyDoubleArray;
  mlength: UInt32; digitsLength: UInt32; digitsRes: TMyUInt32Array);
var
  slice: PMyDouble;
  digitsResPtr: PMyUInt32;

begin
  slice := @marray[0];
  digitsResPtr := @digitsRes[0];

  ConvertDoubleToDigits(slice, mlength, digitsLength, digitsResPtr);

end;

/// <summary>
/// Converts real digits representation (result of FHT) into usual <see cref="TIntX" /> digits.
/// </summary>
/// <param name="slice">Real digits representation.</param>
/// <param name="length"><paramref name="slice" /> length.</param>
/// <param name="digitsLength">New digits array length (we always do know the upper value for this array).</param>
/// <param name="digitsResPtr">Resulting digits storage.</param>
/// <returns>Big integer digits (dword values).</returns>

class procedure TFhtHelper.ConvertDoubleToDigits(slice: PMyDouble;
  mlength: UInt32; digitsLength: UInt32; digitsResPtr: PMyUInt32);
var
  normalizeMultiplier, carry, dataDigit {$IFDEF DEBUG}, error, maxError
  {$ENDIF} : Double;
  unitCount, i, digitsCarry, oldDigit: UInt32;
  carryInt, dataDigitInt: Int64;
  unitDigitsPtr: PMyByte;
begin
  // Calculate data multiplier (don't forget about additional div 2)
  normalizeMultiplier := 0.5 / mlength;

  // Count of units in digits
  unitCount := digitsLength shl DoubleDataLengthShift;

  // Carry and current digit
  carryInt := 0;

{$IFDEF DEBUG}
  // Rounding error
  maxError := 0;
{$ENDIF}
  // Walk thru all double digits
  unitDigitsPtr := PMyByte(digitsResPtr);
  i := 0;
  while i < (mlength) do

  begin
    // Get data digit (don't forget it might be balanced)
    dataDigit := slice[i] * normalizeMultiplier;

{$IFDEF DEBUG}
    // Round to the nearest
    if dataDigit < 0 then
    begin
      dataDigitInt := Trunc(dataDigit - 0.5)
    end
    else
    begin
      dataDigitInt := Trunc(dataDigit + 0.5);
    end;

    // Calculate and (maybe) store max error
    error := Abs(dataDigit - dataDigitInt);
    if (error > maxError) then
    begin
      maxError := error;
    end;

    // Add carry
    dataDigitInt := dataDigitInt + carryInt;
{$ELSE}
    // Round to the nearest
    if dataDigit < 0 then
    begin
      dataDigitInt := Trunc(dataDigit - 0.5) + carryInt
    end
    else
    begin
      dataDigitInt := Trunc(dataDigit + 0.5) + carryInt;
    end;
{$ENDIF}
    // Get next carry floored; maybe modify data digit
    carry := dataDigitInt / DoubleDataBase;
    if (carry < 0) then
    begin
      carry := carry + (Trunc(carry) mod Trunc(1.0));
    end;
    carryInt := Trunc(carry);

    dataDigitInt := dataDigitInt - (carryInt shl DoubleDataDigitShift);
    if (dataDigitInt < 0) then
    begin
      dataDigitInt := dataDigitInt + DoubleDataBaseInt;
      Dec(carryInt);
    end;

    // Maybe add to the digits
    if (i < unitCount) then
    begin
      unitDigitsPtr[i] := Byte(dataDigitInt);
    end;

    Inc(i);
  end;

  // Last carry must be accounted
  if (carryInt < 0) then
  begin
    digitsResPtr[0] := digitsResPtr[0] - UInt32(-carryInt);
  end
  else if (carryInt > 0) then
  begin
    digitsCarry := UInt32(carryInt);
    i := 0;
    while ((digitsCarry <> 0) and (i < (digitsLength))) do
    begin
      oldDigit := digitsResPtr[i];
      digitsResPtr[i] := digitsResPtr[i] + digitsCarry;

      // Check for an overflow
      if digitsResPtr[i] < oldDigit then
        digitsCarry := UInt32(1)
      else
      begin
        digitsCarry := UInt32(0);
      end;

      Inc(i);

    end;

  end;

{$IFDEF DEBUG}
  // Finally store max error in public visible field
  System.TMonitor.Enter(TIntX._maxFhtRoundErrorLock);
  try
    if (maxError > TIntX.MaxFhtRoundError) then
    begin
      TIntX.MaxFhtRoundError := maxError;
    end;
  finally
    System.TMonitor.Exit(TIntX._maxFhtRoundErrorLock);
  end;

{$ENDIF}
end;

/// <summary>
/// Performs FHT "in place" for given double array.
/// </summary>
/// <param name="array">Double array.</param>
/// <param name="mlength">Array length.</param>

class procedure TFhtHelper.Fht(marray: TMyDoubleArray; mlength: UInt32);
var
  slice: PMyDouble;
begin
  slice := @marray[0];

  Fht(slice, mlength, TBits.Msb(mlength));

end;

/// <summary>
/// Performs FHT "in place" for given double array slice.
/// </summary>
/// <param name="slice">Double array slice.</param>
/// <param name="length">Slice length.</param>
/// <param name="lengthLog2">Log2(<paramref name="mlength" />).</param>

class procedure TFhtHelper.Fht(slice: PMyDouble; mlength: UInt32;
  lengthLog2: Integer);
var
  rightSlice: PMyDouble;
  lengthDiv2, lengthDiv4, i: UInt32;
  leftDigit, rightDigit: Double;
  trigValues: TTrigValues;
begin
  // Special fast processing for mlength == 4
  if (mlength = 4) then
  begin
    Fht4(slice);
    Exit;
  end;

  // Divide data into 2 recursively processed parts
  mlength := mlength shr 1;
  Dec(lengthLog2);
  rightSlice := slice + mlength;

  lengthDiv2 := mlength shr 1;
  lengthDiv4 := mlength shr 2;

  // Perform initial "butterfly" operations over left and right array parts
  leftDigit := slice[0];
  rightDigit := rightSlice[0];
  slice[0] := leftDigit + rightDigit;
  rightSlice[0] := leftDigit - rightDigit;

  leftDigit := slice[lengthDiv2];
  rightDigit := rightSlice[lengthDiv2];
  slice[lengthDiv2] := leftDigit + rightDigit;
  rightSlice[lengthDiv2] := leftDigit - rightDigit;

  // Get initial trig values
  trigValues := TTrigValues.Create(0);
  GetInitialTrigValues(@trigValues, lengthLog2);

  // Perform "butterfly"
  i := 1;
  while i < (lengthDiv4) do
  begin

    FhtButterfly(slice, rightSlice, i, mlength - i, trigValues.Cos,
      trigValues.Sin);
    FhtButterfly(slice, rightSlice, lengthDiv2 - i, lengthDiv2 + i,
      trigValues.Sin, trigValues.Cos);

    // Get next trig values
    NextTrigValues(@trigValues);
    Inc(i);
  end;

  // Final "butterfly"
  FhtButterfly(slice, rightSlice, lengthDiv4, mlength - lengthDiv4, Sqrt2Div2,
    Sqrt2Div2);

  // Finally perform recursive run
  Fht(slice, mlength, lengthLog2);
  Fht(rightSlice, mlength, lengthLog2);
end;

/// <summary>
/// Performs FHT "in place" for given double array slice.
/// Fast version for length == 4.
/// </summary>
/// <param name="slice">Double array slice.</param>

class procedure TFhtHelper.Fht4(slice: PMyDouble);
var
  d0, d1, d2, d3, d02, d13: Double;
begin
  // Get 4 digits
  d0 := slice[0];
  d1 := slice[1];
  d2 := slice[2];
  d3 := slice[3];

  // Perform fast "butterfly" addition/subtraction for them.
  // In case when length == 4 we can do it without trigonometry
  d02 := d0 + d2;
  d13 := d1 + d3;
  slice[0] := d02 + d13;
  slice[1] := d02 - d13;

  d02 := d0 - d2;
  d13 := d1 - d3;
  slice[2] := d02 + d13;
  slice[3] := d02 - d13;
end;

/// <summary>
/// Multiplies two FHT results and stores multiplication in first one.
/// </summary>
/// <param name="data">First FHT result.</param>
/// <param name="data2">Second FHT result.</param>
/// <param name="mlength">FHT results length.</param>

class procedure TFhtHelper.MultiplyFhtResults(data: TMyDoubleArray;
  data2: TMyDoubleArray; mlength: UInt32);
var
  slice, slice2: PMyDouble;
begin
  slice := @data[0];
  slice2 := @data2[0];

  MultiplyFhtResults(slice, slice2, mlength);

end;

/// <summary>
/// Multiplies two FHT results and stores multiplication in first one.
/// </summary>
/// <param name="slice">First FHT result.</param>
/// <param name="slice2">Second FHT result.</param>
/// <param name="mlength">FHT results length.</param>

class procedure TFhtHelper.MultiplyFhtResults(slice: PMyDouble;
  slice2: PMyDouble; mlength: UInt32);
var
  d11, d12, d21, d22, ad, sd: Double;
  stepStart, stepEnd, index1, index2: UInt32;
begin
  // Step0 and Step1
  slice[0] := slice[0] * (2.0 * slice2[0]);
  slice[1] := slice[1] * (2.0 * slice2[1]);

  // Perform all other steps
  stepStart := 2;
  stepEnd := 4;
  while stepStart < (mlength) do
  begin
    index1 := stepStart;
    index2 := stepEnd - 1;
    while index1 < (stepEnd) do
    begin
      d11 := slice[index1];
      d12 := slice[index2];
      d21 := slice2[index1];
      d22 := slice2[index2];

      ad := d11 + d12;
      sd := d11 - d12;

      slice[index1] := d21 * ad + d22 * sd;
      slice[index2] := d22 * ad - d21 * sd;
      index1 := index1 + 2;
      index2 := index2 - 2;
    end;

    stepStart := stepStart * 2;
    stepEnd := stepEnd * 2;
  end;

end;

/// <summary>
/// Performs FHT reverse "in place" for given double array.
/// </summary>
/// <param name="array">Double array.</param>
/// <param name="mlength">Array length.</param>

class procedure TFhtHelper.ReverseFht(marray: TMyDoubleArray; mlength: UInt32);
var
  slice: PMyDouble;
begin
  slice := @marray[0];

  ReverseFht(slice, mlength, TBits.Msb(mlength));

end;

/// <summary>
/// Performs reverse FHT "in place" for given double array slice.
/// </summary>
/// <param name="slice">Double array slice.</param>
/// <param name="length">Slice length.</param>
/// <param name="lengthLog2">Log2(<paramref name="mlength" />).</param>

class procedure TFhtHelper.ReverseFht(slice: PMyDouble; mlength: UInt32;
  lengthLog2: Integer);
var
  rightSlice: PMyDouble;
  lengthDiv2, lengthDiv4, i: UInt32;
  trigValues: TTrigValues;
begin
  // Special fast processing for length == 8
  if (mlength = 8) then
  begin
    ReverseFht8(slice);
    Exit;
  end;

  // Divide data into 2 recursively processed parts
  mlength := mlength shr 1;
  Dec(lengthLog2);
  rightSlice := slice + mlength;

  lengthDiv2 := mlength shr 1;
  lengthDiv4 := mlength shr 2;

  // Perform recursive run
  ReverseFht(slice, mlength, lengthLog2);
  ReverseFht(rightSlice, mlength, lengthLog2);

  // Get initial trig values
  trigValues := TTrigValues.Create(0);
  GetInitialTrigValues(@trigValues, lengthLog2);

  // Perform "butterfly"
  i := 1;
  while i < (lengthDiv4) do

  begin
    ReverseFhtButterfly(slice, rightSlice, i, mlength - i, trigValues.Cos,
      trigValues.Sin);
    ReverseFhtButterfly(slice, rightSlice, lengthDiv2 - i, lengthDiv2 + i,
      trigValues.Sin, trigValues.Cos);

    // Get next trig values
    NextTrigValues(@trigValues);
    Inc(i);
  end;

  // Final "butterfly"
  ReverseFhtButterfly(slice, rightSlice, lengthDiv4, mlength - lengthDiv4,
    Sqrt2Div2, Sqrt2Div2);
  ReverseFhtButterfly2(slice, rightSlice, 0, 0, 1.0, 0);
  ReverseFhtButterfly2(slice, rightSlice, lengthDiv2, lengthDiv2, 0, 1.0);
end;

/// <summary>
/// Performs reverse FHT "in place" for given double array slice.
/// Fast version for length == 8.
/// </summary>
/// <param name="slice">Double array slice.</param>

class procedure TFhtHelper.ReverseFht8(slice: PMyDouble);
var
  d0, d1, d2, d3, d4, d5, d6, d7, da01, ds01, da23, ds23, daa0123, dsa0123,
    das0123, dss0123, da45, ds45, da67, ds67, daa4567, dsa4567: Double;
begin
  // Get 8 digits
  d0 := slice[0];
  d1 := slice[1];
  d2 := slice[2];
  d3 := slice[3];
  d4 := slice[4];
  d5 := slice[5];
  d6 := slice[6];
  d7 := slice[7];

  // Calculate add and subtract pairs for first 4 digits
  da01 := d0 + d1;
  ds01 := d0 - d1;
  da23 := d2 + d3;
  ds23 := d2 - d3;

  // Calculate add and subtract pairs for first pairs
  daa0123 := da01 + da23;
  dsa0123 := da01 - da23;
  das0123 := ds01 + ds23;
  dss0123 := ds01 - ds23;

  // Calculate add and subtract pairs for next 4 digits
  da45 := d4 + d5;
  ds45 := (d4 - d5) * Sqrt2;
  da67 := d6 + d7;
  ds67 := (d6 - d7) * Sqrt2;

  // Calculate add and subtract pairs for next pairs
  daa4567 := da45 + da67;
  dsa4567 := da45 - da67;

  // Store digits values
  slice[0] := daa0123 + daa4567;
  slice[4] := daa0123 - daa4567;
  slice[2] := dsa0123 + dsa4567;
  slice[6] := dsa0123 - dsa4567;
  slice[1] := das0123 + ds45;
  slice[5] := das0123 - ds45;
  slice[3] := dss0123 + ds67;
  slice[7] := dss0123 - ds67;
end;

/// <summary>
/// Performs "butterfly" operation for <see cref="Fht(PMyDouble, UInt32, Integer)" />.
/// </summary>
/// <param name="slice1">First data array slice.</param>
/// <param name="slice2">Second data array slice.</param>
/// <param name="index1">First slice index.</param>
/// <param name="index2">Second slice index.</param>
/// <param name="cos">Cos value.</param>
/// <param name="sin">Sin value.</param>

class procedure TFhtHelper.FhtButterfly(slice1: PMyDouble; slice2: PMyDouble;
  index1: UInt32; index2: UInt32; Cos: Double; Sin: Double);
var
  d11, d12, temp: Double;
begin
  d11 := slice1[index1];
  d12 := slice1[index2];

  temp := slice2[index1];
  slice1[index1] := d11 + temp;
  d11 := d11 - temp;

  temp := slice2[index2];
  slice1[index2] := d12 + temp;
  d12 := d12 - temp;

  slice2[index1] := d11 * Cos + d12 * Sin;
  slice2[index2] := d11 * Sin - d12 * Cos;
end;

/// <summary>
/// Performs "butterfly" operation for <see cref="ReverseFht(PMyDouble, UInt32, Integer)" />.
/// </summary>
/// <param name="slice1">First data array slice.</param>
/// <param name="slice2">Second data array slice.</param>
/// <param name="index1">First slice index.</param>
/// <param name="index2">Second slice index.</param>
/// <param name="cos">Cos value.</param>
/// <param name="sin">Sin value.</param>

class procedure TFhtHelper.ReverseFhtButterfly(slice1: PMyDouble;
  slice2: PMyDouble; index1: UInt32; index2: UInt32; Cos: Double; Sin: Double);
var
  d21, d22, temp, temp2: Double;
begin
  d21 := slice2[index1];
  d22 := slice2[index2];

  temp := slice1[index1];
  temp2 := d21 * Cos + d22 * Sin;
  slice1[index1] := temp + temp2;
  slice2[index1] := temp - temp2;

  temp := slice1[index2];
  temp2 := d21 * Sin - d22 * Cos;
  slice1[index2] := temp + temp2;
  slice2[index2] := temp - temp2;
end;

/// <summary>
/// Performs "butterfly" operation for <see cref="ReverseFht(PMyDouble, UInt32, Integer)" />.
/// Another version.
/// </summary>
/// <param name="slice1">First data array slice.</param>
/// <param name="slice2">Second data array slice.</param>
/// <param name="index1">First slice index.</param>
/// <param name="index2">Second slice index.</param>
/// <param name="cos">Cos value.</param>
/// <param name="sin">Sin value.</param>

class procedure TFhtHelper.ReverseFhtButterfly2(slice1: PMyDouble;
  slice2: PMyDouble; index1: UInt32; index2: UInt32; Cos: Double; Sin: Double);
var
  temp, temp2: Double;
begin
  temp := slice1[index1];
  temp2 := slice2[index1] * Cos + slice2[index2] * Sin;
  slice1[index1] := temp + temp2;
  slice2[index2] := temp - temp2;
end;

/// <summary>
/// Fills sine table for FHT.
/// </summary>
/// <param name="sineTable">Sine table to fill.</param>
class procedure TFhtHelper.FillSineTable(var sineTable: TMyDoubleArray);
var
  i, p: Integer;
begin
  i := 0;
  p := 1;
  while i < (length(sineTable)) do

  begin
    sineTable[i] := Sin(TConstants.PI / p);
    Inc(i);
    p := p * 2;
  end;

end;

/// <summary>
/// Initializes trigonometry values for FHT.
/// </summary>
/// <param name="valuesPtr">Values to init.</param>
/// <param name="lengthLog2">Log2(processing slice length).</param>

class procedure TFhtHelper.GetInitialTrigValues(valuesPtr: PTrigValues;
  lengthLog2: Integer);

begin
  valuesPtr^.TableSin := F_sineTable[lengthLog2];
  valuesPtr^.TableCos := F_sineTable[lengthLog2 + 1];
  valuesPtr^.TableCos := valuesPtr^.TableCos * -2.0 * (valuesPtr^.TableCos);

  valuesPtr^.Sin := valuesPtr^.TableSin;
  valuesPtr^.Cos := valuesPtr^.TableCos + 1.0;
end;

/// <summary>
/// Generates next trigonometry values for FHT basing on previous ones.
/// </summary>
/// <param name="valuesPtr">Current trig values.</param>

class procedure TFhtHelper.NextTrigValues(valuesPtr: PTrigValues);
var
  oldCos: Double;
begin
  oldCos := valuesPtr^.Cos;
  valuesPtr^.Cos := valuesPtr^.Cos * valuesPtr^.TableCos - valuesPtr^.Sin *
    valuesPtr^.TableSin + valuesPtr^.Cos;
  valuesPtr^.Sin := valuesPtr^.Sin * valuesPtr^.TableCos + oldCos *
    valuesPtr^.TableSin + valuesPtr^.Sin;
end;

end.
