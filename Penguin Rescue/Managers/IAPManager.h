//
//  IAPManager.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EBPurchase.h"

@interface IAPManager : NSObject <EBPurchaseDelegate> {

	EBPurchase* _ebPurchase;
	
	UIActivityIndicatorView* _loadingIndicator;
	
	__block void(^_purchaseSuccessCallback)(bool);
	__block void(^_requestSuccessCallback)(NSString*);
}

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SKProduct *selectedProduct;
-(void)clearSelectedProduct;
-(bool)purchase:(SKProduct*)product successCallback:(void(^)(bool))successCallback;
-(bool)requestProduct:(NSString*)productId successCallback:(void(^)(NSString*))successCallback;

@end
