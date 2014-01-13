//
//  SoundController.h
//  surespot
//
//  Created by Adam on 1/13/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SoundController : NSObject
+(SoundController*)sharedInstance;
-(void) playNewMessageSound;
-(void) playInviteSound;
-(void) playInviteAcceptedSound;
-(void) playSoundNamed: (NSString *) soundName;
@end
