import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/task_model.dart';

class GeneratorProvider extends ChangeNotifier {
  // State Management
  String _simplePrompt = "";
  String _advancedPrompt = "";
  double steps = 8;
  double cfg = 1.0;
  String sampler = 'res_multistep';
  double batchSize = 1;
  String aspectRatio = '1:1';
  int? seed;
  bool randomSeed = true;
  int width = 1024;
  int height = 1024;

  // I2I Fields
  bool isI2I = false;
  Uint8List? inputImageBytes;
  String? inputImageFilename;
  String? serverImageName;
  double denoise = 1.0;

  String get simplePrompt => _simplePrompt;
  String get advancedPrompt => _advancedPrompt;
  String get prompt => isI2I ? _advancedPrompt : _simplePrompt;

  void setI2I(bool v) {
    isI2I = v;
    notifyListeners();
  }

  void setInputImage(Uint8List? bytes, String? filename) {
    inputImageBytes = bytes;
    inputImageFilename = filename;
    serverImageName = null;
    notifyListeners();
  }

  void setDenoise(double v) {
    denoise = v;
    notifyListeners();
  }

  void setSimplePrompt(String p) {
    _simplePrompt = p;
    notifyListeners();
  }

  void setAdvancedPrompt(String p) {
    _advancedPrompt = p;
    notifyListeners();
  }

  void setPrompt(String p) {
    if (isI2I) {
      _advancedPrompt = p;
    } else {
      _simplePrompt = p;
    }
    notifyListeners();
  }

  void setSteps(double s) {
    steps = s;
    notifyListeners();
  }

  void setCfg(double c) {
    cfg = c;
    notifyListeners();
  }

  void setSampler(String s) {
    sampler = s;
    notifyListeners();
  }

  void setBatchSize(double b) {
    batchSize = b;
    notifyListeners();
  }

  void setAspectRatio(String a) {
    aspectRatio = a;
    if (a == '1:1') {
      width = 1024;
      height = 1024;
    } else if (a == '16:9') {
      width = 1216;
      height = 688;
    } else if (a == '9:16') {
      width = 688;
      height = 1216;
    } else if (a == '4:3') {
      width = 1152;
      height = 864;
    }
    notifyListeners();
  }

  void setSeed(int? s) {
    seed = s;
    notifyListeners();
  }

  void setRandomSeed(bool r) {
    randomSeed = r;
    notifyListeners();
  }

  void updateFromTask(AiTask task) {
    if (task.workflowMode == 'ADVANCED' || task.type == 'image_edit') {
      _advancedPrompt = task.prompt;
    } else {
      _simplePrompt = task.prompt;
    }
    steps = task.steps.toDouble();
    cfg = task.cfg;
    sampler = task.sampler;
    batchSize = task.batchSize.toDouble();
    seed = task.seed;
    randomSeed = task.seed == null;
    notifyListeners();
  }
}
