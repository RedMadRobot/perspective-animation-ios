![](header.svg)
# Perspective Animation

Example of perspective animation of a photo.

This is an implementation of how to detect a rectangle from a camera and animate a perspective.

![](demo.gif)

## Used frameworks

* `AVFoundation` for taking a photo.
* `Vision` for on the fly rectangle detection from the camera.
* `CoreImage` for filtering image.

## Algorithm

1. Launch a camera and observe output for rectangles.
2. When a rectangle is detected, show it at the UI.
3. Take a picture and apply a perspective correction filter to get the resulting image.
4. Calculate the 4x4 transform matrix to animate from the initial image to the resulting image.

Implementation is simplified for clarity.

## See also

* [Core Animation Basics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html)
* [Perspective Mappings](https://www.geometrictools.com/Documentation/PerspectiveMappings.pdf)

## Special thanks

* [Alexander Khlebnikov](https://github.com/orgs/RedMadRobot/people/a-khlebnikov) for rectangle detection.
* [Paul Zabelin](https://github.com/paulz) for transform matrix calculator.
* [Anton Glezman](https://github.com/orgs/RedMadRobot/people/modestman) for the article resource.

