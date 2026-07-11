## P0 Issues

1. Add by to gemspec as dependency, along with any other hard deps that are       
   missing
2. there is a bug right now where running rake -T fails, if .readyfile is not     
   present in ~/. This should not happen. Ensure that the dependency tree is still   
   enforced but that running rake still succeeds
3. the cli interface needs to be reshaped:

## P1 – NEW RUBY CLI SHAPE

First and foremost. YOU MUST READ THOROUGHLY THE COMMAND KIT SOURCE CODE IN REFERENCES/command_kit. You must then
use the command_kit cli library to power the ready cli. It should be idiomatic with respect to command_kit, and you
must not duplicate any functionality that it already provides.

ready
up
compile
clobber
help

up
- compiles all stubs and starts server (`rake ready`)

compile <all|[cli name]>
- when "all"
    - compiles all stubs `rake compile`
- when "[cli name]"
    - runs what `ready gem <cli name>` current does
    - This should also accept "by" as a cli name, doing what "ready by" currently does

clobber
- runs rake clobber

help
- prints the help menu using idiomatic command kit
