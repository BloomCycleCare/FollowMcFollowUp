
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:fmfu/logic/cycle_error_simulation.dart';
import 'package:fmfu/logic/cycle_generation.dart';
import 'package:fmfu/logic/cycle_rendering.dart';
import 'package:fmfu/model/chart.dart';
import 'package:fmfu/model/exercise.dart';
import 'package:fmfu/routes.gr.dart';
import 'package:fmfu/utils/distributions.dart';
import 'package:loggy/loggy.dart';
import 'package:time_machine/time_machine.dart';

class StaticExerciseListScreen extends ExerciseListScreen {
  const StaticExerciseListScreen({super.key}) : super(exercises: staticExerciseList);
}

const staticExerciseList = [
  StaticExercise("Book 1: Figure 11-1"),
  StaticExercise("Book 1: Figure 11-2"),
  StaticExercise("Book 1: Figure 11-3"),
  StaticExercise("Book 1: Figure 11-4"),
];

class StaticExercise extends Exercise {
  const StaticExercise(super.name);

  @override
  bool get enabled => false;

  @override
  ExerciseState getState() {
    // TODO: implement getState
    throw UnimplementedError();
  }
}
class DynamicExerciseListScreen extends ExerciseListScreen {
  DynamicExerciseListScreen({super.key}) : super(exercises: dynamicExerciseList);
}

final dynamicExerciseList = [
  const DynamicExercise(name: "Over reading lubrication"),
  DynamicExercise(name: "Continuous Mucus", recipe: CycleRecipe.create(
    prePeakMucusPatchProbability: 1.0,
    postPeakMucusPatchProbability: 1.0,
  )),
  const DynamicExercise(name: "Mucus Cycle > 8 days (reg. Cycles)"),
  const DynamicExercise(name: "Variable return of Peak-type mucus"),
  DynamicExercise(name: "Post-Peak, non-Peak-type mucus", recipe: CycleRecipe.create(
    postPeakMucusPatchProbability: const UniformRange(0.7, 0.9).get(),
  )),
  const DynamicExercise(name: "Post-Peak Pasty"),
  const DynamicExercise(name: "Post-Peak, Peak-type mucus"),
  const DynamicExercise(name: "Premenstrual Spotting"),
  DynamicExercise(name: "Unusual Bleeding", recipe: CycleRecipe.create(
    unusualBleedingProbability: const UniformRange(0.6, 0.9).get(),
  ), errorScenarios: {
    ErrorScenario.forgetObservationOnFlow: 0.4,
    ErrorScenario.forgetRedStampForUnusualBleeding: 0.5,
    ErrorScenario.forgetCountOfThreeForUnusualBleeding: 0.7,
  }),
  const DynamicExercise(name: "Limited Mucus"),
];

class DynamicExercise extends Exercise {
  final CycleRecipe? recipe;
  final Map<ErrorScenario, double> errorScenarios;

  const DynamicExercise({this.recipe, this.errorScenarios = const {}, name}) : super(name);

  @override
  bool get enabled => recipe != null;

  @override
  ExerciseState getState() {
    if (recipe == null) {
      throw StateError("Should not try and get state with a null recipe!");
    }
    final random = Random();
    Set<ErrorScenario> activeScenarios = {};
    errorScenarios.forEach((scenario, probability) {
      if (random.nextDouble() <= probability) {
        activeScenarios.add(scenario);
      }
    });
    final cycles = List.generate(6, (index) {
      final observations = renderObservations(recipe!.getObservations(), []);
      var entries = List.of(observations.map((o) => ChartEntry(
          renderedObservation: o, observationText: o.observationText)));
      entries = introduceErrors(entries, activeScenarios);
      return Cycle(
        index: index,
        entries: entries,
      );
    });
    return ExerciseState([], activeScenarios, cycles, [], LocalDate.today());
  }
}

abstract class Exercise {
  final String name;

  const Exercise(this.name);

  bool get enabled;
  ExerciseState getState();
}

class ExerciseListScreen extends StatefulWidget {
  final List<Exercise> exercises;

  const ExerciseListScreen({super.key, required this.exercises});

  @override
  State<StatefulWidget> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> with GlobalLoggy {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exercise List"),
      ),
      body: ListView.builder(
        itemCount: widget.exercises.length,
        itemBuilder: (context, index) {
          final exercise = widget.exercises[index];
          return Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            const Spacer(),
            ElevatedButton(
              onPressed: exercise.enabled ? () {
                AutoRouter.of(context).push(FollowUpSimulatorPageRoute(exerciseState: exercise.getState()));
              } : null,
              child: Padding(padding: const EdgeInsets.all(10), child: Text(
                exercise.name,
                style: const TextStyle(fontSize: 18),
              )),
            ),
            const Spacer(),
          ]));
        },
      ),
    );
  }
}