//
//  HSKNetworkIntelligence.h
//  Handshake
//
//  Created by Ian Baird on 11/6/08.
//  Copyright 2008 Skorpiostech, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#include "miniupnpc.h"

enum 
{
    kHSKNetworkIntelligenceStateIdle = 0,
    kHSKNetworkIntelligenceStateDiscover,
    kHSKNetworkIntelligenceStateMapped
};
typedef NSUInteger HSKNetworkIntelligenceState;

@class HSKNetworkIntelligence;

@protocol HSKNetworkIntelligenceDelegate

@required
- (void)networkIntelligenceMappedPort:(HSKNetworkIntelligence *)sender externalPort:(NSNumber *)port externalAddress:(NSString *)dottedQuad;

@end


@interface HSKNetworkIntelligence : NSObject 
{
    NSTimer *statusPollTimer;
    
    NSArray *lastLocalAddrs;
    
    id <HSKNetworkIntelligenceDelegate> delegate;
    
    HSKNetworkIntelligenceState niState;
}

@property(nonatomic, assign) id <HSKNetworkIntelligenceDelegate> delegate;

+ (NSArray*)localAddrs;

+ (id)sharedInstance;

- (void)startMonitoring;
- (void)stopMonitoring;

@end