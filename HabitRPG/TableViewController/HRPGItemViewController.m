//
//  HRPGTableViewController.m
//  HabitRPG
//
//  Created by Phillip Thelen on 08/03/14.
//  Copyright (c) 2014 Phillip Thelen. All rights reserved.
//

#import "HRPGItemViewController.h"
#import "Egg.h"
#import "HRPGAppDelegate.h"
#import "HRPGImageOverlayView.h"
#import "HRPGSharingManager.h"
#import "HatchingPotion.h"
#import "Quest.h"

@interface HRPGItemViewController ()
@property Item *selectedItem;
@property NSIndexPath *selectedIndex;
@property BOOL isHatching;
@property NSArray *existingPets;
@property UIBarButtonItem *backButton;

- (void)configureCell:(UITableViewCell *)cell
          atIndexPath:(NSIndexPath *)indexPath
        withAnimation:(BOOL)animate;
@end

@implementation HRPGItemViewController

float textWidth;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tutorialIdentifier = @"items";

    CGRect screenRect = [[UIScreen mainScreen] bounds];
    textWidth = screenRect.size.width - 118;

    [self clearDuplicates];
}

- (void)clearDuplicates {
    NSMutableArray *duplicates = [NSMutableArray array];
    NSArray *items = self.fetchedResultsController.fetchedObjects;
    for (int i = 1; i < items.count; i++) {
        if ([((Item *)items[i]).key isEqualToString:((Item *)items[i - 1]).key]) {
            [duplicates addObject:items[i]];
        }
    }
    if (duplicates.count > 0) {
        for (Item *item in duplicates) {
            [self.managedObjectContext deleteObject:item];
        }
        NSError *error;
        [self.managedObjectContext save:&error];
    }
}

- (void)fetchExistingPetsWithPartName:(NSString *)string {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity =
        [NSEntityDescription entityForName:@"Pet" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    [fetchRequest setFetchBatchSize:20];

    NSPredicate *predicate;
    predicate = [NSPredicate predicateWithFormat:@"key contains[cd] %@ && trained > 0", string];
    [fetchRequest setPredicate:predicate];

    NSError *error;
    self.existingPets = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
}

- (void)showCancelButton {
    self.backButton = self.navigationItem.leftBarButtonItem;
    UIBarButtonItem *cancelButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(endHatching)];
    [self.navigationItem setLeftBarButtonItem:cancelButton animated:YES];
}

- (void)showBackButton {
    [self.navigationItem setLeftBarButtonItem:self.backButton animated:YES];
}

- (void)endHatching {
    [self showBackButton];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"owned > 0"];
    [self.fetchedResultsController.fetchRequest setPredicate:predicate];
    self.isHatching = NO;
    NSError *error;
    [self.fetchedResultsController performFetch:&error];
    [self.tableView reloadData];
}

