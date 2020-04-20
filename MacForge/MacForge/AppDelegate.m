//
//  AppDelegate.m
//  MacForge
//
//  Created by Wolfgang Baird on 1/9/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

#import "AppDelegate.h"

NSDictionary *testing;

AppDelegate* myDelegate;

NSWindow *mySHeet;

NSMutableArray *allLocalPlugins;
NSMutableArray *allReposPlugins;
NSMutableArray *allRepos;

NSMutableDictionary *myPreferences;
NSMutableArray *pluginsArray;

NSMutableDictionary *installedPluginDICT;
NSMutableDictionary *needsUpdate;

NSMutableArray *confirmDelete;

NSArray *sourceItems;
NSArray *discoverItems;
Boolean isdiscoverView = true;

NSDate *appStart;

NSButton *selectedView;

NSMutableDictionary *myDict;
NSUserDefaults *sharedPrefs;
NSDictionary *sharedDict;

@implementation AppDelegate

NSUInteger osx_ver;
NSArray *tabViewButtons;
NSArray *tabViews;
Boolean showBundleOnOpen;
Boolean appSetupFinished = false;


- (void)searchFieldDidEndSearching:(NSSearchField *)sender {
    [_searchPlugins abortEditing];
}

- (void)controlTextDidChange:(NSNotification *)obj{
//    NSLog(@"%@", obj);
//    NSLog(@"----- test ----- %@", [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.alexbeals.swag"].absoluteString);
    NSView *v = [tabViews objectAtIndex:[tabViewButtons indexOfObject:_viewSources]];
    if (![_tabMain.subviews isEqualToArray:@[v]])
        [myDelegate selectView:_viewSources];

    NSView *myview = myDelegate.tabMain.subviews.firstObject;
    NSArray *sv = myview.subviews;
    NSSearchField *sf;
    NSTableView *tv;
    if (sv.count > 3) {
        sf = sv[3];
        tv = [(NSView*)sv[2] subviews].firstObject.subviews.firstObject.subviews.firstObject;
        [sf setStringValue:_searchPlugins.stringValue];
        [tv controlTextDidChange:obj];
//        NSLog(@"%@", [(NSView*)sv[2] subviews].firstObject.subviews.firstObject.subviews);
    }
//        [myview controlTextDidChange:obj];
//    if ([_searchPlugins.stringValue isEqualToString:@""])
//        [_searchPlugins abortEditing];
//    NSLog(@"%@", _searchPlugins.stringValue);
}

- (void)movePreviousPurchases {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    
    // Probably should have some error checking
    
    NSString *MF_SupportDirectory = [NSString stringWithFormat:@"%@/MacForge", applicationSupportDirectory];
    NSString *PV_SupportDirectory = [NSString stringWithFormat:@"%@/purchaseValidationApp", applicationSupportDirectory];
//    NSLog(@"applicationSupportDirectory: '%@'", applicationSupportDirectory);
    for (NSString *file in [FileManager contentsOfDirectoryAtPath:MF_SupportDirectory error:nil]) {
//        NSLog(@"file: '%@'", file);
        NSString *transferedLicensePath = [NSString stringWithFormat:@"%@/%@", PV_SupportDirectory, file];
        if (![FileManager fileExistsAtPath:transferedLicensePath]) {
            
            NSLog(@"file: '%@'", file);

            NSString *ogLicensePath = [NSString stringWithFormat:@"%@/%@", MF_SupportDirectory, file];
            [FileManager copyItemAtPath:ogLicensePath toPath:transferedLicensePath error:nil];
        }
    }
}

// Shared instance
+ (AppDelegate*) sharedInstance {
    static AppDelegate* myDelegate = nil;
    
    if (myDelegate == nil)
        myDelegate = [[AppDelegate alloc] init];
    
    return myDelegate;
}

// Run bash script
- (NSString*) runCommand: (NSString*)command {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    NSArray *arguments = [NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@", command], nil];
    [task setArguments:arguments];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}

// Cleanup some stuff when user changes dark mode
- (void)systemDarkModeChange:(NSNotification *)notif {
    if (selectedView != nil)
        [self selectView:selectedView];
    
    if (osx_ver >= 14) {
        if (notif == nil) {
            // Need to fix for older versions of macos
            if ([NSApp.effectiveAppearance.name isEqualToString:NSAppearanceNameAqua]) {
                [_changeLog setTextColor:[NSColor blackColor]];
            } else {
                [_changeLog setTextColor:[NSColor whiteColor]];
            }
        } else {
            NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            if ([osxMode isEqualToString:@"Dark"]) {
                [_changeLog setTextColor:[NSColor whiteColor]];
            } else {
                [_changeLog setTextColor:[NSColor blackColor]];
            }
        }
    }
}

// Startup
- (instancetype)init {
    myDelegate = self;
    appStart = [NSDate date];
    osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    return self;
}

// Quit when window closed
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

// Handle macforge:// url scheme
- (void)application:(NSApplication *)application
           openURLs:(NSArray<NSURL *> *)urls {
//    NSLog(@"------------- %@", urls);
    NSLog(@"zzt aourls ------------- %@", [NSDate date]);
    
    // Convert urls to paths
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    for (NSURL *url in urls)
        if ([FileManager fileExistsAtPath:url.path])
            [paths addObject:url.path];
    
    // If there are any paths try installing them
    if (paths.count > 0)
        [PluginManager.sharedInstance installBundles:paths];

    // Handle requests to open to specific plugin
    if ([urls.lastObject.absoluteString containsString:@"macforge://"]) {
        [MSAnalytics trackEvent:@"macforge://" withProperties:@{@"Product ID" : urls.lastObject.lastPathComponent}];
        
        NSURL *t = urls.lastObject;
        MSPlugin *p = [[MSPlugin alloc] init];
        pluginData *data = pluginData.sharedInstance;
        NSString *repo = t.URLByDeletingLastPathComponent.absoluteString;
        NSMutableString *test = [[NSMutableString alloc] initWithString:repo];
        [test deleteCharactersInRange:NSMakeRange([repo length]-1, 1)];
        if (repo.length >= 8)
            [test replaceCharactersInRange:NSMakeRange(0, 8) withString:@"https"];
        repo = test.copy;        
        
        if ([data.repoPluginsDic objectForKey:t.lastPathComponent]) {
            p = [data.repoPluginsDic objectForKey:t.lastPathComponent];
            
            NSLog(@"zzt aourls ------------- data.repoPluginsDic objectForKey:t.lastPathComponent ------------- %@", p.webName);
        } else {
            if ([data.sourceListDic.allKeys containsObject:repo]) {
    //            NSLog(@"------------ repo exists %@", data.repoPluginsDic);
                p = [data.repoPluginsDic objectForKey:t.lastPathComponent];
                
                NSLog(@"zzt aourls ------------- data.sourceListDic.allKeys containsObject:repo ------------- %@", p.webName);
            } else {
    //            NSLog(@"------------ new repo %@", data.repoPluginsDic);

                // should we ask user to add repo?
                [data fetch_repo:repo];
                p = [data.repoPluginsDic objectForKey:t.lastPathComponent];
                
                if (!p) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [data fetch_repo:repo];
                        dispatch_async(dispatch_get_main_queue(), ^(void){
                            if ([data.repoPluginsDic objectForKey:t.lastPathComponent])
                                pluginData.sharedInstance.currentPlugin = [data.repoPluginsDic objectForKey:t.lastPathComponent];
                            NSLog(@"zzt aourls ------------- data fetch_repo:repo ------------- %@", repo);
                            NSLog(@"zzt aourls ------------- data fetch_repo:repo ------------- %@", pluginData.sharedInstance.currentPlugin);
                        });
                    });
                }
                
                NSLog(@"zzt aourls ------------- data fetch_repo:repo ------------- %@", data.repoPluginsDic.allKeys);
            }
        }
        
        NSLog(@"zzt aourls ------------- %@", p.webPlist);

        if (appSetupFinished) {
            [myDelegate showLink:p];
        } else {
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                // Wait for the app to finish launching
                while (!appSetupFinished)
                    [NSThread sleepForTimeInterval:1.0f];
                [myDelegate showLink:p];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    
                });
            });
        }
    }
}

