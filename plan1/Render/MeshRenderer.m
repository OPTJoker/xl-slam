//
//  MeshRenderer.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "MeshRenderer.h"

static SCNFillMode const kDefaultFillMode = SCNFillModeLines;

@interface MeshRenderer ()

@property (nonatomic, weak) ARSCNView *sceneView;
@property (nonatomic, strong) UIColor *meshColor;
@property (nonatomic) SCNFillMode fillMode;

@end

@implementation MeshRenderer

#pragma mark - 初始化

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _meshColor = [UIColor whiteColor];
        _fillMode = kDefaultFillMode;
    }
    return self;
}

#pragma mark - 公开方法

- (void)setMeshColor:(UIColor *)color {
    _meshColor = color;
}

- (void)setFillMode:(SCNFillMode)fillMode {
    _fillMode = fillMode;
}

- (UIColor *)currentColor {
    return _meshColor;
}

/// 为锚点节点创建两个子节点（遮挡体 + 线框），实现深度遮挡效果
- (void)updateNode:(SCNNode *)node withAnchor:(ARMeshAnchor *)anchor {
    for (SCNNode *child in node.childNodes) {
        [child removeFromParentNode];
    }

    // 遮挡体：实体填充，写入深度缓冲，仅输出 Alpha 通道（不显示 RGB）
    SCNNode *occluderNode = [SCNNode nodeWithGeometry:[self createGeometryFromAnchor:anchor]];
    occluderNode.geometry.materials = @[[self solidDepthMaterial]];
    occluderNode.renderingOrder = 0;
    [node addChildNode:occluderNode];

    // 线框：边线模式，渲染在遮挡体上方
    SCNNode *wireframeNode = [SCNNode nodeWithGeometry:[self createGeometryFromAnchor:anchor]];
    [self applyWireframeMaterialToGeometry:wireframeNode.geometry];
    wireframeNode.renderingOrder = 1;
    [node addChildNode:wireframeNode];

    node.geometry = nil;
}

- (SCNGeometry *)createGeometryFromAnchor:(ARMeshAnchor *)meshAnchor {
    SCNGeometry *geometry = [self.class geometryFromAnchorGeometry:meshAnchor.geometry];
    return geometry;
}

- (void)processExistingAnchorsInSession:(ARSession *)session {
    for (ARAnchor *anchor in session.currentFrame.anchors) {
        if (![anchor isKindOfClass:[ARMeshAnchor class]]) {
            continue;
        }
        SCNNode *node = [self.sceneView nodeForAnchor:anchor];
        if (node && !node.childNodes.count) {
            [self updateNode:node withAnchor:(ARMeshAnchor *)anchor];
        }
    }
}

#pragma mark - 几何体构建

+ (SCNGeometry *)geometryFromAnchorGeometry:(ARMeshGeometry *)meshGeometry {
    const SCNVector3 *vertices = (const SCNVector3 *)meshGeometry.vertices.buffer.contents;
    NSInteger vertexCount = meshGeometry.vertices.count;
    NSUInteger vertexStride = meshGeometry.vertices.stride;

    NSMutableData *vertexData = [[NSMutableData alloc] initWithLength:vertexCount * vertexStride];
    for (NSInteger i = 0; i < vertexCount; i++) {
        const void *source = (const uint8_t *)vertices + i * vertexStride;
        [vertexData replaceBytesInRange:NSMakeRange(i * vertexStride, sizeof(SCNVector3)) withBytes:source];
    }

    SCNGeometrySource *vertexSource = [SCNGeometrySource geometrySourceWithData:vertexData
                                                                        semantic:SCNGeometrySourceSemanticVertex
                                                                     vectorCount:vertexCount
                                                                 floatComponents:YES
                                                               componentsPerVector:3
                                                                 bytesPerComponent:sizeof(float)
                                                                        dataOffset:0
                                                                        dataStride:vertexStride];

    const int *indices = (const int *)meshGeometry.faces.buffer.contents;
    NSInteger faceCount = meshGeometry.faces.count;
    NSUInteger indexCount = faceCount * 3;

    NSMutableData *indexData = [[NSMutableData alloc] initWithLength:indexCount * sizeof(int)];
    [indexData replaceBytesInRange:NSMakeRange(0, indexCount * sizeof(int)) withBytes:indices];

    SCNGeometryElement *geometryElement = [SCNGeometryElement geometryElementWithData:indexData
                                                                         primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                                       primitiveCount:faceCount
                                                                        bytesPerIndex:sizeof(int)];

    return [SCNGeometry geometryWithSources:@[vertexSource] elements:@[geometryElement]];
}

#pragma mark - 材质

/// 实体填充材质：写入深度缓冲，仅写 Alpha 通道（RGB 不变）
/// 在 ARSCNView 合成中 Alpha 写入本身不可见，
/// 但确保 SceneKit 处理绘制调用并写入深度缓冲
- (SCNMaterial *)solidDepthMaterial {
    SCNMaterial *material = [[SCNMaterial alloc] init];
    material.diffuse.contents = [UIColor colorWithWhite:1.0 alpha:1.0];
    material.colorBufferWriteMask = SCNColorMaskAlpha;
    material.writesToDepthBuffer = YES;
    material.doubleSided = YES;
    material.fillMode = SCNFillModeFill;
    material.lightingModelName = SCNLightingModelConstant;
    return material;
}

/// 线框材质：仅使用自发光，不写深度缓冲，通过深度测试实现遮挡
- (void)applyWireframeMaterialToGeometry:(SCNGeometry *)geometry {
    SCNMaterial *material = [[SCNMaterial alloc] init];
    material.emission.contents = self.meshColor;
    material.transparency = 1;
    material.fillMode = SCNFillModeLines;
    material.doubleSided = YES;
    material.writesToDepthBuffer = NO;
    geometry.materials = @[material];
}

@end
