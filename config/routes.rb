Rails.application.routes.draw do
  resources :things
  get 'main/index'
  root 'main#index'
  resources :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
