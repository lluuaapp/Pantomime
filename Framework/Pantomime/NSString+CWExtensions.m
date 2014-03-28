/*
**  NSString+Extensions.m
**
**  Copyright (c) 2001-2006
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**  
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**  
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

//
// WARNING: Keep the encoding in this file to ISO-8859-1.
//          See the -hasREPrefix method for details.
//

#import "NSString+CWExtensions.h"

#import "CWCharset.h"
#import "CWConstants.h"
#import "CWInternetAddress.h"
#import "CWPart.h"
#import "NSData+CWExtensions.h"


#define IS_PRINTABLE(c) (isascii(c) && isprint(c))

//
//
//
@implementation NSString (PantomimeStringExtensions)

#ifdef MACOSX
- (NSString *) stringByTrimmingWhiteSpaces
{
  NSMutableString *aMutableString;

  aMutableString = [[NSMutableString alloc] initWithString: self];
  CFStringTrimWhitespace((__bridge CFMutableStringRef)aMutableString);
  
  return aMutableString;
}
#endif


//
//
//
- (NSInteger) indexOfCharacter: (unichar) theCharacter
{
  return [self indexOfCharacter: theCharacter  fromIndex: 0];
}


//
//
//
- (NSInteger) indexOfCharacter: (unichar) theCharacter
               fromIndex: (NSUInteger) theIndex
{
  NSInteger i, len;
  
  len = [self length];
  
  for (i = theIndex; i < len; i++)
    {
      if ([self characterAtIndex: i] == theCharacter)
	{
	  return i;
	}
    }
  
  return -1;
}


//
//
//
- (BOOL) hasCaseInsensitivePrefix: (NSString *) thePrefix
{
  if (thePrefix)
    {
      return [[self uppercaseString] hasPrefix: [thePrefix uppercaseString]];
    }
  
  return NO;
}


//
//
//
- (BOOL) hasCaseInsensitiveSuffix: (NSString *) theSuffix
{
  if (theSuffix)
    {
      return [[self uppercaseString] hasSuffix: [theSuffix uppercaseString]];
    }
  
  return NO;
}


//
//
//
- (NSString *) stringFromQuotedString
{
  NSInteger len;

  len = [self length];
  
  if (len > 1 &&
      [self characterAtIndex: 0] == '"' &&
      [self characterAtIndex: (len-1)] == '"')
    {
      return [self substringWithRange: NSMakeRange(1, len-2)];
    }
  
  return self;
}


//
//
//
+ (NSString *) stringValueOfTransferEncoding: (NSInteger) theEncoding
{
  switch (theEncoding)
    {
    case PantomimeEncodingNone:
      break;
    case PantomimeEncodingQuotedPrintable:
      return @"quoted-printable";
    case PantomimeEncodingBase64:
      return @"base64";
    case PantomimeEncoding8bit:
      return @"8bit";
    case PantomimeEncodingBinary:
      return @"binary";
    default:
      break;
    }

  // PantomimeEncoding7bit will also fall back here.
  return @"7bit";
}


//
//
//
+ (NSInteger) encodingForCharset: (NSData *) theCharset
{
  // We define some aliases for the string encoding.
  static struct { char *name; NSInteger encoding; BOOL fromCoreFoundation; } encodings[] = {
    {"ascii"         ,NSASCIIStringEncoding          ,NO},
    {"us-ascii"      ,NSASCIIStringEncoding          ,NO},
    {"default"       ,NSASCIIStringEncoding          ,NO},  // Ah... spammers.
    {"utf-8"         ,NSUTF8StringEncoding           ,NO},
    {"iso-8859-1"    ,NSISOLatin1StringEncoding      ,NO},
    {"x-user-defined",NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in Outlook.
    {"unknown"       ,NSISOLatin1StringEncoding      ,NO},  // Once more, blame Outlook.
    {"x-unknown"     ,NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in Pine 4.21.
    {"unknown-8bit"  ,NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in Mutt/1.3.28i
    {"0"             ,NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in QUALCOMM Windows Eudora Version 6.0.1.1
    {""              ,NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in Ximian Evolution
    {"iso8859_1"     ,NSISOLatin1StringEncoding      ,NO},  // To prevent a lame bug in Openwave WebEngine
    {"iso-8859-2"    ,NSISOLatin2StringEncoding      ,NO},
#ifdef MACOSX
    {"iso-8859-3"    ,kCFStringEncodingISOLatin3        ,YES},
    {"iso-8859-4"    ,kCFStringEncodingISOLatin4        ,YES},
    {"iso-8859-5"    ,kCFStringEncodingISOLatinCyrillic ,YES},
    {"iso-8859-6"    ,kCFStringEncodingISOLatinArabic   ,YES},
    {"iso-8859-7"    ,kCFStringEncodingISOLatinGreek    ,YES},
    {"iso-8859-8"    ,kCFStringEncodingISOLatinHebrew   ,YES},
    {"iso-8859-9"    ,kCFStringEncodingISOLatin5        ,YES},
    {"iso-8859-10"   ,kCFStringEncodingISOLatin6        ,YES},
    {"iso-8859-11"   ,kCFStringEncodingISOLatinThai     ,YES},
    {"iso-8859-13"   ,kCFStringEncodingISOLatin7        ,YES},
    {"iso-8859-14"   ,kCFStringEncodingISOLatin8        ,YES},
    {"iso-8859-15"   ,kCFStringEncodingISOLatin9        ,YES},
    {"koi8-r"        ,kCFStringEncodingKOI8_R           ,YES},
    {"big5"          ,kCFStringEncodingBig5             ,YES},
    {"euc-kr"        ,kCFStringEncodingEUC_KR           ,YES},
    {"ks_c_5601-1987",kCFStringEncodingEUC_KR           ,YES},
    {"gb2312"        ,kCFStringEncodingHZ_GB_2312       ,YES},
    {"shift_jis"     ,kCFStringEncodingShiftJIS         ,YES},
    {"windows-1255"  ,kCFStringEncodingWindowsHebrew    ,YES},
    {"windows-1256"  ,kCFStringEncodingWindowsArabic    ,YES},
    {"windows-1257"  ,kCFStringEncodingWindowsBalticRim ,YES},
    {"windows-1258"  ,kCFStringEncodingWindowsVietnamese,YES},
#else
    {"iso-8859-3"   ,NSISOLatin3StringEncoding                 ,NO},
    {"iso-8859-4"   ,NSISOLatin4StringEncoding                 ,NO},
    {"iso-8859-5"   ,NSISOCyrillicStringEncoding               ,NO},
    {"iso-8859-6"   ,NSISOArabicStringEncoding                 ,NO},
    {"iso-8859-7"   ,NSISOGreekStringEncoding                  ,NO},
    {"iso-8859-8"   ,NSISOHebrewStringEncoding                 ,NO},
    {"iso-8859-9"   ,NSISOLatin5StringEncoding                 ,NO},
    {"iso-8859-10"  ,NSISOLatin6StringEncoding                 ,NO},
    {"iso-8859-11"  ,NSISOThaiStringEncoding                   ,NO},
    {"iso-8859-13"  ,NSISOLatin7StringEncoding                 ,NO},
    {"iso-8859-14"  ,NSISOLatin8StringEncoding                 ,NO},
    {"iso-8859-15"  ,NSISOLatin9StringEncoding                 ,NO},
    {"koi8-r"       ,NSKOI8RStringEncoding                     ,NO},
    {"big5"         ,NSBIG5StringEncoding                      ,NO},
    {"gb2312"       ,NSGB2312StringEncoding                    ,NO},
    {"utf-7"        ,NSUTF7StringEncoding                      ,NO},
    {"unicode-1-1-utf-7", NSUTF7StringEncoding                 ,NO},  // To prever a bug (sort of) in MS Hotmail
#endif
    {"windows-1250" ,NSWindowsCP1250StringEncoding             ,NO},
    {"windows-1251" ,NSWindowsCP1251StringEncoding             ,NO},
    {"cyrillic (windows-1251)", NSWindowsCP1251StringEncoding  ,NO},  // To prevent a bug in MS Hotmail
    {"windows-1252" ,NSWindowsCP1252StringEncoding             ,NO},
    {"windows-1253" ,NSWindowsCP1253StringEncoding             ,NO},
    {"windows-1254" ,NSWindowsCP1254StringEncoding             ,NO},
    {"iso-2022-jp"  ,NSISO2022JPStringEncoding                 ,NO},
    {"euc-jp"       ,NSJapaneseEUCStringEncoding               ,NO},
  };
  
  NSInteger i;

	NSString *name = [[NSString alloc] initWithData:theCharset encoding:NSUTF8StringEncoding];
	name = [name lowercaseString];
  
  for (i = 0; i < sizeof(encodings)/sizeof(encodings[0]); i++)
    {
      if ([name isEqualToString:[NSString stringWithUTF8String:encodings[i].name]])
	{
	  // Under OS X, we use CoreFoundation if necessary to convert the encoding
	  // to a NSString encoding.
#ifdef MACOSX
	  if (encodings[i].fromCoreFoundation)
	    {
	      return CFStringConvertEncodingToNSStringEncoding(encodings[i].encoding);
	    }
	  else
	    {
	      return encodings[i].encoding;
	    }
#else
	  return encodings[i].encoding;
#endif
	}
    }

  return -1;
}


//
//
//
+ (NSInteger) encodingForPart: (CWPart *) thePart
{
  NSInteger encoding = -1;

  // We get the encoding we are gonna use. We always favor the default encoding.
  
  
  if ([thePart defaultCharset])
    {
      encoding = [self encodingForCharset: [[thePart defaultCharset] dataUsingEncoding: NSASCIIStringEncoding]];
    }
  else if ([thePart charset])
    {
      encoding = [self encodingForCharset: [[thePart charset] dataUsingEncoding: NSASCIIStringEncoding]];
    }
  else
    {
      encoding = [NSString defaultCStringEncoding];
    }

  if (encoding == -1 || encoding == NSASCIIStringEncoding)
    {
      encoding = NSISOLatin1StringEncoding;
    }

  return encoding;
}


//
//
//
+ (NSString *) stringWithData: (NSData *) theData
                      charset: (NSData *) theCharset
{
  NSInteger encoding;

  if (theData == nil)
    {
      return nil;
    }

  encoding = [NSString encodingForCharset: theCharset];
  
  if (encoding == -1)
    {
#ifdef HAVE_ICONV
      NSString *aString;

      const char *i_bytes, *from_code;
      char *o_bytes;

      size_t i_length, o_length;
      NSInteger total_length, ret;
      iconv_t conv;
      
      // Instead of calling cString directly on theCharset, we first try
      // to obtain the ASCII string of the data object.
      from_code = [[theCharset asciiString] cString];
      
      if (!from_code)
	{
	  return nil;
	}
      
      conv = iconv_open("UTF-8", from_code);
      
      if ((NSInteger)conv < 0)
	{
	  // Let's assume we got US-ASCII here.
	  return [[NSString alloc] initWithData: theData  encoding: NSASCIIStringEncoding];
	}
      
      i_bytes = [theData bytes];
      i_length = [theData length];
      
      total_length = o_length = sizeof(unichar)*i_length;
      o_bytes = (char *)malloc(o_length);
      
      if (o_bytes == NULL) return nil;

      while (i_length > 0)
	{
	  ret = iconv(conv, (char **)&i_bytes, &i_length, &o_bytes, &o_length);
	  
	  if (ret == (size_t)-1)
	    {
	      iconv_close(conv);
	      
	      total_length = total_length - o_length;
	      o_bytes -= total_length;
	      free(o_bytes);
	      return nil;
	    }
	}
      
      total_length = total_length - o_length;
      o_bytes -= total_length;
      
      // If we haven't used all our allocated buffer, we shrink it.
      if (o_length > 0)
	{
	  realloc(o_bytes, total_length);
	}

      aString = [[NSString alloc] initWithData: [NSData dataWithBytesNoCopy: o_bytes
							length: total_length]
				  encoding: NSUTF8StringEncoding];
      iconv_close(conv);

      return aString;
#else
      return nil;
#endif
    }
  
  return [[NSString alloc] initWithData: theData  encoding: encoding];
}


//
//
//
// #warning return Charset instead?
- (NSString *) charset
{
  NSMutableArray *aMutableArray;
  NSString *aString;
  CWCharset *aCharset;

  NSUInteger i, j;

  aMutableArray = [[NSMutableArray alloc] initWithCapacity: 21];

  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-1"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-2"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-3"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-4"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-5"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-6"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-7"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-8"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-9"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-10"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-11"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-13"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-14"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"iso-8859-15"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"koi8-r"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"koi8-u"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"windows-1250"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"windows-1251"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"windows-1252"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"windows-1253"]];
  [aMutableArray addObject: [CWCharset charsetForName: @"windows-1254"]];


  for (i = 0; i < [self length]; i++)
    {
      for (j = 0; j < [aMutableArray count]; j++)
        {
          if (![[aMutableArray objectAtIndex: j] characterIsInCharset: [self characterAtIndex: i]])
            {
              // Character is not in the charset
              [aMutableArray removeObjectAtIndex: j];
              j--;
            }
        }

      // FIXME: can't break even if there is only one left. First we have to check
      //        whether that encoding will actually work for the entire string. If it
      //	doesn't we'll need to fall back to utf-8 (or something else that can encode
      //        _everything_).
      // 
      // Intelligent string splitting would help, of course
      //
      if ([aMutableArray count] < 1)
        {
          // We have zero or one charset
          break;
        }
    }

  if ([aMutableArray count])
    {
      aCharset = [aMutableArray objectAtIndex: 0];
      [aMutableArray removeAllObjects];
      aString = [aCharset name];
    }
  else
    {
      // We have no charset, we try to "guess" a default charset
      if ([self canBeConvertedToEncoding: NSISO2022JPStringEncoding])
	{      
	  // ISO-2022-JP is the standard of Japanese character encoding
	  aString = @"iso-2022-jp";
	}
      else
	{ 
	  // We have no charset, we return a default charset
	  aString = @"utf-8";
	}
    }

  return aString;
}

//
//
//
- (BOOL) hasREPrefix
{
  if ([self hasCaseInsensitivePrefix: @"re:"] ||
      [self hasCaseInsensitivePrefix: @"re :"] ||
      [self hasCaseInsensitivePrefix: _(@"PantomimeReferencePrefix")] ||
      [self hasCaseInsensitivePrefix: _(@"PantomimeResponsePrefix")])
    {
      return YES;
    }
  
  return NO;
}



//
//
//
- (NSString *) stringByReplacingOccurrencesOfCharacter: (unichar) theTarget
                                         withCharacter: (unichar) theReplacement
{
  NSMutableString *aMutableString;
  NSInteger len, i;
  unichar c;

  if (!theTarget || !theReplacement || theTarget == theReplacement)
    {
      return self;
    }

  len = [self length];
  
  aMutableString = [NSMutableString stringWithCapacity: len];

  for (i = 0; i < len; i++)
    {
      c = [self characterAtIndex: i];
      
      if (c == theTarget)
	{
	  [aMutableString appendFormat: @"%C", theReplacement];
	}
      else
	{
	  [aMutableString appendFormat: @"%C", c];
	}
    }

  return aMutableString;
}


//
//
//
- (NSString *) stringByDeletingLastPathComponentWithSeparator: (unichar) theSeparator
{
  NSInteger i, c;
  
  c = [self length];

  for (i = c-1; i >= 0; i--)
    {
      if ([self characterAtIndex: i] == theSeparator)
	{
	  return [self substringToIndex: i];
	}
    }

  return @"";
}


//
// 
//
- (NSString *) stringByDeletingFirstPathSeparator: (unichar) theSeparator
{
  if ([self length] && [self characterAtIndex: 0] == theSeparator)
    {
      return [self substringFromIndex: 1];
    }
  
  return self;
}

//
//
//
- (BOOL) is7bitSafe
{
  NSInteger i, len;
  
  // We search for a non-ASCII character.
  len = [self length];
  
  for (i = 0; i < len; i++)
    {
      if ([self characterAtIndex: i] > 0x007E)
	{
	  return NO;
	}
    }
  
  return YES;
}

//
//
//
+ (NSString *) stringFromRecipients: (NSArray *) theRecipients
			       type: (PantomimeRecipientType) theRecipientType
{
  CWInternetAddress *anInternetAddress;
  NSMutableString *aMutableString;
  NSInteger i, count;
  
  aMutableString = [[NSMutableString alloc] init];
  count = [theRecipients count];

  for (i = 0; i < count; i++)
    {
      anInternetAddress = [theRecipients objectAtIndex: i];
      
      if ([anInternetAddress type] == theRecipientType)
	{
	  [aMutableString appendFormat: @"%@, ", [anInternetAddress stringValue]];
	}
    }
  
  return aMutableString;
}

@end
