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

#pragma mark - Init

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _meshColor = [UIColor whiteColor];
        _fillMode = kDefaultFillMode;
    }
    return self;
}

#pragma mark - Public

- (void)setMeshColor:(UIColor *)color {
    _meshColor = color;
}

- (void)setFillMode:(SCNFillMode)fillMode {
    _fillMode = fillMode;
}

- (UIColor *)currentColor {
    return _meshColor;
}

- (SCNGeometry *)createGeometryFromAnchor:(ARMeshAnchor *)meshAnchor {
    ARMeshGeometry *meshGeometry = meshAnchor.geometry;

    // 1. Extract vertex data
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

    // 2. Extract face (index) data
    const int *indices = (const int *)meshGeometry.faces.buffer.contents;
    NSInteger faceCount = meshGeometry.faces.count;
    NSUInteger indexCount = faceCount * 3;

    NSMutableData *indexData = [[NSMutableData alloc] initWithLength:indexCount * sizeof(int)];
    [indexData replaceBytesInRange:NSMakeRange(0, indexCount * sizeof(int)) withBytes:indices];

    SCNGeometryElement *geometryElement = [SCNGeometryElement geometryElementWithData:indexData
                                                                        primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                                      primitiveCount:faceCount
                                                                       bytesPerIndex:sizeof(int)];

    // 3. Create geometry
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[vertexSource]
                                                    elements:@[geometryElement]];

    // 4. Apply material
    [self applyMaterialToGeometry:geometry];

    return geometry;
}

- (void)processExistingAnchorsInSession:(ARSession *)session {
    for (ARAnchor *anchor in session.currentFrame.anchors) {
        if (![anchor isKindOfClass:[ARMeshAnchor class]]) {
            continue;
        }
        SCNNode *node = [self.sceneView nodeForAnchor:anchor];
        if (node && !node.geometry) {
            node.geometry = [self createGeometryFromAnchor:(ARMeshAnchor *)anchor];
        }
    }
}

#pragma mark - Private

- (void)applyMaterialToGeometry:(SCNGeometry *)geometry {
    SCNMaterial *material = [[SCNMaterial alloc] init];
    material.emission.contents = self.meshColor;
    material.transparency = 1;
    material.fillMode = self.fillMode;
    material.doubleSided = YES;
    geometry.materials = @[material];
}

@end
