package funkin.ui.debug.charting.toolboxes;

import funkin.play.character.BaseCharacter.CharacterType;
import funkin.play.character.CharacterData;
import funkin.play.stage.StageData;
import funkin.play.event.SongEvent;
import funkin.data.event.SongEventData.SongEventSchema;
import funkin.ui.debug.charting.commands.ChangeStartingBPMCommand;
import funkin.ui.debug.charting.util.ChartEditorDropdowns;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.Slider;
import haxe.ui.core.Component;
import funkin.data.event.SongEventData.SongEventParser;
import haxe.ui.components.TextField;
import haxe.ui.containers.Box;
import haxe.ui.containers.Frame;
import haxe.ui.events.UIEvent;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.containers.Grid;
import haxe.ui.components.DropDown;
import haxe.ui.containers.Frame;

/**
 * The toolbox which allows modifying information like Song Title, Scroll Speed, Characters/Stages, and starting BPM.
 */
// @:nullSafety // TODO: Fix null safety when used with HaxeUI build macros.
@:access(funkin.ui.debug.charting.ChartEditorState)
@:build(haxe.ui.ComponentBuilder.build("assets/exclude/data/ui/chart-editor/toolboxes/event-data.xml"))
class ChartEditorEventDataToolbox extends ChartEditorBaseToolbox
{
  var toolboxEventsEventKind:DropDown;
  var toolboxEventsDataFrame:Frame;
  var toolboxEventsDataGrid:Grid;

  var _initializing:Bool = true;

  public function new(chartEditorState2:ChartEditorState)
  {
    super(chartEditorState2);

    initialize();

    this.onDialogClosed = onClose;

    this._initializing = false;
  }

  function onClose(event:UIEvent)
  {
    chartEditorState.menubarItemToggleToolboxEventData.selected = false;
  }

  function initialize():Void
  {
    toolboxEventsEventKind.dataSource = new ArrayDataSource();

    var songEvents:Array<SongEvent> = SongEventParser.listEvents();

    for (event in songEvents)
    {
      toolboxEventsEventKind.dataSource.add({text: event.getTitle(), value: event.id});
    }

    toolboxEventsEventKind.onChange = function(event:UIEvent) {
      var eventType:String = event.data.value;

      trace('ChartEditorToolboxHandler.buildToolboxEventDataLayout() - Event type changed: $eventType');

      // Edit the event data to place.
      chartEditorState.eventKindToPlace = eventType;

      var schema:SongEventSchema = SongEventParser.getEventSchema(eventType);

      if (schema == null)
      {
        trace('ChartEditorToolboxHandler.buildToolboxEventDataLayout() - Unknown event kind: $eventType');
        return;
      }

      buildEventDataFormFromSchema(toolboxEventsDataGrid, schema);

      if (!_initializing && chartEditorState.currentEventSelection.length > 0)
      {
        // Edit the event data of any selected events.
        for (event in chartEditorState.currentEventSelection)
        {
          event.event = chartEditorState.eventKindToPlace;
          event.value = chartEditorState.eventDataToPlace;
        }
        chartEditorState.saveDataDirty = true;
        chartEditorState.noteDisplayDirty = true;
        chartEditorState.notePreviewDirty = true;
      }
    }
    toolboxEventsEventKind.value = chartEditorState.eventKindToPlace;
  }

  public override function refresh():Void
  {
    super.refresh();

    toolboxEventsEventKind.value = chartEditorState.eventKindToPlace;

    for (pair in chartEditorState.eventDataToPlace.keyValueIterator())
    {
      var fieldId:String = pair.key;
      var value:Null<Dynamic> = pair.value;

      var field:Component = toolboxEventsDataGrid.findComponent(fieldId);

      if (field == null)
      {
        throw 'ChartEditorToolboxHandler.refresh() - Field "${fieldId}" does not exist in the event data form.';
      }
      else
      {
        switch (field)
        {
          case Std.isOfType(_, NumberStepper) => true:
            var numberStepper:NumberStepper = cast field;
            numberStepper.value = value;
          case Std.isOfType(_, CheckBox) => true:
            var checkBox:CheckBox = cast field;
            checkBox.selected = value;
          case Std.isOfType(_, DropDown) => true:
            var dropDown:DropDown = cast field;
            dropDown.value = value;
          case Std.isOfType(_, TextField) => true:
            var textField:TextField = cast field;
            textField.text = value;
          default:
            throw 'ChartEditorToolboxHandler.refresh() - Field "${fieldId}" is of unknown type "${Type.getClassName(Type.getClass(field))}".';
        }
      }
    }
  }