- (NSDictionary *)getDefinitonForTutorial:(NSString *)tutorialIdentifier {
    if ([tutorialIdentifier isEqualToString:@"items"]) {
        return @{
            @"text" : NSLocalizedString(
                @"Earn items by completing tasks and leveling up. Tap on an item to use it!", nil)
        };
    }
    return nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[self.fetchedResultsController sections][section] name];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath withAnimation:NO];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *sections = [self.fetchedResultsController sections];
    if ([sections count] < indexPath.section) {
        return 0;
    }
    id<NSFetchedResultsSectionInfo> sectionInfo = sections[indexPath.section];
    if ([sectionInfo numberOfObjects] < indexPath.item) {
        return 0;
    }
    NSInteger height = 24;
    if (indexPath.item <
        self.fetchedResultsController.sections[indexPath.section].numberOfObjects) {
        Item *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
        height = height +
                 [item.text boundingRectWithSize:CGSizeMake(textWidth, MAXFLOAT)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{
                                          NSFontAttributeName :
                                              [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                      }
                                         context:nil]
                     .size.height;
    }

    if (height < 60) {
        return 60;
    }
    return height;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndex = indexPath;
    Item *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (self.isHatching) {
        for (Pet *pet in self.existingPets) {
            if ([pet.key rangeOfString:item.key].location != NSNotFound) {
                return;
            }
        }
        NSString *eggName;
        NSString *eggDisplayName;
        NSString *potionName;
        NSString *potionDisplayName;
        if ([self.selectedItem isKindOfClass:[HatchingPotion class]]) {
            eggName = item.key;
            eggDisplayName = item.text;
            potionName = self.selectedItem.key;
            potionDisplayName = self.selectedItem.text;
        } else {
            eggName = self.selectedItem.key;
            eggDisplayName = self.selectedItem.text;
            potionName = item.key;
            potionDisplayName = item.text;
        }
        [self.sharedManager
              hatchEgg:eggName
            withPotion:potionName
             onSuccess:^(NSString *message) {
                 [self.sharedManager
                       getImage:[NSString stringWithFormat:@"Pet-%@-%@", eggName, potionName]
                     withFormat:nil
                      onSuccess:^(UIImage *image) {
                          NSArray *nibViews =
                              [[NSBundle mainBundle] loadNibNamed:@"HRPGImageOverlayView"
                                                            owner:self
                                                          options:nil];
                          HRPGImageOverlayView *overlayView = nibViews[0];
                          [overlayView displayImage:image];
                          overlayView.imageWidth = 81;
                          overlayView.imageHeight = 99;
                          overlayView.descriptionText = [NSString
                              stringWithFormat:NSLocalizedString(@"You hatched a %@ %@!", nil),
                                               potionDisplayName, eggDisplayName];
                          overlayView.dismissButtonText = NSLocalizedString(@"Close", nil);
                          overlayView.shareAction = ^() {
                              HRPGAppDelegate *del =
                                  (HRPGAppDelegate *)[UIApplication sharedApplication].delegate;
                              UIViewController *activeViewController =
                                  del.window.rootViewController.presentedViewController;
                              [HRPGSharingManager shareItems:@[
                                  [[NSString stringWithFormat:NSLocalizedString(
                                                                  @"I just hatched a %@ %@ pet in "
                                                                  @"Habitica by completing my "
                                                                  @"real-life tasks!",
                                                                  nil),
                                                              potionDisplayName, eggDisplayName]
                                      stringByAppendingString:
                                          @" https://habitica.com/social/hatch-pet"],
                                  image
                              ]
                                withPresentingViewController:activeViewController withSourceView:[self.tableView cellForRowAtIndexPath:indexPath]];
                          };
                          [overlayView sizeToFit];
                          KLCPopup *popup =
                              [KLCPopup popupWithContentView:overlayView
                                                    showType:KLCPopupShowTypeBounceIn
                                                 dismissType:KLCPopupDismissTypeBounceOut
                                                    maskType:KLCPopupMaskTypeDimmed
                                    dismissOnBackgroundTouch:YES
                                       dismissOnContentTouch:YES];
                          [popup show];
                      }
                        onError:nil];
             }
               onError:nil];

        [self endHatching];
        return;
    }
    NSString *extraItem;
    NSString *destructiveButton =
        [NSString stringWithFormat:NSLocalizedString(@"Sell (%@ Gold)", nil), item.value];
    if ([item isKindOfClass:[Quest class]]) {
        extraItem = NSLocalizedString(@"Invite Party", nil);
        destructiveButton = nil;
    } else if ([item isKindOfClass:[HatchingPotion class]]) {
        extraItem = NSLocalizedString(@"Hatch Egg", nil);
    } else if ([item isKindOfClass:[Egg class]]) {
        extraItem = NSLocalizedString(@"Hatch with Potion", nil);
    }

    UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:destructiveButton
                                              otherButtonTitles:extraItem, nil];
    popup.tag = 1;
    self.selectedItem = item;

    // get the selected cell so that the popup can be displayed near it on the iPad
    UITableViewCell *selectedCell = [self tableView:tableView cellForRowAtIndexPath:indexPath];

    CGRect rectIPad = CGRectMake(selectedCell.frame.origin.x, selectedCell.frame.origin.y,
                                 selectedCell.frame.size.width, selectedCell.frame.size.height);
    // using the following form rather than [popup showInView:[UIApplication
    // sharedApplication].keyWindow]] to make it compatible with both iPhone and iPad
    [popup showFromRect:rectIPad inView:self.view animated:YES];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item"
                                              inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    NSPredicate *predicate;
    predicate = [NSPredicate predicateWithFormat:@"owned > 0"];
    [fetchRequest setPredicate:predicate];

    // Edit the sort key as appropriate.
    NSSortDescriptor *indexDescriptor = [[NSSortDescriptor alloc] initWithKey:@"key" ascending:YES];
    NSSortDescriptor *typeDescriptor = [[NSSortDescriptor alloc] initWithKey:@"type" ascending:YES];
    NSArray *sortDescriptors = @[ typeDescriptor, indexDescriptor ];

    [fetchRequest setSortDescriptors:sortDescriptors];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController =
        [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                            managedObjectContext:self.managedObjectContext
                                              sectionNameKeyPath:@"type"
                                                       cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;

    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use
        // this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
    didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
             atIndex:(NSUInteger)sectionIndex
       forChangeType:(NSFetchedResultsChangeType)type {
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeMove:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
    didChangeObject:(id)anObject
        atIndexPath:(NSIndexPath *)indexPath
      forChangeType:(NSFetchedResultsChangeType)type
       newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;

    switch (type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[ newIndexPath ]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath
                  withAnimation:YES];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[ newIndexPath ]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.tableView deselectRowAtIndexPath:self.selectedIndex animated:YES];
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [self.sharedManager sellItem:self.selectedItem onSuccess:nil onError:nil];
    } else if (buttonIndex == 0 && [self.selectedItem isKindOfClass:[Quest class]]) {
        User *user = [self.sharedManager getUser];
        Quest *quest = (Quest *)self.selectedItem;
        [self.sharedManager inviteToQuest:user.partyID withQuest:quest onSuccess:nil onError:nil];
    } else if (buttonIndex == 1 && ![self.selectedItem isKindOfClass:[Quest class]]) {
        if ([self.selectedItem isKindOfClass:[HatchingPotion class]]) {
            NSPredicate *predicate =
                [NSPredicate predicateWithFormat:@"type = 'eggs' && owned > 0"];
            self.isHatching = YES;
            [self.fetchedResultsController.fetchRequest setPredicate:predicate];
            NSError *error;
            [self.fetchedResultsController performFetch:&error];
            [self.tableView reloadData];
            [self fetchExistingPetsWithPartName:self.selectedItem.key];
            [self showCancelButton];
        } else if ([self.selectedItem isKindOfClass:[Egg class]]) {
            NSPredicate *predicate =
                [NSPredicate predicateWithFormat:@"type = 'hatchingPotions' && owned > 0"];
            [self.fetchedResultsController.fetchRequest setPredicate:predicate];
            self.isHatching = YES;
            NSError *error;
            [self.fetchedResultsController performFetch:&error];
            [self.tableView reloadData];
            [self fetchExistingPetsWithPartName:self.selectedItem.key];
            [self showCancelButton];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self.tableView deselectRowAtIndexPath:self.selectedIndex animated:YES];
}

