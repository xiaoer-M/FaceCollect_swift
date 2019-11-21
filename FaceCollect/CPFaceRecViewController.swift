//
//  CPFaceRecViewController.swift
//  i84cpn
//
//  Created by 小二 on 2018/8/2.
//  Copyright © 2018年 5i84. All rights reserved.
//

import UIKit
import AVFoundation

var ScreenWidth = UIScreen.main.bounds.size.width
var ScreenHeight = UIScreen.main.bounds.size.height

class CPFaceRecViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK - 私有属性
    fileprivate var session: AVCaptureSession?
    fileprivate var device: AVCaptureDevice?
    fileprivate var input: AVCaptureDeviceInput?
    fileprivate var output: AVCaptureMetadataOutput?
    fileprivate var preview: AVCaptureVideoPreviewLayer?
    fileprivate var myStillImageOutput: AVCaptureStillImageOutput? //拍照操作
    fileprivate var stateLb: UILabel? //人脸识别的状态
    fileprivate var isSuccess: Int = 0
//    fileprivate var hud: MBProgressHUD? //加载框
    
    // MARK - 公开属性
    typealias refreshFace = () -> Void
    var refreshFace: refreshFace?
    var userId: Int?
    var isAdd : Int = 0   //是否为添加乘客跳转过来 1是0否，默认0
    
    let faceX : CGFloat = 20
    let faceY : CGFloat = 100
    let faceW : CGFloat = UIScreen.main.bounds.size.width - 40
    let faceH : CGFloat = (UIScreen.main.bounds.size.width - 40) * 1.1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "人脸识别"
        self.view.backgroundColor = .white
        //设置识别界面和类
        setupCamera()
    }
    
    // 初始化相机
    func setupCamera() {
        //session
        session = AVCaptureSession()
        session?.sessionPreset = .photo
        session?.sessionPreset = .hd1280x720
        
        // device
        device = AVCaptureDevice.default(for: .video)
        // 设置为前置摄像头
        if #available(iOS 10.0, *) {
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: AVCaptureDevice.Position.front)
            for device in devices.devices {
                self.device = device
            }
        } else {
            let devices = AVCaptureDevice.devices(for: .video)
            for device in devices {
                if device.position == .front {
                    self.device = device
                }
            }
        }
        
        // input
        do {
            try input = AVCaptureDeviceInput(device: device!)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        if (session?.canAddInput(input!))! {
            session?.addInput(input!)
        }
        
        // 摄像
        myStillImageOutput = AVCaptureStillImageOutput()
        let myOutputSettings = NSDictionary.init(objects: [AVVideoCodecJPEG], forKeys: [AVVideoCodecKey as NSCopying])
        myStillImageOutput?.outputSettings = myOutputSettings as! [String : Any]
        if (session?.canAddOutput(myStillImageOutput!))! {
            session?.addOutput(myStillImageOutput!)
        }
        
        // 人脸识别
        output = AVCaptureMetadataOutput()
        output?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        if (session?.canAddOutput(output!))! {
            session?.addOutput(output!)
        }
        output?.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
        // preview
        preview = AVCaptureVideoPreviewLayer(session: session!)
        preview?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        preview?.frame = self.view.frame
        
        //人脸识别框
        let faceImg = UIImageView.init(image: UIImage(named: "face"))
        faceImg.frame = CGRect(x: faceX, y: faceY, width: faceW, height: faceH)
        preview?.addSublayer(faceImg.layer)
        self.view.layer.addSublayer(preview!)
        
        //提示文字
        let tipLb = UILabel.init()
        tipLb.frame = CGRect(x: 30, y: 50, width: ScreenWidth - 60, height: 20)
        tipLb.text = "请将面部置于框内识别点名"
        tipLb.font = UIFont.systemFont(ofSize: 20)
        tipLb.textAlignment = .center
        tipLb.textColor = .white
        self.view.addSubview(tipLb)
        
        stateLb = UILabel.init()
        stateLb?.frame = CGRect(x: 50, y:faceImg.frame.maxY + 35 , width: ScreenWidth - 100, height: 20)
        stateLb?.text = "请往人脸图标中心靠拢"
        stateLb?.font = UIFont.systemFont(ofSize: 20)
        stateLb?.textAlignment = .center
        stateLb?.textColor = .white
        self.view.addSubview(stateLb!)
        
//        self.view.layer.insertSublayer(preview!, at: 0)
        session?.startRunning()
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if self.isSuccess == 1 {
            return
        }
        
        for item in metadataObjects {
            if item.type == .face {
                let transform: AVMetadataObject = (preview?.transformedMetadataObject(for: item))!
                DispatchQueue.global().async {
                    DispatchQueue.main.async {
                        if self.showFaceImage(withFrame: transform.bounds) {
                            self.stateLb?.text = "识别成功"
                            self.isSuccess = 1
                            
                            //识别成功，进行自动拍照和上传
                            guard let myStillImageOutputArr = self.myStillImageOutput?.connections else {
                                return
                            }

                            var myVideoConnection: AVCaptureConnection?

                            for myConnection in myStillImageOutputArr {
                                for port in myConnection.inputPorts {
                                    if port.mediaType == .video {
                                        myVideoConnection = myConnection
                                        break
                                    }
                                }
                            }
                            
                            //撷取影像（包含拍照音效）
                            self.myStillImageOutput?.captureStillImageAsynchronously(from: myVideoConnection!, completionHandler: { (imageDataSampleBuffer : CMSampleBuffer?, error : Error?) in
                                
                                if error != nil {
                                    return
                                }
                                //完成撷取时的处理程序(Block)
                                guard let imageDataSampleBuffer = imageDataSampleBuffer  else {
                                    return
                                }
                                //获取图片数据(data)
                                guard let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer) else {
                                    return
                                }
                                
                                //取得的静态影像
                                let myImage = UIImage.init(data: imageData)
                                let transformImage = self.fixOrientation(image: myImage!)
                                self.session?.stopRunning()
                                
                                //图片转化data
                                let imgData = transformImage.jpegData(compressionQuality: 0.5)
                                // 将data转化成 base64的字符串
                                let imageBase64String = imgData?.base64EncodedString()
                                
                                guard let userId = self.userId else {
                                    return
                                }
                                
//                                let param = ["userId":userId,"base64Image":imageBase64String ?? ""] as [String : Any]
//
//                                self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
//
//                                guard let faceBaseUrl = UserDefaults.standard.value(forKey: FaceBaseUrl) else {
//                                    return;
//                                }
//                                let faceUrl = (faceBaseUrl as? String)! + "api/demo/picture/"
//                                CPAFHTTPSessionManager.postJsonToServer(withUrlString: faceUrl, parameter: param, progressBlock: nil, successBlock: { [weak self] (responseObjc) in
//
//                                    let params = ["action":"bind_face_rec","psgId":userId] as [String : Any]
//                                    CPAFHTTPSessionManager.post(withUrlString: Constants.userInfoURL, parameter: params, progressBlock: nil, successBlock: { (responseData) in
//                                        self?.hud?.hide(true)
//                                        self?.refreshFace?()  //刷新之前界面
//                                        Constants.showAlert("人脸注册流程完毕", titleFirst: "确定", handlerFirst: {
//                                            if self?.isAdd == 1 {
//                                                guard let vcArr = self?.navigationController?.viewControllers else {
//                                                    return
//                                                }
//                                                self?.navigationController?.popToViewController(vcArr[vcArr.count - 3], animated: true)
//                                            } else {
//                                                self?.navigationController?.popViewController(animated: true)
//                                            }
//                                        }, title: "提示", titleSecond: nil, handlerSecond: nil)
//
//                                    }, failureBlock: { (error) in
//                                        let desc = error?.localizedDescription
//                                        Constants.showHud(desc ?? String_LoadErrorTip)
//                                    })
//
//                                }, failureBlock: { [weak self] (error) in
//                                    self?.hud?.hide(true)
//                                    Constants.showAlert("人脸注册失败，请重新录制", titleFirst: "确定", handlerFirst: {
//                                        self?.session?.startRunning()
//                                        self?.isSuccess = 0
//                                    }, title: "提示", titleSecond: nil, handlerSecond: nil)
//                                })
                            })
                        } else {
                            print("----识别失败----")
                        }
                    }
                }
            }
        }
    }
    
    /// 判断人脸位置
    func showFaceImage(withFrame rect: CGRect) -> Bool {
        print("-=-=-=\(rect)")
        if rect.origin.x < 50 || rect.origin.x > 100 || rect.origin.y < HEIGHT_DYNAMIC(150) || rect.origin.y > HEIGHT_DYNAMIC(200) {
            stateLb?.text = "请往人脸图标中心靠拢"
            return false
        } else if (rect.size.width < WIDTH_DYNAMIC(150) || rect.size.height < HEIGHT_DYNAMIC(150)) {
            stateLb?.text = "距离屏幕太远了"
            return false
        } else if (rect.size.width > WIDTH_DYNAMIC(200) || rect.size.height > HEIGHT_DYNAMIC(200)) {
            stateLb?.text = "距离屏幕太近了"
            return false
        } else {
            return true
        }
    }
    
    // 修复图片旋转
    func fixOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        var transform = CGAffineTransform.identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
            break
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            break
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -.pi / 2)
            break
            
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            break
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1)
            break
            
        default:
            break
        }
        
        let ctx = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: image.cgImage!.bitsPerComponent, bytesPerRow: 0, space: image.cgImage!.colorSpace!, bitmapInfo: image.cgImage!.bitmapInfo.rawValue)
        ctx?.concatenate(transform)
        
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx?.draw(image.cgImage!, in: CGRect(x: CGFloat(0), y: CGFloat(0), width: CGFloat(image.size.height), height: CGFloat(image.size.width)))
            break
            
        default:
            ctx?.draw(image.cgImage!, in: CGRect(x: CGFloat(0), y: CGFloat(0), width: CGFloat(image.size.width), height: CGFloat(image.size.height)))
            break
        }
        
        let cgimg: CGImage = (ctx?.makeImage())!
        let img = UIImage(cgImage: cgimg)
        
        return img
    }
}

// MARK: - 适配方法
func WIDTH_DYNAMIC(_ width: CGFloat) -> CGFloat {
    return width * ScreenWidth / 375.0
}

func HEIGHT_DYNAMIC(_ height: CGFloat) -> CGFloat {
    return height * ScreenHeight / 667.0
}
