--!strict
-- Minimal test runner for Lune. Each suite is a function(t) that uses
-- t.eq / t.ok / t.approx to record assertions.
local process = require("@lune/process")

local passed, failed = 0, 0
local t = {
	eq = function(a: any, b: any, msg: string)
		if a == b then
			passed += 1
		else
			failed += 1
			print(`  FAIL: {msg} (expected {tostring(b)}, got {tostring(a)})`)
		end
	end,
	ok = function(cond: boolean, msg: string)
		if cond then
			passed += 1
		else
			failed += 1
			print(`  FAIL: {msg}`)
		end
	end,
	approx = function(a: number, b: number, tol: number, msg: string)
		if math.abs(a - b) <= tol then
			passed += 1
		else
			failed += 1
			print(`  FAIL: {msg} (expected ~{b}, got {a})`)
		end
	end,
}

-- Explicitly list suites (robust: no dynamic require).
local suites = {
	{ name = "WeightedRoll", run = require("./WeightedRoll.test") },
	{ name = "Config", run = require("./Config.test") },
	{ name = "FormulaModule", run = require("./FormulaModule.test") },
}

for _, suite in suites do
	print(`Running {suite.name}`)
	suite.run(t)
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
