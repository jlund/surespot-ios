//
//  SwipeViewController.m
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SwipeViewController.h"
#import "NetworkController.h"


@interface SwipeViewController ()
@end


@implementation SwipeViewController


- (void)viewDidLoad
{
    NSLog(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =YES ;
    
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
    return 1;
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
        NSLog(@"view for item at index %d", index);
    if (!_friendView && index == 0) {
    //if (!view) {
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
    NSLog(@"tableview pointer: %@", tableView);
    // Return the number of rows in the section
    if (!self.friends) {
        NSLog(@"returning 0 rows");
        return 0;
    }
    NSArray * friends = [self.friends objectForKey:@"friends"];
    NSUInteger count =  [friends count];
    NSLog(@"returning %d rows",count);
    return count;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"cell for row");
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSArray * friends =[self.friends objectForKey:@"friends"];
    
    // Configure the cell...
    cell.textLabel.text = [(NSDictionary *)[friends objectAtIndex:indexPath.row] objectForKey:@"name"];
    
    return cell;
}


@end