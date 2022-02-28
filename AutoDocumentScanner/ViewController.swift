//
//  ViewController.swift
//  AutoDocumentScanner
//
//  Created by 間嶋大輔 on 2022/03/01.
//

import UIKit
import Vision

class ViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    let context = CIContext()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    }
    
    func presentPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    @IBOutlet weak var imageView: UIImageView!
    @IBAction func CameraButtonTapped(_ sender: UIButton) {
        presentPicker()
    }
    
    private func getDocumentImage(image:UIImage) -> UIImage? {
        let ciImage = CIImage(image: image)!
        let request = VNDetectRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try! handler.perform([request])
        guard let result = request.results?.first else { return nil }
        
        let topLeft = CGPoint(x: result.topLeft.x, y: 1-result.topLeft.y)
        let topRight = CGPoint(x: result.topRight.x, y: 1-result.topRight.y)
        let bottomLeft = CGPoint(x: result.bottomLeft.x, y: 1-result.bottomLeft.y)
        let bottomRight = CGPoint(x: result.bottomRight.x, y: 1-result.bottomRight.y)

        
        let deNormalizedTopLeft = VNImagePointForNormalizedPoint(topLeft, Int(ciImage.extent.width), Int(ciImage.extent.height))
        let deNormalizedTopRight = VNImagePointForNormalizedPoint(topRight, Int(ciImage.extent.width), Int(ciImage.extent.height))
        let deNormalizedBottomLeft = VNImagePointForNormalizedPoint(bottomLeft, Int(ciImage.extent.width), Int(ciImage.extent.height))
        let deNormalizedBottomRight = VNImagePointForNormalizedPoint(bottomRight, Int(ciImage.extent.width), Int(ciImage.extent.height))

        let croppedImage = getCroppedImage(image: ciImage, topL: deNormalizedTopLeft, topR: deNormalizedTopRight, botL: deNormalizedBottomLeft, botR: deNormalizedBottomRight)
        let safeCGImage = context.createCGImage(croppedImage, from: croppedImage.extent)
        let croppedUIImage = UIImage(cgImage: safeCGImage!)
        return croppedUIImage
    }
    
    private func getCroppedImage(image: CIImage, topL: CGPoint, topR: CGPoint, botL: CGPoint, botR: CGPoint) -> CIImage {
        let rectCoords = NSMutableDictionary(capacity: 4)
        
        rectCoords["inputTopLeft"] = topL.toVector(image: image)
        rectCoords["inputTopRight"] = topR.toVector(image: image)
        rectCoords["inputBottomLeft"] = botL.toVector(image: image)
        rectCoords["inputBottomRight"] = botR.toVector(image: image)
        
        guard let coords = rectCoords as? [String : Any] else {
            return image
        }
        return image.applyingFilter("CIPerspectiveCorrection", parameters: coords)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            let orientedImage = getCorrectOrientationUIImage(uiImage: image)
            let documentImage = getDocumentImage(image: orientedImage)
            imageView.image = documentImage
        }
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
            var newImage = UIImage()
            switch uiImage.imageOrientation.rawValue {
            case 1:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                      let cgImage = context.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                
                newImage = UIImage(cgImage: cgImage)
            case 3:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                        let cgImage = context.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                newImage = UIImage(cgImage: cgImage)
            default:
                newImage = uiImage
            }
        return newImage
    }
}

extension CGPoint {
    func toVector(image: CIImage) -> CIVector {
        return CIVector(x: x, y: image.extent.height-y)
    }
}
