enum AcAction {
  turnOn('turn_on'),
  turnOff('turn_off'),
  setTemperature('set_temperature');

  const AcAction(this.value);

  final String value;
}