- (void)showLink:(MSPlugin*)p {
    if (p) {
            showBundleOnOpen = true;
            [myDelegate selectView:_viewDiscover];
            pluginData.sharedInstance.currentPlugin = p;
    //        p.webRepository = repo;
            NSView *v = myDelegate.sourcesBundle;
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [v setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
                [v setFrame:myDelegate.tabMain.frame];
                [v setFrameOrigin:NSMakePoint(0, 0)];
                [v setTranslatesAutoresizingMaskIntoConstraints:true];
                [myDelegate.tabMain setSubviews:[NSArray arrayWithObject:v]];
            });
    //        NSLog(@"------------ test %@", repo);
    //        NSLog(@"%@", data.sourceListDic.allKeys);
    } else {
        showBundleOnOpen = false;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
//    [MSCrashes generateTestCrash];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(systemDarkModeChange:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"com.w0lf.MacForgeNotify"
                                                                 object:nil
                                                                  queue:nil
                                                             usingBlock:^(NSNotification *notification)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([notification.object isEqualToString:@"prefs"]) [self selectView:self->_viewPreferences];
            if ([notification.object isEqualToString:@"about"]) [self selectView:self->_viewAbout];
            if ([notification.object isEqualToString:@"manage"]) [self selectView:self->_viewPlugins];
            if ([notification.object isEqualToString:@"update"]) [self selectView:self->_viewChanges];
            if ([notification.object isEqualToString:@"check"]) { [PluginManager.sharedInstance checkforPluginUpdates:nil :self->_viewUpdateCounter]; }
        });
    }];

    // Loop looking for bundle updates
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [PluginManager.sharedInstance checkforPluginUpdates:nil :self->_viewUpdateCounter];
    });

    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count > 1) {
        if ([args containsObject:@"prefs"]) [self selectView:_viewPreferences];
        if ([args containsObject:@"about"]) [self selectView:_viewAbout];
        if ([args containsObject:@"manage"]) [self selectView:_viewPlugins];
        if ([args containsObject:@"update"]) [self selectView:_viewChanges];
    }

    [self installXcodeTemplate];
    
    // Lets try it with a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (showBundleOnOpen == true) {
            [myDelegate selectView:self->_viewDiscover];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self setViewSubView:myDelegate.tabMain :myDelegate.sourcesBundle];
            });
        }
    });

    appSetupFinished = true;
        
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:appStart];
    NSLog(@"Launch time : %f Seconds", executionTime);
}

- (void)executionTime:(NSString*)s {
    SEL sl = NSSelectorFromString(s);
    NSDate *startTime = [NSDate date];
    if ([self respondsToSelector:sl])
        ((void (*)(id, SEL))[self methodForSelector:sl])(self, sl);
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:startTime];
    NSLog(@"%@ execution time : %f Seconds", s, executionTime);
}

// Loading
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    // Start alanlytics and crash reporting
    [MSAppCenter start:@"ffae4e14-d61c-4078-825c-bb4635407861" withServices:@[
      [MSAnalytics class],
      [MSCrashes class]
    ]];
    
    [MSAnalytics trackEvent:@"Application Launching"];
    
    // Crash on exceptions?
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"NSApplicationCrashOnExceptions": [NSNumber numberWithBool:true]}];
    
    /* Configure Firebase */
    [FIRApp configure];
    
    /* Setup our handler for Authenthication events */
    [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *_Nonnull auth, FIRUser *_Nullable user) {
        self->_user = user;
        
        [self updateUserButtonWithUser:user andAuth:auth];
        
        /* Update the Under Construction view's login/logout button */
        self->_signInOrOutButton.title = (self->_user) ? @"Sign Out" : @"Sign In";
        
        if (user)
            [self setViewSubView:self.tabAccount :self.tabAccountPurchases];
        else
            [self setViewSubView:self.tabAccount :self.tabAccountRegister];
    }];
    
    /* Get signed-in user */
    _user = [FIRAuth auth].currentUser;
    
    /* Check if there actually is someone signed-in */
    if (_user) {
        NSLog(@"Current signed-in user id: %@", _user.uid);
    } else {
        NSLog(@"No user signed-in.");
    }
    
    sourceItems = [NSArray arrayWithObjects:_sourcesURLS, _sourcesPlugins, _sourcesBundle, nil];
    discoverItems = [NSArray arrayWithObjects:_discoverChanges, _sourcesBundle, nil];

    [_sourcesPush setEnabled:true];
    [_sourcesPop setEnabled:false];
    myPreferences = [self getmyPrefs];
    
    // Make sure default sources are in place
    NSArray *defaultRepos = @[@"https://github.com/w0lfschild/myRepo/raw/master/mytweaks",
                              @"https://github.com/w0lfschild/myRepo/raw/master/myPaidRepo",
                              @"https://github.com/w0lfschild/macplugins/raw/master"];
    
//    NSArray *defaultRepos = @[@"https://github.com/w0lfschild/myRepo/raw/master/myPaidRepo"];
    
    NSMutableArray *newArray = [NSMutableArray arrayWithArray:[myPreferences objectForKey:@"sources"]];
    for (NSString *item in defaultRepos)
        if (![[myPreferences objectForKey:@"sources"] containsObject:item])
            [newArray addObject:item];
    [[NSUserDefaults standardUserDefaults] setObject:newArray forKey:@"sources"];
    [myPreferences setObject:newArray forKey:@"sources"];

    [_sourcesRoot setSubviews:[[NSArray alloc] initWithObjects:_discoverChanges, nil]];
    
    [self executionTime:@"updateAdButton"];
    [self executionTime:@"tabs_sideBar"];
    [self executionTime:@"setupWindow"];
    [self executionTime:@"setupPrefstab"];
    [self executionTime:@"addLoginItem"];
    [self executionTime:@"launchHelper"];
    [self executionTime:@"movePreviousPurchases"];
    
//    [FIRApp configure];
//    [self executionTime:@"fireBaseSetup"];
    
    // Setup plugin table
    [_tblView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [_blackListTable registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

    [self setupEventListener];
    [self executionTime:@"setupSIMBLview"];
    
    [_window makeKeyAndOrderFront:self];
    
    [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(keepThoseAdsFresh) userInfo:nil repeats:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    });
    
    // Make sure we're in /Applications
    PFMoveToApplicationsFolderIfNecessary();
}

// Cleanup
- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    [MSAnalytics trackEvent:@"Application Closing"];
}

