//
//  discoverTable.m
//  MacForge
//
//  Created by Wolfgang Baird on 6/18/17.
//  Copyright © 2017 Wolfgang Baird. All rights reserved.
//

@import AppKit;
@import QuartzCore;
#import "AppDelegate.h"
//#import "PluginManager.h"
#import "MSPlugin.h"
#import "MF_Purchase.h"
#import "pluginData.h"
#import "SYFlatButton.h"

extern AppDelegate *myDelegate;
extern NSString *repoPackages;
extern long selectedRow;

NSArray *allPlugins;
NSArray *filteredPlugins;
NSString *textFilter;

NSInteger selRow;
NSInteger selCol;
NSInteger curItem;

@interface discoverPluginTable : NSTableView <NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    PluginManager *_sharedMethods;
    pluginData *_pluginData;
}
@property NSArray *localPlugins;
@property NSMutableArray *tableContent;
@property (weak) IBOutlet NSSearchField* changesFilter;
@end

@interface discoverPluginTableCell : NSTableCellView
@property (weak) IBOutlet NSTextField*  bundleName;
@property (weak) IBOutlet NSTextField*  bundleDescription;
@property (weak) IBOutlet NSTextField*  bundleInfo;
@property (weak) IBOutlet NSTextField*  bundleID;
@property (weak) IBOutlet NSTextField*  bundleRepo;
@property (weak) IBOutlet NSImageView*  bundleImage;
@property (weak) IBOutlet NSImageView*  bundleImageInstalled;
@property (weak) IBOutlet NSImageView*  bundleIndicator;
@property (weak) IBOutlet NSButton*     backGroundButton;

@property (weak) IBOutlet NSProgressIndicator*  bundleProgress;
@property (weak) IBOutlet SYFlatButton*         bundleGet;
@property (weak) IBOutlet MSPlugin*             pluginData;

@property (weak) IBOutlet NSImageView*  bundlePluginType;
@end

@interface discoverPluginTableHeaderCell : NSTableCellView
@property (weak) IBOutlet NSTextField*  updateTime;
@end

@implementation discoverPluginTable {
    
}

- (void)controlTextDidChange:(NSNotification *)obj{
    [myDelegate.changesTable reloadData];
}

- (NSArray*)filterView:(NSArray*)original {
    NSString *filterText = _changesFilter.stringValue;
    NSArray *result = original;
    NSString *filter = @"(webName CONTAINS[cd] %@) OR (bundleID CONTAINS[cd] %@) OR (webTarget CONTAINS[cd] %@)";
    if (filterText.length > 0) {
        result = [original filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:filter, filterText, filterText, filterText]];
    }
    return result;
}

- (NSTableViewSelectionHighlightStyle)selectionHighlightStyle {
    return NSTableViewSelectionHighlightStyleNone;
}

- (NSView *)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self tableView:tableView viewForTableColumn:tableColumn row:row];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (_sharedMethods == nil)
        _sharedMethods = [PluginManager sharedInstance];
    
    // Fetch repo content
    static dispatch_once_t aToken;
    dispatch_once(&aToken, ^{
        self->_pluginData = [pluginData sharedInstance];
        [self->_pluginData fetch_repos];
    });
    
    // Sort table by name
    NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:@"webName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *dank = [[NSMutableArray alloc] initWithArray:[_pluginData.repoPluginsDic allValues]];
    dank = [self filterView:dank];
    _tableContent = [[dank sortedArrayUsingDescriptors:@[sorter]] copy];
    
    // Fetch our local content too
    _localPlugins = [_sharedMethods getInstalledPlugins].allKeys;
    
//    NSLog(@"%lu : %lu", _tableContent.count, (_tableContent.count + tableView.numberOfColumns - 1) / tableView.numberOfColumns);
    
    return (_tableContent.count + tableView.numberOfColumns - 1) / tableView.numberOfColumns;
