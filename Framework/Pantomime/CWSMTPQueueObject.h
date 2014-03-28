//
//  CWSMTPQueueObject.h
//  SalesParser
//
//  Created by Paul Hecker on 28.03.14.
//
//

#import "CWSMTP.h"

@interface CWSMTPQueueObject : NSObject

@property SMTPCommand   command;
@property NSString      *arguments;

- (id) initWithCommand:(SMTPCommand)theCommand
             arguments:(NSString *)theArguments;
@end
