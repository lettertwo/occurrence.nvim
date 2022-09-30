local create_actions = require("occurrency.action").create_actions

local M = {}

function M.run()
  print("operation.run")
end

return create_actions(M)
