import UIKit

/// Quadrilateral in the 3D
struct Quadrilateral {
    
    // MARK: - Private Properties
    
    /// Coordinates of vertex
    private let topLeft: CGPoint
    private let topRight: CGPoint
    private let bottomLeft: CGPoint
    private let bottomRight: CGPoint
    
    // MARK: - Init
    
    /// Init with "flat" quadrilateral
    /// - Parameter frame: frame of rectangle
    init(frame: CGRect) {
        topLeft = CGPoint(x: frame.minX, y: frame.minY)
        topRight = CGPoint(x: frame.maxX, y: frame.minY)
        bottomLeft = CGPoint(x: frame.minX, y: frame.maxY)
        bottomRight = CGPoint(x: frame.maxX, y: frame.maxY)
    }
    
    /// Init with vertex coordinates
    /// - Parameter points: coordinates of topLeft, topRight, bottomRight, bottomLeft vertex
    /// NOTE: in this order only
    init(points: [CGPoint]) {
        topLeft = points[0]
        topRight = points[1]
        bottomRight = points[2]
        bottomLeft = points[3]
    }

    // MARK: - Public
    
    /// Calculate 3D transform to from current to another position
    /// - Parameter quad: new position of quadrilateral
    /// See also: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html
    func transformTo(_ quad: Quadrilateral) -> CATransform3D {
        let rect = box()
        let x1a = quad.topLeft.x
        let y1a = quad.topLeft.y
        let x2a = quad.topRight.x
        let y2a = quad.topRight.y
        let x3a = quad.bottomLeft.x
        let y3a = quad.bottomLeft.y
        let x4a = quad.bottomRight.x
        let y4a = quad.bottomRight.y

        let X = rect.origin.x
        let Y = rect.origin.y
        let W = rect.size.width
        let H = rect.size.height

        let y21 = y2a - y1a
        let y32 = y3a - y2a
        let y43 = y4a - y3a
        let y14 = y1a - y4a
        let y31 = y3a - y1a
        let y42 = y4a - y2a

        let a = -H*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42)
        let b = W*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43)
        let c = H*X*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42) - H*W*x1a*(x4a*y32 - x3a*y42 + x2a*y43) - W*Y*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43)

        let d = H*(-x4a*y21*y3a + x2a*y1a*y43 - x1a*y2a*y43 - x3a*y1a*y4a + x3a*y2a*y4a)
        let e = W*(x4a*y2a*y31 - x3a*y1a*y42 - x2a*y31*y4a + x1a*y3a*y42)
        let f1 = (x4a*(Y*y2a*y31 + H*y1a*y32) - x3a*(H + Y)*y1a*y42 + H*x2a*y1a*y43 + x2a*Y*(y1a - y3a)*y4a + x1a*Y*y3a*(-y2a + y4a))
        let f2 = x4a*y21*y3a - x2a*y1a*y43 + x3a*(y1a - y2a)*y4a + x1a*y2a*(-y3a + y4a)
        let f = -(W*f1 - H*X*f2)

        let g = H*(x3a*y21 - x4a*y21 + (-x1a + x2a)*y43)
        let h = W*(-x2a*y31 + x4a*y31 + (x1a - x3a)*y42)

        let temp = X * (-x3a*y21 + x4a*y21 + x1a*y43 - x2a*y43) + W * (-x3a*y2a + x4a*y2a + x2a*y3a - x4a*y3a - x2a*y4a + x3a*y4a)
        var i = W * Y * (x2a*y31 - x4a*y31 - x1a*y42 + x3a*y42) + H * temp

        let kEpsilon = CGFloat(0.0001)

        if abs(i) < kEpsilon {
            i = kEpsilon * (i > 0 ? 1.0 : -1.0)
        }

        return CATransform3D(
            m11: a/i,   m12: d/i,   m13: 0,     m14: g/i,
            m21: b/i,   m22: e/i,   m23: 0,     m24: h/i,
            m31: 0,     m32: 0,     m33: 1,     m34: 0,
            m41: c/i,   m42: f/i, 	m43: 0,     m44: 1.0
        )
    }
    
    // MARK: - Private
    
    /// Bounding box
    private func box() -> CGRect {
        let xmin = min(min(min(topRight.x, topLeft.x), bottomLeft.x), bottomRight.x)
        let ymin = min(min(min(topRight.y, topLeft.y), bottomLeft.y), bottomRight.y)
        let xmax = max(max(max(topRight.x, topLeft.x), bottomLeft.x), bottomRight.x)
        let ymax = max(max(max(topRight.y, topLeft.y), bottomLeft.y), bottomRight.y)
        return CGRect(origin: CGPoint(x: xmin, y: ymin), size: CGSize(width: xmax - xmin, height: ymax - ymin))
    }

}