- (NSMutableDictionary *)getmyPrefs {
    return [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}

// Setup sidebar
- (void)tabs_sideBar {
    NSInteger height = 42;
    
    tabViewButtons = [NSArray arrayWithObjects:_viewDiscover, _viewPlugins, _viewSources, _viewChanges, _viewSystem, _viewAbout, _viewPreferences, _viewAccount, nil];
    NSArray *topButtons = [NSArray arrayWithObjects:_viewDiscover, _viewApps, _viewPlugins, _viewSources, _viewChanges, _viewSystem, _viewAbout, _viewPreferences, nil];
    NSUInteger yLoc = _window.frame.size.height - 96 - height;
    for (NSButton *btn in topButtons) {
        if (btn.enabled) {
            NSRect newFrame = [btn frame];
            newFrame.origin.x = 0;
            newFrame.origin.y = yLoc;
            newFrame.size.height = 42;
            yLoc -= height;
            [btn setFrame:newFrame];
            [btn setWantsLayer:YES];
            [btn setTarget:self];
        } else {
            btn.hidden = true;
        }
    }
        
    [_viewUpdateCounter setFrameOrigin:CGPointMake(_viewChanges.frame.origin.x + _viewChanges.frame.size.width * .6,
                                                   _viewChanges.frame.origin.y + _viewChanges.frame.size.height * .5 - _viewUpdateCounter.frame.size.height * .5)];
    
    for (NSButton *btn in tabViewButtons)
        [btn setAction:@selector(selectView:)];
    
    NSButton *btn = _viewAccount;
    [btn setWantsLayer:YES];
    [btn setTarget:self];
    [btn setAction:@selector(selectView:)];
    _imgAccount.image = [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].image;
    _viewAccount.title = [NSString stringWithFormat:@"                    %@", [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].fullName];
    [_imgAccount setWantsLayer: YES];
    _imgAccount.layer.cornerRadius = _imgAccount.layer.frame.size.height/2;
    _imgAccount.layer.masksToBounds = YES;
    _imgAccount.animates = YES;
    
    NSArray *bottomButtons = [NSArray arrayWithObjects:_buttonDiscord, _buttonReddit, _buttonDonate, _buttonAdvert, _buttonReport, nil];
    NSMutableArray *visibleButons = [[NSMutableArray alloc] init];
    for (NSButton *btn in bottomButtons)
        if (![btn isHidden])
            [visibleButons addObject:btn];
    bottomButtons = [visibleButons copy];
    
    height = 30;
    yLoc = ([bottomButtons count] - 1) * (height - 1) + 80;
    for (NSButton *btn in bottomButtons) {
        if (btn.enabled) {
            [btn setFont:[NSFont fontWithName:btn.font.fontName size:14]];
            NSRect newFrame = [btn frame];
            newFrame.size.height = height;
            newFrame.origin.x = 0;
            newFrame.origin.y = yLoc;
            yLoc -= (height - 1);
            [btn setFrame:newFrame];
            [btn setAutoresizingMask:NSViewMaxYMargin];
            [btn setWantsLayer:YES];
        } else {
            btn.hidden = true;
        }
    }
}

- (void)byeSIP {
    exit(0);
}

- (void)restartSIP {
    system("osascript -e 'tell application \"Finder\" to restart'");
}

- (void)closeSIP {
    [_window endSheet:mySHeet];
}

- (void)checkSIP {
    if (![MacForgeKit SIP_HasRequiredFlags]) {
        NSString *frameworkBundleID = @"org.w0lf.MacForgeKit";
        NSBundle *frameworkBundle = [NSBundle bundleWithIdentifier:frameworkBundleID];
        MFKSipView *p = [[MFKSipView alloc] initWithNibName:@"MFKSipView" bundle:frameworkBundle];
        NSView *view = p.view;
                
        [p.confirmQuit setTarget:self];
        [p.confirmQuit setAction:@selector(byeSIP)];
        [p.confirmReboot setTarget:self];
        [p.confirmReboot setAction:@selector(restartSIP)];
        [p.confirm setTarget:self];
        [p.confirm setAction:@selector(closeSIP)];
        
        mySHeet = [[NSWindow alloc] initWithContentRect:[view frame] styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
        [mySHeet setContentView:view];
        [_window beginSheet:mySHeet completionHandler:^(NSModalResponse returnCode) {
            
        }];
    }
}

- (void)setupWindow {
    [_window setTitle:@""];
    [_window setMovableByWindowBackground:YES];
    
//    NSLog(@"%@",[FileManager attributesOfItemAtPath:@"/Library/Application Support/MacEnhance/Plugins" error:nil]);
    
    [self executionTime:@"checkSIP"];
    
    [_window setTitlebarAppearsTransparent:true];
    [_window setTitleVisibility:NSWindowTitleHidden];
    [_window setStyleMask:_window.styleMask|NSWindowStyleMaskFullSizeContentView];
    
    [self simbl_blacklist];
    
    // Add blurred background if NSVisualEffectView exists
    Class vibrantClass=NSClassFromString(@"NSVisualEffectView");
    if (vibrantClass) {
        NSVisualEffectView *vibrant=[[vibrantClass alloc] initWithFrame:[[_window contentView] bounds]];
        [vibrant setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [vibrant setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [vibrant setState:NSVisualEffectStateActive];
        [[_window contentView] addSubview:vibrant positioned:NSWindowBelow relativeTo:nil];
    } else {
        [_window setBackgroundColor:[NSColor whiteColor]];
    }
    
    [_window.contentView setWantsLayer:YES];
    
    NSBox *vert = [[NSBox alloc] initWithFrame:CGRectMake(_viewPlugins.frame.size.width - 1, 0, 1, _window.frame.size.height)];
    [vert setBoxType:NSBoxSeparator];
    [vert setAutoresizingMask:NSViewHeightSizable];
    [_window.contentView addSubview:vert];
    
    tabViews = [NSArray arrayWithObjects:_tabFeatured, _tabPlugins, _tabSources, _tabUpdates, _tabSystemInfo, _tabAbout, _tabPreferences, _tabAccount, nil];
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [_appVersion setStringValue:[NSString stringWithFormat:@"Version %@ (%@)",
                                 [infoDict objectForKey:@"CFBundleShortVersionString"],
                                 [infoDict objectForKey:@"CFBundleVersion"]]];
    if ([[[NSString stringWithFormat:@"%@", [infoDict objectForKey:@"CFBundleShortVersionString"]] substringToIndex:1] isEqualToString:@"0"]) {
        [_appName setStringValue:[NSString stringWithFormat:@"%@ BETA", [infoDict objectForKey:@"CFBundleExecutable"]]];
    } else {
        [_appName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    NSString * currentYEAR = [formatter stringFromDate:[NSDate date]];
    [_appCopyright setStringValue:[NSString stringWithFormat:@"Copyright © 2015 - %@ macEnhance", currentYEAR]];
        
    NSString *path = [[[NSBundle mainBundle] URLForResource:@"CHANGELOG" withExtension:@"md"] path];
    CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
    CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
    [_changeLog.textStorage setAttributedString:asr.render];
    
    [self systemDarkModeChange:nil];
    [self selectView:_viewDiscover];
    
    [_prefStartTab selectItemAtIndex:0];
}

- (void)addLoginItem {
    NSBundle *helperBUNDLE = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/Contents/Library/LoginItems/MacForgeHelper.app", [[NSBundle mainBundle] bundlePath]]];
    [helperBUNDLE enableLoginItem];
}

- (IBAction)toggleLoginItem:(NSButton*)sender {
    NSBundle *helperBUNDLE = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/Contents/Library/LoginItems/MacForgeHelper.app", [[NSBundle mainBundle] bundlePath]]];
    if (sender.state == NSOnState){
        [helperBUNDLE enableLoginItem];
    } else {
        [helperBUNDLE disableLoginItem];
    }
}

- (void)launchHelper {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Path to MacForgeHelper
        NSString *path = [NSString stringWithFormat:@"%@/Contents/Library/LoginItems/MacForgeHelper.app", [[NSBundle mainBundle] bundlePath]];

        // Launch helper if it's not open
        //    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.w0lf.MacForgeHelper"].count == 0)
        //        [[NSWorkspace sharedWorkspace] launchApplication:path];

        // Always relaunch in developement
        for (NSRunningApplication *run in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.w0lf.MacForgeHelper"])
            [run terminate];
        
        // Seems to need to run on main thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [Workspace launchApplication:path];
            [[NSRunningApplication currentApplication] performSelector:@selector(activateWithOptions:) withObject:[NSNumber numberWithUnsignedInteger:NSApplicationActivateIgnoringOtherApps] afterDelay:0.0];
        });
    });
}

//- (IBAction)pref_setBeta:(NSButton*)sender {
//    Boolean isBeta = [sender state];
//    [Defaults setObject:[NSNumber numberWithBool:isBeta] forKey:@"SUUpdaterChecksForBetaUpdates"];
//    [Defaults synchronize];
//}

- (void)setupPrefstab {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObjects:@"-c",@"sw_vers -buildVersion",nil]];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    unichar ch = [result characterAtIndex:result.length - 1];
    BOOL isBeta = [[NSCharacterSet letterCharacterSet] characterIsMember: ch];
    
    if (isBeta) {
        NSLog(@"Beta OS Detected");
        [Defaults setObject:[NSNumber numberWithBool:true] forKey:@"SUUpdaterChecksForBetaUpdates"];
        [Defaults synchronize];
        [_prefUpdateBeta setEnabled:false];
    } else {
//        Boolean betaUpdates = [Defaults boolForKey:@"SUUpdaterChecksForBetaUpdates"];
//        [_prefUpdateBeta setState:betaUpdates];
//        [self pref_setBeta:_prefUpdateBeta];
    }
    
    NSString *plist = [NSString stringWithFormat:@"%@/Library/Preferences/net.culater.SIMBL.plist", NSHomeDirectory()];
    NSUInteger logLevel = [[[NSDictionary dictionaryWithContentsOfFile:plist] objectForKey:@"SIMBLLogLevel"] integerValue];
    [_SIMBLLogging selectItemAtIndex:logLevel];
    [_prefDonate setState:[[myPreferences objectForKey:@"prefDonate"] boolValue]];
    [_prefTips setState:[[myPreferences objectForKey:@"prefTips"] boolValue]];
    [_prefWindow setState:[[myPreferences objectForKey:@"prefWindow"] boolValue]];
    [_prefHideMenubar setState:[[myPreferences objectForKey:@"prefHideMenubar"] boolValue]];

    if ([[myPreferences objectForKey:@"prefWindow"] boolValue])
        [_window setFrameAutosaveName:@"MainWindow"];

    if ([[myPreferences objectForKey:@"prefTips"] boolValue]) {
        NSToolTipManager *test = [NSToolTipManager sharedToolTipManager];
        [test setInitialToolTipDelay:0.1];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SUAutomaticallyUpdate"]) {
        [_prefUpdateAuto selectItemAtIndex:2];
        [_updater checkForUpdatesInBackground];
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SUEnableAutomaticChecks"]) {
        [_prefUpdateAuto selectItemAtIndex:1];
        [_updater checkForUpdatesInBackground];
    } else {
        [_prefUpdateAuto selectItemAtIndex:0];
    }

    [_prefUpdateInterval selectItemWithTag:[[myPreferences objectForKey:@"SUScheduledCheckInterval"] integerValue]];

    NSImage *img = [NSImage imageNamed:@"github"];
    [img setTemplate:true];
    [_gitButton setImage:img];
    
    img = [NSImage imageNamed:@"reddit"];
    [img setTemplate:true];
    [_emailButton setImage:img];
    
    img = [NSImage imageNamed:@"code"];
    [img setTemplate:true];
    [_sourceButton setImage:img];
    
    img = [NSImage imageNamed:@"tools"];
    [img setTemplate:true];
    [_xCodeButton setImage:img];
    
    [[_gitButton cell] setImageScaling:NSImageScaleProportionallyDown];
    [[_sourceButton cell] setImageScaling:NSImageScaleProportionallyDown];
    [[_emailButton cell] setImageScaling:NSImageScaleProportionallyDown];
    [[_xCodeButton cell] setImageScaling:NSImageScaleProportionallyDown];
    [[_webButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    
    [_sourceButton setAction:@selector(visitSource)];
    [_gitButton setAction:@selector(visitGithub)];
    [_webButton setAction:@selector(visitWebsite)];
    [_emailButton setAction:@selector(sendEmail)];
}

- (void)installXcodeTemplate {
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        if ([Workspace absolutePathForAppBundleWithIdentifier:@"com.apple.dt.Xcode"].length > 0) {
            NSString *localPath = [NSBundle.mainBundle pathForResource:@"plugin_template" ofType:@"zip"];
            NSString *installPath = [FileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject.path;
            installPath = [NSString stringWithFormat:@"%@/Developer/Xcode/Templates/Project Templates/MacForge", installPath];
            NSString *installFile = [NSString stringWithFormat:@"%@/MacForge plugin.xctemplate", installPath];
            if (![FileManager fileExistsAtPath:installFile]) {
                // Make intermediaries
                NSError *err;
                [FileManager createDirectoryAtPath:installPath withIntermediateDirectories:true attributes:nil error:&err];
                NSLog(@"%@", err);
                
                // unzip our plugin demo project
                NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/unzip" arguments:@[@"-o", localPath, @"-d", installPath]];
                [task waitUntilExit];
                if ([task terminationStatus] == 0) {
                    // Yay
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^(void){
        });
    });
}

- (IBAction)startCoding:(id)sender {
    // Open a test plugin for the user
    NSString *localPath = [NSBundle.mainBundle pathForResource:@"demo_xcode" ofType:@"zip"];
    NSString *installPath = [NSURL fileURLWithPath:[NSHomeDirectory()stringByAppendingPathComponent:@"Desktop"]].path;
    installPath = [NSString stringWithFormat:@"%@/MacForge_plugin_demo", installPath];
    NSString *installFile = [NSString stringWithFormat:@"%@/test.xcodeproj", installPath];
    if ([FileManager fileExistsAtPath:installFile]) {
        // Open the project if it exists
        [Workspace openFile:installFile];
    } else {
        // unzip our plugin demo project
        NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/unzip" arguments:@[@"-o", localPath, @"-d", installPath]];
        [task waitUntilExit];
        if ([task terminationStatus] == 0) {
            // presumably the only case where we've successfully installed
            [Workspace openFile:installFile];
        }
    }
}

- (IBAction)donate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://goo.gl/DSyEFR"]];
}

- (IBAction)report:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/MacForge/issues/new/choose"]];
}

- (void)sendEmail {
    [self visitReddit];
//    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:aguywithlonghair@gmail.com"]];
}

- (IBAction)visitReddit:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.reddit.com/r/OSXTweaks"]];
}

- (IBAction)visitDiscord:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://discord.gg/zjCHuew"]];
}

