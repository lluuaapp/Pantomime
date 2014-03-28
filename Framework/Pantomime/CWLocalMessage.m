/*
**  CWLocalMessage.m
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

#import "CWLocalMessage.h"

#include "io.h"
#import "CWConstants.h"
#import "CWLocalFolder.h"
#import "CWLocalStore.h"
#import "CWMIMEUtility.h"
#import "NSData+CWExtensions.h"


static NSInteger currentLocalMessageVersion = 1;

//
//
//
@implementation CWLocalMessage 

- (id) init
{
  self = [super init];
  [CWLocalMessage setVersion: currentLocalMessageVersion];

  _mailFilename = nil;
  _file_position = 0;

  return self;
}


//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
  [super encodeWithCoder: theCoder];

  [CWLocalMessage setVersion: currentLocalMessageVersion];
	
  [theCoder encodeObject: [NSNumber numberWithLong: _file_position]];

  // Store the name of the file; we need it for local.
  [theCoder encodeObject: _mailFilename];

  // Store the message type; useful to have.
  [theCoder encodeObject: [NSNumber numberWithInteger:_type]];
}


//
//
//
- (id) initWithCoder: (NSCoder *) theCoder
{
  self = [super initWithCoder: theCoder];

  _file_position = [[theCoder decodeObject] longValue];

  // Retrieve the mail file name which we need for local storage.
  [self setMailFilename: [theCoder decodeObject]];
  
  // Retrieve the message type
  _type = [[theCoder decodeObject] integerValue];
  
  return self;
}


//
// access / mutation methods
//
- (NSUInteger) filePosition
{
  return _file_position;
}

- (void) setFilePosition: (NSUInteger) theFilePosition
{
  _file_position = theFilePosition;
}

//
//
//
- (PantomimeFolderFormat) type
{
  return _type;
}

- (void) setType: (PantomimeFolderFormat) theType
{
  _type = theType;
}


//
//
//
- (NSString *) mailFilename
{
  return _mailFilename;
}

- (void) setMailFilename: (NSString *) theFilename
{	
  ASSIGN(_mailFilename, theFilename);
}

//
//
//
- (NSData *) rawSource
{
  NSData *aData;
  char *buf;
  NSInteger fd;

  // If we are reading from a mbox file, the file is already open
  if ([(CWLocalFolder *)[self folder] type] == PantomimeFormatMbox)
    {
      fd = [(CWLocalFolder *)[self folder] fd];
    }
  // For maildir, we need to open the specific file
  else
    {
#ifdef __MINGW32__
      fd = _open([[NSString stringWithFormat: @"%@/cur/%@", [(CWLocalFolder *)[self folder] path], _mailFilename] UTF8String], O_RDONLY);
#else
      fd = open([[NSString stringWithFormat: @"%@/cur/%@", [(CWLocalFolder *)[self folder] path], _mailFilename] UTF8String], O_RDONLY);
#endif
    }

  if (fd < 0)
    {
      NSLog(@"Unable to get the file descriptor");
      return nil;
    }
  
  //NSLog(@"Seeking to %d", [self filePosition]);

#ifdef __MINGW32__
  if (_lseek(fd, [self filePosition], SEEK_SET) < 0)
#else  
  if (lseek(fd, [self filePosition], SEEK_SET) < 0)
#endif
    {
      NSLog(@"Unable to seek.");
      return nil;
    }
  
  buf = (char *)malloc(_size*sizeof(char));

  if (buf != NULL && read_block(fd, buf, _size) >= 0)
    {
      aData = [NSData dataWithBytesNoCopy: buf  length: _size  freeWhenDone: YES];
    }
  else
    {
      free(buf);
      aData = nil;
    }
  
  // If we are operating on a local file, close it.
  if ([(CWLocalFolder *)[self folder] type] == PantomimeFormatMaildir)
    {
      safe_close(fd);
    }
  
  //NSLog(@"READ |%@|", [aData asciiString]);

  return aData;
}


//
// This method is called to initialize the message if it wasn't.
// If we set it to NO and we HAD a content, we release the content;
//
- (void) setInitialized: (BOOL) aBOOL
{
    [super setInitialized: aBOOL];
    
    if (aBOOL)
    {
        NSData *aData;
        
        aData = [self rawSource];
        
        if (aData)
        {
            NSRange aRange;
            
            aRange = [aData rangeOfCString: "\n\n"];
            
            if (aRange.length == 0)
            {
                [super setInitialized: NO];
                return;
            }
            
            [self setHeadersFromData: [aData subdataWithRange: NSMakeRange(0,aRange.location)]];
            [CWMIMEUtility setContentFromRawSource:
             [aData subdataWithRange:
              NSMakeRange(aRange.location + 2, [aData length]-(aRange.location+2))]
                                            inPart: self];
        }
        else
        {
            [super setInitialized: NO];
            return;
        }
    }
    else
    {
        _content = nil;
    } 
}

@end
