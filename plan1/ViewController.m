//
//  ViewController.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "ViewController.h"
#import "Render/MeshRenderer.h"
#import "UI/ScanControlButton.h"
#import "UI/FileListViewController.h"
#import "Data/ScanDataManager.h"
#import "Data/R3DExporter.h"

@interface ViewController ()

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) ARWorldTrackingConfiguration *configuration;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) MeshRenderer *meshRenderer;
@property (nonatomic, strong) ScanControlButton *scanButton;
@property (nonatomic, strong) UIButton *viewFilesButton;
@property (nonatomic, strong) ScanDataManager *dataManager;
@property (nonatomic) BOOL isScanning;
@property (nonatomic) NSUInteger frameCounter;

@end

@implementation ViewController

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupSceneView];
    [self setupConfiguration];
    [self setupMeshRenderer];
    [self setupStatusUI];
    [self setupScanButton];
    [self setupViewFilesButton];
    [self setupDataManager];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.sceneView.session runWithConfiguration:self.configuration
                                         options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.sceneView.session pause];
}

#pragma mark - AR 会话设置

- (void)setupSceneView {
    self.sceneView = [[ARSCNView alloc] initWithFrame:self.view.bounds];
    self.sceneView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.sceneView.delegate = self;
    self.sceneView.scene = [SCNScene scene];
    self.sceneView.autoenablesDefaultLighting = YES;
    self.sceneView.showsStatistics = YES;
    self.sceneView.debugOptions = ARSCNDebugOptionShowFeaturePoints;
    [self.view addSubview:self.sceneView];
}

- (void)setupConfiguration {
    self.configuration = [[ARWorldTrackingConfiguration alloc] init];

    if ([ARWorldTrackingConfiguration supportsSceneReconstruction:ARSceneReconstructionMesh]) {
        self.configuration.sceneReconstruction = ARSceneReconstructionMesh;
    }

    self.configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    self.configuration.environmentTexturing = AREnvironmentTexturingNone;
    self.configuration.frameSemantics = ARFrameSemanticSmoothedSceneDepth;
}

- (void)setupMeshRenderer {
    self.meshRenderer = [[MeshRenderer alloc] initWithSceneView:self.sceneView];
    [self.meshRenderer setMeshColor:[UIColor whiteColor]];
    [self.meshRenderer setFillMode:SCNFillModeLines];
}

- (void)setupViewFilesButton {
    self.viewFilesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.viewFilesButton setTitle:@"查看" forState:UIControlStateNormal];
    self.viewFilesButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.viewFilesButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.viewFilesButton.tintColor = [UIColor whiteColor];
    self.viewFilesButton.layer.cornerRadius = 18;
    [self.viewFilesButton sizeToFit];

    // 增大点击区域
    CGRect btnFrame = self.viewFilesButton.frame;
    btnFrame.size.width += 40;
    btnFrame.size.height = 36;
    self.viewFilesButton.frame = btnFrame;

    self.viewFilesButton.frame = CGRectMake(20,
                                             self.view.bounds.size.height - 120,
                                             self.viewFilesButton.frame.size.width,
                                             36);
    self.viewFilesButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;

    [self.viewFilesButton addTarget:self action:@selector(viewFilesTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.viewFilesButton];
}

- (void)setupDataManager {
    self.dataManager = [[ScanDataManager alloc] init];
}

- (void)setupStatusUI {
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 40)];
    self.statusLabel.text = @"将相机对准空间，点击「开始」扫描";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.statusLabel.layer.cornerRadius = 10;
    self.statusLabel.clipsToBounds = YES;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.statusLabel];
}

- (void)setupScanButton {
    self.scanButton = [[ScanControlButton alloc] init];
    self.scanButton.center = CGPointMake(self.view.center.x, self.view.bounds.size.height - 120);
    self.scanButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

    __weak typeof(self) weakSelf = self;
    self.scanButton.onTap = ^(ScanButtonState currentState) {
        [weakSelf scanButtonTapped:currentState];
    };

    [self.view addSubview:self.scanButton];
}

