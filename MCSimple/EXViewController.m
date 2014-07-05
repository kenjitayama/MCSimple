//
//  EXViewController.m
//  MCSimple
//
//  Created by Kenji Tayama on 7/5/14.
//  Copyright (c) 2014 Example. All rights reserved.
//

#import "EXViewController.h"

@interface EXViewController ()

@property (nonatomic, strong) NSMutableArray *peerIDs;

@property (weak, nonatomic) IBOutlet UISegmentedControl *peerModeSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *startSwitch;
@property (weak, nonatomic) IBOutlet UITableView *peersTableView;

@end


@implementation EXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = [UIDevice currentDevice].name;
    self.peerIDs = [NSMutableArray array];
    [self.peersTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (EXMCPeerMode)peerMode {
    return (self.peerModeSegmentedControl.selectedSegmentIndex == 0) ? EXMCPeerModeBrowser : EXMCPeerModeAdvertiser;
}


- (void)startSession {
    [[EXMCManager sharedManager] startWithPeerMode:[self peerMode]
                                           delegate:self];
}

#pragma mark - Actions

- (IBAction)startSwitchChanged:(id)sender {
    if ([sender isOn]) {
        [self startSession];
    } else {
        [[EXMCManager sharedManager] stop];
    }
}

- (IBAction)peerModeSegmentedControlChanged:(id)sender {
    if (self.startSwitch.on) {
        [self startSession];
    }
}


#pragma mark - UITableViewDatasource

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier
                                                            forIndexPath:indexPath];
    
    MCPeerID *peerID = self.peerIDs[indexPath.row];
    cell.textLabel.text = peerID.displayName;
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [self.peerIDs count];
}

#pragma mark - UITableViewDelegate


#pragma mark - EXMCDelegate

- (void)session:(MCSession *)session
 didReceiveData:(NSData *)data
       fromPeer:(MCPeerID *)peerID {
    LOG(@"%@ [session:didReceiveData:fromPeer:] peerID : %@, peerIDDispName : %@", [UIDevice currentDevice].name, peerID, peerID.displayName);
}

- (void)session:(MCSession *)session
           peer:(MCPeerID *)peerID
 didChangeState:(MCSessionState)state {
    
    LOG(@"%@ [session:peer:didChangeState:] peerID : %@, peerIDDispName : %@, state : %@",
        [UIDevice currentDevice].name,
        peerID,
        peerID.displayName,
        [[EXMCManager sharedManager] sessionStateString:state]);
    
    switch (state) {
        case MCSessionStateNotConnected: {
            if ([self.peerIDs containsObject:peerID]) {
                [self.peerIDs removeObject:peerID];
            }
            
            LOG(@"connectedPeers : %@", [EXMCManager sharedManager].currentSession.connectedPeers);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.peersTableView reloadData];
            });
            
            break;
        }
        case MCSessionStateConnecting: {
            break;
        }
        case MCSessionStateConnected: {
            if (![self.peerIDs containsObject:peerID]) {
                [self.peerIDs addObject:peerID];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.peersTableView reloadData];
            });
            
            break;
        }
        default: {
            break;
        }
    }
}


@end