  function buildEventDataFormFromSchema(target:Box, schema:SongEventSchema):Void
  {
    trace(schema);
    // Clear the frame.
    target.removeAllComponents();

    chartEditorState.eventDataToPlace = {};

    for (field in schema)
    {
      if (field == null) continue;

      // Add a label for the data field.
      var label:Label = new Label();
      label.text = field.title;
      label.verticalAlign = "center";
      target.addComponent(label);

      // Add an input field for the data field.
      var input:Component;
      switch (field.type)
      {
        case INTEGER:
          var numberStepper:NumberStepper = new NumberStepper();
          numberStepper.id = field.name;
          numberStepper.step = field.step ?? 1.0;
          numberStepper.min = field.min ?? 0.0;
          numberStepper.max = field.max ?? 10.0;
          if (field.defaultValue != null) numberStepper.value = field.defaultValue;
          input = numberStepper;
        case FLOAT:
          var numberStepper:NumberStepper = new NumberStepper();
          numberStepper.id = field.name;
          numberStepper.step = field.step ?? 0.1;
          if (field.min != null) numberStepper.min = field.min;
          if (field.max != null) numberStepper.max = field.max;
          if (field.defaultValue != null) numberStepper.value = field.defaultValue;
          input = numberStepper;
        case BOOL:
          var checkBox:CheckBox = new CheckBox();
          checkBox.id = field.name;
          if (field.defaultValue != null) checkBox.selected = field.defaultValue;
          input = checkBox;
        case ENUM:
          var dropDown:DropDown = new DropDown();
          dropDown.id = field.name;
          dropDown.width = 200.0;
          dropDown.dataSource = new ArrayDataSource();

          if (field.keys == null) throw 'Field "${field.name}" is of Enum type but has no keys.';

          // Add entries to the dropdown.

          for (optionName in field.keys.keys())
          {
            var optionValue:Null<Dynamic> = field.keys.get(optionName);
            trace('$optionName : $optionValue');
            dropDown.dataSource.add({value: optionValue, text: optionName});
          }

          dropDown.value = field.defaultValue;

          input = dropDown;
        case STRING:
          input = new TextField();
          input.id = field.name;
          if (field.defaultValue != null) input.text = field.defaultValue;
        default:
          // Unknown type. Display a label that proclaims the type so we can debug it.
          input = new Label();
          input.id = field.name;
          input.text = field.type;
      }

      target.addComponent(input);

      // Update the value of the event data.
      input.onChange = function(event:UIEvent) {
        var value = event.target.value;
        if (field.type == ENUM)
        {
          value = event.target.value.value;
        }

        trace('ChartEditorToolboxHandler.buildEventDataFormFromSchema() - ${event.target.id} = ${value}');

        // Edit the event data to place.
        if (value == null)
        {
          chartEditorState.eventDataToPlace.remove(event.target.id);
        }
        else
        {
          chartEditorState.eventDataToPlace.set(event.target.id, value);
        }

        // Edit the event data of any existing events.
        if (!_initializing && chartEditorState.currentEventSelection.length > 0)
        {
          for (event in chartEditorState.currentEventSelection)
          {
            event.event = chartEditorState.eventKindToPlace;
            event.value = chartEditorState.eventDataToPlace;
          }
          chartEditorState.saveDataDirty = true;
          chartEditorState.noteDisplayDirty = true;
          chartEditorState.notePreviewDirty = true;
        }
      }
    }
  }

  public static function build(chartEditorState:ChartEditorState):ChartEditorEventDataToolbox
  {
    return new ChartEditorEventDataToolbox(chartEditorState);
  }
}
