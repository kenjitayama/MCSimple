//
//  EXMCManager.h
//  MCSimple
//
//  Created by Kenji Tayama on 7/5/14.
//  Copyright (c) 2014 Example. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

typedef NS_ENUM(NSInteger, EXMCPeerMode) {
    EXMCPeerModeBrowser = 0,
    EXMCPeerModeAdvertiser,
};

UIKIT_EXTERN NSString *const kEXMCServiceType;
UIKIT_EXTERN NSUInteger const kEXMCInvitetimeout;

@protocol EXMCManagerDelegate <NSObject>

- (void)session:(MCSession *)session
 didReceiveData:(NSData *)data
       fromPeer:(MCPeerID *)peerID;

- (void)session:(MCSession *)session
           peer:(MCPeerID *)peerID
 didChangeState:(MCSessionState)state;

@optional
@end


@interface EXMCManager : NSObject <MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate>

@property (nonatomic, assign) id<EXMCManagerDelegate> delegate;
@property (nonatomic, strong) MCSession *currentSession;

+ (EXMCManager *)sharedManager;
- (NSString *)sessionStateString:(MCSessionState)sessionState;
- (void)stop;
- (void)startWithPeerMode:(EXMCPeerMode)peerMode
                 delegate:(id)delegate;

@end