#pragma mark - 扫描控制

- (void)scanButtonTapped:(ScanButtonState)state {
    switch (state) {
        case ScanButtonStateStart:
            [self startScanning];
            break;
        case ScanButtonStateEnd:
            [self stopScanning];
            break;
    }
}

- (void)startScanning {
    self.isScanning = YES;
    self.frameCounter = 0;
    [self.dataManager startRecording];
    [self.scanButton setScanState:ScanButtonStateEnd animated:YES];
    self.statusLabel.text = @"扫描中...";
    [self.meshRenderer processExistingAnchorsInSession:self.sceneView.session];
}

- (void)stopScanning {
    self.isScanning = NO;
    [self.scanButton setScanState:ScanButtonStateStart animated:YES];
    self.statusLabel.text = @"扫描完成";

    NSArray<FrameRecord *> *records = [self.dataManager stopRecording];
    [self showExportAlertWithRecords:records];
}

- (void)showExportAlertWithRecords:(NSArray<FrameRecord *> *)records {
    if (records.count == 0) {
        [self clearScene];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"共采集 %lu 帧，输入文件名导出 .r3d：", (unsigned long)records.count];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"扫描完成"
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyyMMdd_HHmmss";
        textField.text = [NSString stringWithFormat:@"Scan_%@", [formatter stringFromDate:[NSDate date]]];
        textField.placeholder = @"输入文件名";
    }];

    __weak typeof(self) weakSelf = self;
    UIAlertAction *exportAction = [UIAlertAction actionWithTitle:@"导出" style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        if (name.length == 0) {
            // 空文件名时用时间戳兜底
            name = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        }
        if (![name hasSuffix:@".r3d"]) {
            name = [name stringByAppendingPathExtension:@"r3d"];
        }
        [weakSelf exportR3DWithRecords:records filename:name];
        [weakSelf clearScene];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
        [weakSelf clearScene];
    }];

    [alert addAction:exportAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewFilesTapped {
    FileListViewController *fileList = [[FileListViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:fileList];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)exportR3DWithRecords:(NSArray<FrameRecord *> *)records filename:(NSString *)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsPath = paths.firstObject;
    NSString *filePath = [docsPath stringByAppendingPathComponent:filename];

    BOOL success = [R3DExporter exportRecords:records toPath:filePath];
    if (success) {
        self.statusLabel.text = [NSString stringWithFormat:@"已导出: %@", filename];
    } else {
        self.statusLabel.text = @"导出失败";
    }
}

- (void)clearScene {
    [self.sceneView.session runWithConfiguration:self.configuration
                                         options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
    self.statusLabel.text = @"就绪";
}

#pragma mark - ARSCNViewDelegate（SCNSceneRendererDelegate）

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    if (!self.isScanning) {
        return;
    }

    self.frameCounter++;
    if (self.frameCounter % 6 != 0) {
        return;
    }

    ARFrame *currentFrame = self.sceneView.session.currentFrame;
    if (currentFrame) {
        [self.dataManager recordFrame:currentFrame];
    }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (!self.isScanning || ![anchor isKindOfClass:[ARMeshAnchor class]]) {
        return;
    }
    [self.meshRenderer updateNode:node withAnchor:(ARMeshAnchor *)anchor];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (!self.isScanning || ![anchor isKindOfClass:[ARMeshAnchor class]]) {
        return;
    }
    [self.meshRenderer updateNode:node withAnchor:(ARMeshAnchor *)anchor];
}

#pragma mark - AR 会话观察者

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.7];
        self.statusLabel.text = [NSString stringWithFormat:@"错误: %@", error.localizedDescription];
    });
}

- (void)sessionWasInterrupted:(ARSession *)session {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"会话中断\u2026";
    });
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"恢复中\u2026";
    });
    [self.sceneView.session runWithConfiguration:self.configuration
                                         options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
}

@end
