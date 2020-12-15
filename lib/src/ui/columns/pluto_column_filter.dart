import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';

class PlutoColumnFilter extends PlutoStatefulWidget {
  final PlutoStateManager stateManager;
  final PlutoColumn column;

  PlutoColumnFilter({
    this.stateManager,
    this.column,
  });

  @override
  _PlutoColumnFilterState createState() => _PlutoColumnFilterState();
}

abstract class _PlutoColumnFilterStateWithChange
    extends PlutoStateWithChange<PlutoColumnFilter> {
  FocusNode focusNode;

  TextEditingController controller;

  List<PlutoRow> filterRows;

  String text;

  bool enabled;

  StreamSubscription event;

  String get filterValue {
    return filterRows.isEmpty
        ? ''
        : filterRows.first.cells[FilterHelper.filterFieldValue].value;
  }

  bool get hasCompositeFilter {
    return filterRows.length > 1 ||
        widget.stateManager
            .filterRowsByField(FilterHelper.filterFieldAllColumns)
            .isNotEmpty;
  }

  @override
  initState() {
    super.initState();

    focusNode = FocusNode(onKey: handleOnKey);

    widget.column.setFilterFocusNode(focusNode);

    controller = TextEditingController(text: filterValue);

    event = widget.stateManager.eventManager.listener(handleFocusFromRows);
  }

  @override
  dispose() {
    event.cancel();

    controller.dispose();

    focusNode.dispose();

    super.dispose();
  }

  @override
  void onChange() {
    resetState((update) {
      filterRows = update<List<PlutoRow>>(
        filterRows,
        widget.stateManager.filterRowsByField(widget.column.field),
      );

      if (focusNode?.hasPrimaryFocus != true) {
        text = update<String>(text, filterValue);

        if (changed) {
          controller?.text = text;
        }
      }

      enabled = update<bool>(
        enabled,
        widget.column.enableFilterMenuItem && !hasCompositeFilter,
      );
    });
  }

  bool handleOnKey(FocusNode node, RawKeyEvent event) {
    var keyManager = KeyManagerEvent(
      focusNode: node,
      event: event,
    );

    if (keyManager.isKeyDownEvent) {
      if (keyManager.isDown || keyManager.isEnter) {
        if (widget.stateManager.refRows.isNotEmpty) {
          focusNode.unfocus();

          if (widget.stateManager.currentCell == null) {
            widget.stateManager.setCurrentCell(
              widget.stateManager.refRows.first.cells[widget.column.field],
              0,
              notify: false,
            );
          }

          widget.stateManager.setKeepFocus(true);
        }
      } else if (keyManager.isTab ||
          (controller.text.isEmpty && keyManager.isHorizontal)) {
        widget.stateManager.nextFocusOfColumnFilter(
          widget.column,
          reversed: keyManager.isLeft || keyManager.isShiftPressed,
        );
      }
    }

    return true;
  }

  void handleFocusFromRows(PlutoEvent plutoEvent) {
    if (!enabled) {
      return;
    }

    if (plutoEvent is PlutoCannotMoveCurrentCellEvent &&
        plutoEvent.direction.isUp) {
      var isCurrentColumn = widget
              .stateManager
              .refColumns[widget.stateManager
                  .columnIndexesByShowFrozen[plutoEvent.cellPosition.columnIdx]]
              .key ==
          widget.column.key;

      if (isCurrentColumn) {
        widget.stateManager.clearCurrentCell(notify: false);
        widget.stateManager.setKeepFocus(false);
        focusNode.requestFocus();
      }
    }
  }
}

class _PlutoColumnFilterState extends _PlutoColumnFilterStateWithChange {
  InputBorder get border => OutlineInputBorder(
        borderSide: BorderSide(
            color: widget.stateManager.configuration.borderColor, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get enabledBorder => OutlineInputBorder(
        borderSide: BorderSide(
            color: widget.stateManager.configuration.activatedBorderColor,
            width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  Color get textFieldColor => enabled
      ? widget.stateManager.configuration.cellColorInEditState
      : widget.stateManager.configuration.cellColorInReadOnlyState;

  void handleOnTap() {
    widget.stateManager.setKeepFocus(false);
  }

  void handleOnChanged(String changed) {
    widget.stateManager.eventManager.addEvent(
      PlutoChangeColumnFilterEvent(
        columnField: widget.column.field,
        filterType: PlutoFilterTypeContains(),
        filterValue: changed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.column.width,
      height: widget.stateManager.columnHeight,
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Align(
        alignment: Alignment.center,
        child: Stack(
          children: [
            TextField(
              focusNode: focusNode,
              controller: controller,
              enabled: enabled,
              style: widget.stateManager.configuration.cellTextStyle,
              onTap: handleOnTap,
              onChanged: handleOnChanged,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: textFieldColor,
                border: border,
                enabledBorder: border,
                focusedBorder: enabledBorder,
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
