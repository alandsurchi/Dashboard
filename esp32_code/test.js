const tests = [
  '{"gardenPumpRunning":true}',
  '{"systemEnabled":false}',
  '{"autoGardenMode":true}'
];

tests.forEach(t => {
  if (t.includes('"gardenPumpRunning":true')) console.log("PUMP_ON");
  else if (t.includes('"systemEnabled":false')) console.log("SYS_OFF");
  else if (t.includes('"autoGardenMode":true')) console.log("AUTO_ON");
  else console.log("MISSING");
});