- (void)visitGithub {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild"]];
}

- (void)visitSource {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/MacForge"]];
}

- (void)visitReddit {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.reddit.com/r/OSXTweaks"]];
}

- (void)visitWebsite {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.macenhance.com/macforge"]];
}

- (void)setupEventListener {
    watchdogs = [[NSMutableArray alloc] init];
    for (NSString *path in [PluginManager MacEnhancePluginPaths]) {
        SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:path
                                                               update:^{
                                                                   [PluginManager.sharedInstance readPlugins:self->_tblView];
                                                               }];
        [watchDog start];
        [watchdogs addObject:watchDog];
    }
}

- (IBAction)changeAutoUpdates:(id)sender {
    int selected = (int)[(NSPopUpButton*)sender indexOfSelectedItem];
    if (selected == 0)
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:false] forKey:@"SUEnableAutomaticChecks"];
    if (selected == 1) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUEnableAutomaticChecks"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:false] forKey:@"SUAutomaticallyUpdate"];
    }
    if (selected == 2) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUEnableAutomaticChecks"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:true] forKey:@"SUAutomaticallyUpdate"];
    }
}

- (IBAction)changeUpdateFrequency:(id)sender {
    int selected = (int)[(NSPopUpButton*)sender selectedTag];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:selected] forKey:@"SUScheduledCheckInterval"];
}

