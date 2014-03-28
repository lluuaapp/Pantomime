/*
**  CWConnection.h
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

#import <Foundation/Foundation.h>

@protocol CWConnectionDelegate; 

/*!
  @protocol CWConnection
  @discussion This protocol defines a basic set of methods that classes
              should implement. CWTCPConnection implements the protocol
	      to offer TCP connections support. An UDP implementation
	      will likely be added in a near future (for DNS requests).
*/
@protocol CWConnection <NSObject>

@required
/*!
  @method initWithName: port: background:
  @discussion This method is use to initialize a new connection
              instance at the specified port. It can connect
	      in background if needed and use the default timeout
	      (60 seconds) when connecting.
  @param theName The host name to connect to.
  @param thePort The port to connect to.
  @param theBOOL YES if we want to connect in background (non-blocking
                 way), NO if we want this call to be blocking until
		 we successfully connected to the host.
  @result An instance implementing the CWConnection protocol, nil
	  if an error occurred, like DNS resolution.
*/
- (id) initWithName:(NSString*)theName
               port:(unsigned short)thePort
           delegate:(id<CWConnectionDelegate>)inDelegate
         background:(BOOL)theBOOL;

/*!
  @method initWithName: port: connectionTimeout: readTimeout: writeTimeout: background:
  @discussion Same as -initWithName: port: background but it allows
              you to specifed the proper connection / read / write
	      timeout values to use.
  @param theName The host name to connect to.
  @param thePort The port to connect to.
  @param theConnectionTimeout The timeout to use when connecting to the host.
  @param theReadTimeout The timeout to use when reading on the socket.
  @param theWriteTimeout The timeout to use when writing on the socket.
  @param theBOOL YES if we want to connect in background (non-blocking
                 way), NO if we want this call to be blocking until
		 we successfully connected to the host.
  @result An instance implementing the CWConnection protocol, nil
	  if an error occurred, like DNS resolution.
*/
- (id) initWithName:(NSString *)theName
               port:(unsigned short)thePort
           delegate:(id<CWConnectionDelegate>)inDelegate
  connectionTimeout:(NSUInteger)theConnectionTimeout
        readTimeout:(NSUInteger)theReadTimeout
       writeTimeout:(NSUInteger)theWriteTimeout
         background:(BOOL)theBOOL;

/*!
  @method isConnected
  @discussion This method is used to verify if the socket is
              in a connected state.
  @result YES if the socket is in a connected state, NO otherwise.
*/
- (BOOL) isConnected;

/*!
  @method close
  @discussion This method is used to close the connection to the host.
*/
- (void) close;

/*!
  @method read: length:
  @discussion This method is used to read <i>len</i> bytes from the
              socket and store them in <i>buf</i>
  @param buf The buffer in which read bytes will be stored in.
  @param len The number of bytes we want to try to read.
  @result The number of bytes successfully read.
*/
- (NSInteger) read:(uint8_t*)buf length:(NSInteger)len;

/*!
  @method write: length:
  @discussion This method is used to write <i>len</i> bytes from
              <i>buf</i> to the socket.
  @param buf The bytes that we want to write to the socket.
  @param len The number of bytes we want to try to write.
  @result The number of bytes successfully written.
*/
- (NSInteger) write:(uint8_t*)buf length:(NSInteger)len;

@optional
- (id<CWConnectionDelegate>)delegate;
- (void)setDelegate:(id<CWConnectionDelegate>)inDelegate;

@end

@protocol CWConnectionDelegate <NSObject>

- (void) connectionReceivedOpenCompleted:(id<CWConnection>)inConnection;
- (void) connectionReceivedReadEvent:(id<CWConnection>)inConnection;
- (void) connectionReceivedWriteEvent:(id<CWConnection>)inConnection;
- (void) connection:(id<CWConnection>)inConnection receivedError:(NSError*)inError;

@end
