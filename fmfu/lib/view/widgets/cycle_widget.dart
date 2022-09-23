import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fmfu/logic/cycle_rendering.dart';
import 'package:fmfu/model/chart.dart';
import 'package:fmfu/model/stickers.dart';
import 'package:fmfu/view/widgets/chart_cell_widget.dart';
import 'package:fmfu/view/widgets/chart_row_widget.dart';
import 'package:fmfu/view/widgets/chart_widget.dart';
import 'package:fmfu/view/widgets/cycle_stats_widget.dart';
import 'package:fmfu/view/widgets/sticker_widget.dart';
import 'package:fmfu/view_model/chart_list_view_model.dart';
import 'package:loggy/loggy.dart';
import 'package:provider/provider.dart';

class CycleWidget extends StatefulWidget {
  final Cycle? cycle;
  final bool showStats;
  final int dayOffset;
  final bool editingEnabled;
  final bool showErrors;
  final SoloCell? soloCell;

  static const int nSectionsPerCycle = 5;
  static const int nEntriesPerSection = 7;

  const CycleWidget({
    required this.cycle,
    this.editingEnabled = false,
    this.showErrors = false,
    this.showStats = true,
    this.dayOffset = 0,
    this.soloCell,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => CycleWidgetState();
}

class CycleWidgetState extends State<CycleWidget> with UiLoggy {
  @override
  Widget build(BuildContext context) {
    return ChartRowWidget(
      dayOffset: widget.dayOffset,
      topCellCreator: _createStickerCell,
      bottomCellCreator: _createObservationCell,
    );
  }

  ChartEntry? _getChartEntry(int entryIndex) {
    var hasCycle = widget.cycle != null;
    if (widget.soloCell == null && hasCycle && entryIndex < widget.cycle!.entries.length) {
      return widget.cycle?.entries[entryIndex];
    } else if (widget.soloCell != null && widget.soloCell!.entryIndex == entryIndex) {
      return widget.cycle?.entries[entryIndex];
    }
    return null;
  }

  Widget _createObservationCell(int entryIndex) {
    var entry = _getChartEntry(entryIndex);
    RenderedObservation? observation = entry?.renderedObservation;

    var textBackgroundColor = Colors.white;
    if (widget.showErrors && (entry?.hasErrors() ?? false)) {
      textBackgroundColor = const Color(0xFFEECDCD);
    }
    String? observationCorrection = widget.cycle?.observationCorrections[entryIndex];
    bool hasObservationCorrection = observation != null && observationCorrection != null;
    var content = RichText(text: TextSpan(
      style: const TextStyle(fontSize: 10),
      children: [
        TextSpan(
          text: entry == null ? "" : entry.observationText,
          style: hasObservationCorrection ? const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 10) : null,
        ),
        if (hasObservationCorrection) TextSpan(
          text: "\n$observationCorrection",
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      ],
    ));
    return ChartCellWidget(
      content: content,
      /*content: Text(
          content,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),*/
      backgroundColor: textBackgroundColor,
      onTap: (entry == null) ? () {} : _showEditDialog(context, entryIndex, entry, observationCorrection),
    );
  }

  Widget _createStickerCell(int entryIndex) {
    var soloingCell = widget.soloCell != null && widget.soloCell!.entryIndex == entryIndex;
    var entry = _getChartEntry(entryIndex);
    RenderedObservation? observation = entry?.renderedObservation;

    StickerWithText? sticker = entry?.manualSticker;
    if (sticker == null && observation != null) {
      sticker = StickerWithText(observation.getSticker(), observation.getStickerText());
    }
    if (soloingCell && !widget.soloCell!.showSticker) {
      sticker = StickerWithText(Sticker.grey, "?");
    }
    Widget stickerWidget = StickerWidget(
      stickerWithText: sticker,
      onTap: observation != null ? _showCorrectionDialog(context, entryIndex, null) : () {},
    );
    StickerWithText? stickerCorrection = widget.cycle?.stickerCorrections[entryIndex];
    if (observation != null && stickerCorrection != null) {
      stickerWidget = Stack(children: [
        stickerWidget,
        Transform.rotate(
          angle: -pi / 12.0,
          child: StickerWidget(
            stickerWithText: StickerWithText(
              stickerCorrection.sticker, stickerCorrection.text,
            ),
            onTap: _showCorrectionDialog(context, entryIndex, stickerCorrection),
          ),
        )
      ]);
    }
    return stickerWidget;
  }

  void Function() _showEditDialog(
      BuildContext context,
      int entryIndex,
      ChartEntry entry,
      String? correction) {
    return () {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ObservationEditDialog(cycle: widget.cycle!, entry: entry, entryIndex: entryIndex);
        },
      );
    };
  }

  void Function() _showCorrectionDialog(
      BuildContext context,
      int entryIndex,
      StickerWithText? existingCorrection) {
    return () {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StickerCorrectionDialog(entryIndex: entryIndex, cycle: widget.cycle!, editingEnabled: widget.editingEnabled);
        },
      );
    };
  }
}

class StickerCorrectionDialog extends StatelessWidget with UiLoggy {
  final Cycle cycle;
  final int entryIndex;
  final bool editingEnabled;
  final StickerWithText? existingCorrection;

