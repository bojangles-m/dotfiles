# Opens node documentation for current version
function node-docs {
  local section=${1:-all}
  open "https://nodejs.org/docs/$(node --version)/api/$section.html"
}
