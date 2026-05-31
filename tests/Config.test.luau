--!strict
local ItemConfig = require("../src/shared/Modules/ItemConfig")
local MutationConfig = require("../src/shared/Modules/MutationConfig")

return function(t)
	-- Every creature has the required fields and positive values.
	for id, c in ItemConfig do
		t.ok(type(c.Name) == "string" and #c.Name > 0, `{id} has Name`)
		t.ok(type(c.Weight) == "number" and c.Weight > 0, `{id} Weight > 0`)
		t.ok(type(c.BaseIncome) == "number" and c.BaseIncome >= 0, `{id} BaseIncome >= 0`)
		t.ok(type(c.Color) == "table" and #c.Color == 3, `{id} has Color rgb`)
		t.ok(type(c.Rarity) == "string" and #c.Rarity > 0, `{id} has Rarity`)
	end
	-- Mutations include a neutral "None" with Mult == 1.
	t.eq(MutationConfig.None.Mult, 1, "None mult is 1")
	for name, m in MutationConfig do
		t.ok(m.Weight > 0, `{name} weight > 0`)
		t.ok(m.Mult >= 1, `{name} mult >= 1`)
	end
end
