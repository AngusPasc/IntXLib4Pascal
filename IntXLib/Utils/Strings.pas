unit Strings;

{
  * Copyright (c) 2015 Ugochukwu Mmaduekwe ugo4brain@gmail.com

  *   This Source Code Form is subject to the terms of the Mozilla Public License
  * v. 2.0. If a copy of the MPL was not distributed with this file, You can
  * obtain one at http://mozilla.org/MPL/2.0/.

  *   Neither the name of Ugochukwu Mmaduekwe nor the names of its contributors may
  *  be used to endorse or promote products derived from this software without
  *  specific prior written permission.

}

interface

resourcestring
  AlphabetRepeatingChars = 'Alphabet characters must be unique.';
  AlphabetTooSmall = 'Alphabet is too small to represent numbers in base %u.';
  CantBeNull = 'Operand(s) can''t be null.';
  CantBeNullCmp = 'Can''t use null in comparison operations.';
  CantBeNullOne = 'Operand can''t be null.';
  CantCmp = 'Can''t compare with provided argument.';
  DigitBytesLengthInvalid = 'Digit bytes array length is invalid.';
  FhtMultiplicationError =
    'FHT multiplication returned invalid results for TIntX objects with lengths %u and %u.';
  IntegerTooBig = 'One of the operated big integers is too big.';
  ParseBaseInvalid = 'Base is invalid.';
  ParseInvalidChar = 'Invalid character in input.';
  ParseNoDigits = 'No digits in string.';
  ParseTooBigDigit = 'Digit is too big for this base.';
  ToStringSmallBase = 'Base must be between 2 and 65536.';
  DivideByZero = 'Attempted to divide by Zero.';
  DivisionUndefined = 'Division undefined (0/0)';
  NegativeFactorial = 'Can''t calculate factorial for negative number %s.';
  BezoutNegativeNotAllowed = 'Negative value not allowed for B�zouts identity.';
  BezoutNegativeCantComputeZero = 'One or more parameters are Zero.';
  NegativeSquareRoot = 'Cannot compute squareroot of Negative number.';
  LogCantComputeZero = 'One or more parameters are Zero.';
  LogNegativeNotAllowed = 'Negative value not allowed for LogN';
  InvModNegativeNotAllowed = 'Negative value not allowed for Modular Inverse.';
  ModPowExponentCantbeNegative =
    'Exponent Can''t be Negative for Modular Exponentiation.';
  ModPowModulusCantbeZeroorNegative = 'Modulus Can''t be Zero or Negative';
  Overflow_TIntXInfinity = 'TIntX cannot represent infinity.';
  Overflow_NotANumber = 'The value is not a number.';

implementation

end.
