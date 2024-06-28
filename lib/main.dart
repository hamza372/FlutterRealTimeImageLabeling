import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

late List<CameraDescription> _cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;
  bool isBusy = false;
  String result = "";
  late ImageLabeler imageLabeler;

  @override
  void initState() {
    super.initState();
    imageLabeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    controller = CameraController(
      _cameras[1],
      ResolutionPreset.max,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888,
    );
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy) {isBusy = true, doImageLabeling(image)}
          });

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  doImageLabeling(CameraImage img) async {
    result = "";
    InputImage? inputImg = _inputImageFromCameraImage(img);
    if (inputImg != null) {
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImg);
      for (ImageLabel label in labels) {
        final String text = label.label;
        final int index = label.index;
        final double confidence = label.confidence;
        result += "$text   ${confidence.toStringAsFixed(2)}\n";
      }
      setState(() {
        result;
        isBusy = false;
      });
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = _cameras[1];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Realtime',style: TextStyle(color: Colors.white),),centerTitle: true,
      ),
      body: Center(
          child: SingleChildScrollView(
           // padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
            controller.value.isInitialized
                ? Container(
                  margin: EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: MediaQuery.of(context).size.height - 300,
                            child: controller.value.isInitialized
                                ? AspectRatio(
                                    child: CameraPreview(controller),
                                    aspectRatio: controller.value.aspectRatio,
                                  )
                                : Container(),
                          ),
                        ),
                      Container(
                        child: Image.asset(
                          "images/f1.png",
                          fit: BoxFit.fill,
                        ),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height - 300,
                        padding: EdgeInsets.all(10),
                      ),
                    ],
                  ),
                )
                : Container(),
                      // Card(
                      //   margin: EdgeInsets.all(10),
                      //   color: Colors.blue,
                      //   child: Container(
                      //     height: 100,
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //       children: [
                      //         InkWell(
                      //           child: Icon(
                      //             Icons.image,
                      //             size: 50,
                      //           ),
                      //           onTap: () {
                      //
                      //           },
                      //         ),
                      //         Divider(),
                      //         InkWell(
                      //           child: Icon(
                      //             Icons.camera,
                      //             size: 50,
                      //           ),
                      //           onTap: () {
                      //
                      //           },
                      //         )
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      Card(
                        color: Colors.blue,
                        margin: EdgeInsets.all(10),
                        child: Container(
                          height: 150,
                          padding: EdgeInsets.all(10),
                          width: MediaQuery.of(context).size.width,
                          child: Container(
                            child: Text(result,style: TextStyle(fontSize: 18,color: Colors.white),),
                          ),
                        ),
                      )
                    ],
                  ),
          )),
    );
  }
}
