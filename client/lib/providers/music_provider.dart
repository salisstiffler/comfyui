import 'package:flutter/material.dart';

class MusicGeneratorProvider extends ChangeNotifier {
  String prompt = "";
  String tags = "acoustic ballad, indie pop, soothing melancholy";
  String lyrics = "[intro]\n(Piano intro)\n[verse]\nRain falls softly...";
  bool isSimpleMode = true;
  int bpm = 190;
  int duration = 120;
  double cfg = 2.0;
  int? seed;
  bool randomSeed = true;

  void setPrompt(String p) {
    prompt = p;
    notifyListeners();
  }

  void setIsSimpleMode(bool s) {
    isSimpleMode = s;
    notifyListeners();
  }

  void setTags(String t) {
    tags = t;
    notifyListeners();
  }

  void setLyrics(String l) {
    lyrics = l;
    notifyListeners();
  }

  void setBpm(double b) {
    bpm = b.toInt();
    notifyListeners();
  }

  void setDuration(double d) {
    duration = d.toInt();
    notifyListeners();
  }

  void setCfg(double c) {
    cfg = c;
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
}
