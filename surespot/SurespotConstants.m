//
//  SurespotConstants.m
//  surespot
//
//  Created by Adam on 11/18/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotConstants.h"

@implementation SurespotConstants

#ifdef DEBUG
    BOOL const serverSecure = NO;
    NSString * const serverBaseIPAddress = @"192.168.10.68";
    NSInteger const serverPort = 8080;

    NSString * const serverPublicKeyString =  @"-----BEGIN PUBLIC KEY-----\nMIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQA93Acih23m8Jy65gLo8A9t0/snVXe\nRm+6ucIp56cXPgYvBwKDxT30z/HU84HPm2T8lnKQjFGMTUKHnIW+vqKFZicAokkW\nJ/GoFMDGz5tEDGEQrHk/tswEysri5V++kzwlORA+kAxAasdx7Hezl0QfvkPScr3N\n5ifR7m1J+RFNqK0bulQ=\n-----END PUBLIC KEY-----"; //local
#else
    BOOL const serverSecure = YES;
    NSString * const serverBaseIPAddress = @"server.surespot.me";
    NSInteger const serverPort = 443;
    NSString * const serverPublicKeyString = @"-----BEGIN PUBLIC KEY-----\nMIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQA/mqxm0092ovWqQluMYWJXc7iE+0v\nmrA8vJNUo1bAEe9dWY9FucDnZIbNNNGKh8soA9Ej7gyW9Yc6D7llh52LhscBpGd6\nbX+FNZEROhIDJP2KgTTKVX+ASB0WtPT3V9AbyoAAxEse8IP5Wec5ZGQG1B/mOlGm\nZ/aaRkB1bwl9eCNojpw=\n-----END PUBLIC KEY-----"; //prod
#endif

NSInteger const SAVE_MESSAGE_COUNT = 50;
NSString * const MIME_TYPE_IMAGE = @"image/";
NSString * const MIME_TYPE_TEXT = @"text/plain";
NSString * const MIME_TYPE_M4A = @"audio/mp4";
NSInteger const MAX_IDENTITIES = 3;

NSString * const FACEBOOK_APP_ID = @"";

NSString * const TUMBLR_CONSUMER_KEY = @"";
NSString * const TUMBLR_SECRET = @"";
NSString * const TUMBLR_CALLBACK_URL = @"";

NSString *const GOOGLE_CLIENT_ID = @"";
NSString *const GOOGLE_CLIENT_SECRET = @"";

NSString * const BITLY_TOKEN = @"";




@end
