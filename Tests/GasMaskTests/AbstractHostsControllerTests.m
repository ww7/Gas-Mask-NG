#import <XCTest/XCTest.h>
#import "AbstractHostsController.h"
#import "Hosts.h"
#import "CombinedHosts.h"
#import "CombinedHostsController.h"
#import "HostsGroup.h"
#import <objc/runtime.h>
#import "PrivilegedActions.h"
#import <sys/acl.h>
#import <sys/stat.h>
#import <membership.h>

// Concrete subclass for testing (groupName would be nil on the abstract base)
@interface TestHostsController : AbstractHostsController
@property (nonatomic, copy) NSString *fixtureSystemPath;
@property (nonatomic, copy) void (^afterWrite)(void);
@end

@implementation TestHostsController
- (NSString *)groupName { return @"TestGroup"; }
- (NSString *)systemHostsFilePath { return self.fixtureSystemPath; }
- (BOOL)writeSystemContents:(NSString*)contents allowAuthorization:(BOOL)interactive
{
    BOOL result = [super writeSystemContents:contents allowAuthorization:interactive];
    if (self.afterWrite) self.afterWrite();
    return result;
}
@end

@interface TestCombinedController : CombinedHostsController
@property (nonatomic, copy) NSString *fixtureSystemPath;
@end
@implementation TestCombinedController
- (NSString*)systemHostsFilePath { return self.fixtureSystemPath; }
@end

static NSMutableArray<NSArray<NSString *> *> *launchedCommands;
static void recordTaskLaunch(NSTask *task, SEL selector) {
    [launchedCommands addObject:[@[task.launchPath ?: @""] arrayByAddingObjectsFromArray:task.arguments ?: @[]]];
}

@interface AbstractHostsControllerTests : XCTestCase
@property (nonatomic, strong) TestHostsController *controller;
@property (nonatomic, strong) NSString *tempDir;
@end

@implementation AbstractHostsControllerTests

- (void)setUp
{
    [super setUp];
    self.controller = [[TestHostsController alloc] init];
    self.tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"GasMaskTests"];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.tempDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    self.controller.fixtureSystemPath = [self.tempDir stringByAppendingPathComponent:@"system-hosts-fixture"];
    [@"initial" writeToFile:self.controller.fixtureSystemPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:self.tempDir error:NULL];
    [super tearDown];
}

