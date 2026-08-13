/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license. The full license text
 * is in THIRD-PARTY-NOTICES at the repository root.
 */

#import <yoga/Yoga.h>
#import "YGLayout.h"

@interface YGLayout ()

@property(nonatomic, assign, readonly) YGNodeRef node;

- (instancetype)initWithView:(UIView*)view;

@end
