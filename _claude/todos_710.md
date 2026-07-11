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

### KEY REQUIREMENTS FOR USER
1. zsh is a requirement. bash and fish are not supported
2. rbenv is required as version manager
3. ruby 3.4.7+ is only supported. You are to use 4.0.1 as we have been using for this session

ready
    init
    up
    compile
    clobber
    help

init
- prints a very concise zsh snippet to source the ready zsh plugin.
- It should use own introspection to figure out where the plugin lies, and resolve the appropriate path.

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

## P2 – Update the README

1. README needs to be completed. It should be concise, and to the point, following a "show don't tell" model.
2. It should start with adding a `gem install ready`, with a warning that they should not use `bundle install ready`. 
This is intended to be a global process, not a project scoped one
3. It should then instruct the user to add a the ready zsh plugin. They can run `ready init` to generate a "source ....."
statement to put in zshrc or eval directly
4. As you can see I started a table of parameters that can configure ready. You are to finish this table and make it
reflect the current configuration plane

For all of these TODO's, ensure you keep a log of issues in _claude if you come across any.
