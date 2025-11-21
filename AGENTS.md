# AGENTS.md

## Project overview

**classnt** is an experimental Ruby library for expressing business logic in a more functional way.  
The project is inspired by Dave Thomas’ argument that many Ruby “service objects” do not need to be classes at all.  
When state or identity are not required, **modules and functions** are preferred over instantiation and OOP ceremony.

Relevant reference:  
https://media.pragprog.com/newsletters/2025-07-29.html

The ideas currently being explored include:

- Result tuples: `[:ok, value]` and `[:failure, error]`
- Optional monadic abstractions
- Procedural composition (pipeline-like flows)
- Pattern matching for control flow
- Optional wrapping of operations inside Active Record transactions
- Declarative Pipeline DSL

---

## Usage

### Declarative Pipeline (Recommended)

Use `Classnt::Pipeline` to define pipelines cleanly inside modules.

```ruby
module CoffeeMachine
  extend Classnt::Pipeline

  pipeline :brew, transaction: true do
    step :grind_beans
    step :brew_coffee
    step :pour_into_cup
  end

  private

  def grind_beans(coffee_type)
    [:ok, "ground #{coffee_type}"]
  end
  
  # ... other steps ...
end
```

When you `extend Classnt::Pipeline` in a module:
1. It provides the `pipeline` macro.
2. It automatically makes your instance methods available as class methods (similar to `module_function`), so you don't need extra boilerplate.

---

## Setup

- Install deps: `bundle install`
- Run tests: `bundle exec rake test`

Tests use **Minitest**.

---

## Notes for agents

- Keep changes small and conceptual until the API solidifies.
- Prefer documentation and written design notes over premature code.
- Avoid adding DSLs, metaprogramming, or class-heavy abstractions unless requested.
- Favor modules/functions when state is not required.
