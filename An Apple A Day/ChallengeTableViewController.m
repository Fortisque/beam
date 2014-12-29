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
#import <BuiltIO/BuiltIO.h>
#import "Global.h"

@interface ChallengeTableViewController () <ChallengeButtonTableViewCellDelegate>

@end

@implementation ChallengeTableViewController

NSDateFormatter *dateFormatter;
Global *globalKeyValueStore;

- (void)viewDidLoad {
    [super viewDidLoad];
    //self.tableView.contentInset = UIEdgeInsetsMake(-64.0f, 0.0f, 0.0f, 0.0f); //hack to remove top space
    
    self.challenge = [[Challenge alloc] init];
    globalKeyValueStore = [Global globalClass];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"]; // using ISODate format so it will sort properly
    
    [self getChallengeForDay];
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
        
        [self.tableView reloadData];
    } onError:^(NSError *error, ResponseType type) {
        // query execution failed.
        // error.userinfo contains more details regarding the same
        NSLog(@"%@", @"ERROR");
        NSLog(@"%@", error.userInfo);
    }];
}

- (void)queryCompletedDailyChallenge {
    NSLog(@"queryCompletedDailyChallenge");
    // Make sure everything is set up first. This method gets called when we successfully login and when challenge
    // is successfully queried
    NSLog(@"uid: %@   useruid: %@", self.challenge.uid, [globalKeyValueStore getValueforKey:kBuiltUserUID]);
    if (self.challenge.uid && [globalKeyValueStore getValueforKey:kBuiltUserUID]) {
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
            } else {
                NSLog(@"completed");
                self.challenge.completed = YES;
                
                NSDictionary *builtResult = [builtResults objectAtIndex:0];
                NSLog(@"%@", builtResult);
                
                self.challenge.comment = [builtResult objectForKey:@"comment"];
                
                NSDictionary *file = [builtResult objectForKey:@"file"];
                if (file) {
                    NSString *fileUrl = [file objectForKey:@"url"];
                    NSURL *url = [NSURL URLWithString:fileUrl];
                    NSData *data = [NSData dataWithContentsOfURL:url];
                    if ([[file objectForKey:@"filename"] isEqualToString:@"image"]) {
                        UIImage *img = [[UIImage alloc] initWithData:data];
                        if (img != nil) {
                            self.challenge.image = img;
                        }
                    } else { // must be MOV file
                        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                        NSString *documentsDirectory = [paths objectAtIndex:0];
                        NSString *path = [documentsDirectory stringByAppendingPathComponent:@"tmp.mov"];
                        
                        NSData *videoData = [NSData dataWithContentsOfURL:url];
                        
                        [[NSFileManager defaultManager] createFileAtPath:path contents:videoData attributes:nil];
                        NSURL *moveUrl = [NSURL fileURLWithPath:path];
                        
                        self.challenge.videoUrl = moveUrl;
                    }
                }
                
                self.challenge.usersChallengesUID = [builtResult objectForKey:@"uid"];
                
                NSLog(@"completed challenge: %@", [self.challenge toString]);
                
                [self.tableView reloadData];
            }
        } onError:^(NSError *error, ResponseType type) {
            // query execution failed.
            // error.userinfo contains more details regarding the same
            NSLog(@"%@", @"ERROR");
            NSLog(@"%@", error.userInfo);
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
            return screenHeight*0.3;
        }
    } else if (indexPath.row == 1) {
        if (self.challenge.completed) {
            return screenHeight*0.5;
        } else {
            return screenHeight*0.7;
        }
    } else if (indexPath.row == 2) {
        if (self.challenge.completed) {
            return 300;
        } else {
            return 0;
        }
    } else if (indexPath.row == 3) {
        if (self.challenge.completed) {
            return 200;
        } else {
            return 0;
        }
    } else if (indexPath.row == 4) {
        if (self.challenge.completed) {
            return 60;
        } else {
            return 0;
        }
    }
    return 40;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        ChallengeHeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeHeaderCell" forIndexPath:indexPath];
        cell.dateLabel.text = self.challenge.date;
        return cell;
    } else if (indexPath.row == 1) {
        ChallengeInfoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeInfoCell" forIndexPath:indexPath];
        cell.title.text = @"Challenge Title";
        cell.info.text = self.challenge.info;
        if (self.challenge.completed) {
            cell.completeButton.hidden = YES;
        } else {
            cell.completeButton.hidden = NO;
            [cell.completeButton addTarget:self action:@selector(challengeButtonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
        }
        return cell;
    } else if (indexPath.row == 2) {
        ChallengeImageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeImageCell" forIndexPath:indexPath];
        cell.image.image = self.challenge.image;
        return cell;
    } else if (indexPath.row == 3) {
        ChallengeCommentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeCommentCell" forIndexPath:indexPath];
        cell.comment.text = self.challenge.comment;
        return cell;
    } else if (indexPath.row == 4) {
        ChallengeButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"challengeButtonCell" forIndexPath:indexPath];
        cell.delegate = self;
        return cell;
    }
    return nil;
}

- (IBAction)challengeButtonWasPressed:(UIButton *)sender {
    CompleteChallengeViewController *vc = [[CompleteChallengeViewController alloc] init];
    vc.presenter = self;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)updateCompletedDailyChallenge {
    
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
