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
#import "MessageProcessor.h"
#import <UIKit/UIKit.h>
#import "MessageView.h"
#import "ChatUtils.h"
#import "HomeCell.h"
#import "SurespotControlMessage.h"
#import "FriendDelegate.h"
#import "UIUtils.h"
#import "LoginViewController.h"
#import "DDLog.h"
#import "REMenu.h"
#import "SVPullToRefresh.h"
#import "SurespotConstants.h"
#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "ImageDelegate.h"
#import "MessageView+WebImageCache.h"
#import "SurespotPhoto.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

//#import <QuartzCore/CATransaction.h>

@interface SwipeViewController ()
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@property (nonatomic, weak) HomeDataSource * homeDataSource;
@property (nonatomic, strong) UIViewPager * viewPager;
@property (nonatomic, strong) NSMutableDictionary * needsScroll;
@property (strong, readwrite, nonatomic) REMenu *menu;
@property (atomic, assign) NSInteger progressCount;
@property (nonatomic, weak) UIView * backImageView;
@property (atomic, assign) NSInteger scrollingTo;
@property (nonatomic, strong) NSMutableDictionary * bottomIndexPaths;
@property (nonatomic, strong) IASKAppSettingsViewController * appSettingsViewController;
@property (nonatomic, strong) ImageDelegate * imageDelegate;
@property (nonatomic, strong) SurespotMessage * imageMessage;
@end

@implementation SwipeViewController


- (void)viewDidLoad
{
    DDLogVerbose(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _needsScroll = [NSMutableDictionary new];
    
    _dateFormatQueue = dispatch_queue_create("date format queue", NULL);
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _chats = [[NSMutableDictionary alloc] init];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =NO ;
    _swipeView.delaysContentTouches = YES;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    _textField.enablesReturnKeyAutomatically = NO;
    _inviteField.enablesReturnKeyAutomatically = NO;
    [self registerForKeyboardNotifications];
    
    
    UIButton *backButton = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 36.0f, 36.0f)];
    
    
    UIImage * backImage = [UIImage imageNamed:@"surespot_logo"];
    [backButton setBackgroundImage:backImage  forState:UIControlStateNormal];
    [backButton setContentMode:UIViewContentModeScaleAspectFit];
    _backImageView = backButton;
    
    [backButton addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    self.navigationItem.leftBarButtonItem = backButtonItem;
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"menu" style:UIBarButtonItemStylePlain target:self action:@selector(showMenuMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = [[IdentityController sharedInstance] getLoggedInUser];
    
    
    //don't swipe to back stack
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    
    //listen for  notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMessages:) name:@"refreshMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHome:) name:@"refreshHome" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFriend:) name:@"deleteFriend" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startProgress:) name:@"startProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopProgress:) name:@"stopProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unauthorized:) name:@"unauthorized" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessage:) name:@"newMessage" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invite:) name:@"invite" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inviteAccepted:) name:@"inviteAccepted" object:nil];
    
    _homeDataSource = [[ChatController sharedInstance] getHomeDataSource];
    
    //show currently open tab immediately
    //    NSString * currentChat = _homeDataSource.currentChat;
    //    if (currentChat) {
    //        [self showChat:currentChat];
    //    }
    
    _viewPager = [[UIViewPager alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 30)];
    _viewPager.autoresizingMask =UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_viewPager];
    _viewPager.delegate = self;
    
    
    //open active tabs, don't load data now well get it after connect
    for (Friend * afriend in [_homeDataSource friends]) {
        if ([afriend isChatActive]) {
            [self loadChat:[afriend name] show:NO availableId: -1 availableControlId:-1];
        }
    }
    
    //setup the button
    _theButton.layer.cornerRadius = 35;
    _theButton.layer.borderColor = [[UIUtils surespotBlue] CGColor];
    _theButton.layer.borderWidth = 3.0f;
    _theButton.backgroundColor = [UIColor whiteColor];
    _theButton.opaque = YES;
    
    [self updateTabChangeUI];
    
    [[ChatController sharedInstance] resume];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    _scrollingTo = -1;
    
    //app settings
    _appSettingsViewController = [IASKAppSettingsViewController new];
    _appSettingsViewController.delegate = self;
    
}

-(void) pause: (NSNotification *)  notification{
    DDLogVerbose(@"pause");
    [[ChatController sharedInstance] pause];
    
}


