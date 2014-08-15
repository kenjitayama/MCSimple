//
//  EXMCManager.m
//  MCSimple
//
//  Created by Kenji Tayama on 7/5/14.
//  Copyright (c) 2014 Example. All rights reserved.
//

#import "EXMCManager.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

NSString *const kEXMCServiceType = @"kEXServiceType";
NSUInteger const kEXMCInvitetimeout = 30;

@interface EXMCManager ()

@property (nonatomic, strong) NSArray *mcSessionStateStrings;
@property (nonatomic, strong) NSArray *exMcPeerModeStrings;

@property (nonatomic, strong) MCPeerID *myPeerID;
@property EXMCPeerMode peerMode;

@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property BOOL advertising;
@property BOOL shouldStartAdvertisingOnFullDisconnection;

@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property BOOL browsing;

@property (nonatomic, strong) MCPeerID *browserPeerID;


@end

@implementation EXMCManager

static EXMCManager *_sharedManager = nil;

+ (EXMCManager *)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[EXMCManager alloc] init];
    });
    return _sharedManager;
}

- (id)init {
    self = [super init];
    if (self) {
        self.mcSessionStateStrings = @[
                                       @"MCSessionStateNotConnected",
                                       @"MCSessionStateConnecting",
                                       @"MCSessionStateConnected"
                                       ];
        self.exMcPeerModeStrings = @[
                                     @"EXMCPeerModeBrowser",
                                     @"EXMCPeerModeAdvertiser"
                                     ];
        
        
        self.advertising = NO;
        self.shouldStartAdvertisingOnFullDisconnection = NO;
        self.browsing = NO;
    }
    return self;
}


- (NSString *)sessionStateString:(MCSessionState)sessionState {
    return self.mcSessionStateStrings[sessionState];
}

- (NSString *)peerModeString:(EXMCPeerMode)peerMode {
    return self.exMcPeerModeStrings[peerMode];
}

- (NSString *)myDisplayName {
    return [UIDevice currentDevice].name;
}


#pragma mark - start/stop

- (void)stopNoBackgroundDispatch {
    self.shouldStartAdvertisingOnFullDisconnection = NO;
    if (self.currentSession) {
        [self.currentSession disconnect];
    }
    if (self.advertiser) {
        [self.advertiser stopAdvertisingPeer];
    }
    if (self.browser) {
        [self.browser stopBrowsingForPeers];
    }
    self.advertising = NO;
    self.browsing = NO;
    self.browserPeerID = NO;
}

- (void)stop {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self stopNoBackgroundDispatch];
    });
}

- (void)startWithPeerMode:(EXMCPeerMode)peerMode
                 delegate:(id)delegate {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    
        LOG(@"%@ [startWithPeerMode:delegate:] peerMode : %@", [self myDisplayName], [self peerModeString:peerMode]);

        self.delegate = delegate;
        
        [self stopNoBackgroundDispatch];
        
        self.peerMode = peerMode;
        
        switch (peerMode) {
            case EXMCPeerModeAdvertiser: {
                self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[self myDisplayName]];
                self.advertiser =[[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID
                                                                   discoveryInfo:[NSDictionary dictionary]
                                                                     serviceType:kEXMCServiceType];
                self.advertiser.delegate = self;
                [self.advertiser startAdvertisingPeer];
                self.advertising = YES;
                self.shouldStartAdvertisingOnFullDisconnection = NO;
                self.browserPeerID = nil;
                break;
            }
            case EXMCPeerModeBrowser: {
                self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[self myDisplayName]];
                self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID
                                                                serviceType:kEXMCServiceType];
                self.browser.delegate = self;
                [self.browser startBrowsingForPeers];
                self.browsing = YES;
                self.browserPeerID = self.myPeerID;
                break;
            }
            default: {
                break;
            }
        }
        
        self.currentSession = [[MCSession alloc] initWithPeer:self.myPeerID];
        self.currentSession.delegate = self;
    });
}


