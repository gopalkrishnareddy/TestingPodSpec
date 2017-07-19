//
//  ViewController.m
//  JMC
//
//  Created by KXK0GKN on 7/10/17.
//  Copyright © 2017 nexteraenergy. All rights reserved.
//

#import "ViewController.h"
#import "JMC.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"JMC";
    [JMC setupJMCWithCustomAppFields:nil completionBlock:nil];

    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)showJMCFeedbackScreen:(id)sender {
    [self.navigationController pushViewController:[[JMC sharedInstance] viewControllerWithMode:JMCViewControllerModeCustom] animated:YES];

}

@end