-(void) resume: (NSNotification *) notification {
    DDLogVerbose(@"resume");
    [[ChatController sharedInstance] resume];
    
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
- (void)keyboardWasShown:(NSNotification*)aNotification {
    DDLogInfo(@"keyboardWasShown");
    UITableView * tableView =(UITableView *)_friendView;
    
    KeyboardState * keyboardState = [[KeyboardState alloc] init];
    keyboardState.contentInset = tableView.contentInset;
    keyboardState.indicatorInset = tableView.scrollIndicatorInsets;
    
    
    UIEdgeInsets contentInsets =  tableView.contentInset;
    DDLogInfo(@"pre move originy %f,content insets bottom %f, view height: %f", _textFieldContainer.frame.origin.y, contentInsets.bottom, tableView.frame.size.height);
    
    NSDictionary* info = [aNotification userInfo];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = [UIUtils keyboardHeightAdjustedForOrientation:keyboardRect.size];
    
    CGRect textFieldFrame = _textFieldContainer.frame;
    textFieldFrame.origin.y -= keyboardHeight;
    
    _textFieldContainer.frame = textFieldFrame;
    
    DDLogInfo(@"keyboard height before: %f", keyboardHeight);
    
    keyboardState.keyboardHeight = keyboardHeight;
    //
    //    NSIndexPath * bottomCell = nil;
    //    NSArray * visibleCells = [tableView indexPathsForVisibleRows];
    //    if ([visibleCells count ] > 0) {
    //        bottomCell = [visibleCells objectAtIndex:[visibleCells count]-1];
    //    }
    //
    
    DDLogInfo(@"after move content insets bottom %f, view height: %f", contentInsets.bottom, tableView.frame.size.height);
    
    contentInsets.bottom = keyboardHeight;
    tableView.contentInset = contentInsets;
    
    
    
    UIEdgeInsets scrollInsets =tableView.scrollIndicatorInsets;
    scrollInsets.bottom = keyboardHeight;
    tableView.scrollIndicatorInsets = scrollInsets;
    
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            UITableView * tableView = [_chats objectForKey:key];
            
            UITableViewCell * bottomCell = nil;
            NSArray * visibleCells = [tableView visibleCells];
            if ([visibleCells count ] > 0) {
                bottomCell = [visibleCells objectAtIndex:[visibleCells count]-1];
            }
            
            
            if (bottomCell) {
                CGRect aRect = self.view.frame;
                aRect.size.height -= keyboardHeight;
                if (!CGRectContainsPoint(aRect, bottomCell.frame.origin) ) {
                    
                    CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y + keyboardHeight);
                    [tableView setContentOffset:newOffset animated:NO];
                    
                }
            }
            
            tableView.contentInset = contentInsets;
            tableView.scrollIndicatorInsets = scrollInsets;
        }
    }
    
    
    CGRect buttonFrame = _theButton.frame;
    buttonFrame.origin.y -= keyboardHeight;
    _theButton.frame = buttonFrame;
    
    self.keyboardState = keyboardState;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    DDLogInfo(@"keyboardWillBeHidden");
    [self handleKeyboardHide];
    
}

