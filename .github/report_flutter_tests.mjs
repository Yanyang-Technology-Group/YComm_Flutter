import { readFileSync } from 'node:fs';

const suites = new Map();
const tests = new Map();
const escapeData = (value) => String(value).replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');
const escapeProperty = (value) => escapeData(value).replaceAll(':', '%3A').replaceAll(',', '%2C');

for (const line of readFileSync(process.argv[2], 'utf8').split(/\r?\n/)) {
  let event;
  try {
    event = JSON.parse(line);
  } catch {
    continue;
  }
  if (event.type === 'suite') suites.set(event.suite.id, event.suite);
  if (event.type === 'testStart') {
    tests.set(event.test.id, { ...event.test, errors: [], output: '' });
  }
  const test = tests.get(event.testID);
  if (!test) continue;
  if (event.type === 'error') test.errors.push(event.error);
  if (event.type === 'print') test.output = (test.output + event.message + '\n').slice(-50000);
  if (event.type === 'testDone') test.result = event.result;
}

let failures = 0;
for (const test of tests.values()) {
  if (test.result !== 'error' && test.result !== 'failure') continue;
  failures++;
  const path = suites.get(test.suiteID)?.path ?? '';
  const marker = path.lastIndexOf('/test/');
  const file = marker >= 0 ? path.slice(marker + 1) : 'test';
  const exceptionStart = test.output.indexOf('EXCEPTION CAUGHT');
  const output = exceptionStart >= 0 ? test.output.slice(exceptionStart) : test.output;
  const message = [test.name, ...test.errors, output].filter(Boolean).join('\n').slice(0, 14000);
  console.log(`::error file=${escapeProperty(file)},title=${escapeProperty(test.name)}::${escapeData(message)}`);
}
console.log(`Flutter failure summaries: ${failures}`);