//    return _tableContent.count / tableView.numberOfColumns;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *clickMenu = [[NSMenu alloc] init];
    
    NSPoint globalLocation = [event locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];
    NSInteger clickedCol = [self columnAtPoint:localLocation];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:clickedRow];
    [self selectRowIndexes:indexSet byExtendingSelection:NO];
    indexSet = [NSIndexSet indexSetWithIndex:clickedCol];
    [self selectColumnIndexes:indexSet byExtendingSelection:NO];
    
    [clickMenu setTitle:@"Bundle Menu"];
    
    NSMenuItem *item = [NSMenuItem.alloc initWithTitle:@"Get plugin" action:nil keyEquivalent:@""];
    [item setTarget:myDelegate];
    [clickMenu addItem:item];
        
    item = [NSMenuItem.alloc initWithTitle:@"Remove plugin" action:nil keyEquivalent:@""];
    [item setTarget:myDelegate];
    [clickMenu addItem:item];
    
    [clickMenu addItem:[NSMenuItem separatorItem]];

    item = [NSMenuItem.alloc initWithTitle:@"Copy plugin URL" action:nil keyEquivalent:@""];
    [item setTarget:self];
    [clickMenu addItem:item];
    
//    [clickMenu addItem:[NSMenuItem separatorItem]];
//
//    item = [NSMenuItem.alloc initWithTitle:@"Refreash sources" action:@selector(reloadData) keyEquivalent:@""];
//    [item setTarget:self];
//    [clickMenu addItem:item];

    return clickMenu;
    
//    NSMenu *booty = [[NSMenu alloc] init];
//    [booty setTitle:@"Test"];
//    [booty addItem:[NSMenuItem.alloc initWithTitle:@"Install" action:nil keyEquivalent:@""]];
//    [booty addItem:[NSMenuItem.alloc initWithTitle:@"Delete" action:nil keyEquivalent:@""]];
//    return booty;
}

- (double)tableView:(NSTableView *)tableView heightOfRow:(long)row {
    // Header row
    if (row == 0) {
//        return 25;
    }

    return 99;
}

//- (CGFloat)rowHeight {
//    NSLog(@"%f", [super rowHeight]);
//    return 16;
//}

