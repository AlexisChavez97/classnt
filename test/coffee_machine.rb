# frozen_string_literal: true

module CoffeeMachine
  extend Classnt::Pipeline

  module_function

  def brew(coffee_type)
    Classnt.transaction do
      pipe(coffee_type,
           :grind_beans,
           :brew_coffee,
           :pour_into_cup,
           :add_sugar,
           :add_cream,
           :serve)
    end
  end

  # Reverted to positional args to support the clean symbol-based pipeline
  def grind_beans(coffee_type)
    case coffee_type
    in "espresso" | "latte" | "cappuccino"
      [:ok, "Grinding #{coffee_type} beans"]
    in "mud"
      [:error, "Invalid coffee type"]
    end
  end

  def brew_coffee(msg)
    [:ok, msg.sub("Grinding", "Brewing").sub("beans", "")]
  end

  def pour_into_cup(msg)
    [:ok, "#{msg.sub("Brewing", "Pouring")} into cup"]
  end

  def add_sugar(msg)
    [:ok, "#{msg} with sugar"]
  end

  def add_cream(msg)
    [:ok, "#{msg} with cream"]
  end

  def serve(msg)
    [:ok, msg.sub("Pouring", "Serving")]
  end
end
