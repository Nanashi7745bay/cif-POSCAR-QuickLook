//
//  AppDelegate.m
//  CrystalQuickLook
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupMenu];

    _mainWindowController = [[MainWindowController alloc] init];
    [_mainWindowController showWindow:nil];
    [_mainWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count > 1) {
        NSString *path = args[1];
        if (![path hasPrefix:@"-"]) {
            NSURL *url = [NSURL fileURLWithPath:path];
            [_mainWindowController openFileURL:url];
        }
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames {
    if (filenames.count > 0) {
        NSURL *url = [NSURL fileURLWithPath:filenames.firstObject];
        if (!_mainWindowController) {
            _mainWindowController = [[MainWindowController alloc] init];
            [_mainWindowController showWindow:nil];
        }
        [_mainWindowController openFileURL:url];
    }
}

- (void)setupMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // App Menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"CrystalQuickLook"];
    [appMenu addItemWithTitle:@"About CrystalQuickLook" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Register QuickLook Extension" action:@selector(registerQuickLook:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide CrystalQuickLook" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit CrystalQuickLook" action:@selector(terminate:) keyEquivalent:@"q"];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    // File Menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Open..." action:@selector(openDocument:) keyEquivalent:@"o"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];

    // View Menu (Styles & Orientations)
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    [viewMenu addItemWithTitle:@"Studio Dark Style" action:@selector(selectStudioStyle:) keyEquivalent:@"1"];
    [viewMenu addItemWithTitle:@"VESTA Style" action:@selector(selectVESTAStyle:) keyEquivalent:@"2"];
    [viewMenu addItemWithTitle:@"Flat White (No Shade)" action:@selector(selectFlatStyle:) keyEquivalent:@"3"];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItemWithTitle:@"Cycle Style" action:@selector(cycleStyle:) keyEquivalent:@"t"];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItemWithTitle:@"Reset View" action:@selector(viewReset:) keyEquivalent:@"r"];
    [viewMenu addItemWithTitle:@"Look along a-axis" action:@selector(viewAlongA:) keyEquivalent:@""];
    [viewMenu addItemWithTitle:@"Look along b-axis" action:@selector(viewAlongB:) keyEquivalent:@""];
    [viewMenu addItemWithTitle:@"Look along c-axis" action:@selector(viewAlongC:) keyEquivalent:@""];

    viewMenuItem.submenu = viewMenu;
    [mainMenu addItem:viewMenuItem];

    // Window Menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    windowMenuItem.submenu = windowMenu;
    [mainMenu addItem:windowMenuItem];

    NSApp.mainMenu = mainMenu;
}

- (void)openDocument:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.message = @"Select a CIF or POSCAR crystal structure file";

    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            [self.mainWindowController openFileURL:panel.URL];
        }
    }];
}

- (void)selectStudioStyle:(id)sender {
    [self.mainWindowController.crystalVC setRenderStyle:CrystalRenderStyleStudio];
}

- (void)selectVESTAStyle:(id)sender {
    [self.mainWindowController.crystalVC setRenderStyle:CrystalRenderStyleVESTA];
}

- (void)selectFlatStyle:(id)sender {
    [self.mainWindowController.crystalVC setRenderStyle:CrystalRenderStyleFlat];
}

- (void)cycleStyle:(id)sender {
    [self.mainWindowController.crystalVC cycleNextStyle];
}

- (void)viewReset:(id)sender {
    [self.mainWindowController.crystalVC resetCamera];
}

- (void)viewAlongA:(id)sender {
    [self.mainWindowController.crystalVC lookAlongA];
}

- (void)viewAlongB:(id)sender {
    [self.mainWindowController.crystalVC lookAlongB];
}

- (void)viewAlongC:(id)sender {
    [self.mainWindowController.crystalVC lookAlongC];
}

- (void)registerQuickLook:(id)sender {
    // Helper action to invoke qlmanage / pluginkit
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *appexPath = [bundlePath stringByAppendingPathComponent:@"Contents/PlugIns/CrystalQuickLookPreview.appex"];

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pluginkit"];
    task.arguments = @[@"-a", appexPath];
    NSError *err = nil;
    [task launchAndReturnError:&err];
    [task waitUntilExit];

    NSTask *qlTask = [[NSTask alloc] init];
    qlTask.executableURL = [NSURL fileURLWithPath:@"/usr/bin/qlmanage"];
    qlTask.arguments = @[@"-r"];
    [qlTask launchAndReturnError:nil];
    [qlTask waitUntilExit];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"QuickLook Extension Registered";
    alert.informativeText = @"The QuickLook extension has been registered. You can now select any .cif or POSCAR file in Finder and press Space to preview!";
    [alert runModal];
}

@end
