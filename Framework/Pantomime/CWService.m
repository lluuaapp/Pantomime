/*
**  CWService.m
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

#import "CWService.h"

#import "CWConstants.h"
#import "CWTCPConnection.h"
#import "NSData+CWExtensions.h"

//
// It's important that the read buffer be bigger than the PMTU. Since almost all networks
// permit 1500-byte packets and few permit more, the PMTU will generally be around 1500.
// 2k is fine, 4k accomodates FDDI (and HIPPI?) networks too.
//
#define NET_BUF_SIZE 4096 

// We set the size increment of blocks we will write. Under Mac OS X, we use 1024 bytes
// in order to avoid a strange bug in SSL_write. This prevents us from no longer beeing
// notified after a couple of writes that we can actually write data!
#define WRITE_BLOCK_SIZE 1024


//
// Default timeout used when waiting for something to complete.
//
#define DEFAULT_TIMEOUT 60

@implementation CWService

//
//
//
- (id) init
{
    self = [super init];
    if (self) {
        
        _supportedMechanisms = [[NSMutableArray alloc] init];
        _responsesFromServer = [[NSMutableArray alloc] init];
        _capabilities = [[NSMutableArray alloc] init];
        _queue = [[NSMutableArray alloc] init];
        _username = nil;
        _password = nil;
        
        
        _rbuf = [[NSMutableData alloc] init];
        _wbuf = [[NSMutableData alloc] init];
        
        _runLoopModes = [[NSMutableArray alloc] initWithObjects: NSDefaultRunLoopMode, nil];
        _connectionTimeout = _readTimeout = _writeTimeout = DEFAULT_TIMEOUT;
        _lastCommand = 0;
        
        previous_queue = [[NSMutableArray alloc] init];
        reconnecting = opening_mailbox = NO;
        
    }
    return self;
}


//
//
//
- (id) initWithName: (NSString *) theName
               port: (NSUInteger) thePort
{
    self = [self init];
    if (self) {
        
        [self setName: theName];
        [self setPort: thePort];
    }
    return self;
}


//
//
//
- (void) dealloc
{
    [self setDelegate: nil];

    if (nil != _connection)
    {
        [_connection close];
        
        if ([_connection respondsToSelector:@selector(setDelegate:)])
        {
            [_connection setDelegate:nil];
        }
    }
}


//
// access / mutation methods
//
- (void) setDelegate: (id) theDelegate
{
  _delegate = theDelegate;
}

- (id) delegate
{
  return _delegate;
}


//
//
//
- (NSString *) name
{
  return _name;
}

- (void) setName: (NSString *) theName
{
  ASSIGN(_name, theName);
}


//
//
//
- (NSUInteger) port
{
  return _port;
}

- (void) setPort: (NSUInteger) thePort
{
  _port = thePort;
}


//
//
//
- (id<CWConnection>) connection
{
  return _connection;
}


//
//
//
- (NSArray *) supportedMechanisms
{
  return [NSArray arrayWithArray: _supportedMechanisms];
}


//
//
//
- (NSString *) username
{
  return _username;
}

- (void) setUsername: (NSString *) theUsername
{
  ASSIGN(_username, theUsername);
}


//
//
//
- (BOOL) isConnected
{
  return _connected;
}


//
// Other methods
//
- (void) authenticate: (NSString *) theUsername
             password: (NSString *) thePassword
            mechanism: (NSString *) theMechanism
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (void) cancelRequest
{
    _connected = NO;
    
    if ([_connection respondsToSelector:@selector(setDelegate:)])
    {
        [_connection setDelegate:nil];
    }
    
    [_connection close];
    _connection = nil;
    [_queue removeAllObjects];
    
    POST_NOTIFICATION(PantomimeRequestCancelled, self, nil);
    (void)PERFORM_SELECTOR_1(_delegate, @selector(requestCancelled:), PantomimeRequestCancelled);
}


//
//
//
- (void) close
{
    //
    // If we are reconnecting, no matter what, we close and release our current connection immediately.
    // We do that since we'll create a new on in -connect/-connectInBackgroundAndNotify. No need
    // to return immediately since _connected will be set to NO in _removeWatchers.
    //
    if (reconnecting)
    {
        _connected = NO;
        
        if ([_connection respondsToSelector:@selector(setDelegate:)])
        {
            [_connection setDelegate:nil];
        }
        
        [_connection close];
        _connection = nil;
    }
    
    if (_connected)
    {
        _connected = NO;
        
        if ([_connection respondsToSelector:@selector(setDelegate:)])
        {
            [_connection setDelegate:nil];
        }

        [_connection close];
        
        POST_NOTIFICATION(PantomimeConnectionTerminated, self, nil);
        (void)PERFORM_SELECTOR_1(_delegate, @selector(connectionTerminated:), PantomimeConnectionTerminated);
    }
}

// 
// If the connection or binding succeeds, zero  is  returned.
// On  error, -1 is returned, and errno is set appropriately
//
- (NSInteger) connect
{
    NSAssert(nil == _connection, @"Connection already allocated");
    _connection = [[CWTCPConnection alloc] initWithName:_name
                                                   port:_port
                                               delegate:self
                                             background: NO];
    
    if (!_connection)
    {
        return -1;
    }
    
    return 0;
}


//
//
//
- (void) connectInBackgroundAndNotify
{
    NSAssert(nil == _connection, @"Connection already allocated");
    _connection = [[CWTCPConnection alloc] initWithName:_name
                                                   port:_port
                                               delegate:self
                                             background:YES];
    
    if (!_connection)
    {
        POST_NOTIFICATION(PantomimeConnectionTimedOut, self, nil);
        (void)PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:),  PantomimeConnectionTimedOut);
        return;
    }
}


//
//
//
- (void) noop
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (void) updateRead
{
    uint8_t buf[NET_BUF_SIZE];
    NSInteger count;
    
    while ((count = [_connection read: buf  length: NET_BUF_SIZE]) > 0)
    {
        if (_delegate && [_delegate respondsToSelector: @selector(service:receivedData:)])
        {
            NSData *aData = [[NSData alloc] initWithBytes: buf  length: count];
            
            [_delegate performSelector: @selector(service:receivedData:)
                            withObject: self
                            withObject: aData];
            
            [_rbuf appendData: aData];
        }
        else
        {
            [_rbuf appendBytes:buf length:count];
        }
    }
}
 
 
//
//
//
- (void) updateWrite
{
    if ([_wbuf length] > 0)
    {
        uint8_t *bytes;
        NSInteger count, len;
        
        bytes = (uint8_t *)[_wbuf mutableBytes];
        len = [_wbuf length];
        
#ifdef MACOSX
        count = [_connection write: bytes  length: len > WRITE_BLOCK_SIZE ? WRITE_BLOCK_SIZE : len];
#else
        count = [_connection write: bytes  length: len];
#endif
        // If nothing was written of if an error occured, we return.
        if (count <= 0)
        {
            return;
        }
        // Otherwise, we inform our delegate that we wrote some data...
        else if (_delegate && [_delegate respondsToSelector: @selector(service:sentData:)])
        {
            [_delegate performSelector: @selector(service:sentData:)
                            withObject: self
                            withObject: [_wbuf subdataToIndex: count]];
        }
        
        //NSLog(@"count = %d, len = %d", count, len);
        
        // If we have been able to write everything...
        if (count == len)
        {
            [_wbuf setLength: 0];
        }
        else
        {
            memmove(bytes, bytes+count, len-count);
            [_wbuf setLength: len-count];
            
            // We enable the write callback under OS X.
            // See the rationale in -writeData:
            
            [self updateWrite];
        }
    }
}


//
//
//
- (void) writeData: (NSData *) theData
{
    if (theData && [theData length])
    {
        [_wbuf appendData: theData];
        
        //
        // Let's not try to enable the write callback if we are not connected
        // There's no reason to try to enable the write callback if we
        // are not connected.
        //
        if (!_connected)
        {
            return;
        }
        
        //
        // We re-enable the write callback.
        //
        // Rationale from OS X's CoreFoundation:
        //
        // By default kCFSocketReadCallBack, kCFSocketAcceptCallBack, and kCFSocketDataCallBack callbacks are
        // automatically reenabled, whereas kCFSocketWriteCallBack callbacks are not; kCFSocketConnectCallBack
        // callbacks can only occur once, so they cannot be reenabled. Be careful about automatically reenabling
        // read and write callbacks, because this implies that the callbacks will be sent repeatedly if the socket
        // remains readable or writable respectively. Be sure to set these flags only for callback types that your
        // CFSocket actually possesses; the result of setting them for other callback types is undefined.
        //
        
        [self updateWrite];
    }
}

//
//
//
- (NSInteger) reconnect
{
  [self subclassResponsibility: _cmd];
  return 0;
}

//
//
//
- (void) addRunLoopMode: (NSString *) theMode
{
#ifndef MACOSX
  if (theMode && ![_runLoopModes containsObject: theMode])
    {
      [_runLoopModes addObject: theMode];
    }
#endif
}


//
//
//
- (NSUInteger) connectionTimeout
{
  return _connectionTimeout;
}

- (void) setConnectionTimeout: (NSUInteger) theConnectionTimeout
{
  _connectionTimeout = (theConnectionTimeout > 0 ? theConnectionTimeout : DEFAULT_TIMEOUT);
}

- (NSUInteger) readTimeout
{
  return _readTimeout;
}

- (void) setReadTimeout: (NSUInteger) theReadTimeout
{
  _readTimeout = (theReadTimeout > 0 ? theReadTimeout: DEFAULT_TIMEOUT);
}

- (NSUInteger) writeTimeout
{
  return _writeTimeout;
}

- (void) setWriteTimeout: (NSUInteger) theWriteTimeout
{
  _writeTimeout = (theWriteTimeout > 0 ? theWriteTimeout : DEFAULT_TIMEOUT);
}

- (void) startTLS
{
  [self subclassResponsibility: _cmd];
}

- (NSUInteger) lastCommand
{
  return _lastCommand;
}

- (NSArray *) capabilities
{
  return _capabilities;
}

- (void) connectionReceivedOpenCompleted:(id<CWConnection>)inConnection;
{
    _connected = YES;
    
	POST_NOTIFICATION(PantomimeConnectionEstablished, self, nil);
	(void)PERFORM_SELECTOR_1(_delegate, @selector(connectionEstablished:),  PantomimeConnectionEstablished);
}

- (void) connectionReceivedReadEvent:(CWTCPConnection*)inConnection
{
    [self updateRead];
}

- (void) connectionReceivedWriteEvent:(CWTCPConnection*)inConnection
{
    [self updateWrite];
}

- (void) connection:(id<CWConnection>)inConnection receivedError:(NSError*)inError
{
    // NSLog(@"Error %ld: %@:\n%@", [inError code], [inError localizedDescription], [inError userInfo]);

    _connected = NO;
    
    if ([_connection respondsToSelector:@selector(setDelegate:)])
    {
        [_connection setDelegate:nil];
    }

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [inError localizedDescription], NSLocalizedDescriptionKey,
                              nil];
    
    switch ([inError code])
    {
        case kCFNetServiceErrorTimeout:
            POST_NOTIFICATION(PantomimeConnectionTimedOut, self, userInfo);
            (void)PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:), PantomimeConnectionTimedOut);
            break;
    
        default:
            NSLog(@"Error %ld: %@", [inError code], [inError localizedDescription]);
            POST_NOTIFICATION(PantomimeConnectionLost, self, userInfo);
            (void)PERFORM_SELECTOR_1(_delegate, @selector(connectionLost:),  PantomimeConnectionLost);
            break;
    }
}

//
//
//
- (void) _removeWatchers
{
    if (!_connected)
    {
        return;
    }
    
    _connected = NO;
    
    if ([_connection respondsToSelector:@selector(setDelegate:)])
    {
        [_connection setDelegate:nil];
    }
}

@end