- (void) handleKeyboardHide {
    
    
    if (self.keyboardState) {
        
        
        CGRect textFieldFrame = _textFieldContainer.frame;
        textFieldFrame.origin.y += self.keyboardState.keyboardHeight;
        _textFieldContainer.frame = textFieldFrame;
        //reset all table view states
        
        _friendView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
        _friendView.contentInset = self.keyboardState.contentInset;
        @synchronized (_chats) {
            
            for (NSString * key in [_chats allKeys]) {
                UITableView * tableView = [_chats objectForKey:key];
                tableView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
                tableView.contentInset = self.keyboardState.contentInset;
                
                //                CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y - _keyboardState.keyboardHeight);
                //                [tableView setContentOffset:newOffset animated:NO];
                
            }
        }
        CGRect buttonFrame = _theButton.frame;
        buttonFrame.origin.y += self.keyboardState.keyboardHeight;
        _theButton.frame = buttonFrame;
        
        self.keyboardState = nil;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration
{
    DDLogInfo(@"will rotate");
    _swipeView.suppressScrollEvent = YES;
    
    
    _bottomIndexPaths = [NSMutableDictionary new];
    
    NSArray * visibleCells = [_friendView indexPathsForVisibleRows];
    if ([visibleCells count ] > 0) {
        
        id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
        DDLogInfo(@"saving index path %@ for home", indexPath );
        [_bottomIndexPaths setObject: indexPath forKey: @"" ];
        
    }
    
    //save scroll indices
    
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            
            UITableView * tableView = [_chats objectForKey:key];
            
            NSArray * visibleCells = [tableView indexPathsForVisibleRows];
            
            if ([visibleCells count ] > 0) {
                
                id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
                
                DDLogInfo(@"saving index path %@ for key %@", indexPath , key);
                
                [_bottomIndexPaths setObject: indexPath forKey: key ];
                
            }
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    DDLogInfo(@"did rotate");
    
    _swipeView.suppressScrollEvent= NO;
    
    //restore scroll indices
    if (_bottomIndexPaths) {
        for (id key in [_bottomIndexPaths allKeys]) {
            if ([key isEqualToString:@""]) {
                
                if (!_homeDataSource.currentChat) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogInfo(@"Scrolling home view to index %@", indexPath);
                    [self scrollTableViewToCell:_friendView indexPath: indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
            else {
                if ([_homeDataSource.currentChat isEqualToString:key]) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogInfo(@"Scrolling %@ view to index %@", key,indexPath);
                    
                    UITableView * tableView = [_chats objectForKey:key];
                    [self scrollTableViewToCell:tableView indexPath:indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
        }
    }
}

- (void) swipeViewDidScroll:(SwipeView *)scrollView {
    DDLogVerbose(@"swipeViewDidScroll");
    [_viewPager scrollViewDidScroll: scrollView.scrollView];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(void) switchToPageIndex:(NSInteger)page {
    _scrollingTo = page;
    [_swipeView scrollToPage:page duration:0.5f];
}

-(NSInteger) currentPage {
    return [_swipeView currentPage];
}

-(NSInteger) pageCount {
    return [self numberOfItemsInSwipeView:nil];
}

-(NSString * ) titleForLabelForPage:(NSInteger)page {
    DDLogVerbose(@"titleForLabelForPage %d", page);
    if (page == 0) {
        return @"home";
    }
    else {
        return [self nameForPage:page];    }
    
    return nil;
}

-(NSString * ) nameForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[self sortedChats] objectAtIndex:page-1];
            }
        }
    }
    
    return nil;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    @synchronized (_chats) {
        
        return 1 + [_chats count];
    }
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    DDLogVerbose(@"view for item at index %d", index);
    if (index == 0) {
        if (!_friendView) {
            DDLogVerbose(@"creating friend view");
            
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            [_friendView registerNib:[UINib nibWithNibName:@"HomeCell" bundle:nil] forCellReuseIdentifier:@"HomeCell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
            if ([_friendView respondsToSelector:@selector(setSeparatorInset:)]) {
                [_friendView setSeparatorInset:UIEdgeInsetsZero];
            }
            
            [self addLongPressGestureRecognizer:_friendView];
        }
        
        DDLogVerbose(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        DDLogVerbose(@"returning chat view");
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedChats];
            id aKey = [keys objectAtIndex:index -1];
            id anObject = [_chats objectForKey:aKey];
            
            return anObject;
        }
    }
    
}

-(void) addLongPressGestureRecognizer: (UITableView  *) tableView {
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(tableLongPress:) ];
    lpgr.minimumPressDuration = .7; //seconds
    [tableView addGestureRecognizer:lpgr];
    
}



- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    NSInteger currPage = swipeView.currentPage;
    DDLogInfo(@"swipeview index changed to %d scrolling to: %d", currPage, _scrollingTo);
    
    UITableView * tableview;
    if (currPage == 0) {
        [[ChatController sharedInstance] setCurrentChat:nil];
        tableview = _friendView;
        
        //stop pulsing
        [UIUtils stopPulseAnimation:_backImageView];
        _scrollingTo = -1;
        
        [tableview reloadData];
        
        if (_bottomIndexPaths) {
            id path = [_bottomIndexPaths objectForKey:@""];
            if (path) {
                [self scrollTableViewToCell:_friendView indexPath:path];
                [_bottomIndexPaths removeObjectForKey:@""];
            }
        }
        
        //update button
        [self updateTabChangeUI];
        [self updateKeyboardState:YES];
        
    }
    else {
        @synchronized (_chats) {
            if (_scrollingTo == currPage || _scrollingTo == -1) {
                tableview = [self sortedValues][swipeView.currentPage-1];
                
                [[ChatController sharedInstance] setCurrentChat: [self sortedChats][currPage-1]];
                _scrollingTo = -1;
                
                if (!_homeDataSource.hasAnyNewMessages) {
                    //stop pulsing
                    [UIUtils stopPulseAnimation:_backImageView];
                }
                
                [tableview reloadData];
                
                //scroll if we need to
                NSString * name =[self nameForPage:currPage];
                BOOL scrolledUsingIndexPath = NO;
                
                //if we've got saved scrlol positions
                if (_bottomIndexPaths) {
                    id path = [_bottomIndexPaths objectForKey:name];
                    if (path) {
                        DDLogInfo(@"scrolling using saved index path for %@",name);
                        [self scrollTableViewToCell:tableview indexPath:path];
                        [_bottomIndexPaths removeObjectForKey:name];
                        scrolledUsingIndexPath = YES;
                    }
                }
                
                
                if (!scrolledUsingIndexPath) {
                    @synchronized (_needsScroll ) {
                        id needsit = [_needsScroll  objectForKey:name];
                        if (needsit) {
                            DDLogInfo(@"scrolling %@ to bottom",name);
                            [self performSelector:@selector(scrollTableViewToBottom:) withObject:tableview afterDelay:0.5];
                            [_needsScroll removeObjectForKey:name];
                        }
                    }
                }
                
                
                //update button
                [self updateTabChangeUI];
                [self updateKeyboardState:NO];
            }
        }
    }
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    DDLogVerbose(@"Selected item at index %i", index);
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    DDLogVerbose(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger) indexForTableView: (UITableView *) tableView {
    if (tableView == _friendView) {
        return 0;
    }
    @synchronized (_chats) {
        NSArray * sortedChats = [self sortedChats];
        for (int i=0; i<[_chats count]; i++) {
            if ([_chats objectForKey:[sortedChats objectAtIndex:i]] == tableView) {
                return i+1;
                
            }
            
        }}
    
    return NSNotFound;
    
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger index = [self indexForTableView:tableView];
    
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    DDLogVerbose(@"number of rows in section, index: %d", index);
    // Return the number of rows in the section
    if (index == 0) {
        if (![[ChatController sharedInstance] getHomeDataSource]) {
            DDLogVerbose(@"returning 1 rows");
            return 1;
        }
        
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        return count == 0 ? 1 : count;
    }
    else {
        NSInteger chatIndex = index-1;
        NSString * username;
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedChats];
            if(chatIndex >= 0 && chatIndex < keys.count ) {
                id aKey = [keys objectAtIndex:chatIndex];
                username = aKey;
            }
        }
        if (username) {
            NSInteger count = [[ChatController sharedInstance] getDataSourceForFriendname: username].messages.count;
            return count == 0 ? 1 : count;
        }
    }
    
    return 1;
    
}



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    //  DDLogVerbose(@"height for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        return 0;
    }
    
    
    
    
    if (index == 0) {
        
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        //if count is 0 we returned 1 for 0 rows so make the single row take up the whole height
        if (count == 0) {
            return tableView.frame.size.height;
        }
        
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        if ([afriend isInviter] ) {
            return 70;
        }
        else {
            return 44;
        }
    }
    else {
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedChats];
            id aKey = [keys objectAtIndex:index -1];
            
            NSString * username = aKey;
            NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
            
            
            //if count is 0 we returned 1 for 0 rows so
            if (messages.count == 0) {
                return tableView.frame.size.height;
            }
            
            
            if (messages.count > 0 && (indexPath.row < messages.count)) {
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
                NSInteger height = 44;
                if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
                    height = message.rowLandscapeHeight;
                }
                else {
                    height  = message.rowPortraitHeight;
                }
                
                if (height > 0) {
                    return height;
                }
                
                else {
                    return 44;
                }
            }
            else {
                return 0;
            }
        }
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    
    //  DDLogVerbose(@"cell for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        return cell;
        
    }
    
    
    
    if (index == 0) {
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        
        if (count == 0) {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"welcome_to_surespot", nil);
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        
        static NSString *CellIdentifier = @"HomeCell";
        HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Configure the cell...
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        cell.friendLabel.text = afriend.name;
        cell.friendName = afriend.name;
        cell.friendDelegate = [ChatController sharedInstance];
        
        BOOL isInviter =[afriend isInviter];
        
        [cell.ignoreButton setHidden:!isInviter];
        [cell.acceptButton setHidden:!isInviter];
        [cell.blockButton setHidden:!isInviter];
        
        cell.activeStatus.hidden = ![afriend isChatActive];
        cell.activeStatus.foregroundColor = [UIUtils surespotBlue];
        
        if (afriend.isInvited || afriend.isInviter || afriend.isDeleted) {
            cell.friendStatus.hidden = NO;
            
            if (afriend.isDeleted) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_deleted", nil);
            }
            
            if (afriend.isInvited) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_invited", nil);
            }
            
            if (afriend.isInviter) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_inviting", nil);
            }
            cell.friendStatus.textAlignment = NSTextAlignmentCenter;
            cell.friendStatus.lineBreakMode = NSLineBreakByWordWrapping;
            cell.friendStatus.numberOfLines = 0;
            
            
        }
        else {
            cell.friendStatus.hidden = YES;
        }
        
        cell.messageNewView.hidden = !afriend.hasNewMessages;
        
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
        bgColorView.layer.masksToBounds = YES;
        cell.selectedBackgroundView = bgColorView;
        
        return cell;
    }
    else {
        id aKey;
        @synchronized (_chats) {
            NSArray *keys = [self sortedChats];
            aKey = [keys objectAtIndex:index -1];
        }
        NSString * username = aKey;
        NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
        
        
        if (messages.count == 0) {
            DDLogInfo(@"no chat messages");
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"no_messages", nil);
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        if (messages.count > 0 && indexPath.row < messages.count) {
            
            
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSString * plainData = [message plainData];
            static NSString *OurCellIdentifier = @"OurMessageView";
            static NSString *TheirCellIdentifier = @"TheirMessageView";
            
            NSString * cellIdentifier;
            BOOL ours = NO;
            
            if ([ChatUtils isOurMessage:message]) {
                ours = YES;
                cellIdentifier = OurCellIdentifier;
                
            }
            else {
                cellIdentifier = TheirCellIdentifier;
            }
            MessageView *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
            if (!ours) {
                
                cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
            }
            
            cell.messageLabel.text = plainData;
            cell.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
            UIView *bgColorView = [[UIView alloc] init];
            bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
            bgColorView.layer.masksToBounds = YES;
            cell.selectedBackgroundView = bgColorView;
            DDLogVerbose(@"message text x position: %f, width: %f", cell.messageLabel.frame.origin.x, cell.messageLabel.frame.size.width);
            
            if (message.errorStatus > 0) {
                NSString * errorText = [UIUtils getMessageErrorText: message.errorStatus];
                cell.messageStatusLabel.text = errorText;
                cell.messageSentView.foregroundColor = [UIColor blackColor];
            }
            else {
                
                if (message.serverid <= 0) {
                    cell.messageStatusLabel.text = NSLocalizedString(@"message_sending",nil);
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor blackColor];
                    }
                }
                else {
                    if (!message.formattedDate) {
                        message.formattedDate = [self stringFromDate:[message dateTime]];
                    }
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                    }
                    
                    if (!message.plainData) {
                        cell.messageStatusLabel.text = NSLocalizedString(@"message_loading_and_decrypting",nil);
                    }
                    else {
                        
                        //   DDLogVerbose(@"setting text for iv: %@ to: %@", [message iv], plainData);
                        
                        cell.messageStatusLabel.text = message.formattedDate;
                        
                        if (ours) {
                            cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                        }
                        else {
                            cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
                        }
                    }
                }
            }
            
            if ([message.mimeType isEqualToString:MIME_TYPE_TEXT]) {
                cell.messageLabel.hidden = NO;
                cell.uiImageView.hidden = YES;
                cell.shareableView.hidden = YES;
            }
            else {
                if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                    cell.shareableView.hidden = NO;
                    cell.messageLabel.hidden = YES;
                    cell.uiImageView.hidden = NO;
                    cell.uiImageView.alignTop = YES;
                    cell.uiImageView.alignLeft = YES;
                    
                    if (message.shareable) {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_partial_secure"];
                    }
                    else {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_secure"];
                    }
                    
                    [cell setImageWithMessage:message
                             placeholderImage:nil
                                     progress:^(NSUInteger receivedSize, long long expectedSize) {
                                         
                                     }
                                    completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
                                        if (error) {
                                            
                                        }
                                    }
                     ];
                    
                    DDLogInfo(@"imageView: %@", cell.uiImageView);
                }
                else {
                    if ([message.mimeType isEqualToString:MIME_TYPE_M4A]) {
                        cell.messageLabel.hidden = YES;
                        cell.uiImageView.hidden = NO;
                    }
                }
            }
            
            
            return cell;
        }
        else {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.userInteractionEnabled = NO;
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    DDLogVerbose(@"selected, on page: %d", page);
    
    if (page == 0) {
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        
        if (afriend && [afriend isFriend]) {
            NSString * friendname =[afriend name];
            [self showChat:friendname];
        }
        else {
            [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
        }
    }
    else {
        // if it's an image, open it in image viewer
        ChatDataSource * cds = [[ChatController sharedInstance] getDataSourceForFriendname:[[ChatController sharedInstance] getCurrentChat]];
        if (cds) {
            SurespotMessage * message = [cds.messages objectAtIndex:indexPath.row];
            if ([message.mimeType isEqualToString: MIME_TYPE_IMAGE]) {
                // Create array of `MWPhoto` objects
                _imageMessage = message;
                // Create & present browser
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                // Set options
                browser.displayActionButton = NO; // Show action button to allow sharing, copying, etc (defaults to YES)
                browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
                browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
                browser.wantsFullScreenLayout = NO; // iOS 5 & 6 only: Decide if you want the photo browser full screen, i.e. whether the status bar is affected (defaults to YES)
                
                // Present
                [self.navigationController pushViewController:browser animated:YES];
            }
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

-(NSArray *) sortedChats {
    return [[_chats allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
}

-(NSArray *) sortedValues {
    NSArray * sortedKeys = [self sortedChats];
    NSMutableArray * sortedValues = [NSMutableArray new];
    for (NSString * key in sortedKeys) {
        [sortedValues addObject:[_chats objectForKey:key]];
    }
    return sortedValues;
}

-(void) loadChat:(NSString *) username show: (BOOL) show  availableId: (NSInteger) availableId availableControlId: (NSInteger) availableControlId {
    DDLogVerbose(@"entered");
    //get existing view if there is one
    UITableView * chatView;
    @synchronized (_chats) {
        chatView = [_chats objectForKey:username];
    }
    if (!chatView) {
        
        chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
        [chatView setDelegate:self];
        [chatView setDataSource: self];
        [chatView setScrollsToTop:NO];
        [chatView setDirectionalLockEnabled:YES];
        if ([chatView respondsToSelector:@selector(setSeparatorInset:)]) {
            [chatView setSeparatorInset:UIEdgeInsetsZero];
        }
        [self addLongPressGestureRecognizer:chatView];
        
        // setup pull-to-refresh
        __weak UITableView *weakView = chatView;
        [chatView addPullToRefreshWithActionHandler:^{
            
            [[ChatController sharedInstance] loadEarlierMessagesForUsername: username callback:^(id result) {
                if (result) {
                    NSInteger resultValue = [result integerValue];
                    if (resultValue == 0 || resultValue == NSIntegerMax) {
                        [UIUtils showToastKey:@"all_messages_loaded"];
                    }
                    else {
                        DDLogInfo(@"loaded %@ earlier messages for user: %@", result, username);
                        [self updateTableView:weakView withNewRowCount:[result integerValue]];
                    }
                }
                else {
                    [UIUtils showToastKey:@"loading_earlier_messages_failed"];
                }
                
                [weakView.pullToRefreshView stopAnimating];
                
            }];
        }];
        
        //create the data source
        [[ChatController sharedInstance] createDataSourceForFriendname:username availableId: availableId availableControlId:availableControlId];
        
        NSInteger index = 0;
        @synchronized (_chats) {
            
            [_chats setObject:chatView forKey:username];
            index = [[self sortedChats] indexOfObject:username] + 1          ;
            
        }
        
        DDLogVerbose(@"creatingindex: %d", index);
        
        //   [chatView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ChatCell"];
        [chatView registerNib:[UINib nibWithNibName:@"OurMessageCell" bundle:nil] forCellReuseIdentifier:@"OurMessageView"];
        [chatView registerNib:[UINib nibWithNibName:@"TheirMessageCell" bundle:nil] forCellReuseIdentifier:@"TheirMessageView"];
        
        [_swipeView loadViewAtIndex:index];
        [_swipeView updateItemSizeAndCount];
        [_swipeView updateScrollViewDimensions];
        
        if (show) {
            _scrollingTo = index;
            [_swipeView scrollToPage:index duration:0.500];
            [[ChatController sharedInstance] setCurrentChat: username];
        }
        
    }
    
    else {
        if (show) {
            [[ChatController sharedInstance] setCurrentChat: username];
            NSInteger index;
            @synchronized (_chats) {
                index = [[self sortedChats] indexOfObject:username] + 1;
            }
            
            DDLogVerbose(@"scrolling to index: %d", index);
            _scrollingTo = index;
            [_swipeView scrollToPage:index duration:0.500];
        }
    }
}

-(void) showChat:(NSString *) username {
    DDLogVerbose(@"showChat, %@", username);
    
    Friend * afriend = [_homeDataSource getFriendByName:username];
    
    [self loadChat:username show:YES availableId:[afriend availableMessageId] availableControlId:[afriend availableMessageControlId]];
    //   [_textField resignFirstResponder];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self handleTextAction];
    return NO;
}

- (BOOL) handleTextAction {
    if (!_homeDataSource.currentChat) {
        NSString * text = _inviteField.text;
        
        if ([text length] > 0) {
            
            NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
            if ([text isEqualToString:loggedInUser]) {
                [UIUtils showToastKey:@"friend_self_error"];
                return YES;
            }
            
            
            [[ChatController sharedInstance] inviteUser:text];
            [_inviteField setText:nil];
            [self updateTabChangeUI];
            return YES;
        }
        else {
            [_inviteField resignFirstResponder];
            [_textField resignFirstResponder];
            
            return NO;
        }
        
    }
    else {
        NSString * text = _textField.text;
        
        if ([text length] > 0) {
            
            [self send];
            return YES;
        }
        
        else {
            [_inviteField resignFirstResponder];
            [_textField resignFirstResponder];
            return NO;
        }
    }
    
    
}


- (void) send {
    
    NSString* message = self.textField.text;
    
    if ([UIUtils stringIsNilOrEmpty:message]) return;
    id friendname;
    @synchronized (_chats) {
        NSArray *keys = [self sortedChats];
        friendname = [keys objectAtIndex:[_swipeView currentItemIndex] -1];
    }
    
    Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:friendname];
    if ([afriend isDeleted]) {
        return;
    }
    
    
    [[ChatController sharedInstance] sendMessage: message toFriendname:friendname];
    
    [_textField setText:nil];
    
    [self updateTabChangeUI];
}


//if we're going to chat tab from home tab and keyboard is showing
//become the first esponder so we're not typing in the invite field
//thinking we're typing in the text field
-(void) updateKeyboardState: (BOOL) goingHome {
    if (goingHome) {
        [_inviteField resignFirstResponder];
        [_textField resignFirstResponder];
    }
    else {
        if ([_inviteField isFirstResponder]) {
            [_inviteField resignFirstResponder];
            
            [_textField becomeFirstResponder];
        }
    }
}

-(void) updateTabChangeUI {
    if (!_homeDataSource.currentChat) {
        [_theButton setImage:[UIImage imageNamed:@"ic_menu_invite"] forState:UIControlStateNormal];
        _textField.hidden = YES;
        _inviteField.hidden = NO;
    }
    else {
        _inviteField.hidden = YES;
        Friend *afriend = [_homeDataSource getFriendByName:_homeDataSource.currentChat];
        if (afriend.isDeleted) {
            [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
            _textField.hidden = YES;
        }
        else {
            _textField.hidden = NO;
            if ([_textField.text length] > 0) {
                [_theButton setImage:[UIImage imageNamed:@"ic_menu_send"] forState:UIControlStateNormal];
            }
            else {
                [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
            }
        }
    }
}

-(void) updateTableView: (UITableView *) tableView withNewRowCount : (int) rowCount
{
    //Save the tableview content offset
    CGPoint tableViewOffset = [tableView contentOffset];
    
    //compute the height change
    int heightForNewRows = 0;
    
    for (NSInteger i = 0; i < rowCount; i++) {
        NSIndexPath *tempIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
        heightForNewRows += [self tableView:tableView heightForRowAtIndexPath: tempIndexPath];
    }
    
    tableViewOffset.y += heightForNewRows;
    [tableView reloadData];
    [tableView setContentOffset:tableViewOffset animated:NO];
}


- (void)refreshMessages:(NSNotification *)notification {
    NSString * username = notification.object;
    DDLogInfo(@"username: %@, currentchat: %@", username, _homeDataSource.currentChat);
    
    if ([username isEqualToString: _homeDataSource.currentChat]) {
        
        UITableView * tableView;
        @synchronized (_chats) {
            tableView = [_chats objectForKey:username];
            
        }
        @synchronized (_needsScroll) {
            [_needsScroll removeObjectForKey:username];
        }
        
        if (tableView) {
            [tableView reloadData];
            [self performSelector:@selector(scrollTableViewToBottom:) withObject:tableView afterDelay:0.5];
        }
    }
    else {
        @synchronized (_needsScroll) {
            DDLogInfo(@"setting needs scroll for %@", username);
            [_needsScroll setObject:@"yourmama" forKey:username];
            [_bottomIndexPaths removeObjectForKey:username];
        }
    }
}

- (void) scrollTableViewToBottom: (UITableView *) tableView {
    NSInteger numRows =[tableView numberOfRowsInSection:0];
    if (numRows > 0) {
        DDLogVerbose(@"scrolling to row: %d", numRows);
        NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:(numRows - 1) inSection:0];
        [tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}


- (void) scrollTableViewToCell: (UITableView *) tableView  indexPath: (NSIndexPath *) indexPath {
    DDLogInfo(@"scrolling to cell: %@", indexPath);
    // NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:(numRows - 1) inSection:0];
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    
}

- (void)refreshHome:(NSNotification *)notification
{
    DDLogVerbose(@"refreshHome");
    
    if (_friendView) {
        [_friendView reloadData];
    }
    
}


-(void) removeFriend: (Friend *) afriend {
    [[[ChatController sharedInstance] getHomeDataSource] removeFriend:afriend withRefresh:YES];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        string = [_dateFormatter stringFromDate:date ];
    });
    return string;
}

-(REMenu *) createMenuMenu {
    //menu menu
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    if (_homeDataSource.currentChat) {
        NSString * theirUsername = _homeDataSource.currentChat;
        
        REMenuItem * selectImageItem = [[REMenuItem alloc]
                                        initWithTitle:NSLocalizedString(@"select_image", nil)
                                        image:[UIImage imageNamed:@"ic_menu_gallery"]
                                        highlightedImage:nil
                                        action:^(REMenuItem * item){
                                            
                                            _imageDelegate = [[ImageDelegate alloc]
                                                              initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                              ourVersion:[[IdentityController sharedInstance] getOurLatestVersion]
                                                              theirUsername:theirUsername];
                                            [ImageDelegate startImageSelectControllerFromViewController:self usingDelegate:_imageDelegate];
                                            
                                            
                                        }];
        [menuItems addObject:selectImageItem];
        
        
        REMenuItem * captureImageItem = [[REMenuItem alloc]
                                         initWithTitle:NSLocalizedString(@"capture_image", nil)
                                         image:[UIImage imageNamed:@"ic_menu_camera"]
                                         highlightedImage:nil
                                         action:^(REMenuItem * item){
                                             
                                             _imageDelegate = [[ImageDelegate alloc]
                                                               initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                               ourVersion:[[IdentityController sharedInstance] getOurLatestVersion]
                                                               theirUsername:theirUsername];
                                             [ImageDelegate startCameraControllerFromViewController:self usingDelegate:_imageDelegate];
                                             
                                             
                                         }];
        [menuItems addObject:captureImageItem];
        
        
        REMenuItem * closeTabItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
            [self closeTab];
        }];
        
        [menuItems addObject:closeTabItem];
        
        REMenuItem * deleteAllItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
            [[ChatController sharedInstance] deleteMessagesForFriend: [_homeDataSource getFriendByName:_homeDataSource.currentChat]];
            
        }];
        
        [menuItems addObject:deleteAllItem];
    }
    REMenuItem * logoutItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"logout", nil) image:[UIImage imageNamed:@"ic_lock_power_off"] highlightedImage:nil action:^(REMenuItem * item){
        [self logout];
        
    }];
    [menuItems addObject:logoutItem];
    
    REMenuItem * settingsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"settings", nil) image:[UIImage imageNamed:@"ic_menu_preferences"] highlightedImage:nil action:^(REMenuItem * item){
        [self showSettings];
        
    }];
    
    [menuItems addObject:settingsItem];
    
    return [self createMenu: menuItems];
}

