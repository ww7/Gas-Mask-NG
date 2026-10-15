//
//  NotificationHelper.m
//  Gas Mask
//
//  Created by Siim Raud on 16.11.12.
//  Copyright (c) 2012 Clockwise. All rights reserved.
//

#import "NotificationHelper.h"

@implementation NotificationHelper

+ (void)initNotificationCenter
{
    static NotificationHelper *delegate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        delegate = [NotificationHelper new];
        UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
        center.delegate = delegate;
        [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError *error) {
            if (error) {
                logError(@"Cannot authorize notifications: %@", error);
            }
        }];
    });
}

+ (void)notify:(NSString*)title message:(NSString*)message
{
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title ?: @"";
    content.body = message ?: @"";
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString
        content:content trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error) {
            logError(@"Cannot deliver notification: %@", error);
        }
    }];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
      willPresentNotification:(UNNotification *)notification
        withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
}

@end