//- (NSRect)visibleRect {
//    NSRect r = [super visibleRect];
//    NSRange rows = [self rowsInRect:r];
//    NSInteger firstVisibleRowIndex = rows.location;
////    NSLog(@"%@", NSStringFromRect(r));
//    NSLog(@"%ld", (long)firstVisibleRowIndex);
//    return r;
//}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    NSView* theResult = NSView.alloc.init;
        
    // Header row
    if (row == 9001) {
        discoverPluginTableHeaderCell *result = (discoverPluginTableHeaderCell*)[tableView makeViewWithIdentifier:@"dpthView" owner:self];
        if ([tableColumn.identifier containsString:@"0"])
            result.textField.stringValue = [NSString stringWithFormat:@"%@", NSDate.date];
        else
            [result.textField setHidden:true];
        
        theResult = result;
    } else {
        // Not header row
        discoverPluginTableCell *result = (discoverPluginTableCell*)[tableView makeViewWithIdentifier:@"dptView" owner:self];
        
        //    NSLog(@"row : %ld column : %@", (long)row, tableColumn.identifier);
        NSInteger column = 0;
        if ([tableColumn.identifier isEqualToString:@"AutomaticTableColumnIdentifier.1"])
            column = 1;
        if ([tableColumn.identifier isEqualToString:@"AutomaticTableColumnIdentifier.2"])
            column = 2;
        NSInteger plugIndex = row * tableView.numberOfColumns + column;
        
        // Don't try to make any views that shouldn't exist
        if (plugIndex >= _tableContent.count) {
            result.hidden = true;
        } else {
            MSPlugin *item = [_tableContent objectAtIndex:plugIndex];
            [result.backGroundButton setWantsLayer:true];
            [result.backGroundButton.layer setBackgroundColor:NSColor.lightGrayColor.CGColor];
    //            [result.backGroundButton setAlphaValue:0.22];
            [result.backGroundButton setAlphaValue:0.0];
            result.backGroundButton.layer.cornerRadius = 10;
            result.pluginData = item;

            //    MSPlugin *item = [_tableContent objectAtIndex:row];

            result.bundleName.stringValue = item.webName;
            NSString *shortDescription = @"";
            if (item.webDescriptionShort != nil) {
                if (![item.webDescriptionShort isEqualToString:@""])
                    shortDescription = item.webDescriptionShort;
            }
            if ([shortDescription isEqualToString:@""])
                shortDescription = item.webDescription;
            result.bundleDescription.stringValue = shortDescription;
            //    NSString *bInfo = [NSString stringWithFormat:@"%@ - %@", item.webVersion, item.bundleID];
            //    result.bundleInfo.stringValue = bInfo;
            result.bundleID.stringValue = item.bundleID;
            result.bundleInfo.stringValue = item.webVersion;
            result.bundleDescription.toolTip = item.webDescription;

            //    NSSize titleSize = [item.webName sizeWithAttributes:@{NSFontAttributeName:result.bundleName.font}];
            //    int xPos = result.bundleName.frame.origin.x + 10 + titleSize.width;
            //    int yPos = result.bundleName.frame.origin.y;

//            [self add_interaction_button:result :item];

                // Check if installed
            //    Boolean hideCheckmark = true;
            //    NSString *a = [NSString stringWithFormat:@"/Library/Application Support/SIMBL/Plugins/%@.bundle", item.webName];
            //    NSString *b = [NSString stringWithFormat:@"/Users/%@/Library/Application Support/SIMBL/Plugins/%@.bundle", NSUserName(), item.webName];
            //    if ([FileManager fileExistsAtPath:a] || [FileManager fileExistsAtPath:b]) hideCheckmark = false;
            //    result.bundleImageInstalled.hidden = hideCheckmark;

            //    NSPoint p = CGPointMake(result.bundleIndicator.frame.origin.x - 40, result.bundleIndicator.frame.origin.y + 8);
            //    [result.bundleImageInstalled setFrameOrigin:p];
            //    [result.bundleImageInstalled setAutoresizingMask:NSViewMinXMargin];

            //    NSBundle *dank = [NSBundle bundleWithIdentifier:item.bundleID];
            //    result.bundleImageInstalled.hidden = true;
            //    if (dank.bundlePath.length)
            //        if ([dank.bundlePath rangeOfString:@"/Library/Application Support/SIMBL/Plugins"].length != 0)

//            if ([_localPlugins containsObject:item.bundleID]) {
//                result.bundleImageInstalled.hidden = false;
//                [result.bundleImageInstalled setImageScaling:NSImageScaleProportionallyUpOrDown];
//            }

            result.bundlePluginType.hidden = false;

            // Bundle
            [result.bundlePluginType setImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/KEXT.icns"]];

            if ([item.webPlist objectForKey:@"type"]) {
                NSString *type = [item.webPlist objectForKey:@"type"];
                if ([type isEqualToString:@"app"]) {
                    // App
                    [result.bundlePluginType setImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"]];
                }

                if ([type isEqualToString:@"theme"]) {
                    // Theme
                    NSRect imgRect = NSMakeRect(0, 0, 18, 18);
                    NSImage * image = [[NSImage alloc] initWithSize:imgRect.size];
                    [image lockFocus];
                    NSFont *font = [NSFont fontWithName:@"Palatino-Roman" size:14];
                    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
                    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"🎨" attributes:attrsDictionary];
                    [attrString drawInRect:CGRectMake(0, 0, 18, 18)];
                    [image unlockFocus];
                    [result.bundlePluginType setImage:image];
                }
            }

            NSImage *basicFetch = [PluginManager pluginGetIcon:item.webPlist];
            if ([item.webPlist objectForKey:@"customIcon"]) {
//                NSLog(@"%@%@", [item.webPlist objectForKey:@"sourceURL"], [item.webPlist objectForKey:@"icon"]);
                result.bundleImage.sd_imageIndicator = SDWebImageProgressIndicator.defaultIndicator;
                NSString *icoSTR = [[item.webPlist objectForKey:@"sourceURL"] stringByAppendingFormat:@"/images/%@/icon.png", item.bundleID];
//                NSLog(@"%@", icoSTR);
                [result.bundleImage sd_setImageWithURL:[NSURL URLWithString:icoSTR]
                                      placeholderImage:basicFetch];
            } else {
                result.bundleImage.image = basicFetch;
            }
            
            [result.bundleImage.cell setImageScaling:NSImageScaleProportionallyUpOrDown];
            
            
            result.bundleGet.backgroundNormalColor = NSColor.whiteColor;
            result.bundleGet.backgroundHighlightColor = NSColor.whiteColor;
            result.bundleGet.backgroundDisabledColor = NSColor.grayColor;
            result.bundleGet.titleNormalColor = [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1];
            result.bundleGet.titleHighlightColor = [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1];
            result.bundleGet.titleDisabledColor = NSColor.whiteColor;
            
            result.bundleGet.cornerRadius = result.bundleGet.frame.size.height/2;
            result.bundleGet.borderWidth = 0;
            result.bundleGet.momentary = true;
            [result.bundleProgress setHidden:true];
            
            [result.bundleGet setTarget:self];
            [result.bundleGet setAction:@selector(press_interaction_button:)];
            if (item.webPaid) {
                [result.bundleGet setTitle:item.webPrice];
            } else {
                [result.bundleGet setTitle:@"GET"];
            }
            
            Boolean installed = [PluginManager.sharedInstance pluginLocalPath:item.bundleID].length;
//            if ([_localPlugins containsObject:item.bundleID])
//                installed = true;
//
//            if ([Workspace URLForApplicationWithBundleIdentifier:item.bundleID])
//                installed = true;
                
            if (installed)
                [result.bundleGet setTitle:@"OPEN"];
                    
            [result.bundleImageInstalled setImageScaling:NSImageScaleProportionallyUpOrDown];
        }
            
        theResult = result;
    }
    
    return theResult;
}