- (IBAction)changeSIMBLLogging:(id)sender {
    NSString *plist = [NSString stringWithFormat:@"%@/Library/Preferences/net.culater.SIMBL.plist", NSHomeDirectory()];
    NSMutableDictionary *dict = [[NSDictionary dictionaryWithContentsOfFile:plist] mutableCopy];
    NSString *logLevel = [NSString stringWithFormat:@"%ld", [_SIMBLLogging indexOfSelectedItem]];
    [dict setObject:logLevel forKey:@"SIMBLLogLevel"];
    [dict writeToFile:plist atomically:YES];
}

- (IBAction)toggleTips:(id)sender {
    NSButton *btn = sender;
    //    [myPreferences setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefTips"];
//    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefTips"];
    NSToolTipManager *test = [NSToolTipManager sharedToolTipManager];
    if ([btn state])
        [test setInitialToolTipDelay:0.1];
    else
        [test setInitialToolTipDelay:2];
}

- (IBAction)toggleHideMenubar:(id)sender {
    NSButton *btn = sender;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefHideMenubar"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSString *message = @"showMenu";
    if (btn.state == NSOnState) message = @"hideMenu";
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.macenhance.MacForgeHelperNotify" object:message];

}

- (IBAction)toggleSaveWindow:(id)sender {
    NSButton *btn = sender;
    //    [myPreferences setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefWindow"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefWindow"];
    if ([btn state]) {
        [[_window windowController] setShouldCascadeWindows:NO];      // Tell the controller to not cascade its windows.
        [_window setFrameAutosaveName:[_window representedFilename]];
    } else {
        [_window setFrameAutosaveName:@""];
    }
}

- (IBAction)toggleDonateButton:(id)sender {
    NSButton *btn = sender;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[btn state]] forKey:@"prefDonate"];
    if ([btn state]) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:1.0];
        [[_buttonDonate animator] setAlphaValue:0];
        [[_buttonDonate animator] setHidden:true];
        [NSAnimationContext endGrouping];
    } else {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:1.0];
        [[_buttonDonate animator] setAlphaValue:1];
        [[_buttonDonate animator] setHidden:false];
        [NSAnimationContext endGrouping];
    }
}

- (IBAction)showAbout:(id)sender {
    [self selectView:_viewAbout];
}

- (IBAction)showPrefs:(id)sender {
    [self selectView:_viewPreferences];
}

- (IBAction)showSysinfo:(id)sender {
    [self selectView:_viewSystem];
}

- (IBAction)aboutInfo:(id)sender {
    if ([sender isEqualTo:_showChanges]) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"CHANGELOG" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [_changeLog.textStorage setAttributedString:asr.render];
    }
    if ([sender isEqualTo:_showCredits]) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"CREDITS" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [_changeLog.textStorage setAttributedString:asr.render];
    }
    if ([sender isEqualTo:_showEULA]) {
        NSMutableAttributedString *mutableAttString = [[NSMutableAttributedString alloc] init];
        for (NSString *item in [FileManager contentsOfDirectoryAtPath:NSBundle.mainBundle.resourcePath error:nil]) {
            if ([item containsString:@"LICENSE"]) {
                
                NSString *unicodeStr = @"\n\u00a0\t\t\n\n";
                NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:unicodeStr];
                NSRange strRange = NSMakeRange(0, str.length);

                NSMutableParagraphStyle *const tabStyle = [[NSMutableParagraphStyle alloc] init];
                tabStyle.headIndent = 16; //padding on left and right edges
                tabStyle.firstLineHeadIndent = 16;
                tabStyle.tailIndent = -70;
                NSTextTab *listTab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter location:_changeLog.frame.size.width - tabStyle.headIndent + tabStyle.tailIndent options:@{}]; //this is how long I want the line to be
                tabStyle.tabStops = @[listTab];
                [str  addAttribute:NSParagraphStyleAttributeName value:tabStyle range:strRange];
                [str addAttribute:NSStrikethroughStyleAttributeName value:[NSNumber numberWithInt:2] range:strRange];
                
                [mutableAttString appendAttributedString:[[NSAttributedString alloc] initWithURL:[[NSBundle mainBundle] URLForResource:item withExtension:@""] options:[[NSDictionary alloc] init] documentAttributes:nil error:nil]];
                [mutableAttString appendAttributedString:str];
            }
        }
        [_changeLog.textStorage setAttributedString:mutableAttString];
    }
    if ([sender isEqualTo:_showDev]) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"README" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [_changeLog.textStorage setAttributedString:asr.render];
    }
    
    [NSAnimationContext beginGrouping];
    NSClipView* clipView = _changeLog.enclosingScrollView.contentView;
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.y = 0;
    [[clipView animator] setBoundsOrigin:newOrigin];
    [NSAnimationContext endGrouping];
    
    [self systemDarkModeChange:nil];
}

- (IBAction)toggleStartTab:(id)sender {
    NSPopUpButton *btn = sender;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:[btn indexOfSelectedItem]] forKey:@"prefStartTab"];
}

