import 'package:fmfu/logic/cycle_generation.dart';
import 'package:fmfu/view_model/chart_view_model.dart';
import 'package:flutter/material.dart';

class FollowUpSimulatorViewModel extends ChartViewModel with ChangeNotifier {

  bool showFollowUpForm = false;
  bool showErrors = false;
  int chartIndex = 0;

  FollowUpSimulatorViewModel() : super(6) {
    updateCharts(CycleRecipe.create(), numCycles: 12);
  }

  @override
  void onChartChange() {
    notifyListeners();
  }

  void toggleShowFollowUpForm() {
    showFollowUpForm = !showFollowUpForm;
    notifyListeners();
  }

  void toggleShowErrors() {
    showErrors = !showErrors;
    notifyListeners();
  }

  bool showNextButton() {
    return chartIndex < charts.length - 1;
  }

  bool showPreviousButton() {
    return chartIndex > 0;
  }

  void moveToNextChart() {
    if (!showNextButton()) {
      throw Exception("Cannot move to next!");
    }
    chartIndex++;
    notifyListeners();
  }

  void moveToPreviousChart() {
    if (!showPreviousButton()) {
      throw Exception("Cannot move to previous!");
    }
    chartIndex--;
    notifyListeners();
  }

  void setLengthOfPostPeakPhase(int cycleIndex, int? length) {
    var cycle = findCycle(cycleIndex);
    if (cycle == null) {
      throw Exception("Could not find cycle at index $cycleIndex");
    }
    cycle.cycleStats = cycle.cycleStats.setLengthOfPostPeakPhase(length);
    notifyListeners();
  }

  void setMucusCycleScore(int cycleIndex, double? score) {
    var cycle = findCycle(cycleIndex);
    if (cycle == null) {
      throw Exception("Could not find cycle at index $cycleIndex");
    }
    cycle.cycleStats = cycle.cycleStats.setMucusCycleScore(score);
    notifyListeners();
  }
}
