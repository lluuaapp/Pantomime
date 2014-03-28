/*
**  CWTCPConnection.m
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

#import "CWTCPConnection.h"
#import "NSStream+IHExtensions.h"

#import "CWConstants.h"


#define DEFAULT_TIMEOUT 60

//
//
//
@implementation CWTCPConnection

@synthesize delegate;

//
//
//
- (id) initWithName:(NSString*)theName
               port:(unsigned short)thePort
           delegate:(id<CWConnectionDelegate>)inDelegate
         background:(BOOL)theBOOL
{
    return [self initWithName:theName
                         port:thePort
                     delegate:inDelegate
            connectionTimeout:DEFAULT_TIMEOUT
                  readTimeout:DEFAULT_TIMEOUT
                 writeTimeout:DEFAULT_TIMEOUT
                   background:theBOOL];
}


//
// This methods throws an exception if the connection timeout
// is exhausted and the connection hasn't been established yet.
//
- (id) initWithName:(NSString *)theName
               port:(unsigned short)thePort
           delegate:(id<CWConnectionDelegate>)inDelegate
  connectionTimeout:(NSUInteger)theConnectionTimeout
        readTimeout:(NSUInteger)theReadTimeout
       writeTimeout:(NSUInteger)theWriteTimeout
         background:(BOOL)theBOOL;
{
    self = [super init];
    if (self)
    {
        if (theName == nil || thePort <= 0)
        {
            return nil;
        }
        
        self.delegate = inDelegate;
        
        NSInputStream   *iStream = nil;
        NSOutputStream  *oStream = nil;

        [NSStream getStreamsToHostNamed:theName
                                   port:thePort 
                            inputStream:&iStream 
                           outputStream:&oStream];
        
        inputStream = iStream;
        outputStream = oStream;
        
        if ((nil == inputStream) ||
            (nil == outputStream))
        {
            return nil;
        }
        
        
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        inputStream.delegate = self;
        outputStream.delegate = self;
        
        if ([inputStream streamStatus] == NSStreamStatusNotOpen)
            [inputStream open];
        
        if ([outputStream streamStatus] == NSStreamStatusNotOpen)
            [outputStream open];
        
    }
    return self;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode)
    {
        case NSStreamEventOpenCompleted:
        {
            if (stream == outputStream) // only handled the event once
            {
                [delegate connectionReceivedOpenCompleted:self];
            }
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            if (stream == inputStream)
            {
                [delegate connectionReceivedReadEvent:self];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            if (stream == outputStream)
            {
                [delegate connectionReceivedWriteEvent:self];
            }
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            [delegate connection:self receivedError:[stream streamError]];
            break;
        }
            
        case NSStreamEventNone:
            break;
        case NSStreamEventEndEncountered:
            break;
    }
}

//
//
//
- (void) dealloc
{
    delegate = nil;
    [self close];
    
    inputStream.delegate = nil;
    outputStream.delegate = nil;


    inputStream = nil;
    outputStream = nil;

}


//
// This method is used to return the file descriptor
// associated with our socket.
//
- (int) fd
{
    NSAssert(nil, @"Not available");
    return 0; // _fd;
}

//
//
//
- (BOOL) isConnected
{
    return ((NSStreamStatusOpen <= [inputStream streamStatus]) &&
            (NSStreamStatusClosed > [inputStream streamStatus]) &&
            (NSStreamStatusOpen <= [outputStream streamStatus]) &&
            (NSStreamStatusClosed > [outputStream streamStatus]));
}

//
//
//
- (BOOL) isSSL
{
    return ([[inputStream propertyForKey:NSStreamSocketSecurityLevelKey] isEqualToString:NSStreamSocketSecurityLevelNegotiatedSSL] &&
            [[outputStream propertyForKey:NSStreamSocketSecurityLevelKey] isEqualToString:NSStreamSocketSecurityLevelNegotiatedSSL]);
}

//
// other methods
//
- (void) close
{
    [inputStream close];
    [outputStream close];
}

//
//
//
- (NSInteger)read:(uint8_t*)buf length:(NSInteger)len
{
    if ([inputStream hasBytesAvailable])
    {
        return [inputStream read:buf maxLength:len];
    }
    
    return 0;
}


//
//
//
- (NSInteger)write:(uint8_t*)buf length:(NSInteger)len
{
    if ([outputStream hasSpaceAvailable])
    {
        return [outputStream write:buf maxLength:len];
    }
    
    return 0;
}


//
// 0  -> success
// -1 ->
// -2 -> handshake error
//
- (NSInteger) startSSL
{
    return ([inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey] &&
            [outputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey] ?
            0 : 1);
}

@end