- (IBAction)segmentDiscoverTogglePush:(id)sender {
    NSInteger clickedSegment = [sender selectedSegment];
    NSArray *segements = @[_sourcesURLS, _discoverChanges];
    NSView* view = segements[clickedSegment];
    [view setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [view setFrameSize:_sourcesRoot.frame.size];
    isdiscoverView = clickedSegment;
    [_sourcesPush setEnabled:true];
    [_sourcesPop setEnabled:false];
    [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:view];
//    [_sourcesRoot.layer setBackgroundColor:NSColor.greenColor.CGColor];
}

- (IBAction)segmentNavPush:(id)sender {
    NSInteger clickedSegment = [sender selectedSegment];
    if (clickedSegment == 0) {
        [self popView:nil];
    } else {
        [self pushView:nil];
    }
}

- (void)reloadTable:(NSView *)view {
    // Get the subviews of the view
    NSArray *subviews = [view subviews];
    
    // Return if there are no subviews
    if ([subviews count] == 0) return; // COUNT CHECK LINE
    
    for (NSView *subview in subviews) {
        // Do what you want to do with the subview
        if ([subview.className isEqualToString:@"repopluginTable"]) {
            [subview performSelector:@selector(reloadData)];
            break;
        } else {
            // List the subviews of subview
            [self reloadTable:subview];
        }
    }
}

- (IBAction)pushView:(id)sender {
    NSArray *currView = sourceItems;
    if (isdiscoverView) currView = discoverItems;
    
    long cur = [currView indexOfObject:[_sourcesRoot.subviews objectAtIndex:0]];
    if ([_sourcesAllTable selectedRow] > -1) {
        [_sourcesPop setEnabled:true];

        if ((cur + 1) < [currView count]) {
            NSView *newView = [currView objectAtIndex:cur + 1];
            [newView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
            [newView setFrameSize:_sourcesRoot.frame.size];
//            [[_sourcesRoot animator] setSubviews:@[newView]];
            [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:[currView objectAtIndex:cur + 1]];
            [_window makeFirstResponder: [currView objectAtIndex:cur + 1]];
        }
        
        if ((cur + 2) >= [currView count]) {
            [_sourcesPush setEnabled:false];
        } else {
            [_sourcesPush setEnabled:true];
            [self reloadTable:_sourcesRoot];
//            dumpViews(_sourcesRoot, 0);
//            if (osx_ver > 9) {
//                [[[[[[[_sourcesRoot subviews] firstObject] subviews] firstObject] subviews] firstObject] reloadData];
//            } else {
//                [[[[[[[_sourcesRoot subviews] firstObject] subviews] firstObject] subviews] lastObject] reloadData];
//            }
        }
        
        [_sourcesRoot setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    }
}

- (IBAction)popView:(id)sender {
    NSArray *currView = sourceItems;
    if (isdiscoverView) currView = discoverItems;
    long cur = [currView indexOfObject:[_sourcesRoot.subviews objectAtIndex:0]];
    [_sourcesPush setEnabled:true];
    if ((cur - 1) <= 0)
        [_sourcesPop setEnabled:false];
    else
        [_sourcesPop setEnabled:true];
    if ((cur - 1) >= 0) {
        NSView *incoming = [currView objectAtIndex:cur - 1];
        [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:incoming];
        [_window makeFirstResponder:incoming];
    }
}

- (IBAction)rootView:(id)sender {
    [_sourcesPush setEnabled:true];
    [_sourcesPop setEnabled:false];
    NSView *currView = _sourcesURLS;
    if (isdiscoverView) currView = _discoverChanges;
    [[_sourcesRoot animator] replaceSubview:[_sourcesRoot.subviews objectAtIndex:0] with:currView];
}

- (IBAction)selectView:(id)sender {
    selectedView = sender;
    if ([tabViewButtons containsObject:sender]) {
        NSString *analyticsTitle = [sender title];
        if ([sender isEqualTo:_viewAccount])
            analyticsTitle = @"👨‍💻 Account";
        [MSAnalytics trackEvent:@"Selected View" withProperties:@{@"View" : analyticsTitle}];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            NSView *v = [tabViews objectAtIndex:[tabViewButtons indexOfObject:sender]];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self setViewSubView:self.tabMain :v];
            });
        });
    }
    
//    [_tabFeatured setWantsLayer:true];
//    [_tabFeatured.layer setBackgroundColor:NSColor.redColor.CGColor];
//    for (NSView *v in _tabFeatured.subviews) {
//        [v setWantsLayer:true];
//        [v.layer setBackgroundColor:NSColor.blueColor.CGColor];
//    }
    
    [_tabMain setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSColor *primary = NSColor.darkGrayColor;
    NSColor *secondary = NSColor.blackColor;
    NSColor *highlight = NSColor.blackColor;
    if (osx_ver >= 14) {
        if ([osxMode isEqualToString:@"Dark"]) {
            primary = NSColor.lightGrayColor;
            secondary = NSColor.whiteColor;
            highlight = NSColor.whiteColor;
        }
    }
    
    for (NSButton *g in tabViewButtons) {
        if (![g isEqualTo:sender]) {
            [[g layer] setBackgroundColor:[NSColor clearColor].CGColor];
            NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithString:g.title];
            [colorTitle addAttribute:NSForegroundColorAttributeName value:primary range:NSMakeRange(0, g.attributedTitle.length)];
            [g setAttributedTitle:colorTitle];
        } else {
            [[g layer] setBackgroundColor:[highlight colorWithAlphaComponent:.25].CGColor];
            NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithString:g.title];
            [colorTitle addAttribute:NSForegroundColorAttributeName value:secondary range:NSMakeRange(0, g.attributedTitle.length)];
            [g setAttributedTitle:colorTitle];
        }
    }
}

- (IBAction)sourceAddorRemove:(id)sender {
    if ([[sender className] isEqualToString:@"NSMenuItem"]) {
        NSMutableArray *newSources = [[[NSUserDefaults standardUserDefaults] objectForKey:@"sources"] mutableCopy];
        NSString *str = (NSString*)[newSources objectAtIndex:[_sourcesRepoTable selectedRow]];
        [newSources removeObject:str];
        [[NSUserDefaults standardUserDefaults] setObject:newSources forKey:@"sources"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [myPreferences setObject:newSources forKey:@"sources"];
    } else {
        NSMutableArray *newArray = [NSMutableArray arrayWithArray:[myPreferences objectForKey:@"sources"]];
        NSString *input = _addsourcesTextFiled.stringValue;
        NSArray *arr = [input componentsSeparatedByString:@"\n"];
        for (NSString* item in arr) {
            if ([item length]) {
                if ([newArray containsObject:item]) {
                    [newArray removeObject:item];
                } else {
                    [newArray addObject:item];
                }
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:newArray forKey:@"sources"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [myPreferences setObject:newArray forKey:@"sources"];
    }
    
    [_srcWin close];
    [_sourcesAllTable reloadData];
    [_sourcesRepoTable reloadData];
}

- (IBAction)refreshSources:(id)sender {
    [_sourcesAllTable reloadData];
    [_sourcesRepoTable reloadData];
}

- (IBAction)sourceAddNew:(id)sender {
    NSRect newFrame = _window.frame;
    newFrame.origin.x += (_window.frame.size.width / 2) - (_srcWin.frame.size.width / 2);
    newFrame.origin.y += (_window.frame.size.height / 2) - (_srcWin.frame.size.height / 2);
    newFrame.size.width = _srcWin.frame.size.width;
    newFrame.size.height = _srcWin.frame.size.height;
    [_srcWin setFrame:newFrame display:true];
    [_window addChildWindow:_srcWin ordered:NSWindowAbove];
    [_srcWin makeKeyAndOrderFront:self];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (proposedMinimumPosition < 125) {
        proposedMinimumPosition = 125;
    }
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (proposedMaximumPosition >= 124) {
        proposedMaximumPosition = 125;
    }
    return proposedMaximumPosition;
}

- (IBAction)toggleAMFI:(id)sender {
    [MacForgeKit AMFI_amfi_get_out_of_my_way_toggle];
    [_AMFIStatus setState:[MacForgeKit AMFI_enabled]];
}

- (void)setupSIMBLview {
    [_SIMBLTogggle setState:[FileManager fileExistsAtPath:@"/Library/PrivilegedHelperTools/com.w0lf.MacForge.Injector"]];
     [_SIMBLAgentToggle setState:[FileManager fileExistsAtPath:@"/Library/PrivilegedHelperTools/com.w0lf.MacForge.Installer"]];
         
     Boolean sipEnabled = [MacForgeKit SIP_enabled];
     Boolean sipHasFlags = [MacForgeKit SIP_HasRequiredFlags];
     Boolean amfiEnabled = [MacForgeKit AMFI_enabled];
     Boolean LVEnabled = [MacForgeKit LIBRARYVALIDATION_enabled];
     
     [_SIP_NVRAM setState:![MacForgeKit SIP_NVRAM]];
     [_SIP_TaskPID setState:![MacForgeKit SIP_TASK_FOR_PID]];
     [_SIP_filesystem setState:![MacForgeKit SIP_Filesystem]];
     
     if (!sipEnabled) [_SIP_status setStringValue:@"Disabled"];
     if (!amfiEnabled) [_AMFI_status setStringValue:@"Disabled"];
     if (!LVEnabled) [_LV_status setStringValue:@"Disabled"];
     if (sipEnabled && sipHasFlags) [_SIP_status setStringValue:@"Enabled (Custom)"];
     
     dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
         [MacForgeKit AMFI_NUKE];
     });
     
     if (!LVEnabled && sipHasFlags) {
         [_SIPWarning setHidden:true];
     } else {
         [_SIPWarning setHidden:false];
     }
}

- (void)simbl_blacklist {
    NSString *plist = @"Library/Preferences/com.w0lf.MacForgeHelper.plist";
    NSMutableDictionary *SIMBLPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:plist]];
    NSArray *blacklist = [SIMBLPrefs objectForKey:@"SIMBLApplicationIdentifierBlacklist"];
    NSArray *alwaysBlaklisted = @[@"org.w0lf.mySIMBL", @"org.w0lf.cDock-GUI",
                                  @"com.w0lf.MacForge", @"com.w0lf.MacForgeHelper",
                                  @"org.w0lf.cDockHelper", @"com.macenhance.purchaseValidationApp"];
    NSMutableArray *newlist = [[NSMutableArray alloc] initWithArray:blacklist];
    for (NSString *app in alwaysBlaklisted)
        if (![blacklist containsObject:app])
            [newlist addObject:app];
    [SIMBLPrefs setObject:newlist forKey:@"SIMBLApplicationIdentifierBlacklist"];
    [SIMBLPrefs writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:plist] atomically:YES];
}