// Helper: add a Hosts file with the given name to the controller
- (Hosts *)addHostsWithName:(NSString *)name
{
    NSString *path = [self.tempDir stringByAppendingPathComponent:
                      [name stringByAppendingPathExtension:HostsFileExtension]];
    [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    Hosts *hosts = [[Hosts alloc] initWithPath:path];
    [self.controller.hostsFiles addObject:hosts];
    return hosts;
}

#pragma mark - hostsGroup

- (void)testHostsGroupCreatedWithGroupName
{
    XCTAssertNotNil([self.controller hostsGroup]);
    XCTAssertEqualObjects([[self.controller hostsGroup] name], @"TestGroup");
}

#pragma mark - hostsExists:

- (void)testHostsExistsReturnsFalseWhenEmpty
{
    XCTAssertFalse([self.controller hostsExists:@"Anything"]);
}

- (void)testHostsExistsReturnsTrueForExistingName
{
    [self addHostsWithName:@"MyFile"];
    XCTAssertTrue([self.controller hostsExists:@"MyFile"]);
}

- (void)testHostsExistsReturnsFalseForDifferentName
{
    [self addHostsWithName:@"MyFile"];
    XCTAssertFalse([self.controller hostsExists:@"OtherFile"]);
}

#pragma mark - generateName:

- (void)testGenerateNameReturnsPrefixWhenUnique
{
    NSString *name = [self.controller generateName:@"New File"];
    XCTAssertEqualObjects(name, @"New File");
}

- (void)testGenerateNameAppendsNumberWhenNameExists
{
    [self addHostsWithName:@"New File"];
    NSString *name = [self.controller generateName:@"New File"];
    XCTAssertEqualObjects(name, @"New File 2");
}

- (void)testGenerateNameIncrementsUntilUnique
{
    [self addHostsWithName:@"New File"];
    [self addHostsWithName:@"New File 2"];
    NSString *name = [self.controller generateName:@"New File"];
    XCTAssertEqualObjects(name, @"New File 3");
}

#pragma mark - constructPath:withName:

- (void)testConstructPath
{
    NSString *path = [self.controller constructPath:@"/tmp/" withName:@"myfile"];
    XCTAssertEqualObjects(path, @"/tmp/myfile.hst");
}

#pragma mark - hostsFileByFileName:

- (void)testHostsFileByFileNameFound
{
    Hosts *hosts = [self addHostsWithName:@"Target"];
    Hosts *found = [self.controller hostsFileByFileName:@"Target.hst"];
    XCTAssertEqualObjects(found, hosts);
}

- (void)testHostsFileByFileNameNotFound
{
    [self addHostsWithName:@"Target"];
    Hosts *found = [self.controller hostsFileByFileName:@"Missing.hst"];
    XCTAssertNil(found);
}

#pragma mark - activeHostsFile

- (void)testActiveHostsFileReturnsNilWhenNoneActive
{
    [self addHostsWithName:@"A"];
    [self addHostsWithName:@"B"];
    XCTAssertNil([self.controller activeHostsFile]);
}

- (void)testActiveHostsFileReturnsActiveOne
{
    [self addHostsWithName:@"A"];
    Hosts *b = [self addHostsWithName:@"B"];
    [b setActive:YES];
    XCTAssertEqualObjects([self.controller activeHostsFile], b);
}

- (void)testRepeatedActiveSavesAndRestoreUseOnlyNoninteractiveCacheFlush
{
    Hosts *hosts = [self addHostsWithName:@"Profile"];
    [hosts setActive:YES];
    Method launch = class_getInstanceMethod([[NSTask new] class], @selector(launch));
    launchedCommands = [NSMutableArray new];
    IMP original = method_setImplementation(launch, (IMP)recordTaskLaunch);
    @try {
        for (int i = 0; i < 3; i++) {
            NSString *content = [NSString stringWithFormat:@"127.0.0.1 fixture-%d.example.test", i];
            [hosts setContents:content];
            [self.controller saveHosts:hosts];
            XCTAssertTrue([hosts saved]);
            XCTAssertEqualObjects([NSString stringWithContentsOfFile:self.controller.fixtureSystemPath encoding:NSUTF8StringEncoding error:NULL], [content stringByAppendingString:@"\n\n"]);
        }
        // Restore reads the saved profile on disk, not its unsaved editor buffer.
        NSString *onDisk = [hosts contentsOnDisk];
        [hosts setContents:@"unsaved buffer"];
        XCTAssertTrue([self.controller restoreHostsToOriginalLocation:hosts]);
        XCTAssertEqualObjects([NSString stringWithContentsOfFile:self.controller.fixtureSystemPath encoding:NSUTF8StringEncoding error:NULL], [onDisk stringByAppendingString:@"\n\n"]);
        XCTAssertEqual(launchedCommands.count, 0u);
        for (NSArray *command in launchedCommands) {
            XCTAssertEqualObjects(command, (@[@"/usr/bin/dscacheutil", @"-flushcache"]));
        }
        [hosts setActive:NO];
        [hosts setContents:@"local save"];
        [self.controller saveHosts:hosts];
        XCTAssertEqual(launchedCommands.count, 0u, @"Saving an inactive profile must not touch the system cache");
    } @finally {
        method_setImplementation(launch, original);
        launchedCommands = nil;
    }
}

- (void)testCombinedRestoreUsesSavedSourceTextAndOrder
{
    Hosts *source = [self addHostsWithName:@"source"];
    [source setContents:@"127.0.0.1 saved.test"];
    [source save];
    CombinedHosts *combined = [[CombinedHosts alloc] initWithPath:[self.tempDir stringByAppendingPathComponent:@"Combined.hst"] allHostsFiles:@[source]];
    [combined setHostsFiles:@[source]];
    [combined save];
    [source setContents:@"127.0.0.1 unsaved.test"];
    XCTAssertTrue([self.controller restoreHostsToOriginalLocation:combined]);
    NSString *actual = [NSString stringWithContentsOfFile:self.controller.fixtureSystemPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertTrue([actual containsString:@"saved.test"]);
    XCTAssertFalse([actual containsString:@"unsaved.test"]);
    XCTAssertFalse([actual containsString:@"Local/source"]);
}

- (void)testNewerCacheDuringApprovalRemainsPending
{
    Hosts *hosts = [self addHostsWithName:@"approval-race"];
    [hosts setContents:@"127.0.0.1 approved-snapshot.test"];
    [hosts save];
    self.controller.afterWrite = ^{
        [hosts setContents:@"127.0.0.1 newer-cache.test"];
        [hosts save];
    };
    XCTAssertTrue([self.controller activateHostsFile:hosts]);
    XCTAssertTrue(hosts.active);
    XCTAssertTrue(hosts.saved);
    XCTAssertTrue(hosts.systemApplyPending);
    NSString *actual = [NSString stringWithContentsOfFile:self.controller.fixtureSystemPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertTrue([actual containsString:@"approved-snapshot.test"]);
    XCTAssertFalse([actual containsString:@"newer-cache.test"]);
    XCTAssertTrue([[hosts contentsOnDisk] containsString:@"newer-cache.test"]);
    self.controller.afterWrite = nil;
    [self.controller saveHosts:hosts allowAuthorization:YES];
    XCTAssertTrue(hosts.saved);
    XCTAssertFalse(hosts.systemApplyPending);
}

- (void)testSourceRefreshNeverCommitsOrAppliesUnsavedCombinedOrder
{
    Hosts *first = [self addHostsWithName:@"first"];
    Hosts *second = [self addHostsWithName:@"second"];
    [first setContents:@"127.0.0.1 first.test"];[first save];
    [second setContents:@"127.0.0.1 second.test"];[second save];
    CombinedHosts *combined = [[CombinedHosts alloc] initWithPath:[self.tempDir stringByAppendingPathComponent:@"combined.hst"] allHostsFiles:@[first,second]];
    [combined setHostsFiles:@[first,second]];[combined save];[combined setActive:YES];
    NSString *savedIndex = [NSString stringWithContentsOfFile:combined.path encoding:NSUTF8StringEncoding error:nil];
    [combined setHostsFiles:@[second,first]];
    TestCombinedController *controller = [[TestCombinedController alloc] init];
    controller.fixtureSystemPath = self.controller.fixtureSystemPath;
    [controller.hostsFiles addObject:combined];
    [first setContents:@"127.0.0.2 refreshed.test"];[first save];
    [[NSNotificationCenter defaultCenter] postNotificationName:HostsFileSavedNotification object:first];
    XCTAssertFalse(combined.saved);
    XCTAssertEqualObjects([NSString stringWithContentsOfFile:combined.path encoding:NSUTF8StringEncoding error:nil],savedIndex);
    XCTAssertEqualObjects([[combined hostsFiles] firstObject],second);
    NSString *applied = [NSString stringWithContentsOfFile:controller.fixtureSystemPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertLessThan([applied rangeOfString:@"refreshed.test"].location,[applied rangeOfString:@"second.test"].location);
    XCTAssertFalse(combined.systemApplyPending);
}

- (void)testLegacyWriteACLRequiresExplicitPermissionRepair
{
    NSString *path = self.controller.fixtureSystemPath;
    XCTAssertEqual(chmod(path.fileSystemRepresentation,0644),0);
    XCTAssertFalse([PrivilegedActions fileNeedsPermissionRepairAtPath:path owner:getuid()]);
    acl_t acl=acl_init(1);acl_entry_t entry;uuid_t user;acl_permset_t permissions;
    XCTAssertEqual(acl_create_entry(&acl,&entry),0);
    XCTAssertEqual(mbr_uid_to_uuid(getuid(),user),0);
    XCTAssertEqual(acl_set_tag_type(entry,ACL_EXTENDED_ALLOW),0);
    XCTAssertEqual(acl_set_qualifier(entry,user),0);
    XCTAssertEqual(acl_get_permset(entry,&permissions),0);
    XCTAssertEqual(acl_add_perm(permissions,ACL_WRITE_DATA),0);
    XCTAssertEqual(acl_set_file(path.fileSystemRepresentation,ACL_TYPE_EXTENDED,acl),0);acl_free(acl);
    XCTAssertTrue([PrivilegedActions fileNeedsPermissionRepairAtPath:path owner:getuid()]);
    acl=acl_init(0);XCTAssertEqual(acl_set_file(path.fileSystemRepresentation,ACL_TYPE_EXTENDED,acl),0);acl_free(acl);
    XCTAssertFalse([PrivilegedActions fileNeedsPermissionRepairAtPath:path owner:getuid()]);
    XCTAssertEqual(chmod(path.fileSystemRepresentation,0666),0);
    XCTAssertTrue([PrivilegedActions fileNeedsPermissionRepairAtPath:path owner:getuid()]);
}

@end
