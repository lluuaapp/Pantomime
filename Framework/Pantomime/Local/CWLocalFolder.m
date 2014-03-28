/*
**  CWLocalFolder.m
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
#import "CWLocalFolder.h"

#import "CWConstants.h"
#import "CWRegEx.h"
#import "CWFlags.h"
#import "CWInternetAddress.h"
#import "CWLocalCacheManager.h"
#import "CWLocalFolder+maildir.h"
#import "CWLocalFolder+mbox.h"
#import "CWLocalMessage.h"
#import "CWLocalStore.h"
#import "CWMIMEMultipart.h"
#import "NSData+CWExtensions.h"
#import "NSFileManager+CWExtensions.h"
#import "NSString+CWExtensions.h"

//
// Private methods
//
@interface CWLocalFolder (Private)

- (BOOL) _findInPart: (CWPart *) thePart
              string: (NSString *) theString
                mask: (PantomimeSearchMask) theMask
             options: (PantomimeSearchOption) theOptions;
@end


//
//
//
@implementation CWLocalFolder

- (id) initWithPath: (NSString *) thePath
{
  NSString *aString;
  BOOL b;

  self = [super initWithName: [thePath lastPathComponent]];

  // We initialize those ivars in order to make sure we don't call
  // the assertion handler when using a maildir-based mailbox.
  stream = NULL;
  fd = -1;

  [self setPath: thePath];
   
  if ([[NSFileManager defaultManager] fileExistsAtPath: [NSString stringWithFormat: @"%@/new", _path]  isDirectory: &b] && b)
    {
      [self setType: PantomimeFormatMaildir];
    }
  else
    {
      [self setType: PantomimeFormatMbox];

      // We verify if a <name>.tmp was present. If yes, we simply remove it.
      if ([[NSFileManager defaultManager] fileExistsAtPath: [thePath stringByAppendingString:@".tmp"]])
	{
	  [[NSFileManager defaultManager] removeItemAtPath:[thePath stringByAppendingString: @".tmp"] error:NULL];
	}
    }

  if ((_type == PantomimeFormatMbox) && ![self open_mbox])
    {
      return nil;
    }
     
  // We load and set our cache from the file (creating it if it doesn't exist)
  aString = [NSString stringWithFormat: @"%@/.%@.cache", [_path substringToIndex: ([_path length] - [[_path lastPathComponent] length])],
		      [_path lastPathComponent]];
  
  [self setCacheManager: [[CWLocalCacheManager alloc] initWithPath: aString  folder: self]];

  return self;
}


//
//
//
- (void) dealloc
{
  //NSLog(@"LocalFolder: -dealloc. fd = %d, stream is NULL? %d", fd, (stream == NULL));

  NSAssert3(fd < 0 && !stream, @"-[%@ %@, path %@] must invoke -close before - dealloc'ing",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd), _path);
}


//
//
//
- (void) parse: (BOOL) theBOOL
{  
  //
  // If we already have messages in our folder, that means parse was already invoked.
  // In this particular case, we do nothing. If we got no messages but we already
  // have invoked -parse before, that won't do any harm.
  //
  if ([allMessages count])
    {
      // 
      // If we are using a maildir-based mailbox, we scan the /new and /tmp directories
      // in order to move any messages in there to our /cur directory.
      //
      if (_type == PantomimeFormatMaildir)
	{  
	  NSFileManager *aFileManager;
	  
	  aFileManager = [NSFileManager defaultManager];
	  
		if ([[aFileManager contentsOfDirectoryAtPath:[NSString stringWithFormat: @"%@/new", _path] error:NULL] count] > 0 || 
	      [[aFileManager contentsOfDirectoryAtPath:[NSString stringWithFormat: @"%@/tmp", _path] error:NULL] count] > 0)
	    {
            @autoreleasepool
            {
                [self parse_maildir: @"new"  all: theBOOL];
                [self parse_maildir: @"tmp"  all: theBOOL];
            }
	    }
	}


      PERFORM_SELECTOR_2([[self store] delegate], @selector(folderPrefetchCompleted:), PantomimeFolderPrefetchCompleted, self, @"Folder");
      return;
    }

 
  //
  // We are NOT using the cache.
  //
    @autoreleasepool
    {
        //
        // Parse the mail store. For mbox, it will be one file.
        // For maildir, there will be a file for each message 
        // in the "cur" and "new" sub-directories.
        //
        switch (_type)
        {
            case PantomimeFormatMaildir:
                [self parse_maildir: @"cur"  all: theBOOL];
                [self parse_maildir: @"new"  all: theBOOL];
                break;
            case PantomimeFormatMbox:
            default:
                [self parse_mbox: _path  stream: [self stream]  flags: nil  all: theBOOL];
                break;
        }
        
        PERFORM_SELECTOR_2([[self store] delegate], @selector(folderPrefetchCompleted:), PantomimeFolderPrefetchCompleted, self, @"Folder");
    }
}





//
// This method is used to close the current folder.
// It creates a temporary file where the folder is written to and
// it replaces the current folder file by this one once everything is
// alright.
//
- (void) close
{  
  //NSLog(@"LocalFolder: -close");

  // We close the current folder
  if (_type == PantomimeFormatMbox || _type == PantomimeFormatMailSpoolFile)
    {
      [self close_mbox];
    }
  
  // We synchorize our cache one last time
  if (_type == PantomimeFormatMbox || _type == PantomimeFormatMaildir)
    {
      [self.cacheManager synchronize];
    }

  POST_NOTIFICATION(PantomimeFolderCloseCompleted, _store, [NSDictionary dictionaryWithObject: self  forKey: @"Folder"]);
  PERFORM_SELECTOR_2([_store delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");

  // We remove our current folder from the list of open folders in the store
  [_store removeFolderFromOpenFolders: self];
}


//
// This method permanently removes messages that have the flag PantomimeDeleted.
//
- (void) expunge
{
  switch (_type)
    {
    case PantomimeFormatMbox:
      [self expunge_mbox];
      break;
    case PantomimeFormatMaildir:
      [self expunge_maildir];
      break;
    default:
      {
	// Do nothing.
      }
    }
  
  if (_allContainers)
    {
      [self thread];
    }
}


//
// access / mutation methods
//

//
// This method returns the file descriptor used by this local folder.
//
- (NSInteger) fd
{
  return fd;
}


//
// This method sets the file descriptor to be used by this local folder.
//
- (void) setFD: (NSInteger) theFD
{
  fd = theFD;
}


//
//
//
- (NSString *) path
{
  return _path;
}


- (void) setPath: (NSString *) thePath
{
  ASSIGN(_path, thePath);
}


//
// This method returns the file stream used by this local folder.
//
- (FILE *) stream
{
  return stream;
}


//
// This method sets the file stream to be used by this local folder.
//
- (void) setStream: (FILE *) theStream
{
  stream = theStream;
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
- (PantomimeFolderMode) mode
{
  return PantomimeReadWriteMode;
}


//
// This method is used to append a message to this folder. The message
// must be specified in raw source. The message is appended to the 
// local file and is initialized after.
//
- (void) appendMessageFromRawSource: (NSData *) theData
                              flags: (CWFlags *) theFlags
{
    NSString *aMailFile;
    NSMutableData *aMutableData;
    NSDictionary *aDictionary;
    CWLocalMessage *aMessage;
    NSRange aRange;
    FILE *aStream;
    
    long mark, filePosition;
    
    @autoreleasepool
    {
        aMutableData = [[NSMutableData alloc] initWithData: theData];
        aMailFile = nil;
        aStream = NULL;
        
        // Set the appropriate stream
        if (_type == PantomimeFormatMaildir)
        {
            aMailFile = [NSString stringWithFormat: @"%@:%@", [NSString stringWithFormat: @"%ld.%d%d%lu.%@",
                                                               time(NULL), 
                                                               getpid(),
                                                               rand(),
                                                               (unsigned long)[(CWLocalCacheManager*)self.cacheManager count],
                                                               [[NSHost currentHost] name]],
                         ((id)theFlags ? (id)[theFlags maildirString] : (id)@"2,")];
            
            NSString *aMailFilePath = [NSString stringWithFormat: @"%@/cur/%@", _path, aMailFile];
            
            aStream = fopen([aMailFilePath UTF8String], "w+");
            
            if (!aStream)
            {
                aDictionary = (theFlags ? [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", theFlags, @"Flags", nil] :
                               [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", nil]);
                PERFORM_SELECTOR_3([[self store] delegate], @selector(folderAppendFailed:), PantomimeFolderAppendFailed, aDictionary);
                return;
            }
        }
        else
        {
            aStream = [self stream];
            // aMailFilePath = _path;
        }
        
        
        // We keep the position where we were in the file
        mark = ftell(aStream);
        
        if (mark < 0)
        {
            aDictionary = (theFlags ? [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", theFlags, @"Flags", nil] :
                           [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", nil]);
            PERFORM_SELECTOR_3([[self store] delegate], @selector(folderAppendFailed:), PantomimeFolderAppendFailed, aDictionary)
            return;
        }
        
        //
        // If the message doesn't contain the "From ", we add it.
        //
        // From qmail's mbox(5) man page:
        //
        //   The  From_  line  always  looks  like  From  envsender  date
        //   moreinfo.  envsender is one word, without spaces or tabs; it
        //   is usually the envelope sender of the message.  date is  the
        //   delivery date of the message.  It always contains exactly 24
        //   characters in asctime format.  moreinfo is optional; it  may
        //   contain arbitrary information.
        //
        if (![aMutableData hasCPrefix: "From "] && _type == PantomimeFormatMbox)
        {
            NSString *aSender, *aString;
            NSCalendarDate *aDate;
            
            // We get a valid sender. We can't use the envelope sender
            // so let's use the From: header instead.
            if (NO)//[aMessage from] && [[aMessage from] address])
            {
                aSender = [[aMessage from] address];
            }
            else
            {
                // If there was no envelope sender, by convention the mailbox name used is MAILER-DAEMON.
                // Whitespace characters in the envelope sender mailbox name are by convention replaced by hyphens.
                aSender = @"MAILER-DAEMON";
            }
            
            // We get a valid delivery date. Again, we can't get
            // the real one of we use the Date: header instead.
            aDate = nil;//[aMessage receivedDate];
            
            if (!aDate)
            {
                aDate = [NSCalendarDate calendarDate];
            }
            
            aString = [NSString stringWithFormat: @"From %@ %@\n", aSender, 
                       [aDate descriptionWithCalendarFormat: @"%a %b %d %H:%M:%S %Y"]];
            [aMutableData insertCString: [aString UTF8String] atIndex: 0];
        }
        
        // We MUST replace every "\nFrom " in the message by "\n From ", if we have a mbox file.
        if (_type == PantomimeFormatMbox)
        {
            aRange = [aMutableData rangeOfCString: "\nFrom "];
            
            while (aRange.location != NSNotFound)
            {
                [aMutableData replaceBytesInRange: aRange
                                        withBytes: "\n From "];
                
                aRange = [aMutableData rangeOfCString: "\nFrom "
                                              options: 0
                                                range: NSMakeRange(aRange.location + aRange.length,
                                                                   [aMutableData length] - aRange.location - aRange.length) ];
            }
            
            //
            // From qmail's mbox(5) man page:
            //
            //  A message encoded in mbox format begins with a  From_  line,
            //  continues  with a series of non-From_ lines, and ends with a
            //  blank line.
            //  ...
            //  The final line is a completely  blank  line  (no  spaces  or
            //  tabs).  Notice that blank lines may also appear elsewhere in
            //  the message.
            //
            [aMutableData appendCString: "\n\n"];
        }
        
        // We go at the end of the file...
        if (fseek(aStream, 0L, SEEK_END) < 0)
        {
            aDictionary = (theFlags ? [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", theFlags, @"Flags", nil] :
                           [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", nil]);
            PERFORM_SELECTOR_3([[self store] delegate], @selector(folderAppendFailed:), PantomimeFolderAppendFailed, aDictionary)
            
            return;
        }
        
        // We get the position of our message in the file. We need
        // to keep it in order to correctly seek back at the beginning
        // of the message to parse it.
        filePosition = ftell(aStream);
        
        // We write the string to our local folder
        if (fwrite([aMutableData bytes], 1, [aMutableData length], aStream) <= 0)
        {
            aDictionary = (theFlags ? [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", theFlags, @"Flags", nil] :
                           [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", nil]);
            PERFORM_SELECTOR_3([[self store] delegate], @selector(folderAppendFailed:), PantomimeFolderAppendFailed, aDictionary)
            
            return;
        }
        
        // We parse the message using our code, which will also update
        // our cache if present
        fseek(aStream, filePosition, SEEK_SET);
        [self parse_mbox: aMailFile  stream: aStream  flags: theFlags  all: NO];
        
        // We get back our message
        aMessage = [allMessages objectAtIndex: [allMessages count]-1];
        
        // We set our flags
        if (theFlags)
        {
            [aMessage setFlags: theFlags];
        }
        
#if 0
        // If we are processing a maildir, close the stream and move the message into the "cur" directory.
        if (_type == PantomimeFormatMaildir)
        {
            NSString *curFilePath;
            
            fclose(aStream);
            curFilePath = [NSString stringWithFormat: @"%@/cur/%@", _path, aMailFile];
            
            if ([[NSFileManager defaultManager] movePath: aMailFilePath  toPath: curFilePath  handler: nil])
            {
                [aMessage setMailFilename: curFilePath];
                
                // We enforce the file attribute (0600)
                [[NSFileManager defaultManager] enforceMode: 0600  atPath: curFilePath];
            }
        }
        
        // We append it to our folder and our cache manager, if we need to.
        [self appendMessage: aMessage];
        
        if (_cacheManager)
        {
            [_cacheManager addObject: aMessage];
        }
        
#endif  
        
        // We finally reset our fp where the mark was set
        if (_type != PantomimeFormatMaildir)
        {
            fseek(aStream, mark, SEEK_SET);
        }
        else
        {
            fclose(aStream);
        }
        
        aDictionary = (theFlags ? [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", theFlags, @"Flags", nil] :
                       [NSDictionary dictionaryWithObjectsAndKeys: aMutableData, @"NSData", self, @"Folder", nil]);
        PERFORM_SELECTOR_3([[self store] delegate], @selector(folderAppendCompleted:), PantomimeFolderAppendCompleted, aDictionary);
    }
}


//
//
//
- (void) search: (NSString *) theString
	   mask: (PantomimeSearchMask) theMask
	options: (PantomimeSearchOption) theOptions
{
    NSMutableArray *aMutableArray;
    NSDictionary *userInfo;
    CWLocalMessage *aMessage;
    
    NSInteger i, count;
    
    aMutableArray = [NSMutableArray array];
    
    @autoreleasepool
    {
        count = [allMessages count];
        
        for (i = 0; i < count; i++)
        {
            aMessage = [allMessages objectAtIndex: i];
            
            //
            // We search inside the Message's content.
            //
            if (theMask == PantomimeContent)
            {
                BOOL messageWasInitialized, messageWasMatched;
                
                messageWasInitialized = [aMessage isInitialized];
                messageWasMatched = NO;
                
                if (!messageWasInitialized)
                {
                    [aMessage setInitialized: YES];
                }
                
                // We search recursively in all Message's parts
                if ([self _findInPart: (CWPart *)aMessage
                               string: theString
                                 mask: theMask
                              options: theOptions])
                {
                    [aMutableArray addObject: aMessage];
                    messageWasMatched = YES;
                }
                
                // We restore the message initialization status if the message doesn't match
                if (!messageWasInitialized && !messageWasMatched)
                {
                    [aMessage setInitialized: NO];
                }
            }
            //
            // We aren't searching in the content. For now, we search only in the Subject header value.
            //
            else
            {
                NSString *aString;
                
                aString = nil;
                
                switch (theMask)
                {
                    case PantomimeFrom:
                        if ([aMessage from])
                        {
                            aString = [[aMessage from] stringValue];
                        }
                        break;
                        
                    case PantomimeTo:
                        aString = [NSString stringFromRecipients: [aMessage recipients]
                                                            type: PantomimeToRecipient];
                        break;
                        
                    case PantomimeSubject:
                    default:
                        aString = [aMessage subject];
                }
                
                
                if (aString)
                {
                    if ((theOptions&PantomimeRegularExpression))
                    {
                        NSArray *anArray;
                        
                        anArray = [CWRegEx matchString: aString
                                          withPattern : theString
                                       isCaseSensitive: (theOptions&PantomimeCaseInsensitiveSearch)];
                        
                        if ([anArray count] > 0)
                        {
                            [aMutableArray addObject: aMessage];
                        }
                    }
                    else
                    {
                        NSRange aRange;
                        
                        if ((theOptions&PantomimeCaseInsensitiveSearch))
                        {
                            aRange = [aString rangeOfString: theString
                                                    options: NSCaseInsensitiveSearch]; 
                        }
                        else
                        {
                            aRange = [aString rangeOfString: theString]; 
                        }
                        
                        if (aRange.length > 0)
                        {
                            [aMutableArray addObject: aMessage];
                        }
                    }
                }
            }
        } // for (i = 0; ...
        
    }
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys: self, @"Folder", aMutableArray, @"Results", nil];
    
    POST_NOTIFICATION(PantomimeFolderSearchCompleted, [self store], userInfo);
    PERFORM_SELECTOR_3([[self store] delegate], @selector(folderSearchCompleted:), PantomimeFolderSearchCompleted, userInfo);
}

@end


//
// Private methods
//
@implementation CWLocalFolder (Private)

- (BOOL) _findInPart: (CWPart *) thePart
	      string: (NSString *) theString
		mask: (PantomimeSearchMask) theMask
             options: (PantomimeSearchOption) theOptions
  
{  
  if ([[thePart content] isKindOfClass:[NSString class]])
    {
      // The part content is text; we perform the search      
      if ((theOptions&PantomimeRegularExpression))
	{
	  // The search pattern is a regexp

	  NSArray *anArray;
	  
	  anArray = [CWRegEx matchString: (NSString *)[thePart content]
			     withPattern : theString
			     isCaseSensitive: (theOptions&PantomimeCaseInsensitiveSearch)];
		  
	  if ([anArray count] > 0)
	    {
	      return YES;
	    }
	}
      else
	{
	  NSRange range;

	  if (theOptions&PantomimeCaseInsensitiveSearch)
	    {
	      range = [(NSString *)[thePart content] rangeOfString: theString
				   options: NSCaseInsensitiveSearch];
	    }
	  else
	    {
	      range = [(NSString *)[thePart content] rangeOfString: theString]; 
	    }
		  
	  if (range.length > 0)
	    {
	      return YES;
	    }
	}
    }
  
  else if ([[thePart content] isKindOfClass: [CWMessage class]])
    {
      // The part content is a message; we parse it recursively
      return [self _findInPart: (CWPart *)[thePart content]
		   string: theString
		   mask: theMask
		   options: theOptions];
    }
  else if ([[thePart content] isKindOfClass: [CWMIMEMultipart class]])
    {
      // The part content contains many part; we parse each part
      CWMIMEMultipart *aMimeMultipart;
      CWPart *aPart;
      NSInteger i, count;
      
      aMimeMultipart = (CWMIMEMultipart*)[thePart content];
      count = [aMimeMultipart count];
      
      for (i = 0; i < count; i++)
	{
	  // We get our part
	  aPart = [aMimeMultipart partAtIndex: i];
	  
	  if ([self _findInPart: (CWPart *)aPart
		     string: theString 
		     mask: theMask
		     options: theOptions])
	    {
	      return YES;
	    }
	}
    }
  
  return NO;
}

@end
