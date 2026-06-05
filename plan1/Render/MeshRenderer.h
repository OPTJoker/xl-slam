//
//  MeshRenderer.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 负责将 ARMeshAnchor 转换为 SCNGeometry 并管理网格渲染样式
@interface MeshRenderer : NSObject

/// 绑定到 ARSCNView，后续 createGeometryFromAnchor: 创建的几何体会自动关联
- (instancetype)initWithSceneView:(ARSCNView *)sceneView;

/// 在锚点节点下创建遮挡体 + 线框子节点，实现深度遮挡
- (void)updateNode:(SCNNode *)node withAnchor:(ARMeshAnchor *)anchor;

/// 从 ARMeshAnchor 创建线框几何体
- (SCNGeometry *)createGeometryFromAnchor:(ARMeshAnchor *)meshAnchor;

/// 遍历已有锚点，为所有 ARMeshAnchor 创建并附加几何体
- (void)processExistingAnchorsInSession:(ARSession *)session;

/// 设置网格颜色（内部使用 emission）
- (void)setMeshColor:(UIColor *)color;

/// 设置填充模式（.lines 或 .fill）
- (void)setFillMode:(SCNFillMode)fillMode;

/// 当前网格颜色
@property (nonatomic, strong, readonly) UIColor *currentColor;

@end

NS_ASSUME_NONNULL_END
