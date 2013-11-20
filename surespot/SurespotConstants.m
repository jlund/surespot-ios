//
//  SurespotConstants.m
//  surespot
//
//  Created by Adam on 11/18/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotConstants.h"

@implementation SurespotConstants
BOOL const serverSecure = NO;
NSString * const serverBaseIPAddress = @"192.168.10.68";
NSInteger const serverPort = 8080;

NSString * const serverPublicKeyString =  @"-----BEGIN PUBLIC KEY-----\nMIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQA93Acih23m8Jy65gLo8A9t0/snVXe\nRm+6ucIp56cXPgYvBwKDxT30z/HU84HPm2T8lnKQjFGMTUKHnIW+vqKFZicAokkW\nJ/GoFMDGz5tEDGEQrHk/tswEysri5V++kzwlORA+kAxAasdx7Hezl0QfvkPScr3N\n5ifR7m1J+RFNqK0bulQ=\n-----END PUBLIC KEY-----"; //local


//@"-----BEGIN PUBLIC KEY-----\nMIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQA/mqxm0092ovWqQluMYWJXc7iE+0v\nmrA8vJNUo1bAEe9dWY9FucDnZIbNNNGKh8soA9Ej7gyW9Yc6D7llh52LhscBpGd6\nbX+FNZEROhIDJP2KgTTKVX+ASB0WtPT3V9AbyoAAxEse8IP5Wec5ZGQG1B/mOlGm\nZ/aaRkB1bwl9eCNojpw=\n-----END PUBLIC KEY-----"; //prod

NSInteger const SAVE_MESSAGE_COUNT = 50;

@end
