/*
**  CWPOP3CacheManager.h
**
**  Copyright (c) 2001-2007
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

@class CWPOP3CacheObject;
@class CWCacheRecord;

/*!
  @class CWPOP3CacheManager
  @discussion This class provides trivial extensions to the
              CWCacheManager superclass for CWPOP3Folder instances.
	      This cache manager makes use of CWPOP3CacheObject
	      instances instead of CWPOP3Message instance for
	      speed and size requirements restrictions.
*/
@interface CWPOP3CacheManager: CWCacheManager
{
  @private
    NSMutableDictionary *_messageTable;
    NSUInteger _count;
    NSInteger _fd;
}

/*!
  @method dateForUID:
  @discussion This method is used to verify if the specific cache
              record with the POP3 UID <i>theUID</i> is present
              in the cache. It also returns the date associated
	      to this specific UID.
  @param theUID The UID to verify.
  @result The date of the associated UID, nil if not present in
          the cache..
*/
- (NSDate *) dateForUID: (NSString *) theUID;

/*!
  @method writeRecord:
  @discussion This method is used to write a cache record to disk.
  @param theRecord The record to write.
*/
- (void) writeRecord:(CWCacheRecord *)theRecord;
@end