#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
didNotStartAdvertisingPeer:(NSError *)error {
    self.advertising = NO;
    self.shouldStartAdvertisingOnFullDisconnection = NO;
    NSString *msg = [NSString stringWithFormat:@"%@ [advertiser:didNotStartAdvertisingPeer:] error : %@", [self myDisplayName], error];
    LOG(@"%@", msg);
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:msg
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context
 invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    
    
    LOG(@"%@ [advertiser:didReceiveInvitationFromPeer:] peerID : %@, peerIDDispName : %@",
        [self myDisplayName],
        peerID,
        peerID.displayName);
    
    LOG(@"accepting invitation...");
    
    // Sause advertising and flag to resume advertising when disconnected from all peers (which means disconnected from browser).
    [self.advertiser stopAdvertisingPeer];
    self.advertising = NO;
    self.shouldStartAdvertisingOnFullDisconnection = YES;
    invitationHandler(YES, self.currentSession);
    self.browserPeerID = peerID;
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser
didNotStartBrowsingForPeers:(NSError *)error {
    self.browsing = NO;
    NSString *msg = [NSString stringWithFormat:@"%@ [browser:didNotStartBrowsingForPeers:] error : %@", [self myDisplayName], error];
    LOG(@"%@", msg);
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:msg
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
    self.browserPeerID = nil;
}


- (void)browser:(MCNearbyServiceBrowser *)browser
      foundPeer:(MCPeerID *)peerID
withDiscoveryInfo:(NSDictionary *)info {
    LOG(@"%@ [browser:foundPeer:withDiscoveryInfo:] peerID : %@, peerIDDispName : %@, info : %@", [self myDisplayName], peerID, peerID.displayName, info);
    LOG(@"%@ [browser:foundPeer:withDiscoveryInfo:] inviting %@...", [self myDisplayName], peerID.displayName);
    [browser invitePeer:peerID
              toSession:self.currentSession
            withContext:nil
                timeout:kEXMCInvitetimeout];
}

- (void)browser:(MCNearbyServiceBrowser *)browser
       lostPeer:(MCPeerID *)peerID {
    LOG(@"%@ [browser:lostPeer:] peerID : %@, peerIDDispName : %@", [self myDisplayName], peerID, peerID.displayName);
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session
 didReceiveData:(NSData *)data
       fromPeer:(MCPeerID *)peerID {
    LOG(@"%@ [session:didReceiveData:fromPeer:] peerID : %@, peerIDDispName : %@", [self myDisplayName], peerID, peerID.displayName);
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveData:fromPeer:)]) {
        [self.delegate session:session didReceiveData:data fromPeer:peerID];
    }
    
}

- (void)session:(MCSession *)session
didStartReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
   withProgress:(NSProgress *)progress {
    // not used
}

- (void)session:(MCSession *)session
didFinishReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
          atURL:(NSURL *)localURL
      withError:(NSError *)error {
    // not used
}

-  (void)session:(MCSession *)session
didReceiveStream:(NSInputStream *)stream
        withName:(NSString *)streamName
        fromPeer:(MCPeerID *)peerID {
    // not used
}

- (void)session:(MCSession *)session
           peer:(MCPeerID *)peerID
 didChangeState:(MCSessionState)state {
    
    LOG(@"%@ [session:peer:didChangeState:] peerID : %@, peerIDDispName : %@, state : %@", [self myDisplayName], peerID, peerID.displayName, [self sessionStateString:state]);
    
    switch (state) {
        case MCSessionStateNotConnected: {
            
            // Got disconnected from a browser
            if ([peerID isEqual:self.browserPeerID]) {
                self.browserPeerID = nil;
                
                // If I am a advertiser and got disconnected from a browser, disconnect from all
                if (self.peerMode == EXMCPeerModeAdvertiser && [session.connectedPeers count]) {
                    [session disconnect];
                }
            }

            // Restart advertising if necessary
            if (![session.connectedPeers count] && !self.advertising && self.shouldStartAdvertisingOnFullDisconnection) {
                [self startWithPeerMode:EXMCPeerModeAdvertiser
                               delegate:self.delegate];
            }
            break;
        }
        case MCSessionStateConnecting: {
            break;
        }
        case MCSessionStateConnected: {
            break;
        }
        default: {
            break;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(session:peer:didChangeState:)]) {
        [self.delegate session:session peer:peerID didChangeState:state];
    }
    
}

- (void)session:(MCSession *)session
didReceiveCertificate:(NSArray *)certificate
       fromPeer:(MCPeerID *)peerID
certificateHandler:(void (^)(BOOL accept))certificateHandler {
    LOG(@"%@ [session:didReceiveCertificate:fromPeer:] peerID : %@, peerIDDispName : %@",
        [self myDisplayName],
        peerID,
        peerID.displayName);
    certificateHandler(YES);
}



@end
