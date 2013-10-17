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
#import "IdentityController.h"
#import "EncryptionController.h"
#import <UIKit/UIKit.h>
//#import <QuartzCore/CATransaction.h>

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
    
    _textField.enablesReturnKeyAutomatically = NO;
    [self registerForKeyboardNotifications];
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"menu" style:UIBarButtonItemStylePlain target:self action:@selector(refreshPropertyList:)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = [@"surespot/" stringByAppendingString:[IdentityController getLoggedInUser]];
    
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    
    NSLog(@"keyboardWasShown");
    
    //if (_swipeView.currentPage > 0 ) {
        NSDictionary* info = [aNotification userInfo];
        CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        
        UITableView * tableView =(UITableView *)_swipeView.currentItemView;
        
        
        
        
        KeyboardState * keyboardState = [[KeyboardState alloc] init];
        keyboardState.keyboardRect = [tableView convertRect:keyboardRect fromView:nil];
        CGSize kbSize = keyboardState.keyboardRect.size;
        
        for (UITableView *tableView in [_chats allValues]) {
            
            UIEdgeInsets contentInsets =  tableView.contentInset;
            
            keyboardState.contentInset = contentInsets;
            contentInsets.bottom = keyboardRect.size.height;
            tableView.contentInset = contentInsets;
            
            keyboardState.indicatorInset = tableView.scrollIndicatorInsets;
            
            contentInsets.bottom = keyboardRect.size.height;
            tableView.contentInset = contentInsets;
            
            keyboardState.offset = tableView.contentOffset;
        }
        
        self.keyboardState = keyboardState;
        
        // [self view].frame
        //   scrollView.contentInset = contentInsets;
        // scrollView.scrollIndicatorInsets = contentInsets;
        
        
        
        // If active text field is hidden by keyboard, scroll it so it's visible
        // Your app might not need or want this behavior.
        //    CGRect aRect = _swipeView.frame;
        //    aRect.size.height -= kbSize.height;
        //    _swipeView.frame = aRect;
        
        //    CGRect aRect = self.view.frame;
        //     aRect.size.height -= kbSize.height;
        //    self.view.frame = aRect;
        
        CGRect aRect = _textField.frame;
        aRect.origin.y -= kbSize.height;
        _textField.frame = aRect;
        //    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        //        [self.scrollView scrollRectToVisible:activeField.frame animated:YES];
        //    }
   // }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSLog(@"keyboardWillBeHidden");
    [self handleKeyboardHide];
    
}

- (void) handleKeyboardHide {
    
    //  NSDictionary* info = [aNotification userInfo];
    // CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    if (self.keyboardState) {
        CGSize kbSize = self.keyboardState.keyboardRect.size;
        //
        //    CGRect aRect = _swipeView.frame;
        //    aRect.size.height += kbSize.height;
        //    _swipeView.frame = aRect;
        //
        CGRect aRect = _textField.frame;
        aRect.origin.y += kbSize.height;
        _textField.frame = aRect;
        
        //reset all table view states
        
        
        // UITableView * tableView =(UITableView *)_swipeView.currentItemView;
        for (UITableView *tableView in [_chats allValues]) {
            
            
            
            
            [tableView setContentOffset:self.keyboardState.offset animated:YES];
            // [CATransaction setCompletionBlock:^{
            tableView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
            tableView.contentInset = self.keyboardState.contentInset;
        }
        //    }];
        
        //    CGRect aRect = self.view.frame;
        //    aRect.size.height += kbSize.height;
        //    self.view.frame = aRect;
        self.keyboardState = nil;
    }
    
    
    //    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    //   scrollView.contentInset = contentInsets;
    //  scrollView.scrollIndicatorInsets = contentInsets;
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
                self.friends = [[NSMutableArray alloc] initWithArray: [((NSDictionary *) JSON) objectForKey:@"friends"]];
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
    NSLog(@"swipeview index changed to %d", swipeView.currentPage);
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
        if (!_friends) {
            NSLog(@"returning 0 rows");
            return 0;
        }
        //        NSArray * friends = [self.friends objectForKey:@"friends"];
        //        NSUInteger count =  [friends count];
        //        NSLog(@"returning %d rows",count);
        return [_friends count];
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
        
        //  NSArray * friends =[self.friends objectForKey:@"friends"];
        
        // Configure the cell...
        cell.textLabel.text = [(NSDictionary *)[_friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
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
            
            
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSMutableDictionary * jsonMessage = message.messageData;
            NSString * plainData = [jsonMessage  objectForKey:@"plaindata"];
            
            if (!plainData){
                
               
                //todo decrypt on thread
                [EncryptionController symmetricDecryptString:[jsonMessage objectForKey:@"data"] ourVersion:[message getOurVersion]  theirUsername:[message getOtherUser] theirVersion:[message getTheirVersion] iv:[jsonMessage objectForKey:@"iv"] callback:^(NSString * plaintext){
                    
                    [jsonMessage setObject:plaintext forKey:@"plaindata"];
                    
                    cell.textLabel.text = plaintext;
                }];
                
                
            }
            else {
                
                cell.textLabel.text = plainData;
            }
            
        }
        
        return cell;
        
    }}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    NSLog(@"selected, on page: %d", page);
    
    if (page == 0) {
        // NSArray * friends =[_friends ob:@"friends"];
        
        // Configure the cell...
        NSString * friendname =[(NSDictionary *)[_friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
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
        
        //  [_swipeView reloadData];
        //  [_swipeView loadItemAtIndex:index];
        [_swipeView updateLayout];
        [_swipeView scrollToPage:index duration:0.500];
        //   chatView.frame = _swipeView.frame;
        
    }
    //
    ////              }
    else {
        //  NSArray * visibleViews = [_swipeView visibleItemViews];
        
        // NSArray * indexes = [_swipeView indexesForVisibleItems];
        
        NSInteger index = [[_chats allKeys] indexOfObject:username] + 1;
        NSLog(@"scrolling to index: %d", index);
        [_swipeView scrollToPage:index duration:0.500];
        
        
    }
    
    [_textField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if ([_swipeView currentPage] == 0) {
        [self inviteUser:[textField text]];
    }
    else {
        [self send];
        
    }
    
    [textField setText:nil];
    return NO;
}

- (void) send {
    NSString* message = self.textField.text;
    
    if (message.length == 0) return;
    
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

- (void) inviteUser: (NSString *) username {
    NSString * loggedInUser = [IdentityController getLoggedInUser];
    if ([username isEqualToString:loggedInUser]) {
        //todo tell user they can't invite themselves
        return;
    }
    
    [[NetworkController sharedInstance]
     inviteFriend:username
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         NSLog(@"response: %d",  [operation.response statusCode]);
         //   NSMutableArray * friends = [self.friends objectForKey:@"friends"];
         NSDictionary * f = [NSDictionary dictionaryWithObjectsAndKeys:username,@"name",[NSNumber numberWithInt:2],@"flags", nil];
         [_friends addObject:f];
         [_friendView reloadData];
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         NSLog(@"response failure: %@",  Error);
         
     }];
}




@end