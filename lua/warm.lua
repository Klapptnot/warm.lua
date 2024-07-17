-- Warm as module, all in one require

local main = {
  spr = require("warm.spr"),
}

main.color = main.spruce.lazy_require("warm.color")
main.path = main.spruce.lazy_require("warm.path")
main.str = main.spruce.lazy_require("warm.str")
main.table = main.spruce.lazy_require("warm.table")
main.utf8 = main.spruce.lazy_require("warm.utf8")
main.uts = main.spruce.lazy_require("warm.uts")

return main
