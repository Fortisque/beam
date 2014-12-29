//
//  ChallengeViewController.h
//  An Apple A Day
//
//  Created by Kevin Casey on 12/24/14.
//  Copyright (c) 2014 ieor190. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>
#import <BuiltIO/BuiltIO.h>
#import <MediaPlayer/MediaPlayer.h>
#import "Global.h"

@interface ChallengeViewControllerOld : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *challengeInformation;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *completeButton;
@property (strong, nonatomic) IBOutlet UILabel *completedDescription;
@property (strong, nonatomic) IBOutlet UIImageView *completedImageView;
@property (strong, nonatomic) MPMoviePlayerController *player;
@property (strong, nonatomic) NSMutableDictionary *challenge;
@property (strong, nonatomic) NSMutableDictionary *challengePost;
@property (strong, nonatomic) Global *globalKeyValueStore;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

- (IBAction)logout:(id)sender;

- (void)activateView;
- (void)updateCompletedDailyChallengeWithProperties:(NSDictionary *)properties;

@end
