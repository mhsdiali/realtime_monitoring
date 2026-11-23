enum AcAction {
  turnOn('turn_on'),
  turnOff('turn_off'),
  setTemperature('set_temperature'),
  setJet('set_jet'),
  setSwing('set_swing');

  const AcAction(this.value);

  final String value;
}
