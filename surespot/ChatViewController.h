//
//  ChatViewController.h
//  surespot
//
//  Created by Adam on 6/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SocketIO.h"

@interface ChatViewController : UIViewController <SocketIODelegate>
@property (strong) SocketIO * socketIO;
@end
