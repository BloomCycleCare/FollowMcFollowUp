
import 'package:flutter/material.dart';
import 'package:fmfu/model/chart.dart';
import 'package:fmfu/model/observation.dart';
import 'package:fmfu/model/stickers.dart';
import 'package:fmfu/model/instructions.dart';
import 'package:time_machine/time_machine.dart';

List<RenderedObservation> renderObservations(List<Observation> observations, List<Instruction> activeInstructions, {LocalDate? startDate}) {
  int daysOfFlow = 0;
  int consecutiveDaysOfNonPeakMucus = 0;
  int consecutiveDaysOfPeakMucus = 0;
  CountsOfThree countsOfThree = CountsOfThree();
  bool yesterdayWasEssentiallyTheSame = false;
  int pointOfChangeCount = 0;
  LocalDate? currentDate = startDate;

  List<RenderedObservation> renderedObservations = [];
  for (int i=0; i < observations.length; i++) {
    var observation = observations[i];
    var isPostPeak = countsOfThree.getCount(CountOfThreeReason.peakDay, i) > 0;
    var isPointOfChange = yesterdayWasEssentiallyTheSame && !(observation.essentiallyTheSame ?? false);
    if (isPointOfChange) {
      pointOfChangeCount++;
      if (pointOfChangeCount % 2 == 0) {
        countsOfThree.registerCountStart(CountOfThreeReason.pointOfChange, i);
      }
    }

    if (observation.flow != null) {
      daysOfFlow++;
    }
    bool inFlow = daysOfFlow == i+1;
    bool hasUnusualBleeding = observation.hasBleeding && !inFlow;
    if (hasUnusualBleeding) {
      countsOfThree.registerCountStart(CountOfThreeReason.unusualBleeding, i);
    }

    if (observation.hasPeakTypeMucus) {
      consecutiveDaysOfPeakMucus++;
    } else {
      consecutiveDaysOfPeakMucus = 0;
    }
    if (observation.hasNonPeakTypeMucus) {
      consecutiveDaysOfNonPeakMucus++;
    } else {
      if (!observation.hasMucus && !isPostPeak && consecutiveDaysOfNonPeakMucus >= 3) {
        countsOfThree.registerCountStart(CountOfThreeReason.consecutiveDaysOfNonPeakMucus, i - 1);
      }
      consecutiveDaysOfNonPeakMucus = 0;
    }

    if (observation.hasPeakTypeMucus) {
      countsOfThree.registerCountStart(CountOfThreeReason.singleDayOfPeakMucus, i);
    }

    List<Instruction> fertilityReasons = [];
    if (inFlow) {
      fertilityReasons.add(Instruction.d1);
    }
    // NOTE: This should really check !isPostPeak && observation.hasMucus but...
    if (observation.hasMucus || countsOfThree.inCountOfThree(CountOfThreeReason.peakDay, i)) {
      fertilityReasons.add(Instruction.d2);
    }
    if (!isPostPeak && (consecutiveDaysOfNonPeakMucus > 0 && consecutiveDaysOfNonPeakMucus < 3)) {
      fertilityReasons.add(Instruction.d3);
    }
    if (!isPostPeak && (
        consecutiveDaysOfNonPeakMucus >= 3
        || countsOfThree.inCountOfThree(CountOfThreeReason.consecutiveDaysOfNonPeakMucus, i))) {
      fertilityReasons.add(Instruction.d4);
    }
    if (!isPostPeak && observation.hasPeakTypeMucus) {
      fertilityReasons.add(Instruction.d5);
    }
    if (hasUnusualBleeding || countsOfThree.inCountOfThree(CountOfThreeReason.unusualBleeding, i)) {
      fertilityReasons.add(Instruction.d6);
    }

    bool hasAnotherEntry = i+1 < observations.length;
    bool isPeakDay = !isPointOfChange && hasAnotherEntry && (consecutiveDaysOfPeakMucus > 0 && !observations[i+1].hasPeakTypeMucus);
    if (isPeakDay) {
      countsOfThree.registerCountStart(CountOfThreeReason.peakDay, i);
    }

    if (yesterdayWasEssentiallyTheSame && !(observation.essentiallyTheSame ?? false)) {
      // TODO: re-enable this once I figure out what's up with stickering
      //countsOfThree.registerCountStart(CountOfThreeReason.pointOfChange, i);
    }

    List<Instruction> infertilityReasons = [];
    if (activeInstructions.contains(Instruction.k2) && isPostPeak) {
      infertilityReasons.add(Instruction.k2);
      // I REALLY don't like how this is done...
      if (!countsOfThree.inCountOfThree(CountOfThreeReason.peakDay, i)) {
        fertilityReasons.remove(Instruction.d2);
      }
    }
    if (activeInstructions.contains(Instruction.k1) && (observation.essentiallyTheSame ?? false)) {
      infertilityReasons.add(Instruction.k1);
      fertilityReasons.remove(Instruction.d2);
      fertilityReasons.remove(Instruction.d3);
      fertilityReasons.remove(Instruction.d4);
      fertilityReasons.remove(Instruction.d5);
      countsOfThree.clearCount(CountOfThreeReason.peakDay);
      countsOfThree.clearCount(CountOfThreeReason.consecutiveDaysOfNonPeakMucus);
      countsOfThree.clearCount(CountOfThreeReason.singleDayOfPeakMucus);
    }

    var activeCountOfThreeReason = countsOfThree.getActiveReason(i);
    renderedObservations.add(RenderedObservation(
        observation.toString(),
        countsOfThree.getCount(activeCountOfThreeReason, i),
        isPeakDay,
        observation.hasBleeding,
        observation.hasMucus,
        inFlow,
        fertilityReasons,
        infertilityReasons,
        observation.essentiallyTheSame,
        DebugInfo(
          countOfThreeReason: activeCountOfThreeReason,
        ),
        currentDate,
    ));

    yesterdayWasEssentiallyTheSame = observation.essentiallyTheSame ?? false;
    if (currentDate != null) {
      currentDate = currentDate.addDays(1);
    }
  }
  return renderedObservations;
}

