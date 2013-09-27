//
//  ChatDataSource.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatDataSource.h"

@implementation ChatDataSource

-(ChatDataSource*)init{
    //call super init
    self = [super init];
    
    if (self != nil) {
               [self setMessages:[[NSMutableArray alloc] init]];
    }
    
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section
    if (![self messages])
        return 0;
    
    
    return [[self messages] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    
    // Configure the cell...
    //todo change bar black/grey
    NSDictionary * message = [[self messages] objectAtIndex:indexPath.row];
    
    
    
    cell.textLabel.text = [message objectForKey:@"plaindata"];
    
    
    return cell;
}

- (void) addMessage:(NSDictionary *) message {
     [[self messages] addObject:message];
}

@end
