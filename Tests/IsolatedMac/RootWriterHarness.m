// Acceptance-only GUI client. Compiles the production PrivilegedActions unchanged.
// Never linked into the product. Refuses physical Macs and non-fixture guests.
#import <AppKit/AppKit.h>
#import <sys/sysctl.h>
#import "PrivilegedActions.h"

static NSString *mode;
static void record(NSDictionary *result) {
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
    [json writeToFile:[@"/private/var/tmp/gasmask-acceptance-" stringByAppendingFormat:@"%@.json",mode] atomically:YES];
}
@interface AcceptanceDelegate : NSObject <NSApplicationDelegate>
@property(strong) NSWindow *window;
@end
@implementation AcceptanceDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,580,140) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Gas Mask NG — Disposable VM Acceptance";
    NSTextField *label=[NSTextField wrappingLabelWithString:[@"Isolated root-writer check: " stringByAppendingString:mode]];
    label.frame=NSMakeRect(24,40,530,60);[self.window.contentView addSubview:label];
    [self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        NSString *first=@"127.0.0.1 localhost\n::1 localhost\n127.0.0.2 gasmask-fixture.invalid\n";
        NSError *backgroundError=nil;
        BOOL background=[PrivilegedActions writeHostsContents:first allowAuthorization:NO error:&backgroundError];
        BOOL refusedWithoutSession=!background && ![PrivilegedActions hasAuthorizedSession];
        BOOL originallyRepair=[PrivilegedActions systemFileNeedsPermissionRepair];
        NSError *error=nil;
        BOOL success=[PrivilegedActions writeHostsContents:first allowAuthorization:YES error:&error];
        NSMutableDictionary *result=[@{@"mode":mode,@"background_refused":@(refusedWithoutSession),
            @"success":@(success),@"error_code":@(error.code),@"error":error.localizedDescription ?: @"",
            @"session":@([PrivilegedActions hasAuthorizedSession]),@"repair_before":@(originallyRepair),
            @"repair_after":@([PrivilegedActions systemFileNeedsPermissionRepair])} mutableCopy];
        if(success && ![mode isEqualToString:@"cancel"] && ![mode isEqualToString:@"conflict"]) {
            NSString *second=[first stringByAppendingString:@"127.0.0.3 second-fixture.invalid\n"];
            NSError *secondError=nil;
            BOOL secondSuccess=[PrivilegedActions writeHostsContents:second allowAuthorization:NO error:&secondError];
            result[@"second_write_without_authorization"]=@(secondSuccess);
            result[@"exact_system_contents"]=@([[PrivilegedActions currentSystemContents] isEqualToString:second]);
        }
        record(result);
        if([mode isEqualToString:@"hold"] && success)return;
        [PrivilegedActions endSession];
        result[@"session_ended"]=@(![PrivilegedActions hasAuthorizedSession]);record(result);
        [NSApp terminate:nil];
    });
}
@end
int main(int argc,const char **argv) {
    @autoreleasepool {
        char model[128]={0};size_t size=sizeof model;
        if(sysctlbyname("hw.model",model,&size,NULL,0) || !strstr(model,"VirtualMac") ||
            ![[NSFileManager defaultManager] fileExistsAtPath:@"/private/var/tmp/gasmask-disposable-vm"] || getuid()==0)return 78;
        mode=argc>1 ? [NSString stringWithUTF8String:argv[1]] : @"approve";
        if(![@[@"approve",@"cancel",@"hold",@"conflict"] containsObject:mode])return 64;
        [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        AcceptanceDelegate *delegate=[AcceptanceDelegate new];NSApp.delegate=delegate;[NSApp run];
    }
    return 0;
}