- (void)configureCell:(UITableViewCell *)cell
          atIndexPath:(NSIndexPath *)indexPath
        withAnimation:(BOOL)animate {
    NSArray *sections = [self.fetchedResultsController sections];
    if ([sections count] <= indexPath.section) {
        return;
    }
    id<NSFetchedResultsSectionInfo> sectionInfo = sections[indexPath.section];
    if ([sectionInfo numberOfObjects] <= indexPath.item) {
        return;
    }
    Item *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    UILabel *textLabel = [cell viewWithTag:1];
    textLabel.text = item.text;
    textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    UILabel *detailTextLabel = [cell viewWithTag:2];
    detailTextLabel.text = [NSString stringWithFormat:@"%@", item.owned];
    detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [detailTextLabel sizeToFit];
    NSString *imageName;
    if ([item.type isEqualToString:@"quests"]) {
        imageName = @"inventory_quest_scroll";
    } else {
        NSString *type;
        if ([item.type isEqualToString:@"eggs"]) {
            type = @"Egg";
        } else if ([item.type isEqualToString:@"food"]) {
            type = @"Food";
        } else if ([item.type isEqualToString:@"hatchingPotions"]) {
            type = @"HatchingPotion";
        }
        imageName = [NSString stringWithFormat:@"Pet_%@_%@", type, item.key];
    }
    [self.sharedManager setImage:imageName withFormat:@"png" onView:cell.imageView];
    cell.imageView.contentMode = UIViewContentModeCenter;
    cell.imageView.alpha = 1;
    textLabel.alpha = 1;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (self.isHatching) {
        for (Pet *pet in self.existingPets) {
            if ([pet.key rangeOfString:item.key].location != NSNotFound) {
                cell.imageView.alpha = 0.4;
                textLabel.alpha = 0.4;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            }
        }
    }
}

@end