-(REMenu *) createMenu: (NSArray *) menuItems {
    return [UIUtils createMenu:menuItems closeCompletionHandler:^{
        _menu = nil;
        NSString * currentChat =[[ChatController sharedInstance] getCurrentChat];
        if (currentChat) {
            id currentTableView =[_chats objectForKey:currentChat];
            if (currentTableView ) {
                [currentTableView deselectRowAtIndexPath:[currentTableView indexPathForSelectedRow] animated:YES];
            }
        }
        else {
            [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
        }
    }];
}


-(REMenu *) createHomeMenuFriend: (Friend *) thefriend {
    //home menu
    
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    
    if ([thefriend isChatActive]) {
        REMenuItem * closeTabHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
            [self closeTabName: thefriend.name];
        }];
        [menuItems addObject:closeTabHomeItem];
    }
    
    
    REMenuItem * deleteAllHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        [[ChatController sharedInstance] deleteMessagesForFriend: thefriend];
        
        
    }];
    [menuItems addObject:deleteAllHomeItem];
    
    REMenuItem * deleteFriendItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_friend", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        [[ChatController sharedInstance] deleteFriend: thefriend];
    }];
    [menuItems addObject:deleteFriendItem];
    
    
    return [self createMenu: menuItems];
}

-(REMenu *) createChatMenuMessage: (SurespotMessage *) message {
    BOOL ours = [ChatUtils isOurMessage:message];
    NSMutableArray * menuItems = [NSMutableArray new];
    
    
    //can always delete
    REMenuItem * deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_message", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        
        
        [self deleteMessage: message];
        
    }];
    
    [menuItems addObject:deleteItem];
    
    
    if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
        
        
        
        
        
        //allow saving to gallery if it's unlocked, or it's ours
        
        REMenuItem * saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"save_to_photos", nil) image:[UIImage imageNamed:@"ic_menu_save"] highlightedImage:nil action:^(REMenuItem * item){
            
        }];
        
        
        [saveItem setTitleEnabled: ours || message.shareable];
        [menuItems addObject:saveItem];
        
        
        
        
        //if i'ts our message and ti's been sent we can change lock status
        if (message.serverid > 0 && ours) {
            UIImage * image = nil;
            NSString * title = nil;
            if (!message.shareable) {
                title = NSLocalizedString(@"menu_unlock", nil);
                image = [UIImage imageNamed:@"ic_partial_secure"];
            }
            else {
                title = NSLocalizedString(@"menu_lock", nil);
                image = [UIImage imageNamed:@"ic_secure"];
            }
            
            REMenuItem * shareItem = [[REMenuItem alloc] initWithTitle:title image:image highlightedImage:nil action:^(REMenuItem * item){
                [[ChatController sharedInstance] toggleMessageShareable:message];
                
            }];
            
            [menuItems addObject:shareItem];
        }
    }
    
    else {
        if ([message.mimeType isEqualToString:MIME_TYPE_M4A]) {
            
        }
    }
    
    
    return [self createMenu: menuItems];
    
}




