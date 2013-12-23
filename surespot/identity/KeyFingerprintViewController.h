//
//  KeyFingerprintViewController.h
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyFingerprintViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
-(id) initWithNibName:(NSString *)nibNameOrNil username: (NSString *) username;
@end
