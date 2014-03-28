/*
**  CWCharset.m
**
**  Copyright (c) 2001-2004
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

#import "CWCharset.h"

#import "CWConstants.h"
#import "CWISO8859_1.h"
#import "CWISO8859_2.h"
#import "CWISO8859_3.h"
#import "CWISO8859_4.h"
#import "CWISO8859_5.h"
#import "CWISO8859_6.h"
#import "CWISO8859_7.h"
#import "CWISO8859_8.h"
#import "CWISO8859_9.h"
#import "CWISO8859_10.h"
#import "CWISO8859_11.h"
#import "CWISO8859_13.h"
#import "CWISO8859_14.h"
#import "CWISO8859_15.h"
#import "CWKOI8_R.h"
#import "CWKOI8_U.h"
#import "CWWINDOWS_1250.h"
#import "CWWINDOWS_1251.h"
#import "CWWINDOWS_1252.h"
#import "CWWINDOWS_1253.h"
#import "CWWINDOWS_1254.h"

static NSMutableDictionary *charset_name_description = nil;
static NSMutableDictionary *charset_instance_cache = nil;

@interface CWCharset ()

@property NSInteger numCodes;
@property NSInteger identityMap;

@end

@implementation CWCharset

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        charset_instance_cache = [[NSMutableDictionary alloc] init];
        charset_name_description = [[NSMutableDictionary alloc] init];
    });
}


//
//
//
- (id) initWithCodeCharTable: (const struct charset_code *) c
		      length: (NSInteger) n
{
    self = [super init];
    
    if (self)
    {
        _codes = c;
        _numCodes = n;
        _identityMap = 0x20;
        
        if ((n > 0) &&
            (_codes[0].code == 0x20))
        {
            NSInteger i = 1;
            for (_identityMap = 0x20;
                 (i < _numCodes) && (_codes[i].code == _identityMap + 1) && (_codes[i].value == _identityMap + 1);
                 _identityMap++,i++)
            { }
        }
    }
    
    return self;
}


//
// TODO: what should this return for eg. \t and \n?
//
- (NSInteger) codeForCharacter: (unichar) theCharacter
{
    NSInteger i;
    
    if (theCharacter <= _identityMap)
    {
        return theCharacter;
    }
    
    for (i = 0; i < _numCodes; i++)
    {
        if (_codes[i].value == theCharacter)
        {
            return _codes[i].code;
        }
    }
    
    return -1;
}


//
//
//
- (BOOL) characterIsInCharset: (unichar) theCharacter
{
    if (theCharacter <= _identityMap)
    {
        return YES;
    }
    
    if ([self codeForCharacter: theCharacter] != -1)
    {
        return YES;
    }
    
    return NO;
}


//
// Returns the name of the Charset. Like:
// "iso-8859-1"
// 
- (NSString *) name
{
    NSAssert2(0, @"Subclass %@ should override %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    return nil;
}


//
//
//
+ (NSDictionary *) allCharsets
{
    if (![charset_name_description count])
    {
        [charset_name_description setObject:NSLocalizedString(@"Western European (ISO Latin 1)", nil)     forKey: @"iso-8859-1"];
        [charset_name_description setObject:NSLocalizedString(@"Western European (ISO Latin 9)", nil)     forKey: @"iso-8859-15"];
        [charset_name_description setObject:NSLocalizedString(@"Western European (Windows Latin 1)", nil) forKey: @"windows-1252"];
        
        [charset_name_description setObject:NSLocalizedString(@"Japanese (ISO 2022-JP)", nil)             forKey: @"iso-2022-jp"];
        [charset_name_description setObject:NSLocalizedString(@"Japanese (EUC-JP)", nil)                  forKey: @"euc-jp"];
        
        [charset_name_description setObject:NSLocalizedString(@"Traditional Chinese (BIG5)", nil)         forKey: @"big5"];
        
        [charset_name_description setObject:NSLocalizedString(@"Arabic (ISO 8859-6)", nil)                forKey: @"iso-8859-6"];
        
        [charset_name_description setObject:NSLocalizedString(@"Greek (ISO 8859-7)", nil)                 forKey: @"iso-8859-7"];
        [charset_name_description setObject:NSLocalizedString(@"Greek (Windows)", nil)                    forKey: @"windows-1253"];
        
        [charset_name_description setObject:NSLocalizedString(@"Hebrew (ISO 8859-8)", nil)                forKey: @"iso-8859-8"];
        
        [charset_name_description setObject:NSLocalizedString(@"Cyrillic (ISO 8859-5)", nil)              forKey: @"iso-8859-5"];
        [charset_name_description setObject:NSLocalizedString(@"Cyrillic (KOI8-R)", nil)                  forKey: @"koi8-r"];
        [charset_name_description setObject:NSLocalizedString(@"Cyrillic (Windows)", nil)                 forKey: @"windows-1251"];
        
        [charset_name_description setObject:NSLocalizedString(@"Thai (ISO 8859-11)", nil)                 forKey: @"iso-8859-11"];
        
        [charset_name_description setObject:NSLocalizedString(@"Central European (ISO Latin 2)", nil)     forKey: @"iso-8859-2"];
        [charset_name_description setObject:NSLocalizedString(@"Central European (Windows Latin 2)", nil) forKey: @"windows-1250"];
        
        [charset_name_description setObject:NSLocalizedString(@"Turkish (Latin 5)", nil)                  forKey: @"iso-8859-9"];
        [charset_name_description setObject:NSLocalizedString(@"Turkish (Windows)", nil)                  forKey: @"windows-1254"];
        
        [charset_name_description setObject:NSLocalizedString(@"South European (ISO Latin 3)", nil)       forKey: @"iso-8859-3"];
        [charset_name_description setObject:NSLocalizedString(@"North European (ISO Latin 4)", nil)       forKey: @"iso-8859-4"];
        
        [charset_name_description setObject:NSLocalizedString(@"Nordic (ISO Latin 6)", nil)               forKey: @"iso-8859-10"];
        [charset_name_description setObject:NSLocalizedString(@"Baltic Rim (ISO Latin 7)", nil)           forKey: @"iso-8859-13"];
        [charset_name_description setObject:NSLocalizedString(@"Celtic (ISO Latin 8)", nil)               forKey: @"iso-8859-14"];
        
        [charset_name_description setObject:NSLocalizedString(@"Simplified Chinese (GB2312)", nil)        forKey: @"gb2312"];
        [charset_name_description setObject:NSLocalizedString(@"UTF-8", nil)                              forKey: @"utf-8"];
        
#ifdef MACOSX
        [charset_name_description setObject:NSLocalizedString(@"Korean (EUC-KR/KS C 5601)", nil)          forKey: @"euc-kr"];
        [charset_name_description setObject:NSLocalizedString(@"Japanese (Win/Mac)", nil)                 forKey: @"shift_jis"];
#endif
    }
    
    return charset_name_description;
}


//
// This method is used to obtain a charset from the name
// of this charset. It caches this charset for future
// usage when it's found.
//
+ (CWCharset *) charsetForName: (NSString *) theName
{
    CWCharset *theCharset;
    
    theCharset = [charset_instance_cache objectForKey:[theName lowercaseString]];
    
    if (!theCharset)
    {
        CWCharset *aCharset;
        
        if ([[theName lowercaseString] isEqualToString: @"iso-8859-2"])
        {
            aCharset = [[CWISO8859_2 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-3"])
        {
            aCharset = [[CWISO8859_3 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-4"])
        {
            aCharset = [[CWISO8859_4 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-5"])
        {
            aCharset = [[CWISO8859_5 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-6"])
        {
            aCharset = [[CWISO8859_6 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-7"])
        {
            aCharset = [[CWISO8859_7 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-8"])
        {
            aCharset = [[CWISO8859_8 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-9"])
        {
            aCharset = [[CWISO8859_9 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-10"])
        {
            aCharset = [[CWISO8859_10 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-11"])
        {
            aCharset = [[CWISO8859_11 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-13"])
        {
            aCharset = [[CWISO8859_13 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-14"])
        {
            aCharset = [[CWISO8859_14 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"iso-8859-15"])
        {
            aCharset = [[CWISO8859_15 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"koi8-r"])
        {
            aCharset = [[CWKOI8_R alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"koi8-u"])
        {
            aCharset = [[CWKOI8_U alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"windows-1250"])
        {
            aCharset = [[CWWINDOWS_1250 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"windows-1251"])
        {
            aCharset = [[CWWINDOWS_1251 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"windows-1252"])
        {
            aCharset = [[CWWINDOWS_1252 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"windows-1253"])
        {
            aCharset = [[CWWINDOWS_1253 alloc] init];
        }
        else if ([[theName lowercaseString] isEqualToString: @"windows-1254"])
        {
            aCharset = [[CWWINDOWS_1254 alloc] init];
        }
        else
        {
            aCharset = [[CWISO8859_1 alloc] init];
        }
        
        [charset_instance_cache setObject: aCharset
                                   forKey: [theName lowercaseString]];
        
        return aCharset;
    }
    
    return theCharset;
}

@end