-(void)tableLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    NSInteger _menuPage = _swipeView.currentPage;
    UITableView * currentView = _menuPage == 0 ? _friendView : [[self sortedValues] objectAtIndex:_menuPage-1];
    
    CGPoint p = [gestureRecognizer locationInView:currentView];
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        NSIndexPath *indexPath = [currentView indexPathForRowAtPoint:p];
        if (indexPath == nil) {
            DDLogVerbose(@"long press on table view at page %d but not on a row", _menuPage);
        }
        else {
            
            
            [currentView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            [self showMenuForPage: _menuPage indexPath: indexPath];
            DDLogInfo(@"long press on table view at page %d, row %d", _menuPage, indexPath.row);
        }
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        DDLogVerbose(@"taking action for chat iv: %@, plaindata: %@", message.iv, message.plainData);
        [[ChatController sharedInstance] deleteMessage: message];
    }
}

-(void) showMenuMenu {
    if (!_menu) {
        _menu = [self createMenuMenu];
        if (_menu) {
            CGRect rect = CGRectMake(25, 0, self.view.frame.size.width                   - 50, self.view.frame.size.height);
            [_menu showFromRect:rect inView:self.view];
        }
    }
    else {
        [_menu close];
    }
    
}

-(void) showMenuForPage: (NSInteger) page indexPath: (NSIndexPath *) indexPath {
    if (!_menu) {
        
        if (page == 0) {
            Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
            _menu = [self createHomeMenuFriend:afriend];
        }
        
        else {
            NSString * name = [self nameForPage:page];
            NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: name].messages;
            if (messages.count > 0) {
                
                
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                
                _menu = [self createChatMenuMessage:message];
            }
        }
        
        if (_menu) {
            CGRect rect = CGRectMake(25, 0, self.view.frame.size.width - 50, self.view.frame.size.height);
            
            [_menu showFromRect:rect inView:self.view];
        }
    }
}