- (IBAction)addorRemoveBlacklistItem:(id)sender {
    NSSegmentedControl *sc = (NSSegmentedControl*)sender;
    if (sc.selectedSegment == 0) {
        [self addBlacklistItem];
    } else {
        [self removeBlacklistItem];
    }
}

- (void)removeBlacklistItem {
    NSMutableArray *bundleIDs = [[NSMutableArray alloc] init];
    NSIndexSet *selected = _blackListTable.selectedRowIndexes;
    NSUInteger idx = [selected firstIndex];
    while (idx != NSNotFound) {
        // do work with "idx"
//        NSLog (@"The current index is %lu", (unsigned long)idx);

        // Get row at specified index of column 0 ( We just have 1 column)
        blacklistTableCell *cellView = [_blackListTable viewAtColumn:0 row:idx makeIfNecessary:YES];
        NSString *bundleID = cellView.bundleID;
        NSLog(@"Deleting key: %@", bundleID);
        [bundleIDs addObject:bundleID];

        // get the next index in the set
        idx = [selected indexGreaterThanIndex:idx];
    }
    [MF_BlacklistManager removeBlacklistItems:bundleIDs.copy];
    [_blackListTable reloadData];
}

- (void)addBlacklistItem {
    NSOpenPanel* opnDlg = [NSOpenPanel openPanel];
    [opnDlg setTitle:@"Blacklist Selected Applications"];
    [opnDlg setPrompt:@"Blacklist"];
    [opnDlg setDirectoryURL:[NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) firstObject]]];
    [opnDlg setAllowedFileTypes:@[@"app"]];
    [opnDlg setCanChooseFiles:true];            //Disable file selection
    [opnDlg setCanChooseDirectories: false];    //Enable folder selection
    [opnDlg setResolvesAliases: true];          //Enable alias resolving
    [opnDlg setAllowsMultipleSelection: true];  //Enable multiple selection
    if ([opnDlg runModal] == NSModalResponseOK) {
        // Got it, use the panel.URL field for something
        NSLog(@"MacForge : %@", [opnDlg URLs]);
        [MF_BlacklistManager addBlacklistItems:opnDlg.URLs];
        [_blackListTable reloadData];
    } else {
        // Cancel was pressed...
    }
}

- (IBAction)uninstallMacForge:(id)sender {
    [MacForgeKit MacEnhance_remove];
}

- (IBAction)visit_ad:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_adURL]];
    [MSAnalytics trackEvent:@"Visit ad" withProperties:@{@"URL" : _adURL}];
}

- (IBAction)storeSelectView:(id)sender {
    NSMenuItem *item = (NSMenuItem*)sender;
    NSMenu *m = item.menu;
    NSUInteger position = [m indexOfItem:item];
    if (position > 1) position -= 2;
    NSArray *items = @[_viewDiscover, _viewPlugins, _viewSources, _viewChanges, _viewSystem, _viewAbout, _viewPreferences, _viewAccount];
    if (position == 11) position = 7;
    [self selectView:items[position]];
    
//    NSLog(@"%lu", (unsigned long)position);
}

- (void)keepThoseAdsFresh {
    if (_adArray != nil) {
        if (!_buttonAdvert.hidden) {
            NSInteger arraySize = _adArray.count;
            NSInteger displayNum = (NSInteger)arc4random_uniform((int)[_adArray count]);
            if (displayNum == _lastAD) {
                displayNum++;
                if (displayNum >= arraySize)
                    displayNum -= 2;
                if (displayNum < 0)
                    displayNum = 0;
            }
            _lastAD = displayNum;
            NSDictionary *dic = [_adArray objectAtIndex:displayNum];
            NSString *name = [dic objectForKey:@"name"];
            name = [NSString stringWithFormat:@"    %@", name];
            NSString *url = [dic objectForKey:@"homepage"];
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:1.25];
                [[self->_buttonAdvert animator] setTitle:name];
            } completionHandler:^{
            }];
            if (url)
                _adURL = url;
            else
                _adURL = @"https://github.com/w0lfschild/mySIMBL";
        }
    }
}

- (void)updateAdButton {
    // Local ads
    NSArray *dict = [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ads" ofType:@"plist"]];
    NSInteger displayNum = (NSInteger)arc4random_uniform((int)[dict count]);
    NSDictionary *dic = [dict objectAtIndex:displayNum];
    NSString *name = [dic objectForKey:@"name"];
    name = [NSString stringWithFormat:@"    %@", name];
    NSString *url = [dic objectForKey:@"homepage"];
    
    [_buttonAdvert setTitle:name];
    if (url)
        _adURL = url;
    else
        _adURL = @"https://github.com/w0lfschild/MacForge";
    
    _adArray = dict;
    _lastAD = displayNum;
    
    // Check web for new ads

    // 1
    NSURL *dataUrl = [NSURL URLWithString:@"https://github.com/w0lfschild/app_updates/raw/master/MacForge/ads.plist"];
    
    // 2
    NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
                                          dataTaskWithURL:dataUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                              // 4: Handle response here
                                              NSPropertyListFormat format;
                                              NSError *err;
                                              NSArray *dict = (NSArray*)[NSPropertyListSerialization propertyListWithData:data
                                                                                                                  options:NSPropertyListMutableContainersAndLeaves
                                                                                                                   format:&format
                                                                                                                    error:&err];
                                              // NSLog(@"mySIMBL : %@", dict);
                                              if (dict) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      NSInteger displayNum = (NSInteger)arc4random_uniform((int)[dict count]);
                                                      NSDictionary *dic = [dict objectAtIndex:displayNum];
                                                      NSString *name = [dic objectForKey:@"name"];
                                                      name = [NSString stringWithFormat:@"    %@", name];
                                                      NSString *url = [dic objectForKey:@"homepage"];
                                                      
                                                      [self->_buttonAdvert setTitle:name];
                                                      if (url)
                                                          self->_adURL = url;
                                                      else
                                                          self->_adURL = @"https://github.com/w0lfschild/MacForge";
                                                      
                                                      self->_adArray = dict;
                                                      self->_lastAD = displayNum;
                                                  });
                                              }
                                              
                                          }];
    
    // 3
    [downloadTask resume];
}

