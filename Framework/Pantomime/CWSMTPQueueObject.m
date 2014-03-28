//
//  CWSMTPQueueObject.m
//  SalesParser
//
//  Created by Paul Hecker on 28.03.14.
//
//

#import "CWSMTPQueueObject.h"

@implementation CWSMTPQueueObject

- (id) initWithCommand:(SMTPCommand)theCommand
             arguments:(NSString *)theArguments
{
    self = [super init];
    if (self)
    {
        _command = theCommand;
        _arguments = theArguments;
    }
    return self;
}

@end