  const StickerCorrectionDialog({Key? key, required this.entryIndex, this.existingCorrection, required this.cycle, required this.editingEnabled}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Sticker? selectedSticker = existingCorrection?.sticker;
    String? selectedStickerText = existingCorrection?.text;
    return StatefulBuilder(builder: (context, setState) {
      return Consumer<ChartListViewModel>(
          builder: (context, model, child) => AlertDialog(
            title: const Text('Sticker Correction'),
            content: _createStickerCorrectionContent(selectedSticker, selectedStickerText, (sticker) {
              setState(() {
                if (selectedSticker == sticker) {
                  selectedSticker = null;
                } else {
                  selectedSticker = sticker;
                }
              });
            }, (text) {
              setState(() {
                if (selectedStickerText == text) {
                  selectedStickerText = null;
                } else {
                  selectedStickerText = text;
                }
              });
            }),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'Cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  StickerWithText? correction;
                  if (selectedSticker != null) {
                    correction = StickerWithText(selectedSticker!, selectedStickerText);
                  }
                  if (!editingEnabled) {
                    model.updateStickerCorrections(cycle.index, entryIndex, correction);
                  } else {
                    model.editSticker(cycle.index, entryIndex, correction);
                  }
                  Navigator.pop(context, 'OK');
                },
                child: const Text('OK'),
              ),
            ],
          ));
    });
  }

  Widget _createStickerCorrectionContent(Sticker? selectedSticker, String? selectedStickerText, void Function(Sticker?) onSelectSticker, void Function(String?) onSelectText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(padding: EdgeInsets.all(10), child: Text("Select the correct sticker")),
        StickerSelectionRow(selectedSticker: selectedSticker, onSelect: onSelectSticker),
        const Padding(padding: EdgeInsets.all(10), child: Text("Select the correct text")),
        StickerTextSelectionRow(selectedText: selectedStickerText, onSelect: onSelectText),
      ],
    );
  }

}

class StickerSelectionRow extends StatelessWidget {
  final bool includeYellow;
  final Sticker? selectedSticker;
  final void Function(Sticker?) onSelect;

  const StickerSelectionRow({super.key, this.selectedSticker, required this.onSelect, this.includeYellow = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _createDialogSticker(Sticker.red, selectedSticker, onSelect),
        _createDialogSticker(Sticker.green, selectedSticker, onSelect),
        _createDialogSticker(Sticker.greenBaby, selectedSticker, onSelect),
        _createDialogSticker(Sticker.whiteBaby, selectedSticker, onSelect),
        if (includeYellow) _createDialogSticker(Sticker.yellow, selectedSticker, onSelect),
        if (includeYellow) _createDialogSticker(Sticker.yellowBaby, selectedSticker, onSelect),
      ],
    );
  }
}

Widget _createDialogSticker(Sticker sticker, Sticker? selectedSticker, void Function(Sticker?) onSelect) {
  Widget child = StickerWidget(stickerWithText: StickerWithText(sticker, null), onTap: () => onSelect(sticker));
  if (selectedSticker == sticker) {
    child = Container(
      decoration: BoxDecoration(
        border: Border.all(color:Colors.black),
      ),
      child: child,
    );
  }
  return Padding(padding: const EdgeInsets.all(2), child: child);
}

class StickerTextSelectionRow extends StatelessWidget {
  final String? selectedText;
  final void Function(String?) onSelect;

  const StickerTextSelectionRow({super.key, this.selectedText, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _createDialogTextSticker("", selectedText, onSelect),
        _createDialogTextSticker("P", selectedText, onSelect),
        _createDialogTextSticker("1", selectedText, onSelect),
        _createDialogTextSticker("2", selectedText, onSelect),
        _createDialogTextSticker("3", selectedText, onSelect),
      ],
    );
  }
}

Widget _createDialogTextSticker(String text, String? selectedText, void Function(String?) onSelect) {
  Widget sticker = StickerWidget(stickerWithText: StickerWithText(Sticker.white, text), onTap: () => onSelect(text));
  if (selectedText == text) {
    sticker = Container(
      decoration: BoxDecoration(
        border: Border.all(color:Colors.black),
      ),
      child: sticker,
    );
  }
  return Padding(padding: const EdgeInsets.all(2), child: sticker);
}


class ObservationEditDialog extends StatelessWidget with UiLoggy {
  final Cycle cycle;
  final ChartEntry entry;
  final int entryIndex;
  final String? correction;

  const ObservationEditDialog({super.key, required this.cycle, required this.entry, this.correction, required this.entryIndex});

  @override
  Widget build(BuildContext context) {
    var formKey = GlobalKey<FormState>();
    var cycleIndex = cycle.index;
    return Consumer<ChartListViewModel>(builder: (context, model, child) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(model.editEnabled ? "Edit Observation" : "Correct Observation"),
      content: Form(
        key: formKey,
        child: TextFormField(
          initialValue: model.editEnabled ? entry.observationText : correction ?? entry.observationText,
          validator: (value) {
            if (!model.editEnabled && (value == null || value.isEmpty)) {
              return 'Please enter some text';
            }
            return null;
          },
          onSaved: (value) {
            if (model.editEnabled) {
              if (value == null) {
                throw Exception(
                    "Validation should have prevented saving a null value");
              }
              loggy.debug("Editing entry to be $value for cycle #$cycleIndex, entry #$entryIndex");
              model.editEntry(cycleIndex, entryIndex, value);
            } else {
              loggy.debug("Updating observation correction to be $value for cycle #$cycleIndex, entry #$entryIndex");
              model.updateObservationCorrections(cycleIndex, entryIndex, value);
            }
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, 'Cancel'),
          child: const Text('Cancel'),
        ),
        if (!model.editEnabled && correction != null) TextButton(
          onPressed: () {
            model.updateObservationCorrections(cycleIndex, entryIndex, null);
            Navigator.pop(context, 'CLEAR');
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              formKey.currentState!.save();
              Navigator.pop(context, 'OK');
            }
          },
          child: const Text('OK'),
        ),
      ],
    )));
  }
}