class RenderedObservation {
  final String observationText;
  final int countOfThree;
  final bool isPeakDay;
  final bool hasBleeding;
  final bool hasMucus;
  final bool inFlow;
  final bool? essentiallyTheSame;
  final List<Instruction> fertilityReasons;
  final List<Instruction> infertilityReasons;
  final DebugInfo _debugInfo;
  final LocalDate? date;

  RenderedObservation(this.observationText, this.countOfThree, this.isPeakDay, this.hasBleeding, this.hasMucus, this.inFlow, this.fertilityReasons, this.infertilityReasons, this.essentiallyTheSame, this._debugInfo, this.date);

  String debugInfo() {
    return "{debugInfo: $_debugInfo, essentiallyTheSame: $essentiallyTheSame, fertilityReasons: $fertilityReasons, infertilityReasons: $infertilityReasons}";
  }

  String getObservationText() {
    String text = observationText;
    if (essentiallyTheSame == null) {
      return text;
    }
    if (essentiallyTheSame!) {
      return "$text\nY";
    }
    return "$text\nN";
  }

  String getStickerText() {
    if (hasBleeding) {
      return "";
    }
    if (isPeakDay) {
      return "P";
    }
    if (countOfThree > 0) {
      return countOfThree.toString();
    }
    if (fertilityReasons.isEmpty) {
      return "";
    }
    if (countOfThree > 0) {
      return "$countOfThree";
    }
    return "";
  }

  Sticker getSticker() {
    bool isFertile = fertilityReasons.isNotEmpty;
    bool hasInfertilityReasons = infertilityReasons.isNotEmpty;

    if (inFlow || isFertile) {
      if (hasBleeding) {
        return Sticker.red;
      } else {
        if (hasMucus) {
          return hasInfertilityReasons ? Sticker.yellowBaby : Sticker.whiteBaby;
        } else {
          return Sticker.greenBaby;
        }
      }
    } else {
      return hasMucus ? Sticker.yellow : Sticker.green;
    }
  }
}

class DebugInfo {
  final CountOfThreeReason? countOfThreeReason;

  const DebugInfo({this.countOfThreeReason});

  @override
  String toString() {
    return "{countOfThreeReason: $countOfThreeReason}";
  }
}

enum CountOfThreeReason {
  unusualBleeding,
  peakDay,
  consecutiveDaysOfNonPeakMucus,
  singleDayOfPeakMucus,
  pointOfChange,
  uncertain
}

class CountsOfThree {
  final Map<CountOfThreeReason, int> _countStarts = {};

  void registerCountStart(CountOfThreeReason reason, int i) {
    _countStarts[reason] = i;
  }

  void clearCount(CountOfThreeReason reason) {
    _countStarts.remove(reason);
  }

  CountOfThreeReason? getActiveReason(int i) {
    int minCount = 4;
    CountOfThreeReason? reason;
    _countStarts.forEach((key, index) {
      var count = i - index;
      if (count > 0 && count < minCount) {
        minCount = count;
        reason = key;
      }
    });
    return reason;
  }

  int getCount(CountOfThreeReason? reason, int i) {
    int? countStart = _countStarts[reason];
    if (countStart == null) {
      return 0;
    }
    return i - countStart;
  }

  bool inCountOfThree(CountOfThreeReason reason, int i) {
    int count = getCount(reason, i);
    return count > 0 && count <= 3;
  }
}