- (void)press_interaction_button:(id)sender {
    SYFlatButton *s = (SYFlatButton*)sender;
    discoverPluginTableCell *cell = (discoverPluginTableCell*)s.superview;
    [MF_Purchase pushthebutton:cell.pluginData :s :cell.pluginData.webRepository :cell.bundleProgress];
}
    
- (void)keyDown:(NSEvent *)theEvent {
    Boolean result = [myDelegate keypressed:theEvent];
    if (!result) result = [self keypressed:theEvent];
    if (!result) [super keyDown:theEvent];
}

- (Boolean)keypressed:(NSEvent *)theEvent {
    NSString*   const   character   =   [theEvent charactersIgnoringModifiers];
    unichar     const   code        =   [character characterAtIndex:0];
    bool                specKey     =   false;
    
    switch (code) {
        case NSDownArrowFunctionKey: {
            [self selectNextItem:true];
            specKey = true;
            break;
        }
        case NSUpArrowFunctionKey: {
            [self selectNextItem:false];
            specKey = true;
            break;
        }
    }
    
    return specKey;
}

- (void)selectNextItem:(Boolean)goUp {
    if (!curItem)
        curItem = 0;
    
    if (goUp) {
        if (curItem < self.numberOfRows * self.numberOfColumns) {
            curItem++;
        } else {
            curItem = 0;
        }
    } else {
        if (curItem > 0) {
            curItem--;
        } else {
            curItem = self.numberOfRows * self.numberOfColumns;
        }
    }

    NSIndexSet *row = [NSIndexSet indexSetWithIndex:curItem / 2];
    NSIndexSet *col = [NSIndexSet indexSetWithIndex:0];
    if ( curItem % 2 == 1)
        col = [NSIndexSet indexSetWithIndex:1];

    [self selectRowIndexes:row byExtendingSelection:NO];
    [self selectColumnIndexes:col byExtendingSelection:NO];
}

-(IBAction)showMoreInfo:(id)sender {
//    id sender = [aNotification object];
//    MSPlugin *item = [_tableContent objectAtIndex:[sender selectedRow]];
//
//    NSTableView* s = (NSTableView*)sender;
//    NSLog(@"row : %ld column : %ld", (long)s.selectedRow, (long)s.selectedColumn);
//
    discoverPluginTableCell *c = (discoverPluginTableCell*)[(NSButton*)sender superview];
    [pluginData sharedInstance].currentPlugin = c.pluginData;
    [myDelegate pushView:nil];
}
    
-(void)tableChange:(NSNotification *)aNotification {
    id sender = [aNotification object];
    
    NSTableView* s = (NSTableView*)sender;
    if (s.selectedRow >= 0)
        selRow = s.selectedRow;
    
    if (s.selectedColumn >= 0)
        selCol = s.selectedColumn;
    else
        selCol = 0;
    
//    NSInteger index = [sender selectedRow] * 2 + [sender selectedColumn];
    NSInteger index = selRow * 2 + selCol;
    
    if (index >= 0 && index < _tableContent.count) {
        MSPlugin *item = [_tableContent objectAtIndex:index];

//        NSTableView* s = (NSTableView*)sender;
//        NSLog(@"row : %ld column : %ld", (long)s.selectedRow, (long)s.selectedColumn);
//        NSLog(@"row : %ld column : %ld index :%ld", selRow, selCol, index);

        [pluginData sharedInstance].currentPlugin = item;
    }
}
    
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self tableChange:aNotification];
}
    
- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification {
    [self tableChange:aNotification];
}
    
@end

@implementation discoverPluginTableCell
@end

@implementation discoverPluginTableHeaderCell
@end