- (void)deleteFriend:(NSNotification *)notification
{
    NSArray * data =  notification.object;
    
    NSString * name  =[data objectAtIndex:0];
    BOOL ideleted = [[data objectAtIndex:1] boolValue];
    
    if (ideleted) {
        [self closeTabName:name];
    }
    else {
        [self updateTabChangeUI];
        if ([name isEqualToString:_homeDataSource.currentChat]) {
            [_textField resignFirstResponder];
        }
    }
}

-(void) closeTabName: (NSString *) name {
    if (name) {
        [[ChatController sharedInstance] destroyDataSourceForFriendname: name];
        [[_homeDataSource getFriendByName:name] setChatActive:NO];
        @synchronized (_chats) {
            [_chats removeObjectForKey:name];
        }
        [_swipeView reloadData];
        NSInteger page = [_swipeView currentPage];
        
        if ([name isEqualToString:_homeDataSource.currentChat]) {
            
            
            if (page >= _swipeView.numberOfPages) {
                page = _swipeView.numberOfPages - 1;
            }
            [_swipeView scrollToPage:page duration:0.2];
        }
        DDLogVerbose(@"page after close: %d", page);
        NSString * name = [self nameForPage:page];
        DDLogVerbose(@"name after close: %@", name);
        [_homeDataSource setCurrentChat:name];
        [_homeDataSource postRefresh];
        
    }
}

