

# Redefine clear! method to do nothing (usually it erases the routes)
class << ActionController::Routing::Routes;self;end.class_eval do
  define_method :clear!, lambda {}
end

# Let the gem/plugin add the routes
ActionController::Routing::Routes.draw do |map|
  map.connect "/translations/:language/:klass/:id/:attribute.:format", :controller => "translations", :action => "show"
end
