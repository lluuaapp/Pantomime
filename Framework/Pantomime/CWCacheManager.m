/*
**  CWCacheManager.m
**
**  Copyright (c) 2004-2006
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

#import "CWCacheManager.h"
#import "CWConstants.h"


@implementation CWCacheManager

- (id) initWithPath:(NSString*)thePath
{
    if ((self = [super init]))
    {
        _cache = [[NSMutableArray alloc] init];
        _path = thePath;
    }
    
    return self;
}

//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
    // Do nothing.
}

- (id) initWithCoder: (NSCoder *) theCoder
{
    // Do nothing.
    return nil;
}

//
//
//
- (void) invalidate
{
    //[_cache removeAllObjects];
}

//
//
//
- (BOOL) synchronize
{
    BOOL result = NO;
    
    // We do NOT write empty cache files on disk.
    //if ([_cache count] == 0) return YES;
    
    @try {
        result = [NSArchiver archiveRootObject:self  toFile:_path];
    }
    @catch (NSException *exception) {
        NSLog(@"Failed to synchronize the %@ cache - not written to disk.", _path);
        result = NO;
    }
    
    return result;
}

//
// For compatibility - will go away in pre4
//
- (NSArray *) obtainCache
{
    return (_cache ? [NSArray arrayWithArray:_cache] : @[]);
}

@end
