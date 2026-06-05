#import "FileListViewController.h"

@interface FileListViewController ()

@property (nonatomic, strong) NSArray<NSString *> *fileNames;
@property (nonatomic, strong) NSString *documentsPath;

@end

@implementation FileListViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @".r3d 文件";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(dismissSelf)];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    self.documentsPath = paths.firstObject;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self reloadFiles];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFiles];
}

- (void)reloadFiles {
    NSError *error = nil;
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.documentsPath error:&error];
    if (!allFiles) {
        self.fileNames = @[];
        [self.tableView reloadData];
        return;
    }

    NSMutableArray *r3dFiles = [[NSMutableArray alloc] init];
    for (NSString *name in allFiles) {
        if ([name hasSuffix:@".r3d"]) {
            [r3dFiles addObject:name];
        }
    }

    [r3dFiles sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSString *pathA = [self.documentsPath stringByAppendingPathComponent:a];
        NSString *pathB = [self.documentsPath stringByAppendingPathComponent:b];
        NSDictionary *attrA = [[NSFileManager defaultManager] attributesOfItemAtPath:pathA error:nil];
        NSDictionary *attrB = [[NSFileManager defaultManager] attributesOfItemAtPath:pathB error:nil];
        return [attrB.fileModificationDate compare:attrA.fileModificationDate];
    }];

    self.fileNames = r3dFiles;
    [self.tableView reloadData];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 文件操作

- (NSString *)filePathAtIndex:(NSUInteger)index {
    return [self.documentsPath stringByAppendingPathComponent:self.fileNames[index]];
}

- (void)shareFileAtIndex:(NSUInteger)index fromSourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect {
    NSURL *fileURL = [NSURL fileURLWithPath:[self filePathAtIndex:index]];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
                                                                             applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceRect = sourceRect;
        activityVC.popoverPresentationController.sourceView = sourceView;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)renameFileAtIndex:(NSUInteger)index {
    NSString *oldName = self.fileNames[index];
    NSString *oldPath = [self filePathAtIndex:index];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名"
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = oldName;
        textField.placeholder = @"输入新文件名";
    }];

    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        NSString *newName = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
        if (newName.length == 0 || [newName isEqualToString:oldName]) {
            return;
        }
        if (![newName hasSuffix:@".r3d"]) {
            newName = [newName stringByAppendingPathExtension:@"r3d"];
        }

        NSString *newPath = [self.documentsPath stringByAppendingPathComponent:newName];
        NSError *error = nil;
        if ([[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
            [self reloadFiles];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:renameAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteFileAtIndex:(NSUInteger)index {
    NSString *name = self.fileNames[index];
    NSString *path = [self filePathAtIndex:index];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除文件"
                                                                    message:[NSString stringWithFormat:@"确定删除「%@」？", name]
                                                             preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
        NSError *error = nil;
        if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
            [self reloadFiles];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:deleteAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 长按菜单 (UIContextMenuConfiguration)

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                        point:(CGPoint)point {
    NSUInteger index = indexPath.row;
    CGRect cellRect = [tableView rectForRowAtIndexPath:indexPath];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *shareAction = [UIAction actionWithTitle:@"分享"
                                                    image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction *action) {
            [self shareFileAtIndex:index fromSourceView:tableView sourceRect:cellRect];
        }];

        UIAction *renameAction = [UIAction actionWithTitle:@"重命名"
                                                     image:[UIImage systemImageNamed:@"pencil"]
                                                identifier:nil
                                                   handler:^(__kindof UIAction *action) {
            [self renameFileAtIndex:index];
        }];

        UIAction *deleteAction = [UIAction actionWithTitle:@"删除"
                                                     image:[UIImage systemImageNamed:@"trash"]
                                                identifier:nil
                                                   handler:^(__kindof UIAction *action) {
            [self deleteFileAtIndex:index];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;

        return [UIMenu menuWithTitle:self.fileNames[index] children:@[shareAction, renameAction, deleteAction]];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fileNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = self.fileNames[indexPath.row];
    return cell;
}

@end
