//
//  CompTableViewController.h
//  gTunes
//
//  Created by kyab on 2017/04/14.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface CompTableViewController : NSObject{
    NSMutableDictionary *_dbTopObj;
    NSMutableArray *_db;
    NSString *_path;
    NSString *_title;
    NSString *_artist;
    NSMutableArray *_compFiles;
}

- (void)loadFile:(NSString *)jsonPath;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

- (void)addItem:(NSString *)path;

- (void)setCurrentSong:(NSString *)title artist:(NSString *)artist;

- (NSString *)itemAtRow:(NSInteger)rowIndex;

@end