- (Boolean)keypressed:(NSEvent *)theEvent {
    NSString*   const   character   =   [theEvent charactersIgnoringModifiers];
    unichar     const   code        =   [character characterAtIndex:0];
    bool                specKey     =   false;
    
    switch (code) {
        case NSLeftArrowFunctionKey: {
            [self popView:nil];
            specKey = true;
            break;
        }
        case NSRightArrowFunctionKey: {
            [self pushView:nil];
            specKey = true;
            break;
        }
        case NSCarriageReturnCharacter: {
            [self pushView:nil];
            specKey = true;
            break;
        }
    }
    
    return specKey;
}

// -------------------
// USER AUTHENTICATION
// -------------------

// XXX Later support Google account (OAuth?)

- (void)setViewSubView:(NSView*)container :(NSView*)subview {
    [subview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [subview setFrame:container.frame];
    [subview setFrameOrigin:NSMakePoint(0, 0)];
    [subview setTranslatesAutoresizingMaskIntoConstraints:true];
    //    [subview setWantsLayer:true];
    //    subview.layer.backgroundColor = NSColor.redColor.CGColor;
    [container setSubviews:[NSArray arrayWithObject:subview]];
}

- (void)setViewSubViewWithAnimation:(NSView*)container :(NSView*)subview {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
        [context setDuration:0.1];
        [[container.subviews.firstObject animator] setFrameOrigin:NSMakePoint(0, container.frame.size.height)];
    } completionHandler:^{
        [container.subviews.firstObject removeFromSuperview];
        [self setViewSubView:container :subview];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [context setDuration:0.2];
            NSPoint startPoint = NSMakePoint(0, subview.frame.size.height);
            [subview setFrameOrigin:startPoint];
            [[subview animator] setFrameOrigin:NSMakePoint(0, 0)];
        } completionHandler:^{
        }];
    }];
}

- (IBAction)showPurchases:(id)sender {
    [self setViewSubView:self.tabAccount :self.tabAccountPurchases];
}

- (IBAction)showUser:(id)sender {
    [self setViewSubView:self.tabAccount :self.tabAccountManage];
}

- (IBAction)signUpUser:(id)sender {
    NSString *username  = _loginUsername.stringValue;
    NSString *email     = _email.stringValue;
    NSString *password  = _password.stringValue;
    NSURL *photoURL     = [NSURL URLWithString:_loginImageURL.stringValue];
    
    MF_accountManager *accountManager = [[MF_accountManager alloc] init];
    
    /* Try to create a new account */
    [accountManager createAccountWithUsername:username
                                        email:email
                                     password:password
                                  andPhotoURL:photoURL
                        withCompletionHandler:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable err) {
        if (!err) {
            NSLog(@"Successfully created user!");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_loginUID.stringValue = authResult.user.uid;
            });
        }
        else {
            NSLog(@"%@", err);
        }
    }];
}

- (IBAction)updateUser:(id)sender {
    NSString *username = _loginUsername.stringValue;
    NSURL *photoURL = [NSURL URLWithString:_loginImageURL.stringValue];
    
    MF_accountManager *accountManager = [[MF_accountManager alloc] init];
    
    /* Try to update account */
    [accountManager updateAccountWithUsername:username andPhotoURL:photoURL withCompletionHandler:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable err) {
        if (!err) {
            [self updateUserButtonWithUser:self->_user andAuth:nil];
            NSLog(@"Successfully signed-in!");
        } else {
            NSLog(@"%@", err);
        }
    }];
}

- (IBAction)signInUser:(id)sender {
    NSString *email = _email.stringValue;
    NSString *password = _password.stringValue;
    
    MF_accountManager *accountManager = [[MF_accountManager alloc] init];
    
    /* Try to log into an account */
    [accountManager loginAccountWithEmail:email
                              andPassword:password
                    withCompletionHandler:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable err) {
        if (!err) {
            NSLog(@"Successfully signed-in!");
            
            [self selectView:self->_viewAccount];
        }
        else {
            NSLog(@"%@", err);
        }
    }];
}

- (IBAction)signOutUSer:(id)sender {
    NSError *signOutError;
    
    NSLog(@"Signing-out user: %@", [FIRAuth auth].currentUser.uid);
    
    BOOL status = [[FIRAuth auth] signOut:&signOutError];
    
    if (!status) {
        NSLog(@"Error signing out: %@", signOutError);
        return;
    }
    
    NSLog(@"Successfully signed-out.");
    
    /* show sign-in form */
    [self selectView:_tabAccountRegister];
}

- (IBAction)signInOrOut:(id)sender {
    if (_user)
        [self signOutUSer:sender];
    else
        [self selectView:_tabAccountRegister];
}

- (IBAction)openRegisterForm:(id)sender {
    [self selectView:_tabAccountRegister];
}

- (IBAction)setPhotoURL:(id)sender {
    NSOpenPanel *op = [NSOpenPanel openPanel];
    
    op.allowsMultipleSelection = NO;
    op.allowedFileTypes = @[@"jpg", @"png", @"tiff"];
    [op runModal];
    
    _loginImageURL.stringValue = op.URL.absoluteString;
}

// Updates title and photo of user on sidebar upon FIRAuth event
- (void)updateUserButtonWithUser:(FIRUser *)user andAuth:(FIRAuth *)auth {
    NSLog(@"Auth-event for user: %@", user.displayName);
    
    /* check if a user is signed-in */
    if (_user) {
        NSURL *photoURL = _user.photoURL;
        NSString *displayName = _user.displayName;

        if (displayName.length > 0) {
            _viewAccount.title = [NSString stringWithFormat:@"                    %@", displayName];
            _loginUsername.stringValue = displayName;
        } else {
            _viewAccount.title = [NSString stringWithFormat:@"                    %@", [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].fullName];
            _loginUsername.stringValue = @"";
        }

        if (photoURL.absoluteString.length > 0) {
            _imgAccount.image = [NSImage sd_imageWithData:[NSData dataWithContentsOfURL:photoURL]];
            _loginImageURL.stringValue = photoURL.absoluteString;
        } else {
            _imgAccount.image = [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].image;
            _loginImageURL.stringValue = @"";
        }
        
        _loginEmail.stringValue = _user.email;
        _loginUID.stringValue = _user.uid;
//        _user.emailVerified
//        _user.providerID
        
        _imgAccount.layer.backgroundColor = NSColor.clearColor.CGColor;
    }
    /* no user signed-in; going with OS user */
    else {
//        _imgAccount.image = [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].image;
//        _viewAccount.title = [NSString stringWithFormat:@"                    %@", [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].fullName];
        
        _imgAccount.image = [NSImage imageNamed:NSImageNameUserGroup];
        _imgAccount.layer.backgroundColor = NSColor.grayColor.CGColor;
        _viewAccount.title = [NSString stringWithFormat:@"                    Create Account"];
    }
}

@end
