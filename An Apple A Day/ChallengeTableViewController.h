//
//  ChallengeTableViewController.h
//  An Apple A Day
//
//  Created by Gavin Chu on 12/28/14.
//  Copyright (c) 2014 ieor190. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Challenge.h"

@interface ChallengeTableViewController : UITableViewController

@property BOOL isHomePage;
@property (strong, nonatomic) Challenge *challenge;

@end
