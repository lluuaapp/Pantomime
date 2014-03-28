/*
**  CWIMAPCacheManager.m
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

#import "CWIMAPCacheManager.h"

#include "io.h"
#import "CWConstants.h"
#import "CWFlags.h"
#import "CWFolder.h"
#import "CWIMAPMessage.h"
#import "CWParser.h"
#import "CWCacheRecord.h"


static unsigned short version = 1;

//
//
//
@implementation CWIMAPCacheManager

- (id) initWithPath: (NSString *) thePath  folder: (id) theFolder
{
    self = [super initWithPath: thePath];
    
    if (self)
    {
        NSDictionary *attributes;
        unsigned short int v;
        
        messageTable = [[NSMutableDictionary alloc] init];
        _count = _UIDValidity = 0;
        _folder = theFolder;
        
        
        if ((_fd = open([thePath UTF8String], O_RDWR|O_CREAT, S_IRUSR|S_IWUSR)) < 0) 
        {
            NSLog(@"CANNOT CREATE OR OPEN THE CACHE!)");
            abort();
        }
        
        if (lseek(_fd, 0L, SEEK_SET) < 0)
        {
            close(_fd);
            NSLog(@"UNABLE TO LSEEK INITIAL");
            abort();
        }
        
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:thePath error:NULL];
        
        // If the cache exists, lets parse it.
        if ([[attributes objectForKey: NSFileSize] integerValue])
        {
            v = read_unsigned_short(_fd);
            
            // HACK: We IGNORE all the previous cache.
            if (v != version)
            {
                //NSLog(@"Ignoring the old cache format.");
                ftruncate(_fd, 0);
                [self synchronize];
                return self;
            }
            
            _count = read_unsigned_int(_fd);
            _UIDValidity = read_unsigned_int(_fd);
        }
        else
        {
            [self synchronize];
        }
    }
    return self;
}


//
//
//
- (void) dealloc
{
    
    if (_fd >= 0) close(_fd);
    
}

//
//
//
- (void) initInRange: (NSRange) theRange
{
  CWIMAPMessage *aMessage;
  unsigned short int len, tot = 0;
  NSInteger begin, end, i;
  unsigned char *r, *s;

  if (lseek(_fd, 10L, SEEK_SET) < 0)
    {
      NSLog(@"lseek failed in initInRange:");
      abort();
    }

  begin = (NSNotFound != theRange.location) ? theRange.location : 0;
  end = (NSMaxRange(theRange) <= _count ? NSMaxRange(theRange) : _count);
  
  //NSLog(@"init from %d to %d, count = %d, size of char %d  UID validity = %d", begin, end, _count, sizeof(char), _UIDValidity);

    @autoreleasepool
    {
        s = (unsigned char *)malloc(65536);
        
        
        // We MUST skip the last few bytes...
        for (i = begin; i < end ; i++)
        {
            aMessage = [[CWIMAPMessage alloc] init];
            [aMessage setMessageNumber: i+1];
            
            // We parse the record length, date, flags, position in file and the size.
            len = read_unsigned_int(_fd);
            //NSLog(@"i = %d, len = %d", i, len);
            
            r = (unsigned char *)malloc(len-4);
            
            if (read(_fd, r, len-4) < 0) { NSLog(@"read failed"); abort(); }
            
            ((CWFlags *)[aMessage flags])->flags = read_unsigned_int_memory(r);  // FASTER and _RIGHT_ since we can't call -setFlags: on CWIMAPMessage
            [aMessage setReceivedDate: [NSCalendarDate dateWithTimeIntervalSince1970: read_unsigned_int_memory(r+4)]];
            [aMessage setUID: read_unsigned_int_memory(r+8)];
            [aMessage setSize: read_unsigned_int_memory(r+12)];
            tot = 16;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseFrom: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseInReplyTo: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseMessageID: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseReferences: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseSubject:  [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseDestination: [NSData dataWithBytes: s  length: len]
                               forType: PantomimeToRecipient
                             inMessage: aMessage
                                 quick: YES];
            tot += len+2;
            
            read_string_memory(r+tot, s, &len);
            [CWParser parseDestination: [NSData dataWithBytes: s  length: len]
                               forType: PantomimeCcRecipient
                             inMessage: aMessage
                                 quick: YES];
            
            [((CWFolder *)_folder)->allMessages addObject: aMessage];
            [messageTable setValue:aMessage forKey:[NSString stringWithFormat:@"%lu", (unsigned long)[aMessage UID]]];
            //[self addObject: aMessage]; // MOVE TO CWFIMAPOLDER
            //[((CWFolder *)_folder)->allMessages replaceObjectAtIndex: i  withObject: aMessage];
            
            free(r);
        }
        
        free(s);
    }
}

//
//
//
- (void) removeMessageWithUID: (NSUInteger) theUID
{
    [messageTable removeObjectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)theUID]];
}

//
//
//
- (CWIMAPMessage *) messageWithUID: (NSUInteger) theUID
{
    return [messageTable objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)theUID]];
}

//
//
//
- (NSUInteger) UIDValidity
{
  return _UIDValidity;
}

//
//
//
- (void) setUIDValidity: (NSUInteger) theUIDValidity
{
  _UIDValidity = theUIDValidity;
}


//
//
//
- (void) invalidate
{
  //NSLog(@"IMAPCacheManager - INVALIDATING the cache...");
  [super invalidate];
  _UIDValidity = 0;
  [self synchronize];
}


//
//
//
- (BOOL) synchronize
{
  NSUInteger len, flags;
  NSInteger i;

  _count = [_folder->allMessages count];
  
  //NSLog(@"CWIMAPCacheManager: -synchronize with folder count = %d", _count);

  if (lseek(_fd, 0L, SEEK_SET) < 0)
    {
      NSLog(@"fseek failed");
      abort();
    }
  
  // We write our cache version, count and UID validity.
  write_unsigned_short(_fd, version);
  write_unsigned_int(_fd, _count);
  write_unsigned_int(_fd, _UIDValidity);
  
  //NSLog(@"Synching flags");
  for (i = 0; i < _count; i++)
    {
      len = read_unsigned_int(_fd);
      flags = ((CWFlags *)[(CWMessage*)[_folder->allMessages objectAtIndex: i] flags])->flags;
      write_unsigned_int(_fd, flags);
      lseek(_fd, (len-8), SEEK_CUR);
    }
  //NSLog(@"Done!");
 
  return (fsync(_fd) == 0);
}


//
//
//
- (void) writeRecord: (CWCacheRecord *) theRecord  message: (id) theMessage
{
  NSUInteger len;

  if (lseek(_fd, 0L, SEEK_END) < 0)
    {
      NSLog(@"COULD NOT LSEEK TO END OF FILE");
      abort();
    }
  
  // We calculate the length of this record (including the
  // first five fields, which is 20 bytes long and is added
  // at the very end)
  len = 0;
  len += [theRecord.from length]+2;
  len += [theRecord.in_reply_to length]+2;
  len += [theRecord.message_id length]+2;
  len += [theRecord.references length]+2;
  len += [theRecord.subject length]+2;
  len += [theRecord.to length]+2;
  len += [theRecord.cc length]+22;
  write_unsigned_int(_fd, len);
  
  // We write the flags, date, position and the size of the message.
  write_unsigned_int(_fd, theRecord.flags); 
  write_unsigned_int(_fd, theRecord.date);
  write_unsigned_int(_fd, theRecord.imap_uid);
  write_unsigned_int(_fd, theRecord.size);

  // We write the read of our cached headers (From, In-Reply-To, Message-ID, References, 
  // Subject, To and Cc)
  write_string(_fd, (unsigned char *)[theRecord.from bytes], [theRecord.from length]);
  write_string(_fd, (unsigned char *)[theRecord.in_reply_to bytes], [theRecord.in_reply_to length]);
  write_string(_fd, (unsigned char *)[theRecord.message_id bytes], [theRecord.message_id length]);
  write_string(_fd, (unsigned char *)[theRecord.references bytes], [theRecord.references length]);
  write_string(_fd, (unsigned char *)[theRecord.subject bytes], [theRecord.subject length]);
  write_string(_fd, (unsigned char *)[theRecord.to bytes], [theRecord.to length]);
  write_string(_fd, (unsigned char *)[theRecord.cc bytes], [theRecord.cc length]);
  
    [messageTable setValue:theMessage forKey:[NSString stringWithFormat:@"%lu", (unsigned long)theRecord.imap_uid]];

  _count++;
}


//
//
//
- (void) expunge
{
  NSDictionary *attributes;

  NSUInteger i, len, size, total_length, v;
  unsigned char *buf;

  //NSLog(@"expunge: rewriting cache");

  if (lseek(_fd, 10L, SEEK_SET) < 0)
    {
      NSLog(@"fseek failed");
      abort();
    }
  
  attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self path] error:NULL];
  
  buf = (unsigned char *)malloc([[attributes objectForKey: NSFileSize] integerValue]);
  total_length = 0;

  for (i = 0; i < _count; i++)
    {
      //NSLog(@"===========");
      len = read_unsigned_int(_fd);
      //NSLog(@"i = %d  len = %d", i, len);
      v = htonl(len);
      memcpy((buf+total_length), (char *)&v, 4);
      
      // We write the rest of the record into the memory
      if (read(_fd, (buf+total_length+4), len-4) < 0) { NSLog(@"read failed"); abort(); }
      
      NSUInteger uid = read_unsigned_int_memory(buf+total_length+12);

      if ([self messageWithUID: uid])
	{
	  total_length += len;
	}
      else
	{
	  //NSLog(@"Message not found! uid = %d  table count = %d", uid, NSCountMapTable(_table));
	}
    }

  if (lseek(_fd, 0L, SEEK_SET) < 0)
    {
      NSLog(@"fseek failed");
      abort();
    }

  // We write our cache version, count, modification date our new size
  _count = [_folder->allMessages count];
  size = total_length+10;

  write_unsigned_short(_fd, version);
  write_unsigned_int(_fd, _count);
  write_unsigned_int(_fd, _UIDValidity);

  // We write our memory cache
  write(_fd, buf, total_length);

  ftruncate(_fd, size);
  free(buf);

  //NSLog(@"Done! New size = %d", size);
}
@end
