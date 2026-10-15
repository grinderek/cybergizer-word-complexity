Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "complexity-score", to: "complexity_scores#create"
  get "complexity-score/:job_id", to: "complexity_scores#show"
end
