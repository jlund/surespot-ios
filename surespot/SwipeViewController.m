//
//  SwipeViewController.m
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SwipeViewController.h"
#import "NetworkController.h"
#import "ChatController.h"
#import <UIKit/UIKit.h>

@interface SwipeViewController ()
@end


@implementation SwipeViewController


- (void)viewDidLoad
{
    NSLog(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _chats = [[NSMutableDictionary alloc] init];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =YES ;
    // _swipeView.defersItemViewLoading = YES;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    //configure page control
    //_pageControl.numberOfPages = _swipeView.numberOfPages;
    //_pageControl.defersCurrentPageDisplay = YES;
    
    
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    return 1 + [_chats count];
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    NSLog(@"view for item at index %d", index);
    if (index == 0) {
        if (!_friendView) {
            NSLog(@"creating friend view");
            //        UIStoryboard * board = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:[NSBundle mainBundle]];
            //        UITableViewController *controller =  [board  instantiateViewControllerWithIdentifier:@"friendView"];
            
            // _friendView = ((UIView *)[[NSBundle mainBundle] loadNibNamed:@"FriendTableView" owner:self options:nil][0]).subviews[0];
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            [_friendView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
            
            [[NetworkController sharedInstance] getFriendsSuccessBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"get friends response: %d",  [response statusCode]);
                //  [self.tableView beginUpdates];
                self.friends = (NSDictionary *) JSON ;
                //[self.tableView endUpdates];
                
                //   [self.friendTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
                [_friendView reloadData];
                
            } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                NSLog(@"response failure: %@",  Error);
                
            }];
        }
        
        NSLog(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        NSLog(@"returning chat view");
        NSArray *keys = [_chats allKeys];
        id aKey = [keys objectAtIndex:index -1];
        id anObject = [_chats objectForKey:aKey];
        
        return anObject;
    }
    
}

- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    //update page control page
    _pageControl.currentPage = swipeView.currentPage;
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    NSLog(@"Selected item at index %i", index);
}

- (IBAction)pageControlTapped
{
    //update swipe view page
    [_swipeView scrollToPage:_pageControl.currentPage duration:0.4];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSLog(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
    NSLog(@"number of rows in section, index: %d", index);
    // Return the number of rows in the section
    if (index == 0) {
        if (!self.friends) {
            NSLog(@"returning 0 rows");
            return 0;
        }
        NSArray * friends = [self.friends objectForKey:@"friends"];
        NSUInteger count =  [friends count];
        NSLog(@"returning %d rows",count);
        return count;
    }
    else {
        
        NSArray *keys = [_chats allKeys];
        id aKey = [keys objectAtIndex:index -1];
        //id anObject = [_chats objectForKey:aKey];
        
        NSString * username = aKey;
        return  [[ChatController sharedInstance] getDataSourceForFriendname: username].messages.count;
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"cell for row");
    
    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
    
    if (index == 0) {
        static NSString *CellIdentifier = @"Cell";
        
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        NSArray * friends =[self.friends objectForKey:@"friends"];
        
        // Configure the cell...
        cell.textLabel.text = [(NSDictionary *)[friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
        return cell;
    }
    else {
        static NSString *CellIdentifier = @"ChatCell";
        
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        NSArray *keys = [_chats allKeys];
        id aKey = [keys objectAtIndex:index -1];
        //id anObject = [_chats objectForKey:aKey];
        
        NSString * username = aKey;
        NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
        if (messages.count > 0) {
            cell.textLabel.text = [[messages objectAtIndex:indexPath.row] objectForKey:@"plaindata"];
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    NSLog(@"selected, on page: %d", page);
    
    if (page == 0) {
        NSArray * friends =[self.friends objectForKey:@"friends"];
        
        // Configure the cell...
        NSString * friendname =[(NSDictionary *)[friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
        [self showChat:friendname];
        
        //  [self performSegueWithIdentifier:@"chatSegue" sender: friendname];
        // Navigation logic may go here. Create and push another view controller.
        /*
         *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
         // ...
         // Pass the selected object to the new view controller.
         [self.navigationController pushViewController:detailViewController animated:YES];
         */
    }
}

-(void) showChat:(NSString *) username {
    //get existing view if there is one
    UITableView * chatView = [_chats objectForKey:username];
    if (!chatView) {
        chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
        [chatView setDelegate:self];
        [chatView setDataSource: self];
        [_chats setObject:chatView forKey:username];
        //listen for rolead notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadMessages:) name:@"reloadMessages" object:username];

        
        [chatView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ChatCell"];
        
        NSInteger index = _chats.count;
        NSLog(@"creating and scrolling to index: %d", index);
        
        [_swipeView reloadData];
      //  [_swipeView loadItemAtIndex:index];
        [_swipeView updateLayout];
        [_swipeView scrollToPage:index duration:0.500];
        //   chatView.frame = _swipeView.frame;
    }
    //
    ////              }
    else {
        NSInteger index =[_swipeView indexOfItemViewOrSubview:chatView];
        NSLog(@"scrolling to index: %d", index);
        [_swipeView scrollToPage:index duration:0.500];
        
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if ([_swipeView currentPage] == 0) {
        
    }
    else {
        [self send];
        
    }
    
    [textField setText:nil];
    return NO;
}

- (void) send {
    NSString* message = self.textField.text;
    NSArray *keys = [_chats allKeys];
    id friendname = [keys objectAtIndex:[_swipeView currentItemIndex] -1];
    //id anObject = [_chats objectForKey:aKey];
    [[ChatController sharedInstance] sendMessage: message toFriendname:friendname];
    UITableView * chatView = [_chats objectForKey:friendname];
    [chatView reloadData];
}

- (void)reloadMessages:(NSNotification *)notification
{
    [[_chats objectForKey:notification.object] reloadData];
}



@end