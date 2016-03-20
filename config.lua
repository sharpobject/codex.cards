local config = require("lapis.config")

config("development", {
  port = 8080
})

config("production", {
  port = 8000,
  num_workers = 1,
  code_cache = "on"
})