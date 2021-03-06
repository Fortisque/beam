//
//  ChallengeTableViewController.m
//  An Apple A Day
//
//  Created by Gavin Chu on 12/28/14.
//  Copyright (c) 2014 ieor190. All rights reserved.
//

#import "ChallengeTableViewController.h"
#import "ChallengeHeaderTableViewCell.h"
#import "ChallengeInfoTableViewCell.h"
#import "ChallengeImageTableViewCell.h"
#import "ChallengeCommentTableViewCell.h"
#import "ChallengeButtonTableViewCell.h"
#import "CompleteChallengeViewController.h"
#import "ChallengeVideoTableViewCell.h"
#import <BuiltIO/BuiltIO.h>
#import "Global.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@interface ChallengeTableViewController ()

@property BOOL checkedIfCompleted;

@end

@implementation ChallengeTableViewController

CGFloat SCREEN_WIDTH;
CGFloat SCREEN_HEIGHT;

NSDateFormatter *dateFormatter;
Global *globalKeyValueStore;

- (void)viewDidLoad {
    [super viewDidLoad];
    [Global addAnimatingLoaderToView:[[[UIApplication sharedApplication] delegate] window]];
    //self.tableView.contentInset = UIEdgeInsetsMake(-64.0f, 0.0f, 0.0f, 0.0f); //hack to remove top space
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    SCREEN_WIDTH = screenRect.size.width;
    SCREEN_HEIGHT = screenRect.size.height;
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    if (!self.challenge) {
        self.challenge = [[Challenge alloc] init];
    }
    
    globalKeyValueStore = [Global globalClass];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"]; // using ISODate format so it will sort properly
    
    self.checkedIfCompleted = NO;
    
    //challenge detail should already have challenge uid
    if (self.isChallengeDetail) {
        [self queryCompletedDailyChallenge];
    } else {
        [self getChallengeForDay];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.tableView beginUpdates];
    // Reload the video, it breaks when we switch back to it.
    NSIndexPath *indexPathToMovie = [NSIndexPath indexPathForRow:2 inSection:0];
    [self.tableView reloadRowsAtIndexPaths:@[indexPathToMovie] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Query

- (void)getChallengeForDay {
    NSLog(@"getChallengeForDay");
    // Set date queried to be stored to persistent storage later
    NSString *dateQueried = [dateFormatter stringFromDate:self.date];
    
    BuiltQuery *query = [BuiltQuery queryWithClassUID:@"challenge"];
    [query whereKey:@"date" equalTo:dateQueried];
    
    [query includeOnlyFields:[NSArray arrayWithObjects: @"uid", @"date", @"information", nil]];
    
    [query exec:^(QueryResult *result, ResponseType type) {
        // the query has executed successfully.
        // [result getResult] will contain a list of objects that satisfy the conditions
        
        NSArray *results = [result getResult];
        if ([results count] == 0) {
            NSLog(@"NO DAILY CHALLENGE!");
        } else {
            BuiltObject *builtChallenge = [results objectAtIndex:0];
            NSLog(@"CHALLENGE %@", builtChallenge);
            self.challenge.date = dateQueried;
            self.challenge.info = [builtChallenge objectForKey:@"information"];
            self.challenge.uid = [builtChallenge objectForKey:@"uid"];
            self.challenge.completed = NO;
        }
        
        NSLog(@"today's challenge: %@", [self.challenge toString]);
        
        //[self.tableView reloadData];
        [self queryCompletedDailyChallenge];
    } onError:^(NSError *error, ResponseType type) {
        // query execution failed.
        // error.userinfo contains more details regarding the same
        NSLog(@"%@", @"ERROR");
        NSLog(@"%@", error.userInfo);
        [Global removeAnimatingLoaderFromView:[[[UIApplication sharedApplication] delegate] window]];
    }];
}

- (void)queryCompletedDailyChallenge {
    NSLog(@"queryCompletedDailyChallenge");
    // Make sure everything is set up first. This method gets called when we successfully login and when challenge is successfully queried
    if (!self.checkedIfCompleted && self.challenge.uid && [globalKeyValueStore getValueforKey:kBuiltUserUID]) {
        
        //only make this query once
        self.checkedIfCompleted = YES;
        
        BuiltQuery *query = [BuiltQuery queryWithClassUID:@"usersChallenges"];
        [query whereKey:@"user" equalTo:[globalKeyValueStore getValueforKey:kBuiltUserUID]];
        [query whereKey:@"challenge" equalTo:self.challenge.uid];
        
        [query exec:^(QueryResult *result, ResponseType type) {
            // the query has executed successfully.
            // [result getResult] will contain a list of objects that satisfy the conditions
            NSArray *builtResults = [result getResult];
            
            if ([builtResults count] == 0) {
                NSLog(@"not completed");
                self.challenge.completed = NO;

                [self.tableView reloadData];
                [Global removeAnimatingLoaderFromView:[[[UIApplication sharedApplication] delegate] window]];
            } else {
                NSLog(@"completed");
                self.challenge.completed = YES;
                
                NSDictionary *builtResult = [builtResults objectAtIndex:0];
                
                self.challenge.comment = [builtResult objectForKey:@"comment"];
                
                NSDictionary *file = [builtResult objectForKey:@"file"];
                
                if (![file respondsToSelector:@selector(objectForKey:)]) {
                    // Make sure we are getting back a dictionary.
                    // Built sometimes returns an empty string.
                    file = nil;
                }
                if (file) {
                    NSString *fileUrl = [file objectForKey:@"url"];
                    NSURL *url = [NSURL URLWithString:fileUrl];
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        // Grabbing the data is expensive, and blocks UI
                        // Using a thread to background it while animation is running
                        NSData *data = [NSData dataWithContentsOfURL:url];
                        if ([[file objectForKey:@"filename"] isEqualToString:@"image"]) {
                            UIImage *img = [[UIImage alloc] initWithData:data];
                            if (img != nil) {
                                self.challenge.image = img;
                            }
                        } else { // must be MOV file
                            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                            NSString *documentsDirectory = [paths objectAtIndex:0];
                            NSString *filename = [NSString stringWithFormat:@"tmp - %@.mov", self.challenge.date];
                            NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];
                        
                            NSData *videoData = [NSData dataWithContentsOfURL:url];
                        
                            [[NSFileManager defaultManager] createFileAtPath:path contents:videoData attributes:nil];
                            NSURL *moveUrl = [NSURL fileURLWithPath:path];
                        
                            self.challenge.videoUrl = moveUrl;
                            NSLog(@"true challenge: %@", [self.challenge toString]);
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Need to do UI updates on main thread
                            [Global removeAnimatingLoaderFromViewWithExplosion:[[[UIApplication sharedApplication] delegate] window]];
                            [self.tableView reloadData];
                        });
                    });
                }
                
                self.challenge.usersChallengesUID = [builtResult objectForKey:@"uid"];
                
                NSLog(@"completed challenge: %@", [self.challenge toString]);
                
                if (file == NULL) {
                    [self.tableView reloadData];
                    [Global removeAnimatingLoaderFromView:[[[UIApplication sharedApplication] delegate] window]];
                }
            }
            
        } onError:^(NSError *error, ResponseType type) {
            // query execution failed.
            // error.userinfo contains more details regarding the same
            NSLog(@"%@", @"ERROR");
            NSLog(@"%@", error.userInfo);
            [Global removeAnimatingLoaderFromView:[[[UIApplication sharedApplication] delegate] window]];
        }];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat screenHeight = self.view.frame.size.height;
    //NSLog(@"table view height: %f", screenHeight);
    if (indexPath.row == 0) {
        if (self.challenge.completed) {
            return 0;
        } else {
            return screenHeight*0.4;
        }
    } else if (indexPath.row == 1) {
        if (self.challenge.completed) {
            if (self.challenge.image) {
                return 150; //shrink info view if there's an image
            }
            return screenHeight*0.4;
        }
        return screenHeight*0.6 - 120;
    } else if (indexPath.row == 2) {
        if (self.challenge.completed) {
            if (self.challenge.image) {
                CGFloat imageRatio = self.challenge.image.size.height/self.challenge.image.size.width;
                return SCREEN_WIDTH*imageRatio;
            } else if (self.challenge.videoUrl) {
                // This is the height of the video player.
                return self.view.frame.size.width;
            }
        }
        return 0;
    } else if (indexPath.row == 3) {
        if (self.challenge.completed) {
            
            CGFloat minimumHeight = screenHeight*0.6 - 120;
            
            NSAttributedString *attributedText = [[NSAttributedString alloc]
                                            initWithString:self.challenge.comment
                                                attributes:@{NSFontAttributeName:
                                                         [UIFont fontWithName:@"Gotham-Book" size:16.0]}];
            
            CGRect rect = [attributedText boundingRectWithSize:(CGSize){self.view.frame.size.width - 100, CGFLOAT_MAX}
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                       context:nil];
            
            CGFloat suggestedHeight = rect.size.height + 100;
            
            
            if (suggestedHeight > minimumHeight) {
                return suggestedHeight;
            } else {
                return minimumHeight;
            }
            
        } else {
            return 0;
        }
    } else if (indexPath.row == 4) {
        if (self.isChallengeDetail) {
            return 0;
        }
        return 120;
    }
    return 40;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        ChallengeHeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeHeaderCell" forIndexPath:indexPath];
        if (self.challenge.completed) {
            cell.sunLogo.hidden = YES;
            cell.background.hidden = YES;
        } else {
            cell.sunLogo.hidden = NO;
            cell.background.hidden = NO;
        }
        return cell;
    } else if (indexPath.row == 1) {
        ChallengeInfoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeInfoCell" forIndexPath:indexPath];
        cell.info.text = self.challenge.info;
        if (self.challenge.completed) {
            cell.contentView.backgroundColor = [UIColor whiteColor];
            cell.info.textColor = [UIColor grayColor];
            cell.challengeLabel.textColor = [UIColor grayColor];
        } else {
            cell.contentView.backgroundColor = UIColorFromRGB(0x4FBDE0);
            cell.info.textColor = [UIColor whiteColor];
            cell.challengeLabel.textColor = [UIColor whiteColor];
        }
        return cell;
    } else if (indexPath.row == 2) {
        if (self.challenge.videoUrl) {
            ChallengeVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeVideoCell" forIndexPath:indexPath];
            if(cell.player) {
                [cell.player.view removeFromSuperview];
            }
            cell.player = [[MPMoviePlayerController alloc] initWithContentURL:self.challenge.videoUrl];
            cell.player.view.frame = CGRectMake(0, 0, cell.frame.size.width, cell.frame.size.width);
            [cell.player prepareToPlay];
            cell.player.shouldAutoplay = NO;
            [cell addSubview:cell.player.view];
            return cell;
        } else {
            ChallengeImageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeImageCell" forIndexPath:indexPath];
            cell.image.image = self.challenge.image;
            NSLog(@"challenge.image height %f and width %f", self.challenge.image.size.height, self.challenge.image.size.width);
            NSLog(@"image height %f and width %f", cell.image.frame.size.height, cell.image.frame.size.width);
            NSLog(@"image cell height %f and width %f", cell.frame.size.height, cell.frame.size.width);
            return cell;
        }
        
    } else if (indexPath.row == 3) {
        ChallengeCommentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeCommentCell" forIndexPath:indexPath];
        NSLog(@"%@", self.challenge.comment);
        if (self.challenge.comment) {
            cell.openQuote.hidden = NO;
            cell.closeQuote.hidden = NO;
        } else {
            cell.openQuote.hidden = YES;
            cell.closeQuote.hidden = YES;
        }
        cell.comment.text = self.challenge.comment;
        return cell;
    } else if (indexPath.row == 4) {
        ChallengeButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeButtonCell" forIndexPath:indexPath];
        if (self.challenge.completed) {
            [cell.button setTitle:@"Edit" forState:UIControlStateNormal];
        }
        if (self.isChallengeDetail) {
            [cell.button setHidden:YES];
        } else {
            [cell.button setHidden:NO];
            [cell.button addTarget:self action:@selector(highlightButton:) forControlEvents:UIControlEventTouchDown];
            [cell.button addTarget:self action:@selector(unhighlightButton:) forControlEvents:UIControlEventTouchUpOutside];
            [cell.button addTarget:self action:@selector(updateButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        }
        return cell;
    }
    return nil;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"completeChallenge"]) {
        CompleteChallengeViewController *vc = [segue destinationViewController];
        vc.presenter = self;
        vc.challenge = _challenge;
    }
}

- (void)unhighlightButton:(UIButton *)sender {
    sender.backgroundColor = [UIColor clearColor];
    sender.layer.borderColor = [[UIColor whiteColor] CGColor];
}

- (void)highlightButton:(UIButton *)sender {
    sender.layer.borderColor = [UIColorFromRGB(0xFAC564) CGColor];
    sender.backgroundColor = UIColorFromRGB(0xFAC564);
}

- (void)updateButtonPressed:(UIButton *)sender {
    sender.backgroundColor = [UIColor clearColor];
    sender.layer.borderColor = [[UIColor whiteColor] CGColor];
    [self performSegueWithIdentifier:@"completeChallenge" sender:self];
}

- (void)updateCompletedDailyChallenge {
    [self.tableView reloadData];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