-(void) closeTab {
    [self closeTabName: _homeDataSource.currentChat];
}

-(void) logout {
    
    //blow the views away
    
    _friendView = nil;
    
    [[NetworkController sharedInstance] logout];
    [[ChatController sharedInstance] logout];
    [[IdentityController sharedInstance] logout];
    @synchronized (_chats) {
        [_chats removeAllObjects];
        [_swipeView reloadData];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)buttonTouchUpInside:(id)sender {
    if (![self handleTextAction]) {
        [self scrollHome];
    }
    
}
- (void) backPressed {
    [self scrollHome];
}

-(void) scrollHome {
    _scrollingTo = 0;
    [_swipeView scrollToPage:0 duration:0.5];
    
}
- (IBAction)textFieldChanged:(id)sender {
    [self updateTabChangeUI];
}

- (void) startProgress: (NSNotification *) notification {
    
    if (_progressCount++ == 0) {
        [UIUtils startSpinAnimation: _backImageView];
    }
    
    DDLogInfo(@"progress count:%d", _progressCount);
}

-(void) stopProgress: (NSNotification *) notification {
    if (--_progressCount == 0) {
        [UIUtils stopSpinAnimation:_backImageView];
    }
    DDLogInfo(@"progress count:%d", _progressCount);
}


- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _inviteField) {
        NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
        NSString * newString = [string stringByTrimmingCharactersInSet:alphaSet];
        if (![newString isEqualToString:@""]) {
            return NO;
        }
        
        NSUInteger newLength = [textField.text length] + [newString length] - range.length;
        return (newLength >= 20) ? NO : YES;
    }
    else {
        
        if (textField == _textField){
            NSUInteger newLength = [textField.text length] + [string length] - range.length;
            return (newLength >= 1024) ? NO : YES;
        }
    }
    
    return YES;
}


