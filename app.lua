local lapis = require("lapis")
local codex_cards = require("codex_cards")
local app = lapis.Application()

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)
app:get("/:cardname", codex_cards.handle_codex)
app:get("/:color/:cardname", codex_cards.handle_codex)
app:get("/:color/:spec/:cardname", codex_cards.handle_codex)

return app
