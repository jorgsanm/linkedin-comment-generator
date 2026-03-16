import CoreGraphics
import Testing
@testable import LinkedInCommentAssistantCore

struct ScreenSelectionCropperTests {
    @Test
    func pixelCropRectMapsScreenSelectionIntoImageCoordinates() throws {
        let cropper = ScreenSelectionCropper()
        let windowFrame = CGRect(x: 100, y: 100, width: 1000, height: 800)
        let selection = CGRect(x: 350, y: 500, width: 300, height: 200)

        let pixelRect = try #require(
            cropper.pixelCropRect(
                for: selection,
                inWindowFrame: windowFrame,
                imageSize: CGSize(width: 2000, height: 1600)
            )
        )

        #expect(pixelRect == CGRect(x: 500, y: 400, width: 600, height: 400))
    }

    @Test
    func pixelCropRectClampsSelectionToVisibleWindow() throws {
        let cropper = ScreenSelectionCropper()
        let windowFrame = CGRect(x: 100, y: 100, width: 1000, height: 800)
        let selection = CGRect(x: 50, y: 700, width: 300, height: 400)

        let pixelRect = try #require(
            cropper.pixelCropRect(
                for: selection,
                inWindowFrame: windowFrame,
                imageSize: CGSize(width: 2000, height: 1600)
            )
        )

        #expect(pixelRect == CGRect(x: 0, y: 0, width: 500, height: 400))
    }
}
