import 'package:dashbord/services/dashboard_state.dart';

enum _VoiceAction { on, off, none }

class VoiceCommandService {
  String executeCommand(String rawCommand, DashboardState state) {
    final command = _normalize(rawCommand);
    if (command.isEmpty) {
      return 'I did not hear a command.';
    }

    final action = _extractAction(command);
    if (action == _VoiceAction.none) {
      return 'Please say on or off (or open or close).';
    }

    final turnOn = action == _VoiceAction.on;

    if (_matches(command, const ['garage', 'garage door', 'كراج', 'باب الكراج', 'المراب'])) {
      state.setGarageDoor(turnOn, source: 'voice');
      return turnOn ? 'Opening garage door.' : 'Closing garage door.';
    }

    if ((_matches(command, const ['main door', 'front door', 'main gate', 'باب البيت', 'الباب الرئيسي']) ||
            _matches(command, const ['door', 'باب'])) &&
        !_matches(command, const ['garage'])) {
      state.setDoor(turnOn ? 'OPEN' : 'CLOSED');
      return turnOn ? 'Opening main door.' : 'Closing main door.';
    }

    if (_matches(command, const ['all lights', 'all light', 'lights', 'all the lights', 'كل الاضواء', 'كل الاضويه', 'كل الانوار'])) {
      state.toggleLed1(turnOn);
      state.toggleLed2(turnOn);
      state.toggleLed3(turnOn);
      state.toggleRgb(turnOn);
      return turnOn ? 'Turning all lights on.' : 'Turning all lights off.';
    }

    if (_matches(command, const ['led 1', 'led1', 'light 1', 'light one', 'led one', 'ليد 1', 'لمبة 1', 'ضو 1'])) {
      state.toggleLed1(turnOn);
      return turnOn ? 'Turning LED 1 on.' : 'Turning LED 1 off.';
    }

    if (_matches(command, const ['led 2', 'led2', 'light 2', 'light two', 'led two', 'ليد 2', 'لمبة 2', 'ضو 2'])) {
      state.toggleLed2(turnOn);
      return turnOn ? 'Turning LED 2 on.' : 'Turning LED 2 off.';
    }

    if (_matches(command, const ['led 3', 'led3', 'light 3', 'light three', 'led three', 'ليد 3', 'لمبة 3', 'ضو 3'])) {
      state.toggleLed3(turnOn);
      return turnOn ? 'Turning LED 3 on.' : 'Turning LED 3 off.';
    }

    if (_matches(command, const ['rgb', 'rgb light', 'color light', 'colour light', 'ضوء ملون', 'ليد ملون'])) {
      state.toggleRgb(turnOn);
      return turnOn ? 'Turning RGB light on.' : 'Turning RGB light off.';
    }

    if (_matches(command, const ['fan', 'مروحة'])) {
      state.toggleFan(turnOn);
      return turnOn ? 'Turning fan on.' : 'Turning fan off.';
    }

    if (_matches(command, const ['tv', 'television', 'تلفزيون'])) {
      state.toggleTv(turnOn);
      return turnOn ? 'Turning TV on.' : 'Turning TV off.';
    }

    if (_matches(command, const ['wash', 'washing machine', 'washer', 'غسالة'])) {
      state.toggleWash(turnOn);
      return turnOn ? 'Turning washing machine on.' : 'Turning washing machine off.';
    }

    if (_matches(command, const ['garden pump', 'water pump', 'soil pump', 'مضخة الحديقة', 'مضخة الماء'])) {
      state.toggleGardenPump(turnOn);
      return turnOn ? 'Turning garden pump on.' : 'Turning garden pump off.';
    }

    if (_matches(command, const ['fire pump', 'مضخة الحريق', 'مضخة النار'])) {
      state.toggleFirePump(turnOn);
      return turnOn ? 'Turning fire pump on.' : 'Turning fire pump off.';
    }

    return 'Command not recognized. Try: turn on LED 1, open garage, turn off fan.';
  }

  _VoiceAction _extractAction(String command) {
    const onPhrases = [
      'turn on',
      'switch on',
      'power on',
      'start',
      'open',
      'enable',
      'on',
      'شغل',
      'شغ ل',
      'افتح',
      'فتح',
      'شغللي',
    ];

    const offPhrases = [
      'turn off',
      'switch off',
      'power off',
      'stop',
      'close',
      'disable',
      'shut',
      'off',
      'طفي',
      'اطفي',
      'اغلق',
      'سكر',
      'قفل',
      'اقفل',
    ];

    if (onPhrases.any(command.contains)) {
      return _VoiceAction.on;
    }

    if (offPhrases.any(command.contains)) {
      return _VoiceAction.off;
    }

    if (RegExp(r'\bon\b').hasMatch(command)) {
      return _VoiceAction.on;
    }

    if (RegExp(r'\boff\b').hasMatch(command)) {
      return _VoiceAction.off;
    }

    return _VoiceAction.none;
  }

  bool _matches(String command, List<String> aliases) {
    return aliases.any(command.contains);
  }

  String _normalize(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }
}