-(void) unauthorized: (NSNotification *) notification {
    DDLogInfo(@"unauthorized");
    // [UIUtils showToastKey:@"unauthorized" duration:2];
    [self logout];
}

-(void) newMessage: (NSNotification *) notification {
    SurespotMessage * message = notification.object;
    NSString * currentChat =[[ChatController sharedInstance] getCurrentChat];
    //show toast if we're not on the tab or home page, and pulse if we're logged in as the user
    if (currentChat &&
        ![message.from isEqualToString: currentChat] &&
        [[[IdentityController sharedInstance] getIdentityNames] containsObject:message.to]) {
        [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_message", nil), message.to, message.from] duration:1];
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}

-(void) invite: (NSNotification *) notification {
    Friend * thefriend = notification.object;
    NSString * currentChat =[[ChatController sharedInstance] getCurrentChat];
    //show toast if we're not on the tab or home page, and pulse if we're logged in as the user
    if (currentChat) {
        [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_invite", nil), [[IdentityController sharedInstance] getLoggedInUser], thefriend.name] duration:1];
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}


-(void) inviteAccepted: (NSNotification *) notification {
    NSString * acceptedBy = notification.object;
    NSString * currentChat =[[ChatController sharedInstance] getCurrentChat];
    //show toast if we're not on the tab or home page, and pulse if we're logged in as the user
    if (currentChat) {
        [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_invite_accept", nil), [[IdentityController sharedInstance] getLoggedInUser], acceptedBy] duration:1];
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}


#pragma mark -
#pragma mark IASKAppSettingsViewControllerDelegate protocol
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    //[self dismissModalViewControllerAnimated:YES];
    
    // your code here to reconfigure the app for changed settings
}

-(void) showSettings {
    self.appSettingsViewController.showDoneButton = NO;
    [self.navigationController pushViewController:self.appSettingsViewController animated:YES];
}


- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return 1;
}

- (SurespotPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index == 0 && _imageMessage)
        return [[SurespotPhoto alloc] initWithURL:[NSURL URLWithString:_imageMessage.data] encryptionParams:[[EncryptionParams alloc] initWithOurUsername:nil ourVersion:[_imageMessage getOurVersion] theirUsername: [_imageMessage getOtherUser] theirVersion:[_imageMessage getTheirVersion] iv:_imageMessage.iv]];
    return nil;
}

@end