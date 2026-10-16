#import <XCTest/XCTest.h>
#import "AbstractHostsController.h"
#import "Hosts.h"
#import "CombinedHosts.h"
#import "HostsGroup.h"
#import <objc/runtime.h>

// Concrete subclass for testing (groupName would be nil on the abstract base)
@interface TestHostsController : AbstractHostsController
@property (nonatomic, copy) NSString *fixtureSystemPath;
@end

@implementation TestHostsController
- (NSString *)groupName { return @"TestGroup"; }
- (NSString *)systemHostsFilePath { return self.fixtureSystemPath; }
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

@end
