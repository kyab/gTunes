//
//  MainView.m
//  Circle Edit
//
//  Created by kyab on 2017/04/13.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import "MainView.h"
#import "AppController.h"

@implementation MainView

- (void)awakeFromNib
{
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSPasteboard *board = [sender draggingPasteboard];
    NSArray *files = [board propertyListForType:NSFilenamesPboardType];
    NSURL *fileURL = [NSURL fileURLWithPath:files[0]];
    NSLog(@"extension = %@",fileURL.pathExtension);
//    if ([fileURL.pathExtension isEqualToString:@"mp3"] ||
//        [fileURL.pathExtension isEqualToString:@"m4a"]){
//        NSLog(@"generic");
//        return NSDragOperationCopy;
//    }else{
//        NSLog(@"none");
//        return NSDragOperationNone;
//    }
    return NSDragOperationCopy;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *board = [sender draggingPasteboard];
    NSArray *files = [board propertyListForType:NSFilenamesPboardType];
    NSURL *fileURL = [NSURL fileURLWithPath:files[0]];
    
//    if ([fileURL.pathExtension isEqualToString:@"mp3"] ||
//        [fileURL.pathExtension isEqualToString:@"m4a"]){
//        NSLog(@"dragged");
//        //[self.window setTitleWithRepresentedFilename:fileURL.path];
//        AppController *controller = (AppController *)self.window.delegate;
//        [controller notifyDD:fileURL];
//        return YES;
//    }else{
//        NSLog(@"canceled");
//        return NO;
//    }
    AppController *controller = (AppController *)self.window.delegate;
    [controller notifyDD:fileURL];
    return YES;
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